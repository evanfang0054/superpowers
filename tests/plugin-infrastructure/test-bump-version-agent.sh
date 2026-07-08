#!/usr/bin/env bash
# Test: scripts/bump-version.sh agent-native path (--json / --dry-run / --yes / --notes / schema)
# Verifies envelope contract, write safety, schema self-introspection.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: bump-version.sh (agent-native) ==="

BUMP="$REPO_ROOT/scripts/bump-version.sh"
TEST_SANDBOX="/tmp/bump-version-agent-test-$$"
cleanup() { rm -rf "$TEST_SANDBOX"; }
trap cleanup EXIT

# 搭一个迷你 repo 沙盒，避免污染真实仓库
setup_sandbox() {
  rm -rf "$TEST_SANDBOX"; mkdir -p "$TEST_SANDBOX/scripts"
  cp "$BUMP" "$TEST_SANDBOX/scripts/bump-version.sh"
  chmod +x "$TEST_SANDBOX/scripts/bump-version.sh"
  cat > "$TEST_SANDBOX/.version-bump.json" <<'JSON'
{
  "files": [
    { "path": "package.json", "field": "version" },
    { "path": ".claude-plugin/plugin.json", "field": "version" }
  ],
  "audit": { "exclude": ["RELEASE-NOTES.md", "node_modules", ".git"] }
}
JSON
  mkdir -p "$TEST_SANDBOX/.claude-plugin"
  echo '{"version":"1.0.0"}' > "$TEST_SANDBOX/package.json"
  echo '{"version":"1.0.0"}' > "$TEST_SANDBOX/.claude-plugin/plugin.json"
  echo "# Release Notes" > "$TEST_SANDBOX/RELEASE-NOTES.md"
}

# --- Test 1: schema 自省输出合法 JSON ---
echo "--- Test 1: schema command ---"
OUT=$("$BUMP" schema)
if echo "$OUT" | jq -e '.commands.bump and .commands.check and .commands.audit and .commands.schema and .envelope_success and .envelope_error' >/dev/null 2>&1; then
  pass "schema outputs valid envelope contract"
else
  fail "schema outputs valid envelope contract"
fi

# --- Test 2: check --json 输出 envelope ---
echo "--- Test 2: check --json on sandbox ---"
setup_sandbox
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh check --json 2>/dev/null) && RC=$? || RC=$?
if [ "$RC" = "0" ] && echo "$OUT" | jq -e '.ok == true and .command == "check" and .data.status == "in_sync" and (.data.files | length) == 2' >/dev/null 2>&1; then
  pass "check --json returns in_sync envelope"
else
  fail "check --json returns in_sync envelope (rc=$RC, out=$OUT)"
fi

# --- Test 3: check --json 在 drift 时退出 2，envelope ok=true 但 status=drift ---
echo "--- Test 3: check --json detects drift ---"
setup_sandbox
echo '{"version":"1.0.1"}' > "$TEST_SANDBOX/.claude-plugin/plugin.json"
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh check --json 2>/dev/null) && RC=$? || RC=$?
if [ "$RC" = "2" ] && echo "$OUT" | jq -e '.ok == true and .data.status == "drift"' >/dev/null 2>&1; then
  pass "check --json reports drift with exit 2 + envelope"
else
  fail "check --json reports drift (rc=$RC, out=$OUT)"
fi

# --- Test 4: bump --dry-run --json --yes 不写盘 ---
echo "--- Test 4: bump --dry-run does not write ---"
setup_sandbox
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh bump 1.1.0 --dry-run --yes --json --notes "test bump" 2>/dev/null) && RC=$? || RC=$?
WRITTEN_VER=$(jq -r '.version' "$TEST_SANDBOX/package.json")
if [ "$RC" = "0" ] && [ "$WRITTEN_VER" = "1.0.0" ] && echo "$OUT" | jq -e '.data.dry_run == true and (.data.files_changed | length) == 2' >/dev/null 2>&1; then
  pass "dry-run leaves files unchanged + reports preview"
else
  fail "dry-run leaves files unchanged (package.json=$WRITTEN_VER, rc=$RC, out=$OUT)"
fi

# --- Test 5: bump --json --yes 实际写盘 ---
echo "--- Test 5: bump --yes writes files ---"
setup_sandbox
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh bump 1.2.0 --yes --json --notes "agent bump" 2>/dev/null) && RC=$? || RC=$?
PKG_VER=$(jq -r '.version' "$TEST_SANDBOX/package.json")
PLG_VER=$(jq -r '.version' "$TEST_SANDBOX/.claude-plugin/plugin.json")
if [ "$RC" = "0" ] && [ "$PKG_VER" = "1.2.0" ] && [ "$PLG_VER" = "1.2.0" ] && echo "$OUT" | jq -e '.data.new_version == "1.2.0"' >/dev/null 2>&1; then
  pass "bump --yes writes new version to all files"
else
  fail "bump --yes writes new version (pkg=$PKG_VER plg=$PLG_VER, rc=$RC)"
fi

# --- Test 6: 非 TTY 无 --yes 时写入被拒绝，exit 1 + not_a_tty ---
echo "--- Test 6: non-TTY write requires --yes ---"
setup_sandbox
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh bump 1.3.0 --json --notes "x" </dev/null 2>/dev/null) && RC=$? || RC=$?
WRITTEN_VER=$(jq -r '.version' "$TEST_SANDBOX/package.json")
if [ "$RC" = "1" ] && [ "$WRITTEN_VER" = "1.0.0" ] && echo "$OUT" | jq -e '.ok == false and .error.code == "not_a_tty"' >/dev/null 2>&1; then
  pass "non-TTY bump without --yes is rejected with not_a_tty"
else
  fail "non-TTY bump rejected (rc=$RC, pkg=$WRITTEN_VER, out=$OUT)"
fi

# --- Test 7: 非法版本号 → invalid_version envelope + exit 1 ---
echo "--- Test 7: invalid version rejected ---"
setup_sandbox
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh bump "not-a-version" --yes --json 2>/dev/null) && RC=$? || RC=$?
if [ "$RC" = "1" ] && echo "$OUT" | jq -e '.ok == false and .error.code == "invalid_version"' >/dev/null 2>&1; then
  pass "invalid version returns invalid_version envelope"
else
  fail "invalid version rejected (rc=$RC, out=$OUT)"
fi

# --- Test 8: 缺 config → missing_config envelope ---
echo "--- Test 8: missing config reported ---"
setup_sandbox
rm "$TEST_SANDBOX/.version-bump.json"
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh check --json 2>/dev/null) && RC=$? || RC=$?
if [ "$RC" = "1" ] && echo "$OUT" | jq -e '.ok == false and .error.code == "missing_config"' >/dev/null 2>&1; then
  pass "missing config returns missing_config envelope"
else
  fail "missing config reported (rc=$RC, out=$OUT)"
fi

# --- Test 9: --notes-file - 从 stdin 读 changelog ---
echo "--- Test 9: --notes-file - reads from stdin ---"
setup_sandbox
OUT=$(echo "stdin changelog line" | (cd "$TEST_SANDBOX" && ./scripts/bump-version.sh bump 1.4.0 --yes --json --notes-file - 2>/dev/null)) && RC=$? || RC=$?
if [ "$RC" = "0" ] && grep -q "stdin changelog line" "$TEST_SANDBOX/RELEASE-NOTES.md"; then
  pass "notes-file - reads changelog from stdin"
else
  fail "notes-file - reads changelog from stdin (rc=$RC)"
fi

# --- Test 10: audit --json 在 clean 时 status=clean ---
echo "--- Test 10: audit --json clean status ---"
setup_sandbox
OUT=$(cd "$TEST_SANDBOX" && ./scripts/bump-version.sh audit --json 2>/dev/null) && RC=$? || RC=$?
if [ "$RC" = "0" ] && echo "$OUT" | jq -e '.data.status == "clean"' >/dev/null 2>&1; then
  pass "audit --json reports clean"
else
  fail "audit --json reports clean (rc=$RC, out=$OUT)"
fi

print_summary "bump-version.sh (agent-native)"
