---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
when_to_use: "[feedforward] Triggered after brainstorming, before implementation, to decompose work into tasks."
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Save plans to:** `docs/agent-harness/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)
- **Before saving:** Check if the target directory is gitignored (`git check-ignore <dir>`). If so, inform the user and suggest `.agent-harness/plans/` as an alternative, but respect the user's choice.

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

**大型任务分段:** If the task is full-stack, spans multiple apps, includes backend + frontend + AI, or will likely exceed 8 implementation tasks, do not create one monolithic plan. First output a directory-level execution map and 默认拆成多个 plan (for example: infrastructure / backend / frontend / design-polish). Each plan must have its own confirmation gate and testable outcome.

**单会话承载上限 (issue #81):** A single session should carry at most **2 active plans** concurrently. To check the current count before starting a new plan:
1. Count files in `docs/agent-harness/plans/*.md` (or wherever the project stores plans).
2. For each file, check frontmatter `status:` — if missing, treat as `active`.
3. If 2+ plans are already `active` (or `status` is absent), do not start a third.

If a third plan is about to start while two are still in flight, stop and recommend one of:
1. Finish or shelve one of the active plans before starting the new one
2. Start a fresh session for the new plan
3. Run `agent-harness:retrospective` to close the current session cleanly

**Escape hatch:** If multiple plans have hard dependencies (infrastructure + feature on top of it, backend + frontend contract work), stacking is legitimate. Note the dependency chain in the new plan's frontmatter (`depends_on: <plan-file>`) so the next plan-creation step knows not to count this as independent stacking.

Rationale: hack project sessions stacking 4 plans in one session triggered 8 compacts and ~96KB of accumulated summary text. Each compact forces re-establishing context, inflating input tokens. See loop-detection's semantic-loop section for the cross-reference.

**GDD gate:** Before writing implementation tasks, check whether the spec has a GDD / gate-driven-test-design artifact when the work carries non-trivial behavior, contract, or regression risk. If missing, stop and tell the user to generate GDD first (or explicitly skip GDD). Do not silently proceed into implementation tasks.

**Design sync:** If a design doc, prototype, or `harness-design` artifact exists, the plan must include explicit 设计同步点. Name the design token / interaction constraints, where they land in code, and which task verifies them. Do not let design intent live only in prose.

## Sprint Contract Verification

Before defining tasks, check for sprint contract:

1. Look for `docs/agent-harness/contracts/{feature-name}.contract.md`
2. If exists: read and align plan tasks with Definition of Done
3. If missing: prompt user to run `agent-harness:sprint-contract` first
   - User can skip with explicit "skip contract" — proceed without contract
   - Default: assume contract exists from prior brainstorming phase

**If contract exists:** Plan tasks must trace to contract acceptance criteria.

## File Structure

**知识库检索约定**：开始前先读 `docs/agent-harness/index.md`，再按主题跳到子目录 index.md，禁止 `**/*.md` 全局通配。

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate. When drawing task boundaries: fold setup, configuration, scaffolding, and documentation steps into the task whose deliverable needs them; split only where a reviewer could meaningfully reject one task while approving its neighbor. Each task ends with an independently testable deliverable.

## Tracer-Bullet Task Decomposition

**Prefer tracer-bullet vertical slices:**
- Each slice should cut a narrow but complete path through the layers needed to prove one user-visible behavior.
- Prefer tasks that end in a runnable verification point.
- Avoid horizontal-only plans where all schema work, all API work, and all UI work are separated unless the spec is explicitly a broad refactor.

**Declare blocking edges:**
- If task B cannot start before task A completes, write that dependency explicitly.
- If tasks are independent, say so and allow parallel subagents.
- For wide refactors, use expand-contract: introduce the new path, migrate callers, then remove the old path after verification.

For broad refactors, do not pretend the work is a normal feature slice. Mark tasks as `Slice type: refactor` and use expand-contract: Expand the new path, Migrate callers with verification, then Contract by removing the old path after behavior is proven unchanged.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this frontmatter, followed by this header:**

```markdown
---
spec_ref: ../specs/<spec-file>.md
spec_topic: <topic-from-docs-agent-harness-index>
task_count: <number>
estimated_phases: [tests, implementation, verification]
dod: "<definition of done from sprint contract>"
---

# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Commit Strategy

Before generating tasks, determine the commit strategy:

- **Ask the user:** "Should each task include a commit step, or do you prefer to commit manually at the end?"
- **Default to manual-commit** if the user has previously expressed this preference (check session-learnings or project CLAUDE.md)
- If auto-commit: include "Step N: Commit" in each task as shown in the Task Structure below
- If manual-commit: omit commit steps from all tasks; add a single "Final commit" reminder at the end of the plan

## Task Structure

````markdown
### Task N: [Component Name]

Blocking: none | Task X
Slice type: tracer-bullet | refactor | verification
Seam: <observable boundary for TDD, or none for non-TDD verification tasks>

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter and return types]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Scope Scan

After defining the task list, check whether any task involves a **global pattern replacement** (token rename, CSS class migration, API signature change, import path shift). If it does, run a project-wide search (Grep) for the pattern before finalizing the plan. List every affected file in the relevant task — do not assume the brainstorming-confirmed file list is exhaustive. A cleanup task that discovers 13 affected files when the plan listed 8 is a plan failure, not a win for the cleanup task.

## API Type Verification

When the plan references API types (interfaces, request/response types, DTOs), verify each referenced field exists before finalizing the plan:

1. **Check type definitions**: open the actual type definition files (e.g., `data-contracts.ts`, `*.d.ts`, auto-generated API types) and confirm every field name and type mentioned in the plan matches
2. **Check imports**: verify that named exports exist in the specified source files — do not assume re-exports
3. **Record findings**: if a type mismatch is found, correct the plan before presenting it to the user

This prevents plan execution interruptions from type errors discovered during implementation.

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**结构前置校验（硬门禁）**：plan 落盘后、进入 self-review 之前，必须跑：
```bash
scripts/validate-handoff.sh --stage plan --file <plan-path>
```
失败则回到 plan 写作步骤补全 frontmatter / 字段。通过后再交 self-review 做语义审稿。

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

- Plan 落盘并通过 self-review 后，跑结构校验并按结果 emit 阶段 gate（不阻断）：
  ```bash
  if scripts/validate-handoff.sh --stage plan --file "$PLAN"; then
    scripts/log-phase-metric.sh --phase writing-plans --action gate --gate-result passed --spec-topic "$SPEC_TOPIC"
  else
    scripts/log-phase-metric.sh --phase writing-plans --action gate --gate-result failed --spec-topic "$SPEC_TOPIC"
  fi
  ```

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/agent-harness/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use agent-harness:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use agent-harness:executing-plans
- Batch execution with checkpoints for review
