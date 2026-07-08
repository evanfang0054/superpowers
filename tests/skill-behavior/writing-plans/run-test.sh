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
