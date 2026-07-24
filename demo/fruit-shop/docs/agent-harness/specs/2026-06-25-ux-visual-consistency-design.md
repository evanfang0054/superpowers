# 鲜果集 Web 端视觉一致性与公共组件抽取

- **日期**：2026-06-25
- **范围**：`packages/web/src/`（纯前端，不动后端/shared/Docker/DESIGN.md）
- **目标**：消除跨页面的视觉与交互不一致，把重复的 UI 模式抽成公共组件，所有页面对齐 `DESIGN.md` 的暖橙圆润设计语言

## 1. 背景与问题

### 1.1 现状

`Home.tsx` 和 `ProductDetail.tsx` 是 1:1 对齐静态模板的基准页面，使用 `brand-*` token、`backdrop-blur`、`border-brand-border`，视觉正确。

其余 8 个页面（Cart / Checkout / OrderList / OrderDetail / Favorites / Profile / Login / Register）是早期或后续添加的，存在系统性视觉偏差：

- **颜色 token 混用**：大量 `text-gray-900/800/600/500/400`、`bg-gray-100`、`border-gray-100/200`，违反 DESIGN.md「不要纯黑、用 brand-dark / brand-muted」规则
- **层级工具错用**：卡片用 `shadow-sm` / `hover:shadow-md` 而非 `border border-brand-border`，违反「用边框而非阴影区分卡片」规则
- **NavBar 各写各的**：至少 5 种内联 NavBar 实现，背景透明度、blur 值、边框颜色、高度均不一致
- **按钮样式散乱**：几十处 `bg-brand-primary ... rounded-full` 散写，圆角（full / 2xl）、颜色、loading 态表达参差
- **底部操作栏重复**：Cart / Checkout / OrderDetail 三处各手写一遍 `fixed bottom-0 bg-white border-t safe-bottom`
- **空态各写**：Cart / OrderList / Favorites 三种不同空态实现，图标、文案、CTA 风格不一

### 1.2 用户选择

- **痛点优先级**：视觉一致性（用户在 4 类问题中选择）
- **改造策略**：抽取公共组件（用户在 A/B/C 方案中选择 A），根治重复代码 + 视觉不一致

## 2. 设计

### 2.1 新增公共组件（`src/components/ui/`）

新建 `src/components/ui/` 目录，放 6 个公共组件 + `index.ts` 聚合导出。

#### 2.1.1 `NavBar`

顶部 sticky 导航。

```tsx
interface NavBarProps {
  title?: React.ReactNode;
  left?: React.ReactNode;
  right?: React.ReactNode;
  showBack?: boolean; // 默认 true；首页设 false
  sticky?: boolean; // 默认 true
}
```

- 外层：`bg-brand-bg/90 backdrop-blur-[10px] border-b border-brand-border h-12 flex items-center px-4`
- `sticky` 为 true 时加 `sticky top-0 z-50`
- `showBack` 为 true 且未传 `left` 时，自动渲染左侧返回箭头（`IconButton` variant=ghost shape=circle），点击 `navigate(-1)`
- 中间 title 区：`flex-1 text-center font-bold text-[17px] text-brand-dark`（title 传入时）
- 右侧 right 区：`flex items-center gap-3`
- **不强制 `max-w-lg`**：布局宽度由外层页面决定，NavBar 内部仅 `px-4`

#### 2.1.2 `BottomActionBar`

底部固定操作栏。

```tsx
interface BottomActionBarProps {
  children: React.ReactNode;
  className?: string;
}
```

- 外层：`fixed bottom-0 inset-x-0 bg-white/95 backdrop-blur-[12px] border-t-[1.5px] border-brand-border z-40 safe-bottom`
- 内容容器：`max-w-lg mx-auto px-4 py-3 flex items-center justify-between`

#### 2.1.3 `Button`

通用按钮，4 种 variant × 3 种 size。

```tsx
type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant; // 默认 'primary'
  size?: ButtonSize; // 默认 'md'
  loading?: boolean;
  fullWidth?: boolean;
}
```

| variant   | 背景                                                  | 文字       | 圆角        | 备注                    |
| --------- | ----------------------------------------------------- | ---------- | ----------- | ----------------------- |
| primary   | `bg-gradient-to-br from-brand-primary to-brand-coral` | white      | rounded-2xl | 加 `animate-pulse-glow` |
| secondary | `bg-brand-secondary`                                  | brand-dark | rounded-2xl |                         |
| ghost     | `bg-transparent border border-brand-border`           | brand-dark | rounded-2xl | hover `bg-brand-bg`     |
| danger    | `bg-brand-coral`                                      | white      | rounded-2xl |                         |

- size：sm = `px-4 py-1.5 text-sm`，md = `px-6 py-2.5 text-sm`，lg = `px-8 py-3 text-base`
- `fullWidth` 时加 `w-full`
- `loading` 时显示 spinner 并 `disabled`
- 统一 `disabled:opacity-50 disabled:active:scale-100 transition-all`
- 非禁用态 active `scale-[0.98]`

#### 2.1.4 `IconButton`

圆形/方形小按钮。

```tsx
interface IconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'ghost' | 'solid'; // 默认 ghost
  shape?: 'circle' | 'square'; // 默认 circle
  size?: 'sm' | 'md' | 'lg'; // sm=28, md=36, lg=44
}
```

- ghost 背景：`bg-brand-btn-bg hover:bg-brand-bg`
- solid 背景：`bg-brand-primary text-white`
- shape：circle = `rounded-full`，square = `rounded-xl`
- 必须传 `aria-label`（无障碍）

#### 2.1.5 `EmptyState`

空态。

```tsx
interface EmptyStateProps {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: React.ReactNode;
}
```

- 容器：`flex flex-col items-center justify-center py-32`
- icon：默认通用空箱 SVG，`text-brand-muted/60` + 尺寸 64-80px
- title：`text-brand-muted text-sm mt-4`
- description：`text-brand-muted/70 text-xs mt-1`
- action：`mt-4`，通常放一个 `Button` 或 `Link`

#### 2.1.6 `Tag`

标签/Badge。

```tsx
interface TagProps {
  children: React.ReactNode;
  variant?: 'primary' | 'success' | 'warning' | 'accent' | 'muted';
  size?: 'sm' | 'md';
}
```

| variant | 背景            | 文字        |
| ------- | --------------- | ----------- |
| primary | brand-primary   | white       |
| success | brand-green     | white       |
| warning | brand-secondary | brand-dark  |
| accent  | brand-accent    | white       |
| muted   | bg-brand-btn-bg | brand-muted |

- 圆角 `rounded-full`
- size sm：`px-2 py-0.5 text-[10px]`，md：`px-2.5 py-1 text-[11px]`

### 2.2 Token 修正映射表（全局严格执行）

| 现状                                                    | 改为                                                               |
| ------------------------------------------------------- | ------------------------------------------------------------------ |
| `bg-white/90 backdrop-blur-sm border-b border-gray-100` | `bg-brand-bg/90 backdrop-blur-[10px] border-b border-brand-border` |
| `bg-gray-100 hover:bg-gray-200`                         | `bg-brand-btn-bg hover:bg-brand-bg`                                |
| `bg-gray-100`（占位图背景）                             | `bg-brand-btn-bg`                                                  |
| `text-gray-900/800`                                     | `text-brand-dark`                                                  |
| `text-gray-600/500/400`                                 | `text-brand-muted`                                                 |
| `text-gray-300`                                         | `text-brand-muted/60`                                              |
| `border-gray-100/200`                                   | `border-brand-border`                                              |
| `bg-white shadow-sm`（卡片）                            | `bg-brand-card border border-brand-border`                         |
| `hover:shadow-md`                                       | `hover:border-brand-primary/30`                                    |
| `rounded-lg`（小图）                                    | `rounded-xl`                                                       |

### 2.3 页面改动清单

| 页面                         | 改动                                                                                                                                                           | 工作量 |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Cart.tsx                     | header → NavBar/PageHeader；卡片去 shadow 加 border；数量按钮换 IconButton；底部栏换 BottomActionBar；空态换 EmptyState；Button 统一；checkbox 边框 token 修正 | 大     |
| Checkout.tsx                 | header → NavBar；3 个 section 卡片去 shadow；返回按钮换 IconButton；底部栏换 BottomActionBar；提交按钮换 Button                                                | 中     |
| OrderList.tsx                | header → NavBar；状态 tab 配色对齐（激活 brand-primary，默认白底 brand-border）；卡片去 shadow 加 border hover；空态换 EmptyState；加载更多按钮换 Button       | 中     |
| OrderDetail.tsx              | header → NavBar；状态色块 label 文字色修正；商品小图圆角；操作按钮换 Button；modal 样式统一                                                                    | 中     |
| Favorites.tsx                | header → NavBar；空态换 EmptyState；分页按钮换 Button                                                                                                          | 小     |
| Profile.tsx                  | 外层 `bg-brand-canvas` → `bg-brand-bg`（canvas token 不存在）；编辑/取消按钮可换 Button                                                                        | 小     |
| Login.tsx / Register.tsx     | label `text-gray-*` → brand-muted；输入框 border 统一；按钮换 Button                                                                                           | 小     |
| Home.tsx / ProductDetail.tsx | 基准页面，基本不动。ProductDetail 收藏/分享按钮可顺手换 IconButton（非必需）                                                                                   | 极小   |

### 2.4 不改的部分

- `ProductCard` / `BuyBar` / `SpecSelector` / `TabBar` / `SearchBar` / `PromoBanner` / `CategoryTabs` / `DecorDots` — 基准风格来源或业务强耦合
- `DESIGN.md` — 设计权威源，本次改动是对齐它，不修改它
- `styles/index.css` — token 已完备，无需新增
- 后端、shared 包、Docker 配置

## 3. 未覆盖范围（明确排除）

- OrderList 状态 tab 切换 + 分页的功能性 bug（前端 filter 导致切 tab 丢失后续页数据）— 属功能 bug，超出视觉一致性范围
- 各页面 catch 块的重试 UI / 骨架屏升级
- LoadingSpinner 的视觉更新
- 文档（DESIGN.md / README.md）更新

## 4. 测试策略

项目无测试框架，本次不引入新测试基础设施（YAGNI）。采用以下轻量验证：

| 验证项          | 方法                                                                                                                        |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| TypeScript 编译 | `pnpm --filter web build` 必须通过                                                                                          |
| 视觉对比        | 改动前后逐页截图比对                                                                                                        |
| 交互回归        | 手动跑核心流程：首页→详情→加购→购物车→结算→下单→订单列表→订单详情→取消/退款/评价；收藏；登录登出                            |
| token 清查      | Grep 搜 `gray-\|shadow-` 在 `packages/web/src/pages/` 和 `packages/web/src/components/` 应零残留（LoadingSpinner 内部除外） |

## 5. 验收标准（Definition of Done）

1. `pnpm --filter web build` 通过，无 TS 错误
2. 新增 6 个公共组件文件 `src/components/ui/{NavBar,BottomActionBar,Button,IconButton,EmptyState,Tag}.tsx` + `index.ts`
3. 8 个页面（Cart / Checkout / OrderList / OrderDetail / Favorites / Profile / Login / Register）全部引用公共组件，不再内联 NavBar / 底部栏 / 按钮样式
4. Token 清查：pages/ 和 components/ 中 `gray-*` 和 `shadow-*` 类零残留（LoadingSpinner 内部除外）
5. 所有卡片容器使用 `border border-brand-border` 而非 `shadow-*`
6. Home / ProductDetail 视觉无回归
7. 移动端核心分辨率（375 / 390 / 414）下布局无错位、底部安全区正确

## 6. 风险与缓解

| 风险                                            | 缓解                                               |
| ----------------------------------------------- | -------------------------------------------------- |
| 抽组件改动面广，易引入回归                      | 按页面逐个改，每改一页手动验证该页流程，不批量替换 |
| `max-w-lg mx-auto` 布局差异                     | NavBar 不强制 max-w，由 children 自决              |
| DESIGN.md 与实际 token 名不一致（canvas vs bg） | 以 `styles/index.css` 中实际定义的 `brand-bg` 为准 |
| IconButton 语义在不同页面不同                   | 通过 `variant` + `aria-label` 区分                 |
