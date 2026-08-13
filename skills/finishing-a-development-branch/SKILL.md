---
name: finishing-a-development-branch
description: Use when implementation is done and tests pass, and the user must choose how to integrate or retain completed branch work.
---

# Finishing a Development Branch

## Overview

Verify the completed result, offer only safe next actions, and preserve work unless the user explicitly requests its destruction.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the relevant project test suite before offering choices. If it fails, STOP: report failures and fix them before merge or PR.

## Step 2: Capture Repository Identity Before Any Directory Change

Before any `cd` to the main repository or base branch, capture the current repository data:

```bash
GIT_DIR=$(git rev-parse --git-dir)
GIT_COMMON=$(git rev-parse --git-common-dir)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

Determine the base branch without changing directories:

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Resolve the current project's common root from the captured common Git directory. `git rev-parse --git-common-dir` may return either an absolute or a relative `.git` path, so handle both before any directory change:

```bash
if [[ "$GIT_COMMON" = /* ]]; then
  PROJECT_ROOT=$(dirname "$GIT_COMMON")
else
  PROJECT_ROOT=$(cd "$(dirname "$GIT_COMMON")" && pwd)
fi
```

Only the captured `WORKTREE_PATH` is eligible for removal. Use this guard exactly; its slash-delimited patterns allow descendants of `.worktrees/` and `worktrees/` only, not prefix lookalikes such as `.worktrees-evil`:

```bash
# BEGIN owned-worktree-removal-guard
remove_captured_owned_worktree() {
  case "$WORKTREE_PATH" in
    "$PROJECT_ROOT"/.worktrees/*|"$PROJECT_ROOT"/worktrees/*)
      git worktree remove "$WORKTREE_PATH"
      ;;
    *)
      printf 'Preserving non-project-owned worktree: %s\n' "$WORKTREE_PATH"
      ;;
  esac
}
# END owned-worktree-removal-guard
```

Never place `git worktree remove` outside this guard. It preserves host-owned, parent-owned, and unmatched workspace paths.

## Step 3: Present Safe Options

For a normal branch or named worktree, present exactly:

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?
```

For detached HEAD, present exactly:

```
Implementation complete. What would you like to do?

1. Push as a new branch and create a Pull Request
2. Keep as-is

Which option?
```

The default menu never includes discard.

## Step 4: Execute the User's Choice

### Local merge

Only after the user selects merge:

```bash
cd <base-branch>
git pull
git merge <feature-branch>
<test command>
```

If merged-result verification fails: **STOP. Keep the branch and worktree for investigation.** Do not delete anything.

After successful verification, delete the feature branch only if appropriate. Remove the captured worktree only through `remove_captured_owned_worktree`.

### Push and create a pull request

Push the branch and create a pull request using the available forge workflow. `gh pr create` is acceptable when available, but it is not the only valid forge workflow. Keep the branch, worktree, and artifacts.

### Keep as-is

Report the retained branch or detached state. Keep the worktree and artifacts.

**PR and Keep preserve all branch, worktree, and SDD artifacts.** Finishing options do not run SDD cleanup; the SDD final-review-clean transition owns current-plan cleanup.

## Explicit Discard Only

Discuss discard only after the user explicitly asks to discard the work. Show the exact branch, commits, and eligible worktree path, then require this exact confirmation:

```
Type `discard` to confirm.
```

Only after that exact response may destructive commands run. For an eligible captured project-owned worktree, call `remove_captured_owned_worktree`; otherwise its fallback preserves the worktree.

## Red Flags

**Never:**
- Proceed while tests fail.
- Delete a branch or worktree without explicit discard confirmation.
- Treat a worktree as owned merely because it is active.
- Remove SDD artifacts from a PR or Keep outcome.
- Force-push without explicit user request.

## Integration

**Called by:**
- **subagent-driven-development** after all tasks complete.
- **executing-plans** after all tasks complete.
