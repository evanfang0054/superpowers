# 鲜果集 Web 端视觉一致性与公共组件抽取 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 抽取 6 个公共 UI 组件，把 8 个偏离基准的页面统一对齐 DESIGN.md 的暖橙圆润设计语言。

**Architecture:** 先建 `src/components/ui/` 公共组件层（NavBar / BottomActionBar / Button / IconButton / EmptyState / Tag），再逐页替换内联实现，最后用 Grep 做 token 清查验收。项目无测试框架，验证靠 `pnpm --filter web build` + 手动点击流 + Grep 残留检查。

**Tech Stack:** React 18 + TypeScript + Vite 6 + Tailwind CSS v4 + React Router v6 + Zustand

**Spec:** `docs/agent-harness/specs/2026-06-25-ux-visual-consistency-design.md`

---

## File Structure

### 新建文件（7 个）

| 文件                                                 | 职责                                     |
| ---------------------------------------------------- | ---------------------------------------- |
| `packages/web/src/components/ui/NavBar.tsx`          | 顶部 sticky 导航，含 showBack 自动返回   |
| `packages/web/src/components/ui/BottomActionBar.tsx` | 底部 fixed 操作栏                        |
| `packages/web/src/components/ui/Button.tsx`          | 通用按钮（4 variant × 3 size + loading） |
| `packages/web/src/components/ui/IconButton.tsx`      | 圆形/方形小按钮                          |
| `packages/web/src/components/ui/EmptyState.tsx`      | 空态（图标+文案+CTA）                    |
| `packages/web/src/components/ui/Tag.tsx`             | 标签/Badge                               |
| `packages/web/src/components/ui/index.ts`            | 聚合导出                                 |

### 修改文件（8 个页面）

| 文件                                     | 改动要点                         |
| ---------------------------------------- | -------------------------------- |
| `packages/web/src/pages/Cart.tsx`        | header/底部栏/卡片/按钮/空态全换 |
| `packages/web/src/pages/Checkout.tsx`    | header/底部栏/卡片/按钮换        |
| `packages/web/src/pages/OrderList.tsx`   | header/tab/卡片/按钮/空态换      |
| `packages/web/src/pages/OrderDetail.tsx` | header/按钮/modal 样式换         |
| `packages/web/src/pages/Favorites.tsx`   | header/空态/按钮换               |
| `packages/web/src/pages/Profile.tsx`     | canvas→bg 换、按钮换             |
| `packages/web/src/pages/Login.tsx`       | label/border/按钮换              |
| `packages/web/src/pages/Register.tsx`    | label/border/按钮换              |

---

## Task 1: 创建公共组件目录与 Button 组件

**Files:**

- Create: `packages/web/src/components/ui/Button.tsx`
- Create: `packages/web/src/components/ui/index.ts`

- [ ] **Step 1: 创建 `Button.tsx`**

```tsx
import type { ButtonHTMLAttributes, ReactNode } from 'react';

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
  fullWidth?: boolean;
  children: ReactNode;
}

const VARIANT_CLASSES: Record<ButtonVariant, string> = {
  primary: 'bg-gradient-to-br from-brand-primary to-brand-coral text-white animate-pulse-glow',
  secondary: 'bg-brand-secondary text-brand-dark',
  ghost: 'bg-transparent border border-brand-border text-brand-dark hover:bg-brand-bg',
  danger: 'bg-brand-coral text-white',
};

const SIZE_CLASSES: Record<ButtonSize, string> = {
  sm: 'px-4 py-1.5 text-sm',
  md: 'px-6 py-2.5 text-sm',
  lg: 'px-8 py-3 text-base',
};

export function Button({
  variant = 'primary',
  size = 'md',
  loading = false,
  fullWidth = false,
  disabled,
  className = '',
  children,
  ...rest
}: ButtonProps) {
  const classes = [
    'inline-flex items-center justify-center font-bold rounded-2xl transition-all',
    'active:scale-[0.98] disabled:opacity-50 disabled:active:scale-100 disabled:pointer-events-none',
    VARIANT_CLASSES[variant],
    SIZE_CLASSES[size],
    fullWidth ? 'w-full' : '',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button className={classes} disabled={disabled || loading} {...rest}>
      {loading && (
        <svg className="animate-spin h-4 w-4 mr-2" viewBox="0 0 24 24" fill="none">
          <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" opacity="0.25" />
          <path
            d="M12 2a10 10 0 0110 10"
            stroke="currentColor"
            strokeWidth="3"
            strokeLinecap="round"
          />
        </svg>
      )}
      {children}
    </button>
  );
}
```

- [ ] **Step 2: 创建 `index.ts` 聚合导出**

```ts
export { Button } from './Button';
```

- [ ] **Step 3: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功，无 TS 错误

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/components/ui/
git commit -m "feat(web): 新增 Button 公共组件与 ui/ 目录"
```

---

## Task 2: IconButton 组件

**Files:**

- Create: `packages/web/src/components/ui/IconButton.tsx`
- Modify: `packages/web/src/components/ui/index.ts`

- [ ] **Step 1: 创建 `IconButton.tsx`**

```tsx
import type { ButtonHTMLAttributes, ReactNode } from 'react';

type IconButtonVariant = 'ghost' | 'solid';
type IconButtonShape = 'circle' | 'square';
type IconButtonSize = 'sm' | 'md' | 'lg';

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: IconButtonVariant;
  shape?: IconButtonShape;
  size?: IconButtonSize;
  children: ReactNode;
}

const SIZE_DIM: Record<IconButtonSize, string> = {
  sm: 'w-7 h-7',
  md: 'w-9 h-9',
  lg: 'w-11 h-11',
};

const SHAPE_CLASS: Record<IconButtonShape, string> = {
  circle: 'rounded-full',
  square: 'rounded-xl',
};

const VARIANT_CLASS: Record<IconButtonVariant, string> = {
  ghost: 'bg-brand-btn-bg text-brand-dark hover:bg-brand-bg',
  solid: 'bg-brand-primary text-white',
};

export function IconButton({
  variant = 'ghost',
  shape = 'circle',
  size = 'md',
  className = '',
  children,
  ...rest
}: IconButtonProps) {
  const classes = [
    'flex items-center justify-center transition-all active:scale-90 disabled:opacity-50 disabled:active:scale-100',
    SIZE_DIM[size],
    SHAPE_CLASS[shape],
    VARIANT_CLASS[variant],
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button className={classes} {...rest}>
      {children}
    </button>
  );
}
```

- [ ] **Step 2: 更新 `index.ts`**

```ts
export { Button } from './Button';
export { IconButton } from './IconButton';
```

- [ ] **Step 3: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/components/ui/
git commit -m "feat(web): 新增 IconButton 公共组件"
```

---

## Task 3: NavBar 组件

**Files:**

- Create: `packages/web/src/components/ui/NavBar.tsx`
- Modify: `packages/web/src/components/ui/index.ts`

- [ ] **Step 1: 创建 `NavBar.tsx`**

```tsx
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { IconButton } from './IconButton';

interface NavBarProps {
  title?: ReactNode;
  left?: ReactNode;
  right?: ReactNode;
  showBack?: boolean;
  sticky?: boolean;
}

export function NavBar({ title, left, right, showBack = true, sticky = true }: NavBarProps) {
  const navigate = useNavigate();
  const positionClass = sticky ? 'sticky top-0 z-50' : '';

  const defaultLeft = showBack ? (
    <IconButton
      variant="ghost"
      shape="circle"
      size="md"
      aria-label="返回"
      onClick={() => navigate(-1)}
    >
      <svg
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M19 12H5M12 19l-7-7 7-7" />
      </svg>
    </IconButton>
  ) : null;

  return (
    <header
      className={`bg-brand-bg/90 backdrop-blur-[10px] border-b border-brand-border h-12 flex items-center px-4 ${positionClass}`}
    >
      <div className="flex items-center gap-2 min-w-0">{left ?? defaultLeft}</div>
      {title && (
        <div className="flex-1 text-center font-bold text-[17px] text-brand-dark truncate px-2">
          {title}
        </div>
      )}
      {!title && <div className="flex-1" />}
      <div className="flex items-center gap-3 min-w-0">{right}</div>
    </header>
  );
}
```

- [ ] **Step 2: 更新 `index.ts`**

```ts
export { Button } from './Button';
export { IconButton } from './IconButton';
export { NavBar } from './NavBar';
```

- [ ] **Step 3: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/components/ui/
git commit -m "feat(web): 新增 NavBar 公共组件"
```

---

## Task 4: BottomActionBar 组件

**Files:**

- Create: `packages/web/src/components/ui/BottomActionBar.tsx`
- Modify: `packages/web/src/components/ui/index.ts`

- [ ] **Step 1: 创建 `BottomActionBar.tsx`**

```tsx
import type { ReactNode } from 'react';

interface BottomActionBarProps {
  children: ReactNode;
  className?: string;
}

export function BottomActionBar({ children, className = '' }: BottomActionBarProps) {
  return (
    <div
      className={`fixed bottom-0 inset-x-0 bg-white/95 backdrop-blur-[12px] border-t-[1.5px] border-brand-border z-40 safe-bottom ${className}`}
    >
      <div className="max-w-lg mx-auto px-4 py-3 flex items-center justify-between gap-3">
        {children}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 更新 `index.ts`**

```ts
export { Button } from './Button';
export { IconButton } from './IconButton';
export { NavBar } from './NavBar';
export { BottomActionBar } from './BottomActionBar';
```

- [ ] **Step 3: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/components/ui/
git commit -m "feat(web): 新增 BottomActionBar 公共组件"
```

---

## Task 5: EmptyState 组件

**Files:**

- Create: `packages/web/src/components/ui/EmptyState.tsx`
- Modify: `packages/web/src/components/ui/index.ts`

- [ ] **Step 1: 创建 `EmptyState.tsx`**

```tsx
import type { ReactNode } from 'react';

interface EmptyStateProps {
  icon?: ReactNode;
  title: string;
  description?: string;
  action?: ReactNode;
}

const DEFAULT_ICON = (
  <svg
    width="72"
    height="72"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z" />
    <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
    <line x1="12" y1="22.08" x2="12" y2="12" />
  </svg>
);

export function EmptyState({ icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-32">
      <div className="text-brand-muted/60">{icon ?? DEFAULT_ICON}</div>
      <p className="text-brand-muted text-sm mt-4">{title}</p>
      {description && <p className="text-brand-muted/70 text-xs mt-1">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
```

- [ ] **Step 2: 更新 `index.ts`**

```ts
export { Button } from './Button';
export { IconButton } from './IconButton';
export { NavBar } from './NavBar';
export { BottomActionBar } from './BottomActionBar';
export { EmptyState } from './EmptyState';
```

- [ ] **Step 3: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/components/ui/
git commit -m "feat(web): 新增 EmptyState 公共组件"
```

---

## Task 6: Tag 组件 + 完成 ui 模块

**Files:**

- Create: `packages/web/src/components/ui/Tag.tsx`
- Modify: `packages/web/src/components/ui/index.ts`

- [ ] **Step 1: 创建 `Tag.tsx`**

```tsx
import type { ReactNode } from 'react';

type TagVariant = 'primary' | 'success' | 'warning' | 'accent' | 'muted';
type TagSize = 'sm' | 'md';

interface TagProps {
  children: ReactNode;
  variant?: TagVariant;
  size?: TagSize;
}

const VARIANT_CLASS: Record<TagVariant, string> = {
  primary: 'bg-brand-primary text-white',
  success: 'bg-brand-green text-white',
  warning: 'bg-brand-secondary text-brand-dark',
  accent: 'bg-brand-accent text-white',
  muted: 'bg-brand-btn-bg text-brand-muted',
};

const SIZE_CLASS: Record<TagSize, string> = {
  sm: 'px-2 py-0.5 text-[10px]',
  md: 'px-2.5 py-1 text-[11px]',
};

export function Tag({ children, variant = 'primary', size = 'md' }: TagProps) {
  return (
    <span
      className={`inline-flex items-center font-bold rounded-full ${VARIANT_CLASS[variant]} ${SIZE_CLASS[size]}`}
    >
      {children}
    </span>
  );
}
```

- [ ] **Step 2: 更新 `index.ts`（最终版）**

```ts
export { Button } from './Button';
export { IconButton } from './IconButton';
export { NavBar } from './NavBar';
export { BottomActionBar } from './BottomActionBar';
export { EmptyState } from './EmptyState';
export { Tag } from './Tag';
```

- [ ] **Step 3: 验证全部组件编译**

Run: `pnpm --filter web build`
Expected: 编译成功，无 TS 错误

- [ ] **Step 4: Commit**

```bash
git add packages/web/src/components/ui/
git commit -m "feat(web): 新增 Tag 公共组件，ui 模块就位"
```

---

## Task 7: 改造 Login 页面

**Files:**

- Modify: `packages/web/src/pages/Login.tsx`

- [ ] **Step 1: 用新 token 重写 Login.tsx**

替换整个 `return` 块与相关 className。注意 label 从 `text-gray-700` → `text-brand-dark`，输入框 `border-gray-200` → `border-brand-border`，副文案 `text-gray-500` → `text-brand-muted`，按钮换 `<Button>`。

完整文件：

```tsx
import { useState, type FormEvent } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/store/auth.store';
import { Toast } from '@/components/Toast';
import { Button } from '@/components/ui';

export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login, isLoading } = useAuthStore();

  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');

  const from = (location.state as { from?: { pathname: string } })?.from?.pathname || '/';

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!phone.trim()) {
      Toast.show('请输入手机号', 'warning');
      return;
    }
    if (!password.trim()) {
      Toast.show('请输入密码', 'warning');
      return;
    }

    try {
      await login({ phone: phone.trim(), password });
      Toast.show('登录成功', 'success');
      navigate(from, { replace: true });
    } catch {
      Toast.show('手机号或密码错误', 'error');
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg flex flex-col">
      <header className="max-w-lg mx-auto w-full px-4 pt-16 pb-8">
        <h1 className="text-3xl font-bold text-brand-primary font-display">鲜果集</h1>
        <p className="text-brand-muted mt-2">登录以享受新鲜水果配送服务</p>
      </header>

      <main className="max-w-lg mx-auto w-full px-4 flex-1">
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">手机号</label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="请输入手机号"
              maxLength={11}
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">密码</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="请输入密码"
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <Button type="submit" loading={isLoading} fullWidth size="lg">
            {isLoading ? '登录中...' : '登录'}
          </Button>
        </form>

        <p className="text-center text-sm text-brand-muted mt-6">
          还没有账号？
          <button
            onClick={() => navigate('/register')}
            className="text-brand-primary font-medium hover:underline ml-1"
          >
            立即注册
          </button>
        </p>
      </main>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/pages/Login.tsx
git commit -m "refactor(web): Login 对齐 brand token + Button 公共组件"
```

---

## Task 8: 改造 Register 页面

**Files:**

- Modify: `packages/web/src/pages/Register.tsx`

- [ ] **Step 1: 同 Login 思路重写**

完整文件：

```tsx
import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/store/auth.store';
import { Toast } from '@/components/Toast';
import { Button } from '@/components/ui';

export default function Register() {
  const navigate = useNavigate();
  const { register, isLoading } = useAuthStore();

  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [nickname, setNickname] = useState('');

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!phone.trim()) {
      Toast.show('请输入手机号', 'warning');
      return;
    }
    if (phone.trim().length !== 11) {
      Toast.show('请输入正确的手机号', 'warning');
      return;
    }
    if (!password.trim() || password.length < 6) {
      Toast.show('密码至少6位', 'warning');
      return;
    }

    try {
      await register({
        phone: phone.trim(),
        password,
        nickname: nickname.trim() || undefined,
      });
      Toast.show('注册成功', 'success');
      navigate('/', { replace: true });
    } catch {
      Toast.show('注册失败，手机号可能已被注册', 'error');
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg flex flex-col">
      <header className="max-w-lg mx-auto w-full px-4 pt-16 pb-8">
        <h1 className="text-3xl font-bold text-brand-primary font-display">鲜果集</h1>
        <p className="text-brand-muted mt-2">创建账号，开启新鲜水果之旅</p>
      </header>

      <main className="max-w-lg mx-auto w-full px-4 flex-1">
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">手机号</label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="请输入手机号"
              maxLength={11}
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">密码</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="请输入密码（至少6位）"
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-brand-dark mb-1.5">
              昵称 <span className="text-brand-muted font-normal">（选填）</span>
            </label>
            <input
              type="text"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
              placeholder="给自己取个名字吧"
              maxLength={20}
              className="w-full px-4 py-3 rounded-2xl border border-brand-border bg-white text-brand-dark placeholder-brand-muted/70 focus:outline-none focus:ring-2 focus:ring-brand-primary/30 focus:border-brand-primary transition-colors"
            />
          </div>

          <Button type="submit" loading={isLoading} fullWidth size="lg">
            {isLoading ? '注册中...' : '注册'}
          </Button>
        </form>

        <p className="text-center text-sm text-brand-muted mt-6">
          已有账号？
          <button
            onClick={() => navigate('/login')}
            className="text-brand-primary font-medium hover:underline ml-1"
          >
            立即登录
          </button>
        </p>
      </main>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/pages/Register.tsx
git commit -m "refactor(web): Register 对齐 brand token + Button 公共组件"
```

---

## Task 9: 改造 Favorites 页面

**Files:**

- Modify: `packages/web/src/pages/Favorites.tsx`

- [ ] **Step 1: 用 NavBar + EmptyState + Button 重写**

```tsx
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { favoriteApi } from '@/api/favorite';
import type { FavoriteWithProduct } from 'shared';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Toast } from '@/components/Toast';
import { NavBar, EmptyState, Button } from '@/components/ui';

const PAGE_SIZE = 10;

export default function Favorites() {
  const navigate = useNavigate();
  const [list, setList] = useState<FavoriteWithProduct[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [removingId, setRemovingId] = useState<number | null>(null);

  const fetchPage = async (targetPage: number) => {
    setLoading(true);
    try {
      const { data } = await favoriteApi.getList({
        page: targetPage,
        limit: PAGE_SIZE,
      });
      const payload = data.data;
      setList(payload?.list ?? []);
      setTotal(payload?.total ?? 0);
      setPage(targetPage);
    } catch {
      Toast.show('加载收藏失败', 'error');
      setList([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPage(1);
  }, []);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const handleRemove = async (fav: FavoriteWithProduct) => {
    if (!fav.product) return;
    setRemovingId(fav.id);
    try {
      await favoriteApi.remove(fav.product.id);
      Toast.show('已取消收藏', 'info');
      if (list.length === 1 && page > 1) {
        fetchPage(page - 1);
      } else {
        fetchPage(page);
      }
    } catch {
      Toast.show('操作失败', 'error');
    } finally {
      setRemovingId(null);
    }
  };

  return (
    <div className="min-h-screen bg-brand-bg pb-24">
      <NavBar
        title={
          <span>
            我的收藏
            {total > 0 && (
              <span className="ml-1 text-[13px] text-brand-muted font-medium">({total})</span>
            )}
          </span>
        }
      />

      <main className="max-w-lg mx-auto px-4 mt-3">
        {loading ? (
          <div className="flex justify-center py-10">
            <LoadingSpinner size="lg" />
          </div>
        ) : list.length === 0 ? (
          <EmptyState
            title="还没有收藏任何商品"
            description="去首页挑喜欢的水果吧"
            action={
              <Button variant="primary" size="md" onClick={() => navigate('/')}>
                去逛逛
              </Button>
            }
          />
        ) : (
          <div className="grid grid-cols-2 gap-3">
            {list.map((fav) => {
              const product = fav.product;
              if (!product) {
                return (
                  <div
                    key={fav.id}
                    className="bg-brand-card rounded-2xl border border-brand-border p-4 text-[12px] text-brand-muted"
                  >
                    商品已下架
                  </div>
                );
              }
              return (
                <div
                  key={fav.id}
                  className="bg-brand-card rounded-3xl border border-brand-border overflow-hidden flex flex-col"
                >
                  <div
                    onClick={() => navigate(`/product/${product.id}`)}
                    className="cursor-pointer"
                  >
                    <img
                      src={product.image || '/placeholder-fruit.png'}
                      alt={product.name}
                      className="w-full h-[140px] object-cover"
                    />
                    <div className="p-3">
                      <p className="text-[14px] font-bold text-brand-dark line-clamp-1">
                        {product.name}
                      </p>
                      <div className="flex items-baseline gap-1 mt-1">
                        <span className="text-xs text-brand-primary font-bold">¥</span>
                        <span className="text-lg font-extrabold text-brand-primary font-display leading-none">
                          {product.price}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className="px-3 pb-3">
                    <button
                      onClick={() => handleRemove(fav)}
                      disabled={removingId === fav.id}
                      className="w-full py-1.5 text-[12px] rounded-full border border-brand-border text-brand-muted hover:text-brand-coral hover:border-brand-coral disabled:opacity-50 transition-colors"
                    >
                      {removingId === fav.id ? '处理中...' : '取消收藏'}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {!loading && totalPages > 1 && (
          <div className="mt-5 flex items-center justify-center gap-3">
            <Button
              variant="ghost"
              size="sm"
              disabled={page <= 1}
              onClick={() => fetchPage(Math.max(1, page - 1))}
            >
              上一页
            </Button>
            <span className="text-[12px] text-brand-muted">
              {page} / {totalPages}
            </span>
            <Button
              variant="ghost"
              size="sm"
              disabled={page >= totalPages}
              onClick={() => fetchPage(Math.min(totalPages, page + 1))}
            >
              下一页
            </Button>
          </div>
        )}
      </main>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/pages/Favorites.tsx
git commit -m "refactor(web): Favorites 用 NavBar/EmptyState/Button 对齐设计"
```

---

## Task 10: 改造 Profile 页面

**Files:**

- Modify: `packages/web/src/pages/Profile.tsx`

- [ ] **Step 1: `bg-brand-canvas` → `bg-brand-bg`，按钮用 Button**

只替换 `return` 块中的外层 div className、header、编辑/保存按钮。

关键 diff（按 Edit 工具应用）：

1. 把 `<div className="min-h-screen bg-brand-canvas pb-20">` 改为 `<div className="min-h-screen bg-brand-bg pb-20">`
2. 把 `<header className="sticky top-0 z-50 bg-brand-canvas/90 ...">` 改为 `<header className="sticky top-0 z-50 bg-brand-bg/90 ...">`
3. 在文件顶部 import：`import { Button } from '@/components/ui';`
4. 「编辑资料」按钮：
   ```tsx
   <Button
     variant="primary"
     fullWidth={false}
     className="mt-2 w-full max-w-[220px]"
     onClick={() => {
       setNickname(user.nickname ?? '');
       setIsEditing(true);
     }}
   >
     编辑资料
   </Button>
   ```
5. 保存/取消按钮（编辑态）：
   ```tsx
   <Button
     variant="primary"
     size="sm"
     disabled={saving || nickname.trim().length === 0}
     onClick={handleSave}
   >
     {saving ? '保存中...' : '保存'}
   </Button>
   <Button
     variant="ghost"
     size="sm"
     disabled={saving}
     onClick={handleCancel}
   >
     取消
   </Button>
   ```

- [ ] **Step 2: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/pages/Profile.tsx
git commit -m "refactor(web): Profile 修正 canvas→bg token + 用 Button"
```

---

## Task 11: 改造 Cart 页面

**Files:**

- Modify: `packages/web/src/pages/Cart.tsx`

**改动要点：**

- header：`bg-white/90 border-b border-gray-100` → 用 `NavBar`（无 back，title="购物车"，右侧放清空按钮）
- 商品卡片：`bg-white shadow-sm` → `bg-brand-card border border-brand-border`；圆角保持 `rounded-2xl`
- 数量按钮：保持原样（已用 `bg-gray-100` → `bg-brand-btn-bg`，`bg-brand-primary` 保留）
- checkbox：`border-gray-300` → `border-brand-border`
- 底部结算栏：替换为 `<BottomActionBar>`
- 空态：替换为 `<EmptyState>`，CTA 用 `<Button>`
- Toast 引入从 `@/components/Toast` 改为统一保持
- 文字颜色 `text-gray-*` → `text-brand-*`

- [ ] **Step 1: 顶部 imports 调整**

```tsx
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useCartStore } from '@/store/cart.store';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Toast } from '@/components/Toast';
import { NavBar, BottomActionBar, EmptyState, Button } from '@/components/ui';
```

- [ ] **Step 2: Empty state 替换**

把现有的空态 `return` 块替换为：

```tsx
if (items.length === 0) {
  return (
    <div className="min-h-screen bg-brand-bg pb-20">
      <NavBar title="购物车" showBack={false} />
      <EmptyState
        title="购物车空空如也"
        description="去挑选喜欢的水果吧"
        action={
          <Button variant="primary" size="md" onClick={() => navigate('/')}>
            去逛逛
          </Button>
        }
      />
    </div>
  );
}
```

- [ ] **Step 3: 主 return 替换 header**

把现有 `<header>...` 块替换为：

```tsx
<NavBar
  title="购物车"
  showBack={false}
  right={
    <div className="flex items-center gap-3">
      <span className="text-sm text-brand-muted">{items.length}件商品</span>
      {items.length > 0 && (
        <button onClick={() => setClearTarget(true)} className="text-brand-coral text-sm font-bold">
          清空
        </button>
      )}
    </div>
  }
/>
```

- [ ] **Step 4: 主 return 替换商品卡片容器 className**

将：

```
className="bg-white rounded-2xl p-4 flex gap-3 shadow-sm"
```

改为：

```
className="bg-brand-card rounded-2xl border border-brand-border p-4 flex gap-3"
```

- [ ] **Step 5: 替换所有文字色**

- `text-gray-900` → `text-brand-dark`
- `text-gray-800` → `text-brand-dark`
- `text-gray-600` → `text-brand-muted`
- `text-gray-500` → `text-brand-muted`
- `text-gray-400` → `text-brand-muted`
- `text-gray-300` → `text-brand-muted/60`
- `border-gray-100` → `border-brand-border`
- `border-gray-200` → `border-brand-border`
- `border-gray-300`（checkbox）→ `border-brand-border`
- `bg-gray-100`（数量减号、占位图）→ `bg-brand-btn-bg`
- `bg-gray-200`（数量减号 hover）→ `hover:bg-brand-bg`

- [ ] **Step 6: 底部结算栏替换**

把 `<div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-100 z-50 safe-bottom">...` 整块替换为：

```tsx
<BottomActionBar>
  <button onClick={toggleSelectAll} className="flex items-center gap-2">
    <span
      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
        isSelectedAll() ? 'bg-brand-primary border-brand-primary' : 'border-brand-border'
      }`}
    >
      {isSelectedAll() && (
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3">
          <polyline points="20 6 9 17 4 12" />
        </svg>
      )}
    </span>
    <span className="text-sm text-brand-muted">全选</span>
  </button>

  <div className="flex items-center gap-4">
    <div className="text-right">
      <span className="text-sm text-brand-muted">合计：</span>
      <span className="text-lg font-bold text-brand-primary">¥{Number(total).toFixed(2)}</span>
    </div>
    <Button variant="primary" disabled={selectedCount === 0 || isUpdating} onClick={handleCheckout}>
      结算({selectedCount})
    </Button>
  </div>
</BottomActionBar>
```

- [ ] **Step 7: 清空确认 modal token 修正**

将 modal 内 `border border-brand-border font-bold` 保持；「确定清空」按钮改用 `<Button variant="danger">`，「取消」改用 `<Button variant="ghost">`。

```tsx
{
  clearTarget && (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-3xl p-6 w-full max-w-xs">
        <p className="text-center text-brand-dark font-bold mb-4">确定清空购物车？此操作不可撤销</p>
        <div className="flex gap-2">
          <Button variant="danger" fullWidth onClick={confirmClear}>
            确定清空
          </Button>
          <Button variant="ghost" fullWidth onClick={() => setClearTarget(false)}>
            取消
          </Button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 8: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 9: 手动验证**

启动 `pnpm --filter web dev`，访问 `/cart`：

- 空态显示 EmptyState
- 有商品时卡片有边框无阴影
- 底部栏样式正确，结算按钮可点

- [ ] **Step 10: Commit**

```bash
git add packages/web/src/pages/Cart.tsx
git commit -m "refactor(web): Cart 全面对齐 brand token + 公共组件"
```

---

## Task 12: 改造 Checkout 页面

**Files:**

- Modify: `packages/web/src/pages/Checkout.tsx`

**改动要点：**

- header 替换为 `<NavBar title="确认订单" />`
- 3 个 section 卡片：`bg-white rounded-2xl shadow-sm` → `bg-brand-card rounded-2xl border border-brand-border`
- 底部栏替换为 `<BottomActionBar>`
- 提交按钮用 `<Button>`
- 所有 `text-gray-*` / `border-gray-*` / `bg-gray-*` → brand token

- [ ] **Step 1: imports 调整**

在顶部加：

```tsx
import { NavBar, BottomActionBar, Button } from '@/components/ui';
```

- [ ] **Step 2: header 替换**

把现有 `<header>...` 块替换为：

```tsx
<NavBar title="确认订单" />
```

- [ ] **Step 3: 3 个 section 卡片 className 替换**

全部把：

```
className="bg-white rounded-2xl p-4 ... shadow-sm"
```

改为：

```
className="bg-brand-card rounded-2xl border border-brand-border p-4 ..."
```

- [ ] **Step 4: token 全局替换（在 Checkout.tsx 范围内）**

- `text-gray-900` → `text-brand-dark`
- `text-gray-800` → `text-brand-dark`
- `text-gray-700` → `text-brand-dark`
- `text-gray-600` → `text-brand-muted`
- `text-gray-500` → `text-brand-muted`
- `text-gray-400` → `text-brand-muted`
- `border-gray-100` → `border-brand-border`
- `border-gray-200` → `border-brand-border`
- `bg-gray-100` → `bg-brand-btn-bg`
- `placeholder-gray-400` → `placeholder-brand-muted/70`

- [ ] **Step 5: 底部栏替换**

把 `<div className="fixed bottom-0 ...">` 块替换为：

```tsx
<BottomActionBar>
  <div>
    <span className="text-sm text-brand-muted">应付：</span>
    <span className="text-xl font-bold text-brand-primary">¥{Number(totalAmount).toFixed(2)}</span>
  </div>
  <Button variant="primary" loading={isSubmitting} onClick={handleSubmit}>
    {isSubmitting ? '提交中...' : '提交订单'}
  </Button>
</BottomActionBar>
```

- [ ] **Step 6: 验证编译 + 手动跑流程**

Run: `pnpm --filter web build`
然后 `pnpm --filter web dev`，从购物车结算进入 `/checkout`，确认布局无错位。

- [ ] **Step 7: Commit**

```bash
git add packages/web/src/pages/Checkout.tsx
git commit -m "refactor(web): Checkout 对齐 brand token + 公共组件"
```

---

## Task 13: 改造 OrderList 页面

**Files:**

- Modify: `packages/web/src/pages/OrderList.tsx`

**改动要点：**

- header + 状态 tab 整合：用 `<NavBar>` 包住 title 和 tabs（注意 tabs 需要换行布局，NavBar 单行不够；保留现有双行结构，只换外层 header 容器样式）
- 状态 tab 默认态：`bg-gray-100 text-gray-600` → `bg-white text-brand-muted border border-brand-border`
- 卡片：`bg-white rounded-2xl shadow-sm` → `bg-brand-card rounded-2xl border border-brand-border`；`hover:shadow-md` → `hover:border-brand-primary/30`
- 空态替换为 `<EmptyState>`
- 加载更多按钮用 `<Button variant="ghost">`

- [ ] **Step 1: imports**

```tsx
import { NavBar, EmptyState, Button } from '@/components/ui';
```

- [ ] **Step 2: header 替换**

把现有 `<header>...` 块替换为：

```tsx
<header className="sticky top-0 z-30 bg-brand-bg/90 backdrop-blur-[10px] border-b border-brand-border">
  <div className="max-w-lg mx-auto">
    <div className="px-4 py-3">
      <h1 className="text-lg font-semibold text-brand-dark text-center">我的订单</h1>
    </div>
    <div className="flex overflow-x-auto px-2 pb-2 scrollbar-hide">
      {STATUS_TABS.map((tab) => (
        <button
          key={tab.label}
          onClick={() => handleTabChange(tab.value)}
          className={`px-3 py-1.5 text-xs font-medium rounded-full whitespace-nowrap transition-colors ${
            activeTab === tab.value
              ? 'bg-brand-primary text-white'
              : 'bg-white text-brand-muted border border-brand-border hover:border-brand-primary/30'
          }`}
        >
          {tab.label}
        </button>
      ))}
    </div>
  </div>
</header>
```

- [ ] **Step 3: 空态替换**

把现有空态 `<div className="flex flex-col items-center justify-center py-32">...</div>` 块替换为：

```tsx
<EmptyState title="暂无订单" />
```

- [ ] **Step 4: OrderCard 样式替换**

把 OrderCard 函数内：

- `className="bg-white rounded-2xl p-4 shadow-sm cursor-pointer hover:shadow-md transition-shadow"`
  → `className="bg-brand-card rounded-2xl border border-brand-border p-4 cursor-pointer hover:border-brand-primary/30 transition-colors"`
- `text-gray-400` → `text-brand-muted`
- `text-gray-600` → `text-brand-muted`
- `text-gray-300` → `text-brand-muted/60`
- `border-gray-50` → `border-brand-border/50`

- [ ] **Step 5: 加载更多按钮替换**

```tsx
{
  page < totalPages && (
    <div className="flex justify-center py-4">
      <Button variant="ghost" size="sm" loading={isLoading} onClick={handleLoadMore}>
        查看更多
      </Button>
    </div>
  );
}
```

- [ ] **Step 6: 验证编译**

Run: `pnpm --filter web build`
Expected: 编译成功

- [ ] **Step 7: Commit**

```bash
git add packages/web/src/pages/OrderList.tsx
git commit -m "refactor(web): OrderList 对齐 brand token + 公共组件"
```

---

## Task 14: 改造 OrderDetail 页面

**Files:**

- Modify: `packages/web/src/pages/OrderDetail.tsx`

**改动要点：**

- header 替换为 `<NavBar title="订单详情" />`
- 商品小图 `rounded-lg` → `rounded-xl`
- 占位图背景 `bg-gray-100` → `bg-brand-btn-bg`
- 所有 `text-gray-*` / `border-gray-*` → brand token
- 底部操作栏替换为 `<BottomActionBar>`
- 所有操作按钮（去支付/取消订单/确认收货/申请退款/去评价/返回列表）用 `<Button>`，按语义选 variant
- modal 样式：边框、文字色统一

- [ ] **Step 1: imports**

```tsx
import { NavBar, BottomActionBar, Button } from '@/components/ui';
```

- [ ] **Step 2: header 替换**

把 `<header>...` 块替换为 `<NavBar title="订单详情" />`

- [ ] **Step 3: 全局 token 替换**

- `text-gray-900` → `text-brand-dark`
- `text-gray-800` → `text-brand-dark`
- `text-gray-600` → `text-brand-muted`
- `text-gray-500` → `text-brand-muted`
- `text-gray-400` → `text-brand-muted`
- `text-gray-300` → `text-brand-muted/60`
- `border-gray-100` → `border-brand-border`
- `border-gray-200` → `border-brand-border`
- `bg-gray-100`（返回按钮、占位图）→ `bg-brand-btn-bg`
- `hover:bg-gray-200` → `hover:bg-brand-bg`
- `rounded-lg`（商品小图）→ `rounded-xl`

- [ ] **Step 4: 商品小图占位背景**

`<div className="w-14 h-14 rounded-lg overflow-hidden bg-gray-100 flex-shrink-0">`
→ `<div className="w-14 h-14 rounded-xl overflow-hidden bg-brand-btn-bg flex-shrink-0">`

- [ ] **Step 5: section 卡片去 shadow 加 border**

3 个 section：`bg-white rounded-2xl p-4 shadow-sm` → `bg-brand-card rounded-2xl border border-brand-border p-4`

- [ ] **Step 6: 底部操作栏替换**

把 `<div className="fixed bottom-0 ...">` 块替换为：

```tsx
{
  hasActionButtons && (
    <BottomActionBar>
      <Button variant="ghost" fullWidth onClick={() => navigate('/orders')}>
        返回列表
      </Button>
      {showPayBtn && (
        <Button variant="primary" loading={isPaying} disabled={isCancelling} onClick={handlePay}>
          {isPaying ? '支付中...' : '去支付'}
        </Button>
      )}
      {showPayBtn && (
        <Button variant="danger" loading={isCancelling} disabled={isPaying} onClick={handleCancel}>
          {isCancelling ? '取消中...' : '取消订单'}
        </Button>
      )}
      {showConfirmBtn && (
        <Button variant="primary" loading={isConfirming} onClick={handleConfirm}>
          {isConfirming ? '处理中...' : '确认收货'}
        </Button>
      )}
      {showRefundBtn && (
        <Button variant="ghost" onClick={openRefundModal} disabled={isConfirming}>
          <span className="text-brand-coral">申请退款</span>
        </Button>
      )}
      {showReviewBtn && (
        <Button
          variant="primary"
          onClick={() => {
            const drafts: Record<number, { rating: number; content: string }> = {};
            order.items.forEach((it) => {
              drafts[it.productId] = { rating: 5, content: '' };
            });
            setReviewDrafts(drafts);
            setShowReviewModal(true);
          }}
        >
          去评价
        </Button>
      )}
    </BottomActionBar>
  );
}
```

- [ ] **Step 7: 退款 modal 样式修正**

- textarea `border-gray-200` → `border-brand-border`，`rounded-lg` → `rounded-xl`
- 取消按钮 → `<Button variant="ghost">`
- 提交按钮 → `<Button variant="danger">`

- [ ] **Step 8: 评价 modal 样式修正**

- 「关闭」按钮（右上角 ×）的 `bg-gray-100` → `bg-brand-btn-bg`
- `border-gray-200` → `border-brand-border`

- [ ] **Step 9: 验证编译 + 手动跑流程**

Run: `pnpm --filter web build`
启动 dev，从订单列表点入订单详情，测试各状态按钮显示。

- [ ] **Step 10: Commit**

```bash
git add packages/web/src/pages/OrderDetail.tsx
git commit -m "refactor(web): OrderDetail 对齐 brand token + 公共组件"
```

---

## Task 15: 全局 token 清查验收

**Files:**

- 验收：整个 `packages/web/src/`

- [ ] **Step 1: Grep 清查 gray-\***

Run:

```bash
cd packages/web && grep -rn "gray-\(100\|200\|300\|400\|500\|600\|700\|800\|900\)" src/pages/ src/components/ \
  --include="*.tsx" --include="*.ts" \
  | grep -v "src/components/ui/" \
  | grep -v "LoadingSpinner"
```

Expected: 无输出（或仅 LoadingSpinner 内部）

如有残留，按映射表修正。

- [ ] **Step 2: Grep 清查 shadow-\***

Run:

```bash
cd packages/web && grep -rn "shadow-sm\|shadow-md\|shadow-lg" src/pages/ src/components/ \
  --include="*.tsx" --include="*.ts" \
  | grep -v "src/components/ui/" \
  | grep -v "LoadingSpinner" \
  | grep -v "Toast"
```

Expected: 无输出（Toast 的 shadow-lg 可保留，它是浮动提示）

如有残留，改成 `border border-brand-border`。

- [ ] **Step 3: 最终编译验证**

Run: `pnpm --filter web build`
Expected: 编译成功，无 TS 错误、无 warning

- [ ] **Step 4: 手动全流程验证**

启动 `pnpm --filter web dev`（需后端 + shared 先起来），跑核心流程：

- 首页 → 商品详情 → 加购 → 购物车 → 结算 → 下单 → 订单列表 → 订单详情
- 订单详情各状态按钮（支付/取消/确认/退款/评价）
- 登录、注册、登出
- 收藏列表、个人中心、地址簿入口
- 移动端分辨率 375 / 390 / 414 下布局无错位

- [ ] **Step 5: Commit（如有修正）**

```bash
git add -A
git commit -m "style(web): token 清查收尾，视觉一致性验收完成"
```

---

## Self-Review

**1. Spec coverage：** spec 中 6 个公共组件 → Task 1-6 全部覆盖；8 个页面改动 → Task 7-14 全部覆盖；token 修正映射表 → Task 11-14 内嵌执行 + Task 15 验收；测试策略与 DoD → Task 15。✅

**2. Placeholder scan：** 无 TBD / TODO / 「类似 Task N」/「添加适当的错误处理」等占位符。每步都有完整代码或精确 diff。✅

**3. Type consistency：** 公共组件 API（NavBar/BottomActionBar/Button/IconButton/EmptyState/Tag 的 props 名称、variant 值）在定义任务（Task 1-6）与使用任务（Task 7-14）中完全一致。✅
