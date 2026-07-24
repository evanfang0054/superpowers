# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

鲜果集 web 前端 — 移动端优先的水果电商 SPA。React 18 + Vite 6 + Tailwind CSS v4 + Zustand + React Router v6。

## 常用命令

```bash
pnpm dev          # 开发服务器 http://localhost:5177（非默认端口），/api 代理到 :3000
pnpm build        # tsc -b && vite build
pnpm preview      # 预览生产构建
```

无 lint / test 脚本，无 ESLint / Prettier / 测试框架配置。

shared 包无需预先构建 — web 通过 Vite alias 直接读 `../shared/src` 源码。

## 架构

### 数据流

`src/api/` (Axios) → `src/store/` (Zustand) → `src/pages/` (React 组件) → `src/components/` (UI 组件)

### API 层 (`src/api/`)

- `client.ts` — Axios 单例，baseURL `/api`，15s 超时
  - 请求拦截器：从 auth store 注入 Bearer token
  - 响应拦截器：401 时自动 refresh，用队列机制（`isRefreshing` + `pendingRequests`）处理并发请求，refresh 失败则 logout 跳转 `/login`
- 各模块 (`auth.ts` / `user.ts` / `product.ts` / `cart.ts` / `order.ts`) 均使用 shared 包的 DTO 类型

### 状态管理 (`src/store/`)

| Store            | 持久化                         | 关键点                                        |
| ---------------- | ------------------------------ | --------------------------------------------- |
| `auth.store.ts`  | localStorage `fruit-shop-auth` | token + refreshToken + user                   |
| `cart.store.ts`  | 无                             | 每次 mutation 后调 `fetchCart()` 重同步服务端 |
| `order.store.ts` | 无                             | `fetchOrders` 支持追加（无限滚动）或替换      |

### 路由 (`src/router/index.tsx`)

`createBrowserRouter` + `React.lazy` 代码分割，所有页面用 `<Suspense>` 包裹。

- 公开：`/` (Home)、`/product/:id` (ProductDetail)、`/login`、`/register`
- 需登录：`/cart`、`/checkout`、`/orders`、`/order/:id` — 内联 `ProtectedRoute` 检查 token
- 需管理员：`/admin/products` — 内联 `AdminRoute` 检查 token + admin 角色

注意：`ProtectedRoute.tsx` 和 `AdminRoute.tsx` 独立文件存在但未被路由引用，路由内使用的是内联版本。

### 样式 (`src/styles/`)

Tailwind CSS v4 — 无 `tailwind.config.*` / `postcss.config.*`，全部在 CSS 中配置。

- `index.css` — `@theme` 定义品牌色 `brand-*` 与旧 token `primary/success/danger` **共存**。新页面用 `brand-*`，旧页面保留旧 token 避免回归
- `animations.css` — 自定义 keyframe + `@utility` 注册动画工具类（`animate-bounce-in`、`animate-float` 等）

### 路径别名

- `@/` → `./src/`
- `shared` → `../shared/src/`（源码直读，不同于 server 读 dist）

### 静态设计参考

仓库根目录 `index.html`（首页）、`product-detail.html`（详情页）— 前端 1:1 对齐目标。

## 关键约定

- API 响应格式：`{ code: 0, data, message: "success" }`，错误也走 HTTP 200，业务码在 body
- Tailwind 级联层：使用 `@layer` 时注意工具类优先级，避免被组件层覆盖导致不生效
- TypeScript strict 模式 + `noUnusedLocals` / `noUnusedParameters`
