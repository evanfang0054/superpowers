# 服务端日志系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `packages/server` 接入 nestjs-pino，建立三层日志能力（access log / error log / 业务事件），含 requestId 链路追踪与敏感字段脱敏。

**Architecture:** 新增 `common/logging/` 模块封装 pino 配置（脱敏序列化器 + 慢请求阈值 + 环境切换 pretty/JSON），在 `main.ts` 替换内置 Logger、在 `HttpExceptionFilter` 接入分级输出，并在 `auth.service` / `order.service` 注入 `PinoLogger` 埋点关键业务事件。

**Tech Stack:** NestJS 10、nestjs-pino 4.x、pino-http、pino-pretty（dev）、pino `redact` + 自定义 serializer。

**关联文档：**

- Spec: `docs/agent-harness/specs/2026-06-18-server-logging-design.md`
- Contract: `docs/agent-harness/contracts/server-logging.contract.md`（DoD D1–D13）

**验证方式说明：** 项目无测试框架，所有「测试」步骤为**手动验证命令**（curl + grep stdout），每条验证命令对应一条 contract DoD。

---

## 文件结构

```
packages/server/src/
├── common/logging/
│   ├── logging.module.ts          # LoggerModule.forRootAsync，全局可注入
│   ├── pino.config.ts             # 工厂函数：级别/transport/serializers/redact/customProps
│   └── redact.serializer.ts       # redactPaths 数组 + maskPersonalData 工具
├── main.ts                        # 注册 PinoLogger，替换 console.log
├── common/filters/http-exception.filter.ts  # 注入 PinoLogger，业务异常 warn / 未知 error
├── modules/auth/auth.service.ts   # 注入 PinoLogger，登录/JWT/登出埋点
├── modules/order/order.service.ts # 注入 PinoLogger，下单成功埋点
└── app.module.ts                  # imports 引入 LoggerModule
```

---

## Task 1: 安装依赖

**Files:**

- Modify: `packages/server/package.json`

- [ ] **Step 1: 安装生产依赖**

Run:

```bash
pnpm --filter server add nestjs-pino@^4.0.0 pino-http
```

Expected: `package.json` 的 `dependencies` 出现 `nestjs-pino` 和 `pino-http`，`pnpm-lock.yaml` 更新。

- [ ] **Step 2: 安装开发依赖（pino-pretty）**

Run:

```bash
pnpm --filter server add -D pino-pretty
```

Expected: `package.json` 的 `devDependencies` 出现 `pino-pretty`。

- [ ] **Step 3: 验证可导入**

Run:

```bash
cd packages/server && node -e "require('nestjs-pino'); require('pino-http'); require('pino-pretty'); console.log('OK')"
```

Expected: 输出 `OK`，无报错。

- [ ] **Step 4: 提交**

```bash
git add packages/server/package.json pnpm-lock.yaml
git commit -m "chore(server): 引入 nestjs-pino / pino-http / pino-pretty"
```

---

## Task 2: 编写脱敏模块 `redact.serializer.ts`

**Files:**

- Create: `packages/server/src/common/logging/redact.serializer.ts`

- [ ] **Step 1: 编写文件**

```ts
// packages/server/src/common/logging/redact.serializer.ts

/**
 * 日志脱敏工具
 * - redactPaths: 喂给 pino `redact.paths`，按路径精确脱敏
 * - maskPersonalData: 自定义 serializer 中递归处理 body 内敏感字段（手机号/邮箱）
 */

// pino redact 路径（请求头 + 请求体 + 响应体）
export const redactPaths: string[] = [
  // 请求头
  'req.headers.authorization',
  // 请求体 - 密码类
  'req.body.password',
  'req.body.oldPassword',
  'req.body.newPassword',
  // 请求体 - token 类
  'req.body.token',
  'req.body.refreshToken',
  // 响应体 - token 类（auth.service 返回）
  'res.body.accessToken',
  'res.body.refreshToken',
  // 响应体 - data 包装后的 token（TransformInterceptor 包装层）
  'res.body.data.accessToken',
  'res.body.data.refreshToken',
];

const PHONE_RE = /^1[3-9]\d{9}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** 将手机号 13888888888 → 138****8888 */
function maskPhone(phone: string): string {
  if (!PHONE_RE.test(phone)) return phone;
  return phone.slice(0, 3) + '****' + phone.slice(-4);
}

/** 将邮箱 foo@example.com → f***@***.com */
function maskEmail(email: string): string {
  if (!EMAIL_RE.test(email)) return email;
  const [name, domain] = email.split('@');
  const [dom, ...tld] = domain.split('.');
  return `${name[0]}***@***.${tld.join('.')}`;
}

/**
 * 递归遍历对象，对 phone / email 字段做马赛克。
 * 不会修改原始对象（深拷贝）。
 */
export function maskPersonalData<T>(obj: T): T {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(maskPersonalData) as unknown as T;

  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
    if (typeof value === 'string' && (key === 'phone' || key === 'email')) {
      out[key] = key === 'phone' ? maskPhone(value) : maskEmail(value);
    } else if (value && typeof value === 'object') {
      out[key] = maskPersonalData(value);
    } else {
      out[key] = value;
    }
  }
  return out as T;
}
```

- [ ] **Step 2: 编译验证**

Run:

```bash
cd packages/server && pnpm exec tsc --noEmit
```

Expected: 无报错。

- [ ] **Step 3: 提交**

```bash
git add packages/server/src/common/logging/redact.serializer.ts
git commit -m "feat(logging): 新增脱敏工具 redact.serializer"
```

---

## Task 3: 编写 pino 配置工厂 `pino.config.ts`

**Files:**

- Create: `packages/server/src/common/logging/pino.config.ts`

**说明（实现 vs 设计差异）：** 设计文档第 5 节 `customProps` 直接读 `req.user?.id`，但 pino-http 的 `customProps` 在中间件阶段执行，此时 JWT 守卫尚未运行（`req.user` 为 undefined）。**实现改为**在 `pino-http` 的 `serializers.req` 中读取 `req.user?.id`（serializer 在请求处理后期才被调用，此时 `req.user` 已被 passport 注入）。

- [ ] **Step 1: 编写文件**

```ts
// packages/server/src/common/logging/pino.config.ts

import type { Params } from 'nestjs-pino';
import { redactPaths, maskPersonalData } from './redact.serializer';

/** 慢请求阈值（毫秒） */
const SLOW_REQUEST_MS = 500;

/**
 * Pino 配置工厂
 * - 开发环境：pino-pretty 着色
 * - 生产环境：纯 JSON 到 stdout
 * - 默认级别由 LOG_LEVEL 控制，缺省 info
 */
export function buildPinoOptions(): Params {
  const isDev = process.env.NODE_ENV !== 'production';
  const level = process.env.LOG_LEVEL || 'info';

  return {
    pinoHttp: {
      level,
      // 开发用 pretty；生产留空走默认 JSON
      transport: isDev
        ? {
            target: 'pino-pretty',
            options: {
              colorize: true,
              translateTime: 'SYS:yyyy-mm-dd HH:MM:ss.l',
              ignore: 'pid,hostname',
              singleLine: false,
            },
          }
        : undefined,
      // 自动生成 requestId（pino-http 默认使用 nanoid/uuid，依赖 req.id）
      // 自定义请求序列化器：含 userId（来自 req.user，由守卫注入）
      serializers: {
        req: (req: any) => ({
          id: req.id,
          method: req.method,
          url: req.url,
          // 守卫运行后 req.user 才有值；serializer 在请求处理后期被调用
          userId: req.user?.id,
          body: req.body ? maskPersonalData(req.body) : undefined,
        }),
        res: (res: any) => ({
          statusCode: res.statusCode,
        }),
      },
      // 自定义日志字段（在 serializers 之外补充）
      customProps: (req: any) => ({
        requestId: req.id,
      }),
      // pino 内置 redact：覆盖 headers.authorization / body.password 等
      redact: {
        paths: redactPaths,
        censor: '***',
      },
      // 慢请求标记
      customSuccessMessage: (req: any, res: any, time: number) => {
        const slow = time > SLOW_REQUEST_MS;
        return `${req.method} ${req.url} ${res.statusCode} ${time}ms${slow ? ' [SLOW]' : ''}`;
      },
      customErrorMessage: (req: any, res: any, time: number) => {
        const slow = time > SLOW_REQUEST_MS;
        return `${req.method} ${req.url} ${res.statusCode} ${time}ms${slow ? ' [SLOW]' : ''}`;
      },
      // 响应头回写 X-Request-ID（pino-http 默认开启）
    },
  };
}
```

- [ ] **Step 2: 编译验证**

Run:

```bash
cd packages/server && pnpm exec tsc --noEmit
```

Expected: 无报错。

- [ ] **Step 3: 提交**

```bash
git add packages/server/src/common/logging/pino.config.ts
git commit -m "feat(logging): 新增 pino 配置工厂"
```

---

## Task 4: 编写 `logging.module.ts`

**Files:**

- Create: `packages/server/src/common/logging/logging.module.ts`

- [ ] **Step 1: 编写文件**

```ts
// packages/server/src/common/logging/logging.module.ts

import { Module } from '@nestjs/common';
import { LoggerModule } from 'nestjs-pino';
import { buildPinoOptions } from './pino.config';

@Module({
  imports: [LoggerModule.forRoot(buildPinoOptions())],
  exports: [LoggerModule],
})
export class LoggingModule {}
```

- [ ] **Step 2: 在 AppModule 引入**

修改 `packages/server/src/app.module.ts`：

```ts
// 在 import 列表顶部加入（其他 import 之后）
import { LoggingModule } from './common/logging/logging.module';

// @Module.imports 数组首项加入 LoggingModule
imports: [
  ConfigModule.forRoot({
    isGlobal: true,
    envFilePath: ['.env.local', '.env'],
  }),
  LoggingModule, // ← 新增，置于 TypeOrmModule 之前，确保启动期日志也走 pino
  TypeOrmModule.forRootAsync({ /* ...existing */ }),
  // ... 其余不变
],
```

- [ ] **Step 3: 编译验证**

Run:

```bash
cd packages/server && pnpm exec tsc --noEmit
```

Expected: 无报错。

- [ ] **Step 4: 提交**

```bash
git add packages/server/src/common/logging/logging.module.ts packages/server/src/app.module.ts
git commit -m "feat(logging): 新增 LoggingModule 并接入 AppModule"
```

---

## Task 5: 改造 `main.ts` — 注册 PinoLogger

**Files:**

- Modify: `packages/server/src/main.ts`

- [ ] **Step 1: 改造文件**

完整替换 `main.ts` 为：

```ts
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  // 使用 pino 作为全局 logger（覆盖 NestJS 内置 Logger）
  app.useLogger(app.get(Logger));

  // 全局路由前缀 — nginx 反向代理 /api/ → /api/
  app.setGlobalPrefix('api');

  // 全局 CORS
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // 全局 ValidationPipe — 自动 trim + 白名单 + 禁止多余字段
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // 全局响应拦截器 — 包装 { code: 0, data, message: 'success' }
  app.useGlobalInterceptors(new TransformInterceptor());

  // 全局异常过滤器 — 统一返回 { code, message }
  app.useGlobalFilters(new HttpExceptionFilter());

  const port = process.env.PORT || 3000;
  await app.listen(port);
  app.get(Logger).log(`Application is running on: http://localhost:${port}`);
}

bootstrap();
```

变化点：

1. import `Logger` from `nestjs-pino`
2. `NestFactory.create(AppModule, { bufferLogs: true })` — 缓冲启动期日志
3. `app.useLogger(app.get(Logger))` — 注册
4. 启动日志用 `app.get(Logger).log(...)` 取代 `console.log`

- [ ] **Step 2: 启动验证 D1**

Run（终端 1）:

```bash
pnpm --filter server dev
```

Expected: 启动时 stdout 输出含 `Application is running on: http://localhost:3000` 的 pretty 行（含 timestamp + level + context）。

- [ ] **Step 3: 提交**

```bash
git add packages/server/src/main.ts
git commit -m "feat(logging): main.ts 接入 PinoLogger 替换 console.log"
```

---

## Task 6: 改造 `HttpExceptionFilter` — 分级日志

**Files:**

- Modify: `packages/server/src/common/filters/http-exception.filter.ts`

**说明：** 原 filter 仅对「未知异常」打日志。改为：

- 业务异常（HttpException）→ `logger.warn`，记录 code / message / path
- 未知异常 → `logger.error` + 完整 stack

- [ ] **Step 1: 完整替换文件**

```ts
import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { PinoLogger } from 'nestjs-pino';
import { Response } from 'express';

/**
 * 统一异常响应格式
 * { code: number, message: string }
 *
 * 业务异常 (HttpException) → warn 级别日志
 * 未知异常              → error 级别日志 + 完整 stack
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  constructor(private readonly logger: PinoLogger) {}

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<{ method: string; url: string }>();
    const response = ctx.getResponse<Response>();

    let code = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = '服务器内部错误';

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
        const resp = exceptionResponse as Record<string, any>;
        if (Array.isArray(resp.message)) {
          // class-validator 验证错误
          code = status;
          message = resp.message.join('; ');
        } else if (typeof resp.code === 'number') {
          // 自定义业务异常: { code: 40001, message: '...' }
          code = resp.code;
          message = resp.message || exception.message;
        } else {
          code = status;
          message = resp.message || exception.message;
        }
      } else if (typeof exceptionResponse === 'string') {
        code = status;
        message = exceptionResponse;
      }

      // 业务异常 - warn 级别
      this.logger.warn(
        {
          method: req.method,
          url: req.url,
          code,
          message,
        },
        `业务异常: ${message}`,
      );
    } else {
      // 未知异常 - error 级别 + 完整 stack
      this.logger.error(
        {
          method: req.method,
          url: req.url,
          err: exception,
        },
        'Unhandled exception',
      );
    }

    response.status(HttpStatus.OK).json({
      code,
      message,
    });
  }
}
```

- [ ] **Step 2: 改造 filter 的实例化方式**

`main.ts` 中现在用 `new HttpExceptionFilter()` 实例化（无参数）。改为由 DI 容器注入：

修改 `packages/server/src/main.ts` 中 `app.useGlobalFilters(...)` 这一行：

```ts
// 原：app.useGlobalFilters(new HttpExceptionFilter());
// 改为：
app.useGlobalFilters(app.get(HttpExceptionFilter));
```

- [ ] **Step 3: 编译验证**

Run:

```bash
cd packages/server && pnpm exec tsc --noEmit
```

Expected: 无报错。

- [ ] **Step 4: 启动验证 D4（业务异常 warn）**

终端 1 启动：

```bash
pnpm --filter server dev
```

终端 2 触发参数校验失败：

```bash
curl -sX POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"not-a-phone"}' | head
```

Expected（终端 1 stdout）：

- 出现一条 `WARN` 级别日志
- 含 `code: 400` 与 `message: phone must ...`（class-validator 报错合并）
- 含 `method / url`

- [ ] **Step 5: 启动验证 D5（未知异常 error）**

临时在 `packages/server/src/modules/product/product.controller.ts` 的任一 handler 顶部加入：

```ts
throw new Error('test-unhandled');
```

（验证后**必须删除**）

终端 2 触发：

```bash
curl -s http://localhost:3000/api/products | head
```

Expected（终端 1 stdout）：

- 出现一条 `ERROR` 级别日志
- `message: Unhandled exception`
- `err.stack` 含 `Error: test-unhandled` 与完整堆栈

- [ ] **Step 6: 删除临时 throw 并提交**

恢复 `product.controller.ts`，然后：

```bash
git add packages/server/src/common/filters/http-exception.filter.ts packages/server/src/main.ts
git commit -m "feat(logging): HttpExceptionFilter 分级日志（warn/error）"
```

---

## Task 7: `auth.service` 注入 PinoLogger + 业务埋点

**Files:**

- Modify: `packages/server/src/modules/auth/auth.service.ts`

- [ ] **Step 1: 修改 import 与构造函数**

在文件顶部 import 区追加：

```ts
import { PinoLogger } from 'nestjs-pino';
```

构造函数追加 `private readonly logger: PinoLogger` 参数：

```ts
constructor(
  @InjectRepository(UserEntity)
  private readonly userRepo: Repository<UserEntity>,
  private readonly jwtService: JwtService,
  private readonly configService: ConfigService,
  @Inject('REDIS_CLIENT')
  private readonly redis: Redis,
  private readonly logger: PinoLogger,  // ← 新增
) {}
```

并在构造函数体内设置 context：

```ts
constructor(/* ...params..., */ private readonly logger: PinoLogger) {
  this.logger.setContext(AuthService.name);
}
```

- [ ] **Step 2: 在 `login` 成功分支埋点**

修改 `auth.service.ts` 中 `login` 方法，在 `const tokens = await this.generateTokens(...)` 之后、`return` 之前插入：

```ts
const tokens = await this.generateTokens(user.id, user.phone, user.role);

this.logger.info(
  {
    userId: user.id,
    phone: user.phone,
  },
  '用户登录成功',
);

// 返回时排除 password
const { password: _, ...userWithoutPassword } = user;
return {/* ...existing */};
```

- [ ] **Step 3: 在 `generateTokens` 内埋点 JWT 签发（debug 级）**

修改 `generateTokens` 方法，在 `return { accessToken, refreshToken }` 之前插入：

```ts
this.logger.debug(
  {
    userId,
    accessJti,
    refreshJti,
  },
  'JWT 签发',
);

return { accessToken, refreshToken };
```

- [ ] **Step 4: 在 `logout` 黑名单写入成功后埋点**

修改 `logout` 方法中 `await this.redis.set(...)` 之后插入：

```ts
await this.redis.set(`token:blacklist:${jti}`, '1', 'EX', ttl);

this.logger.info(
  {
    userId,
    jti,
    ttl,
  },
  'JWT 已加入黑名单（登出）',
);
```

- [ ] **Step 5: 在 `auth.module.ts` 确认 PinoLogger 可注入**

`nestjs-pino` 的 `LoggerModule` 已在 `LoggingModule` 中通过 `exports` 导出，但 `AuthModule` 需确保 `LoggingModule` 在 imports 中可见。由于 `LoggerModule.forRoot` 是全局注册（nestjs-pino v4 默认 global），无需在每个子模块显式 import。

验证：启动后若报 `Nest can't resolve dependencies of AuthService (?, +)`，则需在 `AuthModule.imports` 显式加入 `LoggingModule`。**先不加，遇错再加。**

- [ ] **Step 6: 编译验证**

Run:

```bash
cd packages/server && pnpm exec tsc --noEmit
```

Expected: 无报错。

- [ ] **Step 7: 启动验证 D10（登录 + JWT 日志）**

终端 1：`pnpm --filter server dev`
终端 2（注册 + 登录）：

```bash
TOKEN=$(curl -sX POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"13900000001","password":"Pass1234","nickname":"log_test"}' \
  | grep -o '\"accessToken\":\"[^\"]*\"' | cut -d'"' -f4)

curl -sX POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13900000001","password":"Pass1234"}' >/dev/null
```

Expected（终端 1）：

- 出现 `INFO` 日志：`用户登录成功`，含 `userId / phone: "139****0001"`
- 出现 `DEBUG` 日志：`JWT 签发`，含 `accessJti / refreshJti`

终端 2（登出）：

```bash
curl -sX POST http://localhost:3000/api/auth/logout -H "Authorization: Bearer $TOKEN" >/dev/null
```

Expected（终端 1）：

- 出现 `INFO` 日志：`JWT 已加入黑名单（登出）`，含 `userId / jti / ttl`

- [ ] **Step 8: 提交**

```bash
git add packages/server/src/modules/auth/auth.service.ts
git commit -m "feat(logging): auth.service 接入 PinoLogger（登录/JWT/登出）"
```

---

## Task 8: `order.service` 注入 PinoLogger + 下单埋点

**Files:**

- Modify: `packages/server/src/modules/order/order.service.ts`

- [ ] **Step 1: 修改 import 与构造函数**

文件顶部 import 区追加：

```ts
import { PinoLogger } from 'nestjs-pino';
```

构造函数追加 `private readonly logger: PinoLogger` 参数，并在体内设置 context：

```ts
constructor(
  @InjectRepository(OrderEntity)
  private readonly orderRepo: Repository<OrderEntity>,
  @InjectRepository(OrderItemEntity)
  private readonly orderItemRepo: Repository<OrderItemEntity>,
  @InjectRepository(CartEntity)
  private readonly cartRepo: Repository<CartEntity>,
  private readonly cartService: CartService,
  private readonly dataSource: DataSource,
  private readonly logger: PinoLogger,  // ← 新增
) {
  this.logger.setContext(OrderService.name);
}
```

- [ ] **Step 2: 在 `create` 方法事务提交后埋点**

修改 `create` 方法，在 `await queryRunner.commitTransaction();` 之后、`return this.findOne(userId, savedOrder.id);` 之前插入：

```ts
await queryRunner.commitTransaction();

this.logger.info(
  {
    orderId: savedOrder.id,
    orderNo,
    userId,
    totalAmount,
    itemCount: orderItems.length,
  },
  '订单创建成功',
);

return this.findOne(userId, savedOrder.id);
```

- [ ] **Step 3: 编译验证**

Run:

```bash
cd packages/server && pnpm exec tsc --noEmit
```

Expected: 无报错。

- [ ] **Step 4: 启动验证 D9（下单业务日志）**

前置：需先注册并登录、加购商品。完整 curl 链：

```bash
# 1. 登录拿 token
TOKEN=$(curl -sX POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13900000001","password":"Pass1234"}' \
  | grep -o '\"accessToken\":\"[^\"]*\"' | cut -d'"' -f4)

# 2. 拿任意商品 id（公开接口 GET /api/products）
PID=$(curl -s http://localhost:3000/api/products | grep -o '\"id\":[0-9]*' | head -1 | cut -d':' -f2)

# 3. 加购
curl -sX POST http://localhost:3000/api/cart \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"productId\":$PID,\"quantity\":1}" >/dev/null

# 4. 下单
curl -sX POST http://localhost:3000/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"address":"测试地址","phone":"13900000001"}' >/dev/null
```

Expected（终端 1）：

- 出现 `INFO` 日志：`订单创建成功`
- 字段含 `orderId / orderNo / userId / totalAmount / itemCount`
- 该日志的 `requestId` 与对应 access log 的 `requestId` 一致

- [ ] **Step 5: 提交**

```bash
git add packages/server/src/modules/order/order.service.ts
git commit -m "feat(logging): order.service 接入 PinoLogger（下单成功）"
```

---

## Task 9: 更新 `.env.example` 与 contract 验证

**Files:**

- Modify: `packages/server/.env.example`

- [ ] **Step 1: 追加 LOG_LEVEL**

在 `.env.example` 文件末尾追加：

```
# Logging
LOG_LEVEL=info
```

- [ ] **Step 2: 提交**

```bash
git add packages/server/.env.example
git commit -m "docs(server): .env.example 补充 LOG_LEVEL"
```

- [ ] **Step 3: 合约全量验证（对照 D1–D13）**

按下面清单逐项跑（每条都是单条命令，对照 contract 期望输出）。任一未通过回到对应 Task 修正。

```bash
# D1 启动日志（已在 Task 5 验证）
# D2 Access log 字段完整性 + X-Request-ID
curl -i http://localhost:3000/api/products 2>&1 | grep -i "x-request-id"

# D3 requestId 串联：抓响应头里的 id，去 stdout grep
RID=$(curl -si http://localhost:3000/api/products 2>&1 | grep -i "x-request-id" | awk '{print $2}' | tr -d '\r')
# 在终端 1（server 日志窗口）执行：
#   grep $RID <最近一段日志>   ← 应至少能找到 1 条 access log

# D4 业务异常 warn（已在 Task 6 验证）
# D5 未知异常 error（已在 Task 6 验证）

# D6 请求脱敏
curl -sX POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"13900000099","password":"SecretPass1"}' >/dev/null
# 终端 1 应看到 req.body.password 为 "***"，req.headers.authorization 为 "***"（若发了 auth header）

# D7 响应脱敏
curl -sX POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13900000099","password":"SecretPass1"}' >/dev/null
# 终端 1 应看到 res.body.accessToken / res.body.refreshToken 为 "***"

# D8 慢请求标记：临时加 controller 延迟（操作同 Task 6 Step 5，延迟 600ms）
# 在 product.controller 顶部加：await new Promise(r => setTimeout(r, 600));
# curl 后应看到日志 message 末尾含 [SLOW]，responseTime > 500
# 验证后务必移除延迟代码

# D9 下单日志（已在 Task 8 验证）
# D10 认证日志（已在 Task 7 验证）

# D11 日志级别控制
# 11a. 默认 info：可见 access log + INFO 日志，DEBUG 不见
# 11b. .env.local 设 LOG_LEVEL=warn，重启，重复 D2：access log 应消失
# 11c. .env.local 设 LOG_LEVEL=debug，重启：可见 "JWT 签发" DEBUG 日志

# D12 端到端回归
# 跑 Task 8 Step 4 的完整链路，确认全程响应 code:0、无 5xx、无 "Unhandled exception" 日志

# D13 TypeORM 兼容
# .env.local 设 DB_LOGGING=true，重启，触发任意 SQL 查询
# stdout 应同时含 TypeORM SQL 输出 + pino 日志，互不干扰
```

- [ ] **Step 4: 终结提交（如有遗留改动）**

如果验证过程中为调试修改过任何文件，最终统一一次提交；否则跳过。

```bash
git status
# 如有改动：
git commit -am "chore(logging): 验证后微调"
```

---

## Self-Review 结果

**Spec 覆盖**：

- 第 2 节选型 → Task 1 ✓
- 第 3 节三层架构（access / error / 业务）→ Task 5（access via pino-http）/ Task 6（error）/ Task 7–8（业务）✓
- 第 4 节文件结构 → Task 2–4 ✓
- 第 5 节关键配置 → Task 3 ✓
- 第 6 节脱敏清单 → Task 2（含 oldPassword/newPassword、authorization、data.* 包装）✓
- 第 7 节改造点 → Task 5（main.ts）/ Task 6（filter）/ Task 7–8（service）✓
- 第 8 节风险（pino-pretty dev only / DB_LOGGING 不冲突 / async 不启用）→ 计划未额外启用 async、Task 1 分了 devDep、Task 9 D13 覆盖 DB_LOGGING ✓
- 第 9 节测试清单 → Task 5–8 + Task 9 的 DoD 验证 ✓
- 第 10 节实施分步 → 9 个 Task 对齐 ✓

**占位符扫描**：无 TBD/TODO，所有 step 含完整代码或完整命令。

**类型一致性**：

- `PinoLogger` 统一从 `nestjs-pino` 导入 ✓
- `redactPaths` / `maskPersonalData` 定义点（Task 2）与使用点（Task 3）签名一致 ✓
- `buildPinoOptions` 返回 `Params`（nestjs-pino 类型），与 Task 4 `LoggerModule.forRoot` 入参一致 ✓
- `HttpExceptionFilter` 构造函数改为注入 `PinoLogger`，Task 6 Step 2 同步更新了 `main.ts` 的实例化方式 ✓

**实现 vs 设计的偏离（已显式记录）：**

- 设计第 5 节 `customProps(req) => ({ userId: req.user?.id })` 在中间件阶段拿不到 user。改为在 `serializers.req` 里读 `req.user?.id`（serializer 在请求处理后期才调用）。已在 Task 3 顶部说明。
