#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: writing-plans (naive) ==="
echo ""
run_skill "writing-plans" "$SCRIPT_DIR/prompts/naive-break-into-tasks.txt" 3
assert_skill_triggered "writing-plans"
assert_no_premature_action
assert_output_contains "task\|step\|file path\|verification\|任务\|步骤\|文件路径\|验证" "mentions plan structure"
assert_output_contains "tracer-bullet" "mentions tracer-bullet slices"
assert_output_contains "Blocking" "includes blocking dependencies"
assert_output_contains "Slice type" "includes slice type field"
assert_output_contains "Seam" "includes observable seam field"
assert_output_contains "expand-contract" "mentions expand-contract refactor path"
print_skill_summary "writing-plans (naive)"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: writing-plans (explicit) ==="
echo ""
run_skill "writing-plans" "$SCRIPT_DIR/prompts/explicit-invoke.txt" 3
assert_skill_triggered "writing-plans"
assert_no_premature_action
print_skill_summary "writing-plans (explicit)"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: writing-plans (full-stack pressure) ==="
echo ""
run_skill "writing-plans" "$SCRIPT_DIR/prompts/full-stack-pressure.txt" 3
assert_skill_triggered "writing-plans"
assert_no_premature_action
assert_output_contains "multiple plan\|separate plan\|directory-level\|execution map\|monolithic\|多个 plan\|执行图" "avoids monolithic full-stack plan"
assert_output_contains "confirmation gate\|testable outcome\|确认\|可测试" "keeps per-plan gate or outcome"
print_skill_summary "writing-plans (full-stack pressure)"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: writing-plans (hard gates pressure) ==="
echo ""
run_skill "writing-plans" "$SCRIPT_DIR/prompts/hard-gates-pressure.txt" 3
assert_skill_triggered "writing-plans"
assert_no_premature_action
assert_response_contains "Interfaces" "keeps interface planning"
assert_response_contains "Blocking" "keeps blocking field"
assert_response_contains "Slice type\|Slice-type" "keeps slice type field"
assert_response_contains "Seam" "keeps observable seam field"
assert_response_contains "GDD\|gate-driven-test-design" "keeps GDD gate"
assert_response_contains "contract\|Definition of Done" "keeps sprint contract gate"
assert_response_contains "knowledge.base\|index.md" "keeps knowledge-base lookup"
assert_response_contains "validate-handoff" "keeps structural validation"
print_skill_summary "writing-plans (hard gates pressure)"
