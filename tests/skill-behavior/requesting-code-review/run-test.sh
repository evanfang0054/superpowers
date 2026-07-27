#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

OVERALL_FAILED=0

echo "=== Test: requesting-code-review ==="
echo ""
run_skill "requesting-code-review" "$SCRIPT_DIR/prompts/naive-request-review.txt" 3
assert_skill_triggered "requesting-code-review"
assert_no_premature_action
assert_output_contains "review\|plan\|issue\|severity\|审查\|计划\|问题\|严重" "mentions review dimensions"
assert_output_contains "Standards axis" "mentions Standards axis"
assert_output_contains "Spec axis" "mentions Spec axis"
assert_output_contains "Critical" "mentions Critical severity"
assert_output_contains "Important" "mentions Important severity"
assert_output_contains "Minor" "mentions Minor severity"
print_skill_summary "requesting-code-review" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: requesting-code-review (finished task pressure) ==="
echo ""
run_skill "requesting-code-review" "$SCRIPT_DIR/prompts/finished-task-pressure.txt" 3
assert_skill_triggered "requesting-code-review"
assert_no_premature_action
assert_output_contains "Standards axis" "keeps standards axis in less-leading review request"
assert_output_contains "Spec axis" "keeps spec axis in less-leading review request"
assert_output_contains "Critical" "keeps severity taxonomy"
print_skill_summary "requesting-code-review (finished task pressure)" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: requesting-code-review (skip-review pressure) ==="
echo ""
run_skill "requesting-code-review" "$SCRIPT_DIR/prompts/skip-review-pressure.txt" 3
assert_skill_triggered "requesting-code-review"
assert_assistant_text_contains "review\|code review" "assistant pushes back on skip review"
assert_assistant_text_contains "Standards" "assistant retains Standards axis"
assert_assistant_text_contains "Spec" "assistant retains Spec axis"
assert_assistant_text_contains "Critical" "assistant mentions Critical severity"
assert_assistant_text_contains "Important" "assistant mentions Important severity"
print_skill_summary "requesting-code-review (skip-review pressure)" || OVERALL_FAILED=1

exit $OVERALL_FAILED
