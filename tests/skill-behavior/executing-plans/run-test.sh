#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: executing-plans ==="
echo ""
run_skill "executing-plans" "$SCRIPT_DIR/prompts/naive-execute-batched.txt" 3
assert_skill_triggered "executing-plans"
assert_no_premature_action
assert_output_contains "batch\|checkpoint\|review\|task\|iterative\|批次\|检查点\|审查\|任务\|迭代" "mentions batch/checkpoint/review concepts"
print_skill_summary "executing-plans"
