---
name: executing-plans
description: Use when you have a written implementation plan to execute iteratively in the current session with review checkpoints
argument-hint: "任务描述或 Plan 路径"
when_to_use: "[feedforward, feedback] Triggered when executing a written plan task-by-task with review checkpoints."
---

# Executing Plans

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" \
  "Task: $ARGUMENTS

=== MANDATORY Rules (DO NOT SKIP) ===
1. Pick the highest-priority task and implement ONLY that one. You decide priority—not necessarily the first in the list.
2. For EVERY task: follow agent-harness:test-driven-development (write failing test FIRST, then implement).
3. After completing each task, run agent-harness:requesting-code-review before moving to the next task.
4. After completing the task, update the plan document to record what was done.
5. When encountering unfamiliar or new APIs, use context7 to query the latest documentation.
6. Stay in the current directory—do not cd into other directories unless absolutely necessary.
7. Before rerunning a failed command caused by path / package-root / no-match issues, first confirm the correct target path, package root, or command shape. Do not thrash by repeating the same unstable command.
9. If the same tool-call or command-shape failure repeats twice, stop execution and diagnose the workflow/tool usage itself before continuing.
10. Never pass empty optional tool arguments. Example: omit Read.pages unless you are reading a PDF and have a real page range like "1-5".
11. The Ralph loop replays this SAME prompt inside the current session. Keep progress in files and task state instead of rewriting the task.
12. The completion promise uses exact string matching. Do not quote, mention, or emit it before all required work is complete.
13. If you are approaching the iteration limit and are still blocked, document what is blocking progress, what you already tried, and the most likely next step.
14. When ALL plan tasks are done, you MUST run agent-harness:finishing-a-development-branch to complete the branch.
15. ONLY after finishing-a-development-branch is executed, emit the completion signal exactly once as <promise>COMPLETE</promise>.
" \
  --completion-promise "COMPLETE" \
  --max-iterations 60
```

---

## Overview

Load plan, review critically, execute all tasks iteratively in the current session, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Agent Harness can benefit from subagents. If subagents are available, prefer agent-harness:subagent-driven-development. Otherwise, continue with this skill in the current workspace.

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

**Task stage 结构软提示（不阻断）**：每个 task 完成时，建议跑一下：
```bash
scripts/validate-handoff.sh --stage task --file <plan-path>
```
失败时先看是否缺 `## Tasks` / `### Task N:` 结构，再决定是否回 plan 步骤补全。本阶段不强制阻断——仅作为「plan → task」交接的结构体检。

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use agent-harness:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice
- All tasks 完成并 verified 后，emit 阶段指标（不阻断）：
  ```bash
  scripts/log-phase-metric.sh --phase executing-plans --action end --spec-topic "$SPEC_TOPIC"
  ```

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly
- The same tool-call or command-shape failure repeats twice
- A failed command looks like a path / package-root / target-selection mistake rather than a product bug

**Ask for clarification rather than guessing. Diagnose command shape before rerunning.**

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
- **agent-harness:writing-plans** - Creates the plan this skill executes
- **agent-harness:finishing-a-development-branch** - Complete development after all tasks
