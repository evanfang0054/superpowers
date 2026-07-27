#!/usr/bin/env bash
# Test: harness-init SKILL.md documents CONTEXT.md scaffold creation
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/harness-init/SKILL.md"

[ -f "$SKILL_FILE" ] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }

# 1. SKILL.md mentions CONTEXT.md
grep -q "CONTEXT.md" "$SKILL_FILE" || {
    echo "FAIL: harness-init SKILL.md does not mention CONTEXT.md"; exit 1
}

# 2. SKILL.md mentions domain-modeling skill
grep -q "domain-modeling" "$SKILL_FILE" || {
    echo "FAIL: harness-init SKILL.md does not reference domain-modeling skill"; exit 1
}

# 3. SKILL.md mentions gitignore option for CONTEXT.md
grep -qi "gitignore" "$SKILL_FILE" || {
    echo "FAIL: harness-init SKILL.md does not mention gitignore option"; exit 1
}

# 4. SKILL.md mentions docs/agent-harness/adr/
grep -q "docs/agent-harness/adr" "$SKILL_FILE" || {
    echo "FAIL: harness-init SKILL.md does not mention docs/agent-harness/adr/"; exit 1
}

# 5. SKILL.md mentions idempotent (safe to re-run on existing projects)
grep -qi "idempotent" "$SKILL_FILE" || {
    echo "FAIL: harness-init SKILL.md does not mention idempotency"; exit 1
}

echo "PASS: harness-init documents CONTEXT.md scaffold creation (idempotent)"
exit 0
