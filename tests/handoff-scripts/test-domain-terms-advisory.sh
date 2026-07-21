#!/usr/bin/env bash
# Test: validate-handoff domain_terms advisory check
#
# Verifies the advisory check in scripts/lib/handoff-schema.sh:
#   1. Advisory only — WARNING to stderr, exit code unchanged
#   2. Only runs for spec stage (not plan/task)
#   3. Parses YAML inline flow sequence [Term1, Term2]
#   4. If CONTEXT.md missing → WARNING about missing file
#   5. If term not found as ## heading → WARNING about missing term
#   6. No warning when all terms found / when domain_terms absent
#
# Self-contained: sets up TMPDIR with both docs/agent-harness/index.md
# (for spec_topic validation) and CONTEXT.md (for advisory check), so the
# test does not depend on the state of the host repository.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATE="$REPO_ROOT/scripts/validate-handoff.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Self-contained project: index.md for spec_topic validation + CONTEXT.md for advisory
mkdir -p "$TMPDIR/docs/agent-harness/specs"
mkdir -p "$TMPDIR/docs/agent-harness/plans"
echo "- domain-modeling → specs/x.md" > "$TMPDIR/docs/agent-harness/index.md"

cat > "$TMPDIR/CONTEXT.md" << 'EOF'
# Test Glossary

## Order
A customer's request to purchase items.

## Cancellation
A request to void an Order.
EOF

export CLAUDE_PROJECT_DIR="$TMPDIR"

# --- Test 1: spec with domain_terms, all terms exist in CONTEXT.md → no warning, exit 0 ---
cat > "$TMPDIR/spec1.md" << 'EOF'
---
spec_topic: domain-modeling
decision_summary: "test"
design_approved: true
user_approved_at: 2026-07-21T00:00:00Z
gates: [user-review-passed]
domain_terms: [Order, Cancellation]
---

# Test Spec
EOF

output=$("$VALIDATE" --stage spec --file "$TMPDIR/spec1.md" 2>&1)
exit_code=$?
[ "$exit_code" -eq 0 ] || { echo "FAIL: test1 exit code $exit_code (expected 0)"; echo "$output"; exit 1; }
echo "$output" | grep -qi "WARNING.*domain_term" && {
    echo "FAIL: test1 should not have WARNING for valid terms"; echo "$output"; exit 1
}
echo "PASS: test1 — valid terms, no warning"

# --- Test 2: spec with domain_terms, one term missing → WARNING, exit 0 (advisory) ---
cat > "$TMPDIR/spec2.md" << 'EOF'
---
spec_topic: domain-modeling
decision_summary: "test"
design_approved: true
user_approved_at: 2026-07-21T00:00:00Z
gates: [user-review-passed]
domain_terms: [Order, NonExistentTerm]
---

# Test Spec
EOF

output2=$("$VALIDATE" --stage spec --file "$TMPDIR/spec2.md" 2>&1)
exit_code2=$?
[ "$exit_code2" -eq 0 ] || { echo "FAIL: test2 exit code $exit_code2 (expected 0, advisory only)"; echo "$output2"; exit 1; }
echo "$output2" | grep -qi "WARNING.*NonExistentTerm" || {
    echo "FAIL: test2 should have WARNING for missing term NonExistentTerm"; echo "$output2"; exit 1
}
echo "PASS: test2 — missing term triggers WARNING, exit 0"

# --- Test 3: spec without domain_terms → no warning, exit 0 ---
cat > "$TMPDIR/spec3.md" << 'EOF'
---
spec_topic: domain-modeling
decision_summary: "test"
design_approved: true
user_approved_at: 2026-07-21T00:00:00Z
gates: [user-review-passed]
---

# Test Spec
EOF

output3=$("$VALIDATE" --stage spec --file "$TMPDIR/spec3.md" 2>&1)
exit_code3=$?
[ "$exit_code3" -eq 0 ] || { echo "FAIL: test3 exit code $exit_code3 (expected 0, no domain_terms)"; echo "$output3"; exit 1; }
echo "$output3" | grep -qi "WARNING.*domain_term" && {
    echo "FAIL: test3 should not have domain_term WARNING (no domain_terms field)"; echo "$output3"; exit 1
}
echo "PASS: test3 — no domain_terms field, no warning"

# --- Test 4: spec with domain_terms but CONTEXT.md missing → WARNING about missing file, exit 0 ---
TMPDIR_NOCTX=$(mktemp -d)
mkdir -p "$TMPDIR_NOCTX/docs/agent-harness/specs"
echo "- domain-modeling → specs/x.md" > "$TMPDIR_NOCTX/docs/agent-harness/index.md"
cat > "$TMPDIR_NOCTX/spec4.md" << 'EOF'
---
spec_topic: domain-modeling
decision_summary: "test"
design_approved: true
user_approved_at: 2026-07-21T00:00:00Z
gates: [user-review-passed]
domain_terms: [Order]
---

# Test Spec
EOF

ORIG_CLAUDE_PROJECT_DIR="$CLAUDE_PROJECT_DIR"
export CLAUDE_PROJECT_DIR="$TMPDIR_NOCTX"
output4=$("$VALIDATE" --stage spec --file "$TMPDIR_NOCTX/spec4.md" 2>&1)
exit_code4=$?
export CLAUDE_PROJECT_DIR="$ORIG_CLAUDE_PROJECT_DIR"
rm -rf "$TMPDIR_NOCTX"
[ "$exit_code4" -eq 0 ] || { echo "FAIL: test4 exit code $exit_code4 (expected 0, advisory only)"; echo "$output4"; exit 1; }
echo "$output4" | grep -qi "WARNING.*CONTEXT.md" || {
    echo "FAIL: test4 should have WARNING about missing CONTEXT.md"; echo "$output4"; exit 1
}
echo "PASS: test4 — missing CONTEXT.md triggers WARNING, exit 0"

# --- Test 5: plan stage with domain_terms → no domain_term warning (spec-only check) ---
cat > "$TMPDIR/docs/agent-harness/specs/s.md" << 'EOF'
---
spec_topic: domain-modeling
decision_summary: "test"
design_approved: true
user_approved_at: 2026-07-21T00:00:00Z
gates: [user-review-passed]
---

# Spec
EOF
cat > "$TMPDIR/docs/agent-harness/plans/p.md" << 'EOF'
---
spec_ref: ../specs/s.md
spec_topic: domain-modeling
task_count: 1
estimated_phases: [impl]
dod: contract-x
domain_terms: [Order, NonExistentTerm]
---

# Plan
EOF

output5=$("$VALIDATE" --stage plan --file "$TMPDIR/docs/agent-harness/plans/p.md" 2>&1)
exit_code5=$?
[ "$exit_code5" -eq 0 ] || { echo "FAIL: test5 exit code $exit_code5 (expected 0)"; echo "$output5"; exit 1; }
echo "$output5" | grep -qi "WARNING.*domain_term" && {
    echo "FAIL: test5 should not have domain_term WARNING (plan stage, not spec)"; echo "$output5"; exit 1
}
echo "PASS: test5 — plan stage skips domain_terms advisory"

echo ""
echo "PASS: domain_terms advisory check works"
exit 0
