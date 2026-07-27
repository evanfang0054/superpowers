#!/usr/bin/env bash
# Codex plugin manifest 一致性测试
# 验证 .codex-plugin/plugin.json 与仓库其他元数据一致、引用的资源都存在
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MANIFEST="$REPO_ROOT/.codex-plugin/plugin.json"
PACKAGE_JSON="$REPO_ROOT/package.json"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-to-codex-plugin.sh"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

grep_ok() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if grep -q "$pattern" "$file"; then
        pass "$desc"
    else
        fail "$desc"
        echo "    pattern not found: $pattern"
    fi
}

grep_not_ok() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if ! grep -q "$pattern" "$file"; then
        pass "$desc"
    else
        fail "$desc"
        echo "    pattern should not exist: $pattern"
    fi
}

assert_exists() {
    local path="$1"
    local desc="$2"
    if [[ -e "$path" ]]; then
        pass "$desc"
    else
        fail "$desc (路径不存在: $path)"
    fi
}

assert_executable() {
    local path="$1"
    local desc="$2"
    if [[ -x "$path" ]]; then
        pass "$desc"
    else
        fail "$desc (不可执行: $path)"
    fi
}

assert_contains() {
    local output="$1"
    local pattern="$2"
    local desc="$3"
    if echo "$output" | grep -q -F -- "$pattern"; then
        pass "$desc"
    else
        fail "$desc"
        echo "    pattern not found: $pattern"
    fi
}

assert_json_eq() {
    local actual="$1"
    local expected="$2"
    local desc="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc"
        echo "    expected: $expected"
        echo "    actual:   $actual"
    fi
}

assert_valid_json() {
    local path="$1"
    local desc="$2"
    if jq -e . "$path" >/dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

echo "=== Test: sync-to-codex-plugin.sh 存在性与品牌一致性 ==="

# 1. 源脚本存在且可执行
assert_exists "$SYNC_SCRIPT" "sync-to-codex-plugin.sh 存在"
assert_executable "$SYNC_SCRIPT" "sync-to-codex-plugin.sh 可执行"

# 2. --help 包含 --dry-run
HELP_OUTPUT="$("$SYNC_SCRIPT" --help 2>&1 || true)"
assert_contains "$HELP_OUTPUT" "--dry-run" "--help 输出含 --dry-run"

# 3. 源脚本无 .superpowers 残留（品牌一致性）
grep_not_ok "$SYNC_SCRIPT" '\.superpowers' "源脚本无 .superpowers 文本残留"

# 4. 源脚本含 .agent-harness 品牌引用
grep_ok "$SYNC_SCRIPT" 'agent-harness' "源脚本含 agent-harness 品牌引用"

# 5. 源脚本含 /.pi/ 排除规则（pi 扩展不泄漏）
grep_ok "$SYNC_SCRIPT" '"/\.pi/"' "源脚本含 /.pi/ 排除规则"

# 6. 源脚本引用 skills/hooks/agents 同步路径
grep_ok "$SYNC_SCRIPT" 'skills' "源脚本引用 skills 目录"
grep_ok "$SYNC_SCRIPT" 'hooks' "源脚本引用 hooks 目录"
grep_ok "$SYNC_SCRIPT" 'agents' "源脚本引用 agents 目录"

echo "=== Test: Codex plugin manifest 一致性 ==="

# 1. manifest 存在
assert_exists "$MANIFEST" "Codex plugin manifest 存在"

# 2. manifest 的 skills 字段指向存在的目录
SKILLS_DIR="$REPO_ROOT/$(jq -r .skills "$MANIFEST")"
assert_exists "$SKILLS_DIR" "manifest.skills 指向的目录存在"

# 3. manifest 的 hooks 字段固定指向有效的 Codex hook 配置
HOOKS_PATH=$(jq -r .hooks "$MANIFEST")
assert_json_eq "$HOOKS_PATH" "./hooks/hooks-codex.json" "manifest.hooks 指向 Codex hook 配置"
HOOKS_FILE="$REPO_ROOT/$HOOKS_PATH"
assert_exists "$HOOKS_FILE" "manifest.hooks 指向的文件存在"
assert_valid_json "$HOOKS_FILE" "manifest.hooks 指向有效 JSON"
SESSION_START_COMMAND=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS_FILE")
if [[ "$SESSION_START_COMMAND" == *"session-start-codex"* ]]; then
    pass "SessionStart command 指向 session-start-codex"
else
    fail "SessionStart command 指向 session-start-codex"
    echo "    actual:   $SESSION_START_COMMAND"
fi

# 4. manifest 的 composerIcon 引用存在
COMPOSER_ICON="$REPO_ROOT/$(jq -r '.interface.composerIcon' "$MANIFEST")"
assert_exists "$COMPOSER_ICON" "manifest.interface.composerIcon 引用存在"

# 5. manifest 的 logo 引用存在
LOGO="$REPO_ROOT/$(jq -r '.interface.logo' "$MANIFEST")"
assert_exists "$LOGO" "manifest.interface.logo 引用存在"

# 6. manifest 的 version 与 package.json 的 version 一致（防漂移）
MANIFEST_VERSION=$(jq -r .version "$MANIFEST")
PACKAGE_VERSION=$(jq -r .version "$PACKAGE_JSON")
assert_json_eq "$MANIFEST_VERSION" "$PACKAGE_VERSION" "manifest version 与 package.json version 一致"

# 7. manifest 的 name 与 package.json 的 name 一致且保留本地品牌
MANIFEST_NAME=$(jq -r .name "$MANIFEST")
PACKAGE_NAME=$(jq -r .name "$PACKAGE_JSON")
assert_json_eq "$MANIFEST_NAME" "$PACKAGE_NAME" "manifest name 与 package.json name 一致"
assert_json_eq "$MANIFEST_NAME" "agent-harness" "manifest name 保留 agent-harness 品牌"

# 8. marketplace category 使用批准终态
CATEGORY=$(jq -r '.interface.category' "$MANIFEST")
assert_json_eq "$CATEGORY" "Developer Tools" "interface.category 使用 Developer Tools"

# 9. 必填字段不为空
DISPLAY_NAME=$(jq -r '.interface.displayName' "$MANIFEST")
if [[ -n "$DISPLAY_NAME" && "$DISPLAY_NAME" != "null" ]]; then
    pass "interface.displayName 非空"
else
    fail "interface.displayName 非空 (实际值: $DISPLAY_NAME)"
fi

echo "=== Test: Codex hook bootstrap 生命周期匹配 ==="

# 1. matcher 包含 startup
MATCHER_VALUE=$(jq -r '.hooks.SessionStart[0].matcher' "$HOOKS_FILE")
if echo "$MATCHER_VALUE" | grep -q "startup"; then
    pass "matcher 包含 startup"
else
    fail "matcher 包含 startup"
fi

# 2. matcher 包含 clear
if echo "$MATCHER_VALUE" | grep -q "clear"; then
    pass "matcher 包含 clear"
else
    fail "matcher 包含 clear"
fi

# 3. matcher 包含 compact
if echo "$MATCHER_VALUE" | grep -q "compact"; then
    pass "matcher 包含 compact"
else
    fail "matcher 包含 compact"
fi

# 4. matcher 不含 resume（防止重复注入）
if echo "$MATCHER_VALUE" | grep -q "resume"; then
    fail "matcher 不应包含 resume"
else
    pass "matcher 不含 resume"
fi

# 5. command 只引用一次 session-start-codex（无重复注入）
COMMAND_COUNT=$(jq '[.hooks.SessionStart[] | .hooks[] | select(.command | contains("session-start-codex"))] | length' "$HOOKS_FILE")
assert_json_eq "$COMMAND_COUNT" "1" "SessionStart command 只引用一次 session-start-codex"

# 6. session-start-codex 输出合法 JSON 且 bootstrap 内容只出现一次
SESSION_START_OUTPUT=$("$REPO_ROOT/hooks/session-start-codex" 2>&1 || true)
if echo "$SESSION_START_OUTPUT" | jq -e . >/dev/null 2>&1; then
    pass "session-start-codex 输出合法 JSON"
else
    fail "session-start-codex 输出合法 JSON"
fi

BOOTSTRAP_COUNT=$(echo "$SESSION_START_OUTPUT" | grep -c "EXTREMELY_IMPORTANT" || true)
if [[ "$BOOTSTRAP_COUNT" -eq 1 ]]; then
    pass "bootstrap 内容只出现一次"
else
    fail "bootstrap 内容只出现一次 (实际: $BOOTSTRAP_COUNT)"
fi

if [[ $FAILURES -ne 0 ]]; then
    echo ""
    echo "FAILED: $FAILURES assertion(s) failed."
    exit 1
fi

echo ""
echo "PASS"
