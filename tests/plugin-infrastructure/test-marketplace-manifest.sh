#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: Marketplace Manifest ==="

MARKET_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"

assert_file_exists "$MARKET_JSON" "marketplace.json exists"

if jq empty "$MARKET_JSON" 2>/dev/null; then pass "marketplace.json is valid JSON"; else fail "marketplace.json is valid JSON"; fi

# name 非空
MKT_NAME=$(jq -r '.name // empty' "$MARKET_JSON")
if [ -n "$MKT_NAME" ]; then pass "marketplace name non-empty ($MKT_NAME)"; else fail "marketplace name non-empty"; fi

# plugins[0].version 与 plugin.json 一致
PLUGIN_VER=$(jq -r '.version' "$PLUGIN_JSON")
MKT_VER=$(jq -r '.plugins[0].version' "$MARKET_JSON")
if [ "$PLUGIN_VER" = "$MKT_VER" ]; then
    pass "plugins[0].version matches plugin.json ($MKT_VER)"
else
    fail "plugins[0].version matches plugin.json (market=$MKT_VER plugin=$PLUGIN_VER)"
fi

# source 指向有效目录（./ 表示插件根）
SOURCE=$(jq -r '.plugins[0].source' "$MARKET_JSON")
if [ "$SOURCE" = "./" ] && [ -d "$REPO_ROOT" ]; then
    pass "source points to valid dir ($SOURCE)"
else
    fail "source points to valid dir (got '$SOURCE')"
fi

# 非运行时目录不应进入 git archive / 插件分发包
for excluded in demo tests docs; do
    if git -C "$REPO_ROOT" check-attr export-ignore -- "$excluded" | grep -q 'export-ignore: set'; then
        pass "$excluded excluded from generated archives"
    else
        fail "$excluded excluded from generated archives"
    fi
done

# owner.name 非空
OWNER=$(jq -r '.owner.name // empty' "$MARKET_JSON")
if [ -n "$OWNER" ]; then pass "owner.name non-empty"; else fail "owner.name non-empty"; fi

print_summary "Marketplace Manifest"
