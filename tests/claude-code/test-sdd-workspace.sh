#!/usr/bin/env bash
# Tests for plan-scoped SDD workspaces and the scripts that write artifacts there.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD_SCRIPTS="$REPO_ROOT/skills/subagent-driven-development/scripts"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}
assert_exit_2() {
    local description=$1
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$description"
        echo "    expected exit 2, got 0"
    elif [[ $? -eq 2 ]]; then
        pass "$description"
    else
        local status=$?
        fail "$description"
        echo "    expected exit 2, got $status"
    fi
}
assert_equals() {
    local description=$1 expected=$2 actual=$3
    if [[ "$actual" == "$expected" ]]; then
        pass "$description"
    else
        fail "$description"
        echo "    expected: $expected"
        echo "    got:      $actual"
    fi
}
assert_not_equals() {
    local description=$1 left=$2 right=$3
    if [[ "$left" != "$right" ]]; then
        pass "$description"
    else
        fail "$description"
        echo "    both: $left"
    fi
}
cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

main() {
    echo "=== Test: sdd-workspace ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    git init -q -b main "$TEST_ROOT/repo"
    local repo
    repo="$(cd "$TEST_ROOT/repo" && git rev-parse --show-toplevel)"

    printf '# Plan A\n\n## Task 1: First thing\n\nDo the first thing.\n' > "$repo/plan-a.md"
    printf '# Plan B\n\n## Task 1: Other thing\n\nDo the other thing.\n' > "$repo/plan-b.md"
    local git_id=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)
    ( cd "$repo" && git add plan-a.md plan-b.md && git "${git_id[@]}" commit -qm c1 )

    assert_exit_2 "sdd-workspace requires PLAN_FILE" "$SDD_SCRIPTS/sdd-workspace"
    assert_exit_2 "sdd-workspace rejects a missing plan" "$SDD_SCRIPTS/sdd-workspace" no-such-plan.md

    local plan_a_dir plan_b_dir
    plan_a_dir="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" plan-a.md)"
    plan_b_dir="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" plan-b.md)"
    assert_equals "plan-a resolves to its named workspace" "$repo/.agent-harness/sdd/plan-a" "$plan_a_dir"
    assert_not_equals "different plans resolve to distinct workspaces" "$plan_a_dir" "$plan_b_dir"

    if [[ -f "$repo/.agent-harness/sdd/.gitignore" && "$(<"$repo/.agent-harness/sdd/.gitignore")" == "*" ]]; then
        pass "workspace parent has a self-ignoring .gitignore"
    else
        fail "workspace parent has a self-ignoring .gitignore"
    fi

    printf 'x\n' > "$plan_a_dir/artifact.md"
    local status
    status="$(cd "$repo" && git status --porcelain)"
    if [[ -z "$status" ]]; then
        pass "plan workspace is invisible to git status"
    else
        fail "plan workspace is invisible to git status"
        echo "    status: $status"
    fi

    ( cd "$repo" && git add -A )
    local staged
    staged="$(cd "$repo" && git diff --cached --name-only)"
    if [[ -z "$staged" ]]; then
        pass "git add -A does not stage the workspace"
    else
        fail "git add -A does not stage the workspace"
        echo "    staged: $staged"
    fi

    local brief_out brief_path
    brief_out="$(cd "$repo" && "$SDD_SCRIPTS/task-brief" plan-a.md 1)"
    brief_path="$(printf '%s\n' "$brief_out" | sed -n 's/^wrote \(.*\): [0-9][0-9]* lines$/\1/p')"
    assert_equals "task-brief writes under plan-a workspace" "$plan_a_dir/task-1-brief.md" "$brief_path"

    ( cd "$repo" \
        && printf 'y\n' > f && git add f \
        && git "${git_id[@]}" commit -qm c2 )
    local rp_out rp_path
    rp_out="$(cd "$repo" && "$SDD_SCRIPTS/review-package" plan-a.md HEAD~1 HEAD)"
    rp_path="$(printf '%s\n' "$rp_out" | sed -n 's/^wrote \(.*\): [0-9].*$/\1/p')"
    case "$rp_path" in
        "$plan_a_dir/"*) pass "review-package writes its diff under plan-a workspace" ;;
        *)
            fail "review-package writes its diff under plan-a workspace"
            echo "    got: $rp_path"
            ;;
    esac

    local wt="$TEST_ROOT/wt"
    ( cd "$repo" && git worktree add -q "$wt" -b wt-feature )
    local wt_root wt_dir
    wt_root="$(cd "$wt" && git rev-parse --show-toplevel)"
    wt_dir="$(cd "$wt" && "$SDD_SCRIPTS/sdd-workspace" plan-a.md)"
    assert_equals "linked worktree resolves plan-a under its own root" "$wt_root/.agent-harness/sdd/plan-a" "$wt_dir"
    assert_not_equals "linked worktree plan workspace differs from main" "$plan_a_dir" "$wt_dir"

    printf 'y\n' > "$wt_dir/artifact.md"
    local wt_status
    wt_status="$(cd "$wt" && git status --porcelain)"
    if [[ -z "$wt_status" ]]; then
        pass "linked worktree workspace is invisible to git status"
    else
        fail "linked worktree workspace is invisible to git status"
        echo "    status: $wt_status"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
