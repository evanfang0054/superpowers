#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: Hooks Config ==="

# hooks.json 用 PascalCase（SessionStart, Stop）

# --- hooks.json (Claude Code) ---
CLAUDE_HOOKS="$REPO_ROOT/hooks/hooks.json"
assert_file_exists "$CLAUDE_HOOKS" "hooks.json exists"
if jq empty "$CLAUDE_HOOKS" 2>/dev/null; then pass "hooks.json is valid JSON"; else fail "hooks.json is valid JSON"; fi
if jq -e '.hooks.SessionStart' "$CLAUDE_HOOKS" >/dev/null 2>&1; then pass "hooks.json has SessionStart"; else fail "hooks.json has SessionStart"; fi
if jq -e '.hooks.Stop' "$CLAUDE_HOOKS" >/dev/null 2>&1; then pass "hooks.json has Stop"; else fail "hooks.json has Stop"; fi
if jq -e '.hooks.SessionStart[] | select(.matcher == "startup|clear|compact") | .hooks[] | select((.command == "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start" or (.command | endswith("\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start"))) and .shell == "bash")' "$CLAUDE_HOOKS" >/dev/null 2>&1; then
    pass "SessionStart uses run-hook.cmd session-start with bash shell"
else
    fail "SessionStart uses run-hook.cmd session-start with bash shell"
fi

# --- PreToolUse + SubagentStop (new in session-log-optimization) ---
if jq -e '.hooks.PreToolUse' "$CLAUDE_HOOKS" >/dev/null 2>&1; then
    pass "hooks.json has PreToolUse"
else
    fail "hooks.json has PreToolUse"
fi
if jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash")' "$CLAUDE_HOOKS" >/dev/null 2>&1; then
    pass "PreToolUse has Bash matcher"
else
    fail "PreToolUse has Bash matcher"
fi
if jq -e '.hooks.SubagentStop' "$CLAUDE_HOOKS" >/dev/null 2>&1; then
    pass "hooks.json has SubagentStop"
else
    fail "hooks.json has SubagentStop"
fi
# New scripts must exist and be executable
assert_executable "$REPO_ROOT/scripts/guard-staging.sh" "guard-staging.sh is executable"
assert_executable "$REPO_ROOT/scripts/audit-subagent.sh" "audit-subagent.sh is executable"

# 引用的脚本存在且有可执行位（两个 hooks 文件都引用这些）
assert_executable "$REPO_ROOT/hooks/session-start" "session-start is executable"
assert_executable "$REPO_ROOT/hooks/stop-hook.sh" "stop-hook.sh is executable"
assert_file_exists "$REPO_ROOT/hooks/run-hook.cmd" "run-hook.cmd exists"

print_summary "Hooks Config"
