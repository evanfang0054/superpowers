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

# Reset counters for the helper test-design pressure scenario.
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: test-driven-development (helper production-break pressure) ==="
echo ""
run_skill "test-driven-development" "$SCRIPT_DIR/prompts/helper-production-break-pressure.txt" 3
assert_skill_triggered "test-driven-development"
assert_no_premature_action
assert_output_contains "seam\|observable" "chooses observable seam before the test"
assert_output_contains "production break\|break.*production\|would break\|break.*test" "names a production break"
assert_output_contains "literal\|fixture\|independent\|expected" "uses an independently known expected value"
assert_output_contains "fail\|failing\|red\|失败" "requires a failing test first"
print_skill_summary "test-driven-development (helper production-break pressure)"

# Reset counters for the source-text pressure scenario.
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: test-driven-development (source-text pressure) ==="
echo ""
run_skill "test-driven-development" "$SCRIPT_DIR/prompts/source-text-pressure.txt" 3
assert_skill_triggered "test-driven-development"
assert_no_premature_action
assert_output_contains "seam\|observable" "chooses observable seam before the test"
assert_output_contains "run\|execut\|output\|side effect\|exit" "tests runtime behavior instead of source text"
assert_output_not_contains "assert.*source.*contains.*--safe-mode\|source.*assert.*contains.*--safe-mode" "does not endorse source-text assertion"
assert_output_contains "fail\|failing\|red\|失败" "requires a failing test first"
print_skill_summary "test-driven-development (source-text pressure)"

# Reset counters for the mock-boundary pressure scenario.
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: test-driven-development (mock-boundary pressure) ==="
echo ""
run_skill "test-driven-development" "$SCRIPT_DIR/prompts/mock-boundary-pressure.txt" 3
assert_skill_triggered "test-driven-development"
assert_no_premature_action
assert_output_contains "seam\|observable" "chooses observable seam before the test"
assert_output_contains "real behavior\|behavior" "tests real behavior rather than mock calls"
assert_output_contains "do not.*mock.*call\|not.*mock.*call\|not.*assert.*mock\|refuse.*mock" "rejects internal mock-call assertion"
assert_output_contains "integration" "uses integration test when mocks are complex"
assert_output_contains "test-only.*API\|test-only.*method\|not add.*cleanup\|do not.*cleanup" "rejects production cleanup API"
assert_output_contains "fail\|failing\|red\|失败" "requires a failing test first"
print_skill_summary "test-driven-development (mock-boundary pressure)"
