# Web 端 API 缺口补全设计

- **日期**：2026-06-19
- **状态**：待评审
- **作者**：brainstorming session
- **关联**：`packages/web/src`（前端消费方）、`packages/server/src`（后端实现方）、`packages/shared/src`（类型事实源）

---

## 1. 背景

web 端目前存在大量接口缺口：

- **接口 bug**（PATCH vs PUT 不一致、路径单复数不一致、缺失路由）导致购物车加减、后台编辑商品、商品推荐位等功能静默失败
- **字段缺失**（Product 无 `specs`、Admin 表单缺录入项）导致详情页规格选择器和质量标签永远是空的
- **半成品**（登出 / 个人中心 / 清空购物车 / 应用启动刷新 profile）的 API 层与 store 层都写了，但没有任何 UI 触发点
- **新业务完全无后端支持**：优惠券、评价、收藏、地址簿、订单状态流转（支付/发货/确认收货/物流）、库存扣减、图片上传、推荐位、轮播 Banner、搜索联想、多维筛选与可选排序、分类 Admin CRUD、退款

这些缺口分散在 5 个现有模块和 8 个新业务域中，需要先统一文档、再分批落地，避免一次性大改动失控。

## 2. 目标

1. 建立**单一事实源的 RESTful API 文档**（Markdown，按模块拆分），覆盖现有接口与新增接口
2. 按 **P0 → P1 → P2** 三级分批落地，每批各自走 spec → plan → implementation 流程
3. 让 web 端**所有已渲染的 UI 都能拿到真实数据**，并为后续新业务提供契约基础

## 3. 非目标

- 本设计**不**引入 OpenAPI/Swagger 工具链（采用 Markdown 文档）
- 本设计**不**改动前端 UI 设计（DESIGN.md 仍是 UI 唯一权威源）
- 本设计**不**完成 P1/P2 的实现细节（由各自分批 spec 负责）
- 本设计**不**改动全局响应包装格式与错误码体系（已有约定保留）

## 4. 总体架构

### 4.1 三层交付物

```
docs/api/                          # 全量 API 文档（本次产出，单一事实源）
├── README.md                      # 约定：base url、鉴权、响应格式、错误码、分页、版本
├── auth.md
├── user.md
├── product.md                     # 含 recommendations、specs、多维筛选、可选排序
├── category.md                    # 含 Admin CRUD
├── cart.md                        # 含 clear
├── order.md                       # 含状态流转、物流、退款
├── address.md                     # 地址簿（新）
├── review.md                      # 商品评价（新）
├── favorite.md                    # 收藏（新）
├── coupon.md                      # 优惠券（新）
├── banner.md                      # 首页轮播/推荐位（新）
├── upload.md                      # 图片上传（新）
└── shipping.md                    # 物流跟踪（新）

docs/agent-harness/specs/
└── 2026-06-19-web-api-gap-design.md   # 本文件（分批契约）

docs/agent-harness/plans/
├── 2026-06-19-web-api-p0-*.md         # P0 实施计划（后续 writing-plans 产出）
├── 2026-06-19-web-api-p1-*.md         # P1 实施计划
└── 2026-06-19-web-api-p2-*.md         # P2 实施计划
```

### 4.2 文档统一约定（写入 `docs/api/README.md`）

| 维度      | 约定                                                                                                                          |
| --------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Base URL  | `/api`（保持现状，不引入版本前缀）                                                                                            |
| 协议      | HTTPS（生产）/ HTTP（本地开发）                                                                                               |
| 编码      | UTF-8，JSON body                                                                                                              |
| 成功响应  | `{ code: 0, data: T, message: "success" }`（HTTP 200）                                                                        |
| 错误响应  | HTTP 200 + body 内业务 `code` 非 0（沿用现有 `HttpExceptionFilter`）                                                          |
| 鉴权      | 除显式标 `@Public` 外全部需 JWT Bearer；写商品/分类/轮播/优惠券模板等需 `@Roles(ADMIN)`                                       |
| C 端业务  | 下单、地址、评价、收藏、优惠券领取、订单流转一律需登录                                                                        |
| 分页      | `?page=1&limit=20`；响应 `{ list: T[], total: number, page: number, limit: number }`                                          |
| 时间      | ISO 8601 字符串，UTC+8（与 TypeORM 实体一致）                                                                                 |
| 限流      | 全局 60 次/60 秒；注册/登录单独 10 次/60 秒（沿用 ThrottlerGuard）                                                            |
| 日志/脱敏 | 复用 pino redact 机制；涉及手机号、地址、姓名等 PII 在业务层手动脱敏（参考已有 learning `pino_redact_no_cover_custom_calls`） |

### 4.3 实现优先级分批

| 批次   | 范围                                                               | 触发原因                     |
| ------ | ------------------------------------------------------------------ | ---------------------------- |
| **P0** | 修复已有接口 bug + 库存校验/扣减                                   | 已有功能静默失败，用户可感知 |
| **P1** | 半成品功能 + 推荐位 + 规格字典 + Banner + Admin 表单补字段         | UI 已渲染但数据空，体验差    |
| **P2** | 全新业务（优惠券/评价/收藏/地址簿/物流/上传/筛选/分类 Admin/退款） | 功能增量                     |

## 5. P0 详细设计：接口修复与库存扣减

### P0-1：统一 HTTP 方法（前端对齐后端）

后端统一用 `@Put`，前端错误地用了 `@Patch`，导致三处 405：

| 前端调用位置                                            | 当前                  | 修复后              |
| ------------------------------------------------------- | --------------------- | ------------------- |
| `packages/web/src/api/cart.ts:20` `updateQuantity`      | `PATCH /cart/:id`     | `PUT /cart/:id`     |
| `packages/web/src/pages/AdminProducts.tsx:166` 编辑商品 | `PATCH /products/:id` | `PUT /products/:id` |

**决策**：修改前端对齐后端（后端方法不改，避免破坏其他潜在调用方）。这是最小改动，且符合"后端契约优先"的原则。

### P0-2：修复 `/users/profile` 路径单复数不一致

后端是 `@Controller('user')` → `/api/user/profile`（单数）。前端写成了 `/users/profile`（复数）。

**决策**：修改前端 `packages/web/src/api/user.ts` 对齐后端单数路径。

### P0-3：新增 `GET /products/recommendations`

```
GET /api/products/recommendations?limit=10&excludeId=123
```

- **守卫**：`@Public`（首页/详情页推荐位无需登录可看）
- **算法（MVP）**：`createdAt DESC` + `status = ON` + `stock > 0` + 排除 `excludeId`
- **响应**：`{ list: Product[] }`（不带分页，简单列表）
- **缓存**：60s Redis 缓存（沿用 `ProductService` 现有缓存策略）
- **路由顺序**：必须在 `@Get(':id')` 之前声明，否则被 `:id` 路由 + `ParseIntPipe` 吞掉返回 400

### P0-4：新增 `DELETE /cart`

```
DELETE /api/cart
```

- **守卫**：JWT
- **行为**：清空当前用户所有购物车项
- **响应**：`null`
- **service**：复用 `CartService.removeByUserAndProductIds` 已有的批量删除能力（按当前用户全量删除）

### P0-5：库存校验与扣减

涉及订单创建与取消流程：

**新增 `POST /orders` 内部逻辑（不新增路由）**：

- 下单前校验每个购物车项的 `quantity <= product.stock`
- 库存不足时抛业务码 `40901`（新增），返回缺货商品列表
- 下单成功（事务内）扣减对应商品 `stock`

**修改 `PUT /orders/:id/cancel` 内部逻辑**：

- 取消成功后回补对应订单项的商品 `stock`

**`POST /cart` 内部逻辑**：

- 加购前校验 `product.stock > 0`，不足时返回业务码 `40902`
- （可选）加购数量上限不超过 stock

**新增业务码**（写入 `packages/shared/src/constants.ts` `ErrorCode`）：

- `40901 STOCK_INSUFFICIENT` — 库存不足，无法下单
- `40902 PRODUCT_OUT_OF_STOCK` — 商品已售罄，无法加购

### P0 不包含

- 个人中心页 / 登出按钮 UI 接线（推后到 P1）
- Admin 商品表单补字段（推后到 P1）
- 推荐位智能算法（P1 起开始迭代）

## 6. P1 详细设计：半成品功能与体验补全

> P1 的完整接口定义写入 `docs/api/*.md`，本节只列范围与决策要点。

### P1-1：登出 UI 接线

- 在个人中心入口（P1-3）或 NavBar 添加「退出登录」按钮
- 调用 `POST /api/auth/logout`（后端已存在，将 access jti 加入 Redis 黑名单）
- 成功后清前端 auth store

### P1-2：应用启动刷新 profile

- 在 `App.tsx` 或 `ProtectedRoute` mount 时调一次 `userApi.getProfile()`，用最新数据覆盖 localStorage 中的过期 user

### P1-3：个人中心页

- 新增路由 `/profile`（需登录）
- 展示 nickname / avatar / phone（脱敏显示 138****1234）
- 编辑入口调 `PUT /api/user/profile`（修复 P0-2 后已可用）

### P1-4：Admin 商品表单补字段

- AdminProducts 表单补录入项：`sweetness`、`weight`、`color`、`tags`、`specs`（结构化规格字典）
- 后端 `CreateProductDto` / `UpdateProductDto` 已有 sweetness/weight/color/tags 字段；`specs` 需新增（见 P1-5）

### P1-5：商品规格字典

- 在 `ProductEntity` 新增 `specs` 字段（`simple-json` 存结构化数组，例如 `[{label:"500g/盒", price:29.9}, ...]`）
- 同步到 `packages/shared/src/types/product.ts` 的 `Product` 类型
- `SpecSelector` 组件从 `product.specs` 读取渲染
- BuyBar 加购时 `specLabel` 取自选中规格而非硬编码 `'默认'`

### P1-6：推荐位（依赖 P0-3 已建好的接口）

- MVP 算法见 P0-3；P1 阶段引入权重：同分类优先 + 销量（基于订单 item 聚合）+ 库存适中优先

### P1-7：首页轮播 / Banner

- 新增 `BannerEntity`：id / title / imageUrl / linkType / linkValue / sortOrder / status / 时间戳
- 新增 `GET /api/banners`（`@Public`）按 `sortOrder ASC` 返回上架 Banner
- 新增 Admin CRUD（仅 `/api/admin/banners`，`@Roles(ADMIN)`）
- 前端 `PromoBanner.tsx` 从硬编码改为从接口拉取

### P1-8：清空购物车 UI

- 在 `Cart.tsx` 增加「清空」按钮，调 `DELETE /api/cart`（P0-4 已建好）

## 7. P2 详细设计：全新业务域

> P2 的完整接口定义写入 `docs/api/*.md`，本节只列范围与决策要点。每个业务域独立成 spec。

### P2-1：地址簿 `address.md`

- `AddressEntity`：id / userId / recipientName / phone / province / city / district / detail / isDefault / 时间戳
- 接口：`GET /addresses`、`POST /addresses`、`PUT /addresses/:id`、`DELETE /addresses/:id`、`PUT /addresses/:id/default`
- Checkout 页接入：选择已有地址或新建

### P2-2：商品评价 `review.md`

- `ReviewEntity`：id / productId / userId / orderId（防止重复评价，仅已完成订单可评）/ rating(1-5) / content / images(json) / 时间戳
- 接口：`GET /products/:id/reviews?page=&limit=`（`@Public`）、`POST /orders/:id/reviews`（JWT，已完成订单）、`GET /reviews/mine`（JWT）
- 详情页新增评价模块

### P2-3：收藏 `favorite.md`

- `FavoriteEntity`：id / userId / productId / 时间戳，唯一约束 `(userId, productId)`
- 接口：`POST /products/:id/favorite`、`DELETE /products/:id/favorite`、`GET /favorites?page=&limit=`
- 详情页与个人中心接入

### P2-4：优惠券 `coupon.md`

- `CouponTemplateEntity`（Admin 配置）+ `UserCouponEntity`（用户领取实例）
- 接口：Admin `POST /admin/coupons`（模板）、`GET /coupons`（用户可用券）、`POST /coupons/:id/claim`（领取）、下单时 `couponId` 入参抵扣
- `OrderEntity` 新增 `couponId` / `discountAmount`

### P2-5：物流跟踪 `shipping.md`

- `ShippingEntity`：id / orderId / company / trackingNo / shippedAt / status
- Admin 发货接口 `POST /admin/orders/:id/ship`、用户 `GET /orders/:id/shipping`

### P2-6：订单状态流转（依赖 P2-5）

- `POST /orders/:id/pay`（模拟支付，PENDING → PAID）
- Admin `POST /admin/orders/:id/ship`（PAID → SHIPPED，创建 ShippingEntity）
- `POST /orders/:id/confirm`（SHIPPED → COMPLETED，触发可评价状态）

### P2-7：退款

- `POST /orders/:id/refund`（PAID/SHIPPED → 申请退款）
- `RefundEntity`：id / orderId / reason / status / adminNote / 时间戳
- Admin `POST /admin/refunds/:id/approve|reject`

### P2-8：图片上传 `upload.md`

- `POST /upload/image`（JWT）multipart/form-data，单文件 ≤ 2MB，存到本地 `uploads/` 或对象存储
- 返回 `{ url: string }`，Admin 表单图片字段改用上传组件

### P2-9：搜索与筛选增强（不新增 entity）

- `QueryProductDto` 扩展：`minPrice` / `maxPrice` / `tags` / `origin` / `sortBy`（price_asc/price_desc/sales_desc/created_desc）
- 销量排序依赖订单 item 聚合（可能需要物化视图或定时统计表，P2 spec 详定）

### P2-10：搜索联想

- `GET /products/suggestions?keyword=&limit=10`（`@Public`）返回热门匹配商品名前缀，前端 SearchBar debounce 调用

### P2-11：分类 Admin CRUD

- `POST /categories`、`PUT /categories/:id`、`DELETE /categories/:id`（全部 `@Roles(ADMIN)`）
- 删除时检查是否有关联商品（拒绝或级联，P2 spec 详定）

## 8. shared 类型变更

P0 ~ P2 涉及的 `packages/shared/src` 变更（每批实施时同步）：

| 批次 | 文件               | 变更                                                                                                                       |
| ---- | ------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| P0   | `constants.ts`     | 新增 `STOCK_INSUFFICIENT=40901`、`PRODUCT_OUT_OF_STOCK=40902`                                                              |
| P1   | `types/product.ts` | `Product` 新增 `specs?: ProductSpec[]`；新增 `ProductSpec` 类型                                                            |
| P1   | —                  | 新增 `types/banner.ts`                                                                                                     |
| P2   | —                  | 新增 `types/address.ts`、`types/review.ts`、`types/favorite.ts`、`types/coupon.ts`、`types/shipping.ts`、`types/refund.ts` |
| P2   | `types/order.ts`   | `Order` 新增 `couponId?`、`discountAmount?`                                                                                |

每次改 `shared` 必须重 build：`pnpm --filter shared build`，否则 server 运行时拉到旧 `dist`。

## 9. 风险与权衡

| 风险                                     | 影响                                    | 缓解                                                                |
| ---------------------------------------- | --------------------------------------- | ------------------------------------------------------------------- |
| 推荐位 MVP 算法简单（仅 createdAt DESC） | 推荐质量低，可能不够"个性化"            | P1 引入销量权重；P2+ 视需要引入用户行为                             |
| 库存扣减与并发下单                       | 高并发下可能超卖                        | 事务内 `SELECT ... FOR UPDATE` 锁行；MVP 流量不大可接受             |
| 大量新业务一次性推进                     | 实现失控、PR 巨大                       | 严格按 P0/P1/P2 分批，每批独立 spec → plan → 实施                   |
| `specs` 用 simple-json 存结构化数据      | 无法在 DB 层查询规格字段                | MVP 可接受；如需按规格筛选再迁移到关联表                            |
| 个人中心页未在 P0 包含                   | P0 完成后 logout/userApi 仍未被 UI 触发 | P0 仅修后端契约与 bug；P1 再补 UI                                   |
| 引入新业务码                             | 前端处理需要时间                        | 沿用现有 `ErrorCode` 命名空间，前端按 code 区分 Toast 文案          |
| Markdown 文档与代码可能漂移              | 文档过期                                | 每次实施新接口时，PR 必须同步更新 `docs/api/*.md`；纳入 PR 模板检查 |

## 10. 验收标准

P0 完成后可验证：

- [ ] web 端购物车加减数量成功（不再 405）
- [ ] web 端 Admin 编辑商品成功（不再 405）
- [ ] web 端商品详情页推荐位有数据
- [ ] `DELETE /api/cart` 可用（即使前端 P1 才接入 UI）
- [ ] 下单时库存不足返回业务码 40901，前端 Toast 提示
- [ ] 下单成功后商品 stock 扣减，取消订单后回补
- [ ] `docs/api/*.md` 覆盖所有 P0 接口
- [ ] `packages/shared` 已 build 并被 server/web 拉到新版

## 11. 后续步骤

1. 用户评审本设计文档
2. 进入 `writing-plans` 产出 **P0 实施计划**（`docs/agent-harness/plans/2026-06-19-web-api-p0.md`）
3. P0 实施完成、review 通过后，再写 P1 plan
4. P2 各业务域独立写 spec → plan → 实施

P1/P2 的细节由各自分批 spec 负责，本设计文档作为顶层契约引用。
