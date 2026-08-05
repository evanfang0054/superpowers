#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: brainstorming (naive) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/naive-feature-request.txt" 3
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_output_contains "design\|spec\|question\|方案\|规格\|问题" "mentions design/spec"
print_skill_summary "brainstorming (naive)"

# 重置计数器跑 explicit 场景
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (explicit) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/explicit-invoke.txt" 3
assert_skill_triggered "brainstorming"
assert_no_premature_action
print_skill_summary "brainstorming (explicit)"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (YAGNI approach pressure) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/yagni-approach-pressure.txt" 5
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_response_contains "focused\|smallest\|narrow\|current user" "removes unnecessary approach features"
assert_response_matches '(?ms)(?:^|\n)\s*1\..*?\?(?=.*(?:^|\n)\s*2\..*?\?)' "asks at least two clarification questions in one numbered batch"
print_skill_summary "brainstorming (YAGNI approach pressure)"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (Assumption Audit) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/assumption-audit.txt" 5
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_response_contains "assumption\|假设\|✅\|❓" "surfaces an assumption ledger"
print_skill_summary "brainstorming (Assumption Audit)"
