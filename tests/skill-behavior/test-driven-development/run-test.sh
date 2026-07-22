#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

assert_output_not_contains() {
    local pattern="$1"
    local name="${2:-output does not contain pattern}"

    if [ -z "${LOG_FILE:-}" ] || [ ! -f "$LOG_FILE" ]; then
        _skill_fail "$name (log missing)"
        return 1
    fi

    if grep -q "$pattern" "$LOG_FILE"; then
        _skill_fail "$name (pattern: $pattern)"
        return 1
    fi
    _skill_pass "$name"
    return 0
}

echo "=== Test: test-driven-development (naive) ==="
echo ""
run_skill "test-driven-development" "$SCRIPT_DIR/prompts/naive-tdd.txt" 3
assert_skill_triggered "test-driven-development"
assert_no_premature_action
assert_output_contains "red\|green\|refactor\|fail\|pass\|failing\|test\|红\|绿\|失败\|通过\|重构\|测试" "mentions TDD cycle"
assert_output_contains "seam" "identifies seam concept"
assert_output_contains "observable" "identifies observable boundary"
assert_output_contains "Do not create test-only public APIs" "forbids test-only public APIs"
assert_output_not_contains "test the private helper directly" "does not test private helper directly"
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

# Reset counters for the less-leading private-helper seam scenario.
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: test-driven-development (private helper pressure) ==="
echo ""
run_skill "test-driven-development" "$SCRIPT_DIR/prompts/private-helper-pressure.txt" 3
assert_skill_triggered "test-driven-development"
assert_no_premature_action
assert_output_contains "seam" "identifies seam concept without explicit seam prompt"
assert_output_contains "CLI\|command\|filename\|file" "chooses observable CLI/file behavior boundary"
assert_output_not_contains "test the .*helper directly" "does not test helper directly"
print_skill_summary "test-driven-development (private helper pressure)"
