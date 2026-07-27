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

assert_diagnostic_line() {
    local output="$1"
    local expected_line="$2"
    local description="$3"

    if printf '%s\n' "$output" | grep -Fq -- "$expected_line"; then
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

echo "Test: assert_order dumps original output when pattern B is absent"
DIAGNOSTIC_INPUT=$'Original Mixed-Case Line\nSecond diagnostic line'
set +e
DIAGNOSTIC_OUTPUT="$(assert_order "$DIAGNOSTIC_INPUT" "original" "missing pattern" "missing B dump" 2>&1)"
DIAGNOSTIC_STATUS=$?
set -e

if [ "$DIAGNOSTIC_STATUS" -ne 0 ]; then
    pass "assert_order still fails when pattern B is absent"
else
    fail "assert_order should fail when pattern B is absent"
fi
assert_diagnostic_line "$DIAGNOSTIC_OUTPUT" "  In output:" "pattern B failure labels the diagnostic dump"
assert_diagnostic_line "$DIAGNOSTIC_OUTPUT" "    Original Mixed-Case Line" "pattern B failure preserves the first original line"
assert_diagnostic_line "$DIAGNOSTIC_OUTPUT" "    Second diagnostic line" "pattern B failure preserves the second original line"

echo "Test: assert_order dumps original output when patterns are reversed"
REVERSED_INPUT=$'Second diagnostic line\nOriginal Mixed-Case Line'
set +e
REVERSED_OUTPUT="$(assert_order "$REVERSED_INPUT" "original" "second" "reversed dump" 2>&1)"
REVERSED_STATUS=$?
set -e

if [ "$REVERSED_STATUS" -ne 0 ]; then
    pass "assert_order still fails when patterns are reversed"
else
    fail "assert_order should fail when patterns are reversed"
fi
assert_diagnostic_line "$REVERSED_OUTPUT" "  In output:" "reversed-order failure labels the diagnostic dump"
assert_diagnostic_line "$REVERSED_OUTPUT" "    Second diagnostic line" "reversed-order failure preserves the first original line"
assert_diagnostic_line "$REVERSED_OUTPUT" "    Original Mixed-Case Line" "reversed-order failure preserves the second original line"

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES test(s) failed"
    exit 1
fi

echo "All tests passed"
