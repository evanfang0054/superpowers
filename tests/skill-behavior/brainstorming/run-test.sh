#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../_helpers/run-skill.sh"
source "$SCRIPT_DIR/../_helpers/assert-skill-triggered.sh"

OVERALL_FAILED=0

echo "=== Test: brainstorming (naive) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/naive-feature-request.txt" 3
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_output_contains "design\|spec\|question\|方案\|规格\|问题" "mentions design/spec"
print_skill_summary "brainstorming (naive)" || OVERALL_FAILED=1

# 重置计数器跑 explicit 场景
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (explicit) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/explicit-invoke.txt" 3
assert_skill_triggered "brainstorming"
assert_no_premature_action
print_skill_summary "brainstorming (explicit)" || OVERALL_FAILED=1

# 重置计数器跑 isolation/YAGNI pressure 场景
SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (isolation/YAGNI pressure) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/isolation-yagni-pressure.txt" 10
assert_skill_triggered "brainstorming"
assert_assistant_text_contains "isolat|隔离|boundar|边界|responsib|职责" "rejects shared mutable state through isolation/boundaries"
assert_assistant_text_contains "YAGNI|不需要|删除|移除|当前需求" "rejects speculative infrastructure with YAGNI"
assert_assistant_text_not_contains "visual companion|visual-companion" "does not mention Visual companion"
print_skill_summary "brainstorming (isolation/YAGNI pressure)" || OVERALL_FAILED=1

exit "$OVERALL_FAILED"
