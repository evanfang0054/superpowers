#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: guard-staging.sh ==="

GUARD="$REPO_ROOT/scripts/guard-staging.sh"
assert_file_exists "$GUARD" "guard-staging.sh exists"
assert_executable "$GUARD" "guard-staging.sh is executable"

# Helper: pipe a JSON tool_input to guard-staging, capture exit code
run_guard() {
    local json="$1"
    echo "$json" | bash "$GUARD" 2>/tmp/guard-stderr.txt
    return $?
}

# Case 1: non-git command → exit 0 (passthrough)
run_guard '{"tool_input":{"command":"ls -la"}}'
if [ $? -eq 0 ]; then pass "non-git command passes"; else fail "non-git command passes (got $?)"; fi

# Case 2: git add . → exit 2 (blocked)
run_guard '{"tool_input":{"command":"git add ."}}'
if [ $? -eq 2 ]; then pass "git add . blocked"; else fail "git add . blocked (got $?)"; fi

# Case 3: git add -A → exit 2 (blocked)
run_guard '{"tool_input":{"command":"git add -A"}}'
if [ $? -eq 2 ]; then pass "git add -A blocked"; else fail "git add -A blocked (got $?)"; fi

# Case 4: git add with protected path → exit 2
run_guard '{"tool_input":{"command":"git add .agent-harness/loop-tracker.json"}}'
if [ $? -eq 2 ]; then pass "git add protected path blocked"; else fail "git add protected path blocked (got $?)"; fi

# Case 5: git add -f with protected path → exit 0 (force allowed)
run_guard '{"tool_input":{"command":"git add -f .agent-harness/loop-tracker.json"}}'
if [ $? -eq 0 ]; then pass "git add -f protected path allowed"; else fail "git add -f protected path allowed (got $?)"; fi

# Case 6: git add normal file → exit 0
run_guard '{"tool_input":{"command":"git add README.md"}}'
if [ $? -eq 0 ]; then pass "git add normal file passes"; else fail "git add normal file passes (got $?)"; fi

# Case 6b: git add .env (dotfile) → exit 0 (NOT broad-catch)
# Regression: broad-catch glob `*"git add ."*` substring-matched `git add .env`.
run_guard '{"tool_input":{"command":"git add .env"}}'
if [ $? -eq 0 ]; then pass "git add .env allowed (dotfile, not broad-catch)"; else fail "git add .env allowed (got $?)"; fi

# Case 6c: git add .gitignore → exit 0 (NOT broad-catch)
run_guard '{"tool_input":{"command":"git add .gitignore"}}'
if [ $? -eq 0 ]; then pass "git add .gitignore allowed (dotfile)"; else fail "git add .gitignore allowed (got $?)"; fi

# Case 6d: git add ./relative/path → exit 0 (NOT broad-catch)
run_guard '{"tool_input":{"command":"git add ./src/foo.py"}}'
if [ $? -eq 0 ]; then pass "git add ./src/foo.py allowed (relative path)"; else fail "git add ./src/foo.py allowed (got $?)"; fi

# Case 6e: bare `git add .` still blocked (regression guard for the fix)
run_guard '{"tool_input":{"command":"git add ."}}'
if [ $? -eq 2 ]; then pass "git add . still blocked after fix"; else fail "git add . still blocked after fix (got $?)"; fi

# Case 7: stderr contains reason when blocked
run_guard '{"tool_input":{"command":"git add ."}}' >/dev/null 2>&1
if grep -q "agent-harness\|protected\|staging" /tmp/guard-stderr.txt; then
    pass "stderr contains block reason"
else
    fail "stderr contains block reason (stderr was empty or generic)"
fi

rm -f /tmp/guard-stderr.txt

print_summary "guard-staging.sh"
