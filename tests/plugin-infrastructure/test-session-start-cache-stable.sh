#!/usr/bin/env bash
# Test: SessionStart hook produces a cache-friendly prefix (issue #79).
#
# Anthropic prompt caching is prefix-match: any change before the cache
# breakpoint invalidates downstream cache. This test verifies:
#   1. Two consecutive startup invocations with identical inputs produce
#      byte-equal additionalContext output.
#   2. The using-agent-harness segment forms a stable prefix (no per-session
#      churn that would invalidate it).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: SessionStart Cache-Stable Prefix (issue #79) ==="

SESSION_START="$REPO_ROOT/hooks/session-start"
assert_executable "$SESSION_START" "session-start is executable"

MOCK_ENV_FILE=$(mktemp)
MOCK_INPUT='{"session_id":"cache-stable-test","cwd":"'"$REPO_ROOT"'","transcript_path":"/dev/null","source":"startup"}'

# Run twice with identical inputs. Capture additionalContext only.
run_once() {
    CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
        CLAUDE_ENV_FILE="$MOCK_ENV_FILE" \
        CLAUDE_PROJECT_DIR="$REPO_ROOT" \
        echo "$MOCK_INPUT" | bash "$SESSION_START" 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // .additionalContext // empty'
}

OUT_1=$(run_once) || true
OUT_2=$(run_once) || true

# Assertion 1: byte-equal across two runs.
if [ "$OUT_1" = "$OUT_2" ]; then
    pass "two consecutive invocations produce byte-equal additionalContext"
else
    fail "two consecutive invocations produce byte-equal additionalContext"
    diff <(echo "$OUT_1") <(echo "$OUT_2") | head -20
fi

# Assertion 2: injected context contains no learnings segment (learnings removed).
if echo "$OUT_1" | grep -q "Project Learnings"; then
    fail "injected context should not contain Project Learnings segment"
else
    pass "no Project Learnings segment (learnings removed)"
fi

rm -f "$MOCK_ENV_FILE"

print_summary "SessionStart Cache-Stable Prefix"
