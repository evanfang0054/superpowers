#!/usr/bin/env bash
# Test cleanup-workspace script
# Usage: ./test-cleanup-workspace.sh
#
# Tests:
# 1. Missing current plan workspace → exit 0 after resolving/removing it
# 2. Plan-aware cleanup removes only that plan workspace, preserving siblings/.gitignore
# 3. rm failure is best-effort → exit 0 and emits a warning (root skips)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$PLUGIN_DIR/skills/subagent-driven-development/scripts/cleanup-workspace"
TEST_DIR="/tmp/agent-harness-cleanup-test-$$"
PLAN_A=""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
PASS=0
FAIL=0

log_pass() { echo -e "${GREEN}PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup_repo() {
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR/plans"
  export CLAUDE_PROJECT_DIR="$TEST_DIR"
  PLAN_A="$TEST_DIR/plans/plan-a.md"
  touch "$PLAN_A"
}

workspace_for() {
  printf '%s/.agent-harness/sdd/%s\n' "$TEST_DIR" "$(basename "$1" .md)"
}

echo "=== cleanup-workspace Tests ==="
echo "Script: $SCRIPT"
echo ""

echo "--- Test 1: missing current workspace → exit 0 ---"
setup_repo
out=$(bash "$SCRIPT" "$PLAN_A" 2>/tmp/cleanup-stderr-1); rc=$?
if [ "$rc" = "0" ] && \
   printf '%s\n' "$out" | grep -Fq "cleaned: $TEST_DIR/.agent-harness/sdd/plan-a" && \
   [ ! -d "$TEST_DIR/.agent-harness/sdd/plan-a" ]; then
  log_pass "exit=0 and current workspace is absent after cleanup"
else
  log_fail "rc=$rc, out='$out', stderr='$(< /tmp/cleanup-stderr-1)'"
fi

echo "--- Test 2: current plan only → sibling and .gitignore preserved ---"
setup_repo
workspace_a=$(workspace_for "$PLAN_A")
workspace_b="$TEST_DIR/.agent-harness/sdd/plan-b"
mkdir -p "$workspace_a" "$workspace_b"
touch "$workspace_a/task-1-brief.md" "$workspace_b/task-1-brief.md"
printf '*\n' > "$TEST_DIR/.agent-harness/sdd/.gitignore"
out=$(bash "$SCRIPT" "$PLAN_A" 2>/tmp/cleanup-stderr-2); rc=$?
if [ "$rc" = "0" ] && \
   printf '%s\n' "$out" | grep -Fq "cleaned: $workspace_a" && \
   [ ! -e "$workspace_a" ] && \
   [ -f "$workspace_b/task-1-brief.md" ] && \
   [ -f "$TEST_DIR/.agent-harness/sdd/.gitignore" ]; then
  log_pass "only current plan workspace removed"
else
  log_fail "rc=$rc, out='$out', workspace_a=$([ -e "$workspace_a" ] && echo present || echo absent), sibling=$([ -f "$workspace_b/task-1-brief.md" ] && echo present || echo absent), gitignore=$([ -f "$TEST_DIR/.agent-harness/sdd/.gitignore" ] && echo present || echo absent), stderr='$(< /tmp/cleanup-stderr-2)'"
fi

echo "--- Test 3: rm failure → best-effort warning and exit 0 ---"
if [ "$(id -u)" = "0" ]; then
  echo "    (skipped: running as root, permission test unreliable)"
else
  setup_repo
  workspace_a=$(workspace_for "$PLAN_A")
  mkdir -p "$workspace_a"
  chmod 555 "$TEST_DIR/.agent-harness/sdd"
  out=$(bash "$SCRIPT" "$PLAN_A" 2>/tmp/cleanup-stderr-3); rc=$?
  chmod 755 "$TEST_DIR/.agent-harness/sdd" 2>/dev/null || true
  err=$(< /tmp/cleanup-stderr-3)
  if [ "$rc" = "0" ] && printf '%s\n' "$err" | grep -q 'warning: cleanup-workspace failed'; then
    log_pass "exit=0 with warning on cleanup failure"
  else
    log_fail "rc=$rc, out='$out', stderr='$err'"
  fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ] || exit 1
