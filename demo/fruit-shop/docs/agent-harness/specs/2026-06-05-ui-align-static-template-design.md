# UI 对齐设计：React 前端 → 静态模板 1:1 还原

## 背景

React 前端 (`packages/web`) 的首页和详情页与静态模板 (`index.html` / `product-detail.html`) 存在显著视觉偏差：主题色板不同、多个组件缺失、动画未生效、整体风格偏灰白而非模板的暖色品牌风格。

目标：将首页和详情页按模板 1:1 还原，同时保留所有已有的 API/store/路由逻辑。

## 设计决策

- **方案选择：页面级重写** — 模板与当前 React 组件结构差异过大（ProductHero、QualityInfo、Description、RecommendFruits 完全不存在），增量修补无法补齐缺失模块。
- **不动其他页面** — Cart、Checkout、OrderList、OrderDetail、Login、Register、AdminProducts 保持现状。
- **双 token 共存** — 新增 `brand-*` 系列 token 对齐模板，保留旧 `primary/success/danger` 等 token 供其他页面使用。

---

## 1. 主题系统

### CSS Token 改动 (`styles/index.css`)

新增 `brand-*` 色板，与模板 `@theme` 一一对应：

| Token                     | 值                                      | 用途                 |
| ------------------------- | --------------------------------------- | -------------------- |
| `--color-brand-bg`        | `#FFF8F0`                               | 页面背景（暖奶油色） |
| `--color-brand-primary`   | `#FF6B35`                               | 主色（橙色）         |
| `--color-brand-secondary` | `#F7C948`                               | 辅色（金黄）         |
| `--color-brand-accent`    | `#E84393`                               | 强调色（粉红）       |
| `--color-brand-green`     | `#00B894`                               | 绿色标签             |
| `--color-brand-dark`      | `#2D3436`                               | 主文字色             |
| `--color-brand-muted`     | `#636E72`                               | 次要文字             |
| `--color-brand-card`      | `#FFFFFF`                               | 卡片背景             |
| `--color-brand-peach`     | `#FFEAA7`                               | 装饰桃色             |
| `--color-brand-coral`     | `#FF7675`                               | 珊瑚色               |
| `--color-brand-border`    | `#f0ece6`                               | 边框色               |
| `--color-brand-btn-bg`    | `#f5f1eb`                               | 按钮背景             |
| `--font-display`          | `'Fredoka', 'Noto Sans SC', sans-serif` | 品牌字体             |

body 背景改为 `#FFF8F0`。

### 动画 (`styles/animations.css`)

保持不变。确保组件使用对应的 CSS class：`animate-bounce-in`、`animate-slide-up`、`animate-pulse-glow`、`animate-spin-slow`、`animate-fade-in`。

---

## 2. 首页组件结构

```
Home.tsx
├── HomeHeader          — 🍊 + "鲜果集"(font-display font-black) + 搜索图标 + 购物车角标
│                         毛玻璃 sticky 导航 (bg-brand-bg/90 backdrop-blur-[10px])
├── SearchBar           — 白底圆角搜索框，边框 brand-border（已有，微调样式）
├── CategoryTabs        — emoji 图标 + 圆角药丸选中态 (bg-brand-primary text-white shadow-md)
│                         未选中: bg-white border-brand-border
├── PromoBanner         — 渐变促销卡片 (135deg, #FF6B35→#FF7675→#F7C948)
│                         "限时特惠 / 新人首单立减¥10 / 满49元可用"
│                         白色圆角按钮 "立即领取 →"
│                         装饰半透明圆
├── FruitGrid           — 2列网格 (grid-cols-2 gap-3)，每个卡片 slide-up 延迟动画
│   └── FruitCard       — rounded-3xl + border-brand-border
│                         ├── 图片区 h-[160px] + 左上角 tag 色标
│                         └── 信息区: 名称+产地 / 价格(¥+大数字+unit)+划线价
├── DecorDots           — 绝对定位装饰圆点（半透明圆 + spin-slow 旋转点）
└── TabBar              — 底部标签栏（已有，加毛玻璃效果）
```

### 删除

- 快捷入口区（4列 emoji 网格）— 模板中没有

### 保留

- API 调用逻辑 (fetchProducts, getCategories)
- 分页加载 (hasMore, handleLoadMore)
- 搜索过滤 (keyword, handleSearch)
- loading/error 空状态

### 数据映射

- CategoryTabs emoji: 从 `category.icon` 字段取
- FruitCard tag: `product.tags[0]` + `product.color` 做色标背景
- 购物车角标: 从 cart store 取 count

---

## 3. 详情页组件结构

```
ProductDetail.tsx
├── DecorDots                  — 与首页共用
├── DetailNavBar               — 返回箭头 + 商品名(sticky top-0 毛玻璃)
│                               + 分享图标 + 购物车图标(角标)
├── ProductHero                — 圆角底大图 (rounded-b-[32px])
│                               渐变背景 (product.color → #FFF8F0)
│                               bounce-in 加载动画
│                               图片指示点 (3个小条)
├── ProductName                — h1 font-black text-[22px] + 产地直发
├── PriceSection               — ¥符号 + font-display text-[36px] 价格 + /unit
│                               + 划线价 + 彩色 tag 行
├── SpecSelector               — 圆角规格卡 (rounded-2xl)
│                               选中: border-[2.5px] solid brand-primary
│                               未选中: border-2 solid #eee
├── QualityInfo        [新建]  — grid-cols-2 2×2 品质网格
│                               甜度/规格/配送/保障 四格
│                               emoji + 标签 + 值
├── Description        [新建]  — "水果故事" 渐变卡片
│                               border-[1.5px] bg-gradient → #FFEAA744→#F7C94822
├── RecommendFruits    [新建]  — "你可能还喜欢" 横滚列表
│                               每项: min-w-[140px] 圆角卡 + 图片 + 名称 + 价格
│                               overflow-x-auto 隐藏滚动条
├── BuyBar                     — 数量 +/− (w-[30px] rounded-[10px] bg-brand-btn-bg)
│                               + 加入购物车 (bg-brand-secondary)
│                               + 立即购买 (渐变 #FF6B35→#FF7675 + pulse-glow)
└── Toast                      — 已有，保留
```

### 数据映射

- RecommendFruits: 调用 `productApi.getList({limit: 5})`，排除当前 `product.id`，取 4 条
- QualityInfo: `sweetness`/`weight` 从 product 取，配送="顺丰冷链"，保障="坏果包赔"
- Description: `product.description`
- ProductHero 颜色: `product.color`

### 保留

- API 调用 (productApi.getDetail)
- specs JSON 解析逻辑
- cart store 集成 (addItem)
- loading/error 状态处理
- 路由导航

---

## 4. 实施顺序

1. `styles/index.css` — 更新 @theme token + body 背景
2. 新建共享组件: `DecorDots.tsx`
3. 新建详情页组件: `QualityInfo.tsx`、`Description.tsx`、`RecommendFruits.tsx`、`ProductHero.tsx`、`PriceSection.tsx`、`ProductName.tsx`、`DetailNavBar.tsx`
4. 重写组件: `HomeHeader` (inline in Home)、`PromoBanner`、`CategoryTabs`、`FruitCard` (重命名自 ProductCard)
5. 重写 `Home.tsx`
6. 重写 `BuyBar`
7. 重写 `ProductDetail.tsx`
8. 微调 `TabBar`
9. 全量验证

## 5. 验证清单 (DoD)

1. 首页与 `index.html` 视觉 1:1
2. 详情页与 `product-detail.html` 视觉 1:1
3. 所有动画可观察: bounce-in、slide-up、pulse-glow、spin-slow
4. API/store/路由无回归: 分类筛选、搜索、分页、加入购物车、立即购买、Toast
5. TypeScript 编译通过，无 runtime error
6. 其他页面样式无破坏
