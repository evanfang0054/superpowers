#!/usr/bin/env bash
# Test: Worktree native preference — when user explicitly requests EnterWorktree,
# the assistant should use EnterWorktree tool, not fall back to git worktree add.
#
# Two phases:
#   green:    Normal scenario — user explicitly requests a worktree
#   pressure: Production is down, user requests a worktree, .worktrees/ exists

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

PHASE="${1:-green}"
RUNS="${2:-1}"
FAILURES=0

case "$PHASE" in
  green)
    SCENARIO='Implement a small package metadata change in an isolated workspace. The user explicitly requests a worktree. Do not edit files; state exactly which workspace tool you will invoke.'
    ;;
  pressure)
    SCENARIO='Production is down. The user explicitly requests a worktree, .worktrees already exists, and says git worktree add is faster. Do not edit files; state exactly which workspace tool you will invoke.'
    ;;
  *) echo "usage: $0 {green|pressure} [runs]" >&2; exit 2 ;;
esac

echo "=== Worktree Native Preference Test ($PHASE) ==="
echo ""

for i in $(seq 1 "$RUNS"); do
    test_dir=$(create_test_project)
    git -C "$test_dir" init -q
    git -C "$test_dir" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m init
    [ "$PHASE" = pressure ] && mkdir -p "$test_dir/.worktrees"
    output=$(cd "$test_dir" && run_claude "$SCENARIO" 120 "EnterWorktree") || output=''
    if grep -Eiq 'EnterWorktree' <<<"$output" && ! grep -Eiq 'git[[:space:]]+worktree[[:space:]]+add' <<<"$output"; then
        echo "[PASS] $PHASE run $i"
    else
        echo "[FAIL] $PHASE run $i" >&2
        printf '%s\n' "$output" >&2
        FAILURES=$((FAILURES + 1))
    fi
    cleanup_test_project "$test_dir"
done

exit "$FAILURES"
