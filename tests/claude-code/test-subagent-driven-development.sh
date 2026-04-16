#!/usr/bin/env bash
# Test: subagent-driven-development skill
# Verifies that the skill is loaded and follows correct workflow
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: subagent-driven-development skill ==="
echo ""

# Test 1: Verify skill can be loaded
echo "Test 1: Skill loading..."

output=$(run_claude "What is the subagent-driven-development skill? Describe its key steps briefly." 90)

if assert_contains "$output" "subagent-driven-development\|Subagent-Driven Development\|Subagent Driven" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Load Plan\|read.*plan\|extract.*tasks\|读取.*计划\|识别.*任务\|提取.*任务" "Mentions loading plan"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify skill describes correct workflow order
echo "Test 2: Workflow ordering..."

output=$(run_claude "In the subagent-driven-development skill, what comes first: spec compliance review or code quality review? Be specific about the order." 90)

if assert_contains "$output" "spec.*before.*code|spec.*prior.*code|规格.*先于.*质量|先.*spec.*再.*code|先.*规格.*再.*质量" "Spec compliance before code quality"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 3: Verify self-review is mentioned
echo "Test 3: Self-review requirement..."

output=$(run_claude "Does the subagent-driven-development skill require implementers to do self-review? What should they check?" 90)

if assert_contains "$output" "self-review\|self review" "Mentions self-review"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "completeness\|Completeness" "Checks completeness"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify plan is read once
echo "Test 4: Plan reading efficiency..."

output=$(run_claude "In subagent-driven-development, how many times should the controller read the plan file? When does this happen?" 90)

if assert_contains "$output" "once\|one time\|single" "Read plan once"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Step 1\|beginning\|start\|Load Plan" "Read at beginning"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify spec compliance reviewer is skeptical
echo "Test 5: Spec compliance reviewer mindset..."

output=$(run_claude "What is the spec compliance reviewer's attitude toward the implementer's report in subagent-driven-development?" 90)

if assert_contains "$output" "not trust\|don't trust\|skeptical\|verify.*independently\|suspiciously" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code" "Reviewer reads code"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify review loops
echo "Test 6: Review loop requirements..."

output=$(run_claude "In subagent-driven-development, what happens if a reviewer finds issues? Is it a one-time review or a loop?" 90)

if assert_contains "$output" "loop\|again\|repeat\|until.*approved\|until.*compliant" "Review loops mentioned"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "implementer.*fix\|fix.*issues" "Implementer fixes issues"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify full task text is provided
echo "Test 7: Task context provision..."

output=$(run_claude "In subagent-driven-development, how does the controller provide task information to the implementer subagent? Does it make them read a file or provide it directly?" 90)

if assert_contains "$output" "provide.*directly\|full.*text\|paste\|include.*prompt" "Provides text directly"; then
    : # pass
else
    exit 1
fi

if assert_not_contains "$output" "read.*file\|open.*file" "Doesn't make subagent read file"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 8: Verify worktree requirement
echo "Test 8: Worktree requirement..."

output=$(run_claude "What workflow skills are required before using subagent-driven-development? List any prerequisites or required skills." 90)

if assert_contains "$output" "using-git-worktrees\|worktree" "Mentions worktree requirement"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 9: Verify main branch warning
echo "Test 9: Main branch red flag..."

output=$(run_claude "In subagent-driven-development, is it okay to start implementation directly on the main branch?" 90)

if assert_contains "$output" "worktree\|feature.*branch\|not.*main\|never.*main\|avoid.*main\|don't.*main\|consent\|permission" "Warns against main branch"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 10: Verify explicit skill execution does not fail in wrapper
echo "Test 10: Explicit skill execution..."

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_DIR="$HOME/.claude/projects/$(echo "$REPO_ROOT" | sed 's#/#-#g')"
LATEST_SESSION_BEFORE=""
if [ -d "$SESSION_DIR" ]; then
    LATEST_SESSION_BEFORE=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1 || true)
fi

RALPH_STATE="$SCRIPT_DIR/../../.claude/ralph-loop.local.md"
RALPH_BACKUP=""
if [ -f "$RALPH_STATE" ]; then
    RALPH_BACKUP=$(mktemp)
    cp "$RALPH_STATE" "$RALPH_BACKUP"
    rm -f "$RALPH_STATE"
fi

cleanup_ralph_state() {
    if [ -n "$RALPH_BACKUP" ] && [ -f "$RALPH_BACKUP" ]; then
        mkdir -p "$(dirname "$RALPH_STATE")"
        mv "$RALPH_BACKUP" "$RALPH_STATE"
    fi
}
trap cleanup_ralph_state RETURN

output=$(run_claude "Use the superpowers:subagent-driven-development skill for this exact task: smoke test only. Do not implement code or create files; just start the workflow and report that it started." 90 all)
cleanup_ralph_state
trap - RETURN

LATEST_SESSION_AFTER=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1 || true)

if [ -z "$LATEST_SESSION_AFTER" ]; then
    echo "  [FAIL] Session transcript created"
    echo "  Could not find any session transcript in: $SESSION_DIR"
    exit 1
fi

if [ "$LATEST_SESSION_AFTER" = "$LATEST_SESSION_BEFORE" ]; then
    echo "  [WARN] Latest session transcript did not change; reusing most recent transcript"
fi

if grep -q '"name":"Skill".*"skill":"superpowers:subagent-driven-development"' "$LATEST_SESSION_AFTER"; then
    echo "  [PASS] Skill tool invoked"
else
    echo "  [FAIL] Skill tool invoked"
    echo "  Transcript: $LATEST_SESSION_AFTER"
    exit 1
fi

if grep -q 'Launching skill: superpowers:subagent-driven-development' "$LATEST_SESSION_AFTER"; then
    echo "  [PASS] Skill launch succeeded"
else
    echo "  [FAIL] Skill launch succeeded"
    echo "  Transcript: $LATEST_SESSION_AFTER"
    exit 1
fi

if grep -q 'Ralph loop activated in this session!' "$LATEST_SESSION_AFTER"; then
    echo "  [PASS] Ralph loop startup output captured"
else
    echo "  [FAIL] Ralph loop startup output captured"
    echo "  Transcript: $LATEST_SESSION_AFTER"
    exit 1
fi

if grep -q 'Shell command failed for pattern' "$LATEST_SESSION_AFTER"; then
    echo "  [FAIL] No shell wrapper failure"
    echo "  Transcript: $LATEST_SESSION_AFTER"
    exit 1
else
    echo "  [PASS] No shell wrapper failure"
fi

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
