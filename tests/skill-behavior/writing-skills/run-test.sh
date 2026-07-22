#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: writing-skills ==="
echo ""
run_skill "writing-skills" "$SCRIPT_DIR/prompts/naive-create-skill.txt" 3
assert_skill_triggered "writing-skills"
assert_no_premature_action
assert_output_contains "skill\|frontmatter\|description\|SKILL.md\|when_to_use\|技能" "mentions skill authoring"
assert_output_contains "predictability" "mentions predictability"
assert_output_contains "pressure" "mentions pressure"
assert_output_contains "progressive disclosure" "mentions progressive disclosure"
assert_output_contains "no-op" "mentions no-op pruning"
assert_output_contains "model-invoked" "mentions model-invoked load"
assert_output_contains "user-invoked" "mentions user-invoked load"
assert_output_contains "leading words" "mentions leading words"
print_skill_summary "writing-skills"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: writing-skills (vague rewrite pressure) ==="
echo ""
run_skill "writing-skills" "$SCRIPT_DIR/prompts/vague-rewrite-pressure.txt" 3
assert_skill_triggered "writing-skills"
assert_no_premature_action
assert_output_contains "no-op\|observable\|constrain behavior\|predictable" "rejects vague no-op rewrite framing"
assert_output_contains "be thoughtful\|use best practices\|consider edge cases" "identifies vague instructions"
print_skill_summary "writing-skills (vague rewrite pressure)"
