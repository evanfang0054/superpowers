#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; cd "$SCRIPT_DIR"
echo "=== Diagnose Scripts Suite ==="
bash test-diagnose-failure.sh; RC1=$?
bash test-write-diagnosis-task.sh; RC2=$?
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
  echo "✅ diagnose-scripts: all passed"; exit 0
else
  echo "❌ diagnose-scripts: failures ($RC1/$RC2)"; exit 1
fi
