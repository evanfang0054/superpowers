#!/usr/bin/env bash
# Test: precompact checkpoint behavior (issue #81).
#
# When a session compacts, the hook should write a recovery checkpoint to
# .agent-harness/last-session-checkpoint.md. On the next startup, the hook
# should surface a pointer to that checkpoint and then delete it (one-shot).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: Precompact Checkpoint (issue #81) ==="

SESSION_START="$REPO_ROOT/hooks/session-start"
assert_executable "$SESSION_START" "session-start is executable"

# Use an isolated temp project dir so we don't touch the real .agent-harness.
TMP_PROJECT=$(mktemp -d)
mkdir -p "$TMP_PROJECT/.agent-harness"
CKPT_FILE="$TMP_PROJECT/.agent-harness/last-session-checkpoint.md"

# --- Step 1: simulate precompact → should create checkpoint ---
PRECOMPACT_INPUT='{"session_id":"ckpt-test","cwd":"'"$TMP_PROJECT"'","source":"precompact"}'
MOCK_ENV_FILE=$(mktemp)
CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_ENV_FILE="$MOCK_ENV_FILE" \
    CLAUDE_PROJECT_DIR="$TMP_PROJECT" \
    bash "$SESSION_START" <<<"$PRECOMPACT_INPUT" >/dev/null 2>&1 || true

if [ -f "$CKPT_FILE" ]; then
    pass "precompact source writes last-session-checkpoint.md"
else
    fail "precompact source writes last-session-checkpoint.md"
fi

if grep -q "Trigger: precompact" "$CKPT_FILE" 2>/dev/null; then
    pass "checkpoint file contains precompact trigger marker"
else
    fail "checkpoint file contains precompact trigger marker"
fi

# --- Step 2: simulate next startup → should surface hint and delete checkpoint ---
STARTUP_INPUT='{"session_id":"ckpt-test-2","cwd":"'"$TMP_PROJECT"'","source":"startup"}'
STARTUP_OUT=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_ENV_FILE="$MOCK_ENV_FILE" \
    CLAUDE_PROJECT_DIR="$TMP_PROJECT" \
    bash "$SESSION_START" <<<"$STARTUP_INPUT" 2>/dev/null || true)

if echo "$STARTUP_OUT" | grep -q "Prior Session Checkpoint"; then
    pass "startup surfaces checkpoint recovery hint"
else
    fail "startup surfaces checkpoint recovery hint"
fi

# Checkpoint should be consumed (one-shot).
if [ ! -f "$CKPT_FILE" ]; then
    pass "checkpoint file deleted after one-shot surfacing"
else
    fail "checkpoint file deleted after one-shot surfacing (still exists)"
fi

# --- Step 3: a further startup with no checkpoint should not mention it ---
STARTUP_OUT_2=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
    CLAUDE_ENV_FILE="$MOCK_ENV_FILE" \
    CLAUDE_PROJECT_DIR="$TMP_PROJECT" \
    bash "$SESSION_START" <<<"$STARTUP_INPUT" 2>/dev/null || true)

if echo "$STARTUP_OUT_2" | grep -q "Prior Session Checkpoint"; then
    fail "startup re-surfaces consumed checkpoint (should be one-shot)"
else
    pass "startup does not re-surface consumed checkpoint"
fi

rm -rf "$TMP_PROJECT" "$MOCK_ENV_FILE"

print_summary "Precompact Checkpoint"
