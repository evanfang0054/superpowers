# P1-BC 商品规格 + 内容运营设计

- **日期**：2026-06-19
- **状态**：待评审
- **作者**：brainstorming session
- **关联**：`docs/agent-harness/specs/2026-06-19-web-api-gap-design.md` 第 6 节 P1-4/P1-5/P1-6/P1-7/P1-8
- **前置**：P0 + P1-A 已完成

---

## 1. 背景

P1 剩余两部分合并为一个 spec 一次走完：

- **P1-B 商品规格 + Admin 表单补字段**：ProductDetail 的 SpecSelector 是死代码（强制类型断言 `specs`，永远 undefined）；BuyBar 加购 specLabel 硬编码 `'默认'`；AdminProducts 表单缺 sweetness/weight/color/tags 字段（后端 DTO 必填，当前新建商品必失败）
- **P1-C-1 Banner Admin CRUD**：PromoBanner.tsx 完全硬编码，CTA 无 onClick，无运营能力
- **P1-C-2 推荐位迭代 + 清空购物车 UI**：P0 推荐位仅按 createdAt DESC，无运营手选；清空购物车后端/store/API 全就绪，仅缺 UI

## 2. 目标

1. 商品规格字典端到端打通：shared 类型 → server entity/DTO → Admin 录入 → 详情页 SpecSelector 渲染 → BuyBar 带选中规格加购
2. AdminProducts 表单补齐后端已有的 sweetness/weight/color/tags 字段，新建商品不再失败
3. Banner 完整 Admin CRUD，首页 PromoBanner 从接口拉取动态渲染，CTA 按 linkType 跳转
4. 推荐位支持 Admin 手选（isRecommended + featuredSortOrder），findRecommendations 优先展示推荐商品再补足
5. Cart 页加「清空」按钮 + 二次确认 modal

## 3. 非目标

- 不做 Banner 轮播（先单条展示，P2 按需）
- 不做 Banner 定时上下架（startAt/endAt）
- 不做推荐位点击埋点
- 不做 specs 价格差异化（保持简单键值对）
- 不做规格库存独立扣减（沿用商品总库存）
- 不做 Banner 图片上传（用 URL 输入，图片上传推到 P2-8）
- 不重构 AdminProducts 表单组件（沿用现有 inline 样式，不抽 Form 库）

## 4. 总体架构

### 4.1 三端改动概览

```
shared (单一事实源，最先改最先生效)
├── types/product.ts  + specs 字段 + isRecommended/featuredSortOrder
├── types/banner.ts   (新建)
└── 必须重 build

server (NestJS)
├── entities/product.entity.ts  + specs/isRecommended/featuredSortOrder 列
├── entities/banner.entity.ts   (新建)
├── modules/product/dto/*.dto   + specs 校验
├── modules/product/product.service.ts  findRecommendations 迭代
├── modules/banner/             (新建 module + controller + service + dto)
└── e2e 补充 banner / specs / 推荐位用例

web (React)
├── api/banner.ts                (新建)
├── components/PromoBanner.tsx   接 API 渲染
├── components/BuyBar.tsx        接 selectedSpecs prop
├── components/SpecSelector.tsx  保持，已有 UI 可用
├── pages/ProductDetail.tsx      修 specs 死代码 + 接通 BuyBar
├── pages/AdminProducts.tsx      补字段 + tags/specs 输入 + 推荐位勾选
├── pages/AdminBanners.tsx       (新建)
├── pages/Cart.tsx               清空按钮 + modal
└── router/index.tsx             + /admin/banners 路由
```

### 4.2 三个独立交付单元

1. **P1-B（商品规格 + Admin 表单字段）** — 涉及 shared + server + web 三端
2. **P1-C-1（Banner Admin CRUD）** — 新建 server module + web Admin 页 + 改 PromoBanner
3. **P1-C-2（推荐位迭代 + 清空购物车 UI）** — server service 迭代 + web 局部改动

依赖关系：P1-B 的 specs 字段 shared 变更必须先 build shared 才能让 server/web 消费。P1-C 三项互相独立，可并行实施，但推荐位迭代依赖 P1-B 的 isRecommended/featuredSortOrder 字段（同属 shared 变更）。

## 5. P1-B 详细设计

### 5.1 数据模型

**`packages/shared/src/types/product.ts`** 追加：

```typescript
export interface ProductSpec {
  name: string; // 规格维度名，如「规格」「产地」
  values: string[]; // 可选值，如 ['500g/盒', '1kg/袋']
}

// Product 接口追加三个字段：
//   specs: ProductSpec[] | null;
//   isRecommended: boolean;
//   featuredSortOrder: number;
```

**`packages/server/src/entities/product.entity.ts`** 追加列：

```typescript
@Column({ type: 'simple-json', nullable: true })
specs: ProductSpec[] | null;

@Column({ name: 'is_recommended', type: 'boolean', default: false })
isRecommended: boolean;

@Column({ name: 'featured_sort_order', type: 'int', default: 0 })
featuredSortOrder: number;
```

import 处加 `import { ProductSpec } from 'shared';`。

**`CreateProductDto` / `UpdateProductDto`** 追加（均 `@IsOptional`）：

```typescript
@IsOptional() @IsArray() specs?: ProductSpec[];
@IsOptional() @IsBoolean() isRecommended?: boolean;
@IsOptional() @IsInt() featuredSortOrder?: number;
```

注意：`@IsArray` 仅校验是数组，不校验内部结构。深度校验用 `@ValidateNested` 需额外定义 `ProductSpecDto`，YAGNI 暂不做（前端 Admin 表单 JSON.parse 后会自然结构化，出错 toast 拦截）。

### 5.2 前端 ProductDetail 修死代码

**`packages/web/src/pages/ProductDetail.tsx`**：

删除第 70-86 行的 `(product as Product & { specs?: string }).specs` 强制类型断言与 `JSON.parse`，改为：

```tsx
const [selectedSpecs, setSelectedSpecs] = useState<Record<string, string>>({});
const specs = product.specs ?? [];

// 渲染处（原第 175-180 行）：
{
  specs.length > 0 && <SpecSelector specs={specs} onChange={setSelectedSpecs} />;
}
```

将 `selectedSpecs` 传给 BuyBar：

```tsx
<BuyBar product={product} selectedSpecs={selectedSpecs} />
```

### 5.3 BuyBar 接 specLabel

**`packages/web/src/components/BuyBar.tsx`**：

新增 `selectedSpecs` prop：

```tsx
interface BuyBarProps {
  product: Product;
  selectedSpecs: Record<string, string>;
}
```

加购时计算 specLabel：

```tsx
const specLabel = Object.values(selectedSpecs).join('/') || '默认';
// handleAddToCart 与 handleBuyNow 都改用此 specLabel
```

未选规格时 fallback `'默认'`（向后兼容现有无规格商品）。

### 5.4 AdminProducts 表单补字段

**`packages/web/src/pages/AdminProducts.tsx`**：

`ProductFormData` 接口与 `emptyForm` 追加：

```typescript
sweetness: string; // 必填，input text
weight: string; // 必填，input text
color: string; // 必填，input text（接受 hex 如 #FF6B35）
tags: string; // 逗号分隔字符串，提交时 split
specs: string; // JSON 字符串，提交时 JSON.parse
isRecommended: boolean; // checkbox
featuredSortOrder: number; // number input
```

`emptyForm` 默认值：

```typescript
sweetness: '', weight: '', color: '#FF6B35',
tags: '', specs: '',
isRecommended: false, featuredSortOrder: 0,
```

**JSX 新增控件**（沿用现有 gray-200 border + rounded-2xl 样式）：

- sweetness/weight/color：input text（color 可选 input[type=color] 但保持 text 兼容 hex）
- tags：input text，placeholder `甜,新鲜,限时`
- specs：textarea，placeholder `[{"name":"规格","values":["500g/盒","1kg/袋"]}]`
- isRecommended：checkbox
- featuredSortOrder：input[type=number]

**`openEditModal` 回填**：

```typescript
tags: product.tags?.join(',') ?? '',
specs: product.specs ? JSON.stringify(product.specs, null, 2) : '',
isRecommended: product.isRecommended ?? false,
featuredSortOrder: product.featuredSortOrder ?? 0,
```

**提交 payload 转换**：

```typescript
const payload = {
  ...其他字段,
  sweetness: form.sweetness,
  weight: form.weight,
  color: form.color,
  tags: form.tags
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  isRecommended: form.isRecommended,
  featuredSortOrder: Number(form.featuredSortOrder),
};

// specs 单独处理（JSON.parse 可能失败）
try {
  payload.specs = form.specs.trim() ? JSON.parse(form.specs) : null;
} catch {
  showToast('规格 JSON 格式错误', 'error');
  return; // 不提交
}
```

## 6. P1-C-1 详细设计：Banner Admin CRUD

### 6.1 数据模型

**`packages/shared/src/types/banner.ts`**（新建）：

```typescript
export type BannerLinkType = 'none' | 'product' | 'category' | 'external';

export interface Banner {
  id: number;
  title: string;
  subtitle: string | null;
  image: string | null;
  ctaText: string | null;
  linkType: BannerLinkType;
  linkValue: string | null;
  sortOrder: number;
  status: number; // 0=OFF, 1=ON
  createdAt: string;
  updatedAt: string;
}

export interface CreateBannerDTO {
  title: string;
  subtitle?: string;
  image?: string;
  ctaText?: string;
  linkType?: BannerLinkType;
  linkValue?: string;
  sortOrder?: number;
  status?: number;
}

export type UpdateBannerDTO = Partial<CreateBannerDTO>;
```

**`packages/server/src/entities/banner.entity.ts`**（新建）：

```typescript
@Entity('banners')
export class BannerEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ length: 100 }) title: string;
  @Column({ length: 200, nullable: true }) subtitle: string;
  @Column({ length: 500, nullable: true }) image: string;
  @Column({ name: 'cta_text', length: 50, nullable: true }) ctaText: string;
  @Column({ name: 'link_type', length: 20, default: 'none' }) linkType: string;
  @Column({ name: 'link_value', length: 500, nullable: true }) linkValue: string;
  @Column({ name: 'sort_order', type: 'int', default: 0 }) sortOrder: number;
  @Column({ type: 'smallint', default: 1 }) status: number;
  @CreateDateColumn() createdAt: Date;
  @UpdateDateColumn() updatedAt: Date;
}
```

### 6.2 后端 Module 结构

**`packages/server/src/modules/banner/`**（新建）：

- `banner.module.ts` — `TypeOrmModule.forFeature([BannerEntity])`
- `banner.controller.ts` — `@Controller('banners')`
- `banner.service.ts` — `findActive`（Public 用）/ `findAll`（Admin 用）/ `create` / `update` / `remove`（含 Redis 缓存 300s，参考 ProductService 模式）
- `dto/create-banner.dto.ts` / `update-banner.dto.ts`

### 6.3 接口

| 方法   | 路径               | 守卫        | 说明                                                            |
| ------ | ------------------ | ----------- | --------------------------------------------------------------- |
| GET    | `/api/banners`     | `@Public`   | 返回 `status=ON` 的 Banner，按 `sortOrder ASC`，300s Redis 缓存 |
| GET    | `/api/banners/all` | JWT + ADMIN | 返回全部 Banner（含 OFF），管理用                               |
| POST   | `/api/banners`     | JWT + ADMIN | 新建                                                            |
| PUT    | `/api/banners/:id` | JWT + ADMIN | 更新                                                            |
| DELETE | `/api/banners/:id` | JWT + ADMIN | 删除                                                            |

**DTO 校验**（`CreateBannerDto`）：

- `title`：`@IsString @MinLength(1) @MaxLength(100)` 必填
- `subtitle?`：`@IsOptional @MaxLength(200)`
- `image?`：`@IsOptional @MaxLength(500)`
- `ctaText?`：`@IsOptional @MaxLength(50)`
- `linkType?`：`@IsOptional @IsIn(['none','product','category','external'])`
- `linkValue?`：`@IsOptional @MaxLength(500)`
- `sortOrder?`：`@IsOptional @IsInt @Min(0)`
- `status?`：`@IsOptional @IsInt @IsIn([0,1])`

**缓存失效**：create / update / remove 后清 `banners:*` 缓存。

### 6.4 前端

**`packages/web/src/api/banner.ts`**（新建）：

```typescript
import { apiClient } from './client';
import type { ApiResponse, Banner, CreateBannerDTO, UpdateBannerDTO } from 'shared';

export const bannerApi = {
  getActive() {
    return apiClient.get<ApiResponse<Banner[]>>('/banners');
  },
  getAll() {
    return apiClient.get<ApiResponse<Banner[]>>('/banners/all');
  },
  create(data: CreateBannerDTO) {
    return apiClient.post<ApiResponse<Banner>>('/banners', data);
  },
  update(id: number, data: UpdateBannerDTO) {
    return apiClient.put<ApiResponse<Banner>>(`/banners/${id}`, data);
  },
  remove(id: number) {
    return apiClient.delete<ApiResponse<null>>(`/banners/${id}`);
  },
};
```

**`packages/web/src/components/PromoBanner.tsx`** 改造：

- 内部 `useEffect` 拉取 `bannerApi.getActive()`
- `useState<Banner | null>`，取第一条
- 无 Banner 时不渲染（return null）
- CTA 按 linkType 跳转：
  - `product` → `navigate('/product/${linkValue}')`
  - `category` → `navigate('/?categoryId=${linkValue}')`
  - `external` → `window.open(linkValue, '_blank', 'noopener')`
  - `none` → 无 onClick
- 沿用 DESIGN.md gradient + 装饰圆样式

**`packages/web/src/pages/AdminBanners.tsx`**（新建，仿 AdminProducts）：

- 表格列：title / status（ON/OFF 标签）/ sortOrder / linkType / 操作（编辑/删除）
- 新建/编辑 modal：title / subtitle / image URL / ctaText / linkType(select) / linkValue / sortOrder / status(select ON/OFF)
- 沿用 AdminProducts gray-200 border + rounded-2xl + focus:ring-brand-primary/30 样式

**`packages/web/src/router/index.tsx`** 新增：

```tsx
const AdminBanners = lazy(() => import('@/pages/AdminBanners'));
// 路由表（在 /admin/products 之后）：
{ path: '/admin/banners', element: <AdminRoute><AdminBanners /></AdminRoute> },
```

## 7. P1-C-2 详细设计：推荐位迭代 + 清空购物车 UI

### 7.1 推荐位迭代

依赖 P1-B 第 5.1 节的 `isRecommended` + `featuredSortOrder` 字段（同属 shared 变更）。

**`packages/server/src/modules/product/product.service.ts`** 的 `findRecommendations` 改写排序逻辑：

```typescript
async findRecommendations(opts: { limit?: number; excludeId?: number }) {
  const limit = Math.min(opts.limit ?? 10, 20);
  const excludeId = opts.excludeId ?? 0;
  const cacheKey = `products:recs:${limit}:${excludeId}`;

  const cached = await this.redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  const baseQb = this.productRepo
    .createQueryBuilder('p')
    .where('p.status = :status', { status: ProductStatus.ON })
    .andWhere('p.stock > 0');

  if (excludeId > 0) {
    baseQb.andWhere('p.id != :excludeId', { excludeId });
  }

  // 先取推荐位商品（isRecommended=true）按 featuredSortOrder ASC
  const featured = await baseQb
    .clone()
    .andWhere('p.is_recommended = :isRec', { isRec: true })
    .orderBy('p.featured_sort_order', 'ASC')
    .addOrderBy('p.created_at', 'DESC')
    .take(limit)
    .getMany();

  let list = featured;
  if (list.length < limit) {
    // 不足用非推荐商品按 createdAt DESC 补足
    const excludeIds = list.map(p => p.id);
    const fillQb = baseQb
      .clone()
      .andWhere('p.is_recommended = :isRec', { isRec: false });
    if (excludeIds.length > 0) {
      fillQb.andWhere('p.id NOT IN (:...excludeIds)', { excludeIds });
    }
    const fillers = await fillQb
      .orderBy('p.created_at', 'DESC')
      .take(limit - list.length)
      .getMany();
    list = [...list, ...fillers];
  }

  const result = { list };
  await this.redis.set(cacheKey, JSON.stringify(result), 'EX', 60);
  return result;
}
```

缓存 key 不变（`products:recs:*`），但 `clearProductCache` 在 ProductEntity 的 isRecommended/featuredSortOrder 变更时也会触发（update 路径已调 clearProductCache）。

Admin 表单的 `isRecommended` checkbox + `featuredSortOrder` number input 已在 P1-B 第 5.4 节定义。

### 7.2 清空购物车 UI

**`packages/web/src/pages/Cart.tsx`** 改造：

Header 追加「清空」按钮：

```tsx
<header>
  <h1>购物车</h1>
  <span>{items.length}件商品</span>
  {items.length > 0 && (
    <button
      onClick={() => setClearTarget(true)}
      className="text-brand-coral text-sm font-bold ml-auto"
    >
      清空
    </button>
  )}
</header>
```

Modal 二次确认（复用现有 deleteTarget modal 模式，新增 `clearTarget` state）：

```tsx
const [clearTarget, setClearTarget] = useState(false);

const confirmClear = async () => {
  try {
    await clearCart(); // cart.store 已有，调 cartApi.clear()
    showToast('购物车已清空', 'success');
  } catch {
    showToast('清空失败', 'error');
  } finally {
    setClearTarget(false);
  }
};

// JSX（与现有 delete modal 同级）：
{
  clearTarget && (
    <Modal>
      <p>确定清空购物车？此操作不可撤销</p>
      <button onClick={confirmClear}>确定清空</button>
      <button onClick={() => setClearTarget(false)}>取消</button>
    </Modal>
  );
}
```

## 8. shared 变更汇总

| 变更                                                                      | 文件                                          |
| ------------------------------------------------------------------------- | --------------------------------------------- |
| Product 接口追加 specs/isRecommended/featuredSortOrder                    | `packages/shared/src/types/product.ts`        |
| 新增 ProductSpec 类型                                                     | `packages/shared/src/types/product.ts`        |
| 新增 banner 类型（Banner/CreateBannerDTO/UpdateBannerDTO/BannerLinkType） | `packages/shared/src/types/banner.ts`（新建） |
| index.ts re-export banner 类型                                            | `packages/shared/src/index.ts`                |

每次改 `shared` 必须重 build：`pnpm --filter shared build`。

## 9. 验收场景

### P1-B 场景

| 场景                     | 触发                                     | 预期                                             |
| ------------------------ | ---------------------------------------- | ------------------------------------------------ |
| Admin 创建商品填全字段   | 表单填 sweetness/weight/color/tags/specs | POST 成功，DB 有完整字段                         |
| 详情页 SpecSelector 渲染 | 进入有 specs 的商品详情                  | SpecSelector 显示规格 chips，可选中              |
| BuyBar 加购带 specLabel  | 选规格后加购                             | Cart 中 specLabel 为选中值拼接（如「500g/盒」）  |
| 详情页无 specs 商品      | 商品 specs 为 null                       | SpecSelector 不渲染，BuyBar specLabel 为「默认」 |
| Admin specs JSON 错误    | textarea 填非法 JSON 提交                | toast 错误，不提交                               |

### P1-C-1 场景

| 场景              | 触发                        | 预期                                     |
| ----------------- | --------------------------- | ---------------------------------------- |
| Admin 创建 Banner | /admin/banners 填表保存     | POST 成功，列表显示                      |
| 首页 Banner 渲染  | 首页加载                    | PromoBanner 显示第一条 ON 的 Banner 数据 |
| CTA 跳转 product  | 点 linkType=product 的 CTA  | navigate('/product/:id')                 |
| CTA 跳转 external | 点 linkType=external 的 CTA | window.open 新 tab                       |
| Banner 缓存       | 重复加载首页                | 300s 内不重复查 DB                       |
| Admin 下架        | 状态改 OFF                  | 首页不再显示该 Banner                    |
| 无 ON 的 Banner   | 全部 OFF                    | PromoBanner 不渲染                       |

### P1-C-2 场景

| 场景           | 触发                                        | 预期                                        |
| -------------- | ------------------------------------------- | ------------------------------------------- |
| 推荐位优先展示 | Admin 勾选 2 商品 isRecommended + sortOrder | 详情页推荐位前 2 条是勾选商品，按 sortOrder |
| 推荐位补足     | 推荐商品 < limit                            | 用 createdAt DESC 补足到 limit              |
| 清空购物车     | Cart 页点「清空」→ modal 确认               | items 清空，toast 成功，`DELETE /cart` 200  |
| 空购物车无按钮 | items.length === 0                          | 「清空」按钮不显示                          |
| 清空失败       | 后端异常                                    | toast 失败，items 保持                      |

## 10. 风险与权衡

| 风险                                      | 影响                           | 缓解                                                       |
| ----------------------------------------- | ------------------------------ | ---------------------------------------------------------- |
| specs 用 simple-json 存结构化数组         | DB 层无法按规格字段查询        | MVP 可接受；P2 若需按规格筛选再迁移关联表                  |
| Admin specs JSON textarea                 | 运营易写错 JSON                | 提交时 JSON.parse 校验 + toast 错误，不提交坏数据          |
| 推荐位两段查询                            | 2 次 SQL（featured + fillers） | 单次响应 < 200ms 可接受；Redis 60s 缓存兜底                |
| Banner linkType=external 跳转             | 用户离开站点                   | 用 `window.open(url, '_blank', 'noopener')` 防 tabnabbing  |
| 清空购物车误点                            | 二次确认 modal 已防护          | 复用现有 modal 模式，UX 一致                               |
| Admin 表单字段变多                        | 表单变长                       | 分组（基础/规格/运营），保持视觉层次                       |
| ProductEntity 加 3 列 + BannerEntity 新表 | synchronize 自动建表/加列      | 开发环境 OK；生产需 migration（项目现状 synchronize=true） |
| 推荐位缓存 key 不变但算法变               | 旧缓存命中后仍是旧排序         | 部署后手动清 Redis 或等 60s TTL；MVP 接受                  |

## 11. 测试策略

**后端 e2e**（沿用现有 jest + supertest）：

- `test/banner.e2e-spec.ts`（新建）：Public/Admin 守卫、CRUD、缓存
- `test/product.recommendations.e2e-spec.ts` 扩展：isRecommended 优先、补足逻辑
- `test/product.e2e-spec.ts` 扩展：Create/Update 含 specs/isRecommended/featuredSortOrder

**前端**（无测试框架）：

- TypeScript 构建通过
- docker compose 浏览器手动验证场景

**全量回归**：

- `pnpm --filter shared build`
- `pnpm --filter server test` + `test:e2e`
- `pnpm --filter web build`

## 12. 后续步骤

1. 用户评审本设计文档
2. 进入 `sprint-contract` 协商 Definition of Done
3. 进入 `writing-plans` 产出实施计划
4. Subagent-Driven Development 执行实施
