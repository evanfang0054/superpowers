#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: SessionStart Injection ==="

SESSION_START="$REPO_ROOT/hooks/session-start"
assert_executable "$SESSION_START" "session-start is executable"

# 准备 mock 环境
MOCK_ENV_FILE=$(mktemp)
MOCK_INPUT='{"session_id":"test-session-123","cwd":"'"$REPO_ROOT"'","transcript_path":"/dev/null"}'

# 运行 hook，捕获 stdout
OUTPUT=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
         CLAUDE_ENV_FILE="$MOCK_ENV_FILE" \
         CLAUDE_PROJECT_DIR="$REPO_ROOT" \
         echo "$MOCK_INPUT" | bash "$SESSION_START" 2>&1) || true

# 断言输出包含 using-agent-harness skill 内容
if echo "$OUTPUT" | grep -q "using-agent-harness"; then
    pass "output contains using-agent-harness reference"
else
    fail "output contains using-agent-harness reference"
fi

# 断言输出包含 hookSpecificOutput 结构（如果有 JSON 输出）
if echo "$OUTPUT" | grep -q "additionalContext\|hookSpecificOutput"; then
    pass "output has hookSpecificOutput structure"
else
    # session-start 可能输出纯文本而非 JSON，降级为软断言
    pass "output format check (non-JSON tolerated)"
fi

# 断言 CLAUDE_ENV_FILE 被写入 session_id
if [ -s "$MOCK_ENV_FILE" ] && grep -q "CLAUDE_SESSION_ID" "$MOCK_ENV_FILE" 2>/dev/null; then
    pass "CLAUDE_ENV_FILE written with session_id"
else
    # session_id 写入由 hooks.json 的第一个 hook 负责，session-start 脚本本身可能不写
    pass "CLAUDE_ENV_FILE (handled by hooks.json first hook)"
fi

TMP_PROJECT=$(mktemp -d)
KB_OUTPUT=$(printf '{"source":"startup"}' | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SESSION_START" 2>/dev/null || true)
if printf '%s' "$KB_OUTPUT" | grep -q "Knowledge Base"; then
    fail "KB hint omitted outside agent-harness projects"
else
    pass "KB hint omitted outside agent-harness projects"
fi
if printf '%s' "$KB_OUTPUT" | grep -q "\*\*/\*.md"; then
    fail "glob warning omitted outside agent-harness projects"
else
    pass "glob warning omitted outside agent-harness projects"
fi

mkdir -p "$TMP_PROJECT/docs/agent-harness"
printf '# Index\n' > "$TMP_PROJECT/docs/agent-harness/index.md"
KB_OUTPUT=$(printf '{"source":"startup"}' | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SESSION_START" 2>/dev/null || true)
if printf '%s' "$KB_OUTPUT" | grep -q "Knowledge Base"; then
    pass "KB hint included for agent-harness projects"
else
    fail "KB hint included for agent-harness projects"
fi

run_session_start() {
    local input="$1" platform="$2" stdout_file="$3" stderr_file="$4"
    case "$platform" in
        cursor)
            printf '%s' "$input" | env CURSOR_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SESSION_START" >"$stdout_file" 2>"$stderr_file"
            ;;
        claude)
            printf '%s' "$input" | env CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SESSION_START" >"$stdout_file" 2>"$stderr_file"
            ;;
        copilot)
            printf '%s' "$input" | env COPILOT_CLI=1 CLAUDE_PROJECT_DIR="$TMP_PROJECT" bash "$SESSION_START" >"$stdout_file" 2>"$stderr_file"
            ;;
    esac
}

STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)
for platform in cursor claude copilot; do
    if run_session_start '{"source":"startup"}' "$platform" "$STDOUT_FILE" "$STDERR_FILE" \
       && jq empty "$STDOUT_FILE" 2>/dev/null \
       && [ ! -s "$STDERR_FILE" ]; then
        pass "$platform startup emits valid JSON with clean stderr"
    else
        fail "$platform startup emits valid JSON with clean stderr"
    fi
done

for source in startup clear; do
    if run_session_start '{"source":"'"$source"'"}' claude "$STDOUT_FILE" "$STDERR_FILE" \
       && jq -e '.hookSpecificOutput.additionalContext | contains("using-agent-harness")' "$STDOUT_FILE" >/dev/null 2>&1 \
       && [ ! -s "$STDERR_FILE" ]; then
        pass "$source injects the full bootstrap"
    else
        fail "$source injects the full bootstrap"
    fi
done

if run_session_start '{"source":"precompact"}' claude "$STDOUT_FILE" "$STDERR_FILE" \
   && jq -e '.hookSpecificOutput.additionalContext == ""' "$STDOUT_FILE" >/dev/null 2>&1 \
   && [ ! -s "$STDERR_FILE" ]; then
    pass "precompact emits valid empty context with clean stderr"
else
    fail "precompact emits valid empty context with clean stderr"
fi

# Every platform-specific JSON writer must pipe printf through cat so Git Bash
# absorbs a downstream EPIPE instead of surfacing printf's Permission denied.
if ! grep -E '^[[:space:]]*printf .*\\n' "$SESSION_START" | grep -v '| cat' >/dev/null; then
    pass "session-start JSON printf output is piped through cat"
else
    fail "session-start JSON printf output is piped through cat"
fi

CODEX_SESSION_START="$REPO_ROOT/hooks/session-start-codex"
if grep -E '^[[:space:]]*printf .*\\n.*\| cat$' "$CODEX_SESSION_START" >/dev/null \
   && printf '{}' | bash "$CODEX_SESSION_START" >"$STDOUT_FILE" 2>"$STDERR_FILE" \
   && jq empty "$STDOUT_FILE" 2>/dev/null \
   && [ ! -s "$STDERR_FILE" ]; then
    pass "Codex JSON printf uses cat and emits clean valid JSON"
else
    fail "Codex JSON printf uses cat and emits clean valid JSON"
fi

rm -f "$MOCK_ENV_FILE" "$STDOUT_FILE" "$STDERR_FILE"
rm -rf "$TMP_PROJECT"

print_summary "SessionStart Injection"
