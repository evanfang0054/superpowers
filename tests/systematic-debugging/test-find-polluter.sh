#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POLLUTER="$REPO_ROOT/skills/systematic-debugging/find-polluter.sh"
TMPDIR="$(mktemp -d)"
CALLS_FILE="$TMPDIR/npm-calls"
PREVIOUS_CALLS_FILE="$TMPDIR/previous-npm-calls"

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    exit 1
}

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/bin" "$TMPDIR/project/src/nested"
touch "$TMPDIR/project/src/top.test.ts" "$TMPDIR/project/src/nested/deep.test.ts"
git -C "$TMPDIR/project" init -q

cat > "$TMPDIR/bin/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${2#./}" >> "$NPM_CALLS_FILE"
EOF
chmod +x "$TMPDIR/bin/npm"

run_polluter() {
    : > "$CALLS_FILE"
    OUTPUT=$(cd "$TMPDIR/project" && PATH="$TMPDIR/bin:$PATH" NPM_CALLS_FILE="$CALLS_FILE" bash "$POLLUTER" .pollution "$1" 2>&1)
}

assert_called() {
    if grep -Fxq "$1" "$CALLS_FILE"; then
        pass "npm called for $1"
    else
        fail "npm called for $1"
    fi
}

assert_same_called_files_as_previous() {
    if cmp -s "$PREVIOUS_CALLS_FILE" "$CALLS_FILE"; then
        pass "./ pattern calls the same test files"
    else
        fail "./ pattern calls the same test files"
    fi
}

assert_output_contains() {
    if [[ "$OUTPUT" == *"$1"* ]]; then
        pass "output contains $1"
    else
        fail "output contains $1"
    fi
}

echo "=== Test: find-polluter ==="

run_polluter "src/**/*.test.ts"
assert_called "src/top.test.ts"
assert_called "src/nested/deep.test.ts"
cp "$CALLS_FILE" "$PREVIOUS_CALLS_FILE"

run_polluter "./src/**/*.test.ts"
assert_same_called_files_as_previous

run_polluter "missing/**/*.test.ts"
assert_output_contains "Found 0 test files"

echo "=== All find-polluter tests passed ==="
