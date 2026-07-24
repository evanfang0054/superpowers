---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
argument-hint: "任务描述或Plan路径"
when_to_use: "[feedforward, feedback] Triggered when dispatching subagents for plan execution with review gates."
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
  \"\$SDD_SKILL_DIR/scripts/session-init.sh\"  # SDD Fan-Out: session init
  \"\$SDD_SKILL_DIR/scripts/sdd-state.sh\"     # SDD Fan-Out: state read-write
  \"\$SDD_SKILL_DIR/scripts/sdd-worktree.sh\"  # SDD Fan-Out: worktree management
  \"\$SDD_SKILL_DIR/merge-fix-prompt.md\"      # SDD Fan-Out: merge conflict resolution template
Never call these with bare relative paths like \`scripts/task-brief\` — if
the CWD has drifted (e.g. after cd-ing into a subdirectory) relative paths
resolve to the wrong location and fail.

=== ORCHESTRATOR WORKFLOW (per iteration) ===

**Fan-Out Detection:**
After reading the plan, check if ANY task has \`Blocking: none\`:
- If NO — run serial workflow below (existing behavior)
- If YES — run Fan-Out workflow (see FAN-OUT WORKFLOW section below)

**FAN-OUT WORKFLOW (for plans with Blocking: none tasks):**

0. RESUME CHECK: If \`.agent-harness/sdd/\` has existing state files:
   - Read the latest \`state.json\`
   - For each node: \`in_progress\` and worktree exists → keep running; \`completed\` with no merge → merge now; \`intervention_needed\` → flag; \`pending\` → keep
   - Resume where it left off (do not restart completed nodes)

0. INIT (if no resume): Run \`\"\$SDD_SKILL_DIR/scripts/session-init.sh\" \"\$(git branch --show-current)\" \"\$PLAN_FILE\"\`
   → SESSION_DIR (save for all subsequent steps)

1. Parse the plan: extract all tasks with Blocking / files fields.
   Build a DAG: nodes = tasks, edges = Blocking dependencies.

2. DISPATCH LOOP:
   While nodes remain unstarted or in_progress:
     a. Find all nodes with status=pending AND all blocking deps in 'completed' or empty
     b. Select up to concurrency_limit (default 3) nodes
     c. For each selected node:
        - Create worktree via \`sdd_worktree_create \"\$REPO_ROOT\" \"\$TASK_KEY\" \"\$ORCH_BRANCH\"\`
        - Update state via sdd_state: node.status = in_progress
        - Save worktree_path, branch to state
     d. **Same message: dispatch ALL selected implementers in parallel**
        Agent(implementer-N) with:
          - task brief (via \`\"\$SDD_SKILL_DIR/scripts/task-brief\"\`)
          - WORKTREE_PATH → worktree directory
          - FILE_SCOPE → from plan's \`files:\` field or \"ALL\" if omitted
     e. Wait for all implementers to return
     f. For each returned implementer (serial, needs review agent):
        i. **Check for contradiction signals** — if implementer output contains
           \"contradiction\", \"conflict in requirements\", \"requirement A but\" → flag as intervention_needed
        ii. Record BASE commit (before task): git rev-parse HEAD in worktree
        iii. Generate review package:
            \`\"\$SDD_SKILL_DIR/scripts/review-package\" BASE HEAD [FILE_SCOPE_LIST]\`
        iv. Dispatch TASK REVIEWER with review package + file-scope check
        v. **no-progress detection:** append reviewer findings to
           state.retry_findings_history. If the same finding text appeared
           in the last 2 entries → intervention_needed (stuck in loop)
        vi. Review passes → state.node.status = completed
            Review fails → retry_count++; if < max_retries → dispatch fix
            If max_retries reached or FILE_SCOPE_VIOLATION → intervention_needed
     g. If any node is intervention_needed → keep running other nodes, flag at end

3. MERGE PHASE (serial, topological order):
   For each completed node, in DAG order:
     a. \`git merge --no-ff _sdd/{session}/{task-key}\`
     b. If conflict:
        - Read conflicted files
        - Dispatch merge-fix subagent using \`\"\$SDD_SKILL_DIR/merge-fix-prompt.md\"\`
        - merge-fix fails → intervention_needed
     c. Remove worktree:
        Default: \`sdd_worktree_remove \"\$REPO_ROOT\" \"\$TASK_KEY\"\` (delete branch)
        If intervention_needed: \`sdd_worktree_remove \"\$REPO_ROOT\" \"\$TASK_KEY\" --keep-branch\`
     d. Update state: node.merge = completed

4. INTEGRATION: Run tests in orchestrator branch
   - Pass → proceed to finishing-a-development-branch
   - Fail → dispatch fix agent

5. CLEANUP: \`sdd_cleanup_all_worktrees \"\$REPO_ROOT\"\`
   + Update state via sdd_state

**SERIAL WORKFLOW (fallback, for plans without Blocking: none):**
1. Read the plan/task, extract pending tasks
2. For the NEXT pending task:
   a. Run \`\"\$SDD_SKILL_DIR/scripts/task-brief\"\` to extract task text to a file
   b. **Inline referenced plan content (issue #82):** open the brief; for every line like \"per <plan>.md Task N\" or \"see <plan>.md section X\", copy that section verbatim into the brief. Prefer inlining when the referenced section is <= ~1KB; for larger sections, inline a summary + note in the brief that the full section lives at <plan>.md:<section> and the implementer may Read that specific section if needed (scoped re-Read fallback per ce8d713).
   c. Dispatch IMPLEMENTER subagent (use \`\"\$SDD_SKILL_DIR/implementer-prompt.md\"\` template, with brief file path)
   d. If implementer asks questions, answer them and re-dispatch
   e. When implementer reports DONE, run \`\"\$SDD_SKILL_DIR/scripts/review-package\" BASE HEAD\` to generate diff file
   f. Dispatch TASK REVIEWER subagent (\`\"\$SDD_SKILL_DIR/task-reviewer-prompt.md\"\`) with brief file + report file + review package
   g. If review fails, have implementer fix and re-review
   h. When review passes, mark task complete in progress ledger
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
5. **Fix loop:** Critical/Important findings → dispatch fix subagent → re-review. Record Minor in ledger.
6. **Mark task complete** in both TodoWrite and the progress ledger (append one line: `Task N: complete (commits <base>..<head>, review clean)`).
7. Next task.

## Final Stage

When all tasks complete:
1. Dispatch final whole-branch review (template: `../requesting-code-review/code-reviewer.md`) with a review package spanning `MERGE_BASE..HEAD`.
2. If findings: dispatch ONE fix subagent with the complete findings list.
3. Run **agent-harness:finishing-a-development-branch**.

## Prompt Templates

- [implementer-prompt.md](implementer-prompt.md) — dispatch implementer subagent.
- [task-reviewer-prompt.md](task-reviewer-prompt.md) — dispatch task reviewer (spec + quality).
- Final review: [code-reviewer.md](../requesting-code-review/code-reviewer.md) from agent-harness:requesting-code-review.

## Durable Progress (essential)

Conversation memory does not survive compaction. Track progress in a ledger:
```
SDD_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"/.agent-harness/sdd
mkdir -p "$SDD_DIR"
LEDGER="$SDD_DIR/progress.md"
[ -f "$LEDGER" ] && cat "$LEDGER" || echo "(no prior SDD progress)"
```
Tasks marked complete in the ledger are DONE — never re-dispatch them. After compaction,
trust the ledger and `git log` over your own recollection.
