# P2 全业务域设计

- **日期**：2026-06-19
- **状态**：待评审
- **作者**：brainstorming session
- **关联**：`docs/agent-harness/specs/2026-06-19-web-api-gap-design.md` 第 7 节 P2
- **前置**：P0 + P1-A + P1-BC 已完成

---

## 1. 背景

P0 修复接口 bug + 库存校验，P1-A 落地用户中心，P1-BC 落地商品规格 + Banner + 推荐位迭代 + 清空购物车。P2 是 11 个全新业务域，一次性落地建立完整电商闭环。

## 2. 目标

1. **订单闭环**：支付→发货→收货→评价资格，退款流程
2. **用户互动**：地址簿、商品评价、收藏
3. **营销促销**：优惠券领取与下单抵扣
4. **搜索增强**：多维筛选、销量排序、搜索联想
5. **基础设施**：图片上传、分类 Admin CRUD

## 3. 非目标

- 不做支付网关接入（模拟支付）
- 不做评价回复（商家回复评价）
- 不做优惠券叠加使用（一单一券）
- 不做销量定时统计表（实时聚合 + 缓存）
- 不做搜索分词/ES（仅 LIKE）
- 不做对象存储（本地 uploads）
- 不做分类多级（仅一级）
- 不做图片压缩/水印

## 4. 总体架构

### 4.1 五组交付单元

```
P2-A 订单闭环（强耦合，先做）
  P2-6 状态流转：pay/ship/confirm
  P2-5 物流：ShippingEntity + Admin 发货
  P2-7 退款：OrderStatus 扩展 + RefundEntity + Admin 审批

P2-B 用户互动（独立）
  P2-1 地址簿：AddressEntity + /addresses CRUD + 独立管理页 + Checkout 接入
  P2-2 评价：ReviewEntity + /products/:id/reviews + /orders/:id/reviews
  P2-3 收藏：FavoriteEntity + toggle + /favorites 页

P2-C 营销（独立，影响 OrderEntity）
  P2-4 优惠券：CouponTemplate + UserCoupon 双表 + Admin CRUD + claim + 下单抵扣

P2-D 搜索增强（无新 entity）
  P2-9 多维筛选：QueryProductDto 扩展 + 销量聚合缓存
  P2-10 联想：/products/suggest + SearchBar 浮层

P2-E 基础设施（独立）
  P2-8 图片上传：multer + 本地 uploads/ + useStaticAssets
  P2-11 分类 Admin CRUD：拒绝删除有关联商品的分类
```

### 4.2 三端改动概览

```
shared（最先改最先生效）
├── types/order.ts        + REFUNDING/REFUNDED 枚举 + couponId/discountAmount/paidAt/shippedAt
├── types/address.ts      (新建)
├── types/review.ts       (新建)
├── types/favorite.ts     (新建)
├── types/coupon.ts       (新建)
├── types/shipping.ts     (新建)
├── types/refund.ts       (新建)
├── constants.ts          + 6 段业务码（退款/评价/收藏/地址/优惠券/上传/分类）
└── 必须重 build

server（NestJS）
├── entities/             + Address/Review/Favorite/Coupon/UserCoupon/Shipping/Refund 7 新 entity
├── modules/order/        + pay/ship/confirm/refund/approveRefund/rejectRefund 方法
├── modules/address/      (新建 module)
├── modules/review/       (新建 module)
├── modules/favorite/     (新建 module)
├── modules/coupon/       (新建 module)
├── modules/shipping/     (新建 module)
├── modules/refund/       (新建 module)
├── modules/upload/       (新建 module，multer)
├── modules/product/      + suggest + findAll 多维筛选 + category CRUD + bestsellers
├── main.ts               + useStaticAssets('/uploads/')
├── app.module.ts         + 注册新 module
└── uploads/              (新建目录)

web（React）
├── api/                  + address/review/favorite/coupon/shipping/refund/upload
├── pages/                + Addresses / Favorites / AdminCoupons / AdminCategories / AdminRefunds
├── components/           + ReviewSection / FavoriteToggle / UploadButton / SuggestionDropdown
├── pages/Checkout.tsx    接地址簿 + 优惠券
├── pages/ProductDetail.tsx + 评价区 + 收藏 toggle
├── pages/OrderDetail.tsx + 状态按钮（支付/确认收货/评价/退款）
├── pages/Profile.tsx     + 收藏/地址/优惠券菜单项
├── components/SearchBar.tsx + 联想浮层
└── router/index.tsx      + 新路由
```

## 5. P2-A 详细设计：订单闭环

### 5.1 数据模型

**OrderStatus 扩展**（shared/types/order.ts）：

```typescript
((PENDING = 0),
  (PAID = 1),
  (SHIPPED = 2),
  (COMPLETED = 3),
  (CANCELLED = 4),
  (REFUNDING = 5),
  (REFUNDED = 6));
```

**OrderEntity 追加字段**：

```typescript
@Column({ name: 'coupon_id', nullable: true }) couponId: number | null;
@Column({ name: 'discount_amount', type: 'decimal', precision: 10, scale: 2, default: 0 }) discountAmount: number;
@Column({ name: 'paid_at', type: 'timestamp', nullable: true }) paidAt: Date | null;
@Column({ name: 'shipped_at', type: 'timestamp', nullable: true }) shippedAt: Date | null;
```

**ShippingEntity**（新建 `entities/shipping.entity.ts`）：

```typescript
@Entity('shippings')
export class ShippingEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'order_id' }) orderId: number;
  @Column({ length: 100 }) company: string;
  @Column({ name: 'tracking_no', length: 100 }) trackingNo: string;
  @Column({ name: 'shipped_at', type: 'timestamp' }) shippedAt: Date;
  @Column({ type: 'smallint', default: 0 }) status: number; // 0=运输中 1=已签收
  @CreateDateColumn() createdAt: Date;
}
```

**RefundEntity**（新建 `entities/refund.entity.ts`）：

```typescript
@Entity('refunds')
export class RefundEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'order_id' }) orderId: number;
  @Column({ name: 'user_id' }) userId: number;
  @Column({ length: 500 }) reason: string;
  @Column({ name: 'prev_status', type: 'smallint' }) prevStatus: number; // 申请退款前的状态（PAID 或 SHIPPED）
  @Column({ type: 'smallint', default: 0 }) status: number; // 0=待审批 1=通过 2=拒绝
  @Column({ name: 'admin_note', length: 500, nullable: true }) adminNote: string | null;
  @CreateDateColumn() createdAt: Date;
  @UpdateDateColumn() updatedAt: Date;
}
```

### 5.2 状态机

合法流转：

- `pay`（用户）：仅 `PENDING → PAID`
- `ship`（Admin）：仅 `PAID → SHIPPED`，同时创建 ShippingEntity
- `confirm`（用户）：仅 `SHIPPED → COMPLETED`
- `refund`（用户申请）：仅 `PAID` 或 `SHIPPED → REFUNDING`，记录 prevStatus
- `approveRefund`（Admin）：`REFUNDING → REFUNDED`，事务内回补库存 + 解绑优惠券
- `rejectRefund`（Admin）：`REFUNDING → 恢复 prevStatus`
- 非法流转抛 `ORDER_STATUS_ERROR`（40402 复用）

### 5.3 接口

| 方法 | 路径                             | 守卫      | 说明                               |
| ---- | -------------------------------- | --------- | ---------------------------------- |
| PUT  | `/api/orders/:id/pay`            | JWT       | 模拟支付，PENDING→PAID             |
| POST | `/api/admin/orders/:id/ship`     | JWT+ADMIN | 发货，body `{company, trackingNo}` |
| PUT  | `/api/orders/:id/confirm`        | JWT       | 确认收货                           |
| POST | `/api/orders/:id/refund`         | JWT       | 申请退款，body `{reason}`          |
| GET  | `/api/orders/:id/shipping`       | JWT       | 查物流                             |
| GET  | `/api/admin/refunds`             | JWT+ADMIN | 退款列表（分页）                   |
| POST | `/api/admin/refunds/:id/approve` | JWT+ADMIN | 通过退款（回补库存 + 解绑券）      |
| POST | `/api/admin/refunds/:id/reject`  | JWT+ADMIN | 拒绝退款，body `{adminNote}`       |

### 5.4 前端

- `OrderDetail.tsx` 按 status 显示按钮：PENDING→「去支付」、PAID/SHIPPED→「申请退款」、SHIPPED→「确认收货」、COMPLETED→「去评价」、REFUNDING→「退款审核中」、REFUNDED→「已退款」
- 新建 `pages/AdminRefunds.tsx`：退款审批页（表格 + 通过/拒绝 + 拒绝填 adminNote）

## 6. P2-B 详细设计：用户互动

### 6.1 地址簿（P2-1）

**AddressEntity**（新建）：

```typescript
@Entity('addresses')
export class AddressEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'user_id' }) userId: number;
  @Column({ name: 'recipient_name', length: 50 }) recipientName: string;
  @Column({ length: 20 }) phone: string;
  @Column({ length: 50 }) province: string;
  @Column({ length: 50 }) city: string;
  @Column({ length: 50 }) district: string;
  @Column({ length: 200 }) detail: string;
  @Column({ name: 'is_default', type: 'boolean', default: false }) isDefault: boolean;
  @CreateDateColumn() createdAt: Date;
  @UpdateDateColumn() updatedAt: Date;
}
```

**接口**：

| 方法   | 路径                         | 守卫 | 说明                                          |
| ------ | ---------------------------- | ---- | --------------------------------------------- |
| GET    | `/api/addresses`             | JWT  | 全部地址，默认排第一                          |
| POST   | `/api/addresses`             | JWT  | 新建（若 isDefault，事务内其他置 false）      |
| PUT    | `/api/addresses/:id`         | JWT  | 修改                                          |
| DELETE | `/api/addresses/:id`         | JWT  | 删除（默认地址不可删，抛 ADDRESS_IS_DEFAULT） |
| PUT    | `/api/addresses/:id/default` | JWT  | 设为默认（事务内其他置 false）                |

**CreateOrderDto 扩展**：增加 `addressId?: number`。下单时若有 addressId，读 AddressEntity 快照写入 Order.address/phone。

**前端**：

- 新建 `/addresses` 路由 + `pages/Addresses.tsx`（列表 + CRUD modal + 设默认）
- `Profile.tsx` 追加菜单项「我的地址」
- `Checkout.tsx` 地址区域改为「从地址簿选择 + 显示默认 + 跳转 /addresses 管理」，保留手输 fallback

### 6.2 评价（P2-2）

**ReviewEntity**（新建）：

```typescript
@Entity('reviews')
@Unique(['orderId', 'productId']) // 一件一评
export class ReviewEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'product_id' }) productId: number;
  @Column({ name: 'user_id' }) userId: number;
  @Column({ name: 'order_id' }) orderId: number;
  @Column({ type: 'tinyint' }) rating: number; // 1-5
  @Column({ type: 'text' }) content: string;
  @Column({ type: 'simple-json', nullable: true }) images: string[] | null;
  @CreateDateColumn() createdAt: Date;
  @UpdateDateColumn() updatedAt: Date;
}
```

**接口**：

| 方法 | 路径                                     | 守卫    | 说明                                                                          |
| ---- | ---------------------------------------- | ------- | ----------------------------------------------------------------------------- |
| GET  | `/api/products/:id/reviews?page=&limit=` | @Public | 商品评价列表（分页），含 user 昵称/头像                                       |
| POST | `/api/orders/:id/reviews`                | JWT     | 批量评价订单商品，body `{ reviews: [{productId, rating, content, images?}] }` |
| GET  | `/api/reviews/mine`                      | JWT     | 我的评价                                                                      |

**评价资格**：订单 status === COMPLETED + 归属当前用户 + `(orderId, productId)` 未评过。

**前端**：

- 新建 `components/ReviewSection.tsx`（商品详情页评价区，分页 + 平均分）
- `ProductDetail.tsx` 在 Description 与 RecommendFruits 之间插入 `<ReviewSection productId={product.id} />`
- `OrderDetail.tsx` COMPLETED 订单显示「去评价」按钮 → 弹 modal 批量评价

### 6.3 收藏（P2-3）

**FavoriteEntity**（新建）：

```typescript
@Entity('favorites')
@Unique(['userId', 'productId'])
export class FavoriteEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'user_id' }) userId: number;
  @Column({ name: 'product_id' }) productId: number;
  @CreateDateColumn() createdAt: Date;
}
```

**接口**：

| 方法   | 路径                                | 守卫 | 说明                                |
| ------ | ----------------------------------- | ---- | ----------------------------------- |
| POST   | `/api/products/:id/favorite`        | JWT  | 收藏（已收藏抛 FAVORITE_EXISTS）    |
| DELETE | `/api/products/:id/favorite`        | JWT  | 取消（未收藏抛 FAVORITE_NOT_FOUND） |
| GET    | `/api/favorites?page=&limit=`       | JWT  | 我的收藏分页                        |
| GET    | `/api/products/:id/favorite-status` | JWT  | 查是否已收藏                        |

**前端**：

- 新建 `components/FavoriteToggle.tsx`（心形图标，已收藏实心）
- `ProductDetail.tsx` 导航栏插入 `<FavoriteToggle productId={id} />`
- 新建 `pages/Favorites.tsx`（分页列表）
- `Profile.tsx` 追加菜单项「我的收藏」→ `/favorites`

## 7. P2-C 详细设计：优惠券

### 7.1 数据模型

**CouponTemplateEntity**（Admin 配置，新建）：

```typescript
@Entity('coupon_templates')
export class CouponTemplateEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ length: 100 }) name: string;
  @Column({ type: 'smallint' }) type: number; // 0=满减 1=折扣 2=无门槛
  @Column({ name: 'min_amount', type: 'decimal', precision: 10, scale: 2, default: 0 })
  minAmount: number;
  @Column({ name: 'discount_amount', type: 'decimal', precision: 10, scale: 2, default: 0 })
  discountAmount: number;
  @Column({ name: 'discount_rate', type: 'decimal', precision: 3, scale: 2, nullable: true })
  discountRate: number | null;
  @Column({ name: 'category_id', nullable: true }) categoryId: number | null;
  @Column({ name: 'total_count', type: 'int', default: 0 }) totalCount: number;
  @Column({ name: 'claimed_count', type: 'int', default: 0 }) claimedCount: number;
  @Column({ name: 'start_at', type: 'timestamp' }) startAt: Date;
  @Column({ name: 'end_at', type: 'timestamp' }) endAt: Date;
  @Column({ type: 'smallint', default: 1 }) status: number;
  @CreateDateColumn() createdAt: Date;
  @UpdateDateColumn() updatedAt: Date;
}
```

**UserCouponEntity**（用户领取实例，新建）：

```typescript
@Entity('user_coupons')
export class UserCouponEntity {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'user_id' }) userId: number;
  @Column({ name: 'coupon_id' }) couponId: number;
  @Column({ name: 'order_id', nullable: true }) orderId: number | null;
  @Column({ name: 'used_at', type: 'timestamp', nullable: true }) usedAt: Date | null;
  @CreateDateColumn() createdAt: Date;
}
```

### 7.2 类型与计算

| type | 名称   | 规则                                            |
| ---- | ------ | ----------------------------------------------- |
| 0    | 满减   | subtotal >= minAmount → 减 discountAmount       |
| 1    | 折扣   | subtotal >= minAmount → subtotal * discountRate |
| 2    | 无门槛 | 直接减 discountAmount                           |

适用范围：categoryId 为 null 时全场可用；否则限定该分类商品小计参与计算。

### 7.3 接口

| 方法 | 路径                     | 守卫      | 说明                                                                   |
| ---- | ------------------------ | --------- | ---------------------------------------------------------------------- |
| GET  | `/api/coupons/available` | JWT       | 可领取模板（status=1 + 有效期内 + 未领完）                             |
| GET  | `/api/coupons/mine`      | JWT       | 我的未使用券（含 template 详情）                                       |
| POST | `/api/coupons/:id/claim` | JWT       | 领取（事务内 totalCount 校验 + claimedCount++）                        |
| POST | `/api/coupons/preview`   | JWT       | body `{couponId, items}` → 返回 `{discountAmount, totalAfterDiscount}` |
| CRUD | `/api/admin/coupons`     | JWT+ADMIN | 模板增删改查                                                           |

### 7.4 下单抵扣流程

```
1. Checkout 选券 → POST /coupons/preview 算 discountAmount
2. 提交订单 → POST /orders body 含 couponId
3. OrderService.create 事务内：
   a. SELECT FOR UPDATE user_coupons（锁券）
   b. 校验：usedAt IS NULL、归属、有效期
   c. 重新计算 discountAmount（复用 preview 逻辑）
   d. totalAmount = subtotal - discountAmount（≥0，否则抛 COUPON_NOT_APPLICABLE）
   e. 创建订单 + 扣库存
   f. UPDATE user_coupons SET order_id, used_at=NOW()（核销）
4. cancel/approveRefund 时：回补库存 + 券解绑（usedAt/orderId 清空）
```

### 7.5 前端

- `Checkout.tsx` 价格汇总区追加优惠券行 + 弹出 modal 选券
- 新建 `pages/AdminCoupons.tsx`（模板 CRUD）
- 新建 `pages/MyCoupons.tsx`（已领取未使用）+ `Profile.tsx` 追加菜单项

## 8. P2-D 详细设计：搜索增强

### 8.1 多维筛选与排序（P2-9）

**QueryProductDto 扩展**：

```typescript
minPrice?: number;
maxPrice?: number;
origin?: string;
sortBy?: 'created_desc' | 'price_asc' | 'price_desc' | 'sales_desc';
```

**findAll 改造**：

- 条件：categoryId/keyword + minPrice/maxPrice/origin（andWhere）
- 排序分支：sales_desc 用 OrderItem 子查询聚合 + COALESCE；price_asc/desc 直接 orderBy；默认 created_desc
- cacheKey 含全部筛选维度

**bestsellers 接口**：`GET /api/products/bestsellers?limit=10`（@Public），Redis 缓存 5 分钟。

### 8.2 搜索联想（P2-10）

**接口**：`GET /api/products/suggest?keyword=&limit=10`（@Public）

- `SELECT name FROM products WHERE status=ON AND name LIKE '%keyword%' LIMIT 10`
- Redis 60s 缓存
- 响应 `{ list: string[] }`

**SearchBar 改造**：输入 debounce 300ms 调 suggest，下拉浮层显示，点击触发 onSearch，失焦延时 200ms 隐藏。

## 9. P2-E 详细设计：基础设施

### 9.1 图片上传（P2-8）

**依赖**：`multer` + `@types/multer`

**main.ts**：

```typescript
app.useStaticAssets(join(__dirname, '..', 'uploads'), { prefix: '/uploads/' });
```

**UploadModule**：

```typescript
@Controller('upload')
@UseGuards(JwtAuthGuard)
export class UploadController {
  @Post('image')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: join(process.cwd(), 'uploads'),
        filename: (req, file, cb) => {
          const ext = extname(file.originalname);
          cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 8)}${ext}`);
        },
      }),
      limits: { fileSize: 2 * 1024 * 1024 },
      fileFilter: (req, file, cb) => {
        if (!file.mimetype.startsWith('image/')) {
          return cb(new BadRequestException({ code: 41102, message: '仅支持图片文件' }), false);
        }
        cb(null, true);
      },
    }),
  )
  uploadImage(@UploadedFile() file: Express.Multer.File) {
    if (!file) throw new BadRequestException({ code: 41103, message: '上传失败' });
    return { url: `/uploads/${file.filename}` };
  }
}
```

**Dockerfile**：`RUN mkdir -p uploads` + `VOLUME /app/uploads`

**前端 UploadButton 组件**（新建）：包装 `<input type="file" accept="image/*">`，调 `/upload/image`，返回 url 写入表单字段。

**接入点**：AdminProducts image 字段、AdminBanners image 字段、Profile 头像编辑。

### 9.2 分类 Admin CRUD（P2-11）

**接口扩展**（CategoryController）：

| 方法   | 路径                  | 守卫      | 说明                   |
| ------ | --------------------- | --------- | ---------------------- |
| POST   | `/api/categories`     | JWT+ADMIN | 新建                   |
| PUT    | `/api/categories/:id` | JWT+ADMIN | 修改                   |
| DELETE | `/api/categories/:id` | JWT+ADMIN | 删除（有关联商品拒绝） |

**删除校验**：

```typescript
async removeCategory(id) {
  const count = await this.productRepo.count({ where: { categoryId: id, status: ProductStatus.ON } });
  if (count > 0) {
    throw new BadRequestException({ code: 41201, message: `有 ${count} 个在售商品关联此分类` });
  }
  await this.categoryRepo.delete(id);
  await this.redis.del('categories:all');
}
```

**前端**：新建 `pages/AdminCategories.tsx`（表格 + CRUD modal）。

## 10. shared 变更汇总

| 变更                                                      | 文件                        |
| --------------------------------------------------------- | --------------------------- |
| Order 接口追加 couponId/discountAmount/paidAt/shippedAt   | `types/order.ts`            |
| OrderStatus 枚举追加 REFUNDING=5/REFUNDED=6               | `types/order.ts`            |
| 新增 Address/CreateAddressDTO/UpdateAddressDTO            | `types/address.ts`（新建）  |
| 新增 Review/CreateReviewDTO                               | `types/review.ts`（新建）   |
| 新增 Favorite                                             | `types/favorite.ts`（新建） |
| 新增 CouponTemplate/UserCoupon/CreateCouponDTO/CouponType | `types/coupon.ts`（新建）   |
| 新增 Shipping                                             | `types/shipping.ts`（新建） |
| 新增 Refund/RefundStatus                                  | `types/refund.ts`（新建）   |
| 新增 6 段业务码（退款/评价/收藏/地址/优惠券/上传/分类）   | `constants.ts`              |
| index.ts re-export 全部新类型                             | `index.ts`                  |

每次改 `shared` 必须重 build：`pnpm --filter shared build`。

### 新业务码段

```
40601-40699 退款：REFUND_NOT_ALLOWED / REFUND_NOT_FOUND
40701-40799 评价：REVIEW_EXISTS / REVIEW_NOT_ALLOWED / REVIEW_NOT_FOUND
40801-40899 收藏：FAVORITE_EXISTS / FAVORITE_NOT_FOUND
40901-40999 地址：ADDRESS_NOT_FOUND / ADDRESS_IS_DEFAULT
41001-41099 优惠券：COUPON_NOT_FOUND / COUPON_EXPIRED / COUPON_USED / COUPON_SOLD_OUT / COUPON_MIN_NOT_MET / COUPON_NOT_APPLICABLE
41101-41199 上传：UPLOAD_FILE_TOO_LARGE / UPLOAD_INVALID_TYPE / UPLOAD_FAILED
41201-41299 分类：CATEGORY_HAS_PRODUCTS / CATEGORY_NOT_FOUND
```

## 11. 验收场景

### P2-A 订单闭环

| 场景       | 预期                                |
| ---------- | ----------------------------------- |
| 模拟支付   | PENDING → PAID，paidAt 写入         |
| Admin 发货 | PAID → SHIPPED，ShippingEntity 创建 |
| 确认收货   | SHIPPED → COMPLETED                 |
| 申请退款   | PAID/SHIPPED → REFUNDING            |
| 通过退款   | REFUNDING → REFUNDED，库存回补      |
| 拒绝退款   | REFUNDING → 恢复 prevStatus         |
| 非法流转   | 抛 ORDER_STATUS_ERROR（40402）      |

### P2-B 用户互动

| 场景               | 预期                         |
| ------------------ | ---------------------------- |
| 地址 CRUD          | 新建/编辑/删除/设默认        |
| Checkout 选地址    | Order.address 写快照         |
| 默认地址不可删     | 返回 ADDRESS_IS_DEFAULT      |
| COMPLETED 订单评价 | 批量评价成功                 |
| 重复评价           | 返回 REVIEW_EXISTS           |
| 商品评价列表       | 分页展示含用户昵称           |
| 收藏 toggle        | 心形切换                     |
| 重复收藏           | 返回 FAVORITE_EXISTS         |
| 收藏列表           | 分页展示                     |
| Profile 入口       | 「我的地址」「我的收藏」可见 |

### P2-C 优惠券

| 场景             | 预期                             |
| ---------------- | -------------------------------- |
| Admin 创建满减券 | type=0, minAmount/discountAmount |
| 用户领取         | UserCoupon 创建，claimedCount++  |
| 领取超限         | 返回 COUPON_SOLD_OUT             |
| 下单使用         | totalAmount 扣减，券核销         |
| 重复使用         | 返回 COUPON_USED                 |
| 不满足门槛       | 返回 COUPON_MIN_NOT_MET          |
| 取消订单         | 库存回补 + 券解绑                |
| 退款通过         | 库存回补 + 券解绑                |

### P2-D 搜索增强

| 场景         | 预期                         |
| ------------ | ---------------------------- |
| 价格区间筛选 | minPrice/maxPrice 生效       |
| 产地筛选     | origin LIKE 匹配             |
| 销量排序     | sales_desc 聚合降序          |
| 搜索联想     | 输入「苹」下拉显示匹配商品名 |

### P2-E 基础设施

| 场景               | 预期                      |
| ------------------ | ------------------------- |
| 图片上传 ≤2MB      | 成功返回 /uploads/xxx.jpg |
| 超大文件           | 返回 41101                |
| 非图片 MIME        | 返回 41102                |
| Admin 表单用上传   | image 字段改上传组件      |
| 分类 CRUD          | 新建/修改/删除            |
| 删除有关联商品分类 | 返回 41201                |

## 12. 风险与权衡

| 风险                         | 影响                                   | 缓解                                     |
| ---------------------------- | -------------------------------------- | ---------------------------------------- |
| 一次性做 11 项               | PR 巨大、回归风险高                    | 每 3-4 项插入全量回归 checkpoint         |
| 销量子查询性能               | 大数据量下慢                           | Redis 缓存 bestsellers 5 分钟            |
| 优惠券并发核销               | 高并发可能重复使用                     | SELECT FOR UPDATE user_coupons 行锁      |
| 上传文件安全                 | 恶意文件风险                           | MIME 白名单 + 2MB 限制 + 文件名随机化    |
| RefundEntity prevStatus 推断 | 拒绝退款恢复错状态                     | RefundEntity 显式存 prevStatus 字段      |
| 地址簿默认值唯一             | 并发设置可能破坏                       | 设默认走事务，先全置 false 再设一条 true |
| 状态机扩展破坏 cancel        | cancel 仅 PENDING 可用                 | cancel 校验不变；REFUNDING 不可 cancel   |
| 多维筛选 cacheKey 漂移       | 旧缓存命中错结果                       | cacheKey 含全部筛选维度                  |
| Docker uploads 卷            | 容器重建丢文件                         | Dockerfile VOLUME + compose 挂载         |
| 优惠券与订单事务交叉         | create/cancel/approveRefund 都要处理券 | 三处统一在事务内核销/解绑                |

## 13. 测试策略

**后端 e2e**（沿用 jest + supertest）：

- `test/order.flow.e2e-spec.ts`：完整流转 pay→ship→confirm→refund（依赖 P2-A）
- `test/address.e2e-spec.ts`：CRUD + 设默认 + 默认不可删
- `test/review.e2e-spec.ts`：评价资格、重复评、列表
- `test/favorite.e2e-spec.ts`：toggle + 重复 + 列表
- `test/coupon.e2e-spec.ts`：领取、核销、超限、门槛、取消解绑
- `test/upload.e2e-spec.ts`：成功、超大、非图片
- `test/category.crud.e2e-spec.ts`：CRUD + 有关联商品不可删
- `test/product.search.e2e-spec.ts`：多维筛选 + 销量排序 + suggest

**前端**（无测试框架）：

- TypeScript 构建通过
- docker compose 浏览器手动验证

**全量回归**：每 3-4 个子项后跑 `shared build + server test/e2e + web build`。

## 14. Gate Driven Development

### ROOT

P2 全业务域设计：一次性落地 11 个新业务域（订单状态流转 + 物流 + 退款 / 地址簿 + 评价 + 收藏 / 优惠券 / 多维筛选 + 联想 / 图片上传 + 分类 Admin CRUD）。核心风险集中在订单状态机非法流转、优惠券并发核销、退款拒绝状态恢复、评价与收藏的并发唯一约束、多维筛选缓存键漂移、上传安全校验。测试覆盖按风险显著性递归展开。

### Level Items

#### L4-1

PARENT_ID：ROOT
视角下的需求：订单从 PENDING 经 PAID、SHIPPED 到 COMPLETED 的全链路状态流转在真实用户路径下可达，每个状态对应的前端按钮与后端接口协同正确。
Gate Items：

- Gate：`e2e gate`
  Covers：订单状态流转端到端路径
  Assertions：
  1. 用户下单成功 → status=PENDING → 点「去支付」→ `PUT /orders/:id/pay` 200 → status=PAID → paidAt 非空
  2. Admin 发货 `POST /admin/orders/:id/ship` body `{company, trackingNo}` → status=SHIPPED → ShippingEntity 记录存在 → shippedAt 非空
  3. 用户点「确认收货」`PUT /orders/:id/confirm` → status=COMPLETED
  4. COMPLETED 订单详情页显示「去评价」入口（链接到 P2-2 评价模块）

#### L4-2

PARENT_ID：ROOT
视角下的需求：退款申请→Admin 审批（通过/拒绝）的完整闭环在真实路径下行为正确，通过则库存回补+券解绑，拒绝则订单恢复 prevStatus。
Gate Items：

- Gate：`e2e gate`
  Covers：退款审批闭环
  Assertions：
  1. PAID 订单用户申请退款 `POST /orders/:id/refund` body `{reason}` → status=REFUNDING → RefundEntity(status=0, prevStatus=PAID) 创建
  2. Admin 通过 `POST /admin/refunds/:id/approve` → status=REFUNDED → 对应商品 stock 回补 → 若订单有用券，UserCoupon.usedAt 清空
  3. Admin 拒绝 `POST /admin/refunds/:id/reject` body `{adminNote}` → status 恢复为 RefundEntity.prevStatus → RefundEntity.status=2 + adminNote 写入

#### L4-3

PARENT_ID：ROOT
视角下的需求：用户在 Checkout 选择优惠券 → preview 返回 discountAmount → 提交订单 totalAmount 正确扣减 → 取消订单或退款通过时券解绑可再次使用。
Gate Items：

- Gate：`e2e gate`
  Covers：优惠券下单抵扣全链路
  Assertions：
  1. Checkout 调 `POST /coupons/preview` body `{couponId, items}` → 返回 `{discountAmount, totalAfterDiscount}` 与类型规则（满减/折扣/无门槛）一致
  2. `POST /orders` body 含 couponId → 成功后 OrderEntity.totalAmount = subtotal - discountAmount（≥0）→ UserCoupon.usedAt 非空 + orderId 写入
  3. `PUT /orders/:id/cancel` 成功后 → UserCoupon.usedAt 清空 + orderId 清空（券可再用）
  4. 退款通过后 → 同上券解绑

#### L4-4

PARENT_ID：ROOT
视角下的需求：用户完成订单后能批量评价商品，评价在商品详情页对外可见（含用户昵称/头像），同一订单同一商品不可重复评价。
Gate Items：

- Gate：`e2e gate`
  Covers：评价闭环
  Assertions：
  1. COMPLETED 订单调 `POST /orders/:id/reviews` body `{reviews:[{productId,rating,content}]}` → 成功 → ReviewEntity 创建
  2. 再次评价同一订单相同 productId → 抛 REVIEW_EXISTS（40701）
  3. 商品详情页 `GET /products/:id/reviews` 返回列表含评价者昵称/头像 + 分页元信息

#### L4-5

PARENT_ID：ROOT
视角下的需求：Admin 在商品/Banner 表单中通过上传组件选择图片 → 调 `/upload/image` → 返回 url 写入字段 → 预览可见。
Gate Items：

- Gate：`e2e gate`
  Covers：图片上传端到端
  Assertions：
  1. AdminProducts 表单选择 ≤2MB 图片 → 上传成功 → image 字段写入 `/uploads/xxx.jpg` → 预览显示
  2. AdminBanners 表单同上

#### L3-1

PARENT_ID：L4-1
视角下的需求：订单状态机的非法流转在接口契约层被拒绝，覆盖 pay/ship/confirm/refund 4 个入口与 7 个状态的合法/非法矩阵。
Gate Items：

- Gate：`contract gate`
  Covers：订单状态流转接口契约
  Assertions：
  1. `PUT /orders/:id/pay` 对非 PENDING 状态返回 ORDER_STATUS_ERROR（40402）
  2. `POST /admin/orders/:id/ship` 对非 PAID 状态返回 40402
  3. `PUT /orders/:id/confirm` 对非 SHIPPED 状态返回 40402
  4. `POST /orders/:id/refund` 对非 PAID 且非 SHIPPED 状态返回 40402
  5. `POST /admin/refunds/:id/approve` 对 refund.status≠0 返回 40402
  6. `POST /admin/refunds/:id/reject` 对 refund.status≠0 返回 40402

#### L3-2

PARENT_ID：L4-3
视角下的需求：优惠券并发核销场景下不出现重复使用，事务内行锁保证同一 UserCoupon 不会被两个并发订单同时核销。
Gate Items：

- Gate：`integration gate`
  Covers：优惠券并发核销
  Assertions：
  1. 并发两个 `POST /orders` 携带同一 couponId → 至多一个成功，另一个抛 COUPON_USED（41003）
  2. 单订单核销后 UserCoupon.usedAt 非空、orderId 非空

#### L3-3

PARENT_ID：ROOT
视角下的需求：商品多维筛选（minPrice/maxPrice/origin/sortBy）的 Redis cacheKey 必须包含全部筛选维度，避免不同筛选命中同一缓存。
Gate Items：

- Gate：`contract gate`
  Covers：多维筛选缓存契约
  Assertions：
  1. 同一 page/limit 下不同 minPrice 命中不同 cacheKey
  2. 同一条件下不同 sortBy（price_asc/price_desc/sales_desc/created_desc）命中不同 cacheKey
  3. 商品 create/update/remove 触发 `products:*` 通配清理，覆盖新维度缓存

#### L3-4

PARENT_ID：ROOT
视角下的需求：地址簿「设为默认」在并发请求下保证每用户至多一条 isDefault=true。
Gate Items：

- Gate：`integration gate`
  Covers：地址默认值并发唯一性
  Assertions：
  1. 并发两个 `PUT /addresses/:id/default`（不同 addressId）→ 最终仅一条 isDefault=true
  2. 设默认事务内先 UPDATE 全置 false 再设目标为 true

#### L3-5

PARENT_ID：L4-4
视角下的需求：评价并发提交场景下 `(orderId, productId)` 唯一约束防重复，DB 层 Unique 约束生效。
Gate Items：

- Gate：`schema gate`
  Covers：评价唯一约束
  Assertions：
  1. ReviewEntity 表存在 Unique(orderId, productId)
  2. 并发两个相同 (orderId, productId) 的 INSERT → 第二个抛 duplicate key 错误

#### L2-1

PARENT_ID：L3-1
视角下的需求：OrderService 的 pay/ship/confirm/refund/approveRefund/rejectRefund 方法对当前状态分支的判定符合状态机定义（合法流转放行、非法抛 ORDER_STATUS_ERROR）。
Gate Items：

- Gate：`unit gate`
  Covers：状态机分支判定
  Assertions：
  1. pay 仅放行 PENDING，其他状态抛错
  2. ship 仅放行 PAID
  3. confirm 仅放行 SHIPPED
  4. refund 仅放行 PAID 或 SHIPPED
  5. approveRefund 仅放行 refund.status=0
  6. rejectRefund 仅放行 refund.status=0
  7. cancel 仍仅放行 PENDING（REFUNDING 不可 cancel）

#### L2-2

PARENT_ID：L4-3
视角下的需求：优惠券折扣计算规则按 type 分支正确（0=满减、1=折扣、2=无门槛），含 minAmount 门槛校验与 categoryId 适用范围。
Gate Items：

- Gate：`unit gate`
  Covers：优惠券计算分支
  Assertions：
  1. type=0 + subtotal≥minAmount → discount = discountAmount
  2. type=0 + subtotal<minAmount → 抛 COUPON_MIN_NOT_MET（41005）
  3. type=1 + subtotal≥minAmount → discount = subtotal * (1 - discountRate)
  4. type=2 → discount = discountAmount（无门槛）
  5. categoryId 非空时仅该分类商品小计参与门槛校验

#### L2-3

PARENT_ID：L4-2
视角下的需求：退款拒绝时 OrderEntity.status 恢复为 RefundEntity.prevStatus（PAID 或 SHIPPED），不误恢复为其他状态。
Gate Items：

- Gate：`unit gate`
  Covers：退款拒绝状态恢复
  Assertions：
  1. refund.prevStatus=PAID → reject 后 order.status=PAID
  2. refund.prevStatus=SHIPPED → reject 后 order.status=SHIPPED
  3. reject 不改动库存（与 approve 的回补区分）

#### L2-4

PARENT_ID：ROOT
视角下的需求：分类删除时校验是否有关联在售商品，有则拒绝并返回业务码 41201。
Gate Items：

- Gate：`unit gate`
  Covers：分类删除校验
  Assertions：
  1. 关联商品数 >0 → 抛 CATEGORY_HAS_PRODUCTS（41201），不执行 delete
  2. 关联商品数 =0 → 成功 delete + 清 `categories:all` 缓存

#### L2-5

PARENT_ID：L4-5
视角下的需求：上传接口的 MIME 与 size 校验按分支正确拒绝非法文件。
Gate Items：

- Gate：`unit gate`
  Covers：上传校验分支
  Assertions：
  1. file.size > 2MB → 抛 UPLOAD_FILE_TOO_LARGE（41101）
  2. file.mimetype 不以 `image/` 开头 → 抛 UPLOAD_INVALID_TYPE（41102）
  3. file 为空 → 抛 UPLOAD_FAILED（41103）
  4. 合法文件 → 返回 `/uploads/<filename>`

#### L2-6

PARENT_ID：L3-3
视角下的需求：销量排序的 OrderItem 聚合 SQL 正确计算每商品销量，未售商品销量为 0 排在后面。
Gate Items：

- Gate：`unit gate`
  Covers：销量聚合 SQL
  Assertions：
  1. 商品 A 有 2 单（各 3 件、5 件）、商品 B 无订单 → A 销量=8、B 销量=0
  2. sortBy=sales_desc → A 在 B 之前
  3. COALESCE(sales, 0) 处理无订单商品

#### L1-1

PARENT_ID：ROOT
视角下的需求：shared 包新增的 Order 枚举值、7 个新类型文件、6 段业务码必须成功编译进 dist，否则 server 拉到旧 dist 导致运行时错误。
Gate Items：

- Gate：`build gate`
  Covers：shared 编译完整性
  Assertions：
  1. `pnpm --filter shared build` 成功无 tsc 错误
  2. dist/constants.js 含新增业务码（40601-41299 段）
  3. dist/types/order.js 含 REFUNDING=5/REFUNDED=6

#### L1-2

PARENT_ID：L3-1
视角下的需求：OrderStatus 枚举追加 REFUNDING/REFUNDED 后，所有 switch/if 分支对枚举的判定必须穷举（避免漏处理新状态）。
Gate Items：

- Gate：`type-check gate`
  Covers：枚举穷举
  Assertions：
  1. OrderService 中对 OrderStatus 的判定分支 tsc 通过（无 fallthrough 隐患）
  2. 前端 STATUS_LABELS / STATUS_TABS 含全部 7 个状态（type 层校验）

### Self-Review 自检结果

1. **可追溯**：每个 Level Item 均可追溯到 spec 第 5-9 节具体子项 + 第 10 节业务码段 + 第 11 节验收场景
2. **不复述父项**：L2/L3 子项均提供了独立证明视角（分支矩阵/并发/SQL/缓存键），不复述 L4
3. **跨层不重复 oracle**：L4 e2e 仅证路径可达，错误码矩阵与分支判定下沉到 L3 契约 + L2 单元
4. **L4 不穷举**：L4 仅保留代表路径，无错误码/字段矩阵穷举
5. **无凭空发明**：所有状态/字段/业务码均来自 spec 第 5-10 节，未引入新行为

## 15. 后续步骤

1. 用户评审本设计文档（含 GDD 段）
2. 进入 `sprint-contract` 协商 Definition of Done
3. 进入 `writing-plans` 产出实施计划（按 5 组分阶段，每阶段含 checkpoint，task 与 GDD assertions 一一对应）
4. Subagent-Driven Development 执行实施
