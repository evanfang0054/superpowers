# User API

## GET /api/user/profile

- 守卫：JWT
- 响应 `data`：当前用户实体（不含 password）

```json
{
  "id": 1,
  "phone": "138****0001",
  "nickname": "...",
  "avatar": "...",
  "role": "user",
  "createdAt": "...",
  "updatedAt": "..."
}
```

## PUT /api/user/profile

- 守卫：JWT
- 请求体（字段全部可选）：

```json
{ "nickname": "新昵称", "avatar": "http://..." }
```

- 校验：`nickname` ≤ 50 字符；`avatar` ≤ 500 字符
- 响应 `data`：更新后的用户实体
