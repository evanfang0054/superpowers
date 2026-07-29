#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: finishing-a-development-branch ==="
echo ""
run_skill "finishing-a-development-branch" "$SCRIPT_DIR/prompts/naive-finish-branch.txt" 3
assert_skill_triggered "finishing-a-development-branch"
assert_no_premature_action
assert_output_not_contains() {
  local pattern="$1"
  local name="${2:-output does not contain pattern}"

  if [ -z "${LOG_FILE:-}" ] || [ ! -f "$LOG_FILE" ]; then
    _skill_fail "$name (log missing)"
  elif grep -Eqi "$pattern" "$LOG_FILE"; then
    _skill_fail "$name (pattern: $pattern)"
  else
    _skill_pass "$name"
  fi
}

assert_output_contains "new branch\|PR\|Keep\|保留\|新分支\|拉取请求" "offers detached-safe PR or Keep choices"
assert_output_contains "preserv\|保留\|retain" "states PR and Keep preserve branch, worktree, and artifacts"
assert_output_not_contains "Discard\|discard\|删除工作区\|删除.*worktree" "does not offer discard or deletion by default"
print_skill_summary "finishing-a-development-branch"
