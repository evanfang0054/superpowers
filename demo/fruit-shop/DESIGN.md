---
name: '鲜果集 (Fruit Shop)'
description: '暖橙色系的水果电商移动端设计语言，圆润、亲和、食欲感'
colors:
  - name: canvas
    hex: '#FFF8F0'
  - name: primary
    hex: '#FF6B35'
  - name: secondary
    hex: '#F7C948'
  - name: accent
    hex: '#E84393'
  - name: green
    hex: '#00B894'
  - name: dark
    hex: '#2D3436'
  - name: muted
    hex: '#636E72'
  - name: card
    hex: '#FFFFFF'
  - name: peach
    hex: '#FFEAA7'
  - name: coral
    hex: '#FF7675'
  - name: border
    hex: '#F0ECE6'
  - name: btn-bg
    hex: '#F5F1EB'
typography:
  - role: display
    fontFamily: "'Fredoka', 'Noto Sans SC', sans-serif"
    fontSize: '36px'
    fontWeight: 800
    lineHeight: 1.0
    letterSpacing: '0em'
  - role: h1
    fontFamily: "'Noto Sans SC', -apple-system, sans-serif"
    fontSize: '22px'
    fontWeight: 900
    lineHeight: 1.3
    letterSpacing: '0em'
  - role: body
    fontFamily: "'Noto Sans SC', -apple-system, sans-serif"
    fontSize: '14px'
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: '0em'
  - role: caption
    fontFamily: "'Noto Sans SC', -apple-system, sans-serif"
    fontSize: '11px'
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: '0em'
rounded:
  - name: sm
    value: '8px'
  - name: md
    value: '16px'
  - name: lg
    value: '20px'
  - name: xl
    value: '24px'
  - name: 2xl
    value: '32px'
  - name: full
    value: '9999px'
spacing:
  - name: xs
    value: '4px'
  - name: sm
    value: '8px'
  - name: md
    value: '12px'
  - name: lg
    value: '16px'
  - name: xl
    value: '20px'
  - name: 2xl
    value: '24px'
  - name: 3xl
    value: '32px'
components:
  - name: NavBar
    backgroundColor: 'rgba(255,248,240,0.9)'
    textColor: '#2D3436'
    rounded: '0px'
    padding: '12px 16px'
    backdropFilter: 'blur(10px)'
  - name: SearchBar
    backgroundColor: '#FFFFFF'
    textColor: '#636E72'
    rounded: '16px'
    padding: '10px 16px'
    border: '1px solid #F0ECE6'
  - name: FruitCard
    backgroundColor: '#FFFFFF'
    textColor: '#2D3436'
    rounded: '24px'
    padding: '12px'
    border: '1px solid #F0ECE6'
    shadow: 'none'
  - name: CategoryTab
    backgroundColor:
      active: '#FF6B35'
      inactive: '#FFFFFF'
    textColor:
      active: '#FFFFFF'
      inactive: '#2D3436'
    rounded: '16px'
    padding: '8px 16px'
  - name: PrimaryButton
    backgroundColor: 'linear-gradient(135deg, #FF6B35, #FF7675)'
    textColor: '#FFFFFF'
    rounded: '16px'
    padding: '12px 0'
    fontWeight: 700
    fontSize: '15px'
  - name: SecondaryButton
    backgroundColor: '#F7C948'
    textColor: '#2D3436'
    rounded: '16px'
    padding: '12px 0'
    fontWeight: 700
    fontSize: '15px'
  - name: Tag
    backgroundColor: 'rgba(255,107,53,0.09)'
    textColor: '#FF6B35'
    rounded: '9999px'
    padding: '4px 12px'
    fontSize: '11px'
  - name: TabBar
    backgroundColor: 'rgba(255,255,255,0.95)'
    textColor:
      active: '#FF6B35'
      inactive: '#636E72'
    rounded: '0px'
    padding: '8px 12px'
    backdropFilter: 'blur(12px)'
    borderTop: '1px solid #F0ECE6'
  - name: PromoBanner
    backgroundColor: 'linear-gradient(135deg, #FF6B35 0%, #FF7675 50%, #F7C948 100%)'
    textColor: '#FFFFFF'
    rounded: '24px'
    padding: '20px 24px'
  - name: QualityCard
    backgroundColor: '#FFFFFF'
    textColor: '#2D3436'
    rounded: '16px'
    padding: '12px 14px'
    border: '1.5px solid #F0ECE6'
  - name: SpecCard
    backgroundColor:
      selected: 'rgba(255,107,53,0.06)'
      unselected: '#FFFFFF'
    textColor:
      selected: '#FF6B35'
      unselected: '#2D3436'
    rounded: '16px'
    padding: '10px 18px'
    border:
      selected: '2.5px solid #FF6B35'
      unselected: '2px solid #EEEEEE'
  - name: Toast
    backgroundColor: 'rgba(0,0,0,0.75)'
    textColor: '#FFFFFF'
    rounded: '24px'
    padding: '10px 24px'
    fontSize: '14px'
---

# 鲜果集 · Design System

## 1. Visual Theme & Atmosphere

鲜果集是一个以**暖奶油色**（`#FFF8F0`）为画布、**鲜橙色**（`#FF6B35`）为主调的水果电商设计系统。整体气质亲和、圆润、充满食欲感——就像走进一间阳光充足的水果铺。

视觉印象：大面积暖白背景搭配水果色系的点缀色，圆角贯穿所有容器（最小 8px、最大 32px），没有任何尖锐直角。装饰元素使用半透明彩色圆点（peach / secondary / coral / green / accent 的 25%-40% 透明度变体），带来轻松活泼的呼吸感。

情绪关键词：温暖、新鲜、信任、食欲感、自然。

设计语言灵魂：「让每颗水果看起来都值得信赖地好吃」——用暖色和圆润包裹产品，用 price 的 display 字体（Fredoka）制造视觉甜点。

## 2. Color Palette & Roles

| 语义名    | Hex       | 用途                            | 使用比例 |
| --------- | --------- | ------------------------------- | -------- |
| canvas    | `#FFF8F0` | 页面背景、 NavBar 底色          | ~35%     |
| primary   | `#FF6B35` | 价格、CTA、激活态 tab、品牌主色 | ~15%     |
| secondary | `#F7C948` | 「加入购物车」按钮、辅助强调    | ~8%      |
| accent    | `#E84393` | 购物车 badge 数量、极端强调     | ~3%      |
| green     | `#00B894` | 产地标签、成功状态              | ~3%      |
| dark      | `#2D3436` | 标题文字、导航图标              | ~15%     |
| muted     | `#636E72` | 正文、描述、辅助文字            | ~10%     |
| card      | `#FFFFFF` | 卡片背景、搜索框                | ~5%      |
| peach     | `#FFEAA7` | 装饰圆点、描述卡片渐变          | ~3%      |
| coral     | `#FF7675` | 「立即购买」渐变终点、装饰      | ~3%      |
| border    | `#F0ECE6` | 卡片边框、分割线                | ~2%      |
| btn-bg    | `#F5F1EB` | 数量按钮背景                    | ~1%      |

**渐变使用**：

- CTA 按钮：`linear-gradient(135deg, #FF6B35, #FF7675)`
- PromoBanner：`linear-gradient(135deg, #FF6B35 0%, #FF7675 50%, #F7C948 100%)`
- 描述卡片：`linear-gradient(135deg, #FFEAA744, #F7C94822)`

## 3. Typography Rules

**字体栈**：

- **Display**：`'Fredoka', 'Noto Sans SC', sans-serif` — 用于价格数字、数量数字。圆润几何字体，字重 600-800，与水果主题的亲和感匹配
- **Body**：`'Noto Sans SC', -apple-system, sans-serif` — 所有中文正文和 UI 文字。覆盖 400-900 字重

**字号层级**：

| 层级    | 字号 | 字重              | 用途                     |
| ------- | ---- | ----------------- | ------------------------ |
| Display | 36px | 800 (font-black)  | 价格大数字               |
| H1      | 22px | 900 (font-black)  | 商品名称                 |
| H2      | 17px | 700 (font-bold)   | NavBar 标题              |
| H3      | 15px | 700 (font-bold)   | 区块标题、Tab Bar 标签   |
| Body    | 14px | 400               | 正文描述                 |
| Caption | 13px | 500 (font-medium) | 产地信息、规格价格       |
| Micro   | 11px | 500-700           | tag、badge、辅助说明     |
| Badge   | 10px | 700 (font-bold)   | 购物车数量、Tab Bar 标签 |

**特殊规则**：

- 价格符号「¥」独立为 12-14px 的 bold，与大数字视觉分离
- 划线价统一 `text-gray-300 line-through`，不喧宾夺主
- Fredoka 仅用于数字和英文，中文标题用 Noto Sans SC 的 900 字重

## 4. Component Stylings

### NavBar（导航栏）

- 背景：`rgba(255,248,240,0.9)` + `backdrop-blur(10px)`
- 布局：`flex justify-between`，padding `12px 16px`
- 图标色：`#2D3436`，strokeWidth 2-2.5
- 购物车 badge：`#E84393` 圆底 + 白色 10px 粗体数字
- 定位：`sticky top-0 z-50`

### SearchBar（搜索栏）

- 背景：`#FFFFFF`
- 边框：`1px solid #F0ECE6`
- 圆角：16px（`rounded-2xl`）
- 内边距：`10px 16px`
- 占位文字：`#636E72`，14px

### CategoryTab（分类标签）

- **激活态**：背景 `#FF6B35`，文字白色，`shadow-md`
- **默认态**：背景白色，文字 `#2D3436`，边框 `1px solid #F0ECE6`
- 圆角：16px
- 内边距：`8px 16px`
- 过渡：`transition-all duration-200`
- 横向滚动，隐藏滚动条

### FruitCard（水果卡片）

- 背景：`#FFFFFF`
- 边框：`1px solid #F0ECE6`
- 圆角：24px（`rounded-3xl`）
- 图片区高度：160px，`object-cover`
- 标签：左上角绝对定位，背景为 `fruit.color` + `CC` 透明度
- 底部内边距：`12px`
- 交互：hover `scale(1.02)`，active `scale(0.98)`

### PromoBanner（促销横幅）

- 背景：`linear-gradient(135deg, #FF6B35, #FF7675, #F7C948)`
- 圆角：24px（`rounded-3xl`）
- 内边距：`20px 24px`
- CTA 按钮：白色背景 + `rounded-full` + `#FF6B35` 文字
- 装饰：右侧白色 10% 透明度圆形

### PrimaryButton（主操作按钮）

- 背景：`linear-gradient(135deg, #FF6B35, #FF7675)`
- 文字：白色，15px，bold
- 圆角：16px（`rounded-2xl`）
- 内边距：`12px 0`（全宽）
- 动画：`pulseGlow` 脉冲光晕（`0 0 0 0 rgba(255,107,53,0.4)` → `0 0 0 12px transparent`）

### SecondaryButton（次操作按钮）

- 背景：`#F7C948`
- 文字：`#2D3436`，15px，bold
- 圆角：16px
- 内边距：`12px 0`

### BuyBar（底部购买栏）

- 背景：`rgba(255,255,255,0.95)` + `backdrop-blur(12px)`
- 上边框：`1.5px solid #F0ECE6`
- 定位：`fixed bottom-0 z-40`
- 数量按钮：30×30px，`rounded-[10px]`，背景 `#F5F1EB`，active `scale(0.9)`

### TabBar（底部导航栏）

- 背景：`rgba(255,255,255,0.95)` + `backdrop-blur(12px)`
- 上边框：`1px solid #F0ECE6`
- 激活图标：fill + stroke `#FF6B35`
- 默认图标：fill none + stroke `#636E72`
- 底部安全区：`pb-[max(8px,env(safe-area-inset-bottom))]`

### SpecCard（规格选择卡片）

- **选中态**：边框 `2.5px solid #FF6B35`，背景 `rgba(255,107,53,0.06)`
- **默认态**：边框 `2px solid #EEE`，背景白色
- 圆角：16px
- 过渡：`transition all 0.2s`

### QualityCard（品质信息卡片）

- 背景：`#FFFFFF`
- 边框：`1.5px solid #F0ECE6`
- 圆角：16px
- 内边距：`12px 14px`
- 布局：2×2 Grid，gap 10px

### Toast（提示）

- 背景：`rgba(0,0,0,0.75)`
- 文字：白色，14px，semibold
- 圆角：24px
- 定位：绝对定位，顶部 70px，水平居中
- 动画：bounceIn 0.3s

## 5. Layout Principles

**栅格系统**：

- 商品网格：`grid-cols-2`，gap `12px`
- 品质信息：`grid-cols-2`，gap `10px`
- 页面最大宽度无硬限制（移动优先全宽设计）

**页面级布局模式**：

- 全部页面：单列垂直滚动，背景 `#FFF8F0`
- NavBar：sticky top，backdrop-blur 半透明
- BuyBar / TabBar：fixed bottom，backdrop-blur 半透明
- 内容区域：上下 padding `0`，左右 padding `16-20px`

**内容组织**：

- 首页：Header → SearchBar → CategoryTabs → PromoBanner → FruitGrid（2 列瀑布流）→ TabBar
- 详情页：NavBar → ProductHero（圆角底部裁切）→ 商品信息纵向堆叠 → RecommendFruits（横向滚动）→ BuyBar

**关键间距尺度**：

- 区块间距：12-24px（pb-3 至 pb-6）
- 卡片内边距：12-14px（p-3 至 px-5）
- 页面水平边距：16-20px（px-4 至 px-5）

## 6. Depth & Elevation

**阴影层级**：

- **subtle**：无显式阴影——卡片靠边框 `#F0ECE6` 而非阴影区分层级
- **default**：CategoryTab 激活态 `shadow-md`
- **prominent**：ProductHero 图片 `0 8px 32px ${color}33`（颜色随水果变化）

**backdrop-blur 作为层级工具**：

- NavBar：`backdrop-blur(10px)` + 90% 透明度背景
- BuyBar / TabBar：`backdrop-blur(12px)` + 95% 透明度背景
- 效果：滚动内容在导航/操作栏下方微微透出，既保持可读性又不完全遮挡

**z-index 分层**：

- `z-40`：BuyBar / TabBar（底部固定栏）
- `z-50`：NavBar（顶部 sticky）
- `z-[100]`：Toast（最高层提示）

**阴影 vs 边框规则**：

- 静态容器（卡片、搜索框）：用边框 `1-1.5px solid #F0ECE6`
- 交互元素（激活态 tab、hero 图片）：用阴影
- CTA 按钮：用渐变色而非阴影区分层级

## 7. Do's and Don'ts

- ✅ **Do**: 保持所有容器圆角 ≥ 8px——鲜果集是圆润的设计语言，直角会破坏整体气质
- ✅ **Do**: 价格数字使用 Fredoka display 字体——它是品牌签名，给价格「甜点感」
- ✅ **Do**: 用边框而非阴影区分卡片层级——保持画面干净轻盈
- ✅ **Do**: 使用 `backdrop-blur` 让导航栏/操作栏透出底层内容——增加空间层次感
- ✅ **Do**: CTA 按钮加脉冲光晕动画——引导用户注意力到核心操作

- ❌ **Don't**: 不要在暖色画布上使用冷灰阴影——会显得脏，用边框或暖色透明阴影替代
- ❌ **Don't**: 不要让 accent (`#E84393`) 大面积出现——它只用于 badge 和极端强调，多了会抢 primary 的戏
- ❌ **Don't**: 不要在价格区域使用 body 字重的字体——价格是核心决策信息，必须用 Fredoka 粗体
- ❌ **Don't**: 不要给卡片加超过 1.5px 的边框——边框太粗会让轻盈感消失
- ❌ **Don't**: 不要使用纯黑 `#000000` 作为文字色——用 `#2D3436`（dark），纯黑在暖色背景上过于生硬

## 8. Responsive Behavior

**断点定义**：

- 设计以 375px（iPhone SE）为基准宽度，最大适用至 430px（iPhone Pro Max）
- 未定义 tablet / desktop 断点——当前为纯移动端设计

**移动端核心特征**：

- 商品网格固定 2 列，不随屏幕宽度变化
- 推荐商品横向滚动（`overflow-x-auto`，隐藏滚动条）
- NavBar / TabBar 全宽 fixed，不随内容滚动
- 详情页 hero 图片圆角底部裁切（`rounded-b-[32px]`），制造页面间过渡感

**触摸交互**：

- 所有可点击元素有 `cursor: pointer` + hover/active 缩放反馈
- 数量按钮 active `scale(0.9)` 提供即时触觉反馈
- Tab 切换使用 `transition-all duration-200` 避免生硬跳变
- 底部 TabBar 考虑安全区：`pb-[max(8px,env(safe-area-inset-bottom))]`

## 9. Agent Prompt Guide

当基于本 DESIGN.md 生成 UI 时：

1. 优先使用 YAML frontmatter 中的 colors / typography / rounded / spacing token
2. 容器圆角最低 8px，卡片 24px，CTA 按钮 16px——保持圆润一致性
3. 遵循 Component Stylings 中的组件规格，特别是边框粗细（1-1.5px）和 backdrop-blur 值
4. 背景始终为 `#FFF8F0`（canvas），卡片为白色，不要引入新的底色
5. 价格数字必须使用 Fredoka 字体（display role），中文正文使用 Noto Sans SC
6. 触碰新设计决策时，参考 Do's and Don'ts 决定方向
7. 输出前对照 Visual Theme & Atmosphere 检查整体气质——温暖、新鲜、食欲感
