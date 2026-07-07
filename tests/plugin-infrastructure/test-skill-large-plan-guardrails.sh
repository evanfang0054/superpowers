#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

SKILLS_DIR="$REPO_ROOT/skills"

echo "=== Test: large-plan skill guardrails ==="

BRAINSTORMING="$SKILLS_DIR/brainstorming/SKILL.md"
WRITING_PLANS="$SKILLS_DIR/writing-plans/SKILL.md"
HARNESS_DESIGN="$SKILLS_DIR/harness-design/SKILL.md"

# RED for #77: large projects need segmentation before monolithic specs/plans.
if grep -q "execution map" "$BRAINSTORMING" && grep -q "大型任务分段" "$BRAINSTORMING"; then
    pass "brainstorming requires execution map for large tasks"
else
    fail "brainstorming requires execution map for large tasks"
fi

if grep -q "默认拆成多个 plan" "$WRITING_PLANS" && grep -q "GDD" "$WRITING_PLANS"; then
    pass "writing-plans checks GDD and splits large plans"
else
    fail "writing-plans checks GDD and splits large plans"
fi

if grep -q "设计同步点" "$WRITING_PLANS" && grep -q "design token" "$WRITING_PLANS"; then
    pass "writing-plans requires design synchronization points"
else
    fail "writing-plans requires design synchronization points"
fi

if grep -q "handoff contract" "$HARNESS_DESIGN" && grep -q "design token" "$HARNESS_DESIGN"; then
    pass "harness-design emits design handoff contract"
else
    fail "harness-design emits design handoff contract"
fi

print_summary "large-plan skill guardrails"
