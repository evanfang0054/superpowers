# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 包概述

鲜果集服务端 — NestJS 10 + TypeORM + MySQL + Redis。位于 monorepo 的 `packages/server`，依赖 `packages/shared`（类型/枚举/错误码）。

## 常用命令

```bash
# 开发（需先确保 shared 已构建）
pnpm --filter shared build            # 改了 shared 必须先执行，否则 server 拉到旧 dist
pnpm --filter server dev              # nest start --watch，http://localhost:3000
pnpm --filter server build            # nest build
pnpm --filter server start            # node dist/main.js（生产模式）

# 测试（jest，NODE_ENV=test 会自动加载 .env.test，库切到 fruit_shop_test + REDIS_DB=1）
pnpm --filter server test             # 全部单元测试（src/**/*.spec.ts）
pnpm --filter server test:unit        # 同上，显式 jest.config.ts
pnpm --filter server test:e2e         # e2e（test/**/*.e2e-spec.ts，--runInBand 串行）
pnpm --filter server test:cov         # 覆盖率，输出到 ../coverage
# 单文件
pnpm --filter server test -- path/to/file.spec.ts
pnpm --filter server test:e2e -- test/auth.e2e-spec.ts

# Docker 一键启动（含 MySQL/Redis/种子数据）
docker compose up -d                  # 从 monorepo 根目录执行
```

无 ESLint / Prettier。测试框架为 Jest 30 + ts-jest + supertest。

## 架构要点

### 入口与全局中间件

`src/main.ts` — 全局 API 前缀 `/api`，CORS 开启。pino 作为全局 logger（`app.useLogger(app.get(Logger))`，开启 `bufferLogs`）。注册顺序：

- 全局 `ValidationPipe`：whitelist + forbidNonWhitelisted + transform（隐式类型转换）
- 全局 `TransformInterceptor`：成功响应包装为 `{ code: 0, data, message: "success" }`
- 全局 `HttpExceptionFilter`：**所有错误也返回 HTTP 200**，业务码在 body 的 `code` 字段
- Swagger（`/api/docs`，可通过 `SWAGGER_ENABLED=false` 关闭）

`AppModule` 还通过 `APP_GUARD` 注册了全局 `ThrottlerGuard`（默认 60s / 60 次限流）。因此 `@Public()` 之外的路由同时受 JWT、Roles、Throttler 三层守卫约束。

### 模块结构

6 个 feature module（`src/modules/`），每个遵循 `controller → service → dto`：

| 模块      | 路径               | 职责                                         |
| --------- | ------------------ | -------------------------------------------- |
| `auth`    | `modules/auth/`    | 注册/登录/刷新 Token/登出，JWT 双 token 机制 |
| `user`    | `modules/user/`    | 用户信息查询/更新                            |
| `product` | `modules/product/` | 商品 CRUD + 分类管理（仅 ADMIN）             |
| `cart`    | `modules/cart/`    | 购物车增删改查                               |
| `order`   | `modules/order/`   | 下单（事务）、订单查询/取消                  |
| `health`  | `modules/health/`  | `/api/health` 健康检查（@Public）            |

### 认证机制

- `JwtAuthGuard`（全局默认）：所有接口需 JWT，`@Public()` 装饰器放行
- `RolesGuard` + `@Roles(UserRole.ADMIN)`：管理员权限控制
- `@CurrentUser()`：从 request 中提取当前用户
- Redis 仅用于 JWT 退出黑名单（`token:blacklist:{jti}`），由全局 `RedisProviderModule` 提供
- 首个注册用户自动获得 ADMIN 角色

### 数据层

6 个 TypeORM entity 在 `src/entities/`：User、Product、Category、Cart、Order、OrderItem。`synchronize: true`（开发自动同步表结构），timezone `+08:00`，charset `utf8mb4`。

下单走 TypeORM transaction（`DataSource.createQueryRunner()`），成功后清空该用户购物车。

### 日志（pino）

`src/common/logging/`：`LoggingModule` 全局注册 `nestjs-pino`，`pino.config.ts` 读 `LOG_LEVEL`，`redact.serializer.ts` 脱敏敏感字段。**改日志相关行为先看这里** —— pino-http v11 的 `customErrorMessage` 第 4 个参数是 `responseTime`（不是 err），默认不回写 `X-Request-ID`。

### 配置文件分层

- `ConfigModule.forRoot` 按环境加载不同 env：`NODE_ENV=test` 时优先 `.env.test` → `.env.local` → `.env`；否则 `.env.local` → `.env`。
- `src/config/database.config.ts`、`src/config/redis.config.ts`：DB/Redis 连接工厂。

### shared 依赖

通过 `tsconfig.json` paths 指向 `../shared/dist`（编译后的 CommonJS）；Jest `moduleNameMapper` 也指向同一份 `dist`。从 shared 导入 `ErrorCode`（40001–40499）、`ErrorMessage`、`UserRole`、`OrderStatus`、`SUCCESS_CODE` 等。**修改 shared 后必须重新 `pnpm --filter shared build`**，否则 server 运行时和测试都会拉到旧 dist。

## 测试基础设施

- 单元测试放 `src/**/xxx.spec.ts`（`jest.config.ts`，rootDir=`src`）。
- e2e 测试放 `test/*.e2e-spec.ts`（`test/jest-e2e.config.ts`，`--runInBand` 串行执行避免并发污染）。
- **e2e 依赖真实 MySQL + Redis**：`.env.test` 指向独立库 `fruit_shop_test` 和 `REDIS_DB=1`。运行前需确保两者已启动。
- 通用助手 `test/helpers/test-helper.ts`：
  - `TestHelper.setup()` 复刻 `main.ts` 的全局管道/拦截器/过滤器（通过 DI 获取，保证 Reflector/PinoLogger 注入正确）。
  - `cleanDatabase()` 仅 `TRUNCATE` `users / carts / orders / order_items`，**不清 categories / products**（e2e 依赖种子数据）。
  - `registerAndLogin(phone, password, nickname?)` 返回 `{ accessToken, refreshToken, userId }`；失败会显式抛错。
  - `registerAdmin(...)`：第一个注册用户自动 ADMIN。
- 改路由或响应格式时，注意 `registerAndLogin` 依赖 `{ code:0, data:{ user, accessToken, refreshToken } }` 的形状。

## 环境变量

参考 `.env.example`：

- DB：`DB_HOST / DB_PORT / DB_USERNAME / DB_PASSWORD / DB_DATABASE / DB_LOGGING`
- Redis：`REDIS_HOST / REDIS_PORT / REDIS_DB`（测试用 1）
- JWT：`JWT_SECRET / JWT_ACCESS_EXPIRES_IN`（默认 900s）/ `JWT_REFRESH_EXPIRES_IN`（默认 604800s）
- `PORT`（默认 3000）、`LOG_LEVEL`（默认 info）、`SWAGGER_ENABLED`（默认 true）
