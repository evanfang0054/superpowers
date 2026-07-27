#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: plan-eng-review ==="
echo ""
run_skill "plan-eng-review" "$SCRIPT_DIR/prompts/naive-eng-review.txt" 3
assert_skill_triggered "plan-eng-review"
assert_no_premature_action
assert_output_contains "architecture\|edge case\|test coverage\|data flow\|架构\|边界\|测试覆盖\|数据流" "mentions eng review dimensions"
print_skill_summary "plan-eng-review"
