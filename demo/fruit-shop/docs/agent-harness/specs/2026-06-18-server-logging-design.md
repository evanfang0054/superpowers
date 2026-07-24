# 服务端日志系统设计

- **日期**：2026-06-18
- **状态**：已通过设计评审，待用户最终复核
- **范围**：`packages/server`（NestJS 10）

## 1. 背景与目标

当前 `packages/server` 仅在 `HttpExceptionFilter` 的「未知异常」分支使用 `@nestjs/common` 内置 `Logger`，无统一日志体系，存在以下排查盲区：

- 无 access log，无法定位「某个请求是不是真的打到服务端、耗时多久、状态码是多少」
- 业务异常（HttpException）被吞，只有 HTTP 200 响应，服务端无任何痕迹
- 关键业务事件（下单、JWT 签发/吊销）无显式埋点
- 无 requestId，多用户并发时无法区分日志归属
- 慢请求无法快速发现

**目标**：补齐服务端日志能力，让开发者能根据日志完成常见排查（请求链路、错误定位、关键业务事件、慢请求识别），同时严守敏感信息不落盘。

**非目标**（明确不做）：

- 不接入 ELK / Loki / 阿里云 SLS 等外部日志聚合
- 不写本地滚动文件
- 不引入 OpenTelemetry / APM
- 不加分布式链路追踪（单服务无需求）

## 2. 设计决策

### 2.1 技术选型：nestjs-pino

| 候选                    | 周下载量 | 维护活跃度     | 关键能力                                    | 取舍                                  |
| ----------------------- | -------- | -------------- | ------------------------------------------- | ------------------------------------- |
| **nestjs-pino**（采用） | ~205 万  | 3 个月内有更新 | 原生 request context、HTTP 自动日志、高性能 | 依赖 pino-http、pino-pretty（dev）    |
| nest-winston            | ~100 万  | 1 年前最后更新 | 功能完整但 request context 需自研           | 需手动搭 access log                   |
| 自研 Logger             | —        | —              | 零依赖                                      | 无法覆盖 access log / request context |

社区调研结论（[npm trends](https://npmtrends.com/nest-winston-vs-nestjs-logger-vs-nestjs-pino) + Awesome NestJS 推荐）：nestjs-pino 是 2025 年 NestJS 日志的主流方案，性能约为 winston 的 3-5 倍，内置 `pino-http` 提供 HTTP access log 与 request context 自动注入，是当前最优选。

**新增依赖**：

- `nestjs-pino`（生产）
- `pino-http`（生产，nestjs-pino 依赖）
- `pino-pretty`（devDependencies，仅开发环境人类可读输出）

### 2.2 输出目标

- **生产**：stdout，JSON 格式（容器/PM2 统一收集）
- **开发**：stdout，`pino-pretty` 着色（`colorize: true`）
- **不写文件、不接外部服务**（YAGNI）

### 2.3 日志级别

- 通过环境变量 `LOG_LEVEL` 控制（`debug | info | warn | error`）
- 默认 `info`
- `.env.example` 新增条目：`LOG_LEVEL=info`

## 3. 架构：三层日志能力

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: HTTP Access Log（自动）                        │
│  pino-http 中间件                                        │
│  记录每个请求的 method/url/status/responseTime/ip/       │
│  userId/requestId，慢请求 (>500ms) 自动标记 slow:true    │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│  Layer 2: 全局错误日志（自动）                            │
│  HttpExceptionFilter 内调用 PinoLogger                   │
│  - 业务异常（HttpException） → warn + 上下文              │
│  - 未知异常                → error + 完整 stack           │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│  Layer 3: 关键业务事件（手动）                            │
│  service 注入 PinoLogger，显式 logger.log/warn           │
│  首批示范点：                                            │
│  - order.service：下单成功（含订单号、金额）               │
│  - auth.service：登录成功 / JWT 签发 / JWT 吊销           │
└─────────────────────────────────────────────────────────┘
```

三层之间通过 `requestId` 串联：pino-http 在请求进入时生成 UUID 写入 `req.id`，后续 Layer 2/3 中所有 `PinoLogger` 调用自动携带同一 `requestId`，实现端到端链路追踪。

## 4. 文件结构

```
packages/server/src/
├── common/
│   └── logging/
│       ├── logging.module.ts          # LoggerModule.forRoot 异步配置
│       ├── pino.config.ts             # pino 配置工厂（级别/pretty/serializers）
│       └── redact.serializer.ts       # 敏感字段脱敏 + 手机号/邮箱马赛克
├── main.ts                            # 注册 PinoLogger 作为全局 Logger
├── common/filters/
│   └── http-exception.filter.ts       # 改用 PinoLogger，分级别输出
└── modules/
    ├── order/order.service.ts         # 业务事件日志示范点
    └── auth/auth.service.ts           # 业务事件日志示范点
```

## 5. 关键配置（pino.config.ts 伪代码）

```ts
{
  level: process.env.LOG_LEVEL || 'info',
  transport: isDev
    ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:standard' } }
    : undefined,
  serializers: {
    req: customReqSerializer,
    res: customResSerializer,
  },
  customProps: (req) => ({
    requestId: req.id,
    userId: req.user?.id,
  }),
  redact: {
    paths: [
      'req.headers.authorization',
      'req.body.password',
      'req.body.oldPassword',
      'req.body.newPassword',
      'req.body.token',
      'req.body.refreshToken',
      'res.body.accessToken',
      'res.body.refreshToken',
    ],
    censor: '***',
  },
  customSuccessMessage: (req, res, time) =>
    time > 500 ? `${req.method} ${req.url} ${res.statusCode} ${time}ms [SLOW]`
               : `${req.method} ${req.url} ${res.statusCode} ${time}ms`,
}
```

## 6. 脱敏清单

| 类别         | 字段                                     | 处理方式                                           |
| ------------ | ---------------------------------------- | -------------------------------------------------- |
| Header       | `authorization`                          | pino `redact.paths` → `***`                        |
| Body 密码    | `password`、`oldPassword`、`newPassword` | pino `redact.paths` → `***`                        |
| Body token   | `token`、`refreshToken`                  | pino `redact.paths` → `***`                        |
| 个人信息     | `phone`、`email`                         | 自定义 serializer，`138****8888` / `ev***@***.com` |
| 响应中 token | `data.accessToken`、`data.refreshToken`  | pino `redact.paths` → `***`                        |

实现：

- `redact.serializer.ts` 导出 `redactPaths`（数组，直接喂给 pino 配置）
- 同文件导出 `maskPersonalData(obj)` 函数，在 `customReqSerializer` / `customResSerializer` 中递归处理 body

## 7. 改造点清单

### 7.1 main.ts（最小改动）

```ts
const app = await NestFactory.create(AppModule, { bufferLogs: true });
// 替换内置 Logger
app.useLogger(app.get(PinoLogger));
```

保留启动端口日志（用 `app.get(PinoLogger).log(...)` 替换现有 `console.log`）。

### 7.2 HttpExceptionFilter（替换 Logger）

- 现状：仅「未知异常」分支记录，且用 `@nestjs/common` 内置 Logger
- 改造后：
  - 注入 `PinoLogger`
  - **业务异常**（HttpException）→ `logger.warn`，记录 `code` / `message` / `path` / `requestId`
  - **未知异常** → `logger.error`，记录完整 stack（保持现有 `Unhandled exception` 文案）

### 7.3 业务日志示范点

仅覆盖两个 service，作为示范模板，其余按需扩展：

**order.service.ts**（下单成功）：

```ts
this.logger.log({ orderId: order.id, userId, totalAmount }, '订单创建成功');
```

**auth.service.ts**：

- 登录成功：`logger.info({ userId }, '用户登录成功')`
- JWT 签发：`logger.debug({ userId, jti }, 'JWT 签发')`
- JWT 吊销（登出）：`logger.info({ userId, jti }, 'JWT 已加入黑名单')`

## 8. 风险与取舍

| 风险                               | 处理                                                               |
| ---------------------------------- | ------------------------------------------------------------------ |
| `pino-pretty` 误装到生产           | 仅在 `devDependencies`，生产 `transport: undefined`                |
| 现有 `console.log`（`main.ts:40`） | 替换为 `PinoLogger` 启动日志                                       |
| 业务日志铺满所有 service           | 仅示范 `order/auth` 两个，其余按需扩展，避免一次性铺满             |
| 异步日志吞吐瓶颈                   | 当前不启用 async 模式（YAGNI），同步更易调试                       |
| 与 `TransformInterceptor` 冲突     | 无冲突 — 拦截器只改响应体，不影响 pino 记录的原始请求/响应数据     |
| `DB_LOGGING` 已存在                | 不重叠 — TypeORM 自身 logger 独立处理 SQL，本设计不新增 SQL 日志层 |
| Redis 操作日志                     | 不打日志（YAGNI）— 仅用于 JWT 黑名单，操作极轻                     |

## 9. 测试策略

由于项目当前无测试框架，本设计的测试策略遵循现有约定：

- 手动验证为主：启动服务，发起各类请求（成功/业务异常/未知异常），人工核对日志输出
- 验证项清单：
  - [ ] 正常请求 access log 含 `requestId / userId / method / url / statusCode / responseTime`
  - [ ] 慢请求（模拟 sleep 600ms）标记 `slow` / `[SLOW]`
  - [ ] 业务异常输出 `warn` 级别 + `code`
  - [ ] 未知异常输出 `error` 级别 + stack
  - [ ] 注册接口的 `password` 字段在日志中显示为 `***`
  - [ ] 登录接口响应中的 `accessToken` 在日志中显示为 `***`
  - [ ] `LOG_LEVEL=debug` 时可看到 JWT 签发日志
  - [ ] 响应头含 `X-Request-ID`，与日志中的 `requestId` 一致

## 10. 实施分步

1. 安装依赖：`pnpm --filter server add nestjs-pino pino-http && pnpm --filter server add -D pino-pretty`
2. 新建 `common/logging/` 目录及 3 个文件
3. 改造 `main.ts`（注册 PinoLogger）
4. 改造 `HttpExceptionFilter`
5. 改造 `order.service`、`auth.service`（注入 PinoLogger + 业务事件埋点）
6. 更新 `.env.example`（`LOG_LEVEL`）
7. 手动验证清单全部通过
