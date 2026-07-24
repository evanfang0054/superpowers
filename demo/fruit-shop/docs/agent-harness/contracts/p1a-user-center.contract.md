# Sprint Contract: P1-A 用户中心

## Definition of Done

### 路由与死代码清理

- [ ] 删除 `packages/web/src/router/ProtectedRoute.tsx` 与 `packages/web/src/router/AdminRoute.tsx`（全代码搜索无 import 引用）
- [ ] `packages/web/src/router/index.tsx` 内联 `ProtectedRoute` 补 `useLocation` + `state={{ from: location }}`，未登录跳 `/login` 时携带来源路径
- [ ] 新增 `/profile` 路由，用内联 `ProtectedRoute` 包裹，`React.lazy` 懒加载 `@/pages/Profile`
- [ ] 回归验证：未登录访问 `/cart`、`/orders`、`/order/:id`、`/admin/products`、`/profile` 均跳 `/login` 且登录后能回到原页面（state.from 生效）

### auth store logout async 改造

- [ ] `packages/web/src/store/auth.store.ts` 的 `logout` 改为 async，先 `try { await authApi.logout() } catch {}`（动态 import 规避循环依赖），再 `set({ user: null, token: null, refreshToken: null, error: null })`
- [ ] `packages/web/src/api/client.ts` 401 兜底改为直接 `useAuthStore.setState({ user: null, token: null, refreshToken: null, error: null })` + `window.location.href = '/login'`（不调后端 logout，token 已失效）
- [ ] TypeScript：`pnpm --filter web build` 通过，无类型错误

### App.tsx 启动刷新

- [ ] `packages/web/src/App.tsx` 新增 `useEffect`，依赖 `[token]`，仅当 `token` 存在时调 `useAuthStore.getState().refreshUserInfo()`
- [ ] 场景 A 验证：登录后刷新浏览器 → Network 看到 `GET /api/user/profile` 200 → store user 字段为后端最新值
- [ ] 场景 B 验证：未登录刷新浏览器 → Network 无 `/api/user/profile` 请求

### Profile 页 + Avatar 组件 + TabBar

- [ ] 新建 `packages/web/src/components/Avatar.tsx`：props `{ src?, alt?, size? }`；src 为空或 onError 时显示 alt 首字（无则 🍊 emoji）；`rounded-full border border-brand-border`，size 默认 56
- [ ] 新建 `packages/web/src/pages/Profile.tsx`：
  - 顶部 sticky header「个人中心」+ 主卡片（Avatar 72px + 昵称 22px/900 + 脱敏手机号 📱 138****1234 + admin 角色标签 + 编辑资料 PrimaryButton + 退出登录 SecondaryButton 边框 coral）
  - 行内编辑：点「编辑资料」→ 昵称转 input（maxLength=50, autofocus）+ 保存/取消按钮；保存调 `userApi.updateProfile({ nickname })` → 成功更新 store + toast「资料已更新」+ 退出编辑态；失败 toast「更新失败，请重试」保留编辑态
  - 登出：点「退出登录」→ `await logout()` → `navigate('/login', { replace: true })`
  - 底部渲染 `<TabBar />`
- [ ] `packages/web/src/components/TabBar.tsx` 新增第 4 tab：`{ to: '/profile', icon: '👤', label: '我的' }`，激活判定 `location.pathname.startsWith('/profile')`
- [ ] 场景 C 验证：登录后点 TabBar「我的」→ 进入 `/profile`，显示头像/昵称/脱敏手机号；admin 账号额外显示「管理员」标签
- [ ] 场景 D 验证：点「编辑资料」→ 改昵称 → 保存 → Network `PUT /api/user/profile` 200 → input 转 text + toast 成功 + 顶部昵称更新
- [ ] 场景 E 验证：点「退出登录」→ Network `POST /api/auth/logout` 200 → 跳 `/login` → store 清空
- [ ] 场景 F 验证（已有后端 e2e）：登出后用旧 token 调 API 返回 401
- [ ] 场景 G 验证：在 `/profile` 时 TabBar「我的」高亮 `text-brand-primary`，其他 tab 不高亮
- [ ] 场景 H 验证：DB 将某用户 avatar 设为 null → Profile 页 Avatar 显示 nickname 首字（无 nickname 显示 🍊）

## Boundary Conditions

- **Must not break**: 现有路由 `/`、`/product/:id`、`/cart`、`/checkout`、`/orders`、`/order/:id`、`/login`、`/register`、`/admin/products` 的访问与鉴权
- **Must not break**: 现有 401 自动 refresh + 跳转 `/login` 流程（client.ts 拦截器）
- **Must not break**: `fruit-shop-auth` localStorage persist key 与 `partialize` 仅持久化 `token/refreshToken/user` 的契约
- **Must support**: React 18 StrictMode 下 useEffect 双调用（refreshUserInfo 幂等可接受）
- **Must support**: 循环依赖规避（auth.store ↔ user.ts ↔ client.ts ↔ auth.store），沿用动态 import 模式
- **Must support**: 用户离线时登出仍能清前端状态（authApi.logout 失败容错）
- **UI 一致性**: Profile 页色彩/圆角/字体遵循 DESIGN.md（canvas 背景、白色卡片 24px 圆角、border-brand-border、Fredoka+Noto Sans SC）
- **性能**: 启动刷新只发 1 次 `/user/profile` 请求（StrictMode 下开发环境 2 次可接受）

## Acceptance Criteria

### Computational（可执行验证）

- **TypeScript 构建**: `pnpm --filter web build` 成功无错误
- **后端 e2e 回归**: `pnpm --filter server test:e2e` 全部通过（auth.e2e 含 logout 黑名单场景 F）
- **后端 unit 回归**: `pnpm --filter server test` 全部通过（P1-A 不改后端，但确认无意外影响）
- **shared 构建**: `pnpm --filter shared build` 成功（P1-A 不改 shared，但确认无副作用）
- **手动场景 A-H**: docker compose 环境浏览器走查，全部符合预期

### Inferential（review 验证）

- spec reviewer review `router/index.tsx`：内联 ProtectedRoute 补 state.from 后，5 个受保护路由的鉴权与回跳行为一致
- spec reviewer review `auth.store.ts`：logout async 化 + 动态 import 循环依赖规避正确
- spec reviewer review `client.ts`：401 兜底不调后端 logout 的判断成立（token 已被后端拒绝）
- spec reviewer review `Profile.tsx`：行内编辑状态机（isEditing/saving/nickname）无竞态；登出后 navigate replace 不污染历史栈
- spec reviewer review `Avatar.tsx`：onError fallback 不会无限重渲染（errored 状态稳定）

## Negotiation Record

- **Generator Round 1**: 初稿 6 条 DoD，覆盖路由清理/logout async/启动刷新/Profile 页/TabBar，每条以「实现 + 场景 X 验证」描述
- **Evaluator Round 1 挑战**:
  1. 「实现」与「验证」混在一起不可执行 —— 拆为「实现项」（文件 + 行为）与「场景项」（A-H 触发路径 + Network 观察）
  2. 「logout async」未说明 client.ts 兼容性 —— 显式列出 401 兜底改为直接清前端
  3. 「启动刷新」未说明 StrictMode 双调用 —— 列入 Boundary
  4. 「Profile 页」内容描述太笼统 —— 明确字段（Avatar 72px、昵称 22px/900、脱敏手机号、admin 标签、PrimaryButton/SecondaryButton）
  5. 「Avatar fallback」未说明 onError 无限循环风险 —— Inferential 加入 onError 稳定性检查
  6. 「死代码清理」未说明回归 —— 列出 5 个受保护路由的回跳回归验证
  7. 「TabBar 激活」未说明子路由 —— 激活判定用 startsWith（虽然 P1-A 无子路由，保持一致性）
  8. 缺 TypeScript / 后端回归 Computational —— 补 web build + server e2e + server unit + shared build
- **Generator Round 2 修订**: 拆分为「路由与死代码清理 / logout async / 启动刷新 / Profile+Avatar+TabBar」四组；每条 DoD 绑定到具体场景 A-H；Boundary 覆盖 StrictMode/循环依赖/离线登出/UI 一致性；Acceptance 含 4 项 Computational + 5 项 Inferential
- **Evaluator Round 2**: 接受。所有 criterion 可用 yes/no 验证；场景 A-H 有明确触发路径与观察点；Boundary 覆盖已知风险（StrictMode/循环依赖/离线/persist 契约）。
- **Final consensus**: 本文件当前版本。
