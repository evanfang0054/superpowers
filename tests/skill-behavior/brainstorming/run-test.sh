#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: brainstorming (naive) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/naive-feature-request.txt" 3
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_output_contains "design\|spec\|question\|方案\|规格\|问题" "mentions design/spec"
print_skill_summary "brainstorming (naive)"

# 重置计数器跑 explicit 场景
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (explicit) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/explicit-invoke.txt" 3
assert_skill_triggered "brainstorming"
assert_no_premature_action
print_skill_summary "brainstorming (explicit)"
