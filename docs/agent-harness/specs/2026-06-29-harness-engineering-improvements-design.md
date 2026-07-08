---
spec_topic: harness-engineering-improvements
decision_summary: "把参考文章方法论翻译成 agent-harness 文件式架构；4 个 spec 覆盖可监测性/协议层/知识库/失败自愈，零新依赖。"
design_approved: true
user_approved_at: 2026-06-29T00:00:00Z
gates: [user-review-passed]
---

# Harness Engineering 改进设计

- **Date**: 2026-06-29
- **Status**: Proposed
- **Owner**: evanfang0054
- **Source**: 参考《开启Harness Engineering探索之旅》提炼的工程经验，对照本仓库现状的差距分析

## 背景

《开启Harness Engineering探索之旅》系统总结了 Harness Engineering 的工程方法：协议层（契约）、管线层（阶段）、纪律层（门禁）、可监测性（指标）、知识库（长期记忆）、失败自愈（诊断闭环）。大量实践依赖特定业务栈（TAPD / CLS / K8s / 评分≥95 硬门禁），与本项目「通用 Harness 框架」目标冲突。

经现状排查，agent-harness 在以下四层有明确缺口：

1. **可监测性**：`coverage-metrics.sh` 只做即时快照，无跨 session 阶段指标持久化、无 token/成本度量
2. **协议层契约**：spec/plan-document-reviewer 是事后软审稿，交接点无机器可校验的硬前置
3. **知识库**：`specs/`、`contracts/`、`plans/`、`notes/` 平铺无索引，缺两级查找与 SSOT 约定
4. **失败自愈**：loop-detector 只报警、systematic-debugging 依赖人工驱动，无诊断报告闭环

## 目标

把参考文章的方法论翻译成 agent-harness 已有的「文件式 + shell-based + 跨平台」架构能承载的形态。**不引入后端服务、不绑定平台、不堆企业依赖**。

## 非目标

- ❌ Hook Engine 中央聚合 / Report API / 跨项目对比（需后端）
- ❌ 评分≥95 硬门禁（参考文章的硬规矩，当前阶段先把数据/契约拿到，门禁暂缓）
- ❌ 向量检索 / embedding（需外部服务）
- ❌ UI 像素校准 / API debugger 自动拉 CLS/MySQL/Redis（业务特定栈）
- ❌ 知识库自动治理 / 老化淘汰（参考文章自身标注「待实现」）

## 整体框架

### 四 spec 优先级

| # | Spec | 优先级理由 |
|---|---|---|
| 1 | 可监测性 | 数据是后续所有改进的度量基础 |
| 2 | 协议层契约 | 用可观测数据验证交接质量 |
| 3 | 知识库 / 上下文 | 协议稳定后再谈检索质量 |
| 4 | 失败自愈 | 最高阶，依赖前三者的信号/契约/上下文 |

### Spec 间依赖

```
#1 可监测性 ────────┐
                    │
                    ▼
#2 协议层契约 ──┬── #4 失败自愈
                │     ▲
#3 知识库 ──────┴─────┘
```

- #1 → #2/#4：#2 的 `gate_result` 字段、#4 的「门禁失败」信号源依赖 phase-metrics
- #2 ↔ #3：#2 frontmatter 的 `spec_topic` 必须存在于 #3 的 index.md
- #3 → #4：#4 相似故障检索依赖 #3 增强后的 learnings 索引

### Plan 阶段实施顺序

1. #1 可监测性（无依赖）
2. #3 知识库（不依赖其他 spec，可与 #1 并行）
3. #2 协议层契约（依赖 #1 + #3）
4. #4 失败自愈（依赖前三者）

#1 与 #3 可并行，是缩短总周期的关键。

### 跨 spec 共享决策

| 决策 | 约定 | 理由 |
|---|---|---|
| JSON/YAML 风格 | 全部小写 + 下划线；时间戳 ISO 8601；必含 `ts` / `spec_topic` / `confidence`（适用时） | 与 learnings.jsonl 现有风格一致 |
| 持久化位置 | 运行态文件 `.agent-harness/<name>.jsonl` 或 `<dir>/`；产物文件 `docs/agent-harness/<subdir>/` | 运行态不入 git，产物入 git |
| 零新依赖 | shell + jq + yq（可 sed fallback）；不引入 Python/Rust/外部服务 | 与 agent-harness 现有架构一致 |
| 子代理调用约定 | 不新增子代理——四个 spec 都用 shell 脚本 + 现有 reviewer 子代理 | 参考文章「SubAgent 是独立计费」洞察，能 shell 解决的不开子代理 |
| skill emit 时机 | skill 边界事件主动调 shell，不靠 hook 触发 | 与 learnings/ralph-loop 现有架构一致 |
| 增量不替换 | 四个 spec 全部保留现有机制，并行/扩展而非替代 | 无 breaking change |

---

## Spec #1 · 可监测性

### 目标

让「这套 harness 好不好用、贵不贵、哪一步老翻车」从感觉变成数据。复用 learnings 基础设施模式，新增阶段级指标持久化，让 retrospective / coverage-metrics / 后续三个 spec 都能拿到跨 session 的趋势数据。

### 架构

```
┌─ 阶段边界事件 ─────────────────────────────┐
│ brainstorming→writing-plans→executing-plans│
│ 各 skill 在完成/门禁通过时 emit 一行 JSON    │
└──────────────────┬─────────────────────────┘
                   │ 通过统一脚本
                   ▼
   .agent-harness/phase-metrics.jsonl   ← 持久化（不入 git）
                   │
        ┌──────────┼─────────────┐
        ▼          ▼             ▼
  retrospective  coverage-     新增
  skill 读取     metrics.sh    query-phase-metrics.sh
  生成趋势报告   扩展维度      (供 #2/#3/#4 用)
```

### 关键产物

**a) `.agent-harness/phase-metrics.jsonl`**（运行态，不入 git）

每行一个阶段事件，schema：

```json
{
  "ts": "2026-06-29T14:23:11Z",
  "session_id": "<claude session>",
  "spec_topic": "phase-metrics-design",
  "phase": "brainstorming",
  "action": "phase:end",
  "duration_ms": 184320,
  "input_tokens": 12340,
  "output_tokens": 5678,
  "estimated_cost_usd": 0.082,
  "model": "claude-sonnet-4-6",
  "lines_added": 42,
  "lines_deleted": 0,
  "files_changed": 1,
  "gate_result": "passed",
  "retries": 0
}
```

字段命名与参考文章对齐（`total_input_tokens` 简化为 `input_tokens`），但不照搬全部字段——去掉 `response_count`、`estimated_cost_usd` 用本地费率表（避免外部依赖）。

**b) `scripts/log-phase-metric.sh`**（新增，仿 `log-learning.sh`）

- 参数：`--phase <name> --action <start|end|gate> [--duration-ms <n>] [--tokens-in <n>] [--tokens-out <n>] ...`
- 自动从 git diff 统计 lines/files
- 自动从 `CLAUDE_SESSION_ID`（或 fallback `git rev-parse HEAD` 时间戳）取 session_id
- jq 安全注入（复用 `lib/state.sh` 模式）
- 失败静默 + stderr 警告，绝不阻断主流程

**c) `scripts/query-phase-metrics.sh`**（新增）

- 参数：`--phase <name> --recent <days> --by-spec <topic> --summary`
- 输出：均值 / p50 / p95 / 失败率 / 重试次数 / 累计成本
- 供 retrospective skill、coverage-metrics.sh、后续三个 spec 复用

**d) 现有脚本/skill 集成点**

| 现有 | 改动 |
|---|---|
| `scripts/coverage-metrics.sh` | 新增 `--trends` 子命令，调 query-phase-metrics 输出阶段趋势 |
| `skills/retrospective/SKILL.md` | 在分析阶段调用 query-phase-metrics，把「上 sprint 哪个阶段失败率最高」写进报告 |
| `skills/brainstorming/writing-plans/executing-plans` 等核心 skill | 在 `phase:end` / `gate:passed` 边界调用 log-phase-metric（一行 shell，不侵入主逻辑） |
| `hooks/hooks.json` | **不改**——指标由 skill 主动 emit，不靠 hook 触发 |
| `.gitignore` | 新增 `.agent-harness/phase-metrics.jsonl` |

### 数据流

1. brainstorming skill 跑完 spec self-review → 调 `log-phase-metric.sh --phase brainstorming --action end --duration-ms ...`
2. writing-plans 通过 plan-document-reviewer → 调 `log-phase-metric.sh --phase writing-plans --action gate --gate-result passed`
3. executing-plans / TDD / verification 各自 emit
4. retrospective 跑 `query-phase-metrics.sh --recent 14 --summary` → 趋势写入报告
5. session-learnings 可选：失败率高的阶段自动建议沉淀 learning

### Skill emit 范围

**仅覆盖三层工作流的核心 skill**，不强制全部 33 个 skill emit：

- 决策层：brainstorming、writing-plans
- 执行层：executing-plans、test-driven-development、verification-before-completion
- 质量层：requesting-code-review、retrospective

非核心 skill（loop-detection、session-learnings 等工具型）不 emit——它们是机制而非阶段。

### 测试策略

- **新增** `tests/phase-metrics-scripts/test-phase-metrics.sh`（仿 `tests/learnings-scripts/` 模式）：
  - log 后 jsonl 立即可查
  - jq 注入安全（特殊字符、缺字段）
  - query 的 p50/p95 计算正确
  - 失败静默不影响退出码
- **集成测试**（可选，依赖 Claude API 配额）：在 `tests/skill-behavior/retrospective/` 加用例，验证 retro skill 能读到指标
- **不**做 headless 全链路 token 度量——那是 Claude Code 本身的职责

### 边界

- ❌ 不做跨项目对比（需后端）
- ❌ 不做实时上报（fire-and-forget 即可）
- ❌ 不做自动告警（指标超阈值时由 retrospective 人工读，不引入 hook 触发）
- ❌ 不做「评分≥95 才放行」硬门禁（当前阶段先把数据拿到，门禁是 #2 协议层的事）
- ✅ 预留扩展位：`gate_result` 字段支持后续协议层接入

---

## Spec #2 · 协议层契约

### 目标

把 skill 间交接从「自然语言软校验」升级为「机器可校验的 schema 前置条件」。当前 `spec-document-reviewer-prompt.md` / `plan-document-reviewer-prompt.md` 是事后子代理审稿，无法在交接点硬阻断；本 spec 在关键交接点加结构化前置 schema，让「输入不合格 → 当步就退回」，而不是到下游才发现。

### 架构

```
brainstorming                 writing-plans                executing-plans
    │                             │                            │
    ▼                             ▼                            ▼
spec.md (markdown)          plan.md (markdown)          tasks (markdown)
    │                             │                            │
    └──┐                   ┌──────┘                       ┌─────┘
       ▼                   ▼                              ▼
  spec-frontmatter     plan-frontmatter              task-frontmatter
  (YAML 块)            (YAML 块)                     (YAML 块)
       │                   │                              │
       └───────┬───────────┴──────────────┬─────────────┘
               ▼                          ▼
     scripts/validate-handoff.sh   spec-document-reviewer /
     (硬前置校验)                   plan-document-reviewer
                                   (软审稿，保留)
```

核心思路：**在已有 markdown 文档顶部加 YAML frontmatter**，把「交接所需的机器可读字段」沉淀成结构化数据；markdown 正文仍给人/模型读，frontmatter 给脚本校验。两层共存，不冲突。

### 三个关键交接点

| 交接点 | frontmatter schema 关键字段 | 校验脚本 |
|---|---|---|
| brainstorming → writing-plans | `spec_topic`, `decision_summary` (≤200字), `design_approved: bool`, `user_approved_at: ts`, `gates: [list]` | `validate-spec-frontmatter.sh` |
| writing-plans → executing-plans | `spec_ref`, `task_count`, `estimated_phases: [list]`, `dependencies: {task_id: [blocks]}`, `dod: <sprint-contract ref>` | `validate-plan-frontmatter.sh` |
| executing-plans → verification | `plan_ref`, `implemented_tasks: [ids]`, `tests_passed: bool`, `evidence_paths: [list]` | `validate-task-frontmatter.sh` |

YAML 而非 JSON：与 skill 的 SKILL.md frontmatter 风格一致（已有先例），可读、可手改、可 grep。

### 校验机制

**a) `scripts/validate-handoff.sh`**（新增）

- 参数：`--stage <spec|plan|task> --file <path>`
- 用 `yq`（或纯 sed 兜底，零新依赖）解析 YAML
- 缺字段 / 字段格式错 / 引用的 ref 不存在 → 退出码非 0 + stderr 列出问题
- 成功 → 退出码 0 + stdout 一行摘要

**b) 与现有 reviewer 子代理的关系**

- spec-document-reviewer / plan-document-reviewer：**保留**，做语义审稿（逻辑矛盾、scope 漂移、placeholder 残留）
- validate-handoff.sh：**新增**，做结构前置校验（字段齐全、引用有效）
- 二者并行：结构是语义的前提，结构不通过不浪费子代理 token

**c) Skill 集成**

brainstorming skill 在「写 spec 文档」步骤后，强制跑一次 `validate-handoff.sh --stage spec`；writing-plans 在写完 plan 后同样。失败则回到 spec/plan 修改，不进入下游。

这与 Spec #1 的 `log-phase-metric.sh --action gate` 自然衔接：gate 通过即 emit 指标。

### 数据流

```
1. brainstorming 写 spec.md（含 frontmatter）
2. validate-handoff.sh --stage spec --file spec.md   ← 硬前置
3. 失败 → 回到 step 1 修改
4. 通过 → spec-document-reviewer 子代理语义审稿（软）
5. 用户认可 → log-phase-metric.sh --phase brainstorming --action gate --gate-result passed
6. writing-plans 接力，写 plan.md（含 frontmatter，spec_ref 指向 spec.md）
7. validate-handoff.sh --stage plan   ← 校验 spec_ref 真实存在
...
```

### 测试策略

- **新增** `tests/handoff-scripts/test-validate-handoff.sh`：
  - 各 stage 的 frontmatter 缺字段 / 错格式 / ref 指向不存在文件 → 非零退出
  - 合法 frontmatter → 零退出 + 摘要
  - yq 不存在时 sed fallback 正确
- **集成测试**：在 `tests/skill-behavior/brainstorming/` 加用例，验证 spec 文档生成后能通过 validate-handoff
- **回归**：跑一遍现有 `tests/explicit-skill-requests/`，确认 frontmatter 不破坏 skill 触发

### 边界

- ❌ 不给全部 33 个 skill 上 schema——只覆盖三层工作流的 3 个核心交接点
- ❌ 不引入 JSON Schema 全量规范——YAML frontmatter + 手写校验脚本足够
- ❌ 不做「schema 演进版本号」——YAGNI，等真有第二个版本再说
- ❌ 不替换现有 reviewer 子代理——并行不替代
- ✅ frontmatter 字段从最小集开始，后续按需扩

---

## Spec #3 · 知识库 / 上下文

### 目标

让上下文注入从「塞得越多越好」变成「每一步只送该看见的那一片」。当前 `docs/agent-harness/specs/`、`contracts/`、`plans/`、`notes/` 平铺无索引，长期累积会让 SessionStart hook 注入和 skill 检索越来越贵；learnings 也仅 keyword grep，无语义定位。本 spec 给知识库加两级索引 + SSOT 约定，让 token 花在关键信息上。

### 架构

```
docs/agent-harness/
├── index.md                 ← 新增·顶级索引（入口）
│   └─ 按主题列 specs/contracts/plans/notes 的入口指针
├── specs/
│   ├── index.md             ← 新增·二级索引
│   └── *.md
├── contracts/
│   ├── index.md             ← 新增·二级索引
│   └── *.md
├── plans/
│   ├── index.md             ← 新增·二级索引
│   └── *.md
└── notes/
    ├── index.md             ← 新增·二级索引
    └── *.md

.agent-harness/learnings.jsonl   ← 已存在
└─ 新增 scripts/index-learnings.sh：按 type/key 聚类生成摘要索引
```

**核心原则**（来自参考文章 §2.3.1）：

- **两级查找**：`index.md` → 具体 spec，禁止 `**/*.md` 全局通配
- **SSOT**：术语只在 `glossary.md` 定义一次，别处引用不得重定义
- **原位增量更新**：不复制时间戳目录，原文件改 + git diff 审查

### 关键产物

**a) `docs/agent-harness/index.md`**（新增）

顶级入口，结构化列出四个子目录的入口 + 高频主题：

```markdown
# Agent Harness 知识库索引

## 检索规则
- 两级查找：本文件 → 子目录 index.md → 具体 spec
- 禁止 **/*.md 全局通配
- 术语去 glossary.md 查

## 子目录入口
- specs/     — 设计 spec（按主题）
- contracts/ — 交接契约（按交接点）
- plans/     — 实施 plan
- notes/     — 学习笔记 / 偶发记录

## 主题速查（高频）
- 可监测性 → specs/2026-06-29-phase-metrics-design.md
- 知识库   → specs/2026-06-29-knowledge-base-design.md
- ...
```

**b) 每个子目录的 `index.md`**

二级索引，按文件主题聚类，一行一个指针（与 MEMORY.md 风格一致）：

```markdown
# specs/ 索引

## 可监测性
- [阶段指标设计](2026-06-29-phase-metrics-design.md) — token/耗时/失败率持久化

## 知识库
- [知识库索引设计](2026-06-29-knowledge-base-design.md) — 两级查找 + SSOT
```

**c) `docs/agent-harness/glossary.md`**（新增）

SSOT 术语表，所有 spec / plan / contract 引用术语时只写 `→ 见 glossary.md#术语`，不重定义。

**d) `scripts/index-knowledge-base.sh`**（新增）

- 扫描四个子目录的 .md 文件，根据 frontmatter（spec #2 引入的）或首段摘要自动维护 index.md
- 幂等，重复运行不产生 diff
- 供 writing-plans 完成后调用（plan 落盘 → 更新索引）

**e) `scripts/index-learnings.sh`**（新增）

- 按 `type` / `key` 聚类 learnings.jsonl，输出 `top-N by confidence` 摘要
- SessionStart hook 在 learnings > 50 条时节流逻辑替换为调本脚本
- 不持久化新文件，每次实时计算（learnings 量小，毫秒级）

### 与现有机制的集成

| 现有 | 改动 |
|---|---|
| `hooks/session-start` | 注入块新增一行「知识库入口：`docs/agent-harness/index.md`，禁止 `**/*.md` 通配」——不注入正文，只指路 |
| `skills/brainstorming/writing-plans` 等 | 在「探索项目上下文」步骤明确要求：先读 `docs/agent-harness/index.md`，再按需跳到子目录 index |
| `skills/session-learnings` | 在写 learning 时，若 key 已存在则提示是否更新而非新建（SSOT 精神延伸到 learnings） |
| Spec #1 phase-metrics | metrics 的 `spec_topic` 字段与 index.md 的主题锚点对齐，方便 retro 时按主题聚合 |
| Spec #2 frontmatter | frontmatter 的 `spec_topic` 字段值必须在 index.md 出现，否则 validate-handoff 失败——**Spec 间咬合** |

### 数据流

```
1. 新需求开始 → SessionStart 注入 index.md 指路
2. brainstorming "探索项目上下文" 步骤 → 读 index.md → 跳 specs/index.md
3. 决定写新 spec → 写完更新 specs/index.md（手动 or 调 index-knowledge-base.sh）
4. writing-plans 写 plan → plan.md frontmatter 的 spec_topic 校验存在
5. 后续任何 skill 需要历史资料 → 先查 index.md，再精确读
6. SessionStart 注入 learnings → index-learnings.sh 输出聚类摘要
```

### 测试策略

- **新增** `tests/knowledge-base-scripts/test-index-knowledge-base.sh`：
  - 给定子目录一组 .md（含/缺 frontmatter），生成的 index.md 包含全部条目
  - 重复运行无 diff（幂等）
  - 删除文件后重生成，index.md 同步
- **新增** `tests/knowledge-base-scripts/test-index-learnings.sh`：
  - 给定 jsonl，聚类输出正确
  - confidence decay 后排序变化
- **集成**：`tests/skill-behavior/brainstorming/` 加用例，验证 skill 在新会话首步读了 index.md
- **回归**：现有 SessionStart 注入体积不爆（index.md 只列指针，不嵌正文）

### 边界

- ❌ 不做向量检索 / 语义相似度（embedding 依赖外部）
- ❌ 不做自动治理 / 老化 / 淘汰（参考文章自己标注待实现）
- ❌ 不复制 trpcgo-protocol 那种「代码派生文档」模式（本项目无对应代码源）
- ❌ 不强制全部 .md 必须有 frontmatter（向后兼容，老文件原样保留）
- ✅ index.md 由脚本维护，降低人工出错概率
- ✅ 与 Spec #2 frontmatter 咬合，让「主题」成为跨 spec 的稳定锚点

---

## Spec #4 · 失败自愈

### 目标

把失败处理从「报警 + 人工介入」升级为「诊断报告 → 可执行修复任务」的闭环。当前 `loop-detector` 只在多次编辑同一文件时 HARD STOP，`systematic-debugging` skill 依赖人工驱动根因分析；本 spec 在二者之间插入一个**诊断报告生成器**，把 trace-analyzer / phase-metrics / learnings 的输出收敛成结构化诊断，并回写为可被 executing-plans 消费的任务。

### 架构

```
失败信号源                              诊断生成                    消费
┌─────────────────────┐                ┌──────────────────┐      ┌──────────────┐
│ loop-detector       │──┐          ┌──│ diagnose-failure │──→── │ 回写为 task │
│ (HARD STOP 信号)    │  │          │  │ .sh              │      │ 写入 plan    │
├─────────────────────┤  ├──merge──┤  ├──────────────────┤      │ 或 learnings │
│ phase-metrics       │  │          │  │ 输出 JSON 诊断   │      └──────────────┘
│ (gate_result:failed)│──┤          │  │ + 建议修复路径   │            │
├─────────────────────┤  │          └──┬─────────────────┘            │
│ test 失败 / 验证失败│──┘             │ input from                   ▼
└─────────────────────┘                │                              │
                                  ┌────▼─────────────┐      人工决策点
                                  │ trace-analyzer   │      (stop or 重新进
                                  │ .sh              │      executing-plans)
                                  │ learnings grep   │
                                  └──────────────────┘
```

核心思路：**复用已有信号源，新增一个收敛层 + 一个回写层**，不引入新检测机制。诊断报告是机器可读的 JSON（与 #1/#2 风格一致），回写是 markdown task（与 executing-plans 兼容）。

### 三种失败类型与诊断路径

| 失败类型 | 触发信号 | 诊断路径 | 收敛终点 |
|---|---|---|---|
| **循环编辑**（loop-detector HARD STOP） | 多次编辑同一文件未收敛 | 提取编辑历史 → trace-analyzer 分类 → learnings grep 相似模式 | 诊断报告 + 回写 task（「重新设计该文件边界」或「拆子代理」） |
| **门禁失败**（phase-metrics gate_result=failed） | validate-handoff 或 reviewer 子代理打回 | 取失败 stage + 校验错误信息 → 学习历史同类失败 | 诊断报告 + 回写 task（「修复 frontmatter 字段」或「回到 brainstorming」） |
| **测试/验证失败**（verification-before-completion 检测到） | 测试非零退出 / 命令证据缺失 | 取失败命令 + 输出 → systematic-debugging skill 接管（已存在） | 现有链路，本 spec 只补「回写 task」环节 |

### 关键产物

**a) `scripts/diagnose-failure.sh`**（新增）

- 参数：`--type <loop|gate|test> --context <json-or-file> [--spec-topic <t>]`
- 内部调度：
  - 调 `trace-analyzer.sh` 取失败模式分类
  - 调 `query-phase-metrics.sh`（Spec #1）取同阶段历史失败率
  - 调 `search-learnings.sh` 取相似 key 的 learnings
- 输出 `.agent-harness/diagnoses/<ts>-<type>-<slug>.json`，schema：

```json
{
  "ts": "...",
  "failure_type": "loop|gate|test",
  "failure_summary": "3 次编辑 spec.md 未通过 validate-handoff",
  "evidence": {
    "trace_classification": "schema-mismatch",
    "phase_history": {...},
    "similar_learnings": [{...}]
  },
  "root_cause_hypothesis": "frontmatter schema 与 spec #2 要求不匹配",
  "suggested_fixes": [
    {"action": "revisit-brainstorming", "rationale": "..."},
    {"action": "manual-intervention", "rationale": "..."}
  ],
  "confidence": 7
}
```

**b) `scripts/write-diagnosis-task.sh`**（新增）

- 把诊断 JSON 转成 markdown task（与 executing-plans 的 task 格式兼容）
- 默认行为：plan.md 存在则追加到 plan.md，否则独立文件写入 `docs/agent-harness/notes/diagnoses/`
- **不自动执行**——只生成 task，由人或 executing-plans 决定是否消费

**c) `skills/systematic-debugging/SKILL.md`**（增强）

- 在原根因分析流程后，新增一步：调 `diagnose-failure.sh` 把隐性经验沉淀为结构化诊断
- 调试结束时调 `write-diagnosis-task.sh` 把「这次怎么修的」回写

**d) `skills/loop-detection/SKILL.md`**（增强）

- HARD STOP 时不再只输出警告，而是触发 `diagnose-failure.sh --type loop`
- 诊断报告路径在警告里告知用户，便于后续追溯

### 与其他 spec 的咬合

| 依赖 | 用法 |
|---|---|
| Spec #1 phase-metrics | diagnose-failure 取 `gate_result=failed` 的事件作为门禁失败信号；取同阶段历史失败率作为根因证据 |
| Spec #2 frontmatter | 诊断报告的 `suggested_fixes` 引用 spec_topic（必须存在于 index.md，由 #3 校验） |
| Spec #3 知识库 | `search-learnings.sh` 由 #3 增强聚类后，相似故障命中更准；诊断报告本身存入 `notes/diagnoses/` 并被 index.md 索引 |

### 数据流

```
1. executing-plans 跑 task → 测试失败 / loop-detector 触发 / validate-handoff 失败
2. diagnose-failure.sh --type <type> --context <...>
3. 内部：trace-analyzer + query-phase-metrics + search-learnings
4. 输出 JSON 诊断 → .agent-harness/diagnoses/<ts>.json
5. write-diagnosis-task.sh → 追加 task 到 plan.md 或独立文件
6. executing-plans 下一次迭代消费该 task（或人工 review 后决定）
7. systematic-debugging skill 介入时也能读历史诊断，避免重复根因分析
```

### 测试策略

- **新增** `tests/diagnose-scripts/test-diagnose-failure.sh`：
  - 给定 mock 的 loop/gate/test 失败 context，输出合法 JSON
  - 三个信号源都缺失时优雅降级（不崩）
  - learnings 为空时不报错
- **新增** `tests/diagnose-scripts/test-write-diagnosis-task.sh`：
  - JSON → markdown task 格式正确
  - plan.md 不存在时退化为独立文件
- **集成**：在 `tests/skill-behavior/systematic-debugging/` 加用例，验证调试结束生成了诊断报告
- **回归**：loop-detector 的 HARD STOP 行为不变，只是多了一步诊断生成

### 边界

- ❌ 不自动执行修复——只生成 task，人审或 executing-plans 决定（避免误修复）
- ❌ 不做 UI 像素校准 / API debugger（业务特定栈）
- ❌ 不做跨项目诊断共享（需后端，超出通用框架）
- ❌ 不做诊断报告的自动老化（YAGNI，文件少时人工清理即可）
- ❌ 不引入新检测机制——复用 loop-detector / phase-metrics / verification 的现有信号
- ✅ 诊断 JSON schema 与 phase-metrics 风格统一（小写、下划线、ts/spec_topic/confidence）
- ✅ 「诊断 → task → executing-plans 消费」形成闭环，但每一步都可被人工打断

---

## 风险与权衡

| 风险 | 缓解 |
|---|---|
| 四 spec 同时实施，工程量较大 | Plan 阶段按依赖顺序拆任务；#1/#3 可并行 |
| 新增脚本引入维护成本 | 全部仿现有 `log-learning.sh` / `coverage-metrics.sh` 模式，风格统一 |
| skill 主动 emit 指标可能漏报 | 初期接受漏报；retrospective 自带「指标缺失即信号」的兜底 |
| frontmatter 可能被 skill 写错 | validate-handoff.sh 是硬前置，错了就退回——这正是协议层的目的 |
| 诊断报告可能积累成垃圾 | YAGNI：先做起来，量大了再谈治理（参考文章自身也是这个态度） |

## 成功标准

- [ ] Spec #1：retrospective 能输出「过去 14 天各阶段失败率 / 平均耗时 / 累计 token 成本」
- [ ] Spec #2：brainstorming → writing-plans → executing-plans 三个交接点全部有 schema 校验，结构错必退回
- [ ] Spec #3：SessionStart 注入体积不增加（只加一行指路），但 skill 能通过两级查找命中历史 spec
- [ ] Spec #4：任意一种失败类型触发后，能产出结构化诊断报告 + 回写 task，且不自动执行
- [ ] 全部 spec：现有测试套件不退化，新增测试套件通过
