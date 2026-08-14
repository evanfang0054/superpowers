# GDD Generation Prompt（内部执行指令）

> 译化自 `gdd-spec-prompt.md`。本文件是 gate-driven-test-design skill 的执行主体。
> Gate 能力字典见 `references/gate-capability-table.md`，不要在本文件重复。

## 引用关系

- 原 prompt：仓库根目录 `gdd-spec-prompt.md`（保留作历史参考）
- 本文件：将其结构化为 skill 内部指令，删除 Inputs/Purpose 段（已被 SKILL.md 的 Entry Contract 覆盖）

## Level Item Rules

- Keep the design portion as the authority.
- Level Items may originate at any level reflected by the spec. Do not force the
  first extracted item to be L4.
- Every Level Item must be traceable to the design spec or to project gate facts
  required by that design.
- Create a Level Item only when it catches an important failure. Good candidates
  protect core user value, data correctness, permissions, public contracts,
  cross-module collaboration, explicit out-of-scope boundaries, complex rules,
  or likely regressions introduced by the change.
- A child Level Item must explain a lower-level requirement that helps prove its
  parent. Do not create children that merely restate the parent.
- Do not create Level Items for routine project checks that do not catch a
  feature-specific failure.
- Do not invent behavior, states, fields, commands, fixtures, or release
  requirements that are absent from the approved design or project facts.
- If a useful Level Item depends on a missing design decision, stop and report a
  blocking question instead of guessing.

## Coverage Ownership Rules

Use these rules to keep the generated GDD compatible with the level model above
without duplicating the same proof at several test layers:

- For each business rule or user-visible behavior, identify the cheapest gate
  that can own the detailed oracle. Higher-level gates may prove that the real
  path reaches a representative outcome, but should not repeat the lower-level
  branch matrix, exact field matrix, or detailed error-code matrix.
- Multiple gates may cover the same business point only when each gate proves a
  different failure mode. For example, an e2e gate proves the real user path and
  visible recovery, an integration gate proves boundary collaboration, and a unit
  gate proves deterministic branch classification.
- Treat an assertion as redundant when another assertion for the same feature
  uses the same input class, action, and expected oracle at a cheaper gate. Keep
  the cheaper assertion and rewrite the higher-level assertion as a path-level
  smoke or representative flow when that flow still adds value.
- Do not add lower-level assertions merely to make the shape look like a pyramid.
  Add them only when they catch a distinct implementation, boundary, or rule
  failure.
- Implementation-implied failure modes are allowed only when they follow from an
  explicit design dependency or project gate fact, such as database writes,
  network calls, external services, concurrency, time, storage, generated
  contracts, or background workers. Keep these at the lowest useful level and do
  not invent new product behavior; if the externally visible behavior is
  undecided, block on a design question.

## Process

### 1. Read Source Material

1. Read the approved design spec.
2. Identify the design summary, goals, non-goals, architecture decisions,
   contracts, data shapes, behavior rules, errors, rollout constraints, and any
   user-confirmed decisions supplied with this prompt.
3. Read project gate facts relevant to the feature. Use project-specific gates
   when they exist; otherwise use the generic Gate names above.

### 2. Extract Initial Level Items

Extract initial Level Items directly from the approved spec. Choose only
risk-significant requirements whose failure would affect user value, data
correctness, permissions, public contracts, cross-module collaboration, explicit
scope boundaries, complex rules, or likely regressions. Classify each selected
requirement at its closest abstraction level:

- L4: visible behavior, user paths, runtime health, release-facing or
  operator-visible outcomes.
- L3: API/module/service/storage/config/migration collaboration and public
  boundary contracts.
- L2: rules, states, branches, errors, edge cases, permissions, invariants, and
  deterministic behavior.
- L1: feature-specific static constraints proven by type-check, lint, build,
  schema, or similar static gates, where the assertion names the concrete risk
  constraint being protected.

For each initial item, internally record:

- Level
- Short title
- Requirement statement
- Source section or design fact
- Why this level fits
- The important failure this Level Item catches
- Likely parent, if the spec already implies one

Initial Level Items can be siblings at different levels. Do not create gates yet.

### 3. Recursively Expand Child Level Items

For each initial Level Item, recursively ask:

> What lower-level requirement must hold for this item to be true?

Also ask:

> What important failure would this child catch?

If the answer is unclear, do not create the child.

Expand downward only:

- L4 items may produce L3, L2, or L1 descendants.
- L3 items may produce L2 or L1 descendants.
- L2 items may produce L1 descendants.
- L1 items do not produce lower-level children.

Expansion rules:

1. Prefer one-level-at-a-time expansion when a meaningful intermediate level
   exists.
2. Skip a level only when the spec makes the intermediate level unnecessary.
3. Stop expanding when a child would repeat an existing item, invent design, or
   provide no independent proof value.
4. When multiple parents could own a child, attach it to the parent whose
   contract it most directly proves. If truly shared, keep one Level Item and
   mention the other coverage in `Covers` under its Gate Item instead of
   duplicating the item.
5. If expansion exposes a missing design decision, stop and return the blocking
   output. Do not write a partial GDD section.

### 4. Consolidate Level Item Tree

Before writing gates, normalize the generated tree:

- Assign stable IDs in level order: `L4-1`, `L4-2`, `L3-1`, and so on.
- Set `PARENT_ID` to `ROOT` or the nearest higher-level item that the child
  helps prove.
- Merge obvious duplicates before generating assertions.
- Remove items that only restate another item without adding a distinct
  requirement or proof perspective.
- Preserve enough structure for downstream planning; do not collapse distinct
  contracts merely because they affect the same file.

### 5. Generate Gate Items And Assertions

For each Level Item:

1. Select Gate items whose abstraction level matches the Level Item.
2. Use project-specific gate names and commands when project facts provide them;
   otherwise use the generic Gate names.
3. Write ordered `Assertions` under each Gate item.
4. Assertions should state what the gate proves, not how to implement the
   feature.
5. Keep assertion order stable after review.

### 6. Audit Assertion Ownership

After generating Gate items and Assertions, run a cross-layer ownership audit
before updating the spec:

- Group assertions by business rule or risk point.
- Within each group, compare input class, action, expected oracle, gate cost, and
  failure mode.
- Merge or rewrite assertions that prove the same oracle at multiple gates.
- Slim L4/e2e assertions that enumerate detailed error codes, wording, boundary
  values, field matrices, sorting rules, pagination rules, or role matrices
  unless the approved design makes that exact visible matrix the core user value
  or a high-risk release boundary.
- Check whether explicit implementation dependencies introduce important L2/L3
  failure modes that the design did not spell out, such as timeout, failed
  persistence, late response, stale cache, concurrent update, null/missing
  relation, or external-service failure. Add the lowest-level assertion that
  proves the technical risk only when the behavior follows from existing design
  or project facts; otherwise block on a design question.
- Do not write a separate audit report into the GDD section. Use this pass only
  to improve the Level Items, Gate Items, and Assertions.

### 7. Review And Merge Redundant Level Items

Before updating the spec, run an internal review pass:

- Source alignment: every Level Item and assertion traces to the design portion
  or project facts.
- Coverage: every risk-significant design requirement has enough assertion
  coverage.
- Level fit: each Level Item and Gate item matches the L4/L3/L2/L1 perspective.
- No scope creep: no new behavior, fields, states, gates, or edge cases are
  invented.
- Redundancy: merge Level Items that express the same requirement, collapse
  parent/child pairs where the child merely repeats the parent, and remove
  siblings that have no independent proof value.
- Cross-layer ownership: no two assertions at different gates prove the same
  input/action/oracle unless their distinct failure modes are explicit.
- E2E economy: L4/e2e assertions stay representative and user-path focused; any
  detailed matrix at L4 is justified by core user value, safety, permissions,
  data leakage, or release-risk concerns.
- Value filter: remove assertions that are merely more exhaustive but do not
  catch a distinct important failure.

After merging, update parent IDs and assertion structure so ids remain
parseable. Then write or update the GDD section.

## Output Format

```markdown
## Gate Driven Development

### ROOT

<One-paragraph summary of the approved design portion.>

### Level Items

#### L4-1

PARENT_ID：ROOT
视角下的需求：...
Gate Items：

- Gate：`e2e gate`
  Covers：...
  Assertions：
  1. ...
  2. ...

#### L3-1

PARENT_ID：L4-1
视角下的需求：...
Gate Items：

- Gate：`contract gate`
  Covers：...
  Assertions：
  1. ...
```

## Assertion Rules

- Do not create a separate `Assertion Index`.
- Assertions must be ordered lists under `Assertions：`.
- An assertion id is derived from structure:
  `<LevelItemID>-G<GateItemOrder>-A<AssertionOrder>`. Example: the first
  assertion in the second Gate item under `L3-1` is `L3-1-G2-A1`.
- Keep assertion order stable after review; reordering changes structural ids.
- Every assertion must be specific enough for downstream planning to map it to
  one or more verification steps.
- Assertions should state what the gate proves, not how to implement the
  feature.
- Assertions must name the feature-specific constraint being proven; a gate
  command passing is not enough by itself.
- A missing assertion is blocking only when the omitted behavior is central to
  user value, data correctness, permissions, public contract stability,
  cross-module collaboration, explicit scope boundaries, complex rules, or a
  likely regression introduced by the change.
- Do not include "Does not prove" sections.
- Do not add requirements beyond the design portion. If a useful assertion
  depends on an unstated decision, report a blocking question instead.

## Blocking Output

If generation cannot continue because the design portion lacks a necessary
decision, do not write a partial GDD section. Return:

```text
gdd_result: blocked
blocking_questions:
- <question that must be resolved in the design portion>
why_it_blocks_assertions:
- <which Level Item/Gate/assertion cannot be written without this decision>
```

## Self-Review（写入 spec 前自检）

对照 brainstorming 的 Spec Self-Review 模式，写入 `## Gate Driven Development` 段前，用以下五问自检：

1. 每个 Level Item 能否追溯到 design spec 的具体段或项目 Gate 事实？追溯不到 → 删除。
2. 是否有 Level Item 只是在复述父项、无独立证明价值？是 → 删除。
3. 同一业务点是否有多个 Gate 证明同一 oracle？是 → 保留最便宜的，其余下沉或合并。
4. L4 e2e 是否在穷举错误码/字段矩阵？是 → 下沉到 L2/L3，L4 只留代表路径。
5. 有没有凭空发明的行为/字段/状态？有 → 删除或 block 提问。

任一项不通过，修复后再写入，不写半成品。
