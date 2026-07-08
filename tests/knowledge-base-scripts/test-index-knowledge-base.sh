#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-kb-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR/docs/agent-harness/specs"
  cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

echo "=== Knowledge Base Index Tests ==="

# --- Test 1: generates index for specs subdir ---
echo "--- Test 1: generate specs/index.md ---"
setup
cat > docs/agent-harness/specs/foo-design.md <<'EOF'
# Foo Design

foo bar baz
EOF
"$PLUGIN_DIR/scripts/index-knowledge-base.sh"
if [ -f docs/agent-harness/specs/index.md ]; then log_pass "specs/index.md created"; else log_fail "specs/index.md missing"; fi

# --- Test 2: idempotent ---
echo "--- Test 2: idempotent ---"
cp docs/agent-harness/specs/index.md /tmp/idx-first-$$.txt
"$PLUGIN_DIR/scripts/index-knowledge-base.sh"
if diff -q /tmp/idx-first-$$.txt docs/agent-harness/specs/index.md >/dev/null; then log_pass "idempotent"; else log_fail "non-idempotent"; fi
rm -f /tmp/idx-first-$$.txt

# --- Test 3: deletion reflected ---
echo "--- Test 3: deletion reflected ---"
rm docs/agent-harness/specs/foo-design.md
"$PLUGIN_DIR/scripts/index-knowledge-base.sh"
if grep -q "foo-design" docs/agent-harness/specs/index.md; then log_fail "deletion not reflected"; else log_pass "deletion reflected"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
