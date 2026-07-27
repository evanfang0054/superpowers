#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

OVERALL_FAILED=0

echo "=== Test: writing-skills ==="
echo ""
run_skill "writing-skills" "$SCRIPT_DIR/prompts/naive-create-skill.txt" 3
assert_skill_triggered "writing-skills" || OVERALL_FAILED=1
assert_no_premature_action || OVERALL_FAILED=1
assert_output_contains "skill\|frontmatter\|description\|SKILL.md\|when_to_use\|技能" "mentions skill authoring" || OVERALL_FAILED=1
assert_output_contains "predictability" "mentions predictability" || OVERALL_FAILED=1
assert_output_contains "pressure" "mentions pressure" || OVERALL_FAILED=1
assert_output_contains "progressive disclosure" "mentions progressive disclosure" || OVERALL_FAILED=1
assert_output_contains "no-op" "mentions no-op pruning" || OVERALL_FAILED=1
assert_output_contains "model-invoked" "mentions model-invoked load" || OVERALL_FAILED=1
assert_output_contains "user-invoked" "mentions user-invoked load" || OVERALL_FAILED=1
assert_output_contains "leading words" "mentions leading words" || OVERALL_FAILED=1
print_skill_summary "writing-skills" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: writing-skills (vague rewrite pressure) ==="
echo ""
run_skill "writing-skills" "$SCRIPT_DIR/prompts/vague-rewrite-pressure.txt" 3
assert_skill_triggered "writing-skills" || OVERALL_FAILED=1
assert_no_premature_action || OVERALL_FAILED=1
assert_output_contains "no-op\|observable\|constrain behavior\|predictable" "rejects vague no-op rewrite framing" || OVERALL_FAILED=1
assert_output_contains "be thoughtful\|use best practices\|consider edge cases" "identifies vague instructions" || OVERALL_FAILED=1
print_skill_summary "writing-skills (vague rewrite pressure)" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: writing-skills (form failure pressure) ==="
echo ""
run_skill "writing-skills" "$SCRIPT_DIR/prompts/form-failure-pressure.txt" 3
assert_skill_triggered "writing-skills" || OVERALL_FAILED=1
assert_no_premature_action || OVERALL_FAILED=1
assert_assistant_text_contains "Match the Form|form.*failure|Right form|Wrong form" "matches form to failure type" || OVERALL_FAILED=1
assert_assistant_text_contains "micro-test|Micro-Test|microtest" "micro-tests wording before full scenarios" || OVERALL_FAILED=1
assert_assistant_text_contains "SDO|Skill Discovery Optimization" "uses SDO terminology" || OVERALL_FAILED=1
print_skill_summary "writing-skills (form failure pressure)" || OVERALL_FAILED=1

exit $OVERALL_FAILED
