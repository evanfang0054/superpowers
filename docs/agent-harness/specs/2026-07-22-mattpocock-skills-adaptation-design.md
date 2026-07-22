---
spec_topic: mattpocock-skills-adaptation
decision_summary: "将 mattpocock/skills 中经调研验证的四类实践适配进 agent-harness 现有执行与质量 skill：seam-first TDD、双轴 code review、tracer-bullet planning、skill prompt 可预测性规则"
design_approved: true
user_approved_at: "2026-07-22T00:00:00+08:00"
gates: [user-review-passed]
---

# Matt Pocock Skills 适配优化设计 Spec

## 背景

本次调研对象是 `mattpocock/skills` 仓库及其相关 skill 内容。调研显示，该仓库中有多项实践可借鉴，但 agent-harness 已经拥有更完整的三层工作流、handoff validation、phase metrics、sprint contract、GDD/SDD 和 knowledge-base 基础设施。因此本设计不照搬外部 workflow，也不新增大批兼容 skill，而是把最适合的实践收敛为四个 P1 增强，嵌入现有 skill。

第一版只覆盖四项：

1. `test-driven-development`：引入 seam-first TDD，减少测试耦合实现细节。
2. `requesting-code-review`：引入 Standards / Spec 双轴审查，避免质量审查和需求符合性互相掩盖。
3. `writing-plans`：引入 tracer-bullet vertical slices 与 blocking edges，让计划更适配 subagent-driven-development。
4. `writing-skills`：引入 predictability、context load、progressive disclosure、no-op pruning 等 skill 写作准则。

已排除第一版范围：新增 Wayfinder、architecture report、research skill、批量新增第三方兼容 skill。它们可作为后续 P2/P3，但不进入本 spec。

## 设计目标

- 保持 agent-harness 既有流程不变：`brainstorming → sprint-contract → writing-plans → SDD/TDD/review/verification`。
- 不新增第三方依赖，不引入项目特定配置。
- 所有增强都应是局部 skill 文案与行为契约优化。
- 每项改动必须可通过静态契约检查或 headless 行为测试验证。
- 避免重写已调优 skill，只针对外部调研发现的明确差距做最小增强。

## 非目标

- 不把 mattpocock/skills 整仓复制进 agent-harness。
- 不改变 skill 加载机制、plugin manifest、hooks 架构。
- 不新增独立 `wayfinder` 或 `research` skill。
- 不把 brainstorming 已完成的 frontier batching / recommended answers / facts-vs-decisions 优化重复实现一遍。
- 不修改 demo 项目。

## 优化 A：TDD 增加 seam-first 契约

### 改动文件

- `skills/test-driven-development/SKILL.md`
- 行为测试建议新增或扩展：`tests/skill-behavior/test-driven-development/`

### 当前问题

现有 TDD skill 已强制 Red-Green-Refactor，并明确禁止没有失败测试就写生产代码。但它较少约束“测试应该打在哪个边界”。在复杂系统里，agent 可能虽然先写测试，但测试过度绑定实现细节，导致：

- 重构时测试脆弱。
- 测试验证 private/internal behavior，而不是 public behavior。
- SDD 子代理按任务写测试时，各自选择 seam，造成覆盖边界不一致。

### 适配设计

在 `test-driven-development` 的 Red 阶段前加入 seam-first 规则：

```markdown
**Choose the seam before writing tests:**
- A seam is a public or agreed boundary where behavior can be observed: CLI command, HTTP endpoint, exported function, component prop contract, script output, or persisted file change.
- Before writing the first failing test, identify the seam under test.
- Prefer existing public seams. Do not create test-only public APIs.
- Test behavior through the seam, not private helpers or implementation details.
- If the task plan already names the seam, use it. If no seam is obvious, stop and clarify the smallest observable boundary before writing tests.
```

与现有硬规则的关系：

- “NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST” 保留。
- seam selection 发生在写 failing test 之前。
- 不要求每个微小任务都询问用户；如果 `writing-plans` 已在 task 中声明 seam，TDD skill 直接使用。

### 测试策略

新增 headless 行为测试场景：

1. 给定一个任务要求修改 private helper，期望 agent 先寻找现有 public seam，而不是直接测试 private helper。
2. 给定 plan 中已声明 seam，期望 agent 使用该 seam 写 RED 测试。
3. 给定没有可见 seam 的任务，期望 agent 停止并要求明确 observable boundary，而不是创建 test-only API。

静态检查：

- `skills/test-driven-development/SKILL.md` 包含 `Choose the seam before writing tests`。
- 包含 `Do not create test-only public APIs`。
- 原有 `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST` 仍存在。

## 优化 B：Code Review 改为 Standards / Spec 双轴审查

### 改动文件

- `skills/requesting-code-review/SKILL.md`
- `agents/code-reviewer.md` 或现有 code-reviewer 子代理提示（以仓库实际文件为准）
- 行为测试建议新增或扩展：`tests/skill-behavior/requesting-code-review/`

### 当前问题

当前 `requesting-code-review` 已要求完成重大步骤后调用 reviewer，并按 Critical / Important / Minor 处理反馈。但单一 reviewer 容易把两类问题混在一起：

- Standards：是否符合仓库规则、代码质量、安全性、可维护性。
- Spec：是否忠实实现了 spec / plan / DoD。

混在一起的风险是：代码质量看起来可以，但漏了需求；或需求实现完整，但引入风格/安全/架构问题。

### 适配设计

将 review contract 明确为两轴：

```markdown
**Review on two axes:**
1. Standards axis — Does the change follow repository rules, security expectations, existing patterns, and maintainability standards?
2. Spec axis — Does the change faithfully implement the originating spec, plan task, and Definition of Done?

Do not let one axis hide the other. A clean implementation that misses the spec is still a failed review. A spec-complete implementation with critical quality or security issues is still a failed review.
```

执行方式第一版保持简单：

- 默认仍使用现有 `agent-harness:code-reviewer` 单子代理。
- 子代理输出必须分为 `Standards findings` 与 `Spec findings` 两节。
- 只有当 future SDD/orchestrator 明确支持并行多 reviewer 时，再拆成两个 subagent；第一版不增加编排复杂度。

### 严重级别规则

保留现有 Critical / Important / Minor，并映射到双轴：

- Critical：安全漏洞、数据丢失、破坏 spec 核心需求、测试无法运行。
- Important：明显偏离 repo pattern、漏掉 DoD 项、缺少计划要求的测试。
- Minor：命名、局部可读性、小范围风格建议。

### 测试策略

新增 headless 行为测试场景：

1. 用户说“feature complete，请 review”，期望 assistant 调用 reviewer，并要求 Standards / Spec 两节。
2. 给定代码质量正常但漏掉 spec 要求，期望 review 把它标为 Spec finding，而不是通过。
3. 给定实现满足 spec 但存在安全/维护性问题，期望 review 把它标为 Standards finding。

静态检查：

- `skills/requesting-code-review/SKILL.md` 包含 `Standards axis` 与 `Spec axis`。
- reviewer prompt 包含两节输出要求。
- 原有 Critical / Important / Minor 处理规则仍存在。

## 优化 C：Writing Plans 增加 tracer-bullet vertical slices 与 blocking edges

### 改动文件

- `skills/writing-plans/SKILL.md`
- 可能扩展 handoff schema 或 fixture（如 plan validation 已有 task 字段，优先不改 schema）
- 行为测试建议新增或扩展：`tests/skill-behavior/writing-plans/`

### 当前问题

当前 `writing-plans` 已有 spec handoff、GDD gate、sprint contract、task granularity、RED/GREEN/VERIFY。它适合把已批准 spec 转为任务，但还可以更明确地避免两种计划失败：

- horizontal slice：先改 schema，再改 API，再改 UI，导致中间长期不可验证。
- implicit dependency：任务之间依赖关系没有显式写出，SDD 子代理容易乱序执行。

### 适配设计

在 task decomposition 规则中加入：

```markdown
**Prefer tracer-bullet vertical slices:**
- Each slice should cut a narrow but complete path through the layers needed to prove one user-visible behavior.
- Prefer tasks that end in a runnable verification point.
- Avoid horizontal-only plans where all schema work, all API work, and all UI work are separated unless the spec is explicitly a broad refactor.

**Declare blocking edges:**
- If task B cannot start before task A completes, write that dependency explicitly.
- If tasks are independent, say so and allow parallel subagents.
- For wide refactors, use expand-contract: introduce the new path, migrate callers, then remove the old path after verification.
```

计划格式第一版不强制改 frontmatter schema。建议在每个 task 内增加可读字段：

```markdown
### Task N: <title>

Blocking: none | Task X
Slice type: tracer-bullet | refactor | verification
Seam: <observable boundary for TDD>
Files: ...
RED: ...
GREEN: ...
VERIFY: ...
```

这也为 TDD seam-first 提供输入：`Seam` 字段可被 `test-driven-development` 直接使用。

### 宽重构规则

当 spec 是跨多文件重构，允许非 vertical slice，但必须声明为 `Slice type: refactor`，并使用 expand-contract：

1. Expand：引入新路径或新边界，保持旧路径可用。
2. Migrate：迁移调用方并验证行为不变。
3. Contract：删除旧路径和过时测试。

### 测试策略

新增 headless 行为测试场景：

1. 给定一个 full-stack feature，期望 plan 输出按 vertical slice 拆分，而不是 schema/API/UI 三个水平阶段。
2. 给定任务之间存在依赖，期望 plan 显式写 `Blocking`。
3. 给定宽重构，期望 plan 使用 expand-contract，而不是伪装成 feature slice。
4. 给定需要 TDD 的任务，期望每个实现任务写出 `Seam`。

静态检查：

- `skills/writing-plans/SKILL.md` 包含 `tracer-bullet vertical slices`。
- 包含 `Declare blocking edges`。
- 包含 `expand-contract`。
- 原有 spec frontmatter、GDD、sprint contract、validation 规则仍存在。

## 优化 D：Writing Skills 增加可预测性与 prompt 负载规则

### 改动文件

- `skills/writing-skills/SKILL.md`
- 可选辅助资料：若已有 writing-skills reference 文件，优先编辑现有文件；第一版不新增长篇资料文件。
- 行为测试建议新增或扩展：`tests/skill-behavior/writing-skills/`

### 当前问题

当前 `writing-skills` 已经把 skill 开发映射为 TDD，并强调 baseline failure、pressure scenarios、description 是触发条件。但还可以吸收 mattpocock/skills 对 skill 本质的几条更清晰规则：

- skill 的目标是提高 stochastic agent 的 predictable behavior。
- model-invoked skill 有 context load 成本。
- user-invoked skill 有 cognitive load 成本。
- 长 prompt 应 progressive disclosure，避免一次性加载低频细节。
- 删除 no-op 指令，比如“be thoughtful”“be flexible”“consider best practices”。
- 用 leading words / concrete triggers 增加行为稳定性。

### 适配设计

在 `writing-skills` 的编辑准则中加入：

```markdown
**Optimize for predictability, not prose quality:**
A skill is successful when it makes agent behavior more predictable under pressure scenarios. Beautiful wording that does not change behavior is noise.

**Budget both kinds of load:**
- Model-invoked skills spend context automatically. Keep trigger descriptions precise and the loaded prompt small.
- User-invoked skills spend user attention. Make names discoverable and behavior obvious.

**Use progressive disclosure:**
Keep always-loaded instructions short. Move rare examples, long references, and edge-case matrices into auxiliary files when they are only needed after a specific branch is chosen.

**Prune no-ops:**
Delete instructions that do not constrain behavior: “be thoughtful”, “use best practices”, “consider trade-offs”, “be flexible”. Replace them with observable actions and stop conditions.

**Use leading words for stable behavior:**
Prefer repeated explicit labels such as MUST, STOP, RED, GREEN, VERIFY, HARD-GATE, and Critical when the skill needs deterministic behavior.
```

### 与现有规则关系

- 保留 TDD for skills：RED baseline → GREEN minimal prompt change → REFACTOR pressure test。
- 保留 description = trigger condition。
- 新增规则只补充“如何写得更可预测、更低负载”，不替代现有流程。

### 测试策略

新增或扩展行为测试：

1. 给定一个冗长 skill 草稿，期望 assistant 删除 no-op 文案，而不是润色成更长。
2. 给定 model-invoked skill description 写成 workflow 描述，期望 assistant 改成触发条件。
3. 给定少见 edge-case 内容，期望 assistant建议移到辅助文件，而不是塞进 always-loaded prompt。
4. 给定没有 baseline failure 的 skill 优化请求，期望 assistant拒绝直接改已调优 skill，并要求压力场景证据。

静态检查：

- `skills/writing-skills/SKILL.md` 包含 `Optimize for predictability`。
- 包含 `progressive disclosure`。
- 包含 `Prune no-ops`。
- 原有 RED/GREEN/REFACTOR 和 description 规则仍存在。

## 交互与流程影响

### 对 brainstorming 的影响

无直接修改。`brainstorming` 已经吸收 frontier batching、recommended answers、facts-vs-decisions、domain-modeling 触发，本 spec 不重复改它。

### 对 sprint-contract 的影响

无直接修改。DoD 仍由 sprint-contract 产生，并在 writing-plans 与 code-review 的 Spec axis 中使用。

### 对 SDD 的影响

间接增强：

- `writing-plans` 输出 `Blocking` 与 `Seam` 后，SDD orchestrator 更容易安全地并行或顺序派发任务。
- `requesting-code-review` 双轴输出可作为 SDD task reviewer 后续增强的基础。

第一版不修改 SDD 编排，避免扩大范围。

## 实施文件清单

必须修改：

1. `skills/test-driven-development/SKILL.md`
   - 增加 seam-first TDD 规则。
   - 保留现有 TDD 硬门禁。

2. `skills/requesting-code-review/SKILL.md`
   - 增加 Standards / Spec 双轴审查契约。
   - 明确 Critical / Important / Minor 同时适用于两轴。

3. `agents/code-reviewer.md` 或等效 reviewer prompt 文件
   - 增加输出格式：`Standards findings`、`Spec findings`、`Verdict`。
   - 要求 review spec/plan/DoD coverage。

4. `skills/writing-plans/SKILL.md`
   - 增加 tracer-bullet vertical slice 规则。
   - 增加 `Blocking`、`Slice type`、`Seam` task 字段建议。
   - 增加 wide refactor 的 expand-contract 规则。

5. `skills/writing-skills/SKILL.md`
   - 增加 predictability / load budget / progressive disclosure / no-op pruning / leading words 规则。

建议新增或扩展测试：

1. `tests/skill-behavior/test-driven-development/`
2. `tests/skill-behavior/requesting-code-review/`
3. `tests/skill-behavior/writing-plans/`
4. `tests/skill-behavior/writing-skills/`

不应修改：

- `skills/brainstorming/SKILL.md`
- `skills/domain-modeling/SKILL.md`
- `scripts/auto-loop.sh`
- plugin manifest / hook 配置
- demo 项目

## Gate Driven Development

### ROOT

本设计将 mattpocock/skills 中适合 agent-harness 的四类实践适配进现有执行和质量 skill：TDD 先声明 observable seam，code review 按 Standards / Spec 双轴审查，writing-plans 输出 tracer-bullet vertical slices 与 blocking edges，writing-skills 以 predictability 和 prompt load 为核心优化准则。

### Level Items

#### L4-1

PARENT_ID：ROOT  
视角下的需求：开发任务经过 writing-plans 和 TDD 时，应先明确可观察 seam，并优先按可验证 vertical slice 推进。

Gate Items：

- Gate：`e2e gate`
  Covers：从 spec 到 plan 再到 TDD 的行为链路能避免实现细节测试和水平切片计划。
  Assertions：
  1. `writing-plans` 为实现任务输出 `Seam` 字段或等价 seam 描述。
  2. `writing-plans` 对 feature work 优先拆成 tracer-bullet vertical slices。
  3. `test-driven-development` 在写失败测试前识别 seam，并避免测试 private helper。

#### L3-1

PARENT_ID：L4-1  
视角下的需求：TDD skill 必须明确 seam-first 规则，且不能削弱现有 test-first 硬门禁。

Gate Items：

- Gate：`contract gate`
  Covers：`skills/test-driven-development/SKILL.md` 的 TDD 契约。
  Assertions：
  1. 文案要求写测试前选择 seam。
  2. 文案定义 seam 为 public 或 agreed observable boundary。
  3. 文案禁止创建 test-only public APIs。
  4. 原有 failing-test-first 硬规则仍存在。

#### L3-2

PARENT_ID：L4-1  
视角下的需求：writing-plans 必须显式表达 vertical slice、blocking edges 和 seam，便于后续 SDD/TDD 执行。

Gate Items：

- Gate：`contract gate`
  Covers：`skills/writing-plans/SKILL.md` 的任务拆分契约。
  Assertions：
  1. 文案要求 feature work 优先 tracer-bullet vertical slices。
  2. 文案要求任务依赖用 blocking edges 显式声明。
  3. 文案为 TDD 任务提供 seam 字段或等价 seam 描述。
  4. 宽重构使用 expand-contract，而不是伪装成普通 feature slice。

#### L4-2

PARENT_ID：ROOT  
视角下的需求：完成实现后的 review 必须同时覆盖 repo standards 和 spec fidelity。

Gate Items：

- Gate：`e2e gate`
  Covers：`requesting-code-review` 到 reviewer 输出的用户可见行为。
  Assertions：
  1. review 请求要求检查 Standards axis。
  2. review 请求要求检查 Spec axis。
  3. reviewer 输出中质量问题和需求偏离分开呈现。
  4. 任一轴存在 Critical finding 时 review 不应通过。

#### L3-3

PARENT_ID：L4-2  
视角下的需求：code-reviewer prompt 必须输出双轴 findings，并保留严重级别分类。

Gate Items：

- Gate：`contract gate`
  Covers：reviewer 子代理输出契约。
  Assertions：
  1. 输出包含 `Standards findings`。
  2. 输出包含 `Spec findings`。
  3. 输出包含 `Verdict` 或等价结论。
  4. Critical / Important / Minor 语义仍可用于排序修复。

#### L4-3

PARENT_ID：ROOT  
视角下的需求：skill 作者优化 prompt 时，应以行为可预测性和上下文负载为目标，而不是泛化润色。

Gate Items：

- Gate：`e2e gate`
  Covers：`writing-skills` 对 skill 草稿优化的行为。
  Assertions：
  1. 面对 no-op 指令，assistant 删除或替换为可观察动作。
  2. 面对过长 always-loaded prompt，assistant 建议 progressive disclosure。
  3. 面对 model-invoked description 写成 workflow，assistant 改成触发条件。
  4. 没有 baseline failure 时，assistant 不应直接重写已调优 skill。

#### L3-4

PARENT_ID：L4-3  
视角下的需求：`writing-skills` 文案必须明确 predictability、load budget、progressive disclosure 和 no-op pruning。

Gate Items：

- Gate：`contract gate`
  Covers：`skills/writing-skills/SKILL.md` 的 skill 写作准则。
  Assertions：
  1. 文案声明 skill 成功标准是提高 pressure scenario 下的可预测行为。
  2. 文案区分 model-invoked context load 和 user-invoked cognitive load。
  3. 文案要求长尾细节使用 progressive disclosure。
  4. 文案要求删除 no-op 指令。

#### L2-1

PARENT_ID：ROOT  
视角下的需求：第一版适配必须保持范围受控，不引入外部仓库整体复制或新依赖。

Gate Items：

- Gate：`lint gate`
  Covers：范围控制。
  Assertions：
  1. 不新增第三方依赖。
  2. 不新增 mattpocock/skills 的整仓镜像。
  3. 不修改 plugin hooks 或 release 配置。
  4. 不修改 demo 项目。

## 验证计划

### 结构验证

写入 spec 后运行：

```bash
scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-07-22-mattpocock-skills-adaptation-design.md
```

通过后再进入 self-review。

### Skill 加载验证

若后续实现修改 skill，至少运行：

```bash
cd tests/claude-code && ./run-skill-tests.sh
```

### 行为验证

针对四个修改 skill，优先运行对应行为测试：

```bash
cd tests/skill-behavior/test-driven-development && ./run-test.sh
cd tests/skill-behavior/requesting-code-review && ./run-test.sh
cd tests/skill-behavior/writing-plans && ./run-test.sh
cd tests/skill-behavior/writing-skills && ./run-test.sh
```

如果某目录尚不存在，实施计划应先新增最小行为测试 harness，或明确复用现有测试目录。

### 回归验证

若实现只改 skill 文案与 reviewer prompt，不应需要全量脚本测试。若同时改到 test harness 或 validation schema，再运行相关脚本套件。

## 风险与缓解

### 风险：过度照搬外部 skill

缓解：第一版只增强现有四个 skill，不新增外部仓库镜像，不改工作流主干。

### 风险：prompt 变长抵消收益

缓解：每个 skill 只新增契约级规则，避免长篇解释；必要示例进入测试 fixture，而不是 always-loaded prompt。

### 风险：双轴 review 增加执行复杂度

缓解：第一版不拆两个 subagent，只要求现有 reviewer 输出分轴结果。

### 风险：vertical slice 不适合所有任务

缓解：允许 `Slice type: refactor` 与 expand-contract；文案写“Prefer”，不是绝对禁止非 vertical slice。

### 风险：seam-first 造成额外澄清轮次

缓解：优先使用 `writing-plans` 中的 `Seam` 字段；只有没有 observable boundary 时才停下来澄清。

## 后续可选 P2/P3

- P2：评估是否新增 Wayfinder 风格的大型模糊任务导航 skill。
- P2：把 SDD task reviewer 拆成 Standards reviewer 与 Spec reviewer 并行执行。
- P3：研究 `research` skill 的 primary-source 报告模式是否适合 agent-harness knowledge-base。
- P3：评估 architecture report / deep module scan 是否应作为独立质量层 skill。
