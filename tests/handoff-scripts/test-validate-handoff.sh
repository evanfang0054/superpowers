#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-handoff-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; PASS=$((PASS+1)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; FAIL=$((FAIL+1)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR/docs/agent-harness/specs"
  cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

echo "=== Validate Handoff Tests ==="

# --- Test 1: valid spec passes ---
echo "--- Test 1: valid spec frontmatter ---"
setup
mkdir -p docs/agent-harness
cat > docs/agent-harness/index.md <<EOF
- good-topic → specs/x.md
EOF
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: good-topic
decision_summary: "做了 A 决定"
design_approved: true
user_approved_at: 2026-06-29T10:00:00Z
gates: [review]
---
# 内容
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md
[ $? -eq 0 ] && log_pass "valid spec passes" || log_fail "valid spec rejected"

# --- Test 2: missing field fails ---
echo "--- Test 2: missing field fails ---"
setup
mkdir -p docs/agent-harness
cat > docs/agent-harness/index.md <<EOF
- good-topic → specs/x.md
EOF
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: good-topic
decision_summary: "x"
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md 2>/dev/null
[ $? -ne 0 ] && log_pass "missing field rejected" || log_fail "missing field accepted"

# --- Test 3: plan spec_ref not found ---
echo "--- Test 3: plan spec_ref broken ---"
setup
mkdir -p docs/agent-harness/plans docs/agent-harness/specs
cat > docs/agent-harness/index.md <<EOF
- t1 → specs/s.md
EOF
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: t1
EOF
cat > docs/agent-harness/plans/p.md <<'EOF'
---
spec_ref: ../specs/missing.md
spec_topic: t1
task_count: 3
estimated_phases: [impl]
dod: contract-x
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage plan --file docs/agent-harness/plans/p.md 2>/dev/null
[ $? -ne 0 ] && log_pass "broken spec_ref rejected" || log_fail "broken spec_ref accepted"

# --- Test 4: spec_topic not in index ---
echo "--- Test 4: topic not registered ---"
setup
mkdir -p docs/agent-harness/specs
echo "- other → x" > docs/agent-harness/index.md
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: unregistered
decision_summary: x
design_approved: true
user_approved_at: 2026-06-29T10:00:00Z
gates: []
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md 2>/dev/null
[ $? -ne 0 ] && log_pass "unregistered topic rejected" || log_fail "unregistered topic accepted"

# --- Test 5: topic matching is literal and anchored ---
echo "--- Test 5: literal topic matching ---"
setup
mkdir -p docs/agent-harness/specs
echo "- alphaXbeta → specs/real.md" > docs/agent-harness/index.md
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: alpha.beta
decision_summary: x
design_approved: true
user_approved_at: 2026-06-29T10:00:00Z
gates: []
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md 2>/dev/null
[ $? -ne 0 ] && log_pass "regex-like near match rejected" || log_fail "regex-like near match accepted"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
