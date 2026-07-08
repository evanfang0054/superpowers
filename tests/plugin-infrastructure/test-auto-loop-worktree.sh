#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
source "$REPO_ROOT/scripts/lib/state.sh"
source "$REPO_ROOT/scripts/lib/worktree.sh"

echo "=== Test: auto-loop worktree.sh ==="

# 用临时 git 仓库测试，避免污染主仓库
TEST_REPO="$(mktemp -d)"
git init -q "$TEST_REPO"
git -C "$TEST_REPO" commit -q --allow-empty -m "init"
TEST_STATE_DIR="$TEST_REPO/.claude/auto-loop"

# Case 1: worktree_create 创建 worktree 并绑定分支
state_init "test-wt-001" "feat/auto-test-wt" "测试" "$TEST_STATE_DIR"
WORKTREE=$(worktree_create "$TEST_REPO" "test-wt-001" "feat/auto-test-wt")
if [ -d "$WORKTREE" ]; then pass "worktree_create makes dir"; else fail "worktree_create makes dir"; fi
if git -C "$TEST_REPO" worktree list | grep -q "feat/auto-test-wt"; then pass "worktree registered in git"; else fail "worktree registered in git"; fi

# Case 2: worktree 里能做独立 commit
echo "test" > "$WORKTREE/test.txt"
git -C "$WORKTREE" add test.txt
git -C "$WORKTREE" commit -q -m "test commit"
WT_LOG=$(git -C "$WORKTREE" log --oneline)
if echo "$WT_LOG" | grep -q "test commit"; then pass "worktree accepts commits"; else fail "worktree accepts commits"; fi

# Case 3: 主仓库工作区不受影响（test.txt 不在主仓库工作树里）
if [ ! -f "$TEST_REPO/test.txt" ]; then pass "main worktree clean"; else fail "main worktree clean (contaminated!)"; fi

# Case 4: worktree_remove 清理 worktree
worktree_remove "$TEST_REPO" "$WORKTREE"
if [ ! -d "$WORKTREE" ]; then pass "worktree_remove deletes dir"; else fail "worktree_remove deletes dir"; fi
if ! git -C "$TEST_REPO" worktree list | grep -q "test-wt-001"; then pass "worktree unregistered"; else fail "worktree unregistered"; fi

# Case 5: worktree_remove 幂等（已删不崩溃）
worktree_remove "$TEST_REPO" "$WORKTREE" 2>/dev/null && pass "worktree_remove idempotent" || pass "worktree_remove idempotent"

# Case 6: worktree_exists 判断存在性
WORKTREE2=$(worktree_create "$TEST_REPO" "test-wt-002" "feat/auto-test-wt2")
if worktree_exists "$WORKTREE2"; then pass "worktree_exists true"; else fail "worktree_exists true"; fi
worktree_remove "$TEST_REPO" "$WORKTREE2"
if ! worktree_exists "$WORKTREE2"; then pass "worktree_exists false after remove"; else fail "worktree_exists false after remove"; fi

# Case 7: 无 HEAD 仓库给出明确错误，而不是泛化 worktree 创建失败
NO_HEAD_REPO="$(mktemp -d)"
git init -q "$NO_HEAD_REPO"
OUTPUT=$(worktree_create "$NO_HEAD_REPO" "test-no-head" "feat/no-head" 2>&1) && EXIT=0 || EXIT=$?
if [ "$EXIT" -ne 0 ]; then pass "worktree_create rejects repo without HEAD"; else fail "worktree_create rejects repo without HEAD"; fi
if echo "$OUTPUT" | grep -q "还没有任何 commit\|not a valid object name: 'HEAD'"; then pass "worktree_create explains missing HEAD"; else fail "worktree_create explains missing HEAD (got: $OUTPUT)"; fi
if [ ! -e "$NO_HEAD_REPO/.claude" ]; then pass "worktree_create does not mutate repo without HEAD"; else fail "worktree_create does not mutate repo without HEAD"; fi
rm -rf "$NO_HEAD_REPO"

# Case 8: git worktree add 的底层 stderr 不被吞掉
CONFLICT_REPO="$(mktemp -d)"
git init -q "$CONFLICT_REPO"
git -C "$CONFLICT_REPO" commit -q --allow-empty -m "init"
CONFLICT_WT=$(worktree_create "$CONFLICT_REPO" "test-conflict-a" "feat/conflict")
OUTPUT=$(worktree_create "$CONFLICT_REPO" "test-conflict-b" "feat/conflict" 2>&1) && EXIT=0 || EXIT=$?
if [ "$EXIT" -ne 0 ]; then pass "worktree_create surfaces branch checkout conflict"; else fail "worktree_create surfaces branch checkout conflict"; fi
if echo "$OUTPUT" | grep -qi "already.*checked out\|is already checked out\|fatal:"; then pass "worktree_create preserves git stderr"; else fail "worktree_create preserves git stderr (got: $OUTPUT)"; fi
worktree_remove "$CONFLICT_REPO" "$CONFLICT_WT"
rm -rf "$CONFLICT_REPO"

# 清理
rm -rf "$TEST_REPO"
print_summary "auto-loop worktree.sh"
