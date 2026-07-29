#!/usr/bin/env bash
#
# migrate-release-notes.sh — one-time migration: RELEASE-NOTES.md → CHANGELOG.md
# 转换格式: `## vX.Y.Z (date)` → `## X.Y.Z`（去 v 前缀和日期，匹配 changesets 格式）
# 保留 `### Changes` 下 bullet 原文。迁移后本脚本应删除。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/RELEASE-NOTES.md"
DST="$REPO_ROOT/CHANGELOG.md"

[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }
[ -f "$DST" ] && { echo "error: $DST already exists, refusing to overwrite" >&2; exit 1; }

{
  echo "# agent-harness"
  echo ""
  awk '
    /^# Agent Harness Release Notes/ { next }
    /^## v[0-9]/ {
      line=$0
      sub(/^## v/, "## ", line)
      sub(/ \([0-9]{4}-[0-9]{2}-[0-9]{2}\)/, "", line)
      print line
      next
    }
    { print }
  ' "$SRC"
} > "$DST"

count=$(grep -c '^## ' "$DST" || true)
echo "migrated $count versions to $DST"
echo "first entry: $(grep -m1 '^## ' "$DST")"
