#!/usr/bin/env bash
# Test: index-knowledge-base.sh auto-indexes ADRs with spec_topic: adr
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INDEX_SCRIPT="$REPO_ROOT/scripts/index-knowledge-base.sh"

[ -x "$INDEX_SCRIPT" ] || [ -f "$INDEX_SCRIPT" ] || {
    echo "FAIL: index-knowledge-base.sh not found"; exit 1
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Simulate a project KB with adr/ directory
mkdir -p "$TMPDIR/docs/agent-harness/adr"

cat > "$TMPDIR/docs/agent-harness/adr/0001-test-decision.md" << 'EOF'
---
spec_topic: adr
title: "0001-test-decision"
decision_summary: "Test ADR for indexing"
date: 2026-07-21
status: accepted
---

# ADR 0001: Test Decision

## Context
Test context.

## Decision
Test decision.
EOF

# Run index-knowledge-base.sh on the temp KB
# The script scans for frontmatter spec_topic and generates index.md
export CLAUDE_PROJECT_DIR="$TMPDIR"
bash "$INDEX_SCRIPT" "$TMPDIR/docs/agent-harness" 2>/dev/null || true

# 1. adr/index.md was generated
[ -f "$TMPDIR/docs/agent-harness/adr/index.md" ] || {
    echo "FAIL: adr/index.md not generated"; exit 1
}

# 2. index.md contains the ADR entry
grep -q "0001-test-decision\|0001.*test" "$TMPDIR/docs/agent-harness/adr/index.md" || {
    echo "FAIL: adr/index.md does not contain 0001-test-decision entry"; exit 1
}

echo "PASS: ADR indexing works"
exit 0
