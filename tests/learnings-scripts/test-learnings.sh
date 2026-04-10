#!/usr/bin/env bash
# Test learnings scripts (log-learning.sh and search-learnings.sh)
# Usage: ./test-learnings.sh
#
# Tests:
# 1. log-learning.sh creates valid JSON entries
# 2. search-learnings.sh finds entries correctly
# 3. Confidence decay works
# 4. Deduplication works

# Don't use set -e, we want to continue on failures
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/superpowers-learnings-test-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

log_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAIL++))
}

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Setup test environment (clean slate each time)
setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    # Don't create .superpowers yet - let tests create it as needed
}

echo "=== Learnings Scripts Tests ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Test dir: $TEST_DIR"
echo ""

# ==========================================
# Test 1: log-learning.sh creates valid JSON
# ==========================================
echo "--- Test 1: log-learning.sh basic usage ---"
setup

"$PLUGIN_DIR/scripts/log-learning.sh" pattern "test_key" "Test insight message" 8 observed

if [ -f .superpowers/learnings.jsonl ]; then
    if python3 -c "import json; json.loads(open('.superpowers/learnings.jsonl').read())" 2>/dev/null; then
        log_pass "log-learning.sh creates valid JSON"
    else
        log_fail "log-learning.sh creates invalid JSON"
    fi
else
    log_fail "log-learning.sh did not create file"
fi

# ==========================================
# Test 2: JSON fields are correct
# ==========================================
echo "--- Test 2: JSON fields validation ---"

TYPE=$(python3 -c "import json; print(json.loads(open('.superpowers/learnings.jsonl').read())['type'])")
KEY=$(python3 -c "import json; print(json.loads(open('.superpowers/learnings.jsonl').read())['key'])")
INSIGHT=$(python3 -c "import json; print(json.loads(open('.superpowers/learnings.jsonl').read())['insight'])")
CONFIDENCE=$(python3 -c "import json; print(json.loads(open('.superpowers/learnings.jsonl').read())['confidence'])")

if [ "$TYPE" = "pattern" ] && [ "$KEY" = "test_key" ] && [ "$INSIGHT" = "Test insight message" ] && [ "$CONFIDENCE" = "8" ]; then
    log_pass "JSON fields are correct"
else
    log_fail "JSON fields mismatch: type=$TYPE, key=$KEY, insight=$INSIGHT, confidence=$CONFIDENCE"
fi

# ==========================================
# Test 3: Invalid type rejected
# ==========================================
echo "--- Test 3: Invalid type rejection ---"
setup

if "$PLUGIN_DIR/scripts/log-learning.sh" invalid_type "key" "insight" 2>/dev/null; then
    log_fail "Invalid type was accepted"
else
    log_pass "Invalid type was rejected"
fi

# ==========================================
# Test 4: Invalid confidence rejected
# ==========================================
echo "--- Test 4: Invalid confidence rejection ---"
setup

if "$PLUGIN_DIR/scripts/log-learning.sh" pattern "key" "insight" 15 2>/dev/null; then
    log_fail "Invalid confidence was accepted"
else
    log_pass "Invalid confidence was rejected"
fi

# ==========================================
# Test 5: search-learnings.sh --summary
# ==========================================
echo "--- Test 5: search-learnings.sh --summary ---"
setup

"$PLUGIN_DIR/scripts/log-learning.sh" pattern "api_pattern" "Use decorators for API routes" 9 observed
"$PLUGIN_DIR/scripts/log-learning.sh" pitfall "async_trap" "Avoid async in middleware" 8 error

OUTPUT=$("$PLUGIN_DIR/scripts/search-learnings.sh" --summary)

if echo "$OUTPUT" | grep -q "LEARNINGS: 2 loaded"; then
    log_pass "search-learnings.sh --summary shows correct count"
else
    log_fail "search-learnings.sh --summary count incorrect: $OUTPUT"
fi

if echo "$OUTPUT" | grep -q "api_pattern" && echo "$OUTPUT" | grep -q "async_trap"; then
    log_pass "search-learnings.sh --summary shows all entries"
else
    log_fail "search-learnings.sh --summary missing entries"
fi

# ==========================================
# Test 6: search-learnings.sh keyword search
# ==========================================
echo "--- Test 6: search-learnings.sh keyword search ---"

OUTPUT=$("$PLUGIN_DIR/scripts/search-learnings.sh" "middleware")

if echo "$OUTPUT" | grep -q "async_trap"; then
    log_pass "Keyword search finds matching entry"
else
    log_fail "Keyword search failed: $OUTPUT"
fi

# ==========================================
# Test 7: search-learnings.sh --type filter
# ==========================================
echo "--- Test 7: search-learnings.sh --type filter ---"

OUTPUT=$("$PLUGIN_DIR/scripts/search-learnings.sh" --type pitfall)

if echo "$OUTPUT" | grep -q "async_trap" && ! echo "$OUTPUT" | grep -q "api_pattern"; then
    log_pass "--type filter works correctly"
else
    log_fail "--type filter failed: $OUTPUT"
fi

# ==========================================
# Test 8: Deduplication (latest wins)
# ==========================================
echo "--- Test 8: Deduplication ---"
setup

"$PLUGIN_DIR/scripts/log-learning.sh" pattern "dup_key" "Old insight" 5 observed
sleep 1
"$PLUGIN_DIR/scripts/log-learning.sh" pattern "dup_key" "New insight" 9 observed

OUTPUT=$("$PLUGIN_DIR/scripts/search-learnings.sh" --summary)

# Should show only 1 entry (deduplicated)
if echo "$OUTPUT" | grep -q "LEARNINGS: 1 loaded"; then
    log_pass "Deduplication works (1 entry shown)"
else
    log_fail "Deduplication failed: $OUTPUT"
fi

# Should show the newer insight
if echo "$OUTPUT" | grep -q "New insight"; then
    log_pass "Deduplication keeps latest entry"
else
    log_fail "Deduplication did not keep latest: $OUTPUT"
fi

# ==========================================
# Test 9: Confidence decay
# ==========================================
echo "--- Test 9: Confidence decay ---"
setup
mkdir -p .superpowers

# Create an entry with old timestamp (365 days ago = ~12 months = -12 points decay)
# Use Python for portable date calculation
OLD_TS=$(python3 -c "from datetime import datetime, timedelta; print((datetime.utcnow() - timedelta(days=365)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
echo "{\"ts\":\"$OLD_TS\",\"type\":\"pattern\",\"key\":\"old_entry\",\"insight\":\"Old observed pattern\",\"confidence\":10,\"source\":\"observed\",\"files\":[]}" > .superpowers/learnings.jsonl

OUTPUT=$("$PLUGIN_DIR/scripts/search-learnings.sh" --summary)

# Confidence should have decayed (10 - 12 = -2, capped at 1)
if echo "$OUTPUT" | grep -q "confidence: 1/10"; then
    log_pass "Confidence decay works (old entry decayed to minimum)"
else
    log_fail "Confidence decay failed: $OUTPUT"
fi

# ==========================================
# Test 10: Empty file handling
# ==========================================
echo "--- Test 10: Empty file handling ---"
setup

# No entries, file doesn't exist
OUTPUT=$("$PLUGIN_DIR/scripts/search-learnings.sh" --summary 2>&1 || true)

if [ -z "$OUTPUT" ]; then
    log_pass "Empty/missing file handled gracefully"
else
    log_fail "Empty file not handled: $OUTPUT"
fi

# ==========================================
# Summary
# ==========================================
echo ""
echo "=== Test Summary ==="
echo -e "${GREEN}Passed${NC}: $PASS"
echo -e "${RED}Failed${NC}: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
