# P1-A 用户中心设计

- **日期**：2026-06-19
- **状态**：待评审
- **作者**：brainstorming session
- **关联**：`docs/agent-harness/specs/2026-06-19-web-api-gap-design.md` 第 6 节 P1-1/P1-2/P1-3
- **前置**：P0 已完成（`/user/profile` 路径已对齐、`userApi.updateProfile` PUT 方法已就绪）

---

## 1. 背景

P0 修复了前端 `userApi` 的路径与方法对齐（`/user/profile` 单数、PUT），但 `userApi.getProfile` / `updateProfile` 仍**无任何 UI 触发点**，`auth.store.refreshUserInfo` 实现完整但**从未被任何组件调用**，`auth.store.logout` 仅清前端状态**不调后端**（token 在 access 过期前仍可被滥用）。

P1-A 落地三件事：

- **P1-1**：登出 UI + 真后端登出（jti 加 Redis 黑名单）
- **P1-2**：应用启动时刷新 profile（仅登录用户）
- **P1-3**：个人中心页（资料展示 + 行内编辑 + 登出）

附带清理：删除未引用的独立 `ProtectedRoute.tsx` / `AdminRoute.tsx` 死代码，给内联 `ProtectedRoute` 补 `state.from` 回跳能力。

## 2. 目标

1. 用户能在 `/profile` 查看自己的头像/昵称/手机号（脱敏）/角色
2. 用户能在 Profile 页行内编辑昵称并保存到后端
3. 用户能通过 Profile 页「退出登录」按钮触发真后端登出（token 立即失效）
4. 应用启动时（仅登录用户）自动拉取最新 profile，避免 localStorage 中的 user 过期
5. TabBar 提供「我的」入口直达 Profile

## 3. 非目标

- 不做 Profile 页的「我的订单」「商品管理」入口（推后）
- 不做头像上传（推到 P2-8 图片上传）
- 不做手机号修改（账号标识，风险高）
- 不做退出确认 dialog（YAGNI）
- 不做 StrictMode 双调用去重（接口幂等，可接受）
- 不引入前端测试框架（沿用现有手动验证 + 后端 e2e 模式）

## 4. 总体架构

### 4.1 四个独立单元

```
┌─────────────────────────────────────────────────────┐
│ 1. 路由与死代码清理 (router/index.tsx)              │
│    - 删除独立 ProtectedRoute.tsx / AdminRoute.tsx   │
│    - 内联 ProtectedRoute 补 state.from              │
│    - 新增 /profile 路由（lazy + 内联 ProtectedRoute）│
└─────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────┐
│ 2. auth store logout async 改造 (store/auth.store.ts)│
│    - logout 改 async                                │
│    - 先 await authApi.logout()（容错）再清状态      │
│    - client.ts:85 兼容性处理                        │
└─────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────┐
│ 3. App.tsx 启动刷新 (App.tsx)                       │
│    - useEffect: if (token) refreshUserInfo()       │
└─────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────┐
│ 4. Profile 页 + Avatar 组件 + TabBar                │
│    - pages/Profile.tsx (展示 + 行内编辑 + 登出)     │
│    - components/Avatar.tsx (头像 fallback)          │
│    - components/TabBar.tsx (新增「我的」tab)        │
└─────────────────────────────────────────────────────┘
```

### 4.2 文件清单

**Create**

- `packages/web/src/pages/Profile.tsx`
- `packages/web/src/components/Avatar.tsx`

**Modify**

- `packages/web/src/router/index.tsx` — 新增 /profile 路由 + 内联 ProtectedRoute 补 state.from
- `packages/web/src/store/auth.store.ts` — logout 改 async + 调后端
- `packages/web/src/api/client.ts` — 兼容 async logout（401 兜底点）
- `packages/web/src/App.tsx` — mount 时 refreshUserInfo（仅登录用户）
- `packages/web/src/components/TabBar.tsx` — 新增第 4 tab

**Delete**

- `packages/web/src/router/ProtectedRoute.tsx`（死代码）
- `packages/web/src/router/AdminRoute.tsx`（死代码）

## 5. 详细设计

### 5.1 路由与死代码清理

**`router/index.tsx` 改动**

内联 `ProtectedRoute` 改为：

```tsx
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore((s) => s.token);
  const location = useLocation();
  if (!token) return <Navigate to="/login" replace state={{ from: location }} />;
  return <>{children}</>;
}
```

新增路由（懒加载，放在 `/orders` 之后、`/login` 之前）：

```tsx
{
  path: '/profile',
  element: (
    <ProtectedRoute>
      <Profile />
    </ProtectedRoute>
  ),
},
```

顶部 import：

```tsx
const Profile = lazy(() => import('@/pages/Profile'));
```

`useLocation` 从 `react-router-dom` import。

**死代码删除**：直接删除 `router/ProtectedRoute.tsx` 与 `router/AdminRoute.tsx`（全代码搜索确认无 import）。

### 5.2 auth store logout 改造

**`store/auth.store.ts`**

```ts
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

- 用动态 `import('@/api/auth')` 规避循环依赖（与 `refreshUserInfo` 同模式）
- `authApi.logout` 失败不阻塞，仍清状态

**`api/client.ts:85` 兼容**

原：

```ts
useAuthStore.getState().logout();
window.location.href = '/login';
```

改为：

```ts
useAuthStore
  .getState()
  .logout()
  .finally(() => {
    window.location.href = '/login';
  });
```

或保持同步语义（401 时 token 已无效，调后端必失败）：

```ts
// 401 兜底：token 已无效，直接清前端状态（不调后端）
useAuthStore.setState({ user: null, token: null, refreshToken: null, error: null });
window.location.href = '/login';
```

**推荐方案**：第二种。401 兜底场景 token 已被后端拒绝，调 `/auth/logout` 也会再 401，直接清前端更干净。

### 5.3 App.tsx 启动刷新

**`App.tsx`**

```tsx
import { useEffect } from 'react';
import { useAuthStore } from '@/store/auth.store';

function App() {
  const token = useAuthStore((s) => s.token);

  useEffect(() => {
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
```

- 仅当有 token 时调 refreshUserInfo
- 依赖 `[token]`：登录/登出切换时也会触发（合理）
- StrictMode 下双调用可接受（profile 幂等）

### 5.4 Avatar 组件

**`components/Avatar.tsx`**

```tsx
interface AvatarProps {
  src?: string | null;
  alt?: string | null;
  size?: number; // 默认 56
}

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

- src 为空或加载失败 → fallback 显示 alt 首字（无则 🍊）
- `border-brand-border`、`bg-brand-peach`、`text-brand-primary` 遵循 DESIGN.md token

### 5.5 Profile 页

**`pages/Profile.tsx`**（布局遵循 DESIGN.md 375px 移动基准）

```tsx
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Avatar } from '@/components/Avatar';
import { TabBar } from '@/components/TabBar';
import { useAuthStore } from '@/store/auth.store';
import { userApi } from '@/api/user';
import { useToast } from '@/components/Toast';

export default function Profile() {
  const navigate = useNavigate();
  const { user, logout } = useAuthStore();
  const { showToast } = useToast();
  const [isEditing, setIsEditing] = useState(false);
  const [nickname, setNickname] = useState(user?.nickname ?? '');
  const [saving, setSaving] = useState(false);

  if (!user) return null; // ProtectedRoute 已保证有 user

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

  const handleLogout = async () => {
    await logout();
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
            <div className="flex flex-col items-center gap-2 w-full">
              <input
                value={nickname}
                onChange={(e) => setNickname(e.target.value)}
                maxLength={50}
                autoFocus
                className="text-center text-[18px] font-bold border border-brand-border rounded-2xl px-3 py-2 w-full max-w-[200px]"
              />
              <div className="flex gap-2">
                <button
                  onClick={handleSave}
                  disabled={saving}
                  className="px-4 py-1.5 rounded-2xl bg-brand-primary text-white text-sm font-bold disabled:opacity-50"
                >
                  保存
                </button>
                <button
                  onClick={() => {
                    setNickname(user.nickname ?? '');
                    setIsEditing(false);
                  }}
                  className="px-4 py-1.5 rounded-2xl border border-brand-border text-sm font-bold text-brand-dark"
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
                onClick={() => {
                  setNickname(user.nickname ?? '');
                  setIsEditing(true);
                }}
                className="mt-2 w-full max-w-[200px] py-2.5 rounded-2xl bg-gradient-to-br from-brand-primary to-brand-coral text-white text-sm font-bold"
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

### 5.6 TabBar 新增「我的」tab

**`components/TabBar.tsx`**

在现有 3 个 tab（首页/购物车/订单）之后追加：

```tsx
{ to: '/profile', icon: '👤', label: '我的' }
```

激活判定统一用 `location.pathname.startsWith(tab.to)`（确保 `/profile/xxx` 也激活，虽然 P1-A 没有子路由，保持一致性）。

## 6. 数据流

### 6.1 启动刷新（P1-2）

```
App.tsx mount
  → useEffect: if (token) refreshUserInfo()
    → userApi.getProfile()  (GET /api/user/profile)
    → set({ user: data.data })
    → persist 自动写回 localStorage 'fruit-shop-auth'
  → Profile 页读 useAuthStore.user 显示最新数据
```

失败兜底（已有）：`refreshUserInfo` catch → 清登录态。

### 6.2 行内编辑保存

```
Profile 页「编辑资料」→ isEditing=true
  → input 改昵称 → 点保存
  → userApi.updateProfile({ nickname })  (PUT /api/user/profile)
  → 成功: useAuthStore.setState({ user: {...user, nickname} })
         → showToast('资料已更新', 'success')
         → isEditing=false
  → 失败: showToast('更新失败，请重试', 'error')（保留编辑态）
```

### 6.3 真登出（P1-1）

```
Profile 页「退出登录」
  → auth.store.logout() async
    → try { await authApi.logout() }  (POST /api/auth/logout)
        → 后端: 将 access jti 加入 Redis 黑名单
      catch { /* 容错 */ }
    → set({ user: null, token: null, refreshToken: null })
  → navigate('/login', { replace: true })
```

后续用旧 token 调 API → 后端 JwtAuthGuard 查 Redis 黑名单 → 返回 401。

## 7. 验收场景

| 场景                    | 触发                          | 预期                                                           |
| ----------------------- | ----------------------------- | -------------------------------------------------------------- |
| A. 启动刷新（登录态）   | 登录后刷新浏览器              | App mount → Network `GET /user/profile` 200 → store user 更新  |
| B. 启动不刷新（未登录） | 未登录刷新浏览器              | App mount → Network 无 `/user/profile` 请求                    |
| C. 进入 Profile         | 点 TabBar「我的」             | 进入 `/profile`，显示头像/昵称/脱敏手机号/角色标签             |
| D. 行内编辑             | 点「编辑资料」→ 改昵称 → 保存 | input 转 text，`PUT /user/profile` 200，store 更新，toast 成功 |
| E. 真登出               | 点「退出登录」                | `POST /auth/logout` 200 → 清状态 → 跳 `/login`                 |
| F. 黑名单生效           | 登出后用旧 token 调 API       | 后端返回 401（已有 auth.e2e 覆盖）                             |
| G. TabBar 激活          | 在 `/profile`                 | TabBar「我的」高亮 `text-brand-primary`                        |
| H. Avatar fallback      | user.avatar 为 null           | 显示 nickname 首字（无则 🍊）                                  |

## 8. 风险与权衡

| 风险                               | 影响                           | 缓解                                                                                             |
| ---------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------ |
| StrictMode 双调用 refreshUserInfo  | 开发环境发两次 `/user/profile` | 接口幂等，可接受；YAGNI 不做去重                                                                 |
| logout async 化波及 client.ts      | 401 兜底调用点签名变化         | 401 场景 token 已无效，直接清前端状态（不调后端）                                                |
| 内联 ProtectedRoute 补 state.from  | 影响所有受保护页登录回跳       | 行为改善（原内联版无回跳），回归 `/cart`、`/orders`、`/order/:id`、`/admin/products`、`/profile` |
| 删除独立 ProtectedRoute/AdminRoute | 万一未来有引用                 | 全代码搜索确认无 import，删除安全                                                                |
| 真登出仅防 access token            | refresh token 仍有效           | 后端 logout 只加 access jti；扩展超 P1-A 范围                                                    |
| Avatar onError 状态                | 图片加载失败切换 fallback      | useState(errored) + onError handler                                                              |

## 9. 测试策略

**无前端测试框架**，采用：

1. **后端 e2e**（已有）
   - `auth.e2e-spec.ts` 已覆盖 logout 黑名单场景 F，无需新增

2. **手动验证**（场景 A-E、G、H）
   - `docker compose up -d` → 浏览器走流程
   - 重点：启动刷新请求、登出后旧 token 失效、TabBar 激活、Avatar fallback

3. **TypeScript 类型检查**
   - `pnpm --filter web build` 通过（logout async、Profile、Avatar 无类型错误）

## 10. shared 变更

无。本设计不触及 `packages/shared`，所有改动在 `packages/web`。

## 11. 后续步骤

1. 用户评审本设计文档
2. 进入 `sprint-contract` 协商 Definition of Done
3. 进入 `writing-plans` 产出实施计划
4. Subagent-Driven Development 执行实施
