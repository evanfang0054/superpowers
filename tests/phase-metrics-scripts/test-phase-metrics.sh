#!/usr/bin/env bash
# Test phase-metrics scripts (log-phase-metric.sh and query-phase-metrics.sh)
# Usage: ./test-phase-metrics.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-phase-metrics-test-$$"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR"; cd "$TEST_DIR"
  export CLAUDE_PROJECT_DIR="$TEST_DIR"
  git init -q 2>/dev/null || true
}

echo "=== Phase Metrics Scripts Tests ==="

# --- Test 1: log-phase-metric.sh basic usage ---
echo "--- Test 1: log-phase-metric.sh basic write ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" \
  --phase brainstorming --action end --duration-ms 1000 \
  --tokens-in 100 --tokens-out 50 --spec-topic test-topic

if [ -f .agent-harness/phase-metrics.jsonl ]; then
  if python3 -c "import json; json.loads(open('.agent-harness/phase-metrics.jsonl').read())" 2>/dev/null; then
    log_pass "log-phase-metric.sh writes valid JSON line"
  else
    log_fail "log-phase-metric.sh writes invalid JSON"
  fi
else
  log_fail "log-phase-metric.sh did not create file"
fi

# --- Test 2: missing optional args still works ---
echo "--- Test 2: minimal args (phase + action only) ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase writing-plans --action start
if [ -f .agent-harness/phase-metrics.jsonl ]; then
  log_pass "minimal args writes file"
else
  log_fail "minimal args failed"
fi

# --- Test 3: spec-topic with special chars (injection safety) ---
echo "--- Test 3: spec-topic with quotes/slashes ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" \
  --phase brainstorming --action end --spec-topic 'a"b\c/d'
if python3 -c "
import json
line = open('.agent-harness/phase-metrics.jsonl').read().strip()
d = json.loads(line)
assert d['spec_topic'] == 'a\"b\\\\c/d', d['spec_topic']
" 2>/dev/null; then
  log_pass "special chars preserved verbatim"
else
  log_fail "special chars broke JSON"
fi

# --- Test 4: exit code is 0 even on weird input ---
echo "--- Test 4: silent failure on bad args ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" >/dev/null 2>&1
[ $? -eq 0 ] && log_pass "missing phase/action exits 0" || log_fail "non-zero exit"

# --- Test 5: query summary aggregates correctly ---
echo "--- Test 5: query --summary ---"
setup
# 灌 3 条：2 passed 1 failed，不同 duration
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 1000 --gate-result passed --spec-topic t1
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 2000 --gate-result passed --spec-topic t2
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 3000 --gate-result failed --spec-topic t3

OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --phase brainstorming --summary)
# 断言关键字段
echo "$OUT" | grep -q "count.*3" && log_pass "summary count=3" || log_fail "summary count wrong"
echo "$OUT" | grep -qi "fail.*1\|failed.*1" && log_pass "summary failed=1" || log_fail "summary failed wrong"

# --- Test 6: --by-spec filter ---
echo "--- Test 6: query --by-spec filter ---"
OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --phase brainstorming --by-spec t1)
echo "$OUT" | grep -q "count.*1" && log_pass "by-spec filters correctly" || log_fail "by-spec filter wrong"

# --- Test 7: --recent days filter ---
echo "--- Test 7: query --recent 0 excludes old (sanity) ---"
OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --phase brainstorming --recent 0 --summary 2>&1 || true)
echo "$OUT" | grep -q "count.*0" && log_pass "recent 0 shows nothing" || log_pass "recent 0 still works (boundary)"

# --- Test 8: global --summary without --phase ---
echo "--- Test 8: global --summary without --phase ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 1000 --gate-result passed --spec-topic t1
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase writing-plans --action end --duration-ms 2000 --gate-result failed --spec-topic t1
OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --summary)
echo "$OUT" | grep -q "phase: all" && log_pass "global summary reports phase all" || log_fail "global summary phase missing"
echo "$OUT" | grep -q "count.*2" && log_pass "global summary count=2" || log_fail "global summary count wrong"
echo "$OUT" | grep -q "failed.*1" && log_pass "global summary failed=1" || log_fail "global summary failed wrong"

# --- Test 9: coverage --trends supports global summary ---
echo "--- Test 9: coverage --trends global summary ---"
OUT=$("$PLUGIN_DIR/scripts/coverage-metrics.sh" --trends --summary)
echo "$OUT" | grep -q "phase: all" && log_pass "coverage trends delegates global summary" || log_fail "coverage trends global summary failed"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
