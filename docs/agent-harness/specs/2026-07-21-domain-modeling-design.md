---
spec_topic: domain-modeling
decision_summary: "引入 domain-modeling skill + 根目录 CONTEXT.md glossary + docs/agent-harness/adr/，填补 agent-harness 无持久化领域语言层的空白；深度集成 hook/init/validate/brainstorming。"
design_approved: true
user_approved_at: 2026-07-21T00:00:00Z
gates: [user-review-passed]
---

# Domain Modeling 领域语言层设计

- **Date**: 2026-07-21
- **Status**: Proposed
- **Owner**: evanfang
- **Source**: 对照 `mattpocock/skills`（179k stars）的 `domain-modeling` / `grill-with-docs` / `CONTEXT.md` 机制，识别 agent-harness 在领域语言持久化层的空白

## 背景

agent-harness 有成熟的知识持久化基础设施，但在"领域语言"这一层存在空白：

1. **learnings.jsonl** 是会话知识（ephemeral、confidence decay、throttle top-5），记录 pattern/pitfall/preference，**不是**领域词汇
2. **`docs/agent-harness/glossary.md`** 已存在，但是 **harness 元术语表**（Harness Engineering / 三层工作流 / phase-metrics），不是项目领域词汇
3. **grep 零匹配**：`CONTEXT.md` / `ADR` / `ubiquitous language` / `domain model` 在 `skills/` 和 `docs/` 中无任何结果
4. **harness-init** 只创建 `sensors.json` + hooks config，不创建任何词汇/glossary 文件
5. **brainstorming** 的澄清环节问问题但不沉淀术语——每次新会话/新 subagent 都要重新理解项目 jargon

`mattpocock/skills` 的核心洞察：`CONTEXT.md` 在根目录作为纯 glossary，让 agent "spends fewer tokens on thinking, because it has access to a more concise language"。`domain-modeling` skill 在术语结晶时**立即**更新 glossary，不 batch。这是 mattpocock 称为 "single coolest technique in this repo" 的机制。

## 目标

把 mattpocock 验证过的领域语言层翻译成 agent-harness 已有的「文件式 + shell-based + 跨平台」架构能承载的形态，并深度集成到现有 hook/init/validate/brainstorming 基础设施：

1. 新增 `skills/domain-modeling/SKILL.md`（model-invoked）——维护领域 glossary 的主动纪律
2. 约定根目录 `CONTEXT.md`（glossary only）+ `docs/agent-harness/adr/`（ADR 目录）
3. session-start hook 注入 CONTEXT.md 摘要（cache-friendly）
4. harness-init 创建 CONTEXT.md scaffold + 可选 gitignore
5. validate-handoff 校验 spec 的 `domain_terms` 锚定到 CONTEXT.md（advisory）
6. brainstorming 澄清环节调用 domain-modeling 沉淀术语

## 非目标

- ❌ 语义检索 / embedding / 向量库（需外部服务）
- ❌ 自动术语抽取 / NLP（依赖模型能力，非脚本可做）
- ❌ 强制 block：validate-handoff 的 domain_terms 校验初始只 advisory，不阻断
- ❌ 跨项目 glossary 同步（每项目独立）
- ❌ CONTEXT.md 版本化 / changelog（git 已提供）
- ❌ ADR 编号自动化工具（skill 内逻辑找下一可用号即可）

## 整体架构

### 文件布局

```
agent-harness 插件源（本仓库）
├── skills/domain-modeling/SKILL.md        # 新增，model-invoked
├── hooks/session-start                     # 改：注入 CONTEXT.md 摘要
├── skills/harness-init/SKILL.md            # 改：创建 CONTEXT.md scaffold + 问 gitignore
├── scripts/lib/handoff-schema.sh           # 改：加 domain_terms advisory 校验
└── skills/brainstorming/SKILL.md           # 改：澄清环节调用 domain-modeling

每个下游项目（如 standard-benefit-fe）
├── CONTEXT.md                              # 新增，根目录，glossary only
├── .gitignore                              # 可选：加 CONTEXT.md
└── docs/agent-harness/
    ├── adr/                                # 新增目录
    │   ├── 0001-<topic>.md
    │   └── index.md                        # index-knowledge-base.sh 自动生成
    ├── glossary.md                         # 现有 harness 元术语表（不动）
    ├── specs/                              # 现有
    └── index.md                            # 改：加 domain-modeling 主题（已完成）
```

### 组件职责分离

| 组件 | 职责 | 生命周期 |
|------|------|---------|
| `CONTEXT.md` | 项目领域词汇表（glossary only） | 持久、手维护 + skill 自动更新 |
| `docs/agent-harness/adr/` | 架构决策记录 | 持久、追加只读 |
| `docs/agent-harness/glossary.md` | harness 元术语表（现有，不动） | 持久、手维护 |
| `.agent-harness/learnings.jsonl` | 会话知识（pattern/pitfall） | ephemeral、decay、throttle |
| `skills/domain-modeling/SKILL.md` | 维护 glossary 的主动纪律 | model-invoked |

## 组件详情

### 1. `skills/domain-modeling/SKILL.md`（新增，model-invoked）

**Frontmatter:**
```yaml
---
name: domain-modeling
description: "Build and sharpen the project's domain model. Use when domain terminology needs defining or sharpening, an architectural decision crystallizes, or another skill needs to maintain the domain glossary during design work."
when_to_use: "[feedforward] Triggered when domain terms need defining, sharpening, or when an architectural decision crystallizes. [feedback] Triggered when terminology conflicts are detected during other skills' work."
---
```

**Body 主要 section（adapted from mattpocock + agent-harness 约定）:**

1. **File structure** — `CONTEXT.md` at root（glossary only），ADRs in `docs/agent-harness/adr/`，monorepo 用 `CONTEXT-MAP.md` 指向子 context
2. **During-session behaviors**:
   - **Challenge against glossary** — 用户用词与 `CONTEXT.md` 矛盾时立即指出
   - **Sharpen fuzzy language** — 模糊/重载词提出精确 canonical term
   - **Discuss concrete scenarios** — 用具体场景压测领域关系边界
   - **Cross-reference with code** — 用户描述与代码矛盾时 surface
   - **Update CONTEXT.md inline** — 术语结晶时立即更新，不 batch
   - **Offer ADRs sparingly** — 仅 3 criteria 全满足时 offer（hard to reverse + surprising without context + result of real trade-off）
3. **CONTEXT.md format** — glossary and nothing else；`## <Term>` + 定义 + `_Avoid_: <aliases>`；可选 `## Relationships` section
4. **ADR format** — frontmatter `spec_topic: adr` + 编号 `0001-<topic>.md` + Context/Decision/Consequences/Alternatives sections
5. **Integration points** — brainstorming 澄清环节调用；writing-plans 读词汇；code-review 检查 spec 用词

### 2. `CONTEXT.md` 格式（项目根目录）

```markdown
# <Project> Domain Glossary

## Order
A customer's request to purchase items, in a specific currency, with a shipping address.

_Avoid_: basket, cart (those are UI states pre-purchase)

## Cancellation
A request to void an Order before it ships. Partial cancellation is not supported.

_Avoid_: refund (that's a financial event, not a domain concept)

## Relationships
- An Order holds many Line Items
- A Cancellation targets exactly one Order
```

**约束（glossary 退化的主要原因就是约束不守）:**
- **glossary and nothing else** — 不写实现细节、不写 spec、不写 scratch
- 每个 term 必须有定义 + `_Avoid_` 别名（消除歧义）
- `## Relationships` section 可选，用于描述 term 间关系

### 3. `docs/agent-harness/adr/` 格式

```markdown
---
spec_topic: adr
title: "0001-postgres-for-write-model"
decision_summary: "Use Postgres for the write model instead of DynamoDB"
date: 2026-07-21
status: accepted
---

# ADR 0001: Postgres for write model

## Context
## Decision
## Consequences
## Alternatives considered
```

- `spec_topic: adr` 让 `index-knowledge-base.sh` 自动扫到并生成 `adr/index.md`
- 编号从 `0001` 起，skill 找下一可用号
- `status`: `proposed` / `accepted` / `superseded` / `deprecated`

### 4. Hook 集成（`hooks/session-start`）

在 KB pointer 注入之后（约 line 164）、learnings 注入之前，插入 CONTEXT.md 摘要注入：

```bash
# Inject CONTEXT.md glossary summary (cache-friendly, issue #79)
if [ -f "$PROJECT_ROOT/CONTEXT.md" ]; then
    # Extract ## headings + first line of definition, cap at 20 terms
    context_terms=$(grep -A 1 "^## " "$PROJECT_ROOT/CONTEXT.md" | head -60)
    term_count=$(grep -c "^## " "$PROJECT_ROOT/CONTEXT.md")
    if [ "$term_count" -gt 20 ]; then
        context_terms="${context_terms}\n\n(${term_count} terms total — see CONTEXT.md for full glossary)"
    fi
    static_context="${static_context}\n\n## Domain Glossary\n${context_terms}"
fi
```

**位置决策（cache-friendly，issue #79）:**
- 放**静态段**（与 using-agent-harness、KB pointer 同段），保证 prompt cache 稳定
- learnings 在**动态段**（最后注入），因为 learnings 会变
- 缺 CONTEXT.md → 不注入、不警告（lazy creation）

### 5. Validation 集成（`scripts/lib/handoff-schema.sh`）

Spec frontmatter 加可选字段 `domain_terms`:
```yaml
---
spec_topic: <topic>
decision_summary: "..."
design_approved: true
user_approved_at: <ISO-8601>
gates: [user-review-passed]
domain_terms: [Order, Cancellation, Line Item]   # 新增，可选
---
```

`handoff-schema.sh` 加 advisory 校验（不 block，只 stderr 警告）:
```bash
# domain_terms advisory check (spec stage only)
if [ "$stage" = "spec" ]; then
    local terms; terms=$(yaml_parse_get "domain_terms")
    if [ -n "$terms" ]; then
        local context_md="$ROOT/CONTEXT.md"
        if [ ! -f "$context_md" ]; then
            echo "validate-handoff: WARNING — domain_terms specified but CONTEXT.md not found at root" >&2
        else
            # Parse YAML list [Term1, Term2, Term3]
            for term in $(echo "$terms" | tr -d '[]' | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
                if ! grep -q "^## ${term}$" "$context_md" 2>/dev/null; then
                    echo "validate-handoff: WARNING — domain_term '$term' not found as ## heading in CONTEXT.md" >&2
                fi
            done
        fi
    fi
fi
```

**退出码不变**——advisory 只打 WARNING，不影响 `handoff_check_required` 的返回值。后续可升级为 block。

### 6. harness-init 集成（`skills/harness-init/SKILL.md`）

harness-init 流程末尾追加:
```
1. (existing) detect template, copy sensors.json + hooks config
2. (new) Ask: "Create a domain glossary (CONTEXT.md)? (y/n)"
   - y → create empty CONTEXT.md scaffold:
     ┌─────────────────────────────────┐
     │ # <Project> Domain Glossary     │
     │                                 │
     │ <!-- Domain terms go here.      │
     │      Use /domain-modeling to    │
     │      maintain this file.        │
     │      Glossary only — no impl    │
     │      details.                   │
     │ -->                             │
     └─────────────────────────────────┘
   - create docs/agent-harness/adr/.gitkeep
3. (new) Ask: "Add CONTEXT.md to .gitignore? (y/n)"
   - y → append "CONTEXT.md" to .gitignore
   - 说明: some projects don't commit domain vocab (proprietary terminology)
4. (existing) show recommended skills
```

### 7. brainstorming 集成（`skills/brainstorming/SKILL.md`）

brainstorming 的 "Ask clarifying questions" 环节加 domain-modeling 调用触发点:

- **触发条件**: 术语结晶时（用户定义了一个概念、或 agent 提出精确术语替代模糊用词）
- **动作**: 调用 `domain-modeling` skill 更新 `CONTEXT.md`
- **spec 输出约束**: spec body 使用 `CONTEXT.md` 词汇；frontmatter 加 `domain_terms` 字段列出 spec 引入/依赖的核心术语

brainstorming 的 checklist 第 2 项（"Ask clarifying questions"）追加:
> 当术语结晶时，调用 `agent-harness:domain-modeling` 更新 `CONTEXT.md`（如果存在）或创建它（如果不存在且用户同意）。

## 数据流

```
┌─ Session start ──────────────────────────────────────────────┐
│  session-start hook                                          │
│    1. inject using-agent-harness (static)                    │
│    2. inject CONTEXT.md terms summary (static, NEW)          │
│       └─ if CONTEXT.md missing → skip silently               │
│    3. inject KB pointer (static)                             │
│    4. inject learnings summary (dynamic, throttled)          │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌─ During session ─────────────────────────────────────────────┐
│  brainstorming asks clarifying questions                     │
│    │                                                         │
│    │  term crystallizes (user defines concept /              │
│    │  agent proposes precise term)                           │
│    ▼                                                         │
│  calls domain-modeling skill                                 │
│    ├─ challenge against existing CONTEXT.md terms            │
│    ├─ sharpen fuzzy language → propose canonical term        │
│    ├─ cross-reference with code (does code agree?)           │
│    ├─ update CONTEXT.md inline (immediately, not batched)    │
│    └─ if 3 ADR criteria met → offer ADR creation             │
│       └─ create docs/agent-harness/adr/000N-<topic>.md       │
│                                                              │
│  writing-plans reads CONTEXT.md for vocabulary               │
│    └─ plan tasks use domain terms                            │
│                                                              │
│  requesting-code-review checks diff uses CONTEXT.md terms    │
└──────────────────────────────────────────────────────────────┘
           │
           ▼
┌─ Spec handoff ───────────────────────────────────────────────┐
│  validate-handoff.sh --stage spec                            │
│    1. (existing) check required frontmatter                  │
│    2. (existing) check spec_topic anchors to index.md        │
│    3. (NEW) check domain_terms anchor to CONTEXT.md          │
│       └─ advisory: warn to stderr, don't block               │
│    4. log phase metric (existing)                            │
└──────────────────────────────────────────────────────────────┘
```

## 错误处理

| 场景 | 处理 |
|------|------|
| CONTEXT.md 不存在 | skill 懒创建——第一个术语结晶时创建文件 + scaffold header |
| CONTEXT.md 格式错误（无 `##` heading） | skill 警告，要求用户先修复；不自动重写已有内容 |
| ADR 编号冲突（0001 已存在） | skill 找下一个可用编号；不覆盖 |
| `CONTEXT-MAP.md` 指向不存在的子 context | skill 警告，跳过该子 context，继续处理其他 |
| `domain_terms` 引用 CONTEXT.md 中不存在的 term | validate-handoff 输出 WARNING 到 stderr，**不 block** |
| CONTEXT.md 被 gitignore | 正常工作——hook 读文件系统不依赖 git tracking |
| session-start 读 CONTEXT.md 超过 token 预算 | 截断到前 20 个 term + "(N more in CONTEXT.md)" |
| ADR 目录不存在 | domain-modeling skill 懒创建 `docs/agent-harness/adr/` |
| monorepo 多 context，sub-context CONTEXT.md 缺失 | 跳过该 context，警告 |
| YAML list 解析失败（domain_terms 格式错误） | validate-handoff 跳过校验，打 WARNING |

## 测试策略

### 1. 纯脚本测试（`tests/plugin-infrastructure/`，秒级）

新增 test case 到现有 `run-all.sh`:
- `test-harness-init-creates-context-md` — harness-init 在临时目录创建 CONTEXT.md scaffold + `docs/agent-harness/adr/.gitkeep`
- `test-harness-init-gitignore-option` — harness-init 选 gitignore 时，`.gitignore` 包含 `CONTEXT.md`
- `test-session-start-injects-context-md` — session-start hook 在有 CONTEXT.md 时注入 glossary 摘要；无 CONTEXT.md 时不注入且不报错
- `test-validate-handoff-domain-terms-advisory` — spec 有 `domain_terms` 且 term 在 CONTEXT.md → 无 WARNING；term 不在 → WARNING 但退出码 0
- `test-index-knowledge-base-adr` — `index-knowledge-base.sh` 扫 `spec_topic: adr` 生成 `adr/index.md`

### 2. Skill 行为测试（`tests/skill-behavior/domain-modeling/`，依赖 `claude -p` + API 配额）

`cd tests/skill-behavior/domain-modeling && ./run-test.sh`:
- 给定有 CONTEXT.md 的项目 + 模糊术语，验证 skill 产出精确术语 + 更新 CONTEXT.md
- 给定术语冲突（用户用词与 glossary 矛盾），验证 skill 挑战而非静默接受
- 给定 hard-to-reverse 决策，验证 skill 主动 offer ADR
- 给定 trivial 决策，验证 skill **不** offer ADR（3-criteria 纪律）

### 3. 集成验证（手动 / `tests/explicit-skill-requests/`）

- 在 `demo/fruit-shop` 跑 brainstorming，验证 CONTEXT.md 被更新
- 在 `demo/fruit-shop` 跑 writing-plans，验证 plan 使用 CONTEXT.md 词汇
- 验证 session-start hook 在新会话注入 CONTEXT.md 摘要

### 4. 不受影响的测试套件

- `tests/learnings-scripts/` — learnings 系统独立，无改动
- `tests/knowledge-base-scripts/` — KB 脚本无改动（`index-knowledge-base.sh` 已支持 `spec_topic`）
- `tests/handoff-scripts/` — handoff schema 加可选字段 + advisory，现有测试不受影响

## 多 context 支持（monorepo）

根目录 `CONTEXT-MAP.md` 存在时，repo 有多个 context:
```
/
├── CONTEXT-MAP.md                    # 指向各子 context
├── docs/adr/                         # 系统级 ADR
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md                # 该 context 的 glossary
│   │   └── docs/adr/                 # 该 context 的 ADR
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

`CONTEXT-MAP.md` 格式:
```markdown
# Context Map

- `src/ordering/` — Order intake and fulfillment. See `src/ordering/CONTEXT.md`.
- `src/billing/` — Invoicing and payment. See `src/billing/CONTEXT.md`.
```

skill 行为：优先读 `CONTEXT-MAP.md`，若存在则按当前工作目录定位对应子 context 的 `CONTEXT.md`。session-start hook 只注入根目录 `CONTEXT.md`（若存在），子 context 由 skill 按需读。

## 实现顺序（3 commits，1 PR）

1. **Commit 1: 核心 skill + 格式约定**
   - `skills/domain-modeling/SKILL.md`（新）
   - `docs/agent-harness/adr/` 目录 + `.gitkeep`
   - 本 spec 文档（已在此处）

2. **Commit 2: 基础设施集成**
   - `hooks/session-start`（改：注入 CONTEXT.md 摘要）
   - `skills/harness-init/SKILL.md`（改：创建 scaffold + 问 gitignore）
   - `scripts/lib/handoff-schema.sh`（改：加 domain_terms advisory）

3. **Commit 3: 跨 skill 联动 + 测试**
   - `skills/brainstorming/SKILL.md`（改：澄清环节调用 domain-modeling）
   - `tests/plugin-infrastructure/`（加 5 个 test case）
   - `tests/skill-behavior/domain-modeling/`（新建目录 + run-test.sh）

## 评估计划（PR 必需）

按 CLAUDE.md "Skill 改动需要评估" 要求：

1. **Before/After 对比**：在 `demo/fruit-shop` 跑同一 brainstorming 任务
   - Before：无 CONTEXT.md，agent 每次重新理解 jargon
   - After：有 CONTEXT.md，agent 读取 glossary 后用精确术语

2. **Token 消耗对比**：session-start 注入 CONTEXT.md 摘要 vs 不注入
   - 预期：注入后 agent thinking token 减少（mattpocock 验证过）

3. **术语一致性**：检查 spec/plan 输出是否使用 CONTEXT.md 词汇
   - Before：术语随机（cart/basket/order 混用）
   - After：术语统一（glossary 定义的 canonical term）

4. **ADR 纪律**：验证 skill 只在 3-criteria 满足时 offer ADR
   - 测试用例：trivial 决策不应触发 ADR offer

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| CONTEXT.md 退化为 spec/scratch | SKILL.md 强约束 "glossary and nothing else" + 格式检查 |
| session-start 注入过大（token 超预算） | 截断到前 20 term + pointer |
| domain_terms advisory 被忽略 | 初始 advisory，后续可升级为 block（需社区反馈） |
| brainstorming 改动影响现有流程 | brainstorming 只加调用点，不改 checklist 结构；跑现有 skill-behavior 测试验证 |
| harness-init 交互问题（用户不选） | 默认创建 CONTEXT.md，gitignore 默认否（可后续改） |

## 参考来源

- `mattpocock/skills` `skills/engineering/domain-modeling/SKILL.md` — 主动 glossary 维护纪律
- `mattpocock/skills` `CONTEXT.md` — glossary-only 根目录约定
- `mattpocock/skills` `skills/productivity/writing-great-skills/SKILL.md` — 信息层级 + progressive disclosure
- agent-harness `hooks/session-start` issue #79 — cache-friendly 静态段/动态段分离
- agent-harness `scripts/lib/handoff-schema.sh` — spec_topic 锚定机制

## Gate Driven Development

### ROOT

引入 domain-modeling skill + 根目录 CONTEXT.md glossary + `docs/agent-harness/adr/`，深度集成 session-start hook / harness-init / validate-handoff / brainstorming。核心风险：CONTEXT.md 退化为非 glossary、hook 注入破坏 prompt cache（issue #79 回归）、brainstorming 不调用 domain-modeling 导致 CONTEXT.md 永不填充、validate-handoff 误 block 现有流程、ADR 滥发稀释信号。

### Level Items

#### L4-1

PARENT_ID：ROOT
视角下的需求：新会话启动时，session-start hook 注入 CONTEXT.md glossary 摘要，让 agent 在第一 turn 就能读到项目领域词汇。
Gate Items：

- Gate：`e2e gate`（手动或 `tests/skill-behavior/`：启动新会话，验证 `additionalContext` 包含 `## Domain Glossary` 段）
  Covers：L3-1, L2-4, L2-5
  Assertions：
  1. L4-1-G1-A1：项目根有 CONTEXT.md 时，session-start hook 输出的 `additionalContext` 包含 `## Domain Glossary` 段，内容含至少一个 `## <Term>` heading
  2. L4-1-G1-A2：项目根无 CONTEXT.md 时，`additionalContext` 不含 `## Domain Glossary` 段且 hook 退出码 0

#### L4-2

PARENT_ID：ROOT
视角下的需求：brainstorming 在澄清环节术语结晶时调用 domain-modeling，更新 CONTEXT.md，使 glossary 在设计过程中主动沉淀而非事后补。
Gate Items：

- Gate：`e2e gate`（在 `demo/fruit-shop` 跑 brainstorming，验证 CONTEXT.md 被更新）
  Covers：L2-1
  Assertions：
  1. L4-2-G1-A1：brainstorming 会话结束后，CONTEXT.md 包含会话中讨论的至少一个新 term（`## <Term>` heading + 定义）
  2. L4-2-G1-A2：新 term 条目含 `_Avoid_` 别名行（消除歧义）

#### L4-3

PARENT_ID：ROOT
视角下的需求：harness-init 为新项目创建 CONTEXT.md scaffold + `docs/agent-harness/adr/.gitkeep`，让用户首次运行就有文件骨架。
Gate Items：

- Gate：`smoke gate`（`tests/plugin-infrastructure/`：harness-init 在临时目录完成，不报错）
  Covers：L1-1
  Assertions：
  1. L4-3-G1-A1：harness-init 完成后，项目根存在 `CONTEXT.md` 文件
  2. L4-3-G1-A2：harness-init 完成后，`docs/agent-harness/adr/` 目录存在（含 `.gitkeep`）
  3. L4-3-G1-A3：harness-init 问 gitignore 时选 y，`.gitignore` 包含 `CONTEXT.md` 行

#### L3-1

PARENT_ID：L4-1
视角下的需求：CONTEXT.md 摘要注入必须放在 session-start hook 的静态段（与 using-agent-harness、KB pointer 同段），不能放动态段（learnings 段），否则破坏 prompt cache（issue #79 回归）。
Gate Items：

- Gate：`contract gate`（`tests/plugin-infrastructure/`：检查 session-start 脚本结构，CONTEXT.md 注入代码在 learnings 注入之前）
  Covers：L2-4
  Assertions：
  1. L3-1-G1-A1：session-start 脚本中，CONTEXT.md 读取代码在 learnings 读取代码之前执行
  2. L3-1-G1-A2：CONTEXT.md 注入的输出是 `static_context` 变量的一部分（不是 dynamic/warning 段）

#### L3-2

PARENT_ID：ROOT
视角下的需求：validate-handoff 的 `domain_terms` 校验是 advisory（只 WARNING 到 stderr，退出码 0），不 block 现有 spec 交接流程。
Gate Items：

- Gate：`contract gate`（`tests/handoff-scripts/`：spec 有 domain_terms 但 term 不在 CONTEXT.md，退出码仍为 0）
  Covers：L2-6
  Assertions：
  1. L3-2-G1-A1：spec frontmatter 有 `domain_terms` 且所有 term 在 CONTEXT.md → 无 WARNING，退出码 0
  2. L3-2-G1-A2：spec frontmatter 有 `domain_terms` 但某 term 不在 CONTEXT.md → stderr 有 WARNING，退出码 0
  3. L3-2-G1-A3：spec frontmatter 无 `domain_terms` → 跳过校验，退出码 0

#### L3-3

PARENT_ID：ROOT
视角下的需求：`index-knowledge-base.sh` 自动扫描 `docs/agent-harness/adr/` 下 `spec_topic: adr` 的文件，生成 `adr/index.md`。
Gate Items：

- Gate：`schema gate`（`tests/knowledge-base-scripts/`：放一个 ADR 文件，跑 `index-knowledge-base.sh`，验证 `adr/index.md` 包含该文件）
  Covers：L1-2
  Assertions：
  1. L3-3-G1-A1：`docs/agent-harness/adr/0001-test.md`（frontmatter `spec_topic: adr`）存在时，`index-knowledge-base.sh` 生成 `docs/agent-harness/adr/index.md`
  2. L3-3-G1-A2：`adr/index.md` 包含 `0001-test` 条目

#### L2-1

PARENT_ID：L4-2
视角下的需求：CONTEXT.md 必须是 glossary only——`## <Term>` heading + 定义 + `_Avoid_` 别名，不含实现细节/spec/scratch。
Gate Items：

- Gate：`unit gate`（`tests/skill-behavior/domain-modeling/`：给 skill 一个模糊术语，验证产出的 CONTEXT.md 条目只有 glossary 字段）
  Covers：L1-1
  Assertions：
  1. L2-1-G1-A1：domain-modeling 写入 CONTEXT.md 的每个条目是 `## <Term>` + 一行定义 + `_Avoid_: <aliases>` 格式
  2. L2-1-G1-A2：domain-modeling 不在 CONTEXT.md 写入代码块、实现细节、或 spec 内容

#### L2-2

PARENT_ID：ROOT
视角下的需求：ADR 只在 3 criteria 全满足时 offer（hard to reverse + surprising without context + result of real trade-off），trivial 决策不 offer。
Gate Items：

- Gate：`unit gate`（`tests/skill-behavior/domain-modeling/`：两个场景——trivial 决策 vs hard-to-reverse 决策）
  Covers：
  Assertions：
  1. L2-2-G1-A1：trivial 决策（如"变量命名用 camelCase"）→ skill 不 offer ADR
  2. L2-2-G1-A2：hard-to-reverse + surprising + real-trade-off 决策（如"选 Postgres 而非 DynamoDB"）→ skill 主动 offer ADR

#### L2-3

PARENT_ID：ROOT
视角下的需求：ADR 编号从 0001 起，skill 找下一可用号，不覆盖已有。
Gate Items：

- Gate：`unit gate`（`tests/skill-behavior/domain-modeling/`：已有 0001，验证新 ADR 编号为 0002）
  Covers：
  Assertions：
  1. L2-3-G1-A1：`docs/agent-harness/adr/0001-x.md` 已存在时，skill 创建的新 ADR 编号为 0002
  2. L2-3-G1-A2：skill 不覆盖已有 ADR 文件

#### L2-4

PARENT_ID：L3-1
视角下的需求：CONTEXT.md 超过 20 个 term 时，hook 注入截断到前 20 + 指针，防止 token 超预算。
Gate Items：

- Gate：`unit gate`（`tests/plugin-infrastructure/`：造一个 25 term 的 CONTEXT.md，跑 hook 提取逻辑，验证输出 ≤ 20 term + pointer）
  Covers：
  Assertions：
  1. L2-4-G1-A1：CONTEXT.md 有 25 个 `##` heading 时，hook 注入的 glossary 段含 ≤ 20 个 term
  2. L2-4-G1-A2：glossary 段末尾含指针文案（如 "25 terms total — see CONTEXT.md for full glossary"）

#### L2-5

PARENT_ID：L3-1
视角下的需求：CONTEXT.md 不存在时，hook 不注入、不报错、不创建（lazy creation 由 skill 负责）。
Gate Items：

- Gate：`unit gate`（`tests/plugin-infrastructure/`：无 CONTEXT.md，跑 hook，验证无 glossary 段且退出码 0）
  Covers：
  Assertions：
  1. L2-5-G1-A1：项目根无 CONTEXT.md 时，session-start hook 输出不含 `## Domain Glossary`
  2. L2-5-G1-A2：hook 退出码为 0（不因缺 CONTEXT.md 报错）

#### L2-6

PARENT_ID：L3-2
视角下的需求：`domain_terms` YAML inline flow sequence `[Term1, Term2, Term3]` 能被正确解析为列表并逐个校验。
Gate Items：

- Gate：`unit gate`（`tests/handoff-scripts/`：spec frontmatter `domain_terms: [Order, Cancellation]`，验证两个 term 都被检查）
  Covers：
  Assertions：
  1. L2-6-G1-A1：`domain_terms: [Order, Cancellation]` 时，validate-handoff 检查 "Order" 和 "Cancellation" 两个 term
  2. L2-6-G1-A2：含空格的 term（如 `Line Item`）能被正确解析（不被空格截断）

#### L1-1

PARENT_ID：L2-1
视角下的需求：`skills/domain-modeling/SKILL.md` frontmatter 含 name/description/when_to_use，且无 `disable-model-invocation`（model-invoked）。
Gate Items：

- Gate：`lint gate`（`tests/plugin-infrastructure/`：检查 SKILL.md frontmatter）
  Covers：
  Assertions：
  1. L1-1-G1-A1：`skills/domain-modeling/SKILL.md` frontmatter 含 `name: domain-modeling`
  2. L1-1-G1-A2：frontmatter 含 `description` 字段（非空，≤ 500 字符）
  3. L1-1-G1-A3：frontmatter 含 `when_to_use` 字段
  4. L1-1-G1-A4：frontmatter 不含 `disable-model-invocation: true`（保持 model-invoked）

#### L1-2

PARENT_ID：L3-3
视角下的需求：ADR 文件 frontmatter 含 `spec_topic: adr`，让 `index-knowledge-base.sh` 能扫到。
Gate Items：

- Gate：`schema gate`（`tests/knowledge-base-scripts/`：ADR 文件 frontmatter 校验）
  Covers：
  Assertions：
  1. L1-2-G1-A1：`docs/agent-harness/adr/*.md` 的 frontmatter 含 `spec_topic: adr`
