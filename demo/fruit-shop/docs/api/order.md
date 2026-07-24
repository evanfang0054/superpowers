# Order API

所有接口守卫：JWT。

## POST /api/orders

基于当前用户购物车生成订单（事务内执行：库存校验 → 扣减 → 生成订单 → 清购物车）。

- 请求体：

```json
{ "address": "北京市朝阳区...", "phone": "13800000001", "remark": "备注（可选）" }
```

- 校验：`address` ≤ 255；`phone` ≤ 20；`remark` ≤ 500
- 事务内逻辑：
  1. `SELECT ... FOR UPDATE` 锁定相关商品行
  2. 对每个购物车项校验 `quantity <= product.stock`
  3. 扣减每个商品 `stock`
  4. 生成订单（status=PENDING）+ 订单项（快照商品名/规格/价格/图片）
  5. 清空当前用户购物车
- 响应 `data`：`{ ...order, items: OrderItem[] }`
- 错误码：
  - `40303 CART_EMPTY` 购物车为空
  - `40501 STOCK_INSUFFICIENT` 库存不足（整笔事务回滚）

## GET /api/orders

- 查询参数：`status`（可选，0-4）、`page`、`limit`
- 响应 `data`：`{ list: Order[], total, page, limit }`

## GET /api/orders/:id

- 响应 `data`：`{ ...order, items: OrderItem[] }`
- 错误码：`40401 ORDER_NOT_FOUND`

## PUT /api/orders/:id/cancel

取消订单（仅 `PENDING` 可取消）。

- 事务内：订单状态 → CANCELLED + 回补对应商品 stock
- 响应 `data`：`{ ...order, items }`
- 错误码：
  - `40401 ORDER_NOT_FOUND`
  - `40403 ORDER_CANCEL_NOT_ALLOWED` 仅待付款订单可取消

## 订单状态枚举

| 值  | 名称      | 说明              |
| --- | --------- | ----------------- |
| 0   | PENDING   | 待付款            |
| 1   | PAID      | 已付款（P1 实现） |
| 2   | SHIPPED   | 已发货（P1 实现） |
| 3   | COMPLETED | 已完成（P1 实现） |
| 4   | CANCELLED | 已取消            |
