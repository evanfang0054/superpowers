---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
argument-hint: "任务描述或 Plan 路径"
---

# Executing Plans

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" \
  "Task: $ARGUMENTS

=== MANDATORY Rules (DO NOT SKIP) ===
1. Pick the highest-priority task and implement ONLY that one. You decide priority—not necessarily the first in the list.
2. For EVERY task: follow superpowers:test-driven-development (write failing test FIRST, then implement).
3. After completing each task, run superpowers:requesting-code-review before moving to the next task. If worktree isolation is unavailable or disallowed, perform review directly in the current workspace.
4. After completing the task, update the plan document to record what was done.
5. When encountering unfamiliar or new APIs, use context7 to query the latest documentation.
6. Stay in the current directory—do not cd into other directories unless absolutely necessary.
7. Do not create git worktrees—work directly in the current workspace.
8. When ALL plan tasks are done, you MUST run superpowers:finishing-a-development-branch to complete the branch.
9. ONLY after finishing-a-development-branch is executed, emit the completion signal exactly once (do not quote or mention it earlier).
" \
  --completion-promise "COMPLETE" \
  --max-iterations 60
```

---

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Superpowers can benefit from subagents. If subagents are available **and** do not conflict with active constraints (for example, no-worktree requirements), prefer superpowers:subagent-driven-development. Otherwise, continue with this skill in the current workspace.

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create TodoWrite and proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent

## Integration

**Related workflow skills:**
- **superpowers:using-git-worktrees** - OPTIONAL: Set up isolated workspace if user requests isolation (not required by default)
- **superpowers:writing-plans** - Creates the plan this skill executes
- **superpowers:finishing-a-development-branch** - Complete development after all tasks
