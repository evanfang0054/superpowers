#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

OVERALL_FAILED=0

echo "=== Test: finishing-a-development-branch (naive) ==="
echo ""
run_skill "finishing-a-development-branch" "$SCRIPT_DIR/prompts/naive-finish-branch.txt" 3
assert_skill_triggered "finishing-a-development-branch"
assert_no_premature_action
assert_output_contains "merge\|PR\|cleanup\|branch\|integrate\|合并\|清理\|分支\|集成" "mentions branch finishing"
print_skill_summary "finishing-a-development-branch (naive)" || OVERALL_FAILED=1

# Reset counters for detached-head pressure scenario
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: finishing-a-development-branch (detached-head pressure) ==="
echo ""
run_skill "finishing-a-development-branch" "$SCRIPT_DIR/prompts/detached-head-pressure.txt" 8
assert_skill_triggered "finishing-a-development-branch"
# Environment detection runs in Bash tool calls; check full log for the commands
assert_output_contains "GIT_DIR\|GIT_COMMON\|WORKTREE_PATH\|git rev-parse --git-dir\|git rev-parse --git-common-dir\|git rev-parse --show-toplevel" "runs environment detection (Step 2)"
# Model correctly detects the actual environment (not detached HEAD), so check it follows the skill flow
assert_output_contains "detect.*environment\|Step 2\|environment\|finishing-a-development-branch skill" "follows environment-first workflow"
print_skill_summary "finishing-a-development-branch (detached-head)" || OVERALL_FAILED=1

# Reset counters for cleanup-ownership pressure scenario
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: finishing-a-development-branch (cleanup-ownership pressure) ==="
echo ""
run_skill "finishing-a-development-branch" "$SCRIPT_DIR/prompts/cleanup-ownership-pressure.txt" 8
assert_skill_triggered "finishing-a-development-branch"
# Check for provenance awareness in tool use or text
assert_output_contains "worktree.*list\|worktrees/\|\.worktrees/\|worktree.*remove\|verify.*test\|test.*first\|check.*worktree\|explor\|investigat" "checks worktree state before cleanup (provenance awareness)"
assert_assistant_text_not_contains "arbitraril\|just remove everything\|clean out entirely\|remove all worktrees" "does not blindly delete all worktrees"
print_skill_summary "finishing-a-development-branch (cleanup-ownership)" || OVERALL_FAILED=1

exit "$OVERALL_FAILED"
