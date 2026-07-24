# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

鲜果集 — 水果电商全栈应用。pnpm workspace monorepo，三个包：`shared`（类型/枚举/错误码）、`server`（NestJS 10 + TypeORM + MySQL + Redis）、`web`（React 18 + Vite 6 + Tailwind v4 + Zustand）。

构建依赖链：`shared` → `server`、`shared` → `web`。改 shared 必须先 `pnpm --filter shared build`，否则 server 运行时会拉到旧 `dist`。

## 常用命令

```bash
# 开发（建议三个终端分别跑，可同时热更新）
pnpm --filter shared build        # 监听：pnpm --filter shared build --watch
pnpm --filter server start:dev    # http://localhost:3000, JWT 全局守卫
pnpm --filter web dev             # http://localhost:5177（非默认端口），/api → :3000

# 一键启动（根目录）
pnpm dev                          # 并行起 shared/server/web
pnpm build                        # 顺序构建 shared → server → web

# Docker（首次启动会自动执行 packages/server/init.sql 初始化种子数据）
docker compose up -d              # mysql:3306 / redis:6379 / server:3000 / web:80

# 数据库手动操作（注意 charset）
docker exec -i <mysql-container> mysql -uroot -proot123 --default-character-set=utf8mb4 fruit_shop < packages/server/init.sql
# ⚠️ 不要用 docker exec ... mysql -e "INSERT..." 直接塞中文/emoji —— 默认 latin1 客户端会把数据双重编码成乱码

# 清理
pnpm clean                        # 删除所有 dist 与 node_modules
```

无 ESLint / Prettier / 测试框架配置，目前 `lint` 与 `test` 脚本均为空。

## 架构要点

### shared（`packages/shared`）

- 纯 TypeScript，`tsc` 输出 CommonJS 到 `dist/`
- 单一事实源：`constants.ts`（`ErrorCode` 业务码 40001–40499）、`types/`（user/product/cart/order/api）
- server 通过 `tsconfig` paths 指向 `../shared/dist`；web 通过 Vite alias 指向 `../shared/src`（源码直读，无需先构建）

### server（`packages/server`）

NestJS 10，全局 API 前缀 `/api`。

- `main.ts`：全局 `ValidationPipe`（whitelist + forbidNonWhitelisted + transform）、`TransformInterceptor`（包装成 `{ code, data, message }`）、`HttpExceptionFilter`（错误也走 HTTP 200，业务码在 body 的 `code` 中）
- 5 个 feature module：`auth / user / product / cart / order`
- 6 个 TypeORM entity（`src/entities/`）；`synchronize: true`（开发用），timezone `+08:00`，charset `utf8mb4`
- 自定义装饰器：`@Public()`（跳过 JWT）、`@Roles(UserRole.ADMIN)`、`@CurrentUser()`
- Guards：`JwtAuthGuard`（默认全锁，按 `@Public()` 放行）、`RolesGuard`
- Redis：仅用于 JWT 退出黑名单，由全局 `RedisProviderModule` 提供
- 下单走 TypeORM transaction，成功后清空该用户购物车
- 注册时第一个用户自动获得 `ADMIN` 角色

### web（`packages/web`）

React 18 SPA，Vite 6，端口 **5177**。

- 入口：`main.tsx → App.tsx`（`RouterProvider` 包在 `ToastProvider` 中）
- 路由（`src/router/index.tsx`）：`createBrowserRouter` + `lazy()` 懒加载；受保护页面内联 `ProtectedRoute` / `AdminRoute` 读 Zustand auth store
- 状态管理 3 个 Zustand store：
  - `auth.store.ts` —— persist 到 localStorage key `fruit-shop-auth`
  - `cart.store.ts`、`order.store.ts` —— 非持久化
- API 层（`src/api/`）：`client.ts` Axios 实例，请求拦截器塞 Bearer token，响应拦截器遇 401 自动调 refresh 并排队重放
- 样式：Tailwind v4 经 `@tailwindcss/vite`；自定义 `brand-*` token 与旧 `primary/success/danger` token **共存**（新页面用 `brand-*`，旧页面继续用旧 token，避免回归）
- 路径别名：`@/` → `./src/`，`shared` → `../shared/src`

### 关键约定

- 响应格式统一：成功 `{ code: 0, data, message: "success" }`；错误 HTTP 200 + body 内业务 `code`
- 修改 shared 后必须重 build shared，否则 server 拉到旧 `dist`
- 静态设计模板在仓库根：`index.html`（首页）、`product-detail.html`（详情页）—— 前端 1:1 对齐目标

## 设计规范

前端 UI 实现必须严格遵循 `DESIGN.md`。该文件是鲜果集设计系统的唯一权威源，包含：

- **色彩 token**：暖橙色系画布 `#FFF8F0` + 主色 `#FF6B35`，12 个语义色（canvas / primary / secondary / accent / green / dark / muted / card / peach / coral / border / btn-bg）及对应使用比例
- **字体规则**：Display 层用 Fredoka（价格数字），Body 层用 Noto Sans SC（中文正文）。价格符号「¥」独立为 12-14px bold
- **组件样式规格**：NavBar、SearchBar、FruitCard、CategoryTab、PromoBanner、PrimaryButton、SecondaryButton、BuyBar、TabBar、SpecCard、QualityCard、Toast — 每个组件的背景色、边框、圆角、内边距、交互状态
- **布局原则**：移动优先 375px 基准，2 列商品网格，sticky NavBar + fixed BuyBar/TabBar + backdrop-blur 层级
- **Do's / Don'ts**：圆角 ≥ 8px、用边框不用阴影区分卡片、accent 色只用于 badge、禁止纯黑文字等

**涉及前端样式改动时，先读 `DESIGN.md` 再写代码。**

## 环境变量

server `packages/server/.env.example`：

- DB: `DB_HOST / DB_PORT / DB_USERNAME / DB_PASSWORD / DB_DATABASE / DB_LOGGING`
- Redis: `REDIS_HOST / REDIS_PORT`
- JWT: `JWT_SECRET / JWT_ACCESS_EXPIRES_IN`（默认 900s）`/ JWT_REFRESH_EXPIRES_IN`（默认 604800s）
- `PORT`（默认 3000）

web 通过 Vite `import.meta.env` 读取，主要在前缀 `/api` 上。

## 文档

- `README.md`（中文）—— 完整技术栈、项目结构、API、路由、Schema、认证流程
- `docs/agent-harness/specs/` 与 `docs/agent-harness/plans/` —— 历史任务规格与实施计划
- `.agent-harness/learnings.jsonl` —— session-learnings 记录的踩坑/模式

## 引擎要求

Node >= 20.0.0，pnpm >= 10.0.0。Dockerfile 用 `corepack prepare pnpm@10.27.0`。
