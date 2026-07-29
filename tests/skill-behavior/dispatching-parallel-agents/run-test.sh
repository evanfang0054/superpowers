#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

echo "=== Test: dispatching-parallel-agents ==="
echo ""
run_skill "dispatching-parallel-agents" "$SCRIPT_DIR/prompts/naive-parallel-tasks.txt" 3
assert_skill_triggered "dispatching-parallel-agents"
assert_no_premature_action
assert_output_contains "parallel\|concurrent\|subagent\|independent\|并行\|并发\|子代理\|独立" "mentions parallel/concurrent/subagent concepts"
print_skill_summary "dispatching-parallel-agents"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: dispatching-parallel-agents (shared state pressure) ==="
echo ""
run_skill "dispatching-parallel-agents" "$SCRIPT_DIR/prompts/shared-state-pressure.txt" 3
assert_skill_triggered "dispatching-parallel-agents"
assert_no_premature_action
assert_response_contains "shared state\|same.*configuration\|same file" "blocks shared-state parallelism"
assert_response_contains "sequential" "requires sequential handling"
assert_response_contains "parallel\|concurrent" "keeps parallel dispatch rule for independent work"
print_skill_summary "dispatching-parallel-agents (shared state pressure)"
