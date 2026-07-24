#!/usr/bin/env bash
# sdd-worktree.sh -- SDD Fan-Out worktree lifecycle management
# Creates/removes isolated git worktrees for parallel implementers
# Usage: source sdd-worktree.sh
#
# Depends on: SDD_SESSION_ID (set by session-init.sh)

# Guard against direct execution: return only works in sourced context
(return 2>/dev/null) || {
  echo "error: sdd-worktree.sh is a library to be sourced, not executed directly" >&2
  echo "usage: source sdd-worktree.sh" >&2
  exit 1
}

# sdd_worktree_create <repo_root> <task_key> <base_branch>
# Output: worktree absolute path to stdout
sdd_worktree_create() {
  local repo_root="$1" task_key="$2" base_branch="$3"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_root="$repo_root/.claude/worktrees/sdd-$session_id"
  local wt_path="$wt_root/$task_key"
  local branch="_sdd/$session_id/$task_key"

  mkdir -p "$wt_root"

  if [ -d "$wt_path" ] && git -C "$wt_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "$wt_path"
    return 0
  fi

  local err
  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    err=$(git -C "$repo_root" worktree add -q "$wt_path" "$branch" 2>&1) || {
      echo "error: worktree add failed (branch $branch exists but worktree add failed)" >&2
      [ -n "$err" ] && echo "$err" >&2
      return 1
    }
  else
    err=$(git -C "$repo_root" worktree add -q -b "$branch" "$wt_path" "$base_branch" 2>&1) || {
      echo "error: worktree creation failed" >&2
      [ -n "$err" ] && echo "$err" >&2
      return 1
    }
  fi
  echo "$wt_path"
}

# sdd_worktree_remove <repo_root> <task_key> [--keep-branch]
# --keep-branch: remove worktree dir but keep the local branch (for intervention_needed)
sdd_worktree_remove() {
  local repo_root="$1" task_key="$2" keep_branch="${3:-}"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_path="$repo_root/.claude/worktrees/sdd-$session_id/$task_key"
  local branch="_sdd/$session_id/$task_key"

  [ -d "$wt_path" ] || return 0

  git -C "$repo_root" worktree remove --force "$wt_path" 2>/dev/null || rm -rf "$wt_path"
  if [ "$keep_branch" != "--keep-branch" ]; then
    git -C "$repo_root" branch -d "$branch" 2>/dev/null || true
  fi
}

# sdd_worktree_exists <repo_root> <task_key>
sdd_worktree_exists() {
  local repo_root="$1" task_key="$2"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_path="$repo_root/.claude/worktrees/sdd-$session_id/$task_key"
  [ -d "$wt_path" ] && git -C "$wt_path" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# sdd_cleanup_all_worktrees <repo_root> -- remove all worktrees for this session
sdd_cleanup_all_worktrees() {
  local repo_root="$1"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_root="$repo_root/.claude/worktrees/sdd-$session_id"
  if [ -d "$wt_root" ]; then
    for wt in "$wt_root"/*/; do
      [ -d "$wt" ] || continue
      git -C "$repo_root" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
    done
    rmdir "$wt_root" 2>/dev/null || true
  fi
}
