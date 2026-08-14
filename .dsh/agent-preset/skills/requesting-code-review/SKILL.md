---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
whenToUse: "[feedback] Triggered after implementation is complete to request peer review."
---

# Requesting Code Review

Dispatch agent-harness:code-reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code-reviewer agent:**

Invoke the `code-reviewer` agent (defined in `agents/code-reviewer.md`). Give it precisely constructed work-product context:

- requirements / Definition of Done
- `BASE_SHA` and `HEAD_SHA`
- task brief, task report, and review package when available

Never pass the coordinator's full session history. Do not inline a review diff into the coordinator context: the reviewer reads the package and returns findings only.

Use this dispatch structure, omitting only unavailable optional work products:

```text
agent-harness:code-reviewer
Requirements / DoD: ...
BASE_SHA: ...
HEAD_SHA: ...
Task brief: ...
Task report: ...
Review package: ...
Do not send: coordinator full session history or reasoning; inline diff
Reviewer: read the review package
Return: findings only, labeled Standards or Spec; severity Critical, Important, or Minor
```

**Placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

## Review on Two Axes

Every review request must ask the reviewer to check both axes:

1. **Standards axis** — Does the change follow repository rules, security expectations, existing patterns, and maintainability standards?
2. **Spec axis** — Does the change faithfully implement the originating spec, plan task, and Definition of Done?

Do not let one axis hide the other. A clean implementation that misses the spec is still a failed review. A spec-complete implementation with Critical quality or security issues is still a failed review.

**3. Act on feedback:**
- Fix Critical issues immediately on either axis
- Fix Important issues before proceeding on either axis
- Note Minor issues for later
- Push back if reviewer is wrong, with reasoning tied to the relevant axis
- Reviewer 返回且 Critical/Important 处理完毕后，emit 阶段 gate（不阻断）：
  ```bash
  scripts/log-phase-metric.sh --phase requesting-code-review --action gate --gate-result passed --spec-topic "$SPEC_TOPIC"
  ```

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch agent-harness:code-reviewer subagent]
  WHAT_WAS_IMPLEMENTED: Verification and repair functions for conversation index
  PLAN_OR_REQUIREMENTS: Task 2 from docs/agent-harness/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each batch (3 tasks)
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md
