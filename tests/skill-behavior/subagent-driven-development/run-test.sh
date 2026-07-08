#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

# Prepare a fake plan so the path referenced in the prompt really exists.
cat > /tmp/skill-behavior-fake-plan.md <<'PLAN'
# Fake Plan for Skill Behavior Test

## Task 1: Add hello function
Create src/hello.js that exports a function returning "Hello, World!".

## Task 2: Add goodbye function
Create src/goodbye.js that exports a function returning "Goodbye, World!".

## Task 3: Wire them together
Create src/index.js that re-exports both hello and goodbye.
PLAN

echo "=== Test: subagent-driven-development ==="
echo ""
run_skill "subagent-driven-development" "$SCRIPT_DIR/prompts/naive-execute-plan.txt" 3
assert_skill_triggered "subagent-driven-development"
assert_no_premature_action
assert_output_contains "subagent\|implementer\|reviewer\|plan\|task-brief\|子代理\|实现者\|审查者\|计划\|任务" "mentions subagent/implementer/reviewer concepts"
print_skill_summary "subagent-driven-development"
