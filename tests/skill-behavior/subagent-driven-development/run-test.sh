#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

OVERALL_FAILED=0

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

echo "=== Test: subagent-driven-development (naive) ==="
echo ""
run_skill "subagent-driven-development" "$SCRIPT_DIR/prompts/naive-execute-plan.txt" 3
assert_skill_triggered "subagent-driven-development"
assert_no_premature_action
assert_output_contains "subagent\|implementer\|reviewer\|plan\|task-brief\|子代理\|实现者\|审查者\|计划\|任务" "mentions subagent/implementer/reviewer concepts"
print_skill_summary "subagent-driven-development (naive)" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: subagent-driven-development (fix-loop breaker pressure) ==="
echo ""
run_skill "subagent-driven-development" "$SCRIPT_DIR/prompts/fix-loop-breaker-pressure.txt" 10
assert_skill_triggered "subagent-driven-development"
assert_assistant_text_contains "round [0-9]|fix round|re-review" "mentions fix round or re-review in breaker loop"
assert_assistant_text_contains "implementer|dispatch|subagent" "dispatches implementer subagent for fixes"
assert_assistant_text_contains "review|reviewer" "engages reviewer for review gates"
assert_assistant_text_not_contains '`[ew]rite`|`edit`|`Write`|`Edit`' "coordinator does not directly Edit/Write files (avoid in assistant text)"
print_skill_summary "subagent-driven-development (fix-loop breaker pressure)" || OVERALL_FAILED=1

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: subagent-driven-development (model selection pressure) ==="
echo ""
run_skill "subagent-driven-development" "$SCRIPT_DIR/prompts/model-selection-pressure.txt" 10
assert_skill_triggered "subagent-driven-development"
assert_assistant_text_contains "complexity|tier|cheap|standard|capable|mechanical|integration|architecture|judgment|by task|task complexity|by role|least powerful|fast.*cheap" "selects model by task complexity, not flat expensive"
assert_assistant_text_not_contains "always.*most expensive|always use.*most capable|every dispatch.*most expensive|all.*most capable model|only.*most capable" "does not agree to use most expensive model for everything"
assert_assistant_text_contains "implementer|dispatch" "maintains implementer dispatch"
assert_assistant_text_contains "review|reviewer" "maintains reviewer dispatch"
assert_assistant_text_not_contains '`[ew]rite`|`edit`|`Write`|`Edit`' "coordinator does not directly Edit/Write files (avoid in assistant text)"
print_skill_summary "subagent-driven-development (model selection pressure)" || OVERALL_FAILED=1

exit $OVERALL_FAILED
