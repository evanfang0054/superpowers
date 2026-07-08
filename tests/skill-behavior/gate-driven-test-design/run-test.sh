#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: gate-driven-test-design ==="
echo ""
run_skill "gate-driven-test-design" "$SCRIPT_DIR/prompts/naive-derive-coverage.txt" 3
assert_skill_triggered "gate-driven-test-design"
assert_no_premature_action
assert_output_contains "gate\|coverage\|risk\|assertion\|门\|覆盖\|风险\|断言" "mentions gate/coverage concepts"
print_skill_summary "gate-driven-test-design"
