#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: guard-auto-loop.sh ==="

GUARD="$REPO_ROOT/scripts/guard-auto-loop.sh"
assert_file_exists "$GUARD" "guard-auto-loop.sh exists"
assert_executable "$GUARD" "guard-auto-loop.sh is executable"

# Helper: pipe a JSON tool_input to guard-auto-loop, capture exit code
# Sets AUTO_LOOP_ACTIVE=1 to simulate active run
run_guard() {
    local json="$1"
    echo "$json" | AUTO_LOOP_ACTIVE=1 bash "$GUARD" 2>/tmp/guard-al-stderr.txt
    return $?
}

# Helper: run without AUTO_LOOP_ACTIVE (should always pass)
run_guard_inactive() {
    local json="$1"
    echo "$json" | env -u AUTO_LOOP_ACTIVE bash "$GUARD" 2>/dev/null
    return $?
}

# === Case 1: AUTO_LOOP_ACTIVE unset → all commands pass (no-op) ===
run_guard_inactive '{"tool_name":"Bash","tool_input":{"command":"rm -rf .claude/auto-loop"}}'
if [ $? -eq 0 ]; then pass "inactive: rm -rf passes (no-op when AUTO_LOOP_ACTIVE unset)"; else fail "inactive: should pass"; fi

# === Case 2: rm -rf .claude/auto-loop → blocked ===
run_guard '{"tool_input":{"command":"rm -rf .claude/auto-loop"}}'
if [ $? -eq 2 ]; then pass "blocks rm -rf .claude/auto-loop"; else fail "blocks rm -rf .claude/auto-loop"; fi

# === Case 3: rm -rf .claude/worktrees → blocked ===
run_guard '{"tool_input":{"command":"rm -rf .claude/worktrees"}}'
if [ $? -eq 2 ]; then pass "blocks rm -rf .claude/worktrees"; else fail "blocks rm -rf .claude/worktrees"; fi

# === Case 4: scripts/auto-loop.sh --cleanup → blocked ===
run_guard '{"tool_input":{"command":"scripts/auto-loop.sh --cleanup"}}'
if [ $? -eq 2 ]; then pass "blocks scripts/auto-loop.sh --cleanup"; else fail "blocks scripts/auto-loop.sh --cleanup"; fi

# === Case 5: ./scripts/auto-loop.sh --resume → blocked ===
run_guard '{"tool_input":{"command":"./scripts/auto-loop.sh --resume"}}'
if [ $? -eq 2 ]; then pass "blocks ./scripts/auto-loop.sh --resume"; else fail "blocks ./scripts/auto-loop.sh --resume"; fi

# === Case 6: git worktree remove → blocked ===
run_guard '{"tool_input":{"command":"git worktree remove .claude/worktrees/foo"}}'
if [ $? -eq 2 ]; then pass "blocks git worktree remove"; else fail "blocks git worktree remove"; fi

# === Case 7: git worktree prune → blocked ===
run_guard '{"tool_input":{"command":"git worktree prune"}}'
if [ $? -eq 2 ]; then pass "blocks git worktree prune"; else fail "blocks git worktree prune"; fi

# === Case 8: safe command (git add) → passes ===
run_guard '{"tool_input":{"command":"git add README.md"}}'
if [ $? -eq 0 ]; then pass "safe command (git add) passes"; else fail "safe command passes"; fi

# === Case 9: safe command (ls) → passes ===
run_guard '{"tool_input":{"command":"ls -la"}}'
if [ $? -eq 0 ]; then pass "safe command (ls) passes"; else fail "safe command (ls) passes"; fi

# === Case 10: non-Bash tool → passes (no-op) ===
run_guard '{"tool_name":"Read","tool_input":{"command":"rm -rf .claude/auto-loop"}}'
if [ $? -eq 0 ]; then pass "non-Bash tool passes"; else fail "non-Bash tool passes"; fi

# === Case 10b: Bash tool_name but dangerous command → blocked ===
run_guard '{"tool_name":"Bash","tool_input":{"command":"rm -rf .claude/auto-loop"}}'
if [ $? -eq 2 ]; then pass "Bash tool_name with rm -rf blocked"; else fail "Bash tool_name with rm -rf blocked"; fi

# === Case 11: rm -rf unrelated path → passes ===
run_guard '{"tool_input":{"command":"rm -rf /tmp/some-junk"}}'
if [ $? -eq 0 ]; then pass "rm -rf unrelated path passes"; else fail "rm -rf unrelated path passes"; fi

# === Case 12: find -delete on auto-loop → blocked ===
run_guard '{"tool_input":{"command":"find .claude/auto-loop -type f -delete"}}'
if [ $? -eq 2 ]; then pass "blocks find -delete on auto-loop"; else fail "blocks find -delete on auto-loop"; fi

# === Case 13: stderr contains reason when blocked ===
run_guard '{"tool_input":{"command":"rm -rf .claude/auto-loop"}}' >/dev/null 2>&1
if grep -q "auto-loop\|破坏\|拦截" /tmp/guard-al-stderr.txt; then
    pass "stderr contains block reason"
else
    fail "stderr contains block reason (stderr was empty)"
fi

rm -f /tmp/guard-al-stderr.txt
print_summary "guard-auto-loop.sh"
