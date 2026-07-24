# 后端测试全量补齐设计

- 日期：2026-06-19
- 范围：`packages/server`（NestJS 服务端）单测 + e2e
- 目标：将后端服务测试覆盖率补齐到「service 单测 + common 单测 + e2e 异常/权限/校验路径」全量覆盖

## 背景与现状

当前 `packages/server` 已有 6 个 controller spec + 6 个 e2e 文件（共 1152 行）。缺口：

- **service 层零单测**：auth/user/product/cart/order 五个 service 的核心业务逻辑（首用户 admin、bcrypt 校验、Redis 缓存命中/穿透、事务回滚、订单金额计算等）全部裸奔。
- **common 层零单测**：guards（jwt-auth、roles）、filters（http-exception）、interceptors（transform）、jwt.strategy 均依赖 e2e 间接覆盖，无法隔离验证单分支（如 ThrottlerException → 429、class-validator 数组 message join、SKIP_TRANSFORM 透传）。
- **e2e 偏 happy path**：缺权限越权（USER 调 admin 接口、改他人购物车/订单）、登出黑名单、缓存命中、参数校验等关键安全与边界场景。

## 目标与成功标准

- **DoD**：
  - 新增 5 个 service spec、5 个 common spec、扩写 5 个 e2e 文件
  - `pnpm --filter server test:unit` 全绿（不依赖真实 DB）
  - `pnpm --filter server test:e2e` 全绿（依赖本地 docker compose 起的 MySQL+Redis）
  - 所有新增测试用例覆盖设计矩阵列出的分支
- **非目标**：
  - 不引入新依赖、不重构业务代码（除非测试暴露出明显 bug，另行沟通）
  - 不覆盖 health module（已是 `@Public` 极简实现，e2e 已覆盖）

## 文件结构

```
packages/server/
├── src/
│   ├── modules/auth/auth.service.spec.ts          [新]
│   ├── modules/auth/jwt.strategy.spec.ts          [新]
│   ├── modules/user/user.service.spec.ts          [新]
│   ├── modules/product/product.service.spec.ts    [新]
│   ├── modules/cart/cart.service.spec.ts          [新]
│   ├── modules/order/order.service.spec.ts        [新]
│   └── common/
│       ├── guards/jwt-auth.guard.spec.ts          [新]
│       ├── guards/roles.guard.spec.ts             [新]
│       ├── interceptors/transform.interceptor.spec.ts  [新]
│       └── filters/http-exception.filter.spec.ts  [新]
└── test/
    ├── auth.e2e-spec.ts          [扩：登出黑名单、token 类型错误]
    ├── product.e2e-spec.ts       [扩：非 admin 被拒、缓存、筛选]
    ├── cart.e2e-spec.ts          [扩：越权、商品不存在]
    ├── order.e2e-spec.ts         [扩：取消/查询他人订单、重复取消]
    ├── user.e2e-spec.ts          [扩：无 token、更新 profile]
    └── helpers/test-helper.ts    [扩：createProductAsAdmin / addToCartAsUser]
```

## 设计原则

1. **单测纯 mock**：所有 Repository / DataSource / Redis / PinoLogger / JwtService / ConfigService / bcryptjs / uuid 均 mock，测试不依赖真实 DB/Redis，可并行执行。
2. **e2e 真实链路**：复用 `TestHelper`，连真实 MySQL（`fruit_shop_test`）+ Redis（DB=1），验证端到端契约。
3. **断言风格一致**：遵循现有 e2e 模式 —— HTTP 200 + `res.body.code` 业务码断言（因 `HttpExceptionFilter` 把所有错误也走 HTTP 200，业务码在 body）。
4. **不重构业务代码**：测试只验证现有行为。若测试发现 bug，停下来与用户确认后再修。

## Service 单测覆盖矩阵

### auth.service.spec.ts（~14 用例）

| 方法       | 分支                                                                                                                                      |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `register` | 首用户 → role=ADMIN；非首用户 → role=USER；手机号已注册 → ConflictException(PHONE_EXISTS)；bcrypt.hash 以 salt 10 调用；返回不含 password |
| `login`    | 用户不存在 → UnauthorizedException(AUTH_FAILED)；密码错误 → UnauthorizedException；成功签发双 token；返回不含 password                    |
| `refresh`  | payload.type !== 'refresh' → 401；Redis 黑名单命中 → 401；用户不存在 → 401；jwt.verify 抛错（过期/签名错）→ 401；成功返回新 accessToken   |
| `logout`   | decode 成功 + ttl>0 → 写 Redis 黑名单 key 含 jti、EX=ttl；decode 返回 null → 静默不抛错；ttl<=0 → 不写；decode 抛错 → 静默                |

**Mock 策略**：`jest.mock('bcryptjs')`、`jest.mock('uuid')`；JwtService.verify/sign/decode 全 mock；ConfigService.get 返回 `'JWT_SECRET'`、`'900'`、`'604800'`；Redis mock `{ get, set }`；Repository mock `{ findOne, count, create, save }`。

### user.service.spec.ts（~4 用例）

| 方法            | 分支                                                     |
| --------------- | -------------------------------------------------------- |
| `getProfile`    | 用户不存在 → NotFoundException(USER_NOT_FOUND)；成功返回 |
| `updateProfile` | 用户不存在 → 404；成功 Object.assign + save              |

### product.service.spec.ts（~12 用例）

| 方法                | 分支                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------ |
| `findAll`           | 缓存命中 → 跳过 DB；缓存未命中 → 查 DB + 写缓存 EX 60；categoryId 筛选；keyword 筛选 |
| `findOne`           | 缓存命中；缓存未命中 → 404；成功 + 写缓存                                            |
| `create`            | 保存 + clearProductCache 调用                                                        |
| `update`            | 404；成功 + 清 product:{id} + products:*                                             |
| `remove`            | 404；成功 + 清缓存                                                                   |
| `findAllCategories` | 缓存命中；缓存未命中 → 写缓存 EX 300                                                 |

**Mock 策略**：Redis mock `{ get, set, keys, del }`，验证 set 调用参数（key 格式 + EX 秒数）；QueryBuilder mock 链（`andWhere/getCount/getMany/orderBy/skip/take`）。

### cart.service.spec.ts（~9 用例）

| 方法                        | 分支                                                                |
| --------------------------- | ------------------------------------------------------------------- |
| `add`                       | 商品不存在 → 404；已存在 → 合并数量；新建项；quantity 默认 1        |
| `update`                    | 不存在 → 404；成功更新 quantity                                     |
| `remove`                    | 不存在 → 404；成功 remove                                           |
| `removeByUserAndProductIds` | 空数组 → 直接 return；非空 → 执行 delete builder                    |
| `findAll`                   | product 为 null 时映射正确；字段裁剪（不含 description 等敏感字段） |

### order.service.spec.ts（~10 用例）

| 方法      | 分支                                                                                                                                                                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `create`  | 空购物车 → BadRequestException(CART_EMPTY)；金额计算（price × quantity 求和）；事务 commit 顺序（save order → save items → delete cart）；事务回滚（mock save 抛错 → rollbackTransaction 被调用 + 原错误重新抛出）；queryRunner.release 总被调用 |
| `findAll` | status 筛选；分页参数 page/limit                                                                                                                                                                                                                 |
| `findOne` | 不存在 → 404；成功返回 order + items                                                                                                                                                                                                             |
| `cancel`  | 不存在 → 404；非 PENDING → BadRequestException(ORDER_CANCEL_NOT_ALLOWED)；成功更新 status=CANCELLED                                                                                                                                              |

**Mock 策略**：`DataSource.createQueryRunner()` 返回 `{ connect: jest.fn(), startTransaction: jest.fn(), manager: { create, save, createQueryBuilder: () => ({ delete: () => ({ from: () => ({ where: () => ({ andWhere: () => ({ execute: jest.fn() }) }) }) }) }) }, commitTransaction: jest.fn(), rollbackTransaction: jest.fn(), release: jest.fn() }`。

## Common 层单测覆盖矩阵

### jwt-auth.guard.spec.ts（~5 用例）

- `@Public()` 装饰命中 → canActivate 返回 true（验证不调 super）
- 无 `@Public()` → 调用 super.canActivate
- handleRequest：err 非空 → 抛 err
- handleRequest：user 为空 → 抛 UnauthorizedException(UNAUTHORIZED)
- handleRequest：成功 → 返回 user

### roles.guard.spec.ts（~4 用例）

- 无 `@Roles()` → 返回 true
- 有 `@Roles()` + user 为 null → 返回 false
- 角色匹配 → true
- 角色不匹配 → 抛 ForbiddenException(FORBIDDEN)

### transform.interceptor.spec.ts（~3 用例）

- 无 SKIP_TRANSFORM → 包装 `{ code: 0, data, message: 'success' }`
- 有 SKIP_TRANSFORM → 原样透传
- reflector 为 undefined（@Optional 默认值）→ 正常包装

### http-exception.filter.spec.ts（~7 用例）

- HttpException + `{ code: number, message }` 业务异常 → 透传 code
- HttpException + `{ message: [] }`（class-validator）→ message.join('; ')
- HttpException + string response → 直接用
- HttpException + 普通 message → code = status
- ThrottlerException → HTTP 429 + code 429 + message 'Too Many Requests'
- ServiceUnavailableException + terminus body → HTTP 503 + 透传原 body
- 未知异常（普通 Error）→ HTTP 200 + code 500 + error 级别日志被调用

### jwt.strategy.spec.ts（~3 用例）

- payload.type !== 'access' → 抛 UnauthorizedException(TOKEN_INVALID)
- Redis 黑名单命中 → 抛 UnauthorizedException(TOKEN_EXPIRED)
- 正常 → 返回 `{ id, phone, role, jti }`

**Mock 策略**：guards/interceptor 用 `Test.createTestingModule` 注入 mock Reflector；filter 用 mock `ArgumentsHost`（getResponse/getRequest 返回可控对象）；strategy 直接 `new JwtStrategy(configMock, redisMock)` 调 `validate()`。

## e2e 补强用例

### auth.e2e-spec.ts（扩 3 用例）

- 登出后用旧 accessToken 访问 `/api/auth/profile` → 401（验证 Redis 黑名单在 JwtStrategy 中生效）
- refresh 接口用 accessToken（type='access'）→ 401
- 过期 refreshToken（手动构造非法 JWT）→ 401

### product.e2e-spec.ts（扩 6 用例）

- 普通 USER POST /products → 403
- 普通 USER PUT /products/:id → 403
- 普通 USER DELETE /products/:id → 403
- 无 token GET /products → 401（GET /products 是否 @Public 待确认，若非 @Public 则补此用例）
- categoryId 筛选 → 返回商品均属该分类
- keyword 搜索 → 返回商品 name 含关键词

### cart.e2e-spec.ts（扩 4 用例）

- 添加不存在商品 → 404
- 越权 PUT /cart/:id（B 用户的 cartId）→ 404
- 越权 DELETE /cart/:id（B 用户的 cartId）→ 404
- 无 token GET /cart → 401

### order.e2e-spec.ts（扩 4 用例）

- 取消他人订单 → 404（user 隔离）
- 查询他人订单详情 → 404
- 无 token POST /orders → 401
- 重复取消已取消订单 → 400（已有，确认覆盖）

### user.e2e-spec.ts（扩 3 用例）

- 无 token GET /profile → 401
- PUT /profile 更新昵称 → 成功返回更新后数据
- 越权校验：A 的 token 不会串到 B 的 profile（基于 userId，验证 query 不串号）

## TestHelper 扩展

```ts
// 新增助手方法，减少 e2e 重复 boilerplate
async createProductAsAdmin(
  token: string,
  overrides: Partial<{ name; price; categoryId; stock; ... }> = {}
): Promise<number>   // 返回新商品 id

async addToCartAsUser(
  token: string,
  productId: number,
  specLabel: string,
  quantity: number
): Promise<void>
```

## 自测执行流程

1. `docker compose up -d mysql redis`（仅起依赖服务）
2. 确认 `.env.test` 指向 `fruit_shop_test` + `REDIS_DB=1`
3. `pnpm --filter shared build`（保证 shared dist 最新）
4. `pnpm --filter server test:unit`（单测，无需 DB）
5. `pnpm --filter server test:e2e`（e2e，需 DB，`--runInBand`）
6. 把两份输出贴给用户；若失败，定位并修复（仅测试代码层修复，不改正业务代码除非确认是 bug）

## 风险与注意事项

- **order.service 事务 mock 复杂**：mock queryRunner 链较长，需保证 release 在 try/finally 中被调用的断言。建议用 `expect(queryRunner.release).toHaveBeenCalled()`。
- **product.service Redis 缓存 key 格式**：`products:all:all:1:10` / `product:{id}` / `categories:all`，断言 set 调用参数需精确匹配。
- **e2e 限流污染**：现有 auth.e2e 的 Rate limiting 测试会消耗进程内 Throttler 配额，新增 auth e2e 用例需放在该测试之前，或使用独立手机号避免连锁失败。
- **shared dist 时效**：每轮自测前必须重 build shared，否则 server 拉到旧 dist 导致类型/常量不一致。

## 不在本设计范围

- 前端 web 包的测试（本次仅后端）
- CI 集成（本地自测为主）
- 覆盖率阈值硬性指标（目标是「覆盖设计矩阵列出的分支」，不追求行覆盖率百分比）
