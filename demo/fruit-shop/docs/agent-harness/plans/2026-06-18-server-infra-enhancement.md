# Server 基础设施增强实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 fruit-shop 后端接入 Swagger 文档、速率限制、健康检查，并建立 Jest + Supertest 测试体系。

**Architecture:** 先接入 3 个 NestJS 标准模块（swagger/throttler/terminus），再建立 unit + integration 两层测试覆盖全部 21 个端点。测试中发现的 CategoryController 端点（spec 遗漏）一并覆盖。

**Tech Stack:** @nestjs/swagger, @nestjs/throttler, @nestjs/terminus, Jest, ts-jest, Supertest

---

## 文件结构总览

### 新建文件

| 文件                                                              | 职责                                 |
| ----------------------------------------------------------------- | ------------------------------------ |
| `packages/server/jest.config.ts`                                  | 单元测试 Jest 配置                   |
| `packages/server/test/jest-e2e.config.ts`                         | 集成测试 Jest 配置                   |
| `packages/server/test/helpers/test-helper.ts`                     | 集成测试 app 创建、auth helper、seed |
| `packages/server/.env.test`                                       | 集成测试环境变量                     |
| `packages/server/src/modules/health/health.module.ts`             | Health 模块                          |
| `packages/server/src/modules/health/health.controller.ts`         | /health 端点                         |
| `packages/server/src/modules/auth/auth.controller.spec.ts`        | Auth 单元测试                        |
| `packages/server/src/modules/user/user.controller.spec.ts`        | User 单元测试                        |
| `packages/server/src/modules/product/product.controller.spec.ts`  | Product 单元测试                     |
| `packages/server/src/modules/product/category.controller.spec.ts` | Category 单元测试                    |
| `packages/server/src/modules/cart/cart.controller.spec.ts`        | Cart 单元测试                        |
| `packages/server/src/modules/order/order.controller.spec.ts`      | Order 单元测试                       |
| `packages/server/test/auth.e2e-spec.ts`                           | Auth 集成测试                        |
| `packages/server/test/user.e2e-spec.ts`                           | User 集成测试                        |
| `packages/server/test/product.e2e-spec.ts`                        | Product + Category 集成测试          |
| `packages/server/test/cart.e2e-spec.ts`                           | Cart 集成测试                        |
| `packages/server/test/order.e2e-spec.ts`                          | Order 集成测试                       |
| `packages/server/test/health.e2e-spec.ts`                         | Health 集成测试                      |

### 修改文件

| 文件                                                          | 改动                                |
| ------------------------------------------------------------- | ----------------------------------- |
| `packages/server/package.json`                                | 新增依赖 + test 脚本                |
| `packages/server/src/main.ts`                                 | Swagger setup                       |
| `packages/server/src/app.module.ts`                           | ThrottlerModule + HealthModule 注册 |
| `packages/server/src/modules/auth/auth.controller.ts`         | @Throttle 装饰器                    |
| `packages/server/src/common/filters/http-exception.filter.ts` | ThrottlerException 特殊处理         |
| `packages/server/.env.example`                                | SWAGGER_ENABLED                     |

---

## Task 1: 安装依赖与 Jest 配置

**Files:**

- Modify: `packages/server/package.json`
- Create: `packages/server/jest.config.ts`
- Create: `packages/server/test/jest-e2e.config.ts`
- Create: `packages/server/.env.test`

- [ ] **Step 1: 安装所有新增依赖**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm --filter server add @nestjs/swagger @nestjs/throttler @nestjs/terminus @nestjs/terminus @nestjs/testing
pnpm --filter server add -D supertest @types/supertest ts-jest
```

- [ ] **Step 2: 创建单元测试 Jest 配置**

`packages/server/jest.config.ts`:

```typescript
import type { Config } from 'jest';

const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: ['**/*.ts', '!main.ts', '!**/*.module.ts'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  moduleNameMapper: {
    '^shared(.*)$': '<rootDir>/../../shared/dist$1',
  },
};

export default config;
```

- [ ] **Step 3: 创建集成测试 Jest 配置**

`packages/server/test/jest-e2e.config.ts`:

```typescript
import type { Config } from 'jest';

const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: '.e2e-spec.ts$',
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  moduleNameMapper: {
    '^shared(.*)$': '<rootDir>/../../shared/dist$1',
  },
};

export default config;
```

- [ ] **Step 4: 创建测试环境变量**

`packages/server/.env.test`:

```
DB_HOST=localhost
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=root123
DB_DATABASE=fruit_shop_test
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=1
JWT_SECRET=test-jwt-secret-for-testing
JWT_ACCESS_EXPIRES_IN=900
JWT_REFRESH_EXPIRES_IN=604800
PORT=3001
```

- [ ] **Step 5: 添加 test 脚本到 package.json**

在 `packages/server/package.json` 的 `scripts` 中添加：

```json
"test": "jest",
"test:unit": "jest --config jest.config.ts",
"test:e2e": "jest --config test/jest-e2e.config.ts --runInBand",
"test:cov": "jest --coverage"
```

- [ ] **Step 6: Commit**

```bash
git add packages/server/package.json packages/server/pnpm-lock.yaml packages/server/jest.config.ts packages/server/test/jest-e2e.config.ts packages/server/.env.test
git commit -m "chore(server): install swagger/throttler/terminus/test deps and jest config"
```

---

## Task 2: 接入 Swagger

**Files:**

- Modify: `packages/server/src/main.ts`
- Modify: `packages/server/.env.example`

- [ ] **Step 1: 在 main.ts 中添加 Swagger 配置**

在 `packages/server/src/main.ts` 的 `bootstrap()` 中，`app.enableCors()` 之后、`app.useGlobalPipes()` 之前添加：

```typescript
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

// Swagger API 文档（可通过 SWAGGER_ENABLED=false 关闭）
if (process.env.SWAGGER_ENABLED !== 'false') {
  const swaggerConfig = new DocumentBuilder()
    .setTitle('鲜果集 API')
    .setDescription('水果电商接口文档')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);
}
```

- [ ] **Step 2: 更新 .env.example**

在 `packages/server/.env.example` 末尾添加：

```
# Swagger（设为 false 关闭 API 文档）
SWAGGER_ENABLED=true
```

- [ ] **Step 3: 启动验证 Swagger 可访问**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm --filter shared build
pnpm --filter server start:dev &
sleep 3
curl -s http://localhost:3000/api/docs-json | head -c 200
# 预期：返回 JSON，包含 openapi 和 info 字段
kill %1
```

- [ ] **Step 4: Commit**

```bash
git add packages/server/src/main.ts packages/server/.env.example
git commit -m "feat(server): integrate @nestjs/swagger at /api/docs"
```

---

## Task 3: 接入速率限制

**Files:**

- Modify: `packages/server/src/app.module.ts`
- Modify: `packages/server/src/modules/auth/auth.controller.ts`
- Modify: `packages/server/src/common/filters/http-exception.filter.ts`

- [ ] **Step 1: 在 AppModule 注册 ThrottlerModule**

在 `packages/server/src/app.module.ts` 的 `imports` 数组顶部添加：

```typescript
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';

// 在 @Module imports 数组中添加：
ThrottlerModule.forRoot({
  throttlers: [{ ttl: 60000, limit: 60 }],
}),
```

在 `providers` 中注册全局 ThrottlerGuard：

```typescript
providers: [
  {
    provide: APP_GUARD,
    useClass: ThrottlerGuard,
  },
],
```

- [ ] **Step 2: 为 login/register 添加加强限流**

在 `packages/server/src/modules/auth/auth.controller.ts` 中：

添加 import：

```typescript
import { Throttle } from '@nestjs/throttler';
```

在 `register` 和 `login` 方法上添加装饰器：

```typescript
@Throttle([{ default: { ttl: 60000, limit: 10 } }])
```

- [ ] **Step 3: 处理 ThrottlerException 的 HTTP 状态码**

`@nestjs/throttler` 抛出的 `ThrottlerException` 是 `HttpException` 子类，`getStatus()` 返回 429。当前 `HttpExceptionFilter` 对所有异常返回 HTTP 200，但 429 应该保持真实状态码以便 K8s/负载均衡识别。

在 `packages/server/src/common/filters/http-exception.filter.ts` 中修改 `catch` 方法，在 `response.status(HttpStatus.OK)` 之前添加特殊处理：

```typescript
import { ThrottlerException } from '@nestjs/throttler';

// 在 catch 方法中，response.status() 调用之前添加：
const httpStatus =
  exception instanceof ThrottlerException ? HttpStatus.TOO_MANY_REQUESTS : HttpStatus.OK;

// 将 response.status(HttpStatus.OK) 改为：
response.status(httpStatus).json({
  code,
  message,
});
```

- [ ] **Step 4: 启动验证限流生效**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm --filter server start:dev &
sleep 3

# 发 11 次 login 请求（限流 10 次/分钟），第 11 次应返回 429
for i in $(seq 1 11); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"phone":"13800000000","password":"test123"}')
  echo "Request $i: HTTP $STATUS"
done
kill %1
```

预期：前 10 次返回 HTTP 200（业务错误），第 11 次返回 HTTP 429。

- [ ] **Step 5: Commit**

```bash
git add packages/server/src/app.module.ts packages/server/src/modules/auth/auth.controller.ts packages/server/src/common/filters/http-exception.filter.ts
git commit -m "feat(server): integrate @nestjs/throttler with global 60/min and auth 10/min rate limits"
```

---

## Task 4: 接入健康检查

**Files:**

- Create: `packages/server/src/modules/health/health.module.ts`
- Create: `packages/server/src/modules/health/health.controller.ts`
- Modify: `packages/server/src/app.module.ts`

- [ ] **Step 1: 创建 health.module.ts**

`packages/server/src/modules/health/health.module.ts`:

```typescript
import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';

@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
})
export class HealthModule {}
```

- [ ] **Step 2: 创建 health.controller.ts**

`packages/server/src/modules/health/health.controller.ts`:

```typescript
import { Controller, Get } from '@nestjs/common';
import { HealthCheckService, HealthCheck, TypeOrmHealthIndicator } from '@nestjs/terminus';
import { InjectRedis } from '@nestjs-modules/ioredis';
import { Redis } from 'ioredis';
import { Public } from '../../common/decorators/public.decorator';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    @InjectRedis() private readonly redis: Redis,
  ) {}

  @Get()
  @Public()
  @HealthCheck()
  check() {
    return this.health.check([() => this.db.pingCheck('database'), () => this.redisCheck()]);
  }

  private async redisCheck() {
    try {
      const result = await this.redis.ping();
      return { redis: { status: result === 'PONG' ? 'up' : 'down' } };
    } catch (error) {
      return { redis: { status: 'down', message: (error as Error).message } };
    }
  }
}
```

- [ ] **Step 3: 在 AppModule 注册 HealthModule**

在 `packages/server/src/app.module.ts` 的 `imports` 数组中添加：

```typescript
import { HealthModule } from './modules/health/health.module';

// 在 imports 数组中（建议放在最后）
HealthModule,
```

- [ ] **Step 4: 启动验证 health 端点**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm --filter server start:dev &
sleep 3
curl -s http://localhost:3000/api/health | python3 -m json.tool
# 预期：{ "status": "ok", "details": { "database": { "status": "up" }, "redis": { "status": "up" } } }
kill %1
```

- [ ] **Step 5: Commit**

```bash
git add packages/server/src/modules/health/ packages/server/src/app.module.ts
git commit -m "feat(server): integrate @nestjs/terminus with /health endpoint (DB + Redis checks)"
```

---

## Task 5: Auth 模块单元测试

**Files:**

- Create: `packages/server/src/modules/auth/auth.controller.spec.ts`

- [ ] **Step 1: 编写 Auth 单元测试**

`packages/server/src/modules/auth/auth.controller.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: jest.Mocked<AuthService>;

  const mockAuthService = {
    register: jest.fn(),
    login: jest.fn(),
    refresh: jest.fn(),
    logout: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: mockAuthService }],
    }).compile();

    controller = module.get<AuthController>(AuthController);
    authService = module.get(AuthService) as jest.Mocked<AuthService>;
    jest.clearAllMocks();
  });

  describe('POST /auth/register', () => {
    it('should register a new user', async () => {
      const dto = { phone: '13800000001', password: 'test123456' };
      const result = {
        accessToken: 'at',
        refreshToken: 'rt',
        user: { id: 1, phone: '13800000001' },
      };
      authService.register.mockResolvedValue(result as any);

      expect(await controller.register(dto)).toEqual(result);
      expect(authService.register).toHaveBeenCalledWith(dto);
    });
  });

  describe('POST /auth/login', () => {
    it('should login with valid credentials', async () => {
      const dto = { phone: '13800000001', password: 'test123456' };
      const result = {
        accessToken: 'at',
        refreshToken: 'rt',
        user: { id: 1, phone: '13800000001' },
      };
      authService.login.mockResolvedValue(result as any);

      expect(await controller.login(dto)).toEqual(result);
      expect(authService.login).toHaveBeenCalledWith(dto);
    });
  });

  describe('POST /auth/refresh', () => {
    it('should refresh access token', async () => {
      const dto = { refreshToken: 'valid-rt' };
      const result = { accessToken: 'new-at' };
      authService.refresh.mockResolvedValue(result as any);

      expect(await controller.refresh(dto)).toEqual(result);
      expect(authService.refresh).toHaveBeenCalledWith(dto);
    });
  });

  describe('POST /auth/logout', () => {
    it('should logout user', async () => {
      const user = { id: 1, jti: 'test-jti' };
      authService.logout.mockResolvedValue(null as any);

      // logout 方法需要 @Req() 和 @CurrentUser()，直接调用测试
      expect(
        await controller.logout(user, { headers: { authorization: 'Bearer test-token' } } as any),
      ).toBeNull();
      expect(authService.logout).toHaveBeenCalledWith(1, 'test-jti', 'test-token');
    });
  });
});
```

- [ ] **Step 2: 运行单元测试验证通过**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm --filter shared build
pnpm --filter server test:unit -- --testPathPattern=auth.controller.spec
```

预期：4 tests passed。

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/auth/auth.controller.spec.ts
git commit -m "test(server): auth controller unit tests"
```

---

## Task 6: User 模块单元测试

**Files:**

- Create: `packages/server/src/modules/user/user.controller.spec.ts`

- [ ] **Step 1: 编写 User 单元测试**

`packages/server/src/modules/user/user.controller.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { UserController } from './user.controller';
import { UserService } from './user.service';

describe('UserController', () => {
  let controller: UserController;
  let userService: jest.Mocked<UserService>;

  const mockUserService = {
    getProfile: jest.fn(),
    updateProfile: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UserController],
      providers: [{ provide: UserService, useValue: mockUserService }],
    }).compile();

    controller = module.get<UserController>(UserController);
    userService = module.get(UserService) as jest.Mocked<UserService>;
    jest.clearAllMocks();
  });

  describe('GET /user/profile', () => {
    it('should return user profile', async () => {
      const profile = { id: 1, phone: '13800000001', nickname: 'test' };
      userService.getProfile.mockResolvedValue(profile as any);

      expect(await controller.getProfile(1)).toEqual(profile);
      expect(userService.getProfile).toHaveBeenCalledWith(1);
    });
  });

  describe('PUT /user/profile', () => {
    it('should update user profile', async () => {
      const dto = { nickname: 'new-name' };
      const updated = { id: 1, nickname: 'new-name' };
      userService.updateProfile.mockResolvedValue(updated as any);

      expect(await controller.updateProfile(1, dto)).toEqual(updated);
      expect(userService.updateProfile).toHaveBeenCalledWith(1, dto);
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- --testPathPattern=user.controller.spec
```

预期：2 tests passed。

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/user/user.controller.spec.ts
git commit -m "test(server): user controller unit tests"
```

---

## Task 7: Product + Category 模块单元测试

**Files:**

- Create: `packages/server/src/modules/product/product.controller.spec.ts`
- Create: `packages/server/src/modules/product/category.controller.spec.ts`

- [ ] **Step 1: 编写 Product 单元测试**

`packages/server/src/modules/product/product.controller.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { ProductController } from './product.controller';
import { ProductService } from './product.service';

describe('ProductController', () => {
  let controller: ProductController;
  let productService: jest.Mocked<ProductService>;

  const mockProductService = {
    findAll: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ProductController],
      providers: [{ provide: ProductService, useValue: mockProductService }],
    }).compile();

    controller = module.get<ProductController>(ProductController);
    productService = module.get(ProductService) as jest.Mocked<ProductService>;
    jest.clearAllMocks();
  });

  describe('GET /products', () => {
    it('should return paginated products', async () => {
      const result = { list: [], total: 0, page: 1, limit: 10 };
      productService.findAll.mockResolvedValue(result as any);

      expect(await controller.findAll({ page: 1, limit: 10 })).toEqual(result);
    });
  });

  describe('GET /products/:id', () => {
    it('should return a product by id', async () => {
      const product = { id: 1, name: '苹果' };
      productService.findOne.mockResolvedValue(product as any);

      expect(await controller.findOne(1)).toEqual(product);
      expect(productService.findOne).toHaveBeenCalledWith(1);
    });
  });

  describe('POST /products', () => {
    it('should create a product (ADMIN)', async () => {
      const dto = {
        name: '苹果',
        origin: '山东',
        price: 9.9,
        unit: '斤',
        sweetness: '甜',
        weight: '500g',
        image: 'http://example.com/apple.jpg',
        color: '#FF0000',
        categoryId: 1,
        stock: 100,
      };
      const created = { id: 1, ...dto };
      productService.create.mockResolvedValue(created as any);

      expect(await controller.create(dto)).toEqual(created);
      expect(productService.create).toHaveBeenCalledWith(dto);
    });
  });

  describe('PUT /products/:id', () => {
    it('should update a product (ADMIN)', async () => {
      const dto = { price: 12.9 };
      const updated = { id: 1, name: '苹果', price: 12.9 };
      productService.update.mockResolvedValue(updated as any);

      expect(await controller.update(1, dto)).toEqual(updated);
      expect(productService.update).toHaveBeenCalledWith(1, dto);
    });
  });

  describe('DELETE /products/:id', () => {
    it('should remove a product (ADMIN)', async () => {
      productService.remove.mockResolvedValue(null as any);

      expect(await controller.remove(1)).toBeNull();
      expect(productService.remove).toHaveBeenCalledWith(1);
    });
  });
});
```

- [ ] **Step 2: 编写 Category 单元测试**

`packages/server/src/modules/product/category.controller.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { CategoryController } from './category.controller';
import { ProductService } from './product.service';

describe('CategoryController', () => {
  let controller: CategoryController;

  const mockProductService = {
    findAllCategories: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CategoryController],
      providers: [{ provide: ProductService, useValue: mockProductService }],
    }).compile();

    controller = module.get<CategoryController>(CategoryController);
    jest.clearAllMocks();
  });

  describe('GET /categories', () => {
    it('should return all categories', async () => {
      const categories = [
        { id: 1, name: '热带水果', icon: '🥭', sortOrder: 1 },
        { id: 2, name: '苹果', icon: '🍎', sortOrder: 2 },
      ];
      mockProductService.findAllCategories.mockResolvedValue(categories as any);

      expect(await controller.findAll()).toEqual(categories);
    });
  });
});
```

- [ ] **Step 3: 运行测试**

```bash
pnpm --filter server test:unit -- --testPathPattern=product
```

预期：7 tests passed（product 5 + category 1，注意 category 文件名中也有 product 路径）。

- [ ] **Step 4: Commit**

```bash
git add packages/server/src/modules/product/product.controller.spec.ts packages/server/src/modules/product/category.controller.spec.ts
git commit -m "test(server): product and category controller unit tests"
```

---

## Task 8: Cart 模块单元测试

**Files:**

- Create: `packages/server/src/modules/cart/cart.controller.spec.ts`

- [ ] **Step 1: 编写 Cart 单元测试**

`packages/server/src/modules/cart/cart.controller.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { CartController } from './cart.controller';
import { CartService } from './cart.service';

describe('CartController', () => {
  let controller: CartController;
  let cartService: jest.Mocked<CartService>;

  const mockCartService = {
    findAll: jest.fn(),
    add: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CartController],
      providers: [{ provide: CartService, useValue: mockCartService }],
    }).compile();

    controller = module.get<CartController>(CartController);
    cartService = module.get(CartService) as jest.Mocked<CartService>;
    jest.clearAllMocks();
  });

  describe('GET /cart', () => {
    it('should return cart items for user', async () => {
      const items = [{ id: 1, productId: 1, quantity: 2 }];
      cartService.findAll.mockResolvedValue(items as any);

      expect(await controller.findAll(1)).toEqual(items);
      expect(cartService.findAll).toHaveBeenCalledWith(1);
    });
  });

  describe('POST /cart', () => {
    it('should add item to cart', async () => {
      const dto = { productId: 1, specLabel: '500g', quantity: 1 };
      const items = [{ id: 1, ...dto }];
      cartService.add.mockResolvedValue(items as any);

      expect(await controller.add(1, dto)).toEqual(items);
      expect(cartService.add).toHaveBeenCalledWith(1, dto);
    });
  });

  describe('PUT /cart/:id', () => {
    it('should update cart item quantity', async () => {
      const dto = { quantity: 3 };
      const items = [{ id: 1, quantity: 3 }];
      cartService.update.mockResolvedValue(items as any);

      expect(await controller.update(1, 1, dto)).toEqual(items);
      expect(cartService.update).toHaveBeenCalledWith(1, 1, dto);
    });
  });

  describe('DELETE /cart/:id', () => {
    it('should remove cart item', async () => {
      const items: any[] = [];
      cartService.remove.mockResolvedValue(items as any);

      expect(await controller.remove(1, 1)).toEqual(items);
      expect(cartService.remove).toHaveBeenCalledWith(1, 1);
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- --testPathPattern=cart.controller.spec
```

预期：4 tests passed。

- [ ] **Step 3: Commit**

```bash
git add packages/server/src/modules/cart/cart.controller.spec.ts
git commit -m "test(server): cart controller unit tests"
```

---

## Task 9: Order 模块单元测试

**Files:**

- Create: `packages/server/src/modules/order/order.controller.spec.ts`

- [ ] **Step 1: 编写 Order 单元测试**

`packages/server/src/modules/order/order.controller.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { OrderController } from './order.controller';
import { OrderService } from './order.service';

describe('OrderController', () => {
  let controller: OrderController;
  let orderService: jest.Mocked<OrderService>;

  const mockOrderService = {
    create: jest.fn(),
    findAll: jest.fn(),
    findOne: jest.fn(),
    cancel: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [OrderController],
      providers: [{ provide: OrderService, useValue: mockOrderService }],
    }).compile();

    controller = module.get<OrderController>(OrderController);
    orderService = module.get(OrderService) as jest.Mocked<OrderService>;
    jest.clearAllMocks();
  });

  describe('POST /orders', () => {
    it('should create an order', async () => {
      const dto = { address: '北京市朝阳区', phone: '13800000001' };
      const order = { id: 1, orderNo: '20260618001', status: 0 };
      orderService.create.mockResolvedValue(order as any);

      expect(await controller.create(1, dto)).toEqual(order);
      expect(orderService.create).toHaveBeenCalledWith(1, dto);
    });
  });

  describe('GET /orders', () => {
    it('should return paginated orders', async () => {
      const result = { list: [], total: 0, page: 1, limit: 10 };
      orderService.findAll.mockResolvedValue(result as any);

      expect(await controller.findAll(1, { page: 1, limit: 10 })).toEqual(result);
    });
  });

  describe('GET /orders/:id', () => {
    it('should return order details', async () => {
      const order = { id: 1, orderNo: '20260618001', items: [] };
      orderService.findOne.mockResolvedValue(order as any);

      expect(await controller.findOne(1, 1)).toEqual(order);
      expect(orderService.findOne).toHaveBeenCalledWith(1, 1);
    });
  });

  describe('PUT /orders/:id/cancel', () => {
    it('should cancel an order', async () => {
      const order = { id: 1, status: 3 };
      orderService.cancel.mockResolvedValue(order as any);

      expect(await controller.cancel(1, 1)).toEqual(order);
      expect(orderService.cancel).toHaveBeenCalledWith(1, 1);
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:unit -- --testPathPattern=order.controller.spec
```

预期：4 tests passed。

- [ ] **Step 3: 运行全部单元测试确认通过**

```bash
pnpm --filter server test:unit
```

预期：21 tests passed（auth 4 + user 2 + product 5 + category 1 + cart 4 + order 4 + health 0）。

- [ ] **Step 4: Commit**

```bash
git add packages/server/src/modules/order/order.controller.spec.ts
git commit -m "test(server): order controller unit tests"
```

---

## Task 10: 集成测试基础设施

**Files:**

- Create: `packages/server/test/helpers/test-helper.ts`

- [ ] **Step 1: 创建 TestHelper**

`packages/server/test/helpers/test-helper.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { AppModule } from '../../src/app.module';
import { TransformInterceptor } from '../../src/common/interceptors/transform.interceptor';
import { HttpExceptionFilter } from '../../src/common/filters/http-exception.filter';
import { DataSource } from 'typeorm';
import request from 'supertest';
import { Server } from 'http';

export class TestHelper {
  app: INestApplication;
  httpServer: Server;

  async setup() {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    this.app = moduleFixture.createNestApplication();
    this.app.setGlobalPrefix('api');
    this.app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    // 与 main.ts 保持一致：通过 DI 获取 interceptor/filter，确保 Reflector/PinoLogger 正确注入
    this.app.useGlobalInterceptors(this.app.get(TransformInterceptor));
    this.app.useGlobalFilters(this.app.get(HttpExceptionFilter));

    await this.app.init();
    this.httpServer = this.app.getHttpServer();
  }

  async teardown() {
    if (this.app) {
      await this.app.close();
    }
  }

  /**
   * 清空 e2e 测试相关表，避免跨 run 数据污染（手机号已注册等）。
   * 不清 categories / products：这些是种子数据，且 e2e 依赖其存在。
   */
  async cleanDatabase() {
    const dataSource = this.app.get(DataSource);
    await dataSource.query('SET FOREIGN_KEY_CHECKS = 0');
    await dataSource.query('TRUNCATE TABLE order_items');
    await dataSource.query('TRUNCATE TABLE orders');
    await dataSource.query('TRUNCATE TABLE carts');
    await dataSource.query('TRUNCATE TABLE users');
    await dataSource.query('SET FOREIGN_KEY_CHECKS = 1');
  }

  /**
   * 注册用户并返回 auth tokens
   */
  async registerAndLogin(
    phone = '13800000001',
    password = 'test123456',
    nickname?: string,
  ): Promise<{ accessToken: string; refreshToken: string; userId: number }> {
    const body: any = { phone, password };
    if (nickname) body.nickname = nickname;

    const res = await request(this.httpServer).post('/api/auth/register').send(body);

    // 响应被 TransformInterceptor 包装: { code: 0, data: { accessToken, refreshToken, user } }
    // 防御性解析：注册失败时 data 可能为 undefined
    const data = res.body?.data ?? {};
    const { accessToken, refreshToken, user } = data;
    return { accessToken, refreshToken, userId: user?.id };
  }

  /**
   * 以 ADMIN 身份注册并登录（第一个注册的用户自动成为 ADMIN）
   */
  async registerAdmin(phone = '13900000001', password = 'admin123456') {
    return this.registerAndLogin(phone, password, 'Admin');
  }
}
```

- [ ] **Step 2: 确认 shared 已构建，运行空测试验证基础设施**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm --filter shared build
# 创建一个临时空测试文件来验证配置
echo "test('placeholder', () => expect(true).toBe(true));" > /tmp/placeholder.e2e-spec.ts
cp /tmp/placeholder.e2e-spec.ts packages/server/test/placeholder.e2e-spec.ts
pnpm --filter server test:e2e -- --testPathPattern=placeholder
rm packages/server/test/placeholder.e2e-spec.ts
```

预期：1 test passed（验证 Jest e2e 配置、ts-jest、module aliases 都正确）。

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/helpers/test-helper.ts
git commit -m "test(server): add e2e test helper with app bootstrap and auth utilities"
```

---

## Task 11: Auth 集成测试

**Files:**

- Create: `packages/server/test/auth.e2e-spec.ts`

- [ ] **Step 1: 编写 Auth 集成测试**

`packages/server/test/auth.e2e-spec.ts`:

```typescript
import request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Auth (e2e)', () => {
  const helper = new TestHelper();

  beforeAll(async () => {
    await helper.setup();
    await helper.cleanDatabase();
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('POST /api/auth/register', () => {
    it('should register a new user', () => {
      return request(helper.httpServer)
        .post('/api/auth/register')
        .send({ phone: '13800000001', password: 'test123456' })
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.accessToken).toBeDefined();
          expect(res.body.data.refreshToken).toBeDefined();
          expect(res.body.data.user.phone).toBe('13800000001');
        });
    });

    it('should reject duplicate phone', () => {
      return request(helper.httpServer)
        .post('/api/auth/register')
        .send({ phone: '13800000001', password: 'test123456' })
        .expect(200)
        .expect((res) => {
          // ConflictException(status 409) 经 HttpExceptionFilter 透传 status 作为 code
          expect(res.body.code).toBe(409);
          expect(res.body.message).toContain('已注册');
        });
    });

    it('should reject invalid phone format', () => {
      return request(helper.httpServer)
        .post('/api/auth/register')
        .send({ phone: '123', password: 'test123456' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(400); // ValidationPipe Bad Request
        });
    });

    it('should reject short password', () => {
      return request(helper.httpServer)
        .post('/api/auth/register')
        .send({ phone: '13800000002', password: '123' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(400);
        });
    });
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', () => {
      return request(helper.httpServer)
        .post('/api/auth/login')
        .send({ phone: '13800000001', password: 'test123456' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.accessToken).toBeDefined();
        });
    });

    it('should reject wrong password', () => {
      return request(helper.httpServer)
        .post('/api/auth/login')
        .send({ phone: '13800000001', password: 'wrongpassword' })
        .expect(200)
        .expect((res) => {
          // UnauthorizedException(status 401) 经 HttpExceptionFilter 透传 status 作为 code
          expect(res.body.code).toBe(401);
        });
    });
  });

  describe('POST /api/auth/refresh', () => {
    let refreshToken: string;

    beforeAll(async () => {
      const tokens = await helper.registerAndLogin('13800000003', 'test123456');
      refreshToken = tokens.refreshToken;
    });

    it('should refresh access token', () => {
      return request(helper.httpServer)
        .post('/api/auth/refresh')
        .send({ refreshToken })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.accessToken).toBeDefined();
        });
    });

    it('should reject invalid refresh token', () => {
      return request(helper.httpServer)
        .post('/api/auth/refresh')
        .send({ refreshToken: 'invalid-token' })
        .expect(200)
        .expect((res) => {
          // UnauthorizedException(status 401) 经 HttpExceptionFilter 透传 status 作为 code
          expect(res.body.code).toBe(401);
        });
    });
  });

  describe('POST /api/auth/logout', () => {
    let accessToken: string;

    beforeAll(async () => {
      const tokens = await helper.registerAndLogin('13800000004', 'test123456');
      accessToken = tokens.accessToken;
    });

    it('should logout successfully', () => {
      return request(helper.httpServer)
        .post('/api/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
        });
    });

    it('should reject request without token', () => {
      return request(helper.httpServer)
        .post('/api/auth/logout')
        .expect(200)
        .expect((res) => {
          // JwtAuthGuard 抛出 UnauthorizedException(status 401) → code 401
          expect(res.body.code).toBe(401);
        });
    });
  });
});
```

**注意（错误码语义）**：本仓库的 `HttpExceptionFilter` 对所有错误返回 HTTP 200，业务码放在 body 的 `code` 字段。当异常是 NestJS 内置异常（如 `UnauthorizedException`、`ConflictException`）且 message 为字符串时（不含 `code` 属性），filter 会使用 HTTP status 作为 `code`：所以 `UnauthorizedException(401)` → `code: 401`、`ConflictException(409)` → `code: 409`、`ValidationPipe(400)` → `code: 400`。

**DB 隔离**：TestHelper 提供 `cleanDatabase()` 方法（见 Task 10），在 `beforeAll` 中调用以清空 `users`/`carts`/`orders`/`order_items` 表，避免跨 run 的数据污染（如手机号已注册）。

- [ ] **Step 2: 确保 Docker 服务运行并运行测试**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
docker compose up -d mysql redis
sleep 5
pnpm --filter server test:e2e -- --testPathPattern=auth.e2e-spec
```

预期：所有测试通过。注意：集成测试需要 MySQL 和 Redis 运行中。

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/auth.e2e-spec.ts
git commit -m "test(server): auth module e2e integration tests"
```

---

## Task 12: User 集成测试

**Files:**

- Create: `packages/server/test/user.e2e-spec.ts`

- [ ] **Step 1: 编写 User 集成测试**

`packages/server/test/user.e2e-spec.ts`:

```typescript
import * as request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('User (e2e)', () => {
  const helper = new TestHelper();
  let accessToken: string;

  beforeAll(async () => {
    await helper.setup();
    const tokens = await helper.registerAndLogin('13800000010', 'test123456', 'TestUser');
    accessToken = tokens.accessToken;
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('GET /api/user/profile', () => {
    it('should return user profile', () => {
      return request(helper.httpServer)
        .get('/api/user/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.phone).toBe('13800000010');
          expect(res.body.data.nickname).toBe('TestUser');
        });
    });

    it('should reject unauthenticated request', () => {
      return request(helper.httpServer)
        .get('/api/user/profile')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40005);
        });
    });
  });

  describe('PUT /api/user/profile', () => {
    it('should update nickname', () => {
      return request(helper.httpServer)
        .put('/api/user/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ nickname: 'UpdatedName' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.nickname).toBe('UpdatedName');
        });
    });

    it('should update avatar', () => {
      return request(helper.httpServer)
        .put('/api/user/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ avatar: 'https://example.com/avatar.jpg' })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.avatar).toBe('https://example.com/avatar.jpg');
        });
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:e2e -- --testPathPattern=user.e2e-spec
```

预期：4 tests passed。

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/user.e2e-spec.ts
git commit -m "test(server): user module e2e integration tests"
```

---

## Task 13: Product + Category 集成测试

**Files:**

- Create: `packages/server/test/product.e2e-spec.ts`

- [ ] **Step 1: 编写 Product + Category 集成测试**

`packages/server/test/product.e2e-spec.ts`:

```typescript
import * as request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Product & Category (e2e)', () => {
  const helper = new TestHelper();
  let adminToken: string;
  let userToken: string;
  let createdProductId: number;

  beforeAll(async () => {
    await helper.setup();

    // 第一个注册的用户自动获得 ADMIN 角色
    const admin = await helper.registerAdmin('13900000001', 'admin123456');
    adminToken = admin.accessToken;

    const user = await helper.registerAndLogin('13800000020', 'test123456');
    userToken = user.accessToken;
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('POST /api/products', () => {
    const validProduct = {
      name: '测试苹果',
      origin: '山东',
      price: 9.9,
      unit: '斤',
      sweetness: '甜',
      weight: '500g',
      image: 'http://example.com/apple.jpg',
      color: '#FF0000',
      categoryId: 1,
      stock: 100,
    };

    it('should create product as ADMIN', () => {
      return request(helper.httpServer)
        .post('/api/products')
        .set('Authorization', `Bearer ${adminToken}`)
        .send(validProduct)
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.name).toBe('测试苹果');
          createdProductId = res.body.data.id;
        });
    });

    it('should reject non-ADMIN user', () => {
      return request(helper.httpServer)
        .post('/api/products')
        .set('Authorization', `Bearer ${userToken}`)
        .send(validProduct)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40006); // FORBIDDEN
        });
    });

    it('should reject unauthenticated request', () => {
      return request(helper.httpServer)
        .post('/api/products')
        .send(validProduct)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40005);
        });
    });
  });

  describe('GET /api/products', () => {
    it('should return product list (public)', () => {
      return request(helper.httpServer)
        .get('/api/products')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.list).toBeInstanceOf(Array);
          expect(res.body.data.total).toBeGreaterThanOrEqual(1);
        });
    });

    it('should filter by keyword', () => {
      return request(helper.httpServer)
        .get('/api/products?keyword=苹果')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.list.length).toBeGreaterThanOrEqual(1);
        });
    });
  });

  describe('GET /api/products/:id', () => {
    it('should return product detail', () => {
      return request(helper.httpServer)
        .get(`/api/products/${createdProductId}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.name).toBe('测试苹果');
        });
    });

    it('should return 404 for non-existent product', () => {
      return request(helper.httpServer)
        .get('/api/products/99999')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40201); // PRODUCT_NOT_FOUND
        });
    });
  });

  describe('PUT /api/products/:id', () => {
    it('should update product as ADMIN', () => {
      return request(helper.httpServer)
        .put(`/api/products/${createdProductId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ price: 12.9 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.price).toBe('12.90');
        });
    });
  });

  describe('GET /api/categories', () => {
    it('should return all categories (public)', () => {
      return request(helper.httpServer)
        .get('/api/categories')
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data).toBeInstanceOf(Array);
        });
    });
  });

  describe('DELETE /api/products/:id', () => {
    it('should delete product as ADMIN', () => {
      return request(helper.httpServer)
        .delete(`/api/products/${createdProductId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
        });
    });

    it('should return 404 after deletion', () => {
      return request(helper.httpServer)
        .get(`/api/products/${createdProductId}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40201);
        });
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:e2e -- --testPathPattern=product.e2e-spec
```

预期：所有测试通过。

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/product.e2e-spec.ts
git commit -m "test(server): product and category e2e integration tests"
```

---

## Task 14: Cart 集成测试

**Files:**

- Create: `packages/server/test/cart.e2e-spec.ts`

- [ ] **Step 1: 编写 Cart 集成测试**

`packages/server/test/cart.e2e-spec.ts`:

```typescript
import * as request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Cart (e2e)', () => {
  const helper = new TestHelper();
  let userToken: string;
  let adminToken: string;
  let productId: number;

  beforeAll(async () => {
    await helper.setup();

    const admin = await helper.registerAdmin('13900000002', 'admin123456');
    adminToken = admin.accessToken;

    const user = await helper.registerAndLogin('13800000030', 'test123456');
    userToken = user.accessToken;

    // 创建一个测试商品
    const productRes = await request(helper.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: '购物车测试商品',
        origin: '测试产地',
        price: 19.9,
        unit: '斤',
        sweetness: '甜',
        weight: '500g',
        image: 'http://example.com/test.jpg',
        color: '#FF0000',
        categoryId: 1,
        stock: 50,
      });
    productId = productRes.body.data.id;
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('POST /api/cart', () => {
    it('should add item to cart', () => {
      return request(helper.httpServer)
        .post('/api/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ productId, specLabel: '500g', quantity: 2 })
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data).toBeInstanceOf(Array);
          expect(res.body.data.length).toBe(1);
          expect(res.body.data[0].quantity).toBe(2);
        });
    });

    it('should merge quantity for duplicate item', () => {
      return request(helper.httpServer)
        .post('/api/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ productId, specLabel: '500g', quantity: 3 })
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data[0].quantity).toBe(5); // 2 + 3
        });
    });

    it('should reject unauthenticated request', () => {
      return request(helper.httpServer)
        .post('/api/cart')
        .send({ productId, specLabel: '500g', quantity: 1 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40005);
        });
    });
  });

  describe('GET /api/cart', () => {
    it('should return cart items', () => {
      return request(helper.httpServer)
        .get('/api/cart')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data).toBeInstanceOf(Array);
          expect(res.body.data.length).toBe(1);
        });
    });
  });

  describe('PUT /api/cart/:id', () => {
    let cartItemId: number;

    beforeAll(async () => {
      const res = await request(helper.httpServer)
        .get('/api/cart')
        .set('Authorization', `Bearer ${userToken}`);
      cartItemId = res.body.data[0].id;
    });

    it('should update cart item quantity', () => {
      return request(helper.httpServer)
        .put(`/api/cart/${cartItemId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ quantity: 10 })
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.find((i: any) => i.id === cartItemId).quantity).toBe(10);
        });
    });
  });

  describe('DELETE /api/cart/:id', () => {
    let cartItemId: number;

    beforeAll(async () => {
      const res = await request(helper.httpServer)
        .get('/api/cart')
        .set('Authorization', `Bearer ${userToken}`);
      cartItemId = res.body.data[0].id;
    });

    it('should remove cart item', () => {
      return request(helper.httpServer)
        .delete(`/api/cart/${cartItemId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.length).toBe(0);
        });
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:e2e -- --testPathPattern=cart.e2e-spec
```

预期：所有测试通过。

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/cart.e2e-spec.ts
git commit -m "test(server): cart module e2e integration tests"
```

---

## Task 15: Order 集成测试

**Files:**

- Create: `packages/server/test/order.e2e-spec.ts`

- [ ] **Step 1: 编写 Order 集成测试**

`packages/server/test/order.e2e-spec.ts`:

```typescript
import * as request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Order (e2e)', () => {
  const helper = new TestHelper();
  let userToken: string;
  let adminToken: string;
  let orderId: number;

  beforeAll(async () => {
    await helper.setup();

    const admin = await helper.registerAdmin('13900000003', 'admin123456');
    adminToken = admin.accessToken;

    const user = await helper.registerAndLogin('13800000040', 'test123456');
    userToken = user.accessToken;

    // 创建商品
    const productRes = await request(helper.httpServer)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: '订单测试商品',
        origin: '测试产地',
        price: 29.9,
        unit: '斤',
        sweetness: '甜',
        weight: '1kg',
        image: 'http://example.com/test.jpg',
        color: '#FF0000',
        categoryId: 1,
        stock: 100,
      });
    const pId = productRes.body.data.id;

    // 添加到购物车
    await request(helper.httpServer)
      .post('/api/cart')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ productId: pId, specLabel: '1kg', quantity: 2 });
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('POST /api/orders', () => {
    it('should create order from cart', () => {
      return request(helper.httpServer)
        .post('/api/orders')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ address: '北京市朝阳区', phone: '13800000040' })
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.orderNo).toBeDefined();
          expect(res.body.data.items.length).toBe(1);
          orderId = res.body.data.id;
        });
    });

    it('should reject order with empty cart', () => {
      return request(helper.httpServer)
        .post('/api/orders')
        .set('Authorization', `Bearer ${userToken}`)
        .send({ address: '北京市朝阳区', phone: '13800000040' })
        .expect(201)
        .expect((res) => {
          expect(res.body.code).toBe(40303); // CART_EMPTY
        });
    });
  });

  describe('GET /api/orders', () => {
    it('should return user orders', () => {
      return request(helper.httpServer)
        .get('/api/orders')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.list.length).toBeGreaterThanOrEqual(1);
        });
    });
  });

  describe('GET /api/orders/:id', () => {
    it('should return order detail with items', () => {
      return request(helper.httpServer)
        .get(`/api/orders/${orderId}`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.items).toBeInstanceOf(Array);
          expect(res.body.data.items.length).toBe(1);
        });
    });

    it('should return 404 for non-existent order', () => {
      return request(helper.httpServer)
        .get('/api/orders/99999')
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40401); // ORDER_NOT_FOUND
        });
    });
  });

  describe('PUT /api/orders/:id/cancel', () => {
    it('should cancel a pending order', () => {
      return request(helper.httpServer)
        .put(`/api/orders/${orderId}/cancel`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(0);
          expect(res.body.data.status).toBe(3); // CANCELLED
        });
    });

    it('should reject cancelling already cancelled order', () => {
      return request(helper.httpServer)
        .put(`/api/orders/${orderId}/cancel`)
        .set('Authorization', `Bearer ${userToken}`)
        .expect(200)
        .expect((res) => {
          expect(res.body.code).toBe(40403); // ORDER_CANCEL_NOT_ALLOWED
        });
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:e2e -- --testPathPattern=order.e2e-spec
```

预期：所有测试通过。

- [ ] **Step 3: Commit**

```bash
git add packages/server/test/order.e2e-spec.ts
git commit -m "test(server): order module e2e integration tests"
```

---

## Task 16: Health 集成测试

**Files:**

- Create: `packages/server/test/health.e2e-spec.ts`

- [ ] **Step 1: 编写 Health 集成测试**

`packages/server/test/health.e2e-spec.ts`:

```typescript
import * as request from 'supertest';
import { TestHelper } from './helpers/test-helper';

describe('Health (e2e)', () => {
  const helper = new TestHelper();

  beforeAll(async () => {
    await helper.setup();
  });

  afterAll(async () => {
    await helper.teardown();
  });

  describe('GET /api/health', () => {
    it('should return health status without auth', () => {
      return request(helper.httpServer)
        .get('/api/health')
        .expect(200)
        .expect((res) => {
          expect(res.body.status).toBe('ok');
          expect(res.body.details.database.status).toBe('up');
          expect(res.body.details.redis.status).toBe('up');
        });
    });

    it('should not be wrapped by TransformInterceptor', () => {
      return request(helper.httpServer)
        .get('/api/health')
        .expect(200)
        .expect((res) => {
          // terminus 响应不应有 code/data/message 包装
          expect(res.body.code).toBeUndefined();
          expect(res.body.data).toBeUndefined();
        });
    });
  });
});
```

- [ ] **Step 2: 运行测试**

```bash
pnpm --filter server test:e2e -- --testPathPattern=health.e2e-spec
```

预期：2 tests passed。如果 health 响应被 TransformInterceptor 包装了（出现 `code` 字段），需要在 TransformInterceptor 中排除 health 端点。

- [ ] **Step 3: 如果 TransformInterceptor 包装了 health 响应**

在 `packages/server/src/common/interceptors/transform.interceptor.ts` 中添加排除逻辑：

```typescript
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { SUCCESS_CODE } from 'shared';

export class TransformInterceptor<T> implements NestInterceptor<T, any> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const ctx = context.switchToHttp();
    const request = ctx.getRequest();

    // health 端点由 terminus 直接处理，不包装
    if (request.url === '/api/health') {
      return next.handle();
    }

    return next.handle().pipe(
      map((data) => ({
        code: SUCCESS_CODE,
        data,
        message: 'success',
      })),
    );
  }
}
```

重新运行 health 测试验证修复。

- [ ] **Step 4: Commit**

```bash
git add packages/server/test/health.e2e-spec.ts
# 如果修改了 transform interceptor：
git add packages/server/src/common/interceptors/transform.interceptor.ts
git commit -m "test(server): health endpoint e2e integration tests"
```

---

## Task 17: 运行全部测试 + 限流集成测试

**Files:**

- 无新文件（验证所有测试通过）

- [ ] **Step 1: 运行全部单元测试**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm --filter server test:unit
```

预期：21 tests passed。

- [ ] **Step 2: 运行全部集成测试**

```bash
pnpm --filter server test:e2e
```

预期：所有 e2e 测试通过。

- [ ] **Step 3: 运行覆盖率报告**

```bash
pnpm --filter server test:cov
```

预期：controller 文件覆盖率 > 90%。

- [ ] **Step 4: 补充限流行为集成测试**

在 `packages/server/test/auth.e2e-spec.ts` 末尾添加限流测试：

```typescript
describe('Rate limiting', () => {
  it('should rate-limit login after 10 requests per minute', async () => {
    const requests = [];
    for (let i = 0; i < 11; i++) {
      requests.push(
        request(helper.httpServer)
          .post('/api/auth/login')
          .send({ phone: '13800000099', password: 'wrong' }),
      );
    }
    const responses = await Promise.all(requests);
    const rateLimited = responses.filter((r) => r.status === 429);
    expect(rateLimited.length).toBeGreaterThanOrEqual(1);
    expect(rateLimited[0].body.code).toBe(429);
  });
});
```

重新运行 auth e2e 测试验证限流生效。

- [ ] **Step 5: Final Commit**

```bash
git add packages/server/test/auth.e2e-spec.ts
git commit -m "test(server): add rate limiting e2e test for auth endpoints"
```

---

## Self-Review Checklist

### Spec 覆盖

| Spec 要求                   | Task    |
| --------------------------- | ------- |
| Swagger /api/docs           | Task 2  |
| SWAGGER_ENABLED 环境变量    | Task 2  |
| ThrottlerModule 全局 60/min | Task 3  |
| auth login/register 10/min  | Task 3  |
| ThrottlerException 处理     | Task 3  |
| HealthModule + /health      | Task 4  |
| Redis health check          | Task 4  |
| DB health check             | Task 4  |
| Jest 配置 (unit + e2e)      | Task 1  |
| .env.test                   | Task 1  |
| TestHelper                  | Task 10 |
| Auth unit test              | Task 5  |
| User unit test              | Task 6  |
| Product unit test           | Task 7  |
| Category unit test          | Task 7  |
| Cart unit test              | Task 8  |
| Order unit test             | Task 9  |
| Auth e2e                    | Task 11 |
| User e2e                    | Task 12 |
| Product + Category e2e      | Task 13 |
| Cart e2e                    | Task 14 |
| Order e2e                   | Task 15 |
| Health e2e                  | Task 16 |
| Rate limiting e2e           | Task 17 |
| .env.example 更新           | Task 2  |

### 无占位符

所有步骤包含完整代码块、精确文件路径、可执行命令。

### 类型一致性

- 所有 mock 使用 `jest.Mocked<Service>` 类型
- 所有 e2e 测试使用 `TestHelper` 统一 app 创建
- 端点路径与实际 controller 完全匹配（`/api/auth`, `/api/user`, `/api/products`, `/api/categories`, `/api/cart`, `/api/orders`, `/api/health`）
