#!/usr/bin/env bash
# Static contracts for safe finishing and default execution isolation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FINISHING="$ROOT/skills/finishing-a-development-branch/SKILL.md"
EXECUTING="$ROOT/skills/executing-plans/SKILL.md"

PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
contains() { grep -Fq -- "$1" "$2"; }

assert_contains() {
  if contains "$2" "$1"; then pass "$3"; else fail "$3"; fi
}

assert_not_contains() {
  if contains "$2" "$1"; then fail "$3"; else pass "$3"; fi
}

assert_before() {
  local first last
  first=$(grep -nF -- "$2" "$1" | cut -d: -f1 | head -n1)
  last=$(grep -nF -- "$3" "$1" | cut -d: -f1 | head -n1)
  if [ -n "$first" ] && [ -n "$last" ] && [ "$first" -lt "$last" ]; then
    pass "$4"
  else
    fail "$4"
  fi
}

worktree_removals_are_guarded() {
  awk '
    /^# BEGIN owned-worktree-removal-guard$/ {
      if (in_guard) {
        print "nested ownership guard"
        exit 1
      }
      in_guard = 1
      guard_count++
      next
    }
    /^# END owned-worktree-removal-guard$/ {
      if (!in_guard) {
        print "ownership guard ends before it begins"
        exit 1
      }
      in_guard = 0
      next
    }
    /^[[:space:]]*git[[:space:]]+worktree[[:space:]]+remove([[:space:]]|$)/ {
      if (in_guard) {
        guarded_removals++
      } else {
        print "unguarded git worktree remove at line " NR
        exit 1
      }
    }
    END {
      if (guard_count != 1 || in_guard) {
        print "missing or unterminated ownership guard"
        exit 1
      }
      if (guarded_removals != 1) {
        print "ownership guard must contain exactly one git worktree remove command"
        exit 1
      }
    }
  ' "$1"
}

assert_owned_removal_guard() {
  local result
  result=$(worktree_removals_are_guarded "$1" 2>&1)
  if [ $? -eq 0 ]; then
    pass "$2"
  else
    fail "$2: $result"
  fi
}

assert_rejects_unguarded_flagged_removal() {
  local fixture
  fixture=$(mktemp)
  trap 'rm -f "$fixture"' RETURN
  printf '%s\n' \
    '# BEGIN owned-worktree-removal-guard' \
    'git worktree remove "$WORKTREE_PATH"' \
    '# END owned-worktree-removal-guard' \
    'git worktree remove --force "$WORKTREE_PATH"' > "$fixture"

  if worktree_removals_are_guarded "$fixture" >/dev/null 2>&1; then
    fail "$1"
  else
    pass "$1"
  fi
}

assert_contains "$FINISHING" 'GIT_DIR=' 'captures GIT_DIR'
assert_contains "$FINISHING" 'GIT_COMMON=' 'captures GIT_COMMON'
assert_contains "$FINISHING" 'WORKTREE_PATH=' 'captures WORKTREE_PATH'
assert_before "$FINISHING" 'WORKTREE_PATH=' 'cd <base-branch>' 'captures worktree path before changing directories'
assert_owned_removal_guard "$FINISHING" 'guards every git worktree remove command with delimited ownership guard'
assert_rejects_unguarded_flagged_removal 'rejects an unguarded flagged worktree removal'
assert_contains "$FINISHING" '"$PROJECT_ROOT"/.worktrees/*|"$PROJECT_ROOT"/worktrees/*)' 'guard uses exact slash-delimited owned path patterns'
assert_contains "$FINISHING" 'Preserving non-project-owned worktree:' 'guard preserves unmatched worktrees'
assert_contains "$FINISHING" 'if [[ "$GIT_COMMON" = /* ]]; then' 'resolves absolute GIT_COMMON'
assert_contains "$FINISHING" 'PROJECT_ROOT=$(dirname "$GIT_COMMON")' 'derives project root from absolute GIT_COMMON'
assert_contains "$FINISHING" 'PROJECT_ROOT=$(cd "$(dirname "$GIT_COMMON")" && pwd)' 'resolves relative GIT_COMMON'
assert_contains "$FINISHING" 'Implementation complete. What would you like to do?' 'provides finishing menu'
assert_not_contains "$FINISHING" '4. Discard this work' 'default menu excludes discard'
assert_not_contains "$FINISHING" 'cleanup-workspace' 'finishing options do not clean SDD artifacts'
assert_contains "$FINISHING" 'Type `discard` to confirm.' 'requires exact discard confirmation'
assert_contains "$FINISHING" 'STOP. Keep the branch and worktree for investigation.' 'stops after merge verification failure'
assert_contains "$FINISHING" 'PR and Keep preserve all branch, worktree, and SDD artifacts.' 'preserves artifacts for PR and Keep'
assert_contains "$EXECUTING" 'User specified a branch: execute on that branch.' 'uses specified branch'
assert_contains "$EXECUTING" 'User did not specify an isolation location: create an independent branch before executing.' 'defaults to independent branch'
assert_contains "$EXECUTING" 'User explicitly requested a worktree: create or enter that worktree.' 'uses worktrees only when requested'
assert_contains "$EXECUTING" 'Without an explicit worktree request: do not use a worktree.' 'forbids implicit worktrees'
assert_not_contains "$EXECUTING" 'using-git-worktrees' 'does not reference deleted worktree skill'

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
