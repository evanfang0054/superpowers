# UI 对齐静态模板 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 React 前端首页和详情页按静态模板 1:1 视觉还原，保留所有 API/store/路由功能。

**Architecture:** 逐文件替换策略 — 先改全局主题 token，再新建缺失组件，再重写首页和详情页，最后微调 TabBar。每个 task 产出一个可编译、可验证的 commit。

**Tech Stack:** React 18 + TypeScript + Tailwind CSS v4 + Vite + Zustand + react-router-dom v6

**Spec:** `docs/agent-harness/specs/2026-06-05-ui-align-static-template-design.md`

---

## File Map

### Modify

| File                                           | Responsibility                     |
| ---------------------------------------------- | ---------------------------------- |
| `packages/web/src/styles/index.css`            | 全局主题 token + body 背景         |
| `packages/web/src/components/CategoryTabs.tsx` | 圆角药丸 + emoji 图标样式          |
| `packages/web/src/components/PromoBanner.tsx`  | 渐变促销卡片（替换图片轮播）       |
| `packages/web/src/components/ProductCard.tsx`  | 重写为模板风格 FruitCard           |
| `packages/web/src/components/SearchBar.tsx`    | 品牌色边框 + 圆角调整              |
| `packages/web/src/components/TabBar.tsx`       | 毛玻璃效果                         |
| `packages/web/src/components/BuyBar.tsx`       | 数量按钮 + 渐变双按钮 + pulse-glow |
| `packages/web/src/components/SpecSelector.tsx` | 圆角卡样式                         |
| `packages/web/src/pages/Home.tsx`              | 整页按模板重写                     |
| `packages/web/src/pages/ProductDetail.tsx`     | 整页按模板重写                     |

### Create

| File                                              | Responsibility        |
| ------------------------------------------------- | --------------------- |
| `packages/web/src/components/DecorDots.tsx`       | 装饰圆点背景          |
| `packages/web/src/components/ProductHero.tsx`     | 详情页圆角大图 + 渐变 |
| `packages/web/src/components/ProductName.tsx`     | 商品名 + 产地         |
| `packages/web/src/components/PriceSection.tsx`    | 大数字价格 + tag 行   |
| `packages/web/src/components/QualityInfo.tsx`     | 2×2 品质网格          |
| `packages/web/src/components/Description.tsx`     | 水果故事卡片          |
| `packages/web/src/components/RecommendFruits.tsx` | 推荐横滚列表          |

---

### Task 1: 更新全局主题 Token

**Files:**

- Modify: `packages/web/src/styles/index.css`

- [ ] **Step 1: 更新 @theme 和 body 样式**

将 `index.css` 完整替换为以下内容：

```css
@import './animations.css';
@import 'tailwindcss';

@theme {
  /* 品牌色 — 与静态模板 1:1 */
  --color-brand-bg: #fff8f0;
  --color-brand-primary: #ff6b35;
  --color-brand-secondary: #f7c948;
  --color-brand-accent: #e84393;
  --color-brand-green: #00b894;
  --color-brand-dark: #2d3436;
  --color-brand-muted: #636e72;
  --color-brand-card: #ffffff;
  --color-brand-peach: #ffeaa7;
  --color-brand-coral: #ff7675;
  --color-brand-border: #f0ece6;
  --color-brand-btn-bg: #f5f1eb;

  /* 保留旧 token 供其他页面用 */
  --color-primary: #ff6b35;
  --color-primary-light: #ff8c5a;
  --color-primary-dark: #e55a2b;
  --color-accent: #ffd32a;
  --color-success: #26de81;
  --color-danger: #ff6b6b;
  --color-warning: #ffa502;
  --color-info: #45aaf2;

  /* 灰色梯度 */
  --color-gray-50: #fafafa;
  --color-gray-100: #f5f5f5;
  --color-gray-200: #eeeeee;
  --color-gray-300: #e0e0e0;
  --color-gray-400: #bdbdbd;
  --color-gray-500: #9e9e9e;
  --color-gray-600: #757575;
  --color-gray-700: #616161;
  --color-gray-800: #424242;
  --color-gray-900: #212121;

  /* 字体 */
  --font-display: 'Fredoka', 'Noto Sans SC', sans-serif;
  --font-body: 'Noto Sans SC', sans-serif;
}

/* 基础重置 */
*,
*::before,
*::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

html {
  font-family: var(--font-body);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

body {
  min-height: 100vh;
  color: var(--color-brand-dark);
  background-color: var(--color-brand-bg);
}

#root {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* 滚动条美化 */
::-webkit-scrollbar {
  width: 6px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: var(--color-gray-300);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--color-gray-400);
}

/* 隐藏横向滚动条 */
.scrollbar-hide::-webkit-scrollbar {
  display: none;
}
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

/* 工具类 */
.font-display {
  font-family: var(--font-display);
}

.line-clamp-1 {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* 安全区域 */
.safe-bottom {
  padding-bottom: env(safe-area-inset-bottom, 0px);
}

.safe-top {
  padding-top: env(safe-area-inset-top, 0px);
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/styles/index.css
git commit -m "style: 更新全局主题 token 对齐静态模板"
```

---

### Task 2: 新建 DecorDots 组件

**Files:**

- Create: `packages/web/src/components/DecorDots.tsx`

- [ ] **Step 1: 创建 DecorDots.tsx**

```tsx
export function DecorDots() {
  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden">
      <div className="absolute -top-[60px] -right-[40px] w-40 h-40 rounded-full bg-brand-peach/30" />
      <div className="absolute top-[200px] -left-5 w-20 h-20 rounded-full bg-brand-secondary/25" />
      <div className="animate-spin-slow absolute bottom-[300px] -right-[15px] w-[60px] h-[60px]">
        <div className="absolute top-0 left-[25px] w-2.5 h-2.5 rounded-full bg-brand-coral/40" />
        <div className="absolute bottom-0 left-2.5 w-2 h-2 rounded-full bg-brand-green/40" />
        <div className="absolute bottom-[5px] right-[5px] w-1.5 h-1.5 rounded-full bg-brand-accent/40" />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/DecorDots.tsx
git commit -m "feat(web): 新建 DecorDots 装饰圆点组件"
```

---

### Task 3: 新建详情页专用组件 (ProductHero / ProductName / PriceSection / QualityInfo / Description / RecommendFruits)

**Files:**

- Create: `packages/web/src/components/ProductHero.tsx`
- Create: `packages/web/src/components/ProductName.tsx`
- Create: `packages/web/src/components/PriceSection.tsx`
- Create: `packages/web/src/components/QualityInfo.tsx`
- Create: `packages/web/src/components/Description.tsx`
- Create: `packages/web/src/components/RecommendFruits.tsx`

- [ ] **Step 1: 创建 ProductHero.tsx**

```tsx
import { useState } from 'react';

interface ProductHeroProps {
  image: string;
  name: string;
  color: string;
}

export function ProductHero({ image, name, color }: ProductHeroProps) {
  const [loaded, setLoaded] = useState(false);

  return (
    <div className="relative overflow-hidden rounded-b-[32px]">
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(135deg, ${color}22 0%, #FFF8F0 100%)`,
        }}
      />
      <div className={`flex justify-center px-6 pt-5 pb-4 ${loaded ? 'animate-bounce-in' : ''}`}>
        <img
          src={image}
          alt={name}
          onLoad={() => setLoaded(true)}
          className="w-full h-[280px] object-cover rounded-3xl"
          style={{ boxShadow: `0 8px 32px ${color}33` }}
        />
      </div>
      <div className="flex justify-center gap-1.5 pb-3">
        <div className="w-5 h-1 rounded-sm bg-brand-primary" />
        <div className="w-2 h-1 rounded-sm bg-gray-300" />
        <div className="w-2 h-1 rounded-sm bg-gray-300" />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 创建 ProductName.tsx**

```tsx
interface ProductNameProps {
  name: string;
  origin?: string;
}

export function ProductName({ name, origin }: ProductNameProps) {
  return (
    <div className="px-5 pt-2 pb-1">
      <h1 className="text-[22px] font-black text-brand-dark leading-tight m-0">{name}</h1>
      {origin && (
        <div className="flex items-center gap-1 mt-1.5">
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#00B894"
            strokeWidth="2.5"
            strokeLinecap="round"
          >
            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" />
            <circle cx="12" cy="10" r="3" />
          </svg>
          <span className="text-[13px] text-brand-muted font-medium">产地直发 · {origin}</span>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 3: 创建 PriceSection.tsx**

```tsx
interface PriceSectionProps {
  price: number;
  originalPrice?: number;
  unit?: string;
  tags?: string[];
}

export function PriceSection({ price, originalPrice, unit, tags }: PriceSectionProps) {
  return (
    <div className="px-5 pb-4">
      <div className="flex items-baseline gap-2">
        <span className="text-sm font-bold text-brand-primary">¥</span>
        <span className="text-[36px] font-black text-brand-primary font-display leading-none">
          {price}
        </span>
        {unit && <span className="text-[13px] text-brand-muted">/ {unit}</span>}
        {originalPrice && originalPrice > price && (
          <span className="text-[13px] text-gray-300 line-through ml-1">¥{originalPrice}</span>
        )}
      </div>
      {tags && tags.length > 0 && (
        <div className="flex gap-2 mt-2.5 flex-wrap">
          {tags.map((tag, i) => (
            <span
              key={i}
              className="py-1 px-3 rounded-[20px] text-[11px] font-semibold"
              style={{
                background: i === 0 ? '#FF6B3518' : '#F7C94830',
                color: i === 0 ? '#FF6B35' : '#2D3436',
                border: i === 0 ? '1.5px solid #FF6B3544' : '1.5px solid #F7C94855',
              }}
            >
              {tag}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: 创建 QualityInfo.tsx**

```tsx
interface QualityInfoProps {
  sweetness?: string;
  weight?: string;
}

export function QualityInfo({ sweetness, weight }: QualityInfoProps) {
  const items = [
    { icon: '🍬', label: '甜度', value: sweetness || '暂无' },
    { icon: '⚖️', label: '规格', value: weight || '暂无' },
    { icon: '🚚', label: '配送', value: '顺丰冷链' },
    { icon: '🛡️', label: '保障', value: '坏果包赔' },
  ];

  return (
    <div className="px-5 pb-4">
      <div className="grid grid-cols-2 gap-2.5">
        {items.map((item, i) => (
          <div
            key={i}
            className="py-3 px-3.5 rounded-2xl bg-brand-card border-[1.5px] border-brand-border flex items-center gap-2.5"
          >
            <span className="text-xl">{item.icon}</span>
            <div>
              <div className="text-[11px] text-brand-muted font-medium">{item.label}</div>
              <div className="text-[13px] font-bold text-brand-dark mt-px">{item.value}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 5: 创建 Description.tsx**

```tsx
interface DescriptionProps {
  text?: string;
}

export function Description({ text }: DescriptionProps) {
  if (!text) return null;

  return (
    <div className="px-5 pb-4">
      <div
        className="py-4 px-[18px] rounded-[20px] border-[1.5px]"
        style={{
          background: 'linear-gradient(135deg, #FFEAA744 0%, #F7C94822 100%)',
          borderColor: '#FFEAA766',
        }}
      >
        <div className="text-sm font-bold text-brand-dark mb-1.5">「水果故事」</div>
        <p className="text-[13.5px] text-brand-muted leading-relaxed m-0">{text}</p>
      </div>
    </div>
  );
}
```

- [ ] **Step 6: 创建 RecommendFruits.tsx**

```tsx
import type { Product } from 'shared';

interface RecommendFruitsProps {
  items: Product[];
  onClick: (id: number) => void;
}

export function RecommendFruits({ items, onClick }: RecommendFruitsProps) {
  if (items.length === 0) return null;

  return (
    <div className="px-5 pb-6">
      <div className="text-[15px] font-bold text-brand-dark mb-3">你可能还喜欢</div>
      <div className="flex gap-3 overflow-x-auto scrollbar-hide pb-1">
        {items.map((fruit) => (
          <div
            key={fruit.id}
            onClick={() => onClick(fruit.id)}
            className="min-w-[140px] rounded-[20px] bg-brand-card border-[1.5px] border-brand-border overflow-hidden cursor-pointer shrink-0 hover:scale-[1.02] transition-transform"
          >
            <img
              src={fruit.image || '/placeholder-fruit.png'}
              alt={fruit.name}
              className="w-full h-[100px] object-cover"
            />
            <div className="py-2.5 px-3">
              <div className="text-[13px] font-bold text-brand-dark">{fruit.name}</div>
              <div className="flex items-baseline gap-1 mt-1">
                <span className="text-[11px] text-brand-primary font-bold">¥</span>
                <span className="text-lg font-extrabold text-brand-primary font-display">
                  {fruit.price}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 7: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 8: Commit**

```bash
git add packages/web/src/components/ProductHero.tsx packages/web/src/components/ProductName.tsx packages/web/src/components/PriceSection.tsx packages/web/src/components/QualityInfo.tsx packages/web/src/components/Description.tsx packages/web/src/components/RecommendFruits.tsx
git commit -m "feat(web): 新建详情页专用组件 (Hero/Name/Price/Quality/Desc/Recommend)"
```

---

### Task 4: 重写 CategoryTabs

**Files:**

- Modify: `packages/web/src/components/CategoryTabs.tsx`

- [ ] **Step 1: 重写 CategoryTabs.tsx**

完整替换为：

```tsx
import type { Category } from 'shared';

interface CategoryTabsProps {
  categories: Category[];
  activeId?: number;
  onChange: (categoryId?: number) => void;
}

export function CategoryTabs({ categories, activeId, onChange }: CategoryTabsProps) {
  const allTab = { id: undefined, name: '全部', icon: '🍽️' };

  const tabs = [
    allTab,
    ...categories.map((cat) => ({ id: cat.id, name: cat.name, icon: cat.icon || '🏷️' })),
  ];

  return (
    <div className="flex gap-2 overflow-x-auto scrollbar-hide">
      {tabs.map((tab) => {
        const isActive = activeId === tab.id;
        return (
          <div
            key={tab.id ?? 'all'}
            onClick={() => onChange(tab.id)}
            className={`shrink-0 px-4 py-2 rounded-2xl text-sm font-semibold cursor-pointer transition-all duration-200 ${
              isActive
                ? 'bg-brand-primary text-white shadow-md'
                : 'bg-white text-brand-dark border border-brand-border'
            }`}
          >
            <span className="mr-1">{tab.icon}</span>
            {tab.name}
          </div>
        );
      })}
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/CategoryTabs.tsx
git commit -m "style(web): 重写 CategoryTabs 对齐模板药丸样式"
```

---

### Task 5: 重写 PromoBanner

**Files:**

- Modify: `packages/web/src/components/PromoBanner.tsx`

- [ ] **Step 1: 重写 PromoBanner.tsx 为渐变促销卡片**

完整替换为：

```tsx
export function PromoBanner() {
  return (
    <div className="px-4 py-3">
      <div
        className="relative rounded-3xl overflow-hidden"
        style={{
          background: 'linear-gradient(135deg, #FF6B35 0%, #FF7675 50%, #F7C948 100%)',
        }}
      >
        <div className="px-6 py-5 relative z-10">
          <div className="text-white/80 text-xs font-semibold tracking-wider mb-1">限时特惠</div>
          <div className="text-white text-xl font-black leading-tight">新人首单立减 ¥10</div>
          <div className="text-white/70 text-xs mt-1">满 49 元可用 · 今日有效</div>
          <div className="mt-3 inline-block px-4 py-1.5 bg-white rounded-full text-brand-primary text-xs font-bold cursor-pointer">
            立即领取 →
          </div>
        </div>
        {/* 装饰圆 */}
        <div className="absolute -right-4 -top-4 w-24 h-24 rounded-full bg-white/10" />
        <div className="absolute right-8 -bottom-6 w-20 h-20 rounded-full bg-white/10" />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/PromoBanner.tsx
git commit -m "style(web): 重写 PromoBanner 为渐变促销卡片"
```

---

### Task 6: 重写 SearchBar

**Files:**

- Modify: `packages/web/src/components/SearchBar.tsx`

- [ ] **Step 1: 重写 SearchBar.tsx 品牌色样式**

完整替换为：

```tsx
import { useState, useEffect, useRef } from 'react';

interface SearchBarProps {
  onSearch: (keyword: string) => void;
  placeholder?: string;
  initialValue?: string;
}

export function SearchBar({
  onSearch,
  placeholder = '搜索水果、产地...',
  initialValue = '',
}: SearchBarProps) {
  const [value, setValue] = useState(initialValue);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

  const handleChange = (text: string) => {
    setValue(text);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      onSearch(text);
    }, 400);
  };

  return (
    <div className="px-4 py-2">
      <div className="flex items-center gap-2 bg-white rounded-2xl px-4 py-2.5 border border-brand-border">
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="#636E72"
          strokeWidth="2"
          strokeLinecap="round"
        >
          <circle cx="11" cy="11" r="8" />
          <line x1="21" y1="21" x2="16.65" y2="16.65" />
        </svg>
        <input
          type="text"
          value={value}
          onChange={(e) => handleChange(e.target.value)}
          placeholder={placeholder}
          className="flex-1 bg-transparent text-sm text-brand-dark placeholder-brand-muted outline-none"
        />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/SearchBar.tsx
git commit -m "style(web): 重写 SearchBar 对齐模板品牌色样式"
```

---

### Task 7: 重写 ProductCard (FruitCard)

**Files:**

- Modify: `packages/web/src/components/ProductCard.tsx`

- [ ] **Step 1: 重写 ProductCard.tsx 为模板风格**

完整替换为：

```tsx
import { useNavigate } from 'react-router-dom';
import type { Product } from 'shared';

interface ProductCardProps {
  product: Product;
}

export function ProductCard({ product }: ProductCardProps) {
  const navigate = useNavigate();

  const tags = product.tags || [];

  return (
    <div
      onClick={() => navigate(`/product/${product.id}`)}
      className="bg-brand-card rounded-3xl border border-brand-border overflow-hidden cursor-pointer transition-transform duration-200 hover:scale-[1.02] active:scale-[0.98]"
    >
      <div className="relative">
        <img
          src={product.image || '/placeholder-fruit.png'}
          alt={product.name}
          className="w-full h-[160px] object-cover"
        />
        {tags[0] && (
          <div
            className="absolute top-2.5 left-2.5 px-2.5 py-1 rounded-full text-[10px] font-bold text-white"
            style={{ background: (product.color || '#FF6B35') + 'CC' }}
          >
            {tags[0]}
          </div>
        )}
      </div>
      <div className="p-3">
        <div className="flex items-center justify-between">
          <h3 className="text-[15px] font-bold text-brand-dark">{product.name}</h3>
          {product.origin && <span className="text-[11px] text-brand-muted">{product.origin}</span>}
        </div>
        <div className="flex items-baseline justify-between mt-2">
          <div className="flex items-baseline gap-1">
            <span className="text-xs text-brand-primary font-bold">¥</span>
            <span className="text-xl font-extrabold text-brand-primary font-display leading-none">
              {product.price}
            </span>
            {product.unit && (
              <span className="text-[11px] text-brand-muted ml-0.5">/{product.unit}</span>
            )}
          </div>
          {product.originalPrice && product.originalPrice > product.price && (
            <span className="text-[11px] text-gray-300 line-through">¥{product.originalPrice}</span>
          )}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/ProductCard.tsx
git commit -m "style(web): 重写 ProductCard 对齐模板品牌风格"
```

---

### Task 8: 重写 BuyBar

**Files:**

- Modify: `packages/web/src/components/BuyBar.tsx`

- [ ] **Step 1: 重写 BuyBar.tsx — 数量按钮 + 渐变双按钮 + pulse-glow**

完整替换为：

```tsx
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import type { Product } from 'shared';
import { useCartStore } from '@/store/cart.store';
import { useToast } from './Toast';

interface BuyBarProps {
  product: Product;
}

export function BuyBar({ product }: BuyBarProps) {
  const navigate = useNavigate();
  const addItem = useCartStore((s) => s.addItem);
  const isUpdating = useCartStore((s) => s.isUpdating);
  const { showToast } = useToast();
  const [qty, setQty] = useState(1);

  const handleAddToCart = async () => {
    try {
      await addItem({ productId: product.id, specLabel: '默认', quantity: qty });
      showToast(`已加入购物车 ×${qty}`, 'success');
    } catch {
      showToast('添加失败，请重试', 'error');
    }
  };

  const handleBuyNow = async () => {
    try {
      await addItem({ productId: product.id, specLabel: '默认', quantity: qty });
      navigate('/cart');
    } catch {
      showToast('操作失败，请重试', 'error');
    }
  };

  return (
    <div className="fixed bottom-0 inset-x-0 flex items-center gap-3 px-4 py-3 bg-white/95 backdrop-blur-[12px] border-t-[1.5px] border-brand-border z-40">
      {/* 数量 */}
      <div className="flex items-center gap-2">
        <div
          onClick={() => setQty(Math.max(1, qty - 1))}
          className="w-[30px] h-[30px] rounded-[10px] flex items-center justify-center bg-brand-btn-bg cursor-pointer text-base font-bold text-brand-dark transition-transform duration-150 active:scale-90"
        >
          −
        </div>
        <span className="text-base font-extrabold min-w-6 text-center font-display">{qty}</span>
        <div
          onClick={() => setQty(qty + 1)}
          className="w-[30px] h-[30px] rounded-[10px] flex items-center justify-center bg-brand-btn-bg cursor-pointer text-base font-bold text-brand-dark transition-transform duration-150 active:scale-90"
        >
          +
        </div>
      </div>
      {/* 加购 */}
      <div
        onClick={handleAddToCart}
        className={`flex-1 py-3 rounded-2xl text-center bg-brand-secondary text-brand-dark font-bold text-[15px] cursor-pointer transition-transform duration-150 ${
          isUpdating ? 'opacity-50 pointer-events-none' : ''
        }`}
      >
        加入购物车
      </div>
      {/* 立即购买 */}
      <div
        onClick={handleBuyNow}
        className={`animate-pulse-glow flex-1 py-3 rounded-2xl text-center text-white font-bold text-[15px] cursor-pointer transition-transform duration-150 ${
          isUpdating ? 'opacity-50 pointer-events-none' : ''
        }`}
        style={{ background: 'linear-gradient(135deg, #FF6B35, #FF7675)' }}
      >
        立即购买
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/BuyBar.tsx
git commit -m "style(web): 重写 BuyBar 对齐模板 — 数量按钮 + 渐变双按钮 + pulse-glow"
```

---

### Task 9: 重写 SpecSelector

**Files:**

- Modify: `packages/web/src/components/SpecSelector.tsx`

- [ ] **Step 1: 重写 SpecSelector.tsx 圆角卡样式**

完整替换为：

```tsx
import { useState } from 'react';

interface Spec {
  name: string;
  values: string[];
}

interface SpecSelectorProps {
  specs: Spec[];
  onChange: (selected: Record<string, string>) => void;
}

export function SpecSelector({ specs, onChange }: SpecSelectorProps) {
  const [selected, setSelected] = useState<Record<string, string>>({});

  const handleSelect = (specName: string, value: string) => {
    const next = { ...selected, [specName]: value };
    setSelected(next);
    onChange(next);
  };

  if (specs.length === 0) return null;

  return (
    <div className="px-5 pb-4 space-y-4">
      {specs.map((spec) => (
        <div key={spec.name}>
          <div className="text-sm font-bold text-brand-dark mb-2.5">{spec.name}</div>
          <div className="flex gap-2.5 flex-wrap">
            {spec.values.map((value) => {
              const isActive = selected[spec.name] === value;
              return (
                <div
                  key={value}
                  onClick={() => handleSelect(spec.name, value)}
                  className="py-2.5 px-[18px] rounded-2xl cursor-pointer transition-all duration-200"
                  style={{
                    border: isActive ? '2.5px solid #FF6B35' : '2px solid #eee',
                    background: isActive ? '#FF6B3510' : '#FFFFFF',
                  }}
                >
                  <div
                    className={`text-sm font-semibold ${
                      isActive ? 'text-brand-primary' : 'text-brand-dark'
                    }`}
                  >
                    {value}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/SpecSelector.tsx
git commit -m "style(web): 重写 SpecSelector 对齐模板圆角卡样式"
```

---

### Task 10: 重写首页 Home.tsx

**Files:**

- Modify: `packages/web/src/pages/Home.tsx`

- [ ] **Step 1: 重写 Home.tsx 按模板结构**

完整替换为：

```tsx
import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { productApi, type ProductQuery } from '@/api/product';
import type { Product, Category } from 'shared';
import { ProductCard } from '@/components/ProductCard';
import { CategoryTabs } from '@/components/CategoryTabs';
import { SearchBar } from '@/components/SearchBar';
import { PromoBanner } from '@/components/PromoBanner';
import { DecorDots } from '@/components/DecorDots';
import { TabBar } from '@/components/TabBar';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { useCartStore } from '@/store/cart.store';

export default function Home() {
  const navigate = useNavigate();
  const cartCount = useCartStore((s) => s.totalCount());

  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [keyword, setKeyword] = useState('');
  const [activeCategory, setActiveCategory] = useState<number | undefined>();
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  const fetchProducts = useCallback(async (p: number, kw?: string, catId?: number) => {
    setIsLoading(true);
    try {
      const params: ProductQuery = { page: p, limit: 12 };
      if (kw) params.keyword = kw;
      if (catId) params.categoryId = catId;

      const response = await productApi.getList(params);
      const items = response.data.data?.list || [];

      setProducts((prev) => (p === 1 ? items : [...prev, ...items]));
      setHasMore(items.length >= 12);
    } catch {
      // 静默
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    productApi
      .getCategories()
      .then((res) => {
        setCategories(res.data.data || []);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    setPage(1);
    fetchProducts(1, keyword, activeCategory);
  }, [keyword, activeCategory, fetchProducts]);

  const handleSearch = (kw: string) => {
    setKeyword(kw);
  };

  const handleCategoryChange = (catId?: number) => {
    setActiveCategory(catId);
  };

  const handleLoadMore = () => {
    const nextPage = page + 1;
    setPage(nextPage);
    fetchProducts(nextPage, keyword, activeCategory);
  };

  return (
    <div className="relative bg-brand-bg min-h-screen pb-20">
      <DecorDots />

      {/* 顶部导航 */}
      <div className="flex items-center justify-between px-4 py-3 bg-brand-bg/90 backdrop-blur-[10px] sticky top-0 z-50">
        <div className="flex items-center gap-2">
          <span className="text-2xl">🍊</span>
          <span className="font-black text-xl text-brand-dark font-display">鲜果集</span>
        </div>
        <div className="flex items-center gap-3">
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#2D3436"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <div className="relative cursor-pointer" onClick={() => navigate('/cart')}>
            <svg
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#2D3436"
              strokeWidth="2"
              strokeLinecap="round"
            >
              <circle cx="9" cy="21" r="1" />
              <circle cx="20" cy="21" r="1" />
              <path d="M1 1h4l2.68 13.39a2 2 0 002 1.61h9.72a2 2 0 002-1.61L23 6H6" />
            </svg>
            {cartCount > 0 && (
              <div className="absolute -top-1 -right-1.5 w-4 h-4 rounded-full bg-brand-accent text-white text-[10px] font-bold flex items-center justify-center">
                {cartCount > 99 ? '99+' : cartCount}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* 搜索栏 */}
      <SearchBar onSearch={handleSearch} />

      {/* 分类标签 */}
      <div className="px-4 py-2">
        <CategoryTabs
          categories={categories}
          activeId={activeCategory}
          onChange={handleCategoryChange}
        />
      </div>

      {/* 促销 Banner */}
      <PromoBanner />

      {/* 商品列表 */}
      <div className="px-4 pb-6">
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-display text-lg font-semibold text-brand-dark">
            {activeCategory
              ? categories.find((c) => c.id === activeCategory)?.name || '精选好果'
              : '精选好果'}
          </h2>
        </div>

        {isLoading && page === 1 ? (
          <div className="flex justify-center py-20">
            <LoadingSpinner size="lg" />
          </div>
        ) : products.length === 0 ? (
          <div className="text-center py-20">
            <p className="text-brand-muted text-sm">
              {keyword ? `未找到"${keyword}"相关水果` : '暂无商品'}
            </p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-3">
              {products.map((product, i) => (
                <div
                  key={product.id}
                  className="animate-slide-up"
                  style={{ animationDelay: `${i * 60}ms`, animationFillMode: 'both' }}
                >
                  <ProductCard product={product} />
                </div>
              ))}
            </div>

            {hasMore && (
              <div className="flex justify-center mt-6">
                <button
                  onClick={handleLoadMore}
                  disabled={isLoading}
                  className="px-6 py-2 text-sm text-brand-primary border border-brand-primary/30 rounded-full hover:bg-brand-primary/5 disabled:opacity-50 transition-colors"
                >
                  {isLoading ? '加载中...' : '查看更多'}
                </button>
              </div>
            )}
          </>
        )}
      </div>

      <TabBar />
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/pages/Home.tsx
git commit -m "style(web): 重写首页对齐静态模板"
```

---

### Task 11: 重写详情页 ProductDetail.tsx

**Files:**

- Modify: `packages/web/src/pages/ProductDetail.tsx`

- [ ] **Step 1: 重写 ProductDetail.tsx 按模板结构**

完整替换为：

```tsx
import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { productApi } from '@/api/product';
import type { Product } from 'shared';
import { ProductHero } from '@/components/ProductHero';
import { ProductName } from '@/components/ProductName';
import { PriceSection } from '@/components/PriceSection';
import { SpecSelector } from '@/components/SpecSelector';
import { QualityInfo } from '@/components/QualityInfo';
import { Description } from '@/components/Description';
import { RecommendFruits } from '@/components/RecommendFruits';
import { DecorDots } from '@/components/DecorDots';
import { BuyBar } from '@/components/BuyBar';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { useToast } from '@/components/Toast';

export default function ProductDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { showToast } = useToast();

  const [product, setProduct] = useState<Product | null>(null);
  const [recommendations, setRecommendations] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!id) return;

    const fetchProduct = async () => {
      setIsLoading(true);
      try {
        const { data } = await productApi.getDetail(Number(id));
        setProduct(data.data!);
      } catch {
        showToast('商品不存在或已下架', 'error');
        navigate('/', { replace: true });
      } finally {
        setIsLoading(false);
      }
    };

    fetchProduct();
  }, [id, navigate, showToast]);

  useEffect(() => {
    productApi
      .getRecommendations(5)
      .then((res) => {
        const items = res.data.data || [];
        setRecommendations(items.filter((p: Product) => p.id !== Number(id)).slice(0, 4));
      })
      .catch(() => {});
  }, [id]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-brand-bg">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (!product) return null;

  // 解析规格
  const specs: Array<{ name: string; values: string[] }> = [];
  if ((product as Product & { specs?: string }).specs) {
    try {
      const parsed = JSON.parse((product as Product & { specs?: string }).specs || '[]');
      if (Array.isArray(parsed)) {
        parsed.forEach((s: { name: string; values: string[] }) => {
          if (s.name && Array.isArray(s.values)) {
            specs.push(s);
          }
        });
      }
    } catch {
      // 忽略
    }
  }

  const handleRecommendClick = (productId: number) => {
    navigate(`/product/${productId}`);
    window.scrollTo(0, 0);
  };

  return (
    <div className="relative bg-brand-bg min-h-screen animate-fade-in">
      <DecorDots />

      {/* 导航栏 */}
      <div className="flex items-center justify-between px-4 py-3 bg-brand-bg/90 backdrop-blur-[10px] sticky top-0 z-50">
        <div onClick={() => navigate(-1)} className="cursor-pointer flex items-center gap-1">
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#2D3436"
            strokeWidth="2.5"
            strokeLinecap="round"
          >
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </div>
        <span className="font-bold text-[17px] text-brand-dark">{product.name}</span>
        <div className="flex gap-3">
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#2D3436"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8" />
            <polyline points="16,6 12,2 8,6" />
            <line x1="12" y1="2" x2="12" y2="15" />
          </svg>
          <div className="relative cursor-pointer" onClick={() => navigate('/cart')}>
            <svg
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#2D3436"
              strokeWidth="2"
              strokeLinecap="round"
            >
              <circle cx="9" cy="21" r="1" />
              <circle cx="20" cy="21" r="1" />
              <path d="M1 1h4l2.68 13.39a2 2 0 002 1.61h9.72a2 2 0 002-1.61L23 6H6" />
            </svg>
          </div>
        </div>
      </div>

      {/* 商品大图 */}
      <ProductHero
        image={product.image || '/placeholder-fruit.png'}
        name={product.name}
        color={product.color || '#FF6B35'}
      />

      {/* 商品名称 + 产地 */}
      <ProductName name={product.name} origin={product.origin} />

      {/* 价格 + tag */}
      <PriceSection
        price={product.price}
        originalPrice={product.originalPrice}
        unit={product.unit}
        tags={product.tags}
      />

      {/* 规格选择 */}
      {specs.length > 0 && (
        <div className="px-5 pb-4">
          <div className="text-sm font-bold text-brand-dark mb-2.5">选择规格</div>
          <SpecSelector specs={specs} onChange={() => {}} />
        </div>
      )}

      {/* 品质信息 2×2 */}
      <QualityInfo sweetness={product.sweetness} weight={product.weight} />

      {/* 水果故事 */}
      <Description text={product.description} />

      {/* 推荐水果 */}
      <RecommendFruits items={recommendations} onClick={handleRecommendClick} />

      {/* 底部占位 */}
      <div className="h-[70px]" />

      {/* 底部购买栏 */}
      <BuyBar product={product} />
    </div>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/pages/ProductDetail.tsx
git commit -m "style(web): 重写详情页对齐静态模板"
```

---

### Task 12: 微调 TabBar

**Files:**

- Modify: `packages/web/src/components/TabBar.tsx`

- [ ] **Step 1: 更新 TabBar 样式 — 毛玻璃 + 品牌色**

将 TabBar.tsx 的 `<nav>` 标签样式替换为毛玻璃效果，将颜色从 `text-primary`/`text-gray-400` 改为品牌色。

找到 `<nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-100 safe-bottom z-50">` 替换为：

```tsx
<nav className="fixed bottom-0 left-0 right-0 flex items-center justify-around py-2 pb-[max(8px,env(safe-area-inset-bottom))] bg-white/95 backdrop-blur-[12px] border-t border-brand-border z-40">
```

同时将 `isActive ? 'text-primary' : 'text-gray-400'` 替换为 `isActive ? 'text-brand-primary' : 'text-brand-muted'`。

完整替换 TabBar.tsx：

```tsx
import { useLocation, useNavigate } from 'react-router-dom';

const tabs = [
  {
    path: '/',
    label: '首页',
    icon: (
      <svg
        width="22"
        height="22"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      >
        <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
        <polyline points="9,22 9,12 15,12 15,22" />
      </svg>
    ),
  },
  {
    path: '/cart',
    label: '购物车',
    icon: (
      <svg
        width="22"
        height="22"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      >
        <circle cx="9" cy="21" r="1" />
        <circle cx="20" cy="21" r="1" />
        <path d="M1 1h4l2.68 13.39a2 2 0 002 1.61h9.72a2 2 0 002-1.61L23 6H6" />
      </svg>
    ),
  },
  {
    path: '/orders',
    label: '订单',
    icon: (
      <svg
        width="22"
        height="22"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      >
        <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
        <polyline points="14,2 14,8 20,8" />
        <line x1="16" y1="13" x2="8" y2="13" />
        <line x1="16" y1="17" x2="8" y2="17" />
      </svg>
    ),
  },
];

export function TabBar() {
  const location = useLocation();
  const navigate = useNavigate();

  return (
    <nav className="fixed bottom-0 left-0 right-0 flex items-center justify-around py-2 pb-[max(8px,env(safe-area-inset-bottom))] bg-white/95 backdrop-blur-[12px] border-t border-brand-border z-40">
      {tabs.map((tab) => {
        const isActive =
          tab.path === '/' ? location.pathname === '/' : location.pathname.startsWith(tab.path);

        return (
          <div
            key={tab.path}
            onClick={() => navigate(tab.path)}
            className={`flex flex-col items-center gap-0.5 cursor-pointer px-3 py-1 ${
              isActive ? 'text-brand-primary' : 'text-brand-muted'
            }`}
          >
            {tab.icon}
            <span
              className={`text-[10px] font-semibold ${
                isActive ? 'text-brand-primary' : 'text-brand-muted'
              }`}
            >
              {tab.label}
            </span>
          </div>
        );
      })}
    </nav>
  );
}
```

- [ ] **Step 2: 验证编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add packages/web/src/components/TabBar.tsx
git commit -m "style(web): 微调 TabBar 毛玻璃效果 + 品牌色"
```

---

### Task 13: 全量验证

- [ ] **Step 1: TypeScript 编译**

Run: `cd packages/web && npx tsc --noEmit`
Expected: 无错误

- [ ] **Step 2: Vite 构建**

Run: `cd packages/web && npx vite build`
Expected: 构建成功

- [ ] **Step 3: 启动 dev server 视觉验证**

Run: `cd packages/web && npx vite dev`

在浏览器中验证：

1. 首页 (`/`) — 暖奶油色背景、装饰圆点、Header 橘子logo、搜索框、分类药丸、促销渐变卡、商品卡 slide-up 动画
2. 详情页 (`/product/1`) — 圆角大图 bounce-in、商品名+产地、大数字价格+彩色tag、品质2×2网格、水果故事卡片、推荐横滚、底部数量+双按钮
3. 点击分类/搜索/分页/加入购物车 功能无回归
4. 其他页面 (Cart/Orders/Login) 样式无破坏
