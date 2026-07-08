#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-diag-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; PASS=$((PASS+1)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; FAIL=$((FAIL+1)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

echo "=== Diagnose Failure Tests ==="

# --- Test 1: type loop, outputs valid JSON ---
echo "--- Test 1: type loop ---"
setup
CTX='{"file":"spec.md","edits":3,"last_error":"schema-mismatch"}'
OUT=$("$PLUGIN_DIR/scripts/diagnose-failure.sh" --type loop --context "$CTX" --spec-topic t1 2>/dev/null)

echo "$OUT" | grep -Eq '^\.agent-harness/diagnoses/.+\.json$|^/.+\.agent-harness/diagnoses/.+\.json$' \
  && log_pass "stdout is diagnosis path" \
  || log_fail "stdout should be diagnosis path only"

# 找到产物文件
F=$(ls .agent-harness/diagnoses/*.json 2>/dev/null | head -1)
[ -z "$F" ] && { log_fail "no diagnosis file"; echo "Results: $PASS passed, $FAIL failed"; exit 1; }
log_pass "diagnosis file created"
grep -q '"failure_type": "loop"' "$F" 2>/dev/null && log_pass "loop type stamped" || log_fail "loop type missing"
python3 -c "import json; json.load(open('$F'))" 2>/dev/null && log_pass "JSON valid" || log_fail "JSON invalid"

# --- Test 2: type gate from file ---
echo "--- Test 2: type gate from file ---"
setup
echo '{"phase":"writing-plans","validate_error":"missing field spec_ref"}' > ctx.json
OUT=$("$PLUGIN_DIR/scripts/diagnose-failure.sh" --type gate --context @ctx.json --spec-topic t2 2>/dev/null)
F="$OUT"
echo "$F" | grep -q "gate" && log_pass "gate file named" || log_fail "gate file naming wrong"
grep -q 'missing field spec_ref' "$F" && log_pass "@file context supported" || log_fail "@file context not loaded"

# --- Test 3: graceful when all signals missing ---
echo "--- Test 3: empty warehouse ---"
setup
"$PLUGIN_DIR/scripts/diagnose-failure.sh" --type test --context '{"cmd":"pytest","exit_code":1}' 2>&1 >/dev/null
F=$(ls .agent-harness/diagnoses/*.json 2>/dev/null | head -1)
[ -n "$F" ] && python3 -c "
import json
d = json.load(open('$F'))
assert d['failure_type']=='test'
assert isinstance(d['evidence']['similar_learnings'], list)
print('OK')
" 2>/dev/null && log_pass "graceful empty" || log_fail "crashed on empty"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
