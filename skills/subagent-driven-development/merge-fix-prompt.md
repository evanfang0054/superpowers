# Merge-Fix Subagent Prompt Template

Use this template when `git merge --no-ff` produces conflict markers
that cannot be resolved automatically. The merge-fix subagent reads the
conflict and decides which version to keep.

```
Subagent (general-purpose):
  description: "Resolve merge conflict for task: [task name]"
  model: [MODEL — REQUIRED: choose per SKILL.md Model Selection; an omitted
         model silently inherits the session's most expensive one]
  prompt: |
    You are resolving a git merge conflict between two parallel implementer
    branches. Your job is to read the conflicted files, decide the correct
    resolution, and commit the merge.

    ## Context

    The merge target (orchestrator branch): [ORCH_BRANCH]
    The branch being merged: [MERGE_BRANCH]

    These two branches ran in parallel — they started from the same base
    commit and modified different (or sometimes overlapping) files.

    ## Conflicted Files

    Run `git diff --name-only --diff-filter=U` to list conflicted files.
    For each conflicted file:
    1. Read the file to see the conflict markers
    2. Understand what each side intended
    3. Decide the resolution:
       - Keep one side if the other is outdated
       - Combine both if they address different concerns
       - If truly incompatible, flag as UNSOLVABLE

    ## Resolution Rules

    - Prefer the implementer's version when both sides add similar code to
      the same area (the implementer branch has the intended change)
    - Keep changes from the orchestrator branch (i.e., previously merged
      tasks) when the implementer touched code it shouldn't have
    - If a file was deleted on one side and modified on the other, prefer
      keeping the modified version unless deletion was intentional

    ## Steps

    1. `git diff --name-only --diff-filter=U` — list conflicts
    2. For each conflicted file, read and resolve
    3. `git add <resolved-files>`
    4. `git commit --no-edit` (accepts the auto-generated merge message)

    If you cannot resolve (the conflict represents genuinely incompatible
    changes to the same logic), report back with status UNSOLVABLE and
    list each conflicted file with the incompatible change descriptions.
```
