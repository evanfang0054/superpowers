#!/usr/bin/env bash
# Test: SessionStart hook produces a cache-friendly prefix (issue #79).
#
# Anthropic prompt caching is prefix-match: any change before the cache
# breakpoint invalidates downstream cache. This test verifies:
#   1. Two consecutive startup invocations with identical inputs produce
#      byte-equal additionalContext output.
#   2. The using-agent-harness segment precedes the learnings segment so the
#      stable prefix is unaffected by per-session learnings churn.
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

# Assertion 2: using-agent-harness body precedes learnings in the stable prefix.
# (learnings may legitimately vary across runs; we only assert ordering.)
ua_line=$(echo "$OUT_1" | grep -n "using-agent-harness" | head -1 | cut -d: -f1)
learnings_line=$(echo "$OUT_1" | grep -n "Project Learnings" | head -1 | cut -d: -f1)
if [ -n "$ua_line" ] && [ -n "$learnings_line" ] && [ "$ua_line" -lt "$learnings_line" ]; then
    pass "using-agent-harness precedes Project Learnings (cache-friendly ordering)"
elif [ -n "$ua_line" ] && [ -z "$learnings_line" ]; then
    pass "using-agent-harness present; no learnings injected (still cache-safe)"
else
    fail "using-agent-harness should precede Project Learnings (ua=$ua_line learnings=$learnings_line)"
fi

# Assertion 3: learnings summary output is deterministic (no ts-derived date).
LEARNINGS_FILE="$REPO_ROOT/.agent-harness/learnings.jsonl"
if [ -f "$LEARNINGS_FILE" ]; then
    S1=$("$REPO_ROOT/scripts/search-learnings.sh" --summary 2>/dev/null || true)
    S2=$("$REPO_ROOT/scripts/search-learnings.sh" --summary 2>/dev/null || true)
    if [ "$S1" = "$S2" ]; then
        pass "search-learnings.sh --summary is byte-stable across two runs"
    else
        fail "search-learnings.sh --summary is byte-stable across two runs"
    fi
else
    pass "no learnings file present (skip summary determinism check)"
fi

rm -f "$MOCK_ENV_FILE"

print_summary "SessionStart Cache-Stable Prefix"
