#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: sprint-contract ==="
echo ""
run_skill "sprint-contract" "$SCRIPT_DIR/prompts/naive-define-done.txt" 3
assert_skill_triggered "sprint-contract"
assert_no_premature_action
assert_output_contains "definition of done\|acceptance\|criteria\|完成标准\|验收\|标准" "mentions DoD concepts"
print_skill_summary "sprint-contract"
