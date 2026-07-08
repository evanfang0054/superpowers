# Agent Harness 知识库索引

## 检索规则
- 两级查找：本文件 → 子目录 index.md → 具体 spec/plan/contract/note
- 禁止 `**/*.md` 全局通配
- 术语去 `glossary.md` 查，不重定义

## 子目录入口
- [specs/](specs/index.md)     — 设计 spec（按主题）
- [contracts/](contracts/index.md) — 交接契约（按交接点）
- [plans/](plans/index.md)     — 实施 plan
- [notes/](notes/index.md)     — 学习笔记 / 偶发记录（含 [diagnoses/](notes/diagnoses/) 失败诊断沉淀）

## 主题速查（高频主题锚点）
> 主题锚点是跨 spec/plan/contract 的稳定 key，frontmatter 的 `spec_topic` 字段必须命中本节。

- harness-engineering-improvements → specs/2026-06-29-harness-engineering-improvements-design.md
- phase-metrics → plans/2026-06-29-phase-metrics.md
- knowledge-base → plans/2026-06-29-knowledge-base.md
- handoff-contracts → plans/2026-06-29-handoff-contracts.md
- failure-diagnosis → plans/2026-06-29-failure-diagnosis.md

> 维护方式：手动追加，或跑 `scripts/index-knowledge-base.sh` 自动重建。
