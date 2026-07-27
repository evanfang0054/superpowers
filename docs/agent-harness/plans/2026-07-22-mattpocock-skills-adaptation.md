---
spec_ref: ../specs/2026-07-22-mattpocock-skills-adaptation-design.md
spec_topic: mattpocock-skills-adaptation
status: active
task_count: 6
estimated_phases: [tests, implementation, verification]
dod: "四个现有 skill/reviewer 契约以最小文案改动吸收 seam-first TDD、Standards/Spec 双轴 review、tracer-bullet planning、writing-skills predictability/load 规则；不新增依赖、不复制外部仓库、不修改 hooks/release/demo；运行 skill 加载测试与相关 behavior tests 或记录真实失败原因。"
---

# Matt Pocock Skills Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已批准 spec 中四项 P1 借鉴点以局部、可验证的方式嵌入现有 agent-harness skills 与 reviewer prompt。

**Architecture:** 本次只修改 Markdown 行为契约与既有 headless behavior tests，不改 skill 加载机制、hooks、release 配置、依赖或 demo。每个实现任务是一条可独立验证的 contract slice：先补/扩行为测试，再做最小 prompt 文案改动，再运行对应测试。

**Tech Stack:** Markdown skills, shell-based headless tests under `tests/skill-behavior/`, Claude Code skill loading tests under `tests/claude-code/`.

---

## File Structure

- Modify: `skills/test-driven-development/SKILL.md` — 加入 seam-first RED 前置契约，保留 failing-test-first 硬门禁。
- Modify: `skills/requesting-code-review/SKILL.md` — 加入 Standards axis / Spec axis 双轴 review 要求。
- Modify: `agents/code-reviewer.md` — 调整 reviewer 输出契约为 `Standards findings`、`Spec findings`、`Verdict`。
- Modify: `skills/writing-plans/SKILL.md` — 加入 tracer-bullet vertical slices、blocking edges、`Seam` 字段、expand-contract 规则。
- Modify: `skills/writing-skills/SKILL.md` — 加入 predictability、load budget、progressive disclosure、no-op pruning、leading words 准则。
- Modify: `tests/skill-behavior/test-driven-development/prompts/naive-tdd.txt` or sibling prompt fixtures — 覆盖 seam-first 行为。
- Modify: `tests/skill-behavior/requesting-code-review/prompts/naive-request-review.txt` or sibling prompt fixtures — 覆盖双轴 review 请求。
- Modify: `tests/skill-behavior/writing-plans/prompts/naive-break-into-tasks.txt` or sibling prompt fixtures — 覆盖 vertical slice / blocking / seam plan 输出。
- Modify: `tests/skill-behavior/writing-skills/prompts/naive-create-skill.txt` or sibling prompt fixtures — 覆盖 predictability / prompt load 行为。

## Commit Strategy

用户选择手动提交。各任务不包含 commit step；完成全部验证后再由用户或执行者手动提交。

---

### Task 1: Add seam-first TDD contract

Blocking: none  
Slice type: tracer-bullet  
Seam: `tests/skill-behavior/test-driven-development/run-test.sh` observing `skills/test-driven-development/SKILL.md` behavior through headless skill output.

**Files:**
- Modify: `tests/skill-behavior/test-driven-development/prompts/naive-tdd.txt`
- Modify: `tests/skill-behavior/test-driven-development/run-test.sh`
- Modify: `skills/test-driven-development/SKILL.md`

- [ ] **Step 1: Write the failing behavior prompt**

Update or add a prompt case under `tests/skill-behavior/test-driven-development/prompts/` that asks for a TDD implementation where the tempting target is a private helper, but an observable boundary exists:

```text
I need to change a private helper used by a CLI command. Use TDD to implement the behavior. Before writing tests, identify the observable seam you will test through, and do not create a test-only public API.
```

- [ ] **Step 2: Add assertions that should fail before the skill change**

In `tests/skill-behavior/test-driven-development/run-test.sh`, add assertions for the new prompt output:

```bash
assert_contains "$OUTPUT" "seam"
assert_contains "$OUTPUT" "observable"
assert_contains "$OUTPUT" "Do not create test-only public APIs"
assert_not_contains "$OUTPUT" "test the private helper directly"
```

If the existing helper functions use different variable names or assertion signatures, keep the same local style but assert those exact concepts.

- [ ] **Step 3: Run the TDD behavior test and verify RED**

Run:

```bash
cd tests/skill-behavior/test-driven-development && ./run-test.sh
```

Expected: FAIL because the current skill does not consistently require selecting an observable seam before the first failing test.

- [ ] **Step 4: Add seam-first wording to the RED section**

In `skills/test-driven-development/SKILL.md`, insert this block before the current RED test-writing requirements, without removing `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`:

```markdown
**Choose the seam before writing tests:**
- A seam is a public or agreed boundary where behavior can be observed: CLI command, HTTP endpoint, exported function, component prop contract, script output, or persisted file change.
- Before writing the first failing test, identify the seam under test.
- Prefer existing public seams. Do not create test-only public APIs.
- Test behavior through the seam, not private helpers or implementation details.
- If the task plan already names the seam, use it. If no seam is obvious, stop and clarify the smallest observable boundary before writing tests.
```

- [ ] **Step 5: Update the verification checklist**

Add checklist items near the existing test-first checklist:

```markdown
- [ ] Identified the observable seam before writing the first failing test
- [ ] Tested behavior through a public or agreed boundary, not private helpers
- [ ] Did not create test-only public APIs
```

- [ ] **Step 6: Run test to verify GREEN**

Run:

```bash
cd tests/skill-behavior/test-driven-development && ./run-test.sh
```

Expected: PASS, or fail only for a real environment/API quota reason that must be recorded in the final verification notes.

---

### Task 2: Add Standards / Spec review contract

Blocking: none  
Slice type: tracer-bullet  
Seam: `tests/skill-behavior/requesting-code-review/run-test.sh` observing review-request behavior and `agents/code-reviewer.md` output contract.

**Files:**
- Modify: `tests/skill-behavior/requesting-code-review/prompts/naive-request-review.txt`
- Modify: `tests/skill-behavior/requesting-code-review/run-test.sh`
- Modify: `skills/requesting-code-review/SKILL.md`
- Modify: `agents/code-reviewer.md`

- [ ] **Step 1: Write the failing review prompt**

Update or add a prompt case under `tests/skill-behavior/requesting-code-review/prompts/`:

```text
The feature implementation is complete. Request a code review against the plan and repository standards. The review must separately check whether the code follows standards and whether it satisfies the spec.
```

- [ ] **Step 2: Add assertions for two-axis review**

In `tests/skill-behavior/requesting-code-review/run-test.sh`, add assertions matching the local test helper style:

```bash
assert_contains "$OUTPUT" "Standards axis"
assert_contains "$OUTPUT" "Spec axis"
assert_contains "$OUTPUT" "Critical"
assert_contains "$OUTPUT" "Important"
assert_contains "$OUTPUT" "Minor"
```

- [ ] **Step 3: Run the requesting-code-review behavior test and verify RED**

Run:

```bash
cd tests/skill-behavior/requesting-code-review && ./run-test.sh
```

Expected: FAIL because current review instructions do not require explicit Standards / Spec axes.

- [ ] **Step 4: Add two-axis contract to requesting-code-review**

In `skills/requesting-code-review/SKILL.md`, add this section near the existing review request requirements:

```markdown
## Review on Two Axes

Every review request must ask the reviewer to check both axes:

1. **Standards axis** — Does the change follow repository rules, security expectations, existing patterns, and maintainability standards?
2. **Spec axis** — Does the change faithfully implement the originating spec, plan task, and Definition of Done?

Do not let one axis hide the other. A clean implementation that misses the spec is still a failed review. A spec-complete implementation with Critical quality or security issues is still a failed review.
```

- [ ] **Step 5: Preserve severity handling and apply it to both axes**

Replace or extend the current feedback priority wording with:

```markdown
- Fix Critical issues immediately on either axis
- Fix Important issues before proceeding on either axis
- Note Minor issues for later
- Push back if reviewer is wrong, with reasoning tied to the relevant axis
```

- [ ] **Step 6: Update code-reviewer output contract**

In `agents/code-reviewer.md`, update the review output instructions so every review includes this structure:

```markdown
## Output Format

Return the review in this structure:

### Standards findings
- Critical / Important / Minor findings about repository rules, security expectations, existing patterns, maintainability, and code quality.
- Write `None` if there are no findings on this axis.

### Spec findings
- Critical / Important / Minor findings about fidelity to the originating spec, implementation plan, task requirements, and Definition of Done.
- Write `None` if there are no findings on this axis.

### Verdict
- `PASS` only when neither axis has Critical findings and the implementation satisfies the required spec/plan scope.
- `FAIL` when either axis has a Critical finding or the implementation misses core spec requirements.
```

Also normalize `Suggestions` to `Minor` if the prompt currently lists `Critical (must fix), Important (should fix), or Suggestions (nice to have)`.

- [ ] **Step 7: Run test to verify GREEN**

Run:

```bash
cd tests/skill-behavior/requesting-code-review && ./run-test.sh
```

Expected: PASS, or fail only for a real environment/API quota reason that must be recorded.

---

### Task 3: Add tracer-bullet planning and blocking edges

Blocking: none  
Slice type: tracer-bullet  
Seam: `tests/skill-behavior/writing-plans/run-test.sh` observing generated plan structure through the skill prompt.

**Files:**
- Modify: `tests/skill-behavior/writing-plans/prompts/naive-break-into-tasks.txt`
- Modify: `tests/skill-behavior/writing-plans/run-test.sh`
- Modify: `skills/writing-plans/SKILL.md`

- [ ] **Step 1: Write the failing planning prompt**

Update or add a prompt case under `tests/skill-behavior/writing-plans/prompts/`:

```text
Write an implementation plan for a small full-stack feature with a data model, API endpoint, and user-visible CLI or UI behavior. Prefer vertical slices, explicitly declare task dependencies, and include the observable seam for TDD tasks.
```

- [ ] **Step 2: Add assertions for slice structure**

In `tests/skill-behavior/writing-plans/run-test.sh`, add assertions matching existing helper style:

```bash
assert_contains "$OUTPUT" "tracer-bullet"
assert_contains "$OUTPUT" "Blocking"
assert_contains "$OUTPUT" "Slice type"
assert_contains "$OUTPUT" "Seam"
assert_contains "$OUTPUT" "expand-contract"
```

- [ ] **Step 3: Run the writing-plans behavior test and verify RED**

Run:

```bash
cd tests/skill-behavior/writing-plans && ./run-test.sh
```

Expected: FAIL because current plan instructions do not require these fields and refactor path rules.

- [ ] **Step 4: Add vertical slice rules to writing-plans**

In `skills/writing-plans/SKILL.md`, add this section near task decomposition / bite-sized task rules:

```markdown
## Tracer-Bullet Task Decomposition

**Prefer tracer-bullet vertical slices:**
- Each slice should cut a narrow but complete path through the layers needed to prove one user-visible behavior.
- Prefer tasks that end in a runnable verification point.
- Avoid horizontal-only plans where all schema work, all API work, and all UI work are separated unless the spec is explicitly a broad refactor.

**Declare blocking edges:**
- If task B cannot start before task A completes, write that dependency explicitly.
- If tasks are independent, say so and allow parallel subagents.
- For wide refactors, use expand-contract: introduce the new path, migrate callers, then remove the old path after verification.
```

- [ ] **Step 5: Extend the task template with dependency and seam fields**

Update the task template in `skills/writing-plans/SKILL.md` so every task starts with:

```markdown
Blocking: none | Task X
Slice type: tracer-bullet | refactor | verification
Seam: <observable boundary for TDD, or none for non-TDD verification tasks>
```

Keep the existing `Files`, RED, GREEN, VERIFY, exact command, and no-placeholder rules.

- [ ] **Step 6: Add wide-refactor guardrail**

Add this rule near scope or task decomposition guidance:

```markdown
For broad refactors, do not pretend the work is a normal feature slice. Mark tasks as `Slice type: refactor` and use expand-contract: Expand the new path, Migrate callers with verification, then Contract by removing the old path after behavior is proven unchanged.
```

- [ ] **Step 7: Run test to verify GREEN**

Run:

```bash
cd tests/skill-behavior/writing-plans && ./run-test.sh
```

Expected: PASS, or fail only for a real environment/API quota reason that must be recorded.

---

### Task 4: Add writing-skills predictability and load rules

Blocking: none  
Slice type: tracer-bullet  
Seam: `tests/skill-behavior/writing-skills/run-test.sh` observing skill-writing advice under pressure-scenario prompts.

**Files:**
- Modify: `tests/skill-behavior/writing-skills/prompts/naive-create-skill.txt`
- Modify: `tests/skill-behavior/writing-skills/run-test.sh`
- Modify: `skills/writing-skills/SKILL.md`

- [ ] **Step 1: Write the failing writing-skills prompt**

Update or add a prompt case under `tests/skill-behavior/writing-skills/prompts/`:

```text
Improve this skill draft. It has lots of vague wording like “be thoughtful”, “use best practices”, and “consider trade-offs”, plus rare edge-case examples in the always-loaded SKILL.md. Optimize it for predictable behavior under pressure scenarios, not nicer prose.
```

- [ ] **Step 2: Add assertions for prompt-quality behavior**

In `tests/skill-behavior/writing-skills/run-test.sh`, add assertions matching the local helper style:

```bash
assert_contains "$OUTPUT" "predictability"
assert_contains "$OUTPUT" "pressure"
assert_contains "$OUTPUT" "progressive disclosure"
assert_contains "$OUTPUT" "no-op"
assert_contains "$OUTPUT" "model-invoked"
assert_contains "$OUTPUT" "user-invoked"
assert_contains "$OUTPUT" "leading words"
```

- [ ] **Step 3: Run the writing-skills behavior test and verify RED**

Run:

```bash
cd tests/skill-behavior/writing-skills && ./run-test.sh
```

Expected: FAIL because current skill does not explicitly require these optimization targets.

- [ ] **Step 4: Add predictability and load-budget rules**

In `skills/writing-skills/SKILL.md`, add this section near the existing skill TDD and token efficiency guidance:

```markdown
## Optimize for Predictable Behavior

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

- [ ] **Step 5: Preserve existing skill TDD hard gate**

Confirm this line still exists after editing:

```markdown
NO SKILL WITHOUT A FAILING TEST FIRST
```

Do not weaken the existing RED baseline → GREEN minimal prompt change → REFACTOR pressure test flow.

- [ ] **Step 6: Run test to verify GREEN**

Run:

```bash
cd tests/skill-behavior/writing-skills && ./run-test.sh
```

Expected: PASS, or fail only for a real environment/API quota reason that must be recorded.

---

### Task 5: Run contract and scope validation

Blocking: Task 1, Task 2, Task 3, Task 4  
Slice type: verification  
Seam: repository diff and shell validation output.

**Files:**
- Verify: `skills/test-driven-development/SKILL.md`
- Verify: `skills/requesting-code-review/SKILL.md`
- Verify: `agents/code-reviewer.md`
- Verify: `skills/writing-plans/SKILL.md`
- Verify: `skills/writing-skills/SKILL.md`
- Verify: `tests/skill-behavior/*/run-test.sh`

- [ ] **Step 1: Check required contract strings**

Run targeted searches or inspect the edited files to confirm these strings exist:

```text
Choose the seam before writing tests
Do not create test-only public APIs
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
Standards axis
Spec axis
Standards findings
Spec findings
Verdict
tracer-bullet vertical slices
Declare blocking edges
Seam
expand-contract
Optimize for predictability
progressive disclosure
Prune no-ops
leading words
NO SKILL WITHOUT A FAILING TEST FIRST
```

Expected: every string is present in the appropriate file, with existing hard gates preserved.

- [ ] **Step 2: Check out-of-scope files stayed untouched**

Inspect the diff and confirm there are no changes under these paths:

```text
skills/brainstorming/SKILL.md
skills/domain-modeling/SKILL.md
scripts/auto-loop.sh
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
hooks/
demo/
package.json
pnpm-lock.yaml
```

Expected: no out-of-scope changes. If any appear, revert only those unrelated edits before continuing.

- [ ] **Step 3: Run skill loading validation**

Run:

```bash
cd tests/claude-code && ./run-skill-tests.sh
```

Expected: PASS. If it fails due to environment/API quota, record the exact stderr/stdout reason; do not claim success.

- [ ] **Step 4: Run modified skill behavior tests**

Run:

```bash
cd tests/skill-behavior/test-driven-development && ./run-test.sh
cd tests/skill-behavior/requesting-code-review && ./run-test.sh
cd tests/skill-behavior/writing-plans && ./run-test.sh
cd tests/skill-behavior/writing-skills && ./run-test.sh
```

Expected: PASS for all four, or documented environment/API quota failures with exact reason.

---

### Task 6: Final two-axis review and handoff

Blocking: Task 5  
Slice type: verification  
Seam: `agent-harness:code-reviewer` review output and final diff.

**Files:**
- Review: all changed files from Tasks 1-5

- [ ] **Step 1: Request code review**

Invoke the code-reviewer after implementation and validation. The request must include:

```text
Review this implementation against docs/agent-harness/specs/2026-07-22-mattpocock-skills-adaptation-design.md and docs/agent-harness/contracts/mattpocock-skills-adaptation.contract.md.

Standards axis: check repository rules, security expectations, existing patterns, maintainability, test quality, and scope control.

Spec axis: check whether the four P1 enhancements are implemented and whether all DoD items are satisfied.

Return Standards findings, Spec findings, and Verdict. Any Critical finding on either axis means FAIL.
```

- [ ] **Step 2: Fix Critical and Important findings**

For each reviewer finding:

```text
Critical: fix immediately before final handoff.
Important: fix before final handoff unless explicitly rejected with evidence.
Minor: note for later unless it blocks the contract.
```

- [ ] **Step 3: Prepare final verification notes**

Record:

```markdown
## Verification
- `cd tests/claude-code && ./run-skill-tests.sh`: PASS | FAIL with exact reason
- `cd tests/skill-behavior/test-driven-development && ./run-test.sh`: PASS | FAIL with exact reason
- `cd tests/skill-behavior/requesting-code-review && ./run-test.sh`: PASS | FAIL with exact reason
- `cd tests/skill-behavior/writing-plans && ./run-test.sh`: PASS | FAIL with exact reason
- `cd tests/skill-behavior/writing-skills && ./run-test.sh`: PASS | FAIL with exact reason

## Scope
- No third-party dependencies added.
- No mattpocock/skills repository copy added.
- No plugin hooks, release config, or demo project changes.
```

- [ ] **Step 4: Manual commit reminder**

Because the user selected manual commits, do not auto-commit. Tell the user the implementation is ready for their review and manual commit after they inspect the final diff.

---

## Final Commit Reminder

Manual commit strategy selected. After all tasks pass and the user reviews the final diff, commit only the relevant files for this implementation and the plan/status metadata changes intentionally made during planning.
