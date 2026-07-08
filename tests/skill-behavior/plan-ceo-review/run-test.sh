#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: plan-ceo-review ==="
echo ""
run_skill "plan-ceo-review" "$SCRIPT_DIR/prompts/naive-ceo-review.txt" 3
assert_skill_triggered "plan-ceo-review"
assert_no_premature_action
assert_output_contains "scope\|premise\|10-star\|expand\|范围\|前提\|扩展" "mentions CEO review concepts"
print_skill_summary "plan-ceo-review"
