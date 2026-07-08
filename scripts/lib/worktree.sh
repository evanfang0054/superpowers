#!/usr/bin/env bash
# worktree.sh — Git worktree 生命周期管理 for auto-loop
# Usage: source scripts/lib/worktree.sh
#
# 所有函数都不 cd（caller 负责路径管理），保持纯函数式

# worktree_create <repo_root> <run_id> <branch_name>
# 输出 worktree 绝对路径到 stdout
# 处理分支重名：若分支已存在则复用，若 worktree 已存在则复用
worktree_create() {
    local repo_root="$1" run_id="$2" branch="$3"
    local wt_root="$repo_root/.claude/worktrees"
    local wt_path="$wt_root/auto-loop-$run_id"

    # worktree 已存在则直接复用
    if [ -d "$wt_path" ] && git -C "$wt_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "$wt_path"
        return 0
    fi

    if ! git -C "$repo_root" rev-parse --verify HEAD >/dev/null 2>&1; then
        echo "错误: 目标仓库还没有任何 commit，无法创建 git worktree。" >&2
        echo "当前 auto-loop 模式需要可创建 git worktree；请先提交初始 commit 后重试。" >&2
        return 1
    fi

    mkdir -p "$wt_root"

    local err
    # 检查分支是否已存在
    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        # 分支已存在，worktree add 不带 -b
        err=$(git -C "$repo_root" worktree add -q "$wt_path" "$branch" 2>&1) || {
            echo "错误: worktree 创建失败（分支 $branch 已存在但 worktree add 失败）" >&2
            [ -n "$err" ] && echo "$err" >&2
            return 1
        }
    else
        # 新分支
        err=$(git -C "$repo_root" worktree add -q -b "$branch" "$wt_path" 2>&1) || {
            echo "错误: worktree 创建失败" >&2
            [ -n "$err" ] && echo "$err" >&2
            return 1
        }
    fi
    echo "$wt_path"
}

# worktree_remove <repo_root> <wt_path>
worktree_remove() {
    local repo_root="$1" wt_path="$2"
    # 幂等：不存在直接返回
    [ -d "$wt_path" ] || return 0
    git -C "$repo_root" worktree remove --force "$wt_path" 2>/dev/null || rm -rf "$wt_path"
}

# worktree_exists <wt_path>
worktree_exists() {
    [ -d "$1" ] && git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# worktree_cleanup_all <repo_root> — 清理所有 auto-loop worktree（用于 --cleanup）
worktree_cleanup_all() {
    local repo_root="$1"
    local wt_root="$repo_root/.claude/worktrees"
    if [ -d "$wt_root" ]; then
        for wt in "$wt_root"/auto-loop-*; do
            [ -d "$wt" ] || continue
            git -C "$repo_root" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
        done
        rmdir "$wt_root" 2>/dev/null || true
    fi
}
