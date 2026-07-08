# Glossary

> 本文件是 SSOT（Single Source of Truth）术语表。其他文档引用术语时写 `→ 见 glossary.md#术语`，不重定义。

## Harness Engineering
不是教模型「怎么回答」，而是设计模型「怎么工作」。`Agent = Model + Harness`。本仓库指 agent-harness 这一 AI 辅助软件开发工作流插件体系。

## 三层工作流
决策层（要不要做）/ 执行层（怎么做）/ 质量层（做得好不好）。详见 `CLAUDE.md`。

## phase-metrics
阶段级运行指标持久化。每行 JSON 一条事件，含 token / 耗时 / gate_result 等。见 plans/2026-06-29-phase-metrics.md。

## handoff / 交接契约
skill 间交接点的 YAML frontmatter schema + 校验脚本。见 plans/2026-06-29-handoff-contracts.md。

## spec_topic
跨 spec/plan/contract 的稳定主题锚点。必须存在于 `index.md` 的「主题速查」段，由 validate-handoff 校验。

## SSOT
Single Source of Truth。术语只在 glossary.md 定义一次。

## 两级查找
index.md → 子目录 index.md → 具体文件。禁止 `**/*.md` 全局通配。
