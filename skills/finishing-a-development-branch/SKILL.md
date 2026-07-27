---
name: finishing-a-development-branch
description: Use when implementation is done and tests pass. Guides merge, PR, or cleanup options.
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify tests -> Detect environment -> Present options -> Execute choice -> Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Tests

Run the project's full test suite (`npm test` / `cargo test` / `pytest` / `go test ./...`).

**If tests fail**, report the failures and stop:

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]
```

Cannot proceed with merge/PR until tests pass. Don't proceed to Step 2.

**If tests pass:** continue to Step 2.

## Step 2: Detect Environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# Capture now, while still inside the workspace -- Step 5 changes directory
# before cleanup (Step 6) needs this value
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | Externally managed -- leave in place |

## Step 3: Determine Base Branch

The base branch is whatever this work forked from -- usually named in the plan, the conversation, or the branch's upstream. If it is not already known, ask: "This branch split from <your best guess> - is that correct?" Confirm before merging: merging into the wrong base is expensive to undo.

## Step 4: Present Options

**Normal repo and named-branch worktree -- present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Detached HEAD -- present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

## Step 5: Execute Choice

### Option 1: Merge Locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first -- verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>
```

If tests fail on the merged result: stop, leave the worktree and branch in place, and investigate -- nothing has been pushed, so the merge is local and recoverable.

Once the merged result is green: clean up the worktree (Step 6), then delete the branch:

```bash
git branch -d <feature-branch>
```

Then: Run SDD workspace cleanup:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/subagent-driven-development/scripts/cleanup-workspace"
```

Then: Done

### Option 2: Push and Create PR

```bash
git push -u origin <feature-branch>
# From a detached HEAD, name the new branch on the remote:
# git push origin HEAD:refs/heads/<new-branch>
```

Then create the pull/merge request against <base-branch> with the forge's tooling -- its CLI if one is available, or the creation URL most forges print when you push -- following the repo's PR template and conventions if present, and report the URL to your human partner.

Keep the worktree -- your human partner iterates on PR feedback there.

Then: Run SDD workspace cleanup:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/subagent-driven-development/scripts/cleanup-workspace"
```

Then: Done

### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

Then: Run SDD workspace cleanup:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/subagent-driven-development/scripts/cleanup-workspace"
```

### Option 4: Discard

**Confirm first:**

```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then clean up the worktree (Step 6) and force-delete the branch:

```bash
git branch -D <feature-branch>
```

Then: Run SDD workspace cleanup:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/subagent-driven-development/scripts/cleanup-workspace"
```

Then: Done

## Step 6: Cleanup Workspace

**Runs for Option 1 and confirmed discards.** Options 2 and 3 always preserve the worktree. Both callers have already changed directory to the main repo root -- worktree removal must run from outside the worktree -- and use the `GIT_DIR`/`GIT_COMMON`/`WORKTREE_PATH` values captured in Step 2, from before that directory change.

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** SDD worktree -- subagent-driven-development owns cleanup:

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment owns this workspace -- leave it in place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch | Cleanup SDD Workspace |
|--------|-------|------|---------------|----------------|----------------------|
| 1. Merge locally | yes | - | - | yes | yes |
| 2. Create PR | - | yes | yes | - | yes |
| 3. Keep as-is | - | - | yes | - | yes |
| 4. Discard | - | - | - | yes (force) | yes |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Run the suite on the tree you are about to integrate. A green run only proves the tree it ran on. |
| "They obviously want it merged" | Integration is your human partner's decision. Present the menu and wait. |
| "They seem done with this feature -- I'll offer to discard it" | The menu already includes Option 4. Let them choose. |
| "'Yeah, get rid of it' counts as confirmation" | Only the typed word `discard` authorizes deletion. |
| "The PR is up, so the worktree is clutter now" | PR feedback gets fixed in that worktree. It stays until the work lands. |
| "This other worktree looks stale -- I'll clean it too" | Clean up only worktrees under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Branch and worktree stay put while you investigate. |
| "The base branch is obviously main" | Confirm the fork point or ask. Merging into the wrong base is expensive to undo. |
| "The push was rejected -- force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
| "I'll skip cleanup-workspace, the files aren't that important" | `.agent-harness/sdd/` accumulates dozens of brief/report/diff files across sessions. Always run cleanup-workspace after every option, including Keep As-Is. |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" -> ambiguous
- **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)

**Automatic branch cleanup**
- **Problem:** Remove work when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

**Forgetting SDD workspace cleanup**
- **Problem:** `.agent-harness/sdd/` accumulates dozens of brief/report/diff files across sessions
- **Fix:** Always run `cleanup-workspace` after every option, including Keep As-Is

**Running git worktree remove from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to main repo root before `git worktree remove`

**Cleaning up host-owned worktrees**
- **Problem:** Removing a worktree the host created causes phantom state
- **Fix:** Only clean up worktrees under `.worktrees/` or `worktrees/`

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Run `git worktree remove` from inside the worktree

**Always:**
- Verify tests before offering options
- Detect environment before presenting menu
- Present exactly 4 options (or 3 for detached HEAD)
- Get typed confirmation before any discard
- Clean up worktree for Option 1 and confirmed discards only
- `cd` to main repo root before worktree removal
- Run `git worktree prune` after removal
- Run SDD workspace cleanup after executing any option

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **executing-plans** (Step 5) - After all batches complete

**Calls:**
- **subagent-driven-development** cleanup script (`scripts/cleanup-workspace`) - Removes SDD workspace artifacts after branch completion
- **Step 6** provenance-based cleanup - Removes git worktree created by subagent-driven-development

**Pairs with:**
- **session-learnings** - Record insights discovered during this branch

## Capture Learnings

**Before completing**, reflect on what you learned during this branch:

- Did you discover a reusable pattern?
- Did you hit a pitfall that wasted time?
- Did the user state a preference you should remember?
- Did you find an undocumented project convention?

If yes, use the `session-learnings` skill to record it before finishing.
