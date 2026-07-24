# Sprint Contract: P1-BC 商品规格 + 内容运营

## Definition of Done

### P1-B shared 类型与 server entity

- [ ] `packages/shared/src/types/product.ts` 新增 `ProductSpec` 接口（`{ name: string; values: string[] }`），`Product` 接口追加 `specs: ProductSpec[] | null`、`isRecommended: boolean`、`featuredSortOrder: number`
- [ ] `packages/shared/src/types/banner.ts` 新建，定义 `Banner`、`BannerLinkType`、`CreateBannerDTO`、`UpdateBannerDTO`，并在 `index.ts` re-export
- [ ] `pnpm --filter shared build` 成功；`node -e "require('./packages/shared/dist/...')"` 验证新类型编译进 dist
- [ ] `packages/server/src/entities/product.entity.ts` 追加 3 列：`specs`（simple-json nullable）、`is_recommended`（boolean default false）、`featured_sort_order`（int default 0）
- [ ] `packages/server/src/entities/banner.entity.ts` 新建，字段含 id/title/subtitle/image/cta_text/link_type/link_value/sort_order/status/时间戳
- [ ] `CreateProductDto` / `UpdateProductDto` 追加 `specs`、`isRecommended`、`featuredSortOrder`（均 `@IsOptional`）
- [ ] `CreateBannerDto` / `UpdateBannerDto` 新建，含 title 必填、其余可选 + 校验装饰器（`@IsIn` 校验 linkType）

### P1-B 前端：ProductDetail + BuyBar + AdminProducts

- [ ] `packages/web/src/pages/ProductDetail.tsx` 删除 `(product as Product & { specs?: string }).specs` 强制断言，改用 `product.specs ?? []`；新增 `useState<Record<string,string>>` 管理 selectedSpecs，传给 SpecSelector 的 onChange
- [ ] `packages/web/src/components/BuyBar.tsx` 新增 `selectedSpecs` prop；handleAddToCart / handleBuyNow 中 specLabel 改为 `Object.values(selectedSpecs).join('/') || '默认'`
- [ ] `packages/web/src/pages/AdminProducts.tsx` ProductFormData + emptyForm 追加 sweetness/weight/color/tags/specs/isRecommended/featuredSortOrder 字段；JSX 加对应输入控件（沿用 gray-200 border + rounded-2xl）；openEditModal 回填（tags=join(',')、specs=JSON.stringify）；提交 payload 转换（tags split、specs JSON.parse + 失败 toast 不提交）

### P1-B 验收场景

- [ ] 场景：Admin 创建商品填全字段 → POST 成功 → DB product 行有 sweetness/weight/color/tags/specs/isRecommended/featuredSortOrder 完整值
- [ ] 场景：进入有 specs 的商品详情 → SpecSelector 显示规格 chips 可选中
- [ ] 场景：选规格后加购 → Cart 中 specLabel 为选中值拼接（如「500g/盒」）
- [ ] 场景：商品 specs=null → SpecSelector 不渲染，BuyBar specLabel 为「默认」
- [ ] 场景：Admin textarea 填非法 JSON 提交 → toast 错误，不提交

### P1-C-1 Banner 后端

- [ ] `packages/server/src/modules/banner/` 新建 module（TypeOrmModule.forFeature([BannerEntity]）+ controller + service + dto
- [ ] GET `/api/banners`（@Public）返回 status=1 的 Banner，按 sortOrder ASC，300s Redis 缓存
- [ ] GET `/api/banners/all`（JWT+ADMIN）返回全部 Banner
- [ ] POST `/api/banners`（JWT+ADMIN）新建，返回新 Banner
- [ ] PUT `/api/banners/:id`（JWT+ADMIN）更新，清缓存
- [ ] DELETE `/api/banners/:id`（JWT+ADMIN）删除，清缓存
- [ ] e2e `test/banner.e2e-spec.ts` 覆盖：Public 读、Admin 读、CRUD、无 token 401、非 admin 403、缓存命中

### P1-C-1 Banner 前端

- [ ] `packages/web/src/api/banner.ts` 新建，含 getActive/getAll/create/update/remove
- [ ] `packages/web/src/components/PromoBanner.tsx` 改造：useEffect 拉 bannerApi.getActive()，useState<Banner|null>，无 Banner return null；CTA 按 linkType 跳转（product→navigate, category→navigate, external→window.open noopener, none→无）
- [ ] `packages/web/src/pages/AdminBanners.tsx` 新建（仿 AdminProducts）：表格列 title/status/sortOrder/linkType/操作；新建编辑 modal 含所有字段；沿用 gray-200 样式
- [ ] `packages/web/src/router/index.tsx` 新增 `/admin/banners` 路由，用内联 AdminRoute 包裹

### P1-C-1 验收场景

- [ ] 场景：/admin/banners 填表保存 → POST 成功，列表显示
- [ ] 场景：首页加载 → PromoBanner 显示第一条 ON 的 Banner
- [ ] 场景：点 linkType=product 的 CTA → navigate('/product/:linkValue')
- [ ] 场景：点 linkType=external 的 CTA → window.open 新 tab（带 noopener）
- [ ] 场景：重复加载首页 → 300s 内 DB 不重复查询（Redis 缓存）
- [ ] 场景：Admin 状态改 OFF → 首页不再显示该 Banner
- [ ] 场景：全部 OFF → PromoBanner return null 不渲染

### P1-C-2 推荐位迭代

- [ ] `packages/server/src/modules/product/product.service.ts` 的 `findRecommendations` 改写：先查 isRecommended=true 按 featuredSortOrder ASC + createdAt DESC，不足 limit 时用 isRecommended=false 按 createdAt DESC 补足
- [ ] e2e `test/product.recommendations.e2e-spec.ts` 扩展：isRecommended 商品优先、featuredSortOrder 排序、补足逻辑
- [ ] 场景：Admin 勾选 2 商品 isRecommended + 设 sortOrder → 详情页推荐位前 2 条是勾选商品按 sortOrder 排序
- [ ] 场景：推荐商品数 < limit → 用 createdAt DESC 补足到 limit

### P1-C-2 清空购物车 UI

- [ ] `packages/web/src/pages/Cart.tsx` Header 追加「清空」文字按钮（items.length>0 时显示，brand-coral 色）
- [ ] 新增 `clearTarget` state + modal 二次确认（复用现有 delete modal 模式）
- [ ] confirmClear 调 cart.store.clearCart() → 成功 toast「购物车已清空」、失败 toast「清空失败」
- [ ] 场景：Cart 页点「清空」→ modal 确认 → items 清空 + toast 成功 + `DELETE /cart` 200
- [ ] 场景：items.length===0 → 「清空」按钮不显示
- [ ] 场景：后端异常 → toast 失败，items 保持

## Boundary Conditions

- **Must not break**: 现有商品 CRUD（含 AdminProducts 编辑现有商品）、购物车 add/update/remove、订单创建、首页与详情页渲染
- **Must not break**: P0 + P1-A 已落地的接口与 UI（/profile、登出、启动刷新等）
- **Must not break**: 现有 init.sql 种子数据加载（新增列有 default，旧数据不受影响）
- **Must support**: synchronize=true 自动建 banners 表与 product 新列（开发环境）
- **Must support**: Redis 缓存策略（banners 300s、recommendations 60s），create/update/remove 时清缓存
- **Must support**: 循环依赖规避（沿用动态 import 模式若 Banner store 需要；本 spec 不涉及 store）
- **数据契约顺序**: shared 改完必须 `pnpm --filter shared build` → server entity/DTO → web 消费
- **UI 一致性**: Admin 表单沿用 AdminProducts gray-200 border + rounded-2xl + focus:ring-brand-primary/30；PromoBanner 沿用 DESIGN.md gradient
- **性能**: 推荐位两段查询单次响应 < 200ms（本地），Redis 缓存兜底
- **安全**: Banner external 跳转用 `window.open(url, '_blank', 'noopener')` 防 tabnabbing

## Acceptance Criteria

### Computational（可执行验证）

- **TypeScript 构建**: `pnpm --filter web build` 成功无错误
- **shared 构建**: `pnpm --filter shared build` 成功，dist 含新类型
- **server unit 测试**: `pnpm --filter server test` 全部通过
- **server e2e 测试**: `pnpm --filter server test:e2e` 全部通过（含新增 banner.e2e、扩展的 product.recommendations.e2e、product.e2e 含 specs 字段）
- **手动场景验证**: docker compose 环境浏览器走查 P1-B / P1-C-1 / P1-C-2 全部场景

### Inferential（review 验证）

- spec reviewer review `shared/types/product.ts` 与 `banner.ts`：类型定义完整、ProductSpec 结构与 entity simple-json 兼容
- spec reviewer review `product.entity.ts` 与 `banner.entity.ts`：列名命名（snake_case）、类型、default 值正确
- spec reviewer review `product.service.ts findRecommendations`：两段查询逻辑正确，excludeIds 防 SQL 注入（参数化），缓存 key 与失效逻辑
- spec reviewer review `ProductDetail.tsx`：删除强制断言、selectedSpecs 状态管理无竞态、传 BuyBar prop 类型一致
- spec reviewer review `BuyBar.tsx`：specLabel 拼接逻辑、未选规格 fallback「默认」向后兼容
- spec reviewer review `AdminProducts.tsx`：表单字段补全、tags split 与 specs JSON.parse 容错（失败不提交）、openEditModal 回填正确
- spec reviewer review `banner.controller.ts`：@Public 与 ADMIN 守卫分组正确、缓存失效在写操作后触发
- spec reviewer review `PromoBanner.tsx`：linkType 跳转分支、external 用 noopener、无 Banner 时 return null
- spec reviewer review `AdminBanners.tsx`：CRUD 完整、modal 字段覆盖所有 Banner 字段
- spec reviewer review `Cart.tsx`：清空按钮条件渲染、modal 复用现有模式、clearCart 调用与 toast 反馈

## Negotiation Record

- **Generator Round 1**: 初稿按 P1-B / P1-C-1 / P1-C-2 三组组织 DoD，每组列实现项 + 验收场景
- **Evaluator Round 1 挑战**:
  1. P1-B shared 变更未说明 build 验证 → 显式列入 `pnpm --filter shared build` 与 dist 验证
  2. ProductEntity 新列未说明 default → 填 default 避免 init.sql 种子数据 break
  3. AdminProducts tags/specs 输入未说明提交失败处理 → JSON.parse 失败 toast 不提交
  4. Banner linkType=external 未说明安全 → window.open 加 noopener
  5. 推荐位两段查询的 SQL 注入风险 → 参数化（excludeIds 用 `:...excludeIds`）
  6. 缓存失效边界 → banner create/update/remove 后清 `banners:*`；recommendations update 已有 clearProductCache
  7. 未说明「无 ON 的 Banner」行为 → PromoBanner return null 不渲染
  8. 未说明循环依赖 → 本 spec 不涉及 store，无需动态 import
  9. 缺 TypeScript / e2e Computational → 补 web build + shared build + server test/test:e2e
  10. P1-B 场景「商品 specs=null」未覆盖 → 补 SpecSelector 不渲染 + BuyBar fallback「默认」
  11. 回归边界未列 P0/P1-A → 显式说明 must not break P0 + P1-A
- **Generator Round 2 修订**: 每条 DoD 绑定到具体场景或文件 + 行为；Boundary 覆盖数据契约顺序/UI 一致性/性能/安全；Acceptance 含 5 项 Computational + 10 项 Inferential
- **Evaluator Round 2**: 接受。所有 criterion 可用 yes/no 验证；场景有明确触发路径与观察点；Boundary 覆盖已知风险（数据契约/UI/性能/安全/缓存/循环依赖/回归）。
- **Final consensus**: 本文件当前版本。
