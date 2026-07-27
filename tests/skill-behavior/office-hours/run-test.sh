#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: office-hours ==="
echo ""
run_skill "office-hours" "$SCRIPT_DIR/prompts/naive-build-decision.txt" 3
assert_skill_triggered "office-hours"
assert_no_premature_action
assert_output_contains "demand\|status quo\|wedge\|worth\|需求\|是否值得\|值得做" "mentions decision framework"
print_skill_summary "office-hours"
