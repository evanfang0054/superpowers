# Sprint Contract: Web API Gap P0

## Definition of Done

### 接口契约对齐（前端不再 405）

- [ ] `packages/web/src/api/cart.ts` 的 `updateQuantity` 改为 `PUT /cart/:id`，Cart 页面加减数量后 UI 数值与后端一致（重新 `GET /cart` 能拿到更新后的 quantity）
- [ ] `packages/web/src/pages/AdminProducts.tsx` 编辑商品改为 `PUT /products/:id`，编辑后表单关闭且 `GET /products` 列表显示新值
- [ ] `packages/web/src/api/user.ts` 路径改为 `/user/profile`（单数），为 P1 个人中心做准备（P0 内不要求 UI 触发，但接口需对齐）

### 新增接口

- [ ] `GET /api/products/recommendations?limit=10&excludeId=<id>` 返回 `status=ON && stock>0 && id!=excludeId` 的商品，按 `createdAt DESC` 排序；在 `@Get(':id')` 之前声明（不会被 ParseIntPipe 吞掉）；Redis 60s 缓存生效
- [ ] `DELETE /api/cart` 清空当前用户购物车；调用后 `GET /api/cart` 返回空数组
- [ ] `POST /api/orders` 在事务内对每个购物车项校验 `quantity <= product.stock`；不足时整笔回滚并返回业务码 `40901`，data 字段含缺货明细 `{ productId, productName, requested, available }`
- [ ] `POST /api/orders` 成功后在同一事务内扣减每个商品的 `stock`（`stock -= quantity`）
- [ ] `PUT /api/orders/:id/cancel` 成功后在同一事务内回补每个订单项对应商品的 `stock`
- [ ] `POST /api/cart` 加购前校验 `product.stock > 0`，售罄返回业务码 `40902`

### 类型与构建

- [ ] `packages/shared/src/constants.ts` 新增 `STOCK_INSUFFICIENT=40901`、`PRODUCT_OUT_OF_STOCK=40902`
- [ ] `pnpm --filter shared build` 成功，server 启动后能 import 到新 ErrorCode（验证：登录成功后人为制造库存不足下单，返回体 code === 40901）
- [ ] web 通过 Vite alias 直读 shared 源码，无需额外构建；浏览器 Network 面板能看到 `PUT /cart/:id` 请求

### 文档

- [ ] `docs/api/README.md` 写完统一约定（base url / 鉴权 / 响应格式 / 错误码表 / 分页 / 时间 / 限流 / 脱敏）
- [ ] `docs/api/auth.md`、`user.md`、`product.md`（含 recommendations）、`category.md`、`cart.md`（含 clear）、`order.md`（含库存校验说明）覆盖所有 P0 涉及接口；每个接口含 method/path/守卫/请求体/响应体/错误码

## Boundary Conditions

- **Must not break**: 现有注册/登录/refresh/logout、商品列表与详情查询、分类查询、购物车 add/update/remove、订单 list/detail/cancel、健康检查
- **Must not break**: 现有 `init.sql` 种子数据可正常加载，docker compose up 后所有上述流程可走通
- **Must support**: MySQL 事务（TypeORM `entityManager.transaction`），库存扣减与回补必须在事务内
- **Must support**: Redis 缓存（recommendations 接口）；缓存 key 需考虑 `excludeId` 与 `limit` 参数
- **Performance**: recommendations 查询走索引（`status, stock, createdAt`），单次响应 < 200ms（本地环境）
- **Concurrency**: 库存扣减使用事务内行锁（`SELECT ... FOR UPDATE` 或 TypeORM 等价写法），避免高并发超卖；MVP 接受单机 MySQL 默认隔离级别
- **Cache invalidation**: 商品 stock 变化时（下单扣减/取消回补/Admin 编辑）需考虑是否失效 recommendations 缓存；MVP 接受 60s TTL 自然过期

## Acceptance Criteria

### Computational（可执行验证）

- **场景 A（购物车加减）**：docker compose 环境，登录后加入购物车 → Cart 页点「+」→ 后端 PUT 成功 → 重新 GET /cart 数量 +1；点「-」同理 -1
- **场景 B（Admin 编辑）**：登录 admin 账号 → AdminProducts 编辑某商品 price → 表单提交 PUT 成功 → 列表显示新 price
- **场景 C（推荐位）**：进入任意商品详情页 → Network 面板看到 `GET /products/recommendations` 200 → RecommendFruits 组件渲染至少 1 张商品卡（前提：DB 有 ≥2 个 status=ON 且 stock>0 的商品）
- **场景 D（库存不足下单）**：人为将某商品 stock 改为小于购物车数量 → Checkout 提交 → 响应体 `code === 40901`，前端 Toast 提示库存不足
- **场景 E（库存扣减与回补）**：下单成功后查 DB `products.stock` 减少；取消该订单后查 DB `stock` 恢复原值
- **场景 F（加购售罄）**：将某商品 stock 改为 0 → BuyBar 点「加入购物车」→ 响应体 `code === 40902`
- **TypeScript**: `pnpm --filter server build` 与 `pnpm --filter web build` 均无类型错误
- **shared build**: `pnpm --filter shared build` 成功且 `packages/shared/dist/constants.js` 含新 ErrorCode

### Inferential（review 验证）

- spec reviewer review `packages/server/src/modules/order/order.service.ts` 的事务实现，确认扣减/回补在同一事务内、使用了行锁
- spec reviewer review `packages/server/src/modules/product/product.controller.ts`，确认 `@Get('recommendations')` 在 `@Get(':id')` 之前声明
- spec reviewer review `docs/api/*.md`，确认与代码实现一致（method/path/字段）

## Negotiation Record

- **Generator Round 1**: 初稿 7 条 DoD，每条以"接口成功/可用"描述，无可验证手段
- **Evaluator Round 1 挑战**:
  1. "成功"无法验证 —— 需明确 HTTP 状态、响应体、UI 表现三层
  2. "有数据"依赖种子数据 —— 需在 Boundary 中声明 DB 前置条件
  3. "可用"无测试框架 —— 改用 docker compose 环境手动验证场景 A-F
  4. 库存场景缺触发路径 —— 需明确如何制造 stock=0 或 stock<quantity 状态
  5. 缺 shared build 验证 —— 已知 learning 坑，必须显式列入
  6. 缺错误码返回 data 结构 —— 缺货明细字段需明确
  7. 缺事务/行锁/缓存失效等非功能要求 —— 列入 Boundary
  8. 缺 TypeScript 构建验证 —— 列入 Computational
- **Generator Round 2 修订**: 拆分为「接口契约对齐」「新增接口」「类型与构建」「文档」四组；每条 DoD 绑定到具体场景 A-F；补全 Boundary（事务/缓存/并发/失效）与 Acceptance（computational 6 场景 + inferential 3 项）
- **Evaluator Round 2**: 接受。所有 criterion 可用 yes/no 验证；场景 A-F 有明确的触发路径与观察点；Boundary 覆盖已知风险（事务、shared build、缓存）。
- **Final consensus**: 本文件当前版本。
