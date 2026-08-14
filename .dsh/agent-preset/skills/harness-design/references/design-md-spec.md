# DESIGN.md 规范与生成指南

> 本文件是 harness-design skill 生成 DESIGN.md 的权威模板。
> DESIGN.md 是一种纯文本设计系统文档，遵循 Google Stitch 提出的规范，
> 对齐 awesome-design-md 仓库（https://github.com/VoltAgent/awesome-design-md）的社区标准。
>
> 它可以被其他 AI agent 读取，用来生成与本项目视觉风格一致的 UI。
> 与 AGENTS.md（告诉 AI 怎么构建）互补，DESIGN.md 告诉 AI 项目应该看起来和感觉怎样。

## 标准结构

每个 DESIGN.md 必须包含两个部分：

1. **YAML frontmatter**（结构化 token，机器可读）
2. **9 个 markdown section**（人类可读的设计决策描述）

---

## YAML Frontmatter 标准

```yaml
---
name: <项目/品牌名>
description: <一句话设计哲学>
colors:
  - name: <语义名 e.g. canvas>
    hex: "#XXXXXX"
  - name: <语义名 e.g. primary>
    hex: "#XXXXXX"
  - name: <语义名 e.g. accent>
    hex: "#XXXXXX"
typography:
  - role: display
    fontFamily: "<font stack>"
    fontSize: "<e.g. 80px>"
    fontWeight: <number>
    lineHeight: <number>
    letterSpacing: "<e.g. -0.03em>"
  - role: body
    fontFamily: "<font stack>"
    fontSize: "<e.g. 16px>"
    fontWeight: <number>
    lineHeight: <number>
rounded:
  - name: <e.g. sm>
    value: "<e.g. 6px>"
  - name: <e.g. md>
    value: "<e.g. 12px>"
  - name: <e.g. full>
    value: "9999px"
spacing:
  - name: <e.g. xs>
    value: "<e.g. 4px>"
  - name: <e.g. md>
    value: "<e.g. 24px>"
components:
  - name: <e.g. Button>
    backgroundColor: "<hex>"
    textColor: "<hex>"
    typography: <引用 typography role>
    rounded: <引用 rounded name>
    padding: "<e.g. 12px 24px>"
---
```

---

## 9 个 Markdown Section 模板

### 1. Visual Theme & Atmosphere

描述项目的整体视觉气质和氛围。3-5 句话。

**必须回答**：
- 整体视觉印象是什么？（暗色/亮色/渐变/材质）
- 想传达的情绪是什么？（专业/活泼/安静/未来感）
- 一句话总结这个设计语言的"灵魂"

### 2. Color Palette & Roles

列出所有实际使用的颜色及其语义角色。

**必须包含**：表格列出每个颜色的语义名、hex 值、用途、使用比例。
**数据来源**：从 HTML 实际代码（CSS 变量 / Tailwind classes / inline styles）反向提取，不凭空编造。

### 3. Typography Rules

描述字体层级和使用规则。

**必须包含**：
- 字体栈（Display / Body / Mono）
- 完整字号层级（H1-H6 / Body / Caption / Code）
- 字重、行高、字间距的具体数值
- 特殊规则（如 tabular figures / 特定语言切换 / 数字字体）

### 4. Component Stylings

每个核心组件的视觉规格。

**质量标准**：至少覆盖 5 个核心组件（如 Button / Input / Card / Nav / Modal）。
每个组件包含：背景色、文字色、圆角、内边距、边框、阴影、状态（hover / active / disabled）。

### 5. Layout Principles

布局哲学和栅格系统。

**必须包含**：
- 栅格系统（列数 / gutter / max-width）
- 页面级布局模式（如左 fixed + 右 fluid / 居中容器）
- 关键间距尺度
- 内容如何组织（F 型 / Z 型 / 卡片网格）

### 6. Depth & Elevation

阴影、层级、深度的使用规则。

**必须包含**：
- 阴影层级（至少 3 级：subtle / default / prominent）
- 何时使用阴影 vs 边框
- z-index 使用规则

### 7. Do's and Don'ts

**质量标准**：Do 和 Don't 各至少 3 条，必须基于实际设计中的决策（不写空话）。

格式：
- ✅ Do: <具体规则> —— <原因>
- ❌ Don't: <具体规则> —— <原因>

### 8. Responsive Behavior

响应式策略。

**必须包含**：
- 断点定义
- 移动端 vs 桌面端的核心差异（不只是「缩小」）
- 触摸交互 vs 鼠标交互的差异

### 9. Agent Prompt Guide

给 AI agent 的"如何用本文件生成 UI"的指引。

模板：
```
当基于本 DESIGN.md 生成 UI 时：
1. 优先使用 YAML frontmatter 中定义的 colors / typography / rounded / spacing token
2. 遵循 Component Stylings 中定义的组件规格
3. 触碰不在本文件中的新设计决策时，参考 Do's and Don'ts 决定方向
4. 输出前对照 Visual Theme & Atmosphere 检查整体气质一致性
```

---

## 从 HTML 反向提取 Token 的流程

### Step A · 提取颜色

从实际 HTML 代码中提取颜色：

```bash
# 从 HTML/CSS 文件提取所有 hex 值，按出现频次排序
grep -hoE '#[0-9A-Fa-f]{6}' <html-files> | sort | uniq -c | sort -rn | head -20
```

**角色映射规则**：
- 出现频次最高 + 大面积使用 → canvas / background
- 品牌资产协议采集的 primary 色值 → primary
- 强调色 / CTA → accent
- 文字色（深色）→ ink / foreground
- 文字色（浅色，用于深底）→ muted

### Step B · 提取字体

从 HTML 代码中提取字体栈：

```bash
# 从 link 标签和 font-family 提取
grep -hoE 'font-family:[^;"]+' <html-files> | sort -u
grep -hoE 'family=[^&"]+' <html-files> | sort -u
```

**层级推断**：
- 最大字号 + 高字重 → display
- 正文默认 → body
- 等宽字体（如 JetBrains Mono / SF Mono）→ mono

### Step C · 提取圆角

```bash
grep -hoE 'border-radius:[^;"]+' <html-files> | sort | uniq -c | sort -rn
grep -hoE 'rounded-(sm|md|lg|xl|full|2xl|3xl)' <html-files> | sort | uniq -c | sort -rn
```

### Step D · 提取间距

从 padding / margin / gap 中找规律：

```bash
grep -hoE '(padding|margin|gap):\s*[^;"]+' <html-files> | sort | uniq -c | sort -rn | head -10
```

将常见值归类为 t-shirt 尺度（xs / sm / md / lg / xl）。

### Step E · 提取组件规格

挑出 5+ 核心组件，从其 JSX / CSS 中读取实际样式值（背景色、文字色、圆角、padding 等），填入 components 字段。

---

## 质量标准（自检清单）

生成 DESIGN.md 后必须逐项核对：

- [ ] YAML frontmatter 中每个 hex 值都来自实际 HTML 代码，不凭空编造
- [ ] typography 至少包含 display / body / mono 三个 role
- [ ] Component stylings 至少覆盖 5 个核心组件
- [ ] Do's 和 Don'ts 各至少 3 条，每条带原因
- [ ] 总长度控制在 300-600 行（参考 Linear 548 行 / Stripe 487 行）
- [ ] 不写空话（如"现代/优雅"等无信息量形容词）

---

## 示例引用

完整 DESIGN.md 示例可参考 awesome-design-md 仓库：
- Linear: `design-md/linear/DESIGN.md`（548 行，深色 + 紫蓝 accent，21 个组件定义）
- Stripe: `design-md/stripe/DESIGN.md`（487 行，渐变 mesh + indigo，15 个组件定义）
- 仓库地址：https://github.com/VoltAgent/awesome-design-md

---

## 生成时机

DESIGN.md 在以下条件下生成：
1. 用户在需求确认阶段明确选择「生成 DESIGN.md」
2. HTML 已交付并通过验证（不是 hi-fi 还没做完就提前生成）

不适用场景：
- 用户明确说"不要"
- 纯动画 / 纯幻灯片任务（这些不是 UI 系统，DESIGN.md 没有意义）
- 未完成 placeholder 大量存在时（先补完，再生成）
