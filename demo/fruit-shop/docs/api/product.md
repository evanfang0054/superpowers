# Product API

## GET /api/products

商品列表（分页 + 筛选）。

- 守卫：无（隐式公开，受 Throttler 限制）
- 查询参数：

| 参数       | 类型   | 说明                   |
| ---------- | ------ | ---------------------- |
| page       | number | 默认 1                 |
| limit      | number | 默认 10                |
| categoryId | number | 按分类筛选             |
| keyword    | string | 按商品名 LIKE 模糊匹配 |

- 仅返回 `status = ON` 的商品
- 响应 `data`：`{ list: Product[], total, page, limit }`
- Redis 缓存：60s

## GET /api/products/:id

- 守卫：无
- 响应 `data`：`Product`
- Redis 缓存：60s
- 错误码：`40201 PRODUCT_NOT_FOUND`

## GET /api/products/recommendations

商品推荐位（MVP 算法：最新上架 + 在售 + 有库存）。

- 守卫：`@Public`
- 查询参数：

| 参数      | 类型   | 默认 | 说明                                        |
| --------- | ------ | ---- | ------------------------------------------- |
| limit     | number | 10   | 最大 20                                     |
| excludeId | number | -    | 排除指定商品 id（用于详情页"你可能还喜欢"） |

- 筛选条件：`status = ON AND stock > 0`，按 `createdAt DESC`
- 响应 `data`：`{ list: Product[] }`（不带分页）
- Redis 缓存：60s，key 含 limit 与 excludeId

## POST /api/products

- 守卫：JWT + ADMIN
- 请求体：`CreateProductDto`（详见 `packages/server/src/modules/product/dto/create-product.dto.ts`）
- 字段：name, origin, price, originalPrice?, unit, sweetness, weight, description?, tags?, image, color, categoryId, stock, status?
- 响应 `data`：新 Product

## PUT /api/products/:id

- 守卫：JWT + ADMIN
- 请求体：`UpdateProductDto`（所有字段可选）
- 响应 `data`：更新后的 Product
- 错误码：`40201 PRODUCT_NOT_FOUND`

## DELETE /api/products/:id

- 守卫：JWT + ADMIN
- 响应 `data`：`null`
