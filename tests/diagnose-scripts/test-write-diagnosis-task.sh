#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-wdt-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; PASS=$((PASS+1)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; FAIL=$((FAIL+1)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() { rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR"; cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"; }

echo "=== Write Diagnosis Task Tests ==="

# --- Test 1: append to existing plan ---
echo "--- Test 1: append to plan.md ---"
setup
mkdir -p docs/agent-harness/plans
cat > docs/agent-harness/plans/p.md <<EOF
# Plan
EOF
cat > diag.json <<'EOF'
{"ts":"2026-06-29T00:00:00Z","failure_type":"loop","spec_topic":"t1","failure_summary":"3 edits","evidence":{},"root_cause_hypothesis":"h","suggested_fixes":[{"action":"revisit-brainstorming","rationale":"r"}],"confidence":7}
EOF
"$PLUGIN_DIR/scripts/write-diagnosis-task.sh" --diagnosis diag.json --plan docs/agent-harness/plans/p.md
grep -q "auto-generated" docs/agent-harness/plans/p.md && log_pass "appended to plan" || log_fail "not appended"
grep -q "revisit-brainstorming" docs/agent-harness/plans/p.md && log_pass "task action present" || log_fail "action missing"

# --- Test 2: standalone when no plan ---
echo "--- Test 2: standalone when no plan ---"
setup
cat > diag.json <<'EOF'
{"ts":"2026-06-29T00:00:00Z","failure_type":"loop","spec_topic":"t1","failure_summary":"3 edits","evidence":{},"root_cause_hypothesis":"h","suggested_fixes":[{"action":"revisit-brainstorming","rationale":"r"}],"confidence":7}
EOF
"$PLUGIN_DIR/scripts/write-diagnosis-task.sh" --diagnosis diag.json 2>&1
F=$(ls docs/agent-harness/notes/diagnoses/*.md 2>/dev/null | head -1)
[ -n "$F" ] && log_pass "standalone created" || log_fail "no standalone file"
[ -n "$F" ] && ! grep -q "🔧" "$F" && log_pass "standalone heading has no emoji" || log_fail "standalone heading has emoji"

# --- Test 3: default does not append latest plan ---
echo "--- Test 3: default does not append latest plan ---"
setup
mkdir -p docs/agent-harness/plans
printf '# Plan\n' > docs/agent-harness/plans/latest.md
cat > diag.json <<'EOF'
{"ts":"2026-06-29T00:00:00Z","failure_type":"loop","spec_topic":"t1","failure_summary":"3 edits","evidence":{},"root_cause_hypothesis":"h","suggested_fixes":[{"action":"revisit-brainstorming","rationale":"r"}],"confidence":7}
EOF
"$PLUGIN_DIR/scripts/write-diagnosis-task.sh" --diagnosis diag.json >/dev/null
if [ "$(cat docs/agent-harness/plans/latest.md)" = "# Plan" ]; then log_pass "default does not append latest plan"; else log_fail "default mutated latest plan"; fi
F=$(ls docs/agent-harness/notes/diagnoses/*.md 2>/dev/null | head -1)
[ -n "$F" ] && log_pass "default writes standalone note" || log_fail "default standalone note missing"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
