# P1-A 用户中心 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 P1-A 用户中心：新建 `/profile` 页面（资料展示 + 行内编辑 + 登出）、启动时刷新 profile、TabBar 新增「我的」tab、登出调后端真登出、清理 ProtectedRoute/AdminRoute 死代码。

**Architecture:** 全部改动在 `packages/web`，无后端/shared 变更。四个独立单元：路由与死代码清理 → auth store logout async → App.tsx 启动刷新 → Profile 页 + Avatar 组件 + TabBar。无前端测试框架，采用 TypeScript 构建 + 后端 e2e 回归 + 手动场景 A-H 验证。

**Tech Stack:** React 18 + TypeScript + React Router v6 + Zustand + Tailwind v4。

**Contract:** `docs/agent-harness/contracts/p1a-user-center.contract.md` — 验收场景 A-H 与本计划任务一一对应。

---

## File Structure

**Create**

- `packages/web/src/pages/Profile.tsx` — 个人中心页（展示 + 行内编辑 + 登出）
- `packages/web/src/components/Avatar.tsx` — 头像组件（带 fallback）

**Modify**

- `packages/web/src/router/index.tsx` — 内联 ProtectedRoute 补 state.from + 新增 /profile 路由
- `packages/web/src/store/auth.store.ts` — logout 改 async + 调后端
- `packages/web/src/api/client.ts` — 401 兜底改为直接清前端状态
- `packages/web/src/App.tsx` — mount 时 refreshUserInfo（仅登录用户）
- `packages/web/src/components/TabBar.tsx` — 新增第 4 tab「我的」

**Delete**

- `packages/web/src/router/ProtectedRoute.tsx` — 死代码
- `packages/web/src/router/AdminRoute.tsx` — 死代码

---

## Task 1: 死代码清理 + 内联 ProtectedRoute 补 state.from

**Files:**

- Delete: `packages/web/src/router/ProtectedRoute.tsx`
- Delete: `packages/web/src/router/AdminRoute.tsx`
- Modify: `packages/web/src/router/index.tsx`

- [ ] **Step 1: 确认两个独立文件无 import 引用**

Run: `grep -r "from '@/router/ProtectedRoute'" packages/web/src/ ; grep -r "from '@/router/AdminRoute'" packages/web/src/ ; grep -r "from './ProtectedRoute'" packages/web/src/router/ ; grep -r "from './AdminRoute'" packages/web/src/router/`
Expected: 无任何输出（无 import 引用）

- [ ] **Step 2: 删除两个死代码文件**

```bash
rm packages/web/src/router/ProtectedRoute.tsx packages/web/src/router/AdminRoute.tsx
```

- [ ] **Step 3: 修改 router/index.tsx，内联 ProtectedRoute 补 state.from**

在 `packages/web/src/router/index.tsx` 中，将顶部 import 第一行改为（加 `useLocation`）：

```typescript
import { createBrowserRouter, Navigate, useLocation } from 'react-router-dom';
```

将 `ProtectedRoute` 函数（第 32-36 行）替换为：

```typescript
// 登录保护：未登录跳转到 /login，携带来源路径以便登录后回跳
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore((s) => s.token);
  const location = useLocation();
  if (!token) return <Navigate to="/login" replace state={{ from: location }} />;
  return <>{children}</>;
}
```

- [ ] **Step 4: 运行 web build，确认无类型错误**

Run: `pnpm --filter web build`
Expected: 构建成功，无 TS 错误

- [ ] **Step 5: Commit**

```bash
git add packages/web/src/router/
git commit -m "refactor(web): 删除死代码 ProtectedRoute/AdminRoute 独立文件，内联版补 state.from 回跳"
```

---

## Task 2: auth store logout async 改造 + client.ts 兼容

**Files:**

- Modify: `packages/web/src/store/auth.store.ts:16, 58-60`
- Modify: `packages/web/src/api/client.ts:85-86`

- [ ] **Step 1: 修改 auth.store.ts 的 AuthState 接口与 logout 实现**

在 `packages/web/src/store/auth.store.ts` 中：

第 16 行 `logout: () => void;` 改为：

```typescript
logout: () => Promise<void>;
```

第 58-60 行 `logout` 实现替换为：

```typescript
      logout: async () => {
        try {
          const { authApi } = await import('@/api/auth');
          await authApi.logout();
        } catch {
          // 容错：后端登出失败仍清前端状态，允许离线登出
        }
        set({ user: null, token: null, refreshToken: null, error: null });
      },
```

注意：用动态 `import('@/api/auth')` 规避循环依赖（与 `refreshUserInfo` 同模式）。文件顶部已有 `import { authApi } from '@/api/auth';` 静态 import 用于 login/register，**保留不动**——动态 import 仅用于 logout 方法内部，避免在 logout 时引入新的循环依赖路径。

- [ ] **Step 2: 修改 client.ts 401 兜底逻辑**

在 `packages/web/src/api/client.ts` 中，将第 83-87 行的 catch 块：

```typescript
      } catch (refreshError) {
        processPendingRequests(null, refreshError);
        useAuthStore.getState().logout();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
```

替换为（401 时 token 已被后端拒绝，直接清前端，不调后端 logout）：

```typescript
      } catch (refreshError) {
        processPendingRequests(null, refreshError);
        // 401 兜底：token 已被后端拒绝，调 /auth/logout 也会再 401，直接清前端
        useAuthStore.setState({ user: null, token: null, refreshToken: null, error: null });
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
```

- [ ] **Step 3: 运行 web build，确认无类型错误**

Run: `pnpm --filter web build`
Expected: 构建成功，无 TS 错误（logout 已改 async，调用方 client.ts 已不再调 logout）

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/store/auth.store.ts packages/web/src/api/client.ts
git commit -m "feat(auth): logout 改 async 并调后端真登出，client.ts 401 兜底直接清前端"
```

---

## Task 3: App.tsx 启动刷新 profile

**Files:**

- Modify: `packages/web/src/App.tsx`

- [ ] **Step 1: 修改 App.tsx，新增 useEffect 启动刷新**

将 `packages/web/src/App.tsx` 整文件替换为：

```typescript
import { useEffect } from 'react';
import { RouterProvider } from 'react-router-dom';
import { router } from './router';
import { ToastProvider } from './components/Toast';
import { useAuthStore } from './store/auth.store';

function App() {
  const token = useAuthStore((s) => s.token);

  useEffect(() => {
    // 仅登录用户启动时刷新 profile，避免 localStorage 中的 user 过期
    if (token) {
      useAuthStore.getState().refreshUserInfo();
    }
  }, [token]);

  return (
    <ToastProvider>
      <RouterProvider router={router} />
    </ToastProvider>
  );
}

export default App;
```

- [ ] **Step 2: 运行 web build，确认无类型错误**

Run: `pnpm --filter web build`
Expected: 构建成功，无 TS 错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/App.tsx
git commit -m "feat(app): 启动时刷新 profile（仅登录用户），避免 localStorage user 过期"
```

---

## Task 4: Avatar 组件

**Files:**

- Create: `packages/web/src/components/Avatar.tsx`

- [ ] **Step 1: 创建 Avatar 组件**

创建 `packages/web/src/components/Avatar.tsx`：

```typescript
import { useState } from 'react';

interface AvatarProps {
  src?: string | null;
  alt?: string | null;
  size?: number;
}

/**
 * 头像组件：src 为空或加载失败时显示 alt 首字（无则 🍊 emoji）
 */
export function Avatar({ src, alt, size = 56 }: AvatarProps) {
  const [errored, setErrored] = useState(false);
  const showFallback = !src || errored;
  const initial = (alt ?? '').trim().charAt(0).toUpperCase();

  if (showFallback) {
    return (
      <div
        className="rounded-full border border-brand-border bg-brand-peach flex items-center justify-center text-brand-primary font-bold"
        style={{ width: size, height: size, fontSize: size * 0.4 }}
      >
        {initial || '🍊'}
      </div>
    );
  }

  return (
    <img
      src={src!}
      alt={alt ?? 'avatar'}
      onError={() => setErrored(true)}
      className="rounded-full border border-brand-border object-cover"
      style={{ width: size, height: size }}
    />
  );
}
```

- [ ] **Step 2: 运行 web build，确认无类型错误**

Run: `pnpm --filter web build`
Expected: 构建成功，无 TS 错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/Avatar.tsx
git commit -m "feat(web): 新增 Avatar 组件（带 fallback 显示首字或 🍊）"
```

---

## Task 5: TabBar 新增「我的」tab

**Files:**

- Modify: `packages/web/src/components/TabBar.tsx:3-37`

- [ ] **Step 1: 在 tabs 数组末尾追加「我的」tab**

在 `packages/web/src/components/TabBar.tsx` 中，在 `tabs` 数组的第三个元素（订单 tab，约第 25-36 行的 `},` 之后）追加第四个元素：

```typescript
  {
    path: '/profile',
    label: '我的',
    icon: (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
        <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" />
        <circle cx="12" cy="7" r="4" />
      </svg>
    ),
  },
```

追加后 `tabs` 数组应有 4 个元素（首页/购物车/订单/我的）。

激活判定逻辑无需改（现有 `location.pathname.startsWith(tab.path)` 已覆盖 `/profile`）。

- [ ] **Step 2: 运行 web build，确认无类型错误**

Run: `pnpm --filter web build`
Expected: 构建成功，无 TS 错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/TabBar.tsx
git commit -m "feat(web): TabBar 新增「我的」tab 指向 /profile"
```

---

## Task 6: 新增 /profile 路由

**Files:**

- Modify: `packages/web/src/router/index.tsx`

- [ ] **Step 1: 在 router/index.tsx 顶部新增 Profile 懒加载 import**

在 `packages/web/src/router/index.tsx` 中，在第 13 行 `const Login = lazy(...)` 之前插入：

```typescript
const Profile = lazy(() => import('@/pages/Profile'));
```

- [ ] **Step 2: 在路由表中新增 /profile 路由**

在 `packages/web/src/router/index.tsx` 的 `createBrowserRouter` 数组中，在 `/order/:id` 路由（约第 68-71 行）之后、`/login` 路由（约第 72-75 行）之前插入：

```typescript
  {
    path: '/profile',
    element: <SuspenseWrapper><ProtectedRoute><Profile /></ProtectedRoute></SuspenseWrapper>,
  },
```

⚠️ 注意：此 task 依赖 Task 7（Profile.tsx）才能 build 通过。若先执行此 task，需先 stub Profile.tsx 或与 Task 7 一起执行。

**推荐顺序**：先执行 Task 7 创建 Profile.tsx，再执行本 task 与 Task 7 一起 commit。或按 task 编号执行，本 task build 会失败直到 Task 7 完成。

- [ ] **Step 3: 暂不单独 commit，与 Task 7 合并 commit**

---

## Task 7: Profile 页

**Files:**

- Create: `packages/web/src/pages/Profile.tsx`

- [ ] **Step 1: 创建 Profile 页**

创建 `packages/web/src/pages/Profile.tsx`：

```typescript
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Avatar } from '@/components/Avatar';
import { TabBar } from '@/components/TabBar';
import { useAuthStore } from '@/store/auth.store';
import { userApi } from '@/api/user';
import { useToast } from '@/components/Toast';

export default function Profile() {
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  const { showToast } = useToast();
  const [isEditing, setIsEditing] = useState(false);
  const [nickname, setNickname] = useState(user?.nickname ?? '');
  const [saving, setSaving] = useState(false);

  // ProtectedRoute 已保证 token 存在，但 refreshUserInfo 可能未完成时 user 暂为旧值/null
  if (!user) return null;

  const maskedPhone = user.phone.slice(0, 3) + '****' + user.phone.slice(-4);
  const isAdmin = user.role === 'admin';

  const handleSave = async () => {
    setSaving(true);
    try {
      const { data } = await userApi.updateProfile({ nickname });
      useAuthStore.setState({ user: data.data! });
      showToast('资料已更新', 'success');
      setIsEditing(false);
    } catch {
      showToast('更新失败，请重试', 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    setNickname(user.nickname ?? '');
    setIsEditing(false);
  };

  const handleLogout = async () => {
    await useAuthStore.getState().logout();
    navigate('/login', { replace: true });
  };

  return (
    <div className="min-h-screen bg-brand-canvas pb-20">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-brand-canvas/90 backdrop-blur-[10px] border-b border-brand-border px-4 py-3">
        <h1 className="text-[22px] font-black text-brand-dark">个人中心</h1>
      </header>

      {/* 主卡片 */}
      <div className="px-4 py-6">
        <div className="bg-white rounded-3xl border border-brand-border p-6 flex flex-col items-center gap-3">
          <Avatar src={user.avatar} alt={user.nickname ?? user.phone} size={72} />

          {isEditing ? (
            <div className="flex flex-col items-center gap-3 w-full">
              <input
                value={nickname}
                onChange={(e) => setNickname(e.target.value)}
                maxLength={50}
                autoFocus
                placeholder="输入昵称"
                className="text-center text-[18px] font-bold border border-brand-border rounded-2xl px-3 py-2 w-full max-w-[220px] focus:outline-none focus:border-brand-primary"
              />
              <div className="flex gap-2">
                <button
                  onClick={handleSave}
                  disabled={saving || nickname.trim().length === 0}
                  className="px-5 py-1.5 rounded-2xl bg-gradient-to-br from-brand-primary to-brand-coral text-white text-sm font-bold disabled:opacity-50"
                >
                  {saving ? '保存中...' : '保存'}
                </button>
                <button
                  onClick={handleCancel}
                  disabled={saving}
                  className="px-5 py-1.5 rounded-2xl border border-brand-border text-sm font-bold text-brand-dark"
                >
                  取消
                </button>
              </div>
            </div>
          ) : (
            <>
              <div className="text-[22px] font-black text-brand-dark">
                {user.nickname ?? `用户${user.phone.slice(-4)}`}
              </div>
              <div className="text-[13px] text-brand-muted">📱 {maskedPhone}</div>
              {isAdmin && (
                <span className="px-2 py-0.5 rounded-md bg-brand-peach text-brand-primary text-[11px] font-bold">
                  管理员
                </span>
              )}
              <button
                onClick={() => { setNickname(user.nickname ?? ''); setIsEditing(true); }}
                className="mt-2 w-full max-w-[220px] py-2.5 rounded-2xl bg-gradient-to-br from-brand-primary to-brand-coral text-white text-sm font-bold"
              >
                编辑资料
              </button>
            </>
          )}
        </div>

        {/* 登出按钮 */}
        <button
          onClick={handleLogout}
          className="mt-4 w-full py-3 rounded-2xl border border-brand-coral text-brand-coral text-sm font-bold bg-white"
        >
          退出登录
        </button>
      </div>

      <TabBar />
    </div>
  );
}
```

- [ ] **Step 2: 运行 web build，确认无类型错误（含 Task 6 路由）**

Run: `pnpm --filter web build`
Expected: 构建成功，无 TS 错误（此时 Task 6 的路由 import 与 Task 7 的页面都已就绪）

- [ ] **Step 3: Commit（含 Task 6 路由 + Task 7 Profile 页）**

```bash
git add packages/web/src/pages/Profile.tsx packages/web/src/router/index.tsx
git commit -m "feat(web): 新增 /profile 路由与 Profile 页（资料展示 + 行内编辑 + 登出）"
```

---

## Task 8: 全量回归与手动验证

**Files:** 无（仅执行验证）

- [ ] **Step 1: web 全量构建**

Run: `pnpm --filter web build`
Expected: 构建成功，无 TS 错误

- [ ] **Step 2: shared 重 build（确认无副作用）**

Run: `pnpm --filter shared build`
Expected: 成功无 tsc 错误（P1-A 不改 shared）

- [ ] **Step 3: server 全量 unit 测试**

Run: `pnpm --filter server test`
Expected: 全部通过（P1-A 不改后端，但确认无意外影响）

- [ ] **Step 4: server 全量 e2e 测试**

⚠️ 依赖真实 MySQL + Redis：先 `docker compose ps` 确认 healthy。

Run: `pnpm --filter server test:e2e`
Expected: 全部通过（含 auth.e2e 的 logout 黑名单场景 F）

- [ ] **Step 5: 启动 docker compose 手动验证场景 A-H**

Run: `docker compose up -d --build`
浏览器访问 `http://localhost` 走查：

- **场景 A**（启动刷新-登录态）：登录账号 → 刷新浏览器 → DevTools Network 看到 `GET /api/user/profile` 200 → Profile 页显示最新昵称
- **场景 B**（启动刷新-未登录）：退出登录 → 刷新浏览器 → Network 无 `/api/user/profile` 请求
- **场景 C**（进入 Profile）：登录后点 TabBar「我的」→ 进入 `/profile`，显示头像/昵称/脱敏手机号；admin 账号额外显示「管理员」标签
- **场景 D**（行内编辑）：点「编辑资料」→ 改昵称 → 点保存 → Network `PUT /api/user/profile` 200 → input 转 text + toast「资料已更新」+ 昵称更新
- **场景 E**（真登出）：点「退出登录」→ Network `POST /api/auth/logout` 200 → 跳 `/login` → 返回首页需重新登录
- **场景 F**（黑名单生效-已有 e2e）：DevTools 复制旧 token → 用 curl 调 `/api/user/profile` → 返回 401
- **场景 G**（TabBar 激活）：在 `/profile` → TabBar「我的」高亮 `text-brand-primary`，其他 tab 不高亮；切到 `/` → 「首页」高亮，「我的」不高亮
- **场景 H**（Avatar fallback）：DB 手动将某用户 avatar 设为 null → Profile 页 Avatar 显示 nickname 首字（无 nickname 显示 🍊）

- [ ] **Step 6: 验证回归（受保护路由回跳）**

未登录状态访问 `/cart`、`/orders`、`/order/1`、`/admin/products`、`/profile` → 均跳 `/login` → 登录后回到原页面（state.from 生效）

- [ ] **Step 7: 最终 commit（如有回归修复）**

如所有验证通过，无需额外 commit。如发现回归问题，逐个修复并 commit。

---

## 验收映射（Contract → Task）

| Contract 验收项                              | 对应 Task                                       |
| -------------------------------------------- | ----------------------------------------------- |
| 删除独立 ProtectedRoute.tsx / AdminRoute.tsx | Task 1 Step 2                                   |
| 内联 ProtectedRoute 补 state.from            | Task 1 Step 3                                   |
| 新增 /profile 路由                           | Task 6 + Task 7                                 |
| 回归 5 个受保护路由回跳                      | Task 8 Step 6                                   |
| auth.store logout async + 调后端             | Task 2 Step 1                                   |
| client.ts 401 兜底直接清前端                 | Task 2 Step 2                                   |
| TypeScript 构建                              | 各 Task 的 build step + Task 8 Step 1           |
| App.tsx useEffect 启动刷新                   | Task 3                                          |
| 场景 A 启动刷新（登录态）                    | Task 8 Step 5 场景 A                            |
| 场景 B 启动不刷新（未登录）                  | Task 8 Step 5 场景 B                            |
| Avatar 组件                                  | Task 4                                          |
| Profile 页（展示 + 行内编辑 + 登出）         | Task 7                                          |
| TabBar 新增「我的」tab                       | Task 5                                          |
| 场景 C 进入 Profile                          | Task 8 Step 5 场景 C                            |
| 场景 D 行内编辑                              | Task 8 Step 5 场景 D                            |
| 场景 E 真登出                                | Task 8 Step 5 场景 E                            |
| 场景 F 黑名单生效                            | Task 8 Step 4（auth.e2e 已覆盖）+ Step 5 场景 F |
| 场景 G TabBar 激活                           | Task 8 Step 5 场景 G                            |
| 场景 H Avatar fallback                       | Task 8 Step 5 场景 H                            |

---

## Self-Review Notes

- **Spec coverage**: spec 第 4-6 节四个独立单元（路由清理 / logout async / 启动刷新 / Profile+Avatar+TabBar）全部映射到 Task 1-7
- **Placeholder scan**: 无 TBD/TODO，所有 code step 含完整代码
- **Type consistency**: `logout: () => Promise<void>`（接口）与 `logout: async () => {...}`（实现）签名一致；Avatar props `src/alt/size` 与 Profile 调用 `size={72}` 一致；`useAuthStore.getState().refreshUserInfo()` / `.logout()` 与 store 暴露方法一致
- **Task 依赖**：Task 6 路由依赖 Task 7 Profile.tsx 才能 build，计划中已说明合并 commit；Task 8 依赖前 7 个 task 全部完成
- **循环依赖**：logout 用动态 `import('@/api/auth')`（与 refreshUserInfo 同模式），client.ts 401 兜底改用 setState 不调 logout，规避 async logout 在拦截器中的复杂性
