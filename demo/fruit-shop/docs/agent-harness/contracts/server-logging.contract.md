# Sprint Contract: 服务端日志系统

- **关联 Spec**：`docs/agent-harness/specs/2026-06-18-server-logging-design.md`
- **协商日期**：2026-06-18

## Definition of Done

- [ ] **D1** 启动日志：`pnpm --filter server dev` 启动后，stdout 第一行输出运行端口（`http://localhost:3000`），格式为 JSON（`NODE_ENV=production`）/ pretty（默认开发）
- [ ] **D2** Access log 字段完整性：访问任意 API，stdout 输出一条 access log，字段含 `requestId / method / url / statusCode / responseTime / ip`；`userId` 在已认证请求中为数字，未认证请求中字段缺失（undefined）
- [ ] **D3** X-Request-ID 串联：`curl -i http://localhost:3000/api/products` 响应头含 `X-Request-ID: <uuid>`，且 grep 该 uuid 能在 stdout 中找到对应 access log 行
- [ ] **D4** 业务异常 warn：构造业务异常（如重复注册、参数校验失败），stdout 出现 `level: warn` 日志，含 `code` 与 `message`
- [ ] **D5** 未知异常 error：构造未知异常（临时在 controller 抛 `new Error('test')`），stdout 出现 `level: error` 日志，含完整 stack
- [ ] **D6** 请求脱敏：注册接口 `/api/auth/register` 请求日志中 `body.password` 显示为 `***`；`headers.authorization` 显示为 `***`
- [ ] **D7** 响应脱敏：登录接口 `/api/auth/login` 的响应 body 不被日志记录（res serializer 仅输出 statusCode），token 永不落盘。若未来 res serializer 扩展输出 body，redact.paths 中 `res.body.*` 路径自动接管脱敏
- [ ] **D8** 慢请求标记：人为延迟 > 500ms 的接口，access log 的 message 含 `[SLOW]`，且 `responseTime > 500`
- [ ] **D9** 下单业务日志：完成下单（响应 `code:0`），stdout 出现 `level: info` 日志含 `orderId / userId / totalAmount`，`requestId` 与对应 access log 一致
- [ ] **D10** 认证业务日志：登录成功 → `info` 日志含 `userId`；登出 → `info` 日志含 `jti` 且标注「黑名单」
- [ ] **D11** 日志级别控制：
  - 默认 `LOG_LEVEL=info`：可见 access log + info 业务日志
  - `LOG_LEVEL=warn`：access log 与 debug 日志均消失，仅 warn/error 可见
  - `LOG_LEVEL=debug`：可见 JWT 签发 debug 日志
- [ ] **D12** 端到端回归：注册 → 登录 → 浏览商品 → 加购 → 下单 全流程 HTTP 200 + `code:0`，无 5xx，无未捕获异常日志
- [ ] **D13** TypeORM 兼容：`DB_LOGGING=true` 时 TypeORM SQL 日志照常输出（与 pino 日志并存，不冲突）

## Boundary Conditions

- **Must support**：NestJS 10、Node 20+、pnpm workspace、Docker（`docker compose up`）
- **Must not break**：API 响应格式 `{code,data,message}`、JWT 双 token 流程、全局守卫行为、TypeORM `synchronize`、Redis JWT 黑名单
- **依赖白名单**：仅 `nestjs-pino`、`pino-http`、`pino-pretty`（dev）

## Acceptance Criteria

- **Computational**：项目无测试框架，所有 DoD 以手动验证命令表达（见各 D 项）
- **Inferential**（人工）：开发者能在 5 分钟内凭日志回答「某次下单是否成功、由哪个用户发起、耗时多少、对应哪次 HTTP 请求」

## Negotiation Record

### Round 1 — Generator 初稿

13 条 DoD，覆盖 access log / error log / 脱敏 / 慢请求 / 业务日志 / 级别控制 / 回归。

### Round 2 — Evaluator 挑战

| 原条目                   | 挑战                                                                            | 修订                                     |
| ------------------------ | ------------------------------------------------------------------------------- | ---------------------------------------- |
| D2「未认证 userId 为空」 | "为空"语义模糊（null/undefined/缺失？）                                         | 明确为「字段缺失（undefined）」          |
| D3 X-Request-ID 一致性   | 验证方法不清                                                                    | 明确 `curl -i` + grep 命令               |
| D6/D7 脱敏               | 仅列 password/token，未覆盖 `authorization` header 与 `oldPassword/newPassword` | 合并为完整清单                           |
| D9 下单日志              | 「成功」判定不清                                                                | 明确 = 响应 `code:0`；失败场景由 D4 覆盖 |
| D11 LOG_LEVEL            | 缺一条：默认 info 下应见 access log                                             | 补充三条级别断言                         |
| D12 回归                 | 「无报错」太弱                                                                  | 明确为端到端购买流程全 `code:0`，无 5xx  |
| 缺失                     | 服务启动日志未列入（`console.log` 被替换后端口信息是否保留）                    | 补 D1                                    |
| 缺失                     | TypeORM SQL 日志兼容性未列入                                                    | 补 D13                                   |

### Round 3 — 最终共识

Generator 接受所有修订，Evaluator 无新挑战。最终 13 条 DoD 即上方清单。

## Out of Scope（明确不做）

- 不接 ELK / Loki / SLS
- 不写本地滚动文件
- 不引入 OpenTelemetry / APM
- 不加分布式链路追踪
- 不铺满所有 service（仅 order/auth 示范，其余按需扩展）
- 不启用 pino async 模式
