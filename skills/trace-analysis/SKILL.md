---
name: trace-analysis
description: Use during retrospective or when analyzing recurring failure patterns across sessions via learnings data.
when_to_use: "[feedback] Triggered during retrospective or when analyzing cross-session failure trends."
---

# Trace Analysis

## Overview

Trace analysis turns historical learnings into actionable signal for skill improvement. Uses `scripts/trace-analyzer.sh` to classify failure patterns from `.agent-harness/learnings.jsonl`.

**Core principle:** Data over intuition. Run the analyzer before deciding what to improve.

## When to Use

- During retrospective (pair with `retrospective` skill)
- When reviewing `.agent-harness/learnings.jsonl` for trends
- When noticing recurring failure modes across sessions
- When planning which skills to improve next

## How to Run

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/trace-analyzer.sh" [project_root]
```

## Pattern Reference

The analyzer classifies learnings by keywords in `key` and `insight` fields:

| Pattern | Meaning | Address With |
|---------|---------|-------------|
| `loop` | Re-editing same file without converging | loop-detection |
| `drift` | Wandering away from task goal | writing-plans with explicit task boundaries |
| `oversight` | Missing steps or requirements | verification-before-completion checklists |
| `scope-creep` | Adding work beyond what was asked | sprint-contract to lock scope |
| `verification-gap` | Claiming success without evidence | computational-sensors for deterministic verification |
| `other` | Unmatched failure mode | Investigate manually |

## Interpreting Output

- Top pattern = highest priority. Analyzer sorts by count.
- If `loop` appears, that's urgent. Doom loops waste the most time.
- Multiple patterns at similar counts suggest systemic issues. Planning skills (writing-plans + sprint-contract) may prevent several at once.

## TDD Baseline (RED Phase)

Pressure scenario: agent conducting retrospective, learns failure patterns exist but ignores data, "improves" based on gut feeling instead of analyzer output.

Baseline failures: agent skips trace-analyzer.sh, rationalizes "I know the patterns", does not cross-reference with skill improvement actions.

## Recommendations

Match analyzer recommendations to skill invocations:

1. loop-detection → `agent-harness:loop-detection` — ensure tracking is active
2. computational-sensors → `agent-harness:computational-sensors` — configure sensors
3. sprint-contract → `agent-harness:sprint-contract` — lock scope before next implementation
4. verification checklists → `agent-harness:verification-before-completion`
5. writing-plans → `agent-harness:writing-plans` — plan before next multi-step task

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Treating one learning as a pattern | Need 3+ occurrences to confirm a real pattern |
| Skipping analysis because learnings are sparse | Even sparse data shows direction |
| Acting on every pattern at once | Address top pattern first, then re-run |

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "I know my failure modes" | Feelings are not data. Run the analyzer |
| "The patterns are obvious" | Obvious patterns would have been fixed already |
