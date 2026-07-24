# Spec: Web 项目对齐 DESIGN.md 全面修复

> 日期：2026-06-05
> 目标：让 `packages/web` 所有页面和组件与 `DESIGN.md` 完全对齐

## 背景

`DESIGN.md` 已定义完整的暖橙色系设计系统（12 色 token、Fredoka/Noto Sans SC 字体、圆角/间距规范）。当前 Home 和 ProductDetail 页面对齐度 ~85%，但存在 7 类差异，且 7 个旧页面完全使用旧 token 体系。

## 修复范围（7 项，不遗漏）

### 1. 补全 Google Fonts 字重

**文件**：`packages/web/index.html` 第 12 行

当前加载：`Fredoka:wght@400;500;600;700` + `Noto+Sans+SC:wght@300;400;500;700`

修改为：

- `Fredoka:wght@400;500;600;700;800`（补 800/extrabold）
- `Noto+Sans+SC:wght@300;400;500;700;900`（补 900/black）

### 2. @theme 添加语义变量

**文件**：`packages/web/src/styles/index.css`

在 `@theme` 块中新增：

```css
/* 圆角语义 token */
--radius-sm: 8px;
--radius-md: 16px;
--radius-lg: 20px;
--radius-xl: 24px;
--radius-2xl: 32px;
--radius-full: 9999px;

/* 渐变 token */
--gradient-cta: linear-gradient(135deg, #ff6b35, #ff7675);
--gradient-promo: linear-gradient(135deg, #ff6b35 0%, #ff7675 50%, #f7c948 100%);
--gradient-desc: linear-gradient(135deg, #ffeaa744, #f7c94822);
```

### 3. SVG stroke 改用 currentColor

**涉及文件和行号**：

| 文件                | 行号          | 当前值             | 改为                                       |
| ------------------- | ------------- | ------------------ | ------------------------------------------ |
| `Home.tsx`          | 92, 105       | `stroke="#2D3436"` | 移除 stroke 属性，外层加 `text-brand-dark` |
| `ProductDetail.tsx` | 108, 122, 136 | `stroke="#2D3436"` | 同上                                       |
| `SearchBar.tsx`     | 39            | `stroke="#636E72"` | 移除 stroke，外层 `text-brand-muted`       |
| `ProductName.tsx`   | 17            | `stroke="#00B894"` | 移除 stroke，外层 `text-brand-green`       |

方法：在 SVG 上设 `stroke="currentColor"`，通过父元素 className 控制颜色。

### 4. 硬编码渐变/颜色改用 CSS 变量

**涉及文件**：

| 文件               | 行号  | 改动                                                                                                                                      |
| ------------------ | ----- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `BuyBar.tsx`       | 69    | `style={{ background: 'linear-gradient(135deg, #FF6B35, #FF7675)' }}` → `className="bg-[var(--gradient-cta)]"`                            |
| `PromoBanner.tsx`  | 7     | 同理用 `var(--gradient-promo)`                                                                                                            |
| `Description.tsx`  | 13-14 | `background` 用 `var(--gradient-desc)`，`borderColor` 用 `var(--color-brand-peach)` + 透明度                                              |
| `ProductHero.tsx`  | 17    | `#FFF8F0` → `var(--color-brand-bg)`                                                                                                       |
| `SpecSelector.tsx` | 38-39 | `#FF6B35` → `var(--color-brand-primary)`，`#eee` → `var(--color-brand-border)`，`#FFFFFF` → `var(--color-brand-card)`                     |
| `PriceSection.tsx` | 30-32 | `#FF6B35` / `#F7C948` / `#2D3436` 用 `var(--color-brand-*)`，带透明度用 `color-mix(in srgb, var(--color-brand-primary) 10%, transparent)` |
| `SearchBar.tsx`    | 39    | 已在 #3 处理                                                                                                                              |
| `ProductName.tsx`  | 17    | 已在 #3 处理                                                                                                                              |

### 5. PriceSection Tag 圆角修正

**文件**：`PriceSection.tsx` 第 28 行

`rounded-[20px]` → `rounded-full`（DESIGN.md 规定 Tag 为 pill 形 9999px）

### 6. Toast + LoadingSpinner 迁移到 brand token

**Toast.tsx**（第 47-50 行）：

```ts
// 旧
success: 'bg-success text-white',
error: 'bg-danger text-white',
warning: 'bg-warning text-gray-900',
info: 'bg-info text-white',

// 新
success: 'bg-brand-green text-white',
error: 'bg-brand-coral text-white',
warning: 'bg-brand-secondary text-brand-dark',
info: 'bg-brand-accent text-white',
```

圆角 `rounded-lg`（第 60 行）→ `rounded-2xl`

**LoadingSpinner.tsx**（第 17 行）：
`var(--color-primary)` → `var(--color-brand-primary)`

### 7. 旧页面全面对齐 DESIGN.md

7 个旧页面按 DESIGN.md 全部规范重写样式。每个页面的改动清单：

#### 7a. 通用改动（所有旧页面）

- 页面背景 `bg-gray-50` → `bg-brand-bg`
- 输入框圆角 `rounded-xl` / `rounded-lg` → `rounded-2xl`
- 按钮 `bg-primary` → `bg-brand-primary`
- 标题/链接 `text-primary` → `text-brand-primary`
- focus 样式 `focus:ring-primary/30 focus:border-primary` → `focus:ring-brand-primary/30 focus:border-brand-primary`

#### 7b. Login.tsx

| 行号   | 当前                                                        | 改为                                                                     |
| ------ | ----------------------------------------------------------- | ------------------------------------------------------------------------ |
| 38     | `bg-gray-50`                                                | `bg-brand-bg`                                                            |
| 41     | `text-primary`                                              | `text-brand-primary`                                                     |
| 58, 71 | `rounded-xl` + `focus:ring-primary/30 focus:border-primary` | `rounded-2xl` + `focus:ring-brand-primary/30 focus:border-brand-primary` |
| 78     | `bg-primary rounded-xl`                                     | `bg-brand-primary rounded-2xl`                                           |
| 88     | `text-primary`                                              | `text-brand-primary`                                                     |

#### 7c. Register.tsx

与 Login 结构一致，同样改动：

- `bg-gray-50` → `bg-brand-bg`
- 所有 `text-primary` → `text-brand-primary`
- 所有 `bg-primary` → `bg-brand-primary`
- 所有 `focus:ring-primary/30 focus:border-primary` → `focus:ring-brand-primary/30 focus:border-brand-primary`
- `rounded-xl` → `rounded-2xl`

#### 7d. Cart.tsx

| 行号         | 当前                        | 改为                                    |
| ------------ | --------------------------- | --------------------------------------- |
| 77, 102      | `bg-gray-50`                | `bg-brand-bg`                           |
| 92, 187, 244 | `bg-primary`                | `bg-brand-primary`                      |
| 123, 222     | `bg-primary border-primary` | `bg-brand-primary border-brand-primary` |
| 161, 237     | `text-primary`              | `text-brand-primary`                    |
| 201          | `hover:text-danger`         | `hover:text-brand-coral`                |

#### 7e. Checkout.tsx

| 行号          | 当前                                                        | 改为                                                                     |
| ------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------ |
| 67            | `bg-gray-50`                                                | `bg-brand-bg`                                                            |
| 96, 108, 122  | `focus:ring-primary/30 focus:border-primary` + `rounded-xl` | `focus:ring-brand-primary/30 focus:border-brand-primary` + `rounded-2xl` |
| 147, 177, 191 | `text-primary`                                              | `text-brand-primary`                                                     |
| 166           | `text-success`                                              | `text-brand-green`                                                       |
| 198           | `bg-primary`                                                | `bg-brand-primary`                                                       |

#### 7f. OrderList.tsx

| 行号  | 当前                                                                            | 改为                                                                                     |
| ----- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| 26-30 | STATUS_COLORS 用 `text-warning` / `text-info` / `text-primary` / `text-success` | `text-brand-secondary` / `text-brand-accent` / `text-brand-primary` / `text-brand-green` |
| 58    | `bg-gray-50`                                                                    | `bg-brand-bg`                                                                            |
| 73    | `bg-primary text-white`                                                         | `bg-brand-primary text-white`                                                            |
| 118   | `text-primary border border-primary/30`                                         | `text-brand-primary border border-brand-primary/30`                                      |
| 156   | `text-primary`                                                                  | `text-brand-primary`                                                                     |

#### 7g. OrderDetail.tsx

| 行号              | 当前                                                                                | 改为                                                                                             |
| ----------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 17-21             | STATUS_BG 用 `bg-warning` / `bg-info` / `bg-primary` / `bg-success` / `bg-gray-400` | `bg-brand-secondary` / `bg-brand-accent` / `bg-brand-primary` / `bg-brand-green` / `bg-gray-400` |
| 67, 107, 151, 162 | `text-primary`                                                                      | `text-brand-primary`                                                                             |
| 78                | `bg-gray-50`                                                                        | `bg-brand-bg`                                                                                    |
| 182               | `bg-danger`                                                                         | `bg-brand-coral`                                                                                 |

#### 7h. AdminProducts.tsx

| 行号                    | 当前                                               | 改为                                                              |
| ----------------------- | -------------------------------------------------- | ----------------------------------------------------------------- |
| 18                      | `text-success`                                     | `text-brand-green`                                                |
| 198                     | `bg-gray-50`                                       | `bg-brand-bg`                                                     |
| 215, 234, 484           | `bg-primary`                                       | `bg-brand-primary`                                                |
| 230, 364-466（约 9 处） | `focus:ring-primary/30 focus:border-primary`       | `focus:ring-brand-primary/30 focus:border-brand-primary`          |
| 74, 284, 303, 328       | `text-primary`                                     | `text-brand-primary`                                              |
| 303                     | `hover:bg-primary/10`                              | `hover:bg-brand-primary/10`                                       |
| 309, 512                | `text-danger` / `bg-danger` / `hover:bg-danger/10` | `text-brand-coral` / `bg-brand-coral` / `hover:bg-brand-coral/10` |
| 251                     | `rounded-xl`（表格）                               | `rounded-2xl`                                                     |
| 364-466                 | `rounded-lg`（表单输入框，约 10 处）               | `rounded-2xl`                                                     |

## 旧 token 清理

完成上述迁移后，`index.css` 中的旧 token（第 19-27 行）可移除注释「保留旧 token 供其他页面用」，因为已无页面使用。保留旧 token 定义本身（避免外部依赖），但加注释标注「已无内部使用」。

## 不修改的内容

- `index.css` 中的灰色梯度（`gray-50` 到 `gray-900`）— 标准 Tailwind 灰阶，仍在使用
- `ProductCard.tsx` 的动态 color 拼接（`product.color + 'CC'`）— 数据驱动，无法用 token 替代
- 组件结构和功能逻辑 — 仅改样式
