# Sprint Contract: P2 全业务域

## Definition of Done

### P2-A 订单闭环

- [ ] shared OrderStatus 枚举追加 REFUNDING=5/REFUNDED=6；Order 接口追加 couponId/discountAmount/paidAt/shippedAt；`pnpm --filter shared build` 成功
- [ ] server OrderEntity 追加 couponId/discountAmount/paidAt/shippedAt 列；ShippingEntity 与 RefundEntity 新建（含 prevStatus 字段）
- [ ] OrderService 新增 pay/ship/confirm/requestRefund/approveRefund/rejectRefund 方法，全部用 queryRunner 事务 + SELECT FOR UPDATE 行锁 + 状态机校验（非法流转抛 ORDER_STATUS_ERROR 40402）
- [ ] OrderController 新增路由：PUT /orders/:id/pay、POST /admin/orders/:id/ship（Admin）、PUT /orders/:id/confirm、POST /orders/:id/refund、GET /orders/:id/shipping
- [ ] 新建 RefundController（Admin）：GET /admin/refunds、POST /admin/refunds/:id/approve、POST /admin/refunds/:id/reject
- [ ] approveRefund 事务内：UPDATE orders status=REFUNDED + 回补商品库存（复用 cancel 回补逻辑）+ 若有用券解绑 UserCoupon（usedAt/orderId 清空）
- [ ] rejectRefund 事务内：UPDATE orders status=RefundEntity.prevStatus + UPDATE refunds status=2 + adminNote 写入；不改动库存
- [ ] e2e `test/order.flow.e2e-spec.ts` 覆盖：pay/ship/confirm 全链路、refund 申请、approve 回补+解绑券、reject 恢复 prevStatus、非法流转抛 40402

### P2-B 用户互动

- [ ] AddressEntity 新建；AddressModule 含 5 接口（GET / POST / PUT / DELETE / PUT :id/default）；DELETE 默认地址抛 ADDRESS_IS_DEFAULT（40902）；设默认事务内先全置 false 再设 true
- [ ] CreateOrderDto 扩展 addressId?；order.service.create 若有 addressId 读 AddressEntity 快照写入 Order.address/phone
- [ ] ReviewEntity 新建（Unique(orderId, productId)）；ReviewModule 含 3 接口（GET /products/:id/reviews Public、POST /orders/:id/reviews JWT、GET /reviews/mine JWT）；评价资格校验：订单 COMPLETED + 归属用户 + 未重复
- [ ] FavoriteEntity 新建（Unique(userId, productId)）；FavoriteModule 含 4 接口（POST/DELETE /products/:id/favorite、GET /favorites、GET /products/:id/favorite-status）；重复收藏抛 FAVORITE_EXISTS（40801）
- [ ] 前端：新建 pages/Addresses.tsx + Addresses 路由；pages/Favorites.tsx + Favorites 路由；components/ReviewSection.tsx + components/FavoriteToggle.tsx
- [ ] ProductDetail.tsx 插入 ReviewSection + 导航栏 FavoriteToggle；OrderDetail.tsx 按 status 显示按钮（pay/confirm/refund/评价）；Checkout.tsx 地址区域接地址簿；Profile.tsx 追加菜单项（地址/收藏）
- [ ] e2e 覆盖：address CRUD + 默认不可删 + 设默认并发；review 资格校验 + 重复拒绝；favorite toggle + 重复拒绝

### P2-C 优惠券

- [ ] CouponTemplateEntity + UserCouponEntity 新建；CouponModule 含 5 接口（GET /coupons/available、GET /coupons/mine、POST /coupons/:id/claim、POST /coupons/preview、Admin CRUD /admin/coupons）
- [ ] claim 事务内：校验 status=1 + 有效期内 + claimedCount < totalCount（超限抛 COUPON_SOLD_OUT 41004）+ claimedCount++ + 创建 UserCoupon
- [ ] order.service.create 支持 couponId：事务内 SELECT FOR UPDATE user_coupons（行锁防并发核销）+ 校验 usedAt IS NULL + 重新计算 discountAmount（复用 preview 逻辑）+ totalAmount = subtotal - discountAmount（<0 抛 COUPON_NOT_APPLICABLE）+ UPDATE user_coupons 核销
- [ ] order.service.cancel 与 approveRefund 在库存回补事务内同时解绑 UserCoupon（usedAt/orderId 清空）
- [ ] 前端：Checkout.tsx 优惠券选择 modal + preview 显示折扣；pages/AdminCoupons.tsx 模板 CRUD；pages/MyCoupons.tsx 我的券；Profile.tsx 菜单项
- [ ] e2e 覆盖：claim 成功/超限、preview 各 type 计算、下单核销、重复使用抛 COUPON_USED（41003）、门槛不满足抛 COUPON_MIN_NOT_MET（41005）、cancel/approveRefund 解绑

### P2-D 搜索增强

- [ ] QueryProductDto 扩展 minPrice/maxPrice/origin/sortBy（默认 created_desc）
- [ ] findAll 追加 andWhere 条件 + 排序分支（sales_desc 用 OrderItem 子查询 + COALESCE）；cacheKey 含全部筛选维度
- [ ] 新增 GET /products/bestsellers（@Public，Redis 5 分钟缓存）+ GET /products/suggest（@Public，Redis 60s 缓存，返回商品名数组）
- [ ] 前端 SearchBar.tsx 加联想浮层（debounce 300ms 调 suggest，点击触发 onSearch，失焦延时 200ms 隐藏）
- [ ] e2e 覆盖：价格区间/产地/sortBy 各分支、bestsellers 缓存、suggest 返回匹配名

### P2-E 基础设施

- [ ] 安装 multer + @types/multer；main.ts 加 app.useStaticAssets(join(__dirname, '..', 'uploads'), { prefix: '/uploads/' })
- [ ] 新建 packages/server/uploads/ 目录；Dockerfile 加 RUN mkdir -p uploads + VOLUME /app/uploads；docker-compose 挂载卷
- [ ] UploadModule + UploadController：POST /upload/image（FileInterceptor）+ limits 2MB + fileFilter MIME image/*；超限抛 UPLOAD_FILE_TOO_LARGE（41101）、非图片抛 UPLOAD_INVALID_TYPE（41102）、空文件抛 UPLOAD_FAILED（41103）
- [ ] 前端 components/UploadButton.tsx；AdminProducts/AdminBanners image 字段从 URL 输入改上传组件；Profile 头像编辑扩展上传
- [ ] CategoryController 追加 POST/PUT/DELETE（@Roles ADMIN）；删除前校验关联在售商品数，>0 抛 CATEGORY_HAS_PRODUCTS（41201）
- [ ] 前端 pages/AdminCategories.tsx；router 加 /admin/categories
- [ ] e2e 覆盖：upload 成功/超大/非图片/空文件、category CRUD + 有关联商品不可删

### GDD 对应

- [ ] GDD L4-1 ~ L4-5 e2e 全部通过（订单流转/退款闭环/优惠券抵扣/评价闭环/上传）
- [ ] GDD L3-1 状态契约矩阵（7 状态 × 6 接口）单测或契约测试覆盖
- [ ] GDD L3-2 优惠券并发核销集成测试（并发两订单同一 couponId 仅一成功）
- [ ] GDD L3-3 多维筛选 cacheKey 不漂移
- [ ] GDD L3-4 地址默认值并发唯一性
- [ ] GDD L3-5 评价 Unique(orderId, productId) schema 校验
- [ ] GDD L2-1 ~ L2-6 单元测试覆盖（状态机分支/券计算/退款恢复/分类删除/上传校验/销量聚合）
- [ ] GDD L1-1 shared build 成功 + dist 含新业务码与枚举
- [ ] GDD L1-2 OrderStatus 枚举穷举（前端 STATUS_LABELS/STATUS_TABS 含全 7 状态，TS 编译通过）

## Boundary Conditions

- **Must not break**: P0 + P1-A + P1-BC 已落地的全部接口与 UI（订单创建/取消/库存、Profile/登出/启动刷新、商品规格/Banner/推荐位/清空购物车）
- **Must not break**: init.sql 种子数据加载（新 entity/字段 synchronize=true 自动建表，旧数据不受影响）
- **Must not break**: 现有 e2e 套件全部通过（auth/user/product/cart/order/banner/recommendations/out-of-stock/clear）
- **Must support**: 数据契约顺序——shared 改完必须 `pnpm --filter shared build` → server entity/DTO → web 消费
- **Must support**: 全部新接口的事务边界（pay/ship/confirm/refund/approve/reject、claim、create with coupon、set default address）用 queryRunner + SELECT FOR UPDATE
- **Must support**: 循环依赖规避（web 新 api 模块沿用现有模式）
- **Must support**: Redis 缓存策略——products:*（含 bestsellers/suggest/新筛选维度）60s/5min、banners 300s、categories:all；create/update/remove 触发对应通配清理
- **UI 一致性**: Admin 页面沿用 gray-200 border + rounded-2xl + focus:ring-brand-primary/30；前台沿用 brand-* token；遵循 DESIGN.md
- **安全**: 上传 MIME 白名单 + 2MB 限制 + 文件名随机化（Date.now + Math.random）；external Banner 跳转 noopener（P1-BC 已做，P2 不破坏）
- **性能**: 销量聚合 SQL 单次响应 < 500ms（本地）+ Redis 缓存兜底；bestsellers 缓存 5 分钟；suggest 缓存 60s
- **并发**: 优惠券核销/地址设默认/评价提交 用事务行锁防并发；退款 prevStatus 恢复正确
- **Docker**: uploads 目录 VOLUME + compose 挂载，容器重建不丢文件
- **状态机兼容**: cancel 仍仅 PENDING 可用；REFUNDING/REFUNDED 不可 cancel；OrderDetail 前端按 7 状态显示对应按钮

## Acceptance Criteria

### Computational（可执行验证）

- **TypeScript 构建**: `pnpm --filter web build` 成功无错误
- **shared 构建**: `pnpm --filter shared build` 成功，dist 含新类型与新业务码段（40601-41299）
- **server unit 测试**: `pnpm --filter server test` 全部通过（含新增状态机/券计算/上传校验/销量聚合/分类删除单测）
- **server e2e 测试**: `pnpm --filter server test:e2e` 全部通过（含新增 order.flow/address/review/favorite/coupon/upload/category.crud/product.search 共 8+ 套件）
- **手动场景验证**: docker compose 环境浏览器走查 spec 第 11 节全部场景（P2-A 7 + P2-B 10 + P2-C 8 + P2-D 4 + P2-E 6 = 35 项）

### Inferential（review 验证）

- spec reviewer review shared 类型：Order 枚举与 7 新类型文件字段完整，与 entity/DTO 兼容
- spec reviewer review OrderService：pay/ship/confirm/refund/approve/reject 六方法的状态机校验正确，全部用 queryRunner 事务 + FOR UPDATE
- spec reviewer review approveRefund：库存回补与 UserCoupon 解绑在同事务内
- spec reviewer review rejectRefund：恢复 prevStatus 正确，不改动库存
- spec reviewer review order.service.create with couponId：SELECT FOR UPDATE user_coupons 防并发核销 + discountAmount 重新计算（不复用前端值）
- spec reviewer review order.service.cancel/approveRefund：券解绑与库存回补同事务
- spec reviewer review CouponService.claim：totalCount 校验 + claimedCount++ 原子性（事务）
- spec reviewer review AddressService.setDefault：事务内先全置 false 再设 true
- spec reviewer review ReviewEntity：Unique(orderId, productId) 约束存在
- spec reviewer review FavoriteEntity：Unique(userId, productId) 约束存在
- spec reviewer review findAll：cacheKey 含全部筛选维度（minPrice/maxPrice/origin/sortBy）+ sales_desc 用 OrderItem 子查询 + COALESCE
- spec reviewer review UploadController：MIME 白名单 + 2MB limit + 文件名随机化
- spec reviewer review CategoryController.remove：关联商品校验在 delete 之前
- spec reviewer review 前端 OrderDetail：7 状态对应按钮分支正确
- spec reviewer review 前端 Checkout：地址簿选择 + 优惠券选择 + preview 调用
- spec reviewer review 前端 ProductDetail：ReviewSection + FavoriteToggle 接入
- spec reviewer review 前端 Profile：3 个新菜单项（地址/收藏/优惠券）
- spec reviewer review 前端 SearchBar：联想浮层 debounce + 失焦隐藏

## Negotiation Record

- **Generator Round 1**: 按 P2-A/B/C/D/E 5 组组织 DoD，每组列实现项 + e2e + 场景；GDD 段独立列对应 assertions
- **Evaluator Round 1 挑战**:
  1. 「状态机校验」未说明具体行为 → 显式列出 pay/ship/confirm/refund/approve/reject 六方法的合法状态与非法抛 40402
  2. approveRefund 与 rejectRefund 的库存处理差异未说明 → approve 回补、reject 不改
  3. 优惠券核销并发未说明 → SELECT FOR UPDATE user_coupons 行锁
  4. RefundEntity prevStatus 用途未说明 → reject 时恢复；prevStatus 必须字段化（非推断）
  5. 地址设默认并发未说明 → 事务内先全置 false 再设 true
  6. 评价 Unique 约束位置 → DB schema 层（非应用层）
  7. 多维筛选 cacheKey 漂移 → 必须含全部维度
  8. 上传安全 → MIME 白名单 + 2MB + 文件名随机化
  9. 分类删除策略 → 拒绝有关联商品，抛 41201
  10. cancel 与 REFUNDING 冲突 → cancel 仅 PENDING 不变；REFUNDING 不可 cancel
  11. Docker uploads 卷 → VOLUME + compose 挂载
  12. 销量聚合性能 → Redis 缓存兜底
  13. shared build 验证 → dist 含新业务码与枚举
  14. 前端 OrderStatus 枚举穷举 → STATUS_LABELS/STATUS_TABS 含全 7 状态
  15. P0/P1 回归边界 → 显式列出 must not break
- **Generator Round 2 修订**: 每条 DoD 绑定到 GDD Level Item 或具体场景/文件 + 行为；Boundary 覆盖数据契约顺序/事务/缓存/UI/安全/性能/并发/Docker/状态机兼容；Acceptance 含 5 项 Computational + 17 项 Inferential review
- **Evaluator Round 2**: 接受。所有 criterion 可用 yes/no 验证；GDD Level Items 全覆盖；Boundary 覆盖已知风险（数据契约/事务/缓存/UI/安全/性能/并发/Docker/状态机/循环依赖/回归）。
- **Final consensus**: 本文件当前版本。
