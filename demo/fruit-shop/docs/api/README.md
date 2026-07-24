# 鲜果集 RESTful API 总览

## Base URL

- 本地开发：`http://localhost:3000/api`
- 生产：`https://<domain>/api`
- 不带版本前缀（保持现状）

## 协议与编码

- HTTPS（生产）/ HTTP（本地）
- 请求/响应编码：UTF-8，Content-Type: application/json
- 文件上传接口：multipart/form-data

## 统一响应格式

成功（HTTP 200）：

```json
{ "code": 0, "data": <T>, "message": "success" }
```

错误（HTTP 200，业务码在 body）：

```json
{ "code": <非零业务码>, "message": "<中文消息>" }
```

注：除 Throttler / Health Check 外，所有错误均返回 HTTP 200，业务码在 `code` 字段中。

## 鉴权

- 除显式标注 `@Public` 的接口外，全部需 JWT Bearer
- Header：`Authorization: Bearer <accessToken>`
- 写操作（创建/修改/删除商品、分类、轮播、优惠券模板）需 `@Roles(ADMIN)`
- C 端业务（下单、地址、评价、收藏、优惠券、订单流转）一律需登录

## 业务错误码分段

| 区间        | 模块   |
| ----------- | ------ |
| 40001-40099 | 认证   |
| 40101-40199 | 用户   |
| 40201-40299 | 商品   |
| 40301-40399 | 购物车 |
| 40401-40499 | 订单   |
| 40501-40599 | 库存   |

完整错误码见 `packages/shared/src/constants.ts`。

## 分页

查询参数：`?page=1&limit=20`

响应：`{ list: T[], total: number, page: number, limit: number }`

## 时间

ISO 8601 字符串，UTC+8（与 TypeORM 实体一致）。

## 限流

- 全局：60 次/60 秒
- 注册/登录：10 次/60 秒

## 日志与脱敏

- 复用 pino redact 机制
- 涉及手机号、地址、姓名等 PII 在业务层手动脱敏（pino redact 不覆盖自定义 logger 调用）

## 模块文档索引

- [auth.md](./auth.md)
- [user.md](./user.md)
- [product.md](./product.md)
- [category.md](./category.md)
- [cart.md](./cart.md)
- [order.md](./order.md)
