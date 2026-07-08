#!/usr/bin/env bash
# validate-handoff.sh - Structural validation of handoff frontmatter.
#
# Usage: validate-handoff.sh --stage <spec|plan|task> --file <path>
#
# 退出码：0 通过（stdout 一行摘要）/ 1 失败（stderr 列出所有问题）。
# 不调用子代理；语义审稿仍由 spec-document-reviewer / plan-document-reviewer 负责。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/yaml-parse.sh"
. "$SCRIPT_DIR/lib/handoff-schema.sh"

export ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

STAGE=""; FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    *) echo "validate-handoff: unknown arg '$1'" >&2; shift ;;
  esac
done

if [ -z "$STAGE" ] || [ -z "$FILE" ]; then
  echo "usage: $0 --stage <spec|plan|task> --file <path>" >&2
  exit 1
fi
[ ! -f "$FILE" ] && { echo "validate-handoff: file not found: $FILE" >&2; exit 1; }

yaml_parse_load "$FILE" || { echo "validate-handoff: no frontmatter in $FILE" >&2; exit 1; }

if handoff_check_required "$STAGE" "$FILE"; then
  echo "OK $STAGE $(basename "$FILE")"
  exit 0
else
  exit 1
fi
