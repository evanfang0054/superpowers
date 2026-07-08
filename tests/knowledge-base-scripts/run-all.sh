#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "=== Knowledge Base Scripts Suite ==="
bash test-index-knowledge-base.sh; RC1=$?
bash test-index-learnings.sh; RC2=$?
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
  echo "✅ knowledge-base-scripts: all passed"; exit 0
else
  echo "❌ knowledge-base-scripts: failures ($RC1/$RC2)"; exit 1
fi
