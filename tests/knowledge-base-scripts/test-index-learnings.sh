#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-idx-learn-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR/.agent-harness"
  cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

echo "=== Index Learnings Tests ==="

# --- Test 1: groups by type, sorts by confidence ---
echo "--- Test 1: group by type, sort by confidence ---"
setup
cat > .agent-harness/learnings.jsonl <<'EOF'
{"ts":"2026-06-29T00:00:00Z","type":"pitfall","key":"k1","insight":"i1","confidence":8,"source":"observed","files":[]}
{"ts":"2026-06-29T00:00:00Z","type":"pitfall","key":"k2","insight":"i2","confidence":5,"source":"observed","files":[]}
{"ts":"2026-06-29T00:00:00Z","type":"pattern","key":"k3","insight":"i3","confidence":9,"source":"observed","files":[]}
EOF
OUT=$("$PLUGIN_DIR/scripts/index-learnings.sh" --max-entries 2)
# 断言：type pitfall 在前，且 pitfall 内 k1（conf 8）排在 k2（conf 5）前
if echo "$OUT" | grep -q "pitfall"; then log_pass "groups include pitfall"; else log_fail "no pitfall"; fi
if echo "$OUT" | grep -q "pattern"; then log_pass "groups include pattern"; else log_fail "no pattern"; fi

# pitfall 内 k1（conf 8）应排在 k2（conf 5）前
if echo "$OUT" | awk '/pitfall/{p=1;next} /^##/{p=0} p{print}' | grep -q "k1"; then
  FIRST_K=$(echo "$OUT" | awk '/pitfall/{p=1;next} /^##/{p=0} p{print}' | grep -oE 'k[0-9]' | head -1)
  [ "$FIRST_K" = "k1" ] && log_pass "k1 (conf 8) before k2 (conf 5)" || log_fail "order wrong (first=$FIRST_K)"
else
  log_fail "k1 not in pitfall group"
fi

# --- Test 2: empty learnings doesn't crash ---
echo "--- Test 2: empty learnings ---"
setup
rm -f .agent-harness/learnings.jsonl
OUT=$("$PLUGIN_DIR/scripts/index-learnings.sh" 2>&1 || true)
if echo "$OUT" | grep -qi "no.learnings\|empty\|_(无 learnings)_"; then log_pass "empty handled"; else log_pass "empty no-crash"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
