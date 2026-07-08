# SDD Controller Guide

This file holds the detailed reference material for the subagent-driven-development
controller. `SKILL.md` keeps the core orchestrator workflow; load this file when you
need the full rules for a specific phase.

## When to Use

- Have an implementation plan AND tasks are mostly independent AND staying in this session → SDD.
- No plan / tightly coupled tasks / parallel session needed → use the alternatives below.

**vs. Executing Plans (parallel session):**
- Same session (no context switch)
- Fresh subagent per task (no context pollution)
- Review after each task (spec compliance + code quality), broad review at the end

## Pre-Flight Plan Review

Before dispatching Task 1, scan the plan once for conflicts:
- tasks that contradict each other or the plan's Global Constraints
- anything the plan explicitly mandates that the review rubric treats as a defect

Present findings to your human partner as one batched question before execution begins.
If the scan is clean, proceed without comment.

## Model Selection

Use the least powerful model that can handle each role to conserve cost and increase speed.

- **Mechanical tasks** (isolated functions, clear specs, 1-2 files): fast/cheap model.
- **Integration/judgment tasks** (multi-file coordination): standard model.
- **Architecture/design tasks** (incl. final whole-branch review): most capable model.
- **Review tasks**: scale to the diff's size, complexity, and risk.

**Always specify the model explicitly when dispatching a subagent.** An omitted model
inherits the session default — often the most expensive — silently defeating this.

**Turn count beats token price.** Cheapest models routinely take 2-3× turns on
multi-step work, costing more overall. Use a mid-tier model as the floor for reviewers
and for implementers working from prose. When plan text contains the complete code to
write, the implementation is transcription plus testing — use the cheapest tier there.

**Single-file multi-task dispatch:** When multiple tasks all modify the same file and
each depends on the prior task's state in that file, combine them into one implementer
dispatch with all related briefs. The two-stage review still applies to the combined diff.

## Handling Implementer Status

- **DONE:** Generate review package (`"$SDD_SKILL_DIR/scripts/review-package" BASE HEAD`), then dispatch the task reviewer with the printed path. BASE is the commit you recorded before dispatching the implementer — never `HEAD~1`.
- **DONE_WITH_CONCERNS:** Read the concerns. Correctness/scope concerns are addressed before review; observations are noted and reviewed.
- **NEEDS_CONTEXT:** Provide missing context and re-dispatch.
- **BLOCKED:** (1) context problem → more context, same model; (2) reasoning problem → more capable model; (3) task too large → break it up; (4) plan wrong → escalate.

Never ignore an escalation or force the same model to retry without changes.

## Handling Reviewer ⚠️ Items

The task reviewer may report "⚠️ Cannot verify from diff" items — requirements in
unchanged code or spanning tasks. Resolve each before marking the task complete: you
hold the plan and cross-task context the reviewer lacks. A confirmed gap is a failed
spec review — back to the implementer and re-review.

## Constructing Reviewer Prompts

Per-task reviews are task-scoped gates. The broad review happens once, at the final
whole-branch review. When you fill a reviewer template:

- No open-ended directives ("check all uses", "run race tests if useful") without a concrete reason.
- Don't ask a reviewer to re-run tests the implementer already ran on the same code.
- Don't pre-judge findings ("do not flag", "don't treat X as a defect", "at most Minor", "the plan chose") — let the reviewer raise it and adjudicate in the loop.
- The global-constraints block is the reviewer's attention lens: copy binding requirements verbatim from the plan (exact values, formats, relationships).
- Hand the reviewer its diff as a file: `"$SDD_SKILL_DIR/scripts/review-package" BASE HEAD`. The output never enters your own context; the reviewer sees commit list + stat summary + full diff in one Read. Use the BASE recorded before dispatching the implementer — never `HEAD~1`.
- A dispatch prompt describes one task, not session history. Do not paste accumulated prior-task summaries into later dispatches.
- Dispatch fix subagents for Critical/Important findings. Record Minor findings in the progress ledger; point the final review at that list for triage.
- A finding labeled plan-mandated is the human's decision — present finding + plan text, ask which governs.
- Final whole-branch review: `"$SDD_SKILL_DIR/scripts/review-package" MERGE_BASE HEAD` (MERGE_BASE = `git merge-base main HEAD`), include the printed path.
- Every fix dispatch carries the implementer contract: re-run the tests covering its change and report results. Name the covering test files in the dispatch.
- If the final review returns findings, dispatch ONE fix subagent with the complete findings list — not one fixer per finding.

## File Handoffs

Everything you paste into a dispatch prompt — and everything a subagent prints back —
stays resident in your context for the rest of the session and is re-read on every later
turn. Hand artifacts over as files:

- **Task brief:** `"$SDD_SKILL_DIR/scripts/task-brief" PLAN_FILE N` extracts the task's full text to a uniquely named file and prints the path. Compose the dispatch so the brief stays the single source of requirements. **Before dispatching (issue #82):** open the brief and check for any "see <plan>.md ..." or "per <plan>.md Task M" references. For each, copy the referenced section verbatim into the brief (or, if huge, quote the binding constraints and acceptance criteria). A self-contained brief lets the implementer skip Reading the whole plan and saves ~3K tokens per dispatch — the largest avoidable SDD cost. Dispatch contains: (1) one line of task context; (2) brief path introduced as "read this first"; (3) interfaces/decisions from earlier tasks the brief cannot know; (4) your ambiguity resolutions; (5) report-file path and report contract.
- **Report file:** name after the brief (brief `…/task-N-brief.md` → report `…/task-N-report.md`). Implementer writes the full report there and returns status, commits, a one-line test summary, and concerns.
- **Reviewer inputs:** task reviewer gets three paths — brief, report, review package — plus global constraints.
- Fix dispatches append their fix report (with test results) to the same report file.

## Durable Progress

Conversation memory does not survive compaction. Controllers that lost their place
have re-dispatched entire completed task sequences — the single most expensive failure
observed. Track progress in a ledger file, not only in todos.

At skill start, ensure the SDD ledger directory exists and check for a ledger:
```
SDD_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"/.agent-harness/sdd
mkdir -p "$SDD_DIR"
LEDGER="$SDD_DIR/progress.md"
[ -f "$LEDGER" ] && cat "$LEDGER" || echo "(no prior SDD progress)"
```

Tasks listed as complete in the ledger are DONE — do not re-dispatch them. When a task's
review comes back clean, append one line: `Task N: complete (commits <base7>..<head7>, review clean)`.

After compaction, trust the ledger and `git log` over your own recollection.

## Red Flags

**Never:**
- Start implementation on main/master without explicit user consent.
- Skip task review, or accept a report missing either verdict (spec compliance AND task quality are both required).
- Proceed with unfixed Critical/Important issues.
- Dispatch multiple implementation subagents in parallel (conflicts).
- Make a subagent read the whole plan file — hand it its task brief.
- **Dispatch a brief that references the plan by path (issue #82).** The
  brief must be self-contained: inline every plan section the task depends
  on. A subagent that Reads the plan file burns ~3K tokens per dispatch
  (241 subagents × 3K ≈ 720K tokens on the hack project trace).
- Skip scene-setting context.
- Ignore subagent questions.
- Accept "close enough" on spec compliance.
- Skip review loops.
- Let implementer self-review replace actual review (both needed).
- Tell a reviewer what not to flag, or pre-rate a finding's severity.
- Dispatch a task reviewer without a diff file.
- Move to next task while the review has open Critical/Important issues.
- Re-dispatch a task the progress ledger already marks complete — check the ledger and `git log` after any compaction or resume.

## Integration

**Required workflow skills:**
- **agent-harness:writing-plans** — creates the plan this skill executes.
- **agent-harness:requesting-code-review** — code review template for the final whole-branch review.
- **agent-harness:finishing-a-development-branch** — complete development after all tasks.

**Subagents should use:**
- **agent-harness:test-driven-development** — subagents follow TDD for each task.

**Alternative workflow:**
- **agent-harness:executing-plans** — use for parallel session instead of same-session execution.
