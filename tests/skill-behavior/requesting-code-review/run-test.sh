#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

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
print_skill_summary "requesting-code-review"

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
print_skill_summary "requesting-code-review (finished task pressure)"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: requesting-code-review (reviewer context isolation pressure) ==="
echo ""
run_skill "requesting-code-review" "$SCRIPT_DIR/prompts/reviewer-context-isolation-pressure.txt" 3
assert_skill_triggered "requesting-code-review"
assert_no_premature_action
assert_response_contains "requirements\|Definition of Done\|DoD" "passes requirements or DoD"
assert_response_contains "BASE_SHA" "passes base SHA"
assert_response_contains "HEAD_SHA" "passes head SHA"
assert_response_contains "brief" "passes task brief"
assert_response_contains "report" "passes task report"
assert_response_contains "package" "uses review package"
assert_response_contains "do not send.*session\|will not send.*session\|can.t send.*session\|not.*send.*session\|not.*session.*reasoning\|不.*\(传递\|发送\).*会话" "rejects coordinator session history"
assert_response_contains "do not send.*inline diff\|will not send.*inline diff\|can.t send.*inline diff\|not.*send.*inline diff\|not.*inline diff\|不.*\(传递\|发送\).*\(inline diff\|内联.*差异\)" "rejects inline review diff"
assert_response_contains "Return format\|findings only\|findings-only" "returns findings-only review output"
assert_response_contains "Standards" "returns Standards findings category"
assert_response_contains "Spec" "returns Spec findings category"
print_skill_summary "requesting-code-review (reviewer context isolation pressure)"
