#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: test-driven-development (naive) ==="
echo ""
run_skill "test-driven-development" "$SCRIPT_DIR/prompts/naive-tdd.txt" 3
assert_skill_triggered "test-driven-development"
assert_no_premature_action
assert_output_contains "red\|green\|refactor\|fail\|pass\|failing\|test\|红\|绿\|失败\|通过\|重构\|测试" "mentions TDD cycle"
print_skill_summary "test-driven-development (naive)"

# Reset counters for the explicit scenario.
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: test-driven-development (explicit) ==="
echo ""
run_skill "test-driven-development" "$SCRIPT_DIR/prompts/explicit-invoke.txt" 3
assert_skill_triggered "test-driven-development"
assert_no_premature_action
print_skill_summary "test-driven-development (explicit)"
