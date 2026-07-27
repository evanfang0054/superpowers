#!/usr/bin/env bash
# Regression check: SDD workspace paths use local .claude/worktrees/ paths,
# not upstream .superpowers/sdd/ brand. Finishing-a-development-branch cleanup
# uses project-local patterns, not upstream global paths.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FINISHING="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
WORKTREE="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-worktree.sh"
FAILURES=0

contains() { grep -Fq "$2" "$1" || { echo "[FAIL] missing '$2' in $1" >&2; FAILURES=$((FAILURES + 1)); }; }
absent() { ! grep -Fq "$2" "$1" || { echo "[FAIL] unexpected '$2' in $1" >&2; FAILURES=$((FAILURES + 1)); }; }

echo "=== Worktree Path Policy Test ==="
echo ""

contains "$FINISHING" '`.worktrees/` or `worktrees/`'
for anchor in session-init.sh sdd-state.sh sdd-worktree.sh merge-fix-prompt.md; do contains "$SDD" "$anchor"; done
contains "$WORKTREE" '.claude/worktrees'
absent "$FINISHING" '~/.config/superpowers/worktrees'
absent "$SDD" '.superpowers/sdd/'
absent "$WORKTREE" '.superpowers/sdd/'

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "STATUS: FAILED ($FAILURES failures)"
    exit "$FAILURES"
fi
echo "STATUS: PASSED"
