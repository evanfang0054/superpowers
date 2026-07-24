# Auth API

## POST /api/auth/register

注册新用户（首个用户自动获得 ADMIN 角色）。

- 守卫：`@Public`，限流 10 次/60 秒
- 请求体：

```json
{ "phone": "13800000001", "password": "abc123", "nickname": "昵称（可选）" }
```

- 校验：`phone` 匹配 `/^1[3-9]\d{9}$/`；`password` 长度 6-20
- 响应 `data`：

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "user": { "id": 1, "phone": "...", "nickname": "...", "avatar": null, "role": "user" }
}
```

- 错误码：`40102 PHONE_EXISTS` 手机号已注册

## POST /api/auth/login

- 守卫：`@Public`，限流 10 次/60 秒
- 请求体：`{ "phone": "...", "password": "..." }`
- 响应 `data`：同 register

- 错误码：`40001 AUTH_FAILED` 手机号或密码错误

## POST /api/auth/refresh

- 守卫：`@Public`
- 请求体：`{ "refreshToken": "..." }`
- 响应 `data`：`{ "accessToken": "..." }`（仅刷新 access，不续 refresh）

- 错误码：`40004 REFRESH_TOKEN_INVALID`

## POST /api/auth/logout

- 守卫：JWT
- 无 body
- 行为：将当前 access jti 加入 Redis 黑名单
- 响应 `data`：`null`
