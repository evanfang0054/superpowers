#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

OVERALL_FAILED=0

echo "=== Test: writing-good-tests (naive) ==="
run_skill "writing-good-tests" "$SCRIPT_DIR/prompts/naive.txt" 3
assert_skill_triggered "writing-good-tests" || OVERALL_FAILED=1
assert_no_premature_action || OVERALL_FAILED=1
assert_assistant_text_contains "name.*break|exercise.*real|names the break|exercises the real thing" "mentions two principles" || OVERALL_FAILED=1
print_skill_summary "writing-good-tests (naive)" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0; SKILL_FAIL_COUNT=0
echo ""
echo "=== Test: writing-good-tests (explicit) ==="
run_skill "writing-good-tests" "$SCRIPT_DIR/prompts/explicit.txt" 3
assert_skill_triggered "writing-good-tests" || OVERALL_FAILED=1
assert_no_premature_action || OVERALL_FAILED=1
print_skill_summary "writing-good-tests (explicit)" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0; SKILL_FAIL_COUNT=0
echo ""
echo "=== Test: writing-good-tests (pressure) ==="
run_skill "writing-good-tests" "$SCRIPT_DIR/prompts/pressure.txt" 4
assert_skill_triggered "writing-good-tests" || OVERALL_FAILED=1
assert_no_premature_action || OVERALL_FAILED=1
assert_assistant_text_contains "real|integration|end-to-end|actual|mock at the right|exercise the real|name the break|mock only|mock.*slow" "rejects mock-only pressure" || OVERALL_FAILED=1
print_skill_summary "writing-good-tests (pressure)" || OVERALL_FAILED=1

exit "$OVERALL_FAILED"
