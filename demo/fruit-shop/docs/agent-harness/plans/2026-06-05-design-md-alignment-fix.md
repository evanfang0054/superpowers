# DESIGN.md 全面对齐修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `packages/web` 所有页面和组件的样式与 `DESIGN.md` 完全对齐，消除旧 token 残留

**Architecture:** 纯 CSS 变量 + Tailwind class 替换，不改组件结构和功能逻辑。分 7 个任务按依赖顺序执行：先基础设施（字体+CSS 变量），再组件级修复，最后旧页面批量迁移。

**Tech Stack:** React 18, Tailwind CSS v4 (`@theme` directive), Vite 6

**Spec:** `docs/agent-harness/specs/2026-06-05-design-md-alignment-fix.md`
**Contract:** `docs/agent-harness/contracts/design-md-alignment-fix.contract.md`

---

## File Map

| Action | File                                             | Responsibility                       |
| ------ | ------------------------------------------------ | ------------------------------------ |
| Modify | `packages/web/index.html`                        | Google Fonts 字重补全                |
| Modify | `packages/web/src/styles/index.css`              | 新增语义 token（radius + gradient）  |
| Modify | `packages/web/src/components/SearchBar.tsx`      | SVG stroke 改 currentColor           |
| Modify | `packages/web/src/components/ProductName.tsx`    | SVG stroke 改 currentColor           |
| Modify | `packages/web/src/components/BuyBar.tsx`         | 硬编码渐变 → CSS 变量                |
| Modify | `packages/web/src/components/PromoBanner.tsx`    | 硬编码渐变 → CSS 变量                |
| Modify | `packages/web/src/components/Description.tsx`    | 硬编码渐变+颜色 → CSS 变量           |
| Modify | `packages/web/src/components/ProductHero.tsx`    | 硬编码 hex → CSS 变量                |
| Modify | `packages/web/src/components/SpecSelector.tsx`   | 硬编码 hex → CSS 变量                |
| Modify | `packages/web/src/components/PriceSection.tsx`   | 硬编码 hex → CSS 变量 + rounded-full |
| Modify | `packages/web/src/components/Toast.tsx`          | 旧 token → brand token + rounded-2xl |
| Modify | `packages/web/src/components/LoadingSpinner.tsx` | 旧 token → brand token               |
| Modify | `packages/web/src/pages/Login.tsx`               | 旧 token → brand token 全量替换      |
| Modify | `packages/web/src/pages/Register.tsx`            | 旧 token → brand token 全量替换      |
| Modify | `packages/web/src/pages/Cart.tsx`                | 旧 token → brand token 全量替换      |
| Modify | `packages/web/src/pages/Checkout.tsx`            | 旧 token → brand token 全量替换      |
| Modify | `packages/web/src/pages/OrderList.tsx`           | 旧 token → brand token 全量替换      |
| Modify | `packages/web/src/pages/OrderDetail.tsx`         | 旧 token → brand token 全量替换      |
| Modify | `packages/web/src/pages/AdminProducts.tsx`       | 旧 token → brand token 全量替换      |

---

### Task 1: 补全 Google Fonts 字重 + 添加 @theme 语义变量

**Files:**

- Modify: `packages/web/index.html:10-13`
- Modify: `packages/web/src/styles/index.css:4-43`

- [ ] **Step 1: 修改 index.html 补全字重**

将第 11 行的 Google Fonts URL 从：

```
href="https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600;700&family=Noto+Sans+SC:wght@300;400;500;700&display=swap"
```

改为：

```
href="https://fonts.googleapis.com/css2?family=Fredoka:wght@400;500;600;700;800&family=Noto+Sans+SC:wght@300;400;500;700;900&display=swap"
```

- [ ] **Step 2: 在 index.css @theme 块中新增语义变量**

在 `--color-brand-btn-bg: #f5f1eb;` 之后、`/* 保留旧 token */` 之前，插入：

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

- [ ] **Step 3: 更新旧 token 注释**

将 `/* 保留旧 token 供其他页面用 */` 改为 `/* 旧 token 定义保留（已无内部 .tsx 使用） */`

- [ ] **Step 4: 提交**

```bash
cd packages/web
git add index.html src/styles/index.css
git commit -m "feat(web): 补全 Google Fonts 字重 + 新增 @theme 语义 token（radius/gradient）"
```

---

### Task 2: SVG stroke 硬编码色值改为 currentColor

**Files:**

- Modify: `packages/web/src/components/SearchBar.tsx:34-44`
- Modify: `packages/web/src/components/ProductName.tsx:12-23`

- [ ] **Step 1: 修改 SearchBar.tsx**

将第 34-44 行的 SVG：

```tsx
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#636E72"
          strokeWidth="2"
          strokeLinecap="round"
        >
```

改为：

```tsx
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          className="text-brand-muted"
        >
```

- [ ] **Step 2: 修改 ProductName.tsx**

将第 12-20 行的 SVG：

```tsx
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#00B894"
            strokeWidth="2.5"
            strokeLinecap="round"
          >
```

改为：

```tsx
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            className="text-brand-green"
          >
```

- [ ] **Step 3: 提交**

```bash
cd packages/web
git add src/components/SearchBar.tsx src/components/ProductName.tsx
git commit -m "fix(web): SVG stroke 硬编码色值改为 currentColor + brand token class"
```

---

### Task 3: 硬编码渐变/颜色改用 CSS 变量（组件级）

**Files:**

- Modify: `packages/web/src/components/BuyBar.tsx:64-69`
- Modify: `packages/web/src/components/PromoBanner.tsx:4-8`
- Modify: `packages/web/src/components/Description.tsx:10-15`
- Modify: `packages/web/src/components/ProductHero.tsx:14-18`
- Modify: `packages/web/src/components/SpecSelector.tsx:33-40`
- Modify: `packages/web/src/components/PriceSection.tsx:26-33`

- [ ] **Step 1: 修改 BuyBar.tsx**

将第 64-69 行：

```tsx
      <div
        onClick={handleBuyNow}
        className={`animate-pulse-glow flex-1 py-3 rounded-2xl text-center text-white font-bold text-[15px] cursor-pointer transition-transform duration-150 ${
          isUpdating ? 'opacity-50 pointer-events-none' : ''
        }`}
        style={{ background: 'linear-gradient(135deg, #FF6B35, #FF7675)' }}
      >
```

改为：

```tsx
      <div
        onClick={handleBuyNow}
        className={`animate-pulse-glow flex-1 py-3 rounded-2xl text-center text-white font-bold text-[15px] cursor-pointer transition-transform duration-150 ${
          isUpdating ? 'opacity-50 pointer-events-none' : ''
        }`}
        style={{ background: 'var(--gradient-cta)' }}
      >
```

- [ ] **Step 2: 修改 PromoBanner.tsx**

将第 4-8 行：

```tsx
      <div
        className="relative rounded-3xl overflow-hidden"
        style={{
          background: 'linear-gradient(135deg, #FF6B35 0%, #FF7675 50%, #F7C948 100%)',
        }}
      >
```

改为：

```tsx
      <div
        className="relative rounded-3xl overflow-hidden"
        style={{
          background: 'var(--gradient-promo)',
        }}
      >
```

- [ ] **Step 3: 修改 Description.tsx**

将第 10-15 行：

```tsx
      <div
        className="py-4 px-[18px] rounded-[20px] border-[1.5px]"
        style={{
          background: 'linear-gradient(135deg, #FFEAA744 0%, #F7C94822 100%)',
          borderColor: '#FFEAA766',
        }}
      >
```

改为：

```tsx
      <div
        className="py-4 px-[18px] rounded-[20px] border-[1.5px]"
        style={{
          background: 'var(--gradient-desc)',
          borderColor: 'color-mix(in srgb, var(--color-brand-peach) 40%, transparent)',
        }}
      >
```

- [ ] **Step 4: 修改 ProductHero.tsx**

将第 14-18 行：

```tsx
<div
  className="absolute inset-0"
  style={{
    background: `linear-gradient(135deg, ${color}22 0%, #FFF8F0 100%)`,
  }}
/>
```

改为：

```tsx
<div
  className="absolute inset-0"
  style={{
    background: `linear-gradient(135deg, ${color}22 0%, var(--color-brand-bg) 100%)`,
  }}
/>
```

- [ ] **Step 5: 修改 SpecSelector.tsx**

将第 33-40 行：

```tsx
                <div
                  key={value}
                  onClick={() => handleSelect(spec.name, value)}
                  className="py-2.5 px-[18px] rounded-2xl cursor-pointer transition-all duration-200"
                  style={{
                    border: isActive ? '2.5px solid #FF6B35' : '2px solid #eee',
                    background: isActive ? '#FF6B3510' : '#FFFFFF',
                  }}
                >
```

改为：

```tsx
                <div
                  key={value}
                  onClick={() => handleSelect(spec.name, value)}
                  className="py-2.5 px-[18px] rounded-2xl cursor-pointer transition-all duration-200"
                  style={{
                    border: isActive ? '2.5px solid var(--color-brand-primary)' : '2px solid var(--color-brand-border)',
                    background: isActive ? 'color-mix(in srgb, var(--color-brand-primary) 6%, transparent)' : 'var(--color-brand-card)',
                  }}
                >
```

- [ ] **Step 6: 修改 PriceSection.tsx（含 rounded-full 修正）**

将第 26-33 行：

```tsx
            <span
              key={i}
              className="py-1 px-3 rounded-[20px] text-[11px] font-semibold"
              style={{
                background: i === 0 ? '#FF6B3518' : '#F7C94830',
                color: i === 0 ? '#FF6B35' : '#2D3436',
                border: i === 0 ? '1.5px solid #FF6B3544' : '1.5px solid #F7C94855',
              }}
            >
```

改为：

```tsx
            <span
              key={i}
              className="py-1 px-3 rounded-full text-[11px] font-semibold"
              style={{
                background: i === 0
                  ? 'color-mix(in srgb, var(--color-brand-primary) 9%, transparent)'
                  : 'color-mix(in srgb, var(--color-brand-secondary) 19%, transparent)',
                color: i === 0 ? 'var(--color-brand-primary)' : 'var(--color-brand-dark)',
                border: i === 0
                  ? '1.5px solid color-mix(in srgb, var(--color-brand-primary) 27%, transparent)'
                  : '1.5px solid color-mix(in srgb, var(--color-brand-secondary) 33%, transparent)',
              }}
            >
```

- [ ] **Step 7: 提交**

```bash
cd packages/web
git add src/components/BuyBar.tsx src/components/PromoBanner.tsx src/components/Description.tsx src/components/ProductHero.tsx src/components/SpecSelector.tsx src/components/PriceSection.tsx
git commit -m "fix(web): 组件硬编码渐变/颜色改用 CSS 变量 + PriceSection rounded-full"
```

---

### Task 4: Toast + LoadingSpinner 迁移到 brand token

**Files:**

- Modify: `packages/web/src/components/Toast.tsx:46-60`
- Modify: `packages/web/src/components/LoadingSpinner.tsx:17`

- [ ] **Step 1: 修改 Toast.tsx typeStyles**

将第 46-51 行：

```tsx
const typeStyles: Record<ToastType, string> = {
  success: 'bg-success text-white',
  error: 'bg-danger text-white',
  warning: 'bg-warning text-gray-900',
  info: 'bg-info text-white',
};
```

改为：

```tsx
const typeStyles: Record<ToastType, string> = {
  success: 'bg-brand-green text-white',
  error: 'bg-brand-coral text-white',
  warning: 'bg-brand-secondary text-brand-dark',
  info: 'bg-brand-accent text-white',
};
```

- [ ] **Step 2: 修改 Toast.tsx 圆角**

将第 60 行的 `rounded-lg` 改为 `rounded-2xl`：

```tsx
className={`animate-slide-up rounded-2xl px-4 py-3 shadow-lg text-sm font-medium min-w-[240px] max-w-[360px] flex items-center justify-between ${typeStyles[toast.type]}`}
```

- [ ] **Step 3: 修改 LoadingSpinner.tsx**

将第 17 行：

```tsx
      style={{ color: color || 'var(--color-primary)' }}
```

改为：

```tsx
      style={{ color: color || 'var(--color-brand-primary)' }}
```

- [ ] **Step 4: 提交**

```bash
cd packages/web
git add src/components/Toast.tsx src/components/LoadingSpinner.tsx
git commit -m "fix(web): Toast + LoadingSpinner 迁移到 brand token"
```

---

### Task 5: 旧页面迁移 — Login + Register

**Files:**

- Modify: `packages/web/src/pages/Login.tsx`
- Modify: `packages/web/src/pages/Register.tsx`

- [ ] **Step 1: 修改 Login.tsx**

以下 class 替换（使用 replace_all 逐项替换）：

| 旧值                                         | 新值                                                     |
| -------------------------------------------- | -------------------------------------------------------- |
| `bg-gray-50`                                 | `bg-brand-bg`                                            |
| `text-primary`                               | `text-brand-primary`                                     |
| `bg-primary`                                 | `bg-brand-primary`                                       |
| `focus:ring-primary/30 focus:border-primary` | `focus:ring-brand-primary/30 focus:border-brand-primary` |
| `rounded-xl`                                 | `rounded-2xl`                                            |

注意：`text-primary` 出现在第 41、88 行（标题和链接），`bg-primary` 出现在第 78 行（按钮），`rounded-xl` 出现在第 58、71、78 行（输入框和按钮），`focus:ring-primary/30 focus:border-primary` 出现在第 58、71 行。

完整替换后的 Login.tsx 关键行：

第 38 行：`<div className="min-h-screen bg-brand-bg flex flex-col">`
第 41 行：`<h1 className="text-3xl font-bold text-brand-primary font-display">鲜果集</h1>`
第 58 行：`className="w-full px-4 py-3 rounded-2xl border border-gray-200 focus:outline-none focus:ring-brand-primary/30 focus:border-brand-primary transition"`
第 71 行：`className="w-full px-4 py-3 rounded-2xl border border-gray-200 focus:outline-none focus:ring-brand-primary/30 focus:border-brand-primary transition"`
第 78 行：`className="w-full py-3 bg-brand-primary text-white rounded-2xl font-bold text-base transition hover:opacity-90 disabled:opacity-50"`
第 88 行：`<span className="text-brand-primary font-medium">立即注册</span>`

- [ ] **Step 2: 修改 Register.tsx**

与 Login 相同的替换规则：

| 旧值                                         | 新值                                                     |
| -------------------------------------------- | -------------------------------------------------------- |
| `bg-gray-50`                                 | `bg-brand-bg`                                            |
| `text-primary`                               | `text-brand-primary`                                     |
| `bg-primary`                                 | `bg-brand-primary`                                       |
| `focus:ring-primary/30 focus:border-primary` | `focus:ring-brand-primary/30 focus:border-brand-primary` |
| `rounded-xl`                                 | `rounded-2xl`                                            |

- [ ] **Step 3: 提交**

```bash
cd packages/web
git add src/pages/Login.tsx src/pages/Register.tsx
git commit -m "fix(web): Login + Register 迁移到 brand token"
```

---

### Task 6: 旧页面迁移 — Cart + Checkout

**Files:**

- Modify: `packages/web/src/pages/Cart.tsx`
- Modify: `packages/web/src/pages/Checkout.tsx`

- [ ] **Step 1: 修改 Cart.tsx**

以下 class 替换（使用 replace_all 逐项替换）：

| 旧值                        | 新值                                    |
| --------------------------- | --------------------------------------- |
| `bg-gray-50`                | `bg-brand-bg`                           |
| `bg-primary border-primary` | `bg-brand-primary border-brand-primary` |
| `bg-primary`                | `bg-brand-primary`                      |
| `text-primary`              | `text-brand-primary`                    |
| `hover:text-danger`         | `hover:text-brand-coral`                |

注意替换顺序：先替换长字符串 `bg-primary border-primary`，再替换短的 `bg-primary` 和 `text-primary`，避免部分匹配。

- [ ] **Step 2: 修改 Checkout.tsx**

以下 class 替换：

| 旧值                                         | 新值                                                     |
| -------------------------------------------- | -------------------------------------------------------- |
| `bg-gray-50`                                 | `bg-brand-bg`                                            |
| `focus:ring-primary/30 focus:border-primary` | `focus:ring-brand-primary/30 focus:border-brand-primary` |
| `rounded-xl`                                 | `rounded-2xl`                                            |
| `text-primary`                               | `text-brand-primary`                                     |
| `text-success`                               | `text-brand-green`                                       |
| `bg-primary`                                 | `bg-brand-primary`                                       |

注意：`text-success` 出现在第 166 行（地址标签），其余分布与 Login 类似。

- [ ] **Step 3: 提交**

```bash
cd packages/web
git add src/pages/Cart.tsx src/pages/Checkout.tsx
git commit -m "fix(web): Cart + Checkout 迁移到 brand token"
```

---

### Task 7: 旧页面迁移 — OrderList + OrderDetail + AdminProducts

**Files:**

- Modify: `packages/web/src/pages/OrderList.tsx`
- Modify: `packages/web/src/pages/OrderDetail.tsx`
- Modify: `packages/web/src/pages/AdminProducts.tsx`

- [ ] **Step 1: 修改 OrderList.tsx**

STATUS_COLORS 替换（第 26-30 行附近）：

| 旧值           | 新值                   |
| -------------- | ---------------------- |
| `text-warning` | `text-brand-secondary` |
| `text-info`    | `text-brand-accent`    |
| `text-primary` | `text-brand-primary`   |
| `text-success` | `text-brand-green`     |

其他 class 替换：

| 旧值                                    | 新值                                                |
| --------------------------------------- | --------------------------------------------------- |
| `bg-gray-50`                            | `bg-brand-bg`                                       |
| `bg-primary text-white`                 | `bg-brand-primary text-white`                       |
| `text-primary border border-primary/30` | `text-brand-primary border border-brand-primary/30` |
| `text-primary`                          | `text-brand-primary`                                |

- [ ] **Step 2: 修改 OrderDetail.tsx**

STATUS_BG 替换（第 17-21 行附近）：

| 旧值         | 新值                 |
| ------------ | -------------------- |
| `bg-warning` | `bg-brand-secondary` |
| `bg-info`    | `bg-brand-accent`    |
| `bg-primary` | `bg-brand-primary`   |
| `bg-success` | `bg-brand-green`     |

其他 class 替换：

| 旧值           | 新值                 |
| -------------- | -------------------- |
| `text-primary` | `text-brand-primary` |
| `bg-gray-50`   | `bg-brand-bg`        |
| `bg-danger`    | `bg-brand-coral`     |

- [ ] **Step 3: 修改 AdminProducts.tsx**

按以下顺序替换（先长后短）：

| 旧值                                         | 新值                                                     |
| -------------------------------------------- | -------------------------------------------------------- |
| `hover:bg-danger/10`                         | `hover:bg-brand-coral/10`                                |
| `hover:bg-primary/10`                        | `hover:bg-brand-primary/10`                              |
| `focus:ring-primary/30 focus:border-primary` | `focus:ring-brand-primary/30 focus:border-brand-primary` |
| `text-danger`                                | `text-brand-coral`                                       |
| `bg-danger`                                  | `bg-brand-coral`                                         |
| `text-success`                               | `text-brand-green`                                       |
| `bg-gray-50`                                 | `bg-brand-bg`                                            |
| `bg-primary`                                 | `bg-brand-primary`                                       |
| `text-primary`                               | `text-brand-primary`                                     |
| `rounded-xl`                                 | `rounded-2xl`                                            |
| `rounded-lg`                                 | `rounded-2xl`                                            |

注意：`rounded-lg` 在 AdminProducts 中约 10 处（表单输入框），`rounded-xl` 在第 251 行（表格）。全部改为 `rounded-2xl`。

- [ ] **Step 4: 提交**

```bash
cd packages/web
git add src/pages/OrderList.tsx src/pages/OrderDetail.tsx src/pages/AdminProducts.tsx
git commit -m "fix(web): OrderList + OrderDetail + AdminProducts 迁移到 brand token"
```

---

### Task 8: 验证 + 清理

**Files:**

- Verify: `packages/web/` 全部 `.tsx` 文件

- [ ] **Step 1: 编译验证**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness/demo/fruit-shop
pnpm build
```

Expected: exit code 0，无 TypeScript 错误

- [ ] **Step 2: 旧 token 残留检查**

```bash
grep -r 'bg-primary\b\|text-primary\b\|bg-success\b\|bg-danger\b\|bg-warning\b\|bg-info\b\|text-success\b\|text-danger\b\|text-warning\b\|text-info\b\|hover:text-danger\b\|hover:bg-danger\b\|bg-gray-50\b' packages/web/src/ --include='*.tsx'
```

Expected: 0 结果（旧 token 在 tsx 中无残留）

注意：`\b` 确保只匹配完整 class 名（如 `bg-primary`），不匹配 `bg-brand-primary`

- [ ] **Step 3: 硬编码 hex 残留检查**

```bash
grep -rn '#FF6B35\|#FF7675\|#F7C948\|#FFEAA7\|#2D3436\|#636E72\|#00B894\|#E84393\|#FFF8F0' packages/web/src/components/ --include='*.tsx'
```

Expected: 0 结果（组件中无 DESIGN.md 颜色的硬编码 hex）

排除：`ProductCard.tsx` 中的 `product.color + 'CC'` 动态拼接（不在检查范围）

- [ ] **Step 4: 开发服务器启动验证**

```bash
pnpm dev
```

Expected: 正常启动在 `http://localhost:5177`，无控制台报错

- [ ] **Step 5: 提交验证状态（如有 index.css 注释更新）**

如果 Step 2 和 Step 3 都通过，确认 `index.css` 旧 token 注释已标注「已无内部使用」。

---

## Self-Review Checklist

- [x] Spec coverage: 7 类差异全部覆盖（Task 1-8 对应 spec #1-#7）
- [x] No placeholders: 每步含具体代码/命令
- [x] Type consistency: CSS 变量名与 Task 1 `@theme` 定义一致
- [x] Contract alignment: DoD 12 条全部有对应验证步骤（Task 8）
- [x] Replace order: 长字符串先替换，避免部分匹配
- [x] ProductCard.tsx 未列入修改范围（spec 明确排除）
