# Server 基础设施增强设计

日期：2026-06-18
状态：已批准

## 背景

fruit-shop 后端目前缺少以下基础设施：

- API 文档（Swagger）—— 前后端对接需手动查代码
- 测试覆盖（Jest + Supertest）—— 当前零测试
- 速率限制（Throttler）—— 公开端点无防刷保护
- 健康检查（Terminus）—— K8s/负载均衡无探针

## 目标

1. 接入 `@nestjs/swagger`，`/api/docs` 自动生成接口文档
2. 接入 `@nestjs/throttler`，全局 60 次/分钟/IP，login/register 加强至 10 次/分钟/IP
3. 接入 `@nestjs/terminus`，`/api/health` 检查 DB + Redis 连通性
4. 建立 Jest + Supertest 测试体系，unit + integration 两层覆盖所有端点

## 实施策略

基础设施先行：先接入 Swagger + Throttler + Terminus，再统一写测试。测试能看到完整 API 面貌（含限流行为），效率最高。

---

## 1. Swagger 接口文档

### 依赖

```
@nestjs/swagger
```

### 配置（main.ts）

```typescript
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

// 在 bootstrap() 中，app.listen() 之前
const swaggerConfig = new DocumentBuilder()
  .setTitle('鲜果集 API')
  .setDescription('水果电商接口文档')
  .setVersion('1.0')
  .addBearerAuth()
  .build();
const document = SwaggerModule.createDocument(app, swaggerConfig);
SwaggerModule.setup('api/docs', app, document);
```

### 生产环境控制

通过环境变量 `SWAGGER_ENABLED` 控制，默认 `true`。生产部署时设为 `false`。

### 路径

`/api/docs` — 配合已有的全局前缀 `/api`。

### DTO 自动映射

DTO 上的 `class-validator` 装饰器（`@IsString()`、`@IsNumber()`、`@Min()` 等）自动转为 Swagger schema 约束，无需额外装饰器。

### 改动文件

- `packages/server/src/main.ts`
- `packages/server/package.json`
- `packages/server/.env.example`

---

## 2. 速率限制（@nestjs/throttler）

### 依赖

```
@nestjs/throttler
```

### 全局配置（app.module.ts）

```typescript
import { ThrottlerModule } from '@nestjs/throttler';

@Module({
  imports: [
    ThrottlerModule.forRoot({
      throttlers: [{ ttl: 60000, limit: 60 }],
    }),
    // ... 其他 imports
  ],
})
```

### auth 端点加强

在 `auth.controller.ts` 的 `login` 和 `register` 方法上添加：

```typescript
@Throttle([{ default: { ttl: 60000, limit: 10 } }])
```

### 限流命中响应

HTTP 429，body（不使用 shared/ErrorCode，因为 429 是基础设施错误而非业务错误）：

```json
{ "code": 429, "message": "Too Many Requests" }
```

在 `HttpExceptionFilter` 中捕获 `ThrottlerException`，直接返回 HTTP 429 + 上述 body。`ThrottlerException` 继承自 `HttpException`，现有 filter 可以捕获，但需要自定义响应格式以匹配项目规范。

### 与 @Public() 的关系

`@Public()` 端点仍受限流保护。公开接口更需要防刷（认证接口本身就需要限流）。

### 改动文件

- `packages/server/src/app.module.ts`
- `packages/server/src/modules/auth/auth.controller.ts`
- `packages/server/src/common/filters/http-exception.filter.ts`（处理 ThrottlerException）
- `packages/server/package.json`

---

## 3. 健康检查（@nestjs/terminus）

### 依赖

```
@nestjs/terminus
```

### 新增模块

`packages/server/src/modules/health/`

- `health.module.ts`
- `health.controller.ts`

### 端点

`GET /api/health`（`@Public()` 跳过 JWT 认证）

### TransformInterceptor 兼容

`@nestjs/terminus` 的 `@HealthCheck()` 装饰器直接返回响应，不经过 NestJS 标准响应管道，因此不会被 `TransformInterceptor` 包装。这是预期行为——K8s 探针期望原始的 `{ status, details }` 格式，而非 `{ code, data, message }`。

如果 terminus 响应被 interceptor 拦截（需要在实现时验证），则在 `TransformInterceptor` 中通过 `@BypassTransform()` 自定义装饰器或 `context.getHandler()` 元数据跳过 health 端点。

### 成功响应（HTTP 200）

```json
{
  "status": "ok",
  "details": {
    "database": { "status": "up" },
    "redis": { "status": "up" }
  }
}
```

### 失败响应（HTTP 503）

```json
{
  "status": "error",
  "details": {
    "database": { "status": "down", "message": "..." },
    "redis": { "status": "up" }
  }
}
```

### 检查实现

- **DB**：`TypeOrmHealthIndicator.pingCheck('database')`
- **Redis**：自定义检查，注入 `REDIS_CLIENT`，执行 `redis.ping()`，返回 up/down

### 改动文件

- `packages/server/src/modules/health/health.module.ts`（新增）
- `packages/server/src/modules/health/health.controller.ts`（新增）
- `packages/server/src/app.module.ts`（注册 HealthModule）

---

## 4. Jest + Supertest 测试体系

### 依赖

```
supertest
@types/supertest
```

`@nestjs/testing` 已随 `@nestjs/cli` 安装。

### Jest 配置

使用 NestJS 默认配置，在 `packages/server/` 下新建 `jest.config.ts`：

```typescript
export default {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: { '^.+\\.ts$': 'ts-jest' },
  collectCoverageFrom: ['**/*.ts', '!main.ts', '!**/*.module.ts'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  moduleNameMapper: {
    '^shared(.*)$': '<rootDir>/../../shared/dist/$1',
  },
};
```

集成测试单独配置 `test/jest-e2e.config.ts`：

```typescript
export default {
  rootDir: '.',
  testRegex: '.e2e-spec.ts$',
  transform: { '^.+\\.ts$': 'ts-jest' },
  moduleNameMapper: {
    '^shared(.*)$': '<rootDir>/../../shared/dist/$1',
  },
};
```

### 目录结构

```
packages/server/
  src/
    modules/
      auth/
        auth.controller.spec.ts       ← unit test
      user/
        user.controller.spec.ts       ← unit test
      product/
        product.controller.spec.ts    ← unit test
      cart/
        cart.controller.spec.ts       ← unit test
      order/
        order.controller.spec.ts      ← unit test
  test/
    helpers/
      test-helper.ts                  ← 创建测试 app、seed 数据
    auth.e2e-spec.ts                  ← integration test
    user.e2e-spec.ts                  ← integration test
    product.e2e-spec.ts               ← integration test
    cart.e2e-spec.ts                  ← integration test
    order.e2e-spec.ts                 ← integration test
    health.e2e-spec.ts               ← integration test
```

### 单元测试策略（*.spec.ts）

- 每个 controller 一个 spec 文件
- 使用 `Test.createTestingModule()` + `.overrideProvider(Service).useValue(mockService)`
- 测试内容：
  - 正常响应状态码和数据结构
  - 参数校验（ValidationPipe 拦截非法输入）
  - DTO 约束（必填字段、类型、范围）
- 不需要数据库，纯 mock，运行快

### 集成测试策略（test/*.e2e-spec.ts）

- 使用 `Test.createTestingModule()` 完整启动 NestJS 应用
- `app.getHttpServer()` 获取底层 server，传给 Supertest
- Supertest 发真实 HTTP 请求
- 测试内容：
  - 完整请求链路（controller → service → DB）
  - 认证流程（先 login 拿 token，再请求受保护端点）
  - 限流行为（发超限请求验证 429）
  - 错误处理（业务错误码验证）

### 测试数据库

通过 `.env.test` 配置：

```
DB_DATABASE=fruit_shop_test
REDIS_DB=1
```

集成测试前（beforeAll）：

1. 创建测试 app
2. TypeORM `synchronize: true` 自动建表
3. seed 必要的基础数据（测试用户、测试商品）

集成测试后（afterAll）：

1. 清理测试数据
2. 关闭 app 连接

### 测试脚本（package.json）

```json
{
  "test": "jest",
  "test:unit": "jest --config jest.config.ts",
  "test:e2e": "jest --config test/jest-e2e.config.ts",
  "test:cov": "jest --coverage"
}
```

### 覆盖范围

| 模块    | Unit | Integration | 端点                                                                         |
| ------- | ---- | ----------- | ---------------------------------------------------------------------------- |
| auth    | ✓    | ✓           | POST register, login, refresh, logout (4)                                    |
| user    | ✓    | ✓           | GET profile, PUT profile (2)                                                 |
| product | ✓    | ✓           | GET list, GET :id, POST create(ADMIN), PUT :id(ADMIN), DELETE :id(ADMIN) (5) |
| cart    | ✓    | ✓           | GET list, POST add, PUT :id, DELETE :id (4)                                  |
| order   | ✓    | ✓           | POST create, GET list, GET :id, PUT :id/cancel (4)                           |
| health  | —    | ✓           | GET /health (1)                                                              |

---

## 环境变量新增

`packages/server/.env.example` 新增：

```
SWAGGER_ENABLED=true
```

`.env.test`（新增，用于集成测试）：

```
DB_DATABASE=fruit_shop_test
REDIS_DB=1
JWT_SECRET=test-jwt-secret
```

---

## 不做的事

- 不加 ESLint / Prettier（项目当前无此配置，不在本次范围）
- 不改现有日志配置（已完成的 pino 集成保持不变）
- 不加 CI/CD 配置
- 不写端点的 `@ApiOperation` / `@ApiResponse` 装饰器（自动扫描足够）
