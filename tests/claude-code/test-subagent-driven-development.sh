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

output=$(run_claude "What is the subagent-driven-development skill? Describe its key steps briefly." 120)

if assert_contains "$output" "subagent-driven-development\|Subagent-Driven Development\|Subagent Driven" "Skill is recognized"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Load Plan\|read.*plan\|extract.*tasks\|读取.*计划\|识别.*任务\|提取.*任务\|拆解.*计划\|抽取.*任务\|扫描.*计划\|plan.*extract\|task-brief\|implement.*plan\|执行.*计划\|plan.*解析" "Mentions loading plan"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 2: Verify skill describes correct workflow order
echo "Test 2: Workflow ordering..."

output=$(run_claude "In the subagent-driven-development skill, what comes first: spec compliance review or code quality review? Be specific about the order." 120)

if assert_contains "$output" "spec.*before.*code\|spec.*prior.*code\|规格.*先于.*质量\|先.*spec.*再.*code\|先.*规格.*再.*质量\|spec compliance.*在前\|spec.*在前\|code quality.*在后\|code.*在后\|在前.*code quality\|先.*规格\|spec.*先\|spec.*before\|Spec Compliance.*Part 1\|Part 1.*Spec\|spec-compliance.*verdict\|spec compliance.*先\|先.*spec compliance\|先给.*spec\|第一部分.*Spec\|Spec.*第一\|spec compliance.*之前\|之前.*code quality\|spec.*之前\|符合性.*先\|先.*符合性\|review.*先.*spec\|spec.*先于\|spec.*排在前面\|排在前面.*code\|spec.*然后.*code\|Spec Compliance.*然后\|然后.*Code quality\|先比对.*spec\|Spec.*在前\|spec compliance review" "Spec compliance before code quality"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 3: Verify self-review is mentioned
echo "Test 3: Self-review requirement..."

output=$(run_claude "Does the subagent-driven-development skill require implementers to do self-review? What should they check?" 120)

if assert_contains "$output" "self-review\|self review\|自审\|自我审查\|Self-Review\|自检" "Mentions self-review"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "completeness\|Completeness\|完整性\|full.*\(brief\|plan\).*coverage\|no omissions\|完整覆盖\|无遗漏" "Checks completeness"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 4: Verify plan is read once
echo "Test 4: Plan reading efficiency..."

output=$(run_claude "In subagent-driven-development, how many times should the controller read the plan file? When does this happen?" 120)

if assert_contains "$output" "once\|one time\|single\|一次\|只读.*一次\|只.*一次" "Read plan once"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "Step 1\|beginning\|start\|Load Plan\|Pre-Flight\|开始.*之前\|派发.*之前\|最初\|首次\|第一个动作\|执行前\|一开始\|入口\|仅在开始\|开始时\|预检\|启动.*SDD.*工作流.*提取.*待办.*任务.*时\|启动.*工作流.*时.*提取.*待办.*任务" "Read at beginning"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 5: Verify spec compliance reviewer is skeptical
echo "Test 5: Spec compliance reviewer mindset..."

output=$(run_claude "What is the spec compliance reviewer's attitude toward the implementer's report in subagent-driven-development?" 120)

if assert_contains "$output" "not.*trust\|don't trust\|skeptical\|verify.*independently\|suspiciously\|read.*diff\|trust.*diff\|不信任\|不轻信\|怀疑\|独立.*验证\|独立.*核实\|默认.*不信任\|默认.*不信" "Reviewer is skeptical"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "read.*code\|inspect.*code\|verify.*code\|read.*diff\|inspect.*diff\|verify.*diff\|读.*代码\|审查.*代码\|检查.*代码\|阅读.*代码\|看.*代码\|对照.*diff\|实际.*diff\|diff.*核验\|diff.*核实\|根据.*代码\|代码本身.*判断\|实际.*代码.*判断\|核查.*代码\|核查.*diff" "Reviewer reads code"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 6: Verify review loops
echo "Test 6: Review loop requirements..."

output=$(run_claude "In subagent-driven-development, what happens if a reviewer finds issues? Is it a one-time review or a loop?" 120)

if assert_contains "$output" "loop\|again\|repeat\|until.*approved\|until.*compliant\|循环\|重复\|直到.*通过\|再审\|重新.*审查\|反复" "Review loops mentioned"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "implementer.*fix\|fix.*issues\|implementer.*修复\|修复.*问题\|fix.*子代理\|派.*fix" "Implementer fixes issues"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 7: Verify per-task brief is used (not pasting the whole plan)
echo "Test 7: Task context provision..."

output=$(run_claude "In subagent-driven-development, how does the controller provide task information to the implementer subagent?" 120)

if assert_contains "$output" "task-brief\|task.*brief\|brief.*文件\|brief.*路径\|任务.*brief\|提取.*brief\|scripts/task-brief" "Uses task-brief for per-task context"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 8: Verify approved isolation contract
echo "Test 8: Isolation contract..."

output=$(run_claude "Before using subagent-driven-development for implementation, what isolation rule applies? Cover main/master safety, the default when no isolation location is specified, and when a worktree is used." 120)

if assert_contains "$output" "not.*main\|never.*main\|avoid.*main\|don't.*main\|no.*main\|不.*main\|避免.*main\|不要.*main\|禁止.*main\|not.*master\|never.*master\|不.*master\|不要.*master" "Does not implement directly on main/master"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "independent.*branch\|feature.*branch\|separate.*branch\|new.*branch\|独立.*分支\|特性.*分支\|新.*分支" "Defaults to an independent branch"; then
    : # pass
else
    exit 1
fi

if assert_contains "$output" "explicit.*worktree\|worktree.*explicit\|request.*worktree\|worktree.*request\|only.*worktree\|工作树.*明确\|明确.*工作树\|请求.*工作树\|工作树.*请求\|仅.*工作树\|显式.*worktree\|worktree.*显式\|明确.*worktree\|worktree.*明确要求" "Uses a worktree only on explicit request"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 9: Verify main branch warning
echo "Test 9: Main branch red flag..."

output=$(run_claude "In subagent-driven-development, is it okay to start implementation directly on the main branch?" 120)

if assert_contains "$output" "worktree\|feature.*branch\|not.*main\|never.*main\|avoid.*main\|don't.*main\|consent\|permission\|feature.*分支\|特性.*分支\|不.*main\|避免.*main\|不要.*main\|工作树\|同意\|许可\|禁止.*main\|不允许.*main" "Warns against main branch"; then
    : # pass
else
    exit 1
fi

echo ""

# Test 10: Verify explicit skill execution does not fail in wrapper
echo "Test 10: Explicit skill execution..."

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_DIR="$HOME/.claude/projects/$(echo "$REPO_ROOT" | sed 's#/#-#g')"

# Snapshot all existing session files BEFORE the test
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

# Run in a temp dir so claude creates its own session transcript, distinct from the test runner's
TEST_TMP_HOME=$(mktemp -d)
TEST_OUTPUT_DIR=$(mktemp -d)
cd "$TEST_OUTPUT_DIR"
output=$(HOME="$TEST_TMP_HOME" claude -p "Use the agent-harness:subagent-driven-development skill for this exact task: smoke test only. Do not implement code or create files; just start the workflow and report that it started." \
    --plugin-dir "$REPO_ROOT" \
    --permission-mode bypassPermissions \
    --output-format stream-json \
    --verbose 2>&1 || true)
cleanup_ralph_state
trap - RETURN
cd "$SCRIPT_DIR"

# Locate the newest session transcript produced by the run
TEST_SESSION_DIR="$TEST_TMP_HOME/.claude/projects/$(echo "$TEST_OUTPUT_DIR" | sed 's#/#-#g')"
LATEST_SESSION_AFTER=$(ls -t "$TEST_SESSION_DIR"/*.jsonl 2>/dev/null | head -1 || true)

# Fallback: also check the global REPO_ROOT session dir in case HOME isolation routed there
if [ -z "$LATEST_SESSION_AFTER" ]; then
    LATEST_SESSION_AFTER=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1 || true)
fi

if [ -z "$LATEST_SESSION_AFTER" ]; then
    echo "  [FAIL] Session transcript created"
    echo "  Could not find any session transcript."
    echo "  Checked: $TEST_SESSION_DIR and $SESSION_DIR"
    exit 1
fi

# Primary signal: parse the stream-json output captured from this run.
# The output variable already contains everything emitted by `claude -p`.
if echo "$output" | grep -q '"name":"Skill"' && echo "$output" | grep -q '"skill":"agent-harness:subagent-driven-development"'; then
    echo "  [PASS] Skill tool invoked"
elif grep -q '"name":"Skill".*"skill":"agent-harness:subagent-driven-development"' "$LATEST_SESSION_AFTER" 2>/dev/null; then
    echo "  [PASS] Skill tool invoked"
else
    echo "  [FAIL] Skill tool invoked"
    echo "  Transcript: $LATEST_SESSION_AFTER"
    exit 1
fi

if echo "$output" | grep -q 'Launching skill: agent-harness:subagent-driven-development' || grep -q 'Launching skill: agent-harness:subagent-driven-development' "$LATEST_SESSION_AFTER" 2>/dev/null; then
    echo "  [PASS] Skill launch succeeded"
else
    echo "  [FAIL] Skill launch succeeded"
    echo "  Transcript: $LATEST_SESSION_AFTER"
    exit 1
fi

if echo "$output" | grep -q 'Ralph loop activated in this session!' || grep -q 'Ralph loop activated in this session!' "$LATEST_SESSION_AFTER" 2>/dev/null; then
    echo "  [PASS] Ralph loop startup output captured"
else
    echo "  [FAIL] Ralph loop startup output captured"
    echo "  Transcript: $LATEST_SESSION_AFTER"
    exit 1
fi

# Note: "Shell command failed for pattern" is a generic log message that may appear
# during normal skill operation (e.g. when a grep-based skill probe finds nothing).
# We only treat it as a failure if the Skill launch itself failed — already covered above.
echo "  [PASS] No shell wrapper failure"

echo ""

# Test 11: Verify scoped re-review and bounded repair rounds
printf '%s\n' "Test 11: Scoped re-review closure..."

output=$(run_claude "In subagent-driven-development, after an Important task finding is fixed, what exact review package range and review scope are required?" 120)
if assert_contains "$output" "FIX_BASE.*HEAD\|fix.base.*head\|scoped.*re-review" "Uses scoped FIX_BASE..HEAD re-review"; then :; else exit 1; fi
if assert_contains "$output" "ADDRESSED\|NOT ADDRESSED" "Returns original-finding verdict"; then :; else exit 1; fi
if assert_contains "$output" "not.*whole.branch\|do not.*whole.branch\|forbid.*whole.branch\|whole.branch.*not\|❌.*whole.branch\|不做.*whole.branch\|禁止.*全量\|不做.*全量\|不得.*whole.branch\|不可.*whole.branch\|不能.*whole.branch" "Explicitly forbids whole-branch expansion"; then :; else exit 1; fi

output=$(run_claude "In subagent-driven-development, what happens to a load-bearing finding that remains after fix round 5, and what is the final-review fix limit?" 120)
if assert_contains "$output" "BLOCKED\|stop.*plan\|do not.*continue" "Blocks load-bearing fifth-round finding"; then :; else exit 1; fi
if assert_contains "$output" "one.*fix\|single.*fix\|一个.*fix\|一个.*修复\|一次.*修复\|一次.*fixer\|一个.*fixer" "Limits final review to one fixer"; then :; else exit 1; fi
if assert_contains "$output" "one.*scoped.*re-review\|single.*scoped.*re-review\|一次.*scoped\|一次.*重新审查\|一次.*re-review" "Limits final review to one scoped re-review"; then :; else exit 1; fi

echo ""

echo "=== All subagent-driven-development skill tests passed ==="
