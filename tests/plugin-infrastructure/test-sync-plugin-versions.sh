#!/usr/bin/env bash
# test-sync-plugin-versions.sh — verify sync-plugin-versions.sh syncs + detects drift
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC="$REPO_ROOT/scripts/sync-plugin-versions.sh"

PASS=0; FAIL=0
assert() { if eval "$1" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $2"; fi; }

# Test 1: --check passes on real repo (all manifests at 6.4.4)
"$SYNC" --check >/dev/null 2>&1
assert '[ $? -eq 0 ]' "--check exits 0 when all 4 files in sync"

# Test 2: sandbox — sync writes package.json version to 3 manifests
TMP=$(mktemp -d)
mkdir -p "$TMP/scripts" "$TMP/.claude-plugin" "$TMP/.codex-plugin"
cp "$SYNC" "$TMP/scripts/sync-plugin-versions.sh"
echo '{"version":"9.9.9"}' > "$TMP/package.json"
echo '{"version":"0.0.0"}' > "$TMP/.claude-plugin/plugin.json"
echo '{"version":"0.0.0"}' > "$TMP/.codex-plugin/plugin.json"
echo '{"plugins":[{"version":"0.0.0"}]}' > "$TMP/.claude-plugin/marketplace.json"
"$TMP/scripts/sync-plugin-versions.sh" >/dev/null 2>&1
v1=$(jq -r '.version' "$TMP/.claude-plugin/plugin.json")
v2=$(jq -r '.version' "$TMP/.codex-plugin/plugin.json")
v3=$(jq -r '.plugins[0].version' "$TMP/.claude-plugin/marketplace.json")
assert '[ "$v1" = "9.9.9" ]' "sync writes .claude-plugin/plugin.json → 9.9.9"
assert '[ "$v2" = "9.9.9" ]' "sync writes .codex-plugin/plugin.json → 9.9.9"
assert '[ "$v3" = "9.9.9" ]' "sync writes marketplace.json plugins[0].version → 9.9.9"

# Test 3: sandbox — --check detects drift (exit 2)
echo '{"version":"0.0.0"}' > "$TMP/.claude-plugin/plugin.json"
"$TMP/scripts/sync-plugin-versions.sh" --check >/dev/null 2>&1
assert '[ $? -eq 2 ]' "--check exits 2 when a manifest drifts"

# Test 4: sandbox — missing target file → exit 1
rm "$TMP/.claude-plugin/marketplace.json"
"$TMP/scripts/sync-plugin-versions.sh" >/dev/null 2>&1
assert '[ $? -eq 1 ]' "sync exits 1 when a target file is missing"
rm -rf "$TMP"

echo "sync-plugin-versions: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
