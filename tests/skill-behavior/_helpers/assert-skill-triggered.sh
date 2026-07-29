#!/usr/bin/env bash
# Assertion helpers for skill-behavior tests.
# Requires: $LOG_FILE set by run_skill before calling any assert.
# Usage (after `source`):
#   assert_skill_triggered "brainstorming"
#   assert_output_contains "design\|spec\|方案"
#   assert_no_premature_action
#   print_skill_summary "brainstorming"

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0
SKILL_CURRENT=""

_skill_pass() {
    echo "  [PASS] $1"
    SKILL_PASS_COUNT=$((SKILL_PASS_COUNT + 1))
}

_skill_fail() {
    echo "  [FAIL] $1"
    SKILL_FAIL_COUNT=$((SKILL_FAIL_COUNT + 1))
}

# assert_skill_triggered <skill-name>
assert_skill_triggered() {
    local skill="$1"
    SKILL_CURRENT="$skill"

    if [ -z "${LOG_FILE:-}" ] || [ ! -f "$LOG_FILE" ]; then
        _skill_fail "Skill '$skill' triggered (log missing: ${LOG_FILE:-unset})"
        return 1
    fi

    # 必须同时出现 "name":"Skill" 和 "skill":"agent-harness:<name>"
    if grep -q '"name":"Skill"' "$LOG_FILE" && \
       grep -q "\"skill\":\"agent-harness:${skill}\"" "$LOG_FILE"; then
        _skill_pass "Skill '$skill' triggered"
        return 0
    fi

    _skill_fail "Skill '$skill' triggered"
    echo "    Expected: \"name\":\"Skill\" + \"skill\":\"agent-harness:${skill}\"" >&2
    echo "    Actual skills in log:" >&2
    grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u | head -10 >&2
    return 1
}

# assert_output_contains <pattern> [test-name]
# Legacy full-log assertion. Use assert_response_contains for new behavior checks.
assert_output_contains() {
    local pattern="$1"
    local name="${2:-output contains pattern}"

    if [ -z "${LOG_FILE:-}" ] || [ ! -f "$LOG_FILE" ]; then
        _skill_fail "$name (log missing)"
        return 1
    fi

    if grep -q "$pattern" "$LOG_FILE"; then
        _skill_pass "$name"
        return 0
    fi
    _skill_fail "$name (pattern: $pattern)"
    return 1
}

# final_assistant_response: print only the final assistant text response from stream-json.
# This deliberately excludes the user prompt, tool inputs, and tool results.
final_assistant_response() {
    if [ -z "${LOG_FILE:-}" ] || [ ! -f "$LOG_FILE" ]; then
        return 1
    fi

    jq -r -s '
        [ .[]
          | select(.type == "assistant")
          | [ .message.content[]? | select(.type == "text") | .text ]
          | select(length > 0)
          | join("\n")
        ]
        | if length > 0 then last else empty end
    ' "$LOG_FILE"
}

# assert_response_contains <pattern> [test-name]
# Matches only the final assistant response, never fixture/tool payloads in the log.
assert_response_contains() {
    local pattern="$1"
    local name="${2:-response contains pattern}"
    local response

    response=$(final_assistant_response) || {
        _skill_fail "$name (log missing)"
        return 1
    }

    if printf '%s\n' "$response" | grep -qi "$pattern"; then
        _skill_pass "$name"
        return 0
    fi
    _skill_fail "$name (pattern: $pattern; final response only)"
    return 1
}

# assert_response_matches <perl-regex> [test-name]
# Supports multiline response invariants such as a numbered batch of questions.
assert_response_matches() {
    local pattern="$1"
    local name="${2:-response matches pattern}"
    local response

    response=$(final_assistant_response) || {
        _skill_fail "$name (log missing)"
        return 1
    }

    if printf '%s\n' "$response" | perl -0ne "exit 0 if /$pattern/; exit 1"; then
        _skill_pass "$name"
        return 0
    fi
    _skill_fail "$name (pattern: $pattern; final response only)"
    return 1
}

# assert_no_premature_action: Skill 调用前无非 TodoWrite/system 的 tool_use
assert_no_premature_action() {
    if [ -z "${LOG_FILE:-}" ] || [ ! -f "$LOG_FILE" ]; then
        _skill_fail "no premature action (log missing)"
        return 1
    fi

    local first_skill_line
    first_skill_line=$(grep -n '"name":"Skill"' "$LOG_FILE" | head -1 | cut -d: -f1)

    if [ -z "$first_skill_line" ]; then
        # 没有 Skill 调用，由 assert_skill_triggered 报告，这里跳过
        _skill_pass "no premature action (no skill call, skipped)"
        return 0
    fi

    # 检查 Skill 调用前是否有非 TodoWrite/system 的 tool_use
    local premature
    premature=$(head -n "$first_skill_line" "$LOG_FILE" \
        | grep '"type":"tool_use"' \
        | grep -v '"name":"Skill"' \
        | grep -v '"name":"TodoWrite"' \
        | grep -v '"name":"system"' \
        | head -3 || true)

    if [ -z "$premature" ]; then
        _skill_pass "no premature action before skill"
        return 0
    fi
    _skill_fail "no premature action before skill"
    echo "    Premature tool_use found:" >&2
    echo "$premature" | sed 's/^/      /' >&2
    return 1
}

# print_skill_summary <skill-name>
print_skill_summary() {
    local skill="$1"
    echo ""
    echo "=== $skill Summary ==="
    echo "Passed: $SKILL_PASS_COUNT"
    echo "Failed: $SKILL_FAIL_COUNT"
    if [ "$SKILL_FAIL_COUNT" -gt 0 ]; then
        echo "STATUS: FAILED"
        return 1
    fi
    echo "STATUS: PASSED"
    return 0
}
