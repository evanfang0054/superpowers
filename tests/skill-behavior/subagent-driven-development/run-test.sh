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

run_pressure() {
    local prompt="$1"
    run_skill "subagent-driven-development" "$SCRIPT_DIR/prompts/$prompt" 3
    assert_skill_triggered "subagent-driven-development"
}

# v6.2 pressure scenarios: every load-bearing contract has its own assertion.
# Do not reset the shared counters here: a failed early scenario must fail this suite.
run_pressure "scoped-rereview-pressure.txt"
assert_output_contains "FIX_BASE.*HEAD\|fix.base.*head" "scoped re-review uses FIX_BASE..HEAD"
assert_output_contains "scoped.*re-review\|re-review.*scoped" "scoped re-review stays task-local"
assert_output_contains "ADDRESSED\|NOT ADDRESSED" "scoped re-review gives original-finding verdict"
assert_output_contains "not.*whole.branch\|do not.*whole.branch\|forbid.*whole.branch\|whole.branch.*not" "scoped re-review explicitly forbids whole-branch expansion"

run_pressure "fourth-round-pressure.txt"
assert_output_contains "round.*4\|fourth" "fourth round is identified"
assert_output_contains "fresh.*implementer\|new.*implementer" "fourth round uses a fresh implementer"
assert_output_contains "stronger\|higher.*tier\|tier.*higher\|highest.*tier" "fourth round uses a stronger model tier"

run_pressure "fifth-round-blocked-pressure.txt"
assert_output_contains "load-bearing" "fifth-round rule distinguishes load-bearing findings"
assert_output_contains "BLOCKED" "load-bearing fifth-round finding is recorded BLOCKED"
assert_output_contains "stop.*(dispatch|plan|execution)\|do not.*(dispatch|continue)\|not.*continue" "BLOCKED finding stops subsequent dispatch"

run_pressure "final-review-pressure.txt"
assert_output_contains "one.*fix\|single.*fix\|sole.*fixer" "final review permits one fixer"
assert_output_contains "one.*scoped.*re-review\|single.*scoped.*re-review" "final review permits one scoped re-review"
assert_output_contains "no.*second.*fix\|do not.*second.*fix\|never.*second.*fix\|not.*second.*wave" "final review forbids a second fix wave"

run_pressure "ledger-identity-pressure.txt"
assert_output_contains "first line.*exact\|exact.*first line\|exactly.*# SDD ledger" "ledger recovery requires exact first-line identity"
assert_output_contains "match.*restore\|match.*resume\|restore.*match\|resume.*match\|Restoration.*match" "matching ledger identity may restore state"
assert_output_contains "must not be restored\|not valid state\|not used to recover\|ignore.*state" "mismatched ledger does not restore old state"
assert_output_contains "initialize a new ledger\|new ledger" "mismatched ledger initializes a new ledger"
assert_output_contains "git clean -fdx.*Git history\|Git history.*git clean -fdx" "git clean recovery relies on Git history"
assert_output_contains "not.*automatic\|no.*automatic\|does not.*automatic" "git clean recovery makes no automatic-restore promise"

print_skill_summary "subagent-driven-development"
