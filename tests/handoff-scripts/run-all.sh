#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "=== Handoff Scripts Suite ==="
OVERALL_RC=0
bash test-validate-handoff.sh; RC=$?; [ $RC -ne 0 ] && OVERALL_RC=$RC
bash test-domain-terms-advisory.sh; RC=$?; [ $RC -ne 0 ] && OVERALL_RC=$RC
[ $OVERALL_RC -eq 0 ] && echo "✅ handoff-scripts: all passed" || echo "❌ handoff-scripts: failures ($OVERALL_RC)"
exit $OVERALL_RC
