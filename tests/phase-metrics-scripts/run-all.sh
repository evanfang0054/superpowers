#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "=== Phase Metrics Scripts Suite ==="
bash test-phase-metrics.sh
RC=$?
if [ $RC -eq 0 ]; then
  echo "✅ phase-metrics-scripts: all passed"
else
  echo "❌ phase-metrics-scripts: failures (exit $RC)"
fi
exit $RC
