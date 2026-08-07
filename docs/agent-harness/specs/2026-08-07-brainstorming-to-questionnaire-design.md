---
spec_topic: brainstorming-to-questionnaire
decision_summary: "在 brainstorming 内嵌 to-questionnaire escape hatch(frontier 阻塞时产出问卷交第三方),并加 frontier 未空不得进方案的硬规则"
design_approved: true
user_approved_at: "2026-08-07T00:00:00+08:00"
gates: [user-review-passed]
---

# Brainstorming 吸收 grilling + to-questionnaire 优化设计 Spec

## 背景

本次优化参考 mattpocock/skills 的 `grilling` 与 `to-questionnaire` 两个 skill,目标是补强 agent-harness `skills/brainstorming/SKILL.md` 的两类能力缺口。

前置 spec:
- `brainstorming-optimization`(2026-07-21)已实施 frontier batching、推荐答案、facts/decisions 分离、决策树映射
- `mattpocock-skills-adaptation`(2026-07-22)已实施 TDD/Review/Plans/Skills 四项,明确排除 brainstorming 改动

本次延续上述工作,聚焦三点尚未吸收的能力:A. frontier 终止硬规则;B. to-questionnaire escape hatch(全新能力);C. 格式对齐 grilling。

## 设计目标

- 在 `skills/brainstorming/SKILL.md` 内部增量补强,不新增 skill、不动 plugin manifest、不动 hooks、不动 release 配置、不扩展 handoff schema。
- 不破坏现有 Assumption Audit / Circuit-Breaker / Six Forcing Questions / domain-modeling 触发。
- 每个改动可通过静态文案检查或 headless 行为测试验证。
- PR 给 2-3 个对抗场景的前后对比作为评估证据。

## 非目标

- 不新增 `skills/to-questionnaire/` 独立 skill(留作 P2,等 brainstorming 内嵌版有使用证据再考虑)。
- 不新增 `/to-questionnaire` slash command(agent 自动触发即可)。
- 不扩展 `validate-handoff.sh` schema(问卷文档不是 spec/plan/contract/notes gate)。
- 不改 frontier round 主线编号风格(`1. 2. 3.` + 推荐答案)。
- 不改 Assumption Audit / Circuit-Breaker / Six Forcing Questions。
- 不修改 demo 项目。

## 设计决策(来自 brainstorming 对话)

| # | 决策 | 选项 | 理由 |
|---|------|------|------|
| Q1 | 优化对象 | `skills/brainstorming/SKILL.md` | 用户明确指定 |
| Q2 | 优化方向 | A + B + C(以 B 最痛) | A 已部分实施,B 是真正的能力缺口 |
| Q3 | PR 导向 | 要提 PR,给 2-3 个对抗场景证据 | CLAUDE.md 要求评估证据 |
| Q4 | 问卷文档位置 | `docs/agent-harness/handoffs/to-<recipient>-<slug>.md` | 与现有目录约定一致 |
| Q5 | 触发方式 | 仅用户明确表示答不了时 | 防止滥触发 |
| Q6 | 接收人元数据 | 当场问两件事(角色 + 需要拿回什么) | 对齐 mattpocock 三步流程 |
| Q7 | ❓/➡️ 格式 | 仅问卷分支内部使用 | 不冲突破现有 frontier round 测试 |
| Q8 | A 的落地 | 硬规则:frontier 未空不得进入方案阶段 | 可静态校验,有 forcing function |

## 改动清单

### 改动 1 — frontier 终止硬规则(方向 A)

**位置**:`skills/brainstorming/SKILL.md` 第 97-98 行 `Relentless termination` 段末尾。

**新增文案**(接在现有 "the grilling discipline is to keep asking..." 之后):

```markdown
**Hard rule:** If the frontier is not empty, you MUST NOT proceed to Propose approaches or Present design. "I think I have enough" is not a substitute for an empty frontier.
```

**理由**:把 grilling 的 "session is done when the frontier is empty" 固化成可静态校验的硬门禁。允许现有 "ruled out as out-of-scope" 机制把问题踢出 frontier(等于已答)。

### 改动 2 — 新增 "When the user cannot answer" 小节(方向 B)

**位置**:插入在第 107 行 `Fact-checking rules` 段之后、`Exploring approaches` 段(第 109 行)之前。

**新小节全文**:

```markdown
**When the user cannot answer a frontier question (to-questionnaire escape hatch):**

A frontier question may require knowledge the user doesn't hold (domain SME, customer insight, product decision owned elsewhere). When the user clearly signals they cannot answer — "I need to ask X", "I'm not sure", "this depends on what the team decides" — do NOT guess, do NOT drop the question, and do NOT force the user to invent an answer. Instead, turn the unanswerable question into a questionnaire for whoever holds the knowledge.

**Grill the send, not the subject.** Interview the user only about what they can always answer — who the questionnaire goes to, and what the user needs back. Then write a Markdown questionnaire that targets the gap.

1. **Who is it going to?** Ask, in one exchange, the recipient's role, expertise, and relationship to the user. This fixes tone and how much context the document must carry. Done when you know who the recipient is and what they know that the user doesn't.
2. **What do you need back?** Ask, in one exchange, the specific decisions or facts the user can't resolve alone and needs from this person. Done when you have a concrete list of what the user must walk away able to do or decide.
3. **Write the questionnaire.** Draft questions aimed at the gap from steps 1–2, using the format below. Write it to `docs/agent-harness/handoffs/to-<recipient>-<slug>.md` where `<recipient>` is the recipient's role or team (e.g. `to-pm-`, `to-finance-`, `to-sre-`), not a personal name, and `<slug>` is kebab-cased from the topic. Create the directory if missing. Report the path to the user. Done when the file exists and every item the user named in step 2 is covered by a question.

**Question format inside the questionnaire** (use these exact markers so the recipient can scan):

​```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <what the user needs from the recipient to decide>
​```

**Pause, don't abandon.** The frontier node that triggered the questionnaire stays paused until the user returns with answers. Other unblocked frontier nodes may proceed in parallel. When the user comes back, recompute the frontier with the new answers.

**Document skeleton** (adapt to context):

​```markdown
# Questionnaire: <topic>

**Purpose:** why this questionnaire exists and the decision riding on it.
**From:** <the user> — **To:** <recipient role> — **How answers will be used:** <where they go>
**Deadline / effort:** <if known>

## Context
One paragraph orienting a recipient who wasn't in the user's head.

## <Theme heading>
### ❓ Q1 - **<title>**: <body>
➡️ <what's needed>

## Anything else?
A closing catch-all.
​```

**Do NOT trigger this branch speculatively.** Only when the user has clearly said they can't answer. If you're unsure whether the user can answer, ask them directly ("can you answer this, or should we turn it into a questionnaire for someone else?") rather than assuming either way.
```

**理由**:
- "Grill the send, not the subject" + 三步流程直接来自 mattpocock to-questionnaire 原文,落地到 agent-harness 目录约定(`docs/agent-harness/handoffs/`)。
- `❓/➡️` 来自 grilling,只在问卷文档内部使用,不冲突破 frontier round 主线编号风格。
- "Pause, don't abandon" 让问卷分支与现有 frontier rounds 机制无缝衔接。
- "Do NOT trigger this branch speculatively" 是防止滥触发的关键指令(对应 Q5 决策)。

### 改动 3 — 注册 handoffs/ 目录到知识库索引

**位置**:`docs/agent-harness/index.md` 第 8-12 行 "子目录入口" 列表。

**新增一行**:

```markdown
- [handoffs/](handoffs/)       — to-questionnaire 问卷等交接给外部接收人的中间产物
```

**理由**:目录约定要求所有 `docs/agent-harness/` 子目录在 index.md 注册。问卷文档不是 gate,不进入阶段 metric。

### 改动 4 — 占位文件保证目录可被 git 跟踪

**新增**:`docs/agent-harness/handoffs/.gitkeep` 或 `README.md`,简述该目录用途。

**理由**:空目录不被 git 跟踪,需要占位文件。

### 不改动的清单(明确范围边界)

- `validate-handoff.sh`、`handoff-schema.sh` — 问卷文档不进 spec/plan/contract/notes gate
- `commands/` — 不新增 slash command
- `tests/skill-behavior/brainstorming/run-test.sh` 现有断言 — frontier round 编号风格不变
- Assumption Audit / Circuit-Breaker / Six Forcing Questions 文案 — 全部保留
- plugin manifest / hooks / release 配置
- demo 项目

## 交互与流程影响

### 与 Circuit-Breaker 的关系

互补不冲突:
- **Circuit-Breaker**(第 216-241 行)管"用户拒绝选项(连续 3 次明确说不行)"→ 切换策略,停止列选项,改问 outcome question
- **to-questionnaire escape hatch**(改动 2)管"用户答不了问题(明确表示需要问别人/不确定)"→ 产出问卷交第三方

两者触发条件互斥,文案明确分隔。

### 与 Assumption Audit 的关系

Assumption Audit 仍在 `Propose approaches` 之前执行。改动 1 的硬规则要求 frontier 必须先空才能进入 Assumption Audit,所以两者顺序不变,只是 frontier 终止更严格。

### 与 frontier rounds 主线的关系

问卷分支不替代 frontier round,只处理"答不了"的子集。其余决策问题仍走编号 + 推荐答案的标准 frontier round。

## 评估场景(给 PR 用)

### 场景 1 — frontier 硬规则触发(方向 A)

**输入**(模拟用户):
> "我在做一个 todo CLI 工具,用 Node.js 写。先帮我设计一下,不用问太多,直接给方案。"

**改前**:agent 可能在 1-2 轮后跳到 Propose approaches。
**改后**:agent 持续推 frontier 直到空,或用户对每个未问问题明确说"暂不考虑"。

**断言**:
1. agent 输出包含 "frontier" 或等价表达
2. 用户明确结束每个未决问题前,agent 不输出 "Propose approaches" / "我推荐方案" 字样

### 场景 2 — 问卷分支触发(方向 B)

**输入**(模拟多轮,headless 不支持则改单轮 + mock 用户已表态):
> User: "我在做一个支付回调系统,需要对接第三方支付通道。"
> (assistant frontier round)
> User: "这个手续费率要问财务那边,我也不确定。"

**改前**:agent 可能强行让用户"先假设一个值",或直接 skip。
**改后**:agent 触发 "When the user cannot answer" 分支,当场问两件事,写 `docs/agent-harness/handoffs/to-finance-<slug>.md`,报告路径,frontier 该节点暂停。

**断言**:
1. agent 输出包含 "questionnaire" 或 "问卷"
2. `docs/agent-harness/handoffs/` 下创建 `.md` 文件,文件名形如 `to-<recipient>-<slug>.md`
3. 文件内容包含 `From:`、`To:`、`❓`、`➡️` 标记
4. agent 明确说明 frontier 该节点暂停

### 场景 3 — 不滥触发(防滥用例)

**输入**:
> "我在做一个全栈博客平台,前端 Next.js,后端 Node.js,数据库 Postgres。用户认证我想了几个方案,JWT 还是 Session 你帮我判断。"

**改前 + 改后**:agent 正常跑 frontier round,**不**触发问卷分支。

**断言**:
1. agent 输出包含 frontier round(编号问题 + 推荐答案)
2. agent **不**创建 `docs/agent-harness/handoffs/` 下任何文件
3. agent **不**输出 "questionnaire" / "问卷"

## 测试落地

新增 fixture:`tests/skill-behavior/brainstorming/prompts/` 下新增 3 个 `.txt`:
- `frontier-hard-rule.txt`(场景 1)
- `to-questionnaire-trigger.txt`(场景 2)
- `no-speculative-trigger.txt`(场景 3)

`run-test.sh` 扩展断言矩阵,按上述断言检查。

**评估流程**:
1. 改 skill 前先跑 → baseline
2. 改 skill 后再跑 → after
3. PR 描述贴前后对比

## 实施顺序

1. 新增 3 个测试 fixture(baseline)
2. 跑改前测试,记录输出
3. 改 SKILL.md 改动 1
4. 改 SKILL.md 改动 2
5. 改 docs/agent-harness/index.md(改动 3)
6. 新增 docs/agent-harness/handoffs/.gitkeep(改动 4)
7. 跑改后测试,记录对比
8. 写 PR 描述,贴前后对比

## 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| Circuit-Breaker 与问卷分支语义冲突 | 中 | 触发条件互斥(拒绝 vs 答不了),文案明确分隔 |
| frontier 硬规则过严导致小改动也要拷问 | 中 | 保留 "ruled out as out-of-scope" 机制,允许把问题踢出 frontier |
| 新增 handoffs/ 破坏 index.md | 低 | 改动 3 同步注册 |
| 问卷文档被误纳入 validate-handoff.sh | 低 | schema 只校验白名单 stage,不校验目录 |
| PR 评估证据不足 | 中 | 三场景贴前后对比,严格按 PR 模板填 |
| CLAUDE.md "一个 PR 一个问题" 规则 | 中 | PR 主题统一为"brainstorming 增加 to-questionnaire escape hatch + frontier 硬规则 + 格式对齐",内聚 |
| 场景 2 多轮对话 headless 不支持 | 低 | 改单轮 prompt 里 mock 用户已表态"答不了" |

## 回归验证

**必跑**:
- `cd tests/skill-behavior/brainstorming && ./run-test.sh` — 3 新场景 + 现有 4 场景全过
- `cd tests/claude-code && ./run-skill-tests.sh` — skill 加载测试

**可选**:若改动意外影响其他 skill 加载,跑 `cd tests/plugin-infrastructure && ./run-all.sh`。

**不需要**:其他 skill 行为测试(本次只改 brainstorming);explicit-skill-requests / skill-triggering(不改 description 字段)。

## DoD(Definition of Done)

- [ ] SKILL.md 三处改动落地,frontmatter 未破
- [ ] `docs/agent-harness/index.md` 注册了 handoffs/
- [ ] `docs/agent-harness/handoffs/` 目录存在(含占位文件)
- [ ] `tests/skill-behavior/brainstorming/` 3 个新场景通过
- [ ] `tests/claude-code/run-skill-tests.sh` 加载测试通过
- [ ] PR 描述贴 2-3 个场景的前后对比
- [ ] PR 引用前置 spec `brainstorming-optimization` 与 `mattpocock-skills-adaptation`,说明本次为延续

## 后续可选 P2/P3

- **P2**:若 brainstorming 内嵌版使用后发现 `to-questionnaire` 在 office-hours、writing-plans 等场景也有用,拆独立 skill `skills/to-questionnaire/`,`disable-model-invocation: true`,brainstorming 显式调用。
- **P3**:把问卷文档纳入 handoff schema 校验(若 PR review 发现需要)。
