#!/usr/bin/env bash
#
# sync-plugin-versions.sh — sync package.json version to 3 plugin manifests.
# Usage:
#   sync-plugin-versions.sh           # sync (write)
#   sync-plugin-versions.sh --check   # check drift (exit 0 in-sync, 2 drift, 1 missing)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PKG="$REPO_ROOT/package.json"
# 格式: "相对路径|jq字段路径"
TARGETS=(
  ".claude-plugin/plugin.json|.version"
  ".codex-plugin/plugin.json|.version"
  ".claude-plugin/marketplace.json|.plugins[0].version"
)

cmd_sync() {
  local pkg_ver; pkg_ver=$(jq -r '.version' "$PKG")
  for entry in "${TARGETS[@]}"; do
    local rel="${entry%|*}" field="${entry#*|}"
    local file="$REPO_ROOT/$rel"
    if [ ! -f "$file" ]; then
      echo "error: missing target file: $rel" >&2
      exit 1
    fi
    local tmp="${file}.tmp"
    jq "$field = \"$pkg_ver\"" "$file" > "$tmp" && mv "$tmp" "$file"
    echo "  synced $rel ($field) → $pkg_ver"
  done
}

cmd_check() {
  local pkg_ver; pkg_ver=$(jq -r '.version' "$PKG")
  local drift=0
  for entry in "${TARGETS[@]}"; do
    local rel="${entry%|*}" field="${entry#*|}"
    local file="$REPO_ROOT/$rel"
    if [ ! -f "$file" ]; then
      echo "MISSING: $rel" >&2
      drift=1
      continue
    fi
    local ver; ver=$(jq -r "$field" "$file")
    if [ "$ver" != "$pkg_ver" ]; then
      echo "DRIFT: $rel field=$field expected=$pkg_ver actual=$ver" >&2
      drift=1
    fi
  done
  if [ "$drift" = "0" ]; then
    echo "All manifests in sync at $pkg_ver"
    return 0
  fi
  return 2
}

case "${1:-sync}" in
  sync|"") cmd_sync ;;
  --check|check) cmd_check ;;
  *) echo "usage: sync-plugin-versions.sh [sync|--check]" >&2; exit 1 ;;
esac
