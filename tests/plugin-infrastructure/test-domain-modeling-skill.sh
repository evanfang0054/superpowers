#!/usr/bin/env bash
# Test: domain-modeling SKILL.md frontmatter and structure
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/domain-modeling/SKILL.md"

# 1. File exists
[ -f "$SKILL_FILE" ] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }

# 2. Frontmatter has name: domain-modeling
head -20 "$SKILL_FILE" | grep -q "^name: domain-modeling" || {
    echo "FAIL: frontmatter missing 'name: domain-modeling'"; exit 1;
}

# 3. Frontmatter has description (non-empty, ≤500 chars)
desc=$(head -20 "$SKILL_FILE" | grep "^description:" | sed 's/^description: *//; s/^"//; s/"$//')
[ -n "$desc" ] || { echo "FAIL: frontmatter missing 'description'"; exit 1; }
[ ${#desc} -le 500 ] || { echo "FAIL: description exceeds 500 chars (${#desc})"; exit 1; }

# 4. Frontmatter has when_to_use
head -20 "$SKILL_FILE" | grep -q "^when_to_use:" || {
    echo "FAIL: frontmatter missing 'when_to_use'"; exit 1;
}

# 5. Frontmatter does NOT have disable-model-invocation: true (must be model-invoked)
if head -20 "$SKILL_FILE" | grep -q "^disable-model-invocation: *true"; then
    echo "FAIL: skill must be model-invoked (disable-model-invocation: true found)"; exit 1;
fi

# 6. Body has required sections
for section in "File structure" "During-session behaviors" "CONTEXT.md format" "ADR format" "Integration points"; do
    grep -q "##.*$section\|$section" "$SKILL_FILE" || {
        echo "FAIL: missing section '$section'"; exit 1;
    }
done

# 7. adr/ directory exists with .gitkeep
[ -d "$REPO_ROOT/docs/agent-harness/adr" ] || { echo "FAIL: docs/agent-harness/adr/ not found"; exit 1; }
[ -f "$REPO_ROOT/docs/agent-harness/adr/.gitkeep" ] || { echo "FAIL: adr/.gitkeep not found"; exit 1; }

echo "PASS: domain-modeling SKILL.md structure valid"
exit 0
