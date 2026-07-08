#!/usr/bin/env bash
# Run all plugin-infrastructure tests
# Usage: ./run-all.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Plugin Infrastructure Test Suite ==="
echo "Repository: $(cd "$SCRIPT_DIR/../.." && pwd)"
echo "Time: $(date)"
echo ""

PASSED=0
FAILED=0
RESULTS=""

TESTS=(
    "test-plugin-manifest.sh"
    "test-marketplace-manifest.sh"
    "test-hooks-config.sh"
    "test-session-start-injection.sh"
    "test-stop-hook.sh"
    "test-commands-frontmatter.sh"
    "test-agents-frontmatter.sh"
    "test-bump-version.sh"
    "test-bump-version-agent.sh"
    "test-scripts-smoke.sh"
    "test-guard-staging.sh"
    "test-guard-auto-loop.sh"
    "test-audit-subagent.sh"
    "test-auto-loop-state.sh"
    "test-auto-loop-worktree.sh"
    "test-auto-loop-observe.sh"
    "test-auto-loop-cli.sh"
    "test-auto-loop-fix-only.sh"
)

for test in "${TESTS[@]}"; do
    echo ">>> Running: $test"
    if bash "$SCRIPT_DIR/$test"; then
        PASSED=$((PASSED + 1))
        RESULTS="$RESULTS\nPASS: $test"
    else
        FAILED=$((FAILED + 1))
        RESULTS="$RESULTS\nFAIL: $test"
    fi
    echo ""
done

echo "=== Summary ==="
echo -e "$RESULTS"
echo ""
echo "Suites passed: $PASSED"
echo "Suites failed: $FAILED"
echo "Total: $((PASSED + FAILED))"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
