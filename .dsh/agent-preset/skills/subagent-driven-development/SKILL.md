---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
argument-hint: "任务描述或Plan路径"
whenToUse: "[feedforward, feedback] Triggered when dispatching subagents for plan execution with review gates."
---

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" \
  "Task: $ARGUMENTS

You are the ORCHESTRATOR. Your job is to coordinate subagents, NOT implement code yourself.

IMPORTANT: All script paths in this workflow MUST be anchored to the plugin
root so they resolve regardless of the current working directory. Define
once at the top of your shell context:
  SDD_SKILL_DIR=\"\${CLAUDE_PLUGIN_ROOT}/skills/subagent-driven-development\"
Then use:
  \"\$SDD_SKILL_DIR/scripts/task-brief\"      # task brief extractor
  \"\$SDD_SKILL_DIR/scripts/review-package\"  # diff packager
  \"\$SDD_SKILL_DIR/implementer-prompt.md\"   # implementer template
  \"\$SDD_SKILL_DIR/task-reviewer-prompt.md\" # reviewer template
  \"\$SDD_SKILL_DIR/re-review-prompt.md\"      # scoped re-review template
Never call these with bare relative paths like \`scripts/task-brief\` — if
the CWD has drifted (e.g. after cd-ing into a subdirectory) relative paths
resolve to the wrong location and fail.

=== ORCHESTRATOR PREFLIGHT — ISOLATION (before reading or dispatching) ===
1. User specified a branch: execute on that branch.
2. User did not specify an isolation location: create an independent branch before executing.
3. User explicitly requested a worktree: create or enter that worktree.
4. Without an explicit worktree request: do not use a worktree.
Never start implementation on main/master without explicit user consent.

=== ORCHESTRATOR WORKFLOW (per iteration) ===
1. Read the plan/task, extract pending tasks
2. For the NEXT pending task:
   a. Run \`\"\$SDD_SKILL_DIR/scripts/task-brief\" PLAN_FILE TASK_NUMBER\` to extract task text to a file
   b. **Inline referenced plan content (issue #82):** open the brief; for every line like \"per <plan>.md Task N\" or \"see <plan>.md section X\", copy that section verbatim into the brief. Prefer inlining when the referenced section is <= ~1KB; for larger sections, inline a summary + note in the brief that the full section lives at <plan>.md:<section> and the implementer may Read that specific section if needed (scoped re-Read fallback per ce8d713).
   c. Dispatch IMPLEMENTER subagent (use \`\"\$SDD_SKILL_DIR/implementer-prompt.md\"\` template, with brief file path)
   d. If implementer asks questions, answer them and re-dispatch
   e. When implementer reports DONE, run \`\"\$SDD_SKILL_DIR/scripts/review-package\" PLAN_FILE BASE HEAD\` to generate diff file
   f. Dispatch TASK REVIEWER subagent (\`\"\$SDD_SKILL_DIR/task-reviewer-prompt.md\"\`) with brief file + report file + review package
   g. **HARD GATE — failed task review:** For spec ❌, Critical, Important, or confirmed ⚠️, record `FIX_BASE` before the fixer (never `HEAD~1`), then create `review-package PLAN_FILE FIX_BASE HEAD`. Dispatch `re-review-prompt.md` with the original findings, brief, report, and that package. It MUST give every original finding `ADDRESSED` or `NOT ADDRESSED`; it reviews only those findings plus new Critical/Important breakage in the fix diff — never `MERGE_BASE..HEAD` or a whole-branch re-review.
   h. **Round-5 boundary:** rounds 1–3 resume the original implementer; rounds 4–5 use a fresh implementer at least one model tier stronger. At round 5, only a non-load-bearing/disputable finding may be `parked` with a ruling. A load-bearing finding is `BLOCKED`: stop the current plan and do not dispatch the next task.
   i. When review passes, mark task complete in progress ledger
3. Move to next task

=== MANDATORY Rules (DO NOT SKIP) ===
1. You are COORDINATOR ONLY - never write implementation code yourself. This includes fixing review findings: when a reviewer reports issues, you MUST dispatch a fix subagent (implementer) to address them — never fix them yourself, even for \"trivial\" one-line fixes.
2. Each task requires TWO subagents: implementer → task reviewer (spec + quality in one pass)
3. Subagents must follow agent-harness:test-driven-development (TDD)
4. Every dispatch MUST state its model explicitly (see references/controller-guide.md Model Selection)
5. Do NOT skip any review stage
6. Do NOT proceed if any review has open Critical/Important issues
7. Do NOT tell the reviewer what to ignore or pre-rate severity
8. When ALL tasks complete, dispatch FINAL CODE REVIEWER for entire implementation
9. After final review, you MUST run agent-harness:finishing-a-development-branch
10. ONLY after finishing-a-development-branch is executed, emit the completion signal exactly once (do not quote or mention it earlier).
" \
  --completion-promise "COMPLETE" \
  --max-iterations 60
```

# Subagent-Driven Development

Execute a plan by dispatching a fresh implementer subagent per task, a task review
(spec compliance + code quality) after each, and a broad whole-branch review at the end.

**Core principle:** Fresh subagent per task + task review + broad final review = high quality, fast iteration.

**Narration:** between tool calls, narrate at most one short line — the ledger and tool results carry the record.

**Continuous execution:** Do not pause between tasks. Execute the plan without stopping.
The only reasons to stop are: BLOCKED status you cannot resolve, ambiguity that genuinely
prevents progress, or all tasks complete.

## Detailed Reference

For model selection, status handling, reviewer-prompt construction, file handoffs,
durable progress (ledger), pre-flight plan review, red flags, and integration notes:

**Read [`references/controller-guide.md`](references/controller-guide.md)** — load it
when you need rules for a specific phase (e.g., before the first dispatch, before the
first review, or after compaction). Do not paste its content into dispatch prompts.

## The Process (per task)

1. **Extract brief:** `"$SDD_SKILL_DIR/scripts/task-brief" PLAN_FILE N` → brief file path.
2. **Dispatch implementer** (template: `implementer-prompt.md`) with brief + report paths + task context.
3. **Handle status:** DONE → review package; DONE_WITH_CONCERNS → read concerns; NEEDS_CONTEXT → provide; BLOCKED → diagnose.
4. **Dispatch task reviewer** (template: `task-reviewer-prompt.md`) with brief + report + review package.
5. **Fix loop:** For Critical, Important, spec ❌, or controller-confirmed ⚠️, follow the five-round scoped re-review contract. Record Minor in ledger.
6. **Mark task complete** in both TodoWrite and the progress ledger (append one line: `Task N: complete (commits <base>..<head>, review clean)`).
7. Next task.

## Final Stage

When all tasks complete:
1. Dispatch final whole-branch review with `MERGE_BASE..HEAD` package.
2. If it finds Critical/Important issues: one fixer, then one scoped re-review using `re-review-prompt.md`; adjudicate residuals and never start a second fix wave.
3. Clean the current-plan workspace only after that review is clean and accepted fixes are on this branch, then run **agent-harness:finishing-a-development-branch**.

## Prompt Templates

- [implementer-prompt.md](implementer-prompt.md) — dispatch implementer subagent.
- [task-reviewer-prompt.md](task-reviewer-prompt.md) — initial task reviewer (spec + quality).
- [re-review-prompt.md](re-review-prompt.md) — scoped review of open findings and a fix diff.
- Final review: [code-reviewer.md](../requesting-code-review/code-reviewer.md) from agent-harness:requesting-code-review.

## Durable Progress (essential)

Conversation memory does not survive compaction. Track progress in a ledger:
```
SDD_DIR=$("$SDD_SKILL_DIR/scripts/sdd-workspace" PLAN_FILE)
LEDGER="$SDD_DIR/progress.md"
# Restore only when the existing first line is exactly:
# # SDD ledger — plan: <PLAN_FILE path>
```
Only an identity-matching ledger may restore completed tasks or fix-round state. Initialize a
new ledger with `# SDD ledger — plan: <PLAN_FILE path>`; `.agent-harness/sdd` is git-ignored
and `git clean -fdx` deletes it, so recovery relies on Git history rather than automatic restore.
