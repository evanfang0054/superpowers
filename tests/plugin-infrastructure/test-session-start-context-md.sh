#!/usr/bin/env bash
# Test: session-start hook injects CONTEXT.md glossary summary
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"

# Create temp project with CONTEXT.md
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR"
cat > "$TMPDIR/CONTEXT.md" << 'EOF'
# Test Project Domain Glossary

## Order
A customer's request to purchase items.

_Avoid_: basket, cart

## Cancellation
A request to void an Order before it ships.

_Avoid_: refund

## LineItem
A single product entry within an Order.
EOF

# Run hook with startup source, simulating Claude Code environment
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$REPO_ROOT"
export SESSION_SOURCE="startup"

# Provide startup payload on stdin
echo '{"source":"startup","session_id":"test-123"}' | bash "$HOOK" > "$TMPDIR/output.json" 2>/dev/null

# 1. Output contains ## Domain Glossary section
grep -q "## Domain Glossary" "$TMPDIR/output.json" || {
    echo "FAIL: output missing '## Domain Glossary' section"; exit 1
}

# 2. Output contains at least one term heading (Order, Cancellation, or LineItem)
grep -q "Order\|Cancellation\|LineItem" "$TMPDIR/output.json" || {
    echo "FAIL: output missing term content"; exit 1
}

# 4. Test missing CONTEXT.md — no glossary section but discovery hint appears
rm "$TMPDIR/CONTEXT.md"
echo '{"source":"startup","session_id":"test-456"}' | bash "$HOOK" > "$TMPDIR/output2.json" 2>/dev/null
grep -q "## Domain Glossary" "$TMPDIR/output2.json" || {
    echo "FAIL: output should contain '## Domain Glossary' discovery hint when CONTEXT.md missing"; exit 1
}
grep -q "No CONTEXT.md found" "$TMPDIR/output2.json" || {
    echo "FAIL: discovery hint text missing"; exit 1
}

# 4b. Test dismiss marker — no hint when .context-md-dismissed exists
mkdir -p "$TMPDIR/.agent-harness"
touch "$TMPDIR/.agent-harness/.context-md-dismissed"
echo '{"source":"startup","session_id":"test-456b"}' | bash "$HOOK" > "$TMPDIR/output2b.json" 2>/dev/null
grep -q "No CONTEXT.md found" "$TMPDIR/output2b.json" && {
    echo "FAIL: discovery hint should not appear when .context-md-dismissed exists"; exit 1
}
rm -rf "$TMPDIR/.agent-harness"

# 4. Test truncation with >20 terms
# Re-create with 25+ terms
cat > "$TMPDIR/CONTEXT.md" << 'EOF'
# Big Project Domain Glossary
EOF
for i in $(seq 1 25); do
    cat >> "$TMPDIR/CONTEXT.md" << EOF
## Term$i
Definition $i

_Avoid_: alias$i
EOF
done

echo '{"source":"startup","session_id":"test-789"}' | bash "$HOOK" > "$TMPDIR/output3.json" 2>/dev/null
# Should contain truncation pointer
grep -q "see CONTEXT.md\|terms total" "$TMPDIR/output3.json" || {
    echo "FAIL: output missing truncation pointer for >20 terms"; exit 1
}

echo "PASS: session-start CONTEXT.md injection works"
exit 0
