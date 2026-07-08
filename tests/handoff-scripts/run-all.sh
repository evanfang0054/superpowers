#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "=== Handoff Scripts Suite ==="
bash test-validate-handoff.sh; RC=$?
[ $RC -eq 0 ] && echo "✅ handoff-scripts: all passed" || echo "❌ handoff-scripts: failures ($RC)"
exit $RC
