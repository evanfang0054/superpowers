---
name: gate-driven-test-design
description: Use after brainstorming produces an approved design spec, before writing-plans — derives a risk-based test coverage tree (Gates + Assertions).
when_to_use: "[feedforward] Triggered between brainstorming and writing-plans for features with non-trivial behavior, contracts, or regression risk."
---

# Gate Driven Test Design (GDD)

## Overview

从已批准的设计 spec 出发，按风险显著性提取 Level Items（L1-L4 抽象层级），递归向下展开「为让父项成立，子项必须满足什么」，得到树状测试覆盖结构。树状结构天然构成金字塔形状——多底少顶，且每个叶子指向一个具体 Gate 与断言。

**核心原则**：测试结构不是事后校验，而是事前递归生成的产物。

## When to Use

- brainstorming 已写完 design spec 且用户复核通过
- 功能涉及：用户路径、跨模块协作、公共契约、数据正确性、权限、复杂规则、回归风险
- **不适用**：单行 typo、纯文档、无行为变更的改动

## Entry Contract（进入前置）

- 已存在 `docs/agent-harness/specs/YYYY-MM-DD-<topic>-design.md`
- 用户明确说「生成测试用例 / 生成 GDD 段 / 进入测试设计」
- 若 spec 缺关键决策 → 返回 blocking questions，不写半成品

## Process（骨架）

执行流程详见 `references/generation-prompt.md`，共 7 步：

1. Read Source → 2. Extract Initial Level Items → 3. Recursively Expand Children → 4. Consolidate Tree → 5. Generate Gates & Assertions → 6. Audit Cross-Layer Ownership → 7. Merge Redundant

Gate 能力字典见 `references/gate-capability-table.md`。

## Output

在 spec 文件**追加或更新** `## Gate Driven Development` 段（不另存新文件），格式见 generation-prompt.md 的 Output Format 节。

## Exit & Handoff

- GDD 段写入后，回到 brainstorming 的 User Review Gate，让用户复核 GDD 段
- 复核通过 → 调用 writing-plans，plan task 须与 GDD assertions 一一对应

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "测试结构等写完代码再校验" | 事后校验是宏观打微观，效果差；递归生成才能自然成形 |
| "Level Items 越多越好" | 只为风险显著性而设，冗余项稀释覆盖焦点 |
| "L4 的 e2e 要穷举所有错误码" | L4 只证路径可达，详细矩阵下沉到 L2/L3 |
| "缺决策先猜一个" | blocking——返回提问，不写半成品 |
