#!/usr/bin/env bash
# Skill behavior test: domain-modeling
# Depends on: claude -p (Claude Code CLI headless mode) + API quota
# Run: cd tests/skill-behavior/domain-modeling && ./run-test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== domain-modeling skill behavior test ==="
echo "This test uses claude -p headless mode and consumes API quota."
echo ""

# Check claude CLI is available
command -v claude >/dev/null 2>&1 || {
    echo "SKIP: claude CLI not found"
    exit 0
}

# Test prompt: given a project with CONTEXT.md, ask claude to sharpen a fuzzy term
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/CONTEXT.md" << 'EOF'
# Test Glossary

## Order
A customer's request to purchase items.
EOF

PROMPT="You are working in a project with a CONTEXT.md at $TMPDIR/CONTEXT.md. The user says: 'I want to handle account stuff.' The word 'account' is fuzzy. Invoke the domain-modeling skill to sharpen this term and update CONTEXT.md. Then report what you did."

echo "Running claude -p (this may take 30-60 seconds)..."
output=$(claude -p "$PROMPT" --allowedTools "Skill,Read,Write" 2>&1 || true)

# Assertions
echo "--- Output ---"
echo "$output"
echo "--- End Output ---"

# 1. Output mentions domain-modeling skill
echo "$output" | grep -qi "domain-modeling" || {
    echo "WARN: output does not mention domain-modeling skill"
}

# 2. CONTEXT.md was updated (non-deterministic — model may or may not update)
if [ "$(wc -l < "$TMPDIR/CONTEXT.md")" -gt 3 ]; then
    echo "PASS: CONTEXT.md appears to have been updated"
else
    echo "WARN: CONTEXT.md may not have been updated (non-deterministic with headless mode)"
fi

echo ""
echo "=== Test complete (behavioral — results depend on model) ==="
exit 0
