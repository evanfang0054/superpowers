---
name: loop-detection
description: Use when an agent is stuck editing the same file repeatedly without converging, or when verification requires doom loop analysis.
when_to_use: "[feedback] Triggered after multiple unsuccessful edits to the same file or when verification detects repeated changes without progress."
---

# Loop Detection

## Overview

Editing the same file repeatedly without convergence is a doom loop. Stop. Detect. Recover.

**Core principle:** Three edits to the same file without measurable progress = stop and reassess.

## When to Use

- Edited same file 3+ times, problem persists
- Each edit fixes one thing, breaks another
- "Iterating" with no convergence evidence
- verification-before-completion detects repeated changes
- **Semantic loop (issue #81):** 3+ consecutive assistant turns with no tool calls while user keeps rejecting proposals ("不对", "不行", "重新"), or a single session exceeds 2 active plans (see writing-plans)

**Not for:** Intentional multi-file refactors, systematic changes across different files.

## Core Pattern

```
BEFORE each edit to a file you have already modified this session:

1. TRACK: bash scripts/loop-detector.sh --track <file>
2. CHECK: bash scripts/loop-detector.sh
3. ACT based on exit code:
   0 = OK      -> proceed
   1 = WARNING -> reconsider approach (see Recovery)
   2 = HARD STOP -> stop editing, mandatory recovery
```

## Quick Reference

| Exit Code | Label | Threshold | Action |
|-----------|-------|-----------|--------|
| 0 | OK | <5 edits | Proceed, track edits |
| 1 | WARNING | >=5 edits | Reconsider, try different approach |
| 2 | HARD STOP | >=8 edits | Stop. Mandatory recovery. No more edits to this file. |

**Thresholds configurable via env:** `LOOP_WARN_THRESHOLD`, `LOOP_HARD_THRESHOLD`

**Reset after successful approach change:** `bash scripts/loop-detector.sh --reset`

## Recovery Strategies

### WARNING (exit 1) -- Reconsider

1. Stop and re-read the original error/problem statement
2. Check: am I treating symptoms instead of root cause?
3. Try a different approach: different file, different strategy, different abstraction level
4. If new approach works, reset tracker and continue

### HARD STOP (exit 2) -- Mandatory Recovery

You MUST do ONE of the following before touching that file again:

1. **Rollback:** `git checkout -- <file>` and start fresh with a different plan
2. **Seek help:** Ask your human partner for guidance, show them what you tried
3. **Replan:** Step back, write a new plan, get it reviewed before implementing

No exceptions. HARD STOP means stop.

## Semantic Loop Recovery (issue #81)

When the semantic-loop trigger fires (3+ consecutive no-tool turns with user
rejecting proposals, or 2+ active plans stacking in one session):

1. **Stop generating option lists.** Listing more options does not converge.
2. **Switch to outcome question:** ask the user to describe the end result they
   want, ignoring feasibility.
3. **Or recommend handoff:** "我们对需求理解差距较大，先用 office-hours 厘清目标"
   / "this session is carrying too many plans, start a new session".
4. **Or recommend compaction:** if context is the problem, suggest `/compact`
   or starting a fresh session before continuing.

Rationale (issue #81, hack session evidence): a single session stacking 4 plans
triggered 8 compacts and 45.6% of turns were no-tool text loops. Breaking the
loop at turn 3 saves an estimated 60+ zero-output turns.

**触发诊断（不自动修复）：** HARD STOP 时除原警告外，额外生成一份失败诊断报告，便于后续追溯同类循环：

```bash
scripts/diagnose-failure.sh --type loop --context '{"file":"<path>","edits":<n>}' --spec-topic "$SPEC_TOPIC"
```

诊断报告路径会在警告输出里告知用户（stderr）。报告只记录，不执行修复——由人审决定下一步。

## Red Flags -- STOP Editing

- "This time is different" -- convergence evidence or stop
- "I'm iterating, not looping" -- iteration has measurable progress
- "Just one more fix" -- you said that last time
- "The user is waiting" -- looping wastes MORE time than stopping
- "I'm making progress" -- name the specific metric that improved
- "Each edit is small" -- small edits that don't converge = still a loop
- "I almost have it" -- "almost" for 5+ edits means no
- "The fix is more complex than expected" -- then replan
- "I need to try one more thing" -- after 5 attempts, trying isn't solving

**If you recognize yourself above, stop and run loop-detector.sh.**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Editing without tracking | Always `--track` before editing |
| Ignoring WARNING | WARNING exists to prevent HARD STOP |
| Resetting tracker without changing approach | Reset only after you have a genuinely new plan |
| Treating "different error" as progress | Same file, same root cause = still looping |
| Skipping detection "because I know I'm fine" | That confidence is the loop talking |

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "I'm iterating, not looping" | Iteration converges. Where is your evidence? |
| "This time is different" | Prove it with a measurable outcome before editing |
| "Just one more small change" | You said that 5 times already |
| "User is waiting, no time to stop" | 8 failed edits waste more time than 1 reset |
| "I can see the end" | If you could, you would have finished by now |
| "The skill doesn't apply here" | That is the loop talking |
| "I'm making incremental progress" | Name the metric. No metric = no progress. |
| "This is a special case" | Every loop thinks it is special |

## TDD Baseline (RED Phase)

Pressure scenario: agent fixing TypeScript error, 6 failed edits to same file, time pressure.

Baseline failures: agent continues without reflection, rationalizes "this time is different", does not call loop-detector.sh, does not consider alternatives.
