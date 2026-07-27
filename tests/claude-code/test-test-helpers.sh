#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

FAILURES=0

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

assert_succeeds() {
    local description="$1"
    shift

    if "$@" >/dev/null; then
        pass "$description"
    else
        fail "$description"
    fi
}

echo "Test: assert_contains matches prose case-insensitively"
assert_succeeds \
    "assert_contains accepts mixed capitalization" \
    assert_contains "Do Not Trust the Report" "not trust" "mixed-case contains"

echo "Test: assert_order matches prose case-insensitively"
ORDERED_OUTPUT=$'First: Check Spec Compliance\nSecond: Review Code Quality'
assert_succeeds \
    "assert_order accepts mixed capitalization" \
    assert_order "$ORDERED_OUTPUT" "first:.*spec.*compliance" "second:.*code.*quality" "mixed-case order"

echo "Test: assert_order failure includes the original output"
DIAGNOSTIC_INPUT=$'Original Mixed-Case Line\nSecond diagnostic line'
set +e
DIAGNOSTIC_OUTPUT="$(assert_order "$DIAGNOSTIC_INPUT" "missing pattern" "second" "diagnostic dump" 2>&1)"
DIAGNOSTIC_STATUS=$?
set -e

if [ "$DIAGNOSTIC_STATUS" -ne 0 ]; then
    pass "assert_order still fails when a pattern is absent"
else
    fail "assert_order should fail when a pattern is absent"
fi

if printf '%s' "$DIAGNOSTIC_OUTPUT" | grep -Fq -- "$DIAGNOSTIC_INPUT"; then
    pass "assert_order preserves original output in failure diagnostics"
else
    fail "assert_order failure diagnostics omitted or changed the original output"
fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES test(s) failed"
    exit 1
fi

echo "All tests passed"
