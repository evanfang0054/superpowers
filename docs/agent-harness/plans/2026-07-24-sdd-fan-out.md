---
spec_ref: ../specs/2026-07-24-sdd-fan-out-design.md
spec_topic: sdd-fan-out
task_count: 10
estimated_phases: [tests, implementation, verification]
dod: "SDD Fan-Out 上线：plan 支持 Blocking: none 标注实现并行 dispatch，新脚本 session-init/state/merge-fix 就位，review-package 支持 file-scope 越界检测，cleanup-workspace 覆盖 session 目录，controller-guide 红牌更新，finishing-a-development-branch 和 writing-plans 同步更新，全部 skill 加载测试通过。"
---

# SDD Fan-Out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 SDD (Subagent-Driven Development) 引入 Fan-Out 能力——当 plan 任务标注 `Blocking: none` 时，orchestrator 并行 dispatch 多个 implementer 在隔离 worktree 中工作，完成后自动 merge 回 orchestrator 分支。

**Architecture:** 新增 3 个脚本（session-init、state 管理、merge-fix prompt）、修改 2 个现有脚本（review-package 加越界检测、cleanup-workspace 支持 session 隔离）、修改 4 个 prompt 文件（SKILL.md orchestrator 加入 Fan-Out 工作流、implementer-prompt 加 worktree 边界、task-reviewer-prompt 加 file-scope 检查、merge-fix-prompt 新文件）、更新 3 个 skill 文档（controller-guide 红牌、finishing-a-development-branch cleanup 覆盖、writing-plans 的 Blocking 编写指导）。

**非 git 项目：** 如果当前项目不是 git 仓库（`git rev-parse --show-toplevel` 失败），Fan-Out 不可用，退化为当前串行 SDD 行为。不引入新复杂度。

**Tech Stack:** Shell scripts + Markdown prompts + git worktree

**Language:** 所有 skill 文件（SKILL.md、prompt 模板、脚本注释和用户可见文本）使用英文。Plan 文档本身使用中文。

---
**Commit strategy:** 手动提交，plan 末尾统一 commit。

---

### Task 1: 新增 session-init + state 管理脚本

Blocking: none
Slice type: verification
Seam: 脚本可用性（`bash scripts/session-init.sh --help` 可运行）

**Files:**
- Create: `skills/subagent-driven-development/scripts/session-init.sh`
- Create: `skills/subagent-driven-development/scripts/sdd-state.sh`
- Create: `skills/subagent-driven-development/scripts/sdd-worktree.sh`

- [ ] **Step 1: 创建 session-init.sh**

```bash
#!/usr/bin/env bash
# session-init.sh — SDD Fan-Out session initialization
# Creates session ID, session directory, initial state.json
#
# Usage: session-init.sh <orchestrator-branch> <plan-file>
# Output: echo session directory path
# Env: exports SDD_SESSION_ID, SDD_SESSION_DIRset -euo pipefail

if [ $# -lt 2 ] || [ "$1" = "--help" ]; then
  echo "usage: session-init.sh <orchestrator-branch> <plan-file>" >&2
  exit 1
fi

ORCH_BRANCH="$1"
PLAN_FILE="$2"

# plan file must exist and be readable
if [ ! -f "$PLAN_FILE" ]; then
  echo "error: plan file not found: $PLAN_FILE" >&2
  exit 1
fi
SESSION_ID=$(openssl rand -hex 4 2>/dev/null || echo "$(date +%s | shasum | head -c8)")
export SDD_SESSION_ID="$SESSION_ID"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
SESSION_DIR="$REPO_ROOT/.agent-harness/sdd/$SESSION_ID"
mkdir -p "$SESSION_DIR"

export SDD_SESSION_DIR="$SESSION_DIR"
mkdir -p "$SESSION_DIR"

# Parse tasks from plan: extract ### Task N: headings and
# Blocking / files field values
parse_tasks_from_plan() {
  local plan="$1"
  local in_task=0
  local current_task=""
  local task_count=0

  while IFS= read -r line; do
    if echo "$line" | grep -qE '^### Task [0-9]+:'; then
      [ -n "$current_task" ] && echo "$current_task"
      task_count=$((task_count + 1))
      current_task=$(echo "$line" | sed -E 's/^### (Task [0-9]+):.*/\1/')
    elif echo "$line" | grep -qE '^Blocking: '; then
      current_task="$current_task|blocking:$(echo "$line" | sed 's/^Blocking: //')"
    elif echo "$line" | grep -qE '^files: '; then
      current_task="$current_task|files:$(echo "$line" | sed 's/^files: //')"
    fi
  done < "$plan"
  [ -n "$current_task" ] && echo "$current_task"
}

# Write initial state.json
cat > "$SESSION_DIR/state.json" << STATEEOF
{
  "session_id": "$SESSION_ID",
  "orchestrator_branch": "$ORCH_BRANCH",
  "concurrency_limit": 3,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_dir": "$SESSION_DIR",
  "plan_file": "$PLAN_FILE",
  "nodes": {},
  "phases": {
    "dispatch": "pending",
    "merge": "pending",
    "integration": "pending"
  }
}
STATEEOF

echo "$SESSION_DIR"
```

- [ ] **Step 2: 创建 sdd-state.sh**

```bash
#!/usr/bin/env bash
# sdd-state.sh — SDD Fan-Out state 读写库
# Usage: source sdd-state.sh
#
# Depends on SDD_SESSION_DIR (set by session-init.sh)

# sdd_state_get <jq_path> — read a value from state.json
sdd_state_get() {
  local path="$1"
  jq -r "$path" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_set <jq_path> <value_json> — write a JSON value to state.json
sdd_state_set() {
  local path="$1" value="$2"
  local tmp="$SDD_SESSION_DIR/state.json.tmp"
  jq "$path = $value" "$SDD_SESSION_DIR/state.json" > "$tmp" && mv "$tmp" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_set_str <jq_path> <raw_string> — safe string write (auto-jq-escape)
# Safe string injection (auto-escapes via jq -R)
sdd_state_set_str() {
  local path="$1" raw="$2"
  local tmp="$SDD_SESSION_DIR/state.json.tmp"
  jq --arg v "$raw" "$path = \$v" "$SDD_SESSION_DIR/state.json" > "$tmp" && mv "$tmp" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_add_node <task-key> <json-object> — add a node to state.nodes
# 向 state.nodes 添加一个节点
sdd_state_add_node() {
  local key="$1" value="$2"
  local tmp="$SDD_SESSION_DIR/state.json.tmp"
  jq ".nodes[\"$key\"] = $value" "$SDD_SESSION_DIR/state.json" > "$tmp" && mv "$tmp" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_exists <path> — check if state.json exists
sdd_state_exists() {
  [ -f "$SDD_SESSION_DIR/state.json" ]
}
```

- [ ] **Step 3: 创建 sdd-worktree.sh**（worktree 生命周期管理）

```bash
#!/usr/bin/env bash
# sdd-worktree.sh — SDD Fan-Out worktree 生命周期管理
# 为每个 implementer 创建/删除隔离的 git worktree
# Usage: source sdd-worktree.sh
#
# Depends on: SDD_SESSION_ID (set by session-init.sh)

# sdd_worktree_create <repo_root> <task_key> <base_branch>
# 输出 worktree 绝对路径到 stdout
sdd_worktree_create() {
  local repo_root="$1" task_key="$2" base_branch="$3"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_root="$repo_root/.claude/worktrees/sdd-$session_id"
  local wt_path="$wt_root/$task_key"
  local branch="_sdd/$session_id/$task_key"

  mkdir -p "$wt_root"

  if [ -d "$wt_path" ] && git -C "$wt_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "$wt_path"
    return 0
  fi

  local err
  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    err=$(git -C "$repo_root" worktree add -q "$wt_path" "$branch" 2>&1) || {
      echo "error: worktree add failed (branch $branch exists but worktree add failed)" >&2
      [ -n "$err" ] && echo "$err" >&2
      return 1
    }
  else
    err=$(git -C "$repo_root" worktree add -q -b "$branch" "$wt_path" "$base_branch" 2>&1) || {
      echo "error: worktree creation failed" >&2
      [ -n "$err" ] && echo "$err" >&2
      return 1
    }
  fi
  echo "$wt_path"
}

# sdd_worktree_remove <repo_root> <task_key> [--keep-branch]
# --keep-branch: remove worktree dir but keep the local branch (for intervention_needed)
sdd_worktree_remove() {
  local repo_root="$1" task_key="$2" keep_branch="${3:-}"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_path="$repo_root/.claude/worktrees/sdd-$session_id/$task_key"
  local branch="_sdd/$session_id/$task_key"

  [ -d "$wt_path" ] || return 0

  git -C "$repo_root" worktree remove --force "$wt_path" 2>/dev/null || rm -rf "$wt_path"
  if [ "$keep_branch" != "--keep-branch" ]; then
    git -C "$repo_root" branch -d "$branch" 2>/dev/null || true
  fi
}
# sdd_worktree_exists <repo_root> <task_key>
sdd_worktree_exists() {
  local repo_root="$1" task_key="$2"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_path="$repo_root/.claude/worktrees/sdd-$session_id/$task_key"
  [ -d "$wt_path" ] && git -C "$wt_path" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# sdd_cleanup_all_worktrees <repo_root> — 清理当前 session 所有 worktree
sdd_cleanup_all_worktrees() {
  local repo_root="$1"
  local session_id="${SDD_SESSION_ID:?SDD_SESSION_ID not set}"
  local wt_root="$repo_root/.claude/worktrees/sdd-$session_id"
  if [ -d "$wt_root" ]; then
    for wt in "$wt_root"/*/; do
      [ -d "$wt" ] || continue
      git -C "$repo_root" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
    done
    rmdir "$wt_root" 2>/dev/null || true
  fi
}
```

- [ ] **Step 4: 验证脚本可执行**

Run: `bash skills/subagent-driven-development/scripts/session-init.sh --help 2>&1 | head -3`
Expected: 显示 usage 信息

Run: `source skills/subagent-driven-development/scripts/sdd-state.sh && echo "OK"`
Expected: `OK`

Run: `source skills/subagent-driven-development/scripts/sdd-worktree.sh && echo "OK"`
Expected: `OK`

---

### Task 2: 创建 merge-fix prompt 模板

Blocking: none
Slice type: verification
Seam: 文件存在

**Files:**
- Create: `skills/subagent-driven-development/merge-fix-prompt.md`

- [ ] **Step 1: 创建 merge-fix-prompt.md**

```markdown
# Merge-Fix Subagent Prompt Template

Use this template when `git merge --no-ff` produces conflict markers
that cannot be resolved automatically. The merge-fix subagent reads the
conflict and decides which version to keep.

```
Subagent (general-purpose):
  description: "Resolve merge conflict for task: [task name]"
  model: [MODEL — REQUIRED: choose per SKILL.md Model Selection]
  prompt: |
    You are resolving a git merge conflict between two parallel implementer
    branches. Your job is to read the conflicted files, decide the correct
    resolution, and commit the merge.

    ## Context

    The merge target (orchestrator branch): [ORCH_BRANCH]
    The branch being merged: [MERGE_BRANCH]

    These two branches ran in parallel — they started from the same base
    commit and modified different (or sometimes overlapping) files.

    ## Conflicted Files

    Run `git diff --name-only --diff-filter=U` to list conflicted files.
    For each conflicted file:
    1. Read the file to see the conflict markers
    2. Understand what each side intended
    3. Decide the resolution:
       - Keep one side if the other is outdated
       - Combine both if they address different concerns
       - If truly incompatible, flag as UNSOLVABLE

    ## Resolution Rules

    - Prefer the implementer's version when both sides add similar code to
      the same area (the implementer branch has the intended change)
    - Keep changes from the orchestrator branch (i.e., previously merged
      tasks) when the implementer touched code it shouldn't have
    - If a file was deleted on one side and modified on the other, prefer
      keeping the modified version unless deletion was intentional

    ## Steps

    1. `git diff --name-only --diff-filter=U` — list conflicts
    2. For each conflicted file, read and resolve
    3. `git add <resolved-files>`
    4. `git commit --no-edit` (accepts the auto-generated merge message)

    If you cannot resolve (the conflict represents genuinely incompatible
    changes to the same logic), report back with status UNSOLVABLE and
    list each conflicted file with the incompatible change descriptions.
```

- [ ] **Step 2: 验证文件存在**

Run: `ls -la skills/subagent-driven-development/merge-fix-prompt.md`
Expected: 文件存在

---

### Task 3: review-package 新增 file-scope 越界检测

Blocking: none
Slice type: refactor
Seam: `review-package BASE HEAD` 输出中新增 "File-scope check" 行

**Files:**
- Modify: `skills/subagent-driven-development/scripts/review-package`

- [ ] **Step 1: 在 review-package 末尾添加越界检测**
- [ ] **Step 0: Update review-package argument guard**

   Update the argument guard from `$# -gt 3` to `$# -gt 4` to accept
   the optional 4th file-scope argument:
  
  ```
  # Before:  if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  # After:   if [ $# -lt 2 ] || [ $# -gt 4 ]; then
  ```


在 `review-package` 脚本末尾、`echo` 输出行之前，添加 file-scope 比较逻辑：

```bash
# --- File-scope violation check (SDD Fan-Out) ---
# If caller passes optional 4th argument <file-scope-list>,
# verify all changed files in the diff are within this scope.
if [ $# -ge 4 ] && [ -n "$4" ]; then
  IFS=',' read -ra SCOPE_FILES <<< "$4"
  VIOLATIONS=()

  # Normalize scope files: trim whitespace, strip leading ./ prefix
  NORM_SCOPE=()
  for sf in "${SCOPE_FILES[@]}"; do
    sf=$(echo "$sf" | sed 's/^ *//;s/ *$//;s|^\./||')
    NORM_SCOPE+=("$sf")
  done

  # Get changed files from the diff (normalize paths too)
  while IFS= read -r changed_file; do
    [ -z "$changed_file" ] && continue
    changed_file=$(echo "$changed_file" | sed 's|^\./||')
    found=0
    for scope_file in "${NORM_SCOPE[@]}"; do
      if [ "$changed_file" = "$scope_file" ]; then
        found=1
        break
      fi
    done
    if [ "$found" -eq 0 ]; then
      VIOLATIONS+=("$changed_file")
    fi
  done < <(git diff --name-only "${base}".."${head}")

  if [ ${#VIOLATIONS[@]} -gt 0 ]; then
    { echo "FILE_SCOPE_VIOLATION:"; for v in "${VIOLATIONS[@]}"; do echo "  - $v"; done; } >> "$out"
    echo "file-scope violations: ${#VIOLATIONS[@]}" >&2
  else
    echo "file-scope check: passed" >> "$out"
  fi
fi
```

修改后的完整脚本调整为：在 `echo "wrote ..."` 之前，先判断是否有第 4 个参数，执行越界检查。

- [ ] **Step 2: 验证旧功能不破坏**

Run: `cd "$REPO" && git rev-parse HEAD > /dev/null && BASE=$(git rev-parse HEAD~1 2>/dev/null || echo HEAD) && HEAD=$(git rev-parse HEAD) && bash skills/subagent-driven-development/scripts/review-package "$BASE" "$HEAD" 2>&1`
Expected: 能够正常输出 diff package

---

### Task 4: cleanup-workspace 支持 session 隔离

Blocking: none
Slice type: refactor
Seam: `cleanup-workspace` 运行时也清理 session 命名的子目录

**Files:**
- Modify: `skills/subagent-driven-development/scripts/cleanup-workspace`

- [ ] **Step 1: 修改 cleanup-workspace 清理 session 目录**

将原来的"清空 `.agent-harness/sdd/` 内容"改为"清空整个 `.agent-harness/sdd/` 目录（包括子目录如 session ID 目录），同时清理 `.claude/worktrees/sdd-*`：

```bash
dir="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}/.agent-harness/sdd"

if [ ! -d "$dir" ]; then
  exit 0
fi

shopt -s dotglob nullglob
if rm -rf "${dir:?}/"*; then
  echo "cleaned: $dir"
else
  echo "warning: cleanup-workspace failed to remove contents of $dir" >&2
fi

# 额外清理：SDD Fan-Out worktree 目录（不 git worktree remove，
# 因为分支可能已删除，用 rm -rf 兜底）
wt_root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}/.claude/worktrees"
for wt_dir in "$wt_root"/sdd-*; do
  [ -d "$wt_dir" ] || continue
  rm -rf "$wt_dir" 2>/dev/null || true
  echo "cleaned worktree: $wt_dir"
done

exit 0
```

- [ ] **Step 2: 验证执行不报错**

Run: `bash skills/subagent-driven-development/scripts/cleanup-workspace 2>&1`
Expected: 输出 `cleaned:` 行，exit code 0

---

### Task 5: implementer-prompt.md 加入 worktree 路径 + file-scope

Blocking: none
Slice type: refactor
Seam: prompt 模板文件中新增 [WORKTREE_PATH] 和 [FILE_SCOPE] 占位符

**Files:**
- Modify: `skills/subagent-driven-development/implementer-prompt.md`

- [ ] **Step 1: 在 implementer-prompt.md 的 Context 区域前添加 worktree 说明**

在 `## Context` 章节前插入：

```markdown
    ## Worktree Boundary

    You are working in an isolated git worktree at: [WORKTREE_PATH]
    
    **CRITICAL:** You may ONLY modify files in the following scope:
    [FILE_SCOPE]
    
    If no file scope is specified, you may work on any file related to the task.
    If a file scope IS specified, modifying files outside that scope is a
    **SEVERITY VIOLATION** that will trigger human intervention.
    
    Work from: [WORKTREE_PATH]
```

然后在 `## Your Job` 章节中，将 `Work from: [directory]` 替换为对 worktree 路径的引用。

在报告格式章节，在 `- Files changed` 之后添加一条：

```markdown
    - File-scope check: modified files within scope (see WORKTREE BOUNDARY)
```

- [ ] **Step 2: 验证占位符存在**

Run: `grep -c 'WORKTREE_PATH\|FILE_SCOPE' skills/subagent-driven-development/implementer-prompt.md`
Expected: 至少 3 处匹配

---

### Task 6: task-reviewer-prompt.md 加入 file-scope 越界检查指令

Blocking: none
Slice type: refactor
Seam: prompt 模板中新增 file-scope 检查段落

**Files:**
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md`

- [ ] **Step 1: 在 Spec Compliance 部分末尾添加越界检查**

在 `## Part 1: Spec Compliance` 末尾追加：

```markdown
    ### File-Scope Compliance (SDD Fan-Out)
    
    If a task brief specifies a file scope, verify that ALL modified files
    in the diff fall within this scope. The diff file may contain a
    `FILE_SCOPE_VIOLATION:` section at the bottom — if present, the
    controller has already flagged these as violations.
    
    Your job: if you see FILE_SCOPE_VIOLATION entries, confirm them:
    - TRUE: the file is genuinely outside the task's file scope
      → escalate to Critical finding
    - FALSE: the file is related enough (e.g., a dependency required by a
      file in scope) → suggest the implementer update the file-scope in
      the brief and note as Minor
```

- [ ] **Step 2: 验证改动**

Run: `grep -c 'File-Scope Compliance' skills/subagent-driven-development/task-reviewer-prompt.md`
Expected: 1

---

### Task 7: controller-guide.md 更新红牌

Blocking: none
Slice type: refactor
Seam: 第 117 行的"Never: Dispatch multiple implementation subagents in parallel" 已改为有条件允许

**Files:**
- Modify: `skills/subagent-driven-development/references/controller-guide.md`

- [ ] **Step 1: 修改红牌规则**

将第 117 行的：
```
- Dispatch multiple implementation subagents in parallel (conflicts).
```
改为：
```
- Dispatch multiple implementation subagents in parallel UNLESS the plan
  task explicitly annotates `Blocking: none` (SDD Fan-Out). When a plan
  uses Fan-Out, each implementer runs in an isolated git worktree and
  the orchestrator handles merge + conflict resolution. Tasks without
  `Blocking: none` must still run sequentially per the existing workflow.
```

- [ ] **Step 2: 验证改动**

Run: `grep 'Blocking: none' skills/subagent-driven-development/references/controller-guide.md`
Expected: 匹配到改后的内容

---

### Task 8: finishing-a-development-branch: verify cleanup coverage

**Files:** None needed — cleanup-workspace (Task 4) already extended.

- [ ] **Step 1: Verify**

  The finishing-a-development-branch SKILL.md already calls cleanup-workspace
  after every option (lines 90, 115, 127, 152). The cleanup-workspace script
  (Task 4) now clears session worktrees too — no changes needed.

---

### Task 9: writing-plans SKILL.md 添加 Blocking: none + files: 编写指导

Blocking: none
Slice type: refactor
Seam: writing-plans SKILL.md template includes Blocking: none annotation guide

**Files:**
- Check: `skills/finishing-a-development-branch/SKILL.md` — 确认 cleanup 步骤已存在
- Check: `skills/subagent-driven-development/scripts/cleanup-workspace` — 确认已包含 Fan-Out worktree 清理

- [ ] **Step 1: 检查 finishing SKILL.md**

确认 `skills/finishing-a-development-branch/SKILL.md` 中所有 4 个 option 的 cleanup 步骤都正确调用 `cleanup-workspace`。当前代码已验证为：
```

```markdown
## SDD Fan-Out Annotations (optional)

When a plan has multiple tasks with no dependencies, SDD (Subagent-Driven
Development) can dispatch them in parallel. Annotate each task with:

- **`Blocking: none`** — no dependencies; can run in parallel with other
  `Blocking: none` tasks
- **`Blocking: Task N`** — depends on Task N; runs after Task N merges
- **`files: path/to/file`** (optional, recommended) — files the task
  intends to modify, used for conflict detection
  - Multiple files: comma-separated: `files: src/a.ts, tests/a.test.ts`
  - If omitted the orchestrator skips file-conflict checks

**Read-after-write dependencies**: if Task B needs to **read** code that
Task A modified (even if B only writes to different files), annotate
`Blocking: Task A`. Plan authors own semantic dependencies; the
orchestrator does not infer them.

**Backward compatibility**: if any task in a plan lacks the `Blocking:`
field, the orchestrator falls back to sequential execution (current
behavior).

Example:
```markdown
### Task 1: Implement user model
Blocking: none
files: src/user.ts, tests/user.test.ts

### Task 2: Implement order model
Blocking: none
files: src/order.ts, tests/order.test.ts

### Task 3: Integrate user and order
Blocking: Task 1, Task 2
files: src/integration.ts
```

Task 1 and Task 2 run in parallel; Task 3 waits for both.

### Task heading format

Plan task headings MUST use `### Task N: Description` format. The
orchestrator parses task boundaries with this regex. Plans with
non-standard headings (e.g., `### Step 1`) fall back to sequential
execution.
```

- [ ] **Step 2: Verify changes**

Run: `grep -c 'SDD Fan-Out' skills/writing-plans/SKILL.md`
Expected: 1

---

### Task 10: SDD SKILL.md — orchestrator prompt 加入 Fan-Out 工作流

Blocking: Task 1, Task 2, Task 3, Task 5, Task 6, Task 7
Slice type: tracer-bullet
Seam: orchestrator 能在发现 plan 有 `Blocking: none` 任务时启用并行分支

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`

- [ ] **Step 1: 在 SKILL.md 的 orchestrator prompt 中添加 Fan-Out 分支**

在现有 ORCHESTRATOR WORKFLOW 的 step 2 "For the NEXT pending task" 之前，插入 Fan-Out 检测分支。修改 `=== ORCHESTRATOR WORKFLOW (per iteration) ===` 如下：

```
=== ORCHESTRATOR WORKFLOW (per iteration) ===

**Fan-Out Detection:**
After reading the plan, check if ANY task has `Blocking: none`:
- If NO — run serial workflow below (existing behavior)
- If YES — run Fan-Out workflow (see FAN-OUT WORKFLOW section below)

**FAN-OUT WORKFLOW (for plans with Blocking: none tasks):**

0. RESUME CHECK: If `.agent-harness/sdd/` has existing state files:
   - Read the latest `state.json`
   - For each node: `in_progress` and worktree exists → keep running; `completed` with no merge → merge now; `intervention_needed` → flag; `pending` → keep
   - Resume where it left off (do not restart completed nodes)

0. INIT (if no resume): Run `"$SDD_SKILL_DIR/scripts/session-init.sh" "$(git branch --show-current)" "$PLAN_FILE"`
   → SESSION_DIR (save for all subsequent steps)

1. Parse the plan: extract all tasks with Blocking / files fields.
   Build a DAG: nodes = tasks, edges = Blocking dependencies.

2. DISPATCH LOOP:
   While nodes remain unstarted or in_progress:
     a. Find all nodes with status=pending AND all blocking deps in 'completed' or empty
     b. Select up to concurrency_limit (default 3) nodes
     c. For each selected node:
        - Create worktree via `sdd_worktree_create "$REPO_ROOT" "$TASK_KEY" "$ORCH_BRANCH"`
        - Update state via sdd_state: node.status = in_progress
        - Save worktree_path, branch to state
     d. **Same message: dispatch ALL selected implementers in parallel**
        Agent(implementer-N) with:
          - task brief (via `"$SDD_SKILL_DIR/scripts/task-brief"`)
          - WORKTREE_PATH → worktree directory
          - FILE_SCOPE → from plan's `files:` field or "ALL" if omitted
     e. Wait for all implementers to return
     f. For each returned implementer (serial, needs review agent):
        i. **Check for contradiction signals** — if implementer output contains
           "contradiction", "conflict", "requirement A but" → flag as intervention_needed
        ii. Record BASE commit (before task): git rev-parse HEAD in worktree
        iii. Generate review package:
            `"$SDD_SKILL_DIR/scripts/review-package" BASE HEAD [FILE_SCOPE_LIST]`
        iv. Dispatch TASK REVIEWER with review package + file-scope check
        v. **no-progress detection (spec §7):** append reviewer findings to
           state.retry_findings_history. If the same finding text appeared
           in the last 2 entries → intervention_needed (stuck in loop)
        vi. Review passes → state.node.status = completed
            Review fails → retry_count++; if < max_retries → dispatch fix
            If max_retries reached or FILE_SCOPE_VIOLATION → intervention_needed
     g. If any node is intervention_needed → keep running other nodes, flag at end

3. MERGE PHASE (serial, topological order):
   For each completed node, in DAG order:
     a. `git merge --no-ff _sdd/{session}/{task-key}`
     b. If conflict:
        - Read conflicted files
        - Dispatch merge-fix subagent with merge-fix-prompt.md
        - merge-fix fails → intervention_needed
     c. Remove worktree (keep branch if node had intervention_needed, else delete):
        `sdd_worktree_remove "$REPO_ROOT" "$TASK_KEY"` (default: delete branch)
        If intervention_needed: `sdd_worktree_remove "$REPO_ROOT" "$TASK_KEY" --keep-branch`
     d. Update state: node.merge = completed

4. INTEGRATION: Run tests in orchestrator branch
   - Pass → proceed to finishing-a-development-branch
   - Fail → dispatch fix agent

5. CLEANUP: `sdd_cleanup_all_worktrees "$REPO_ROOT"`
   + `sdd_state_set '.phases.dispatch = "completed"'`
```

5. Keep the serial WORKFLOW as the default fallback; skip it when Fan-Out is active.

Note: orchestrator does not need full script code in the prompt — function names and key paths are enough.

- [ ] **Step 2: 在 SKILL.md 的脚本引用列表添加新脚本引用**

在现有脚本引用（`"$SDD_SKILL_DIR/scripts/task-brief"` 等）之后添加：
```bash
  \"\$SDD_SKILL_DIR/scripts/session-init.sh\"  # SDD Fan-Out: session init
  \"\$SDD_SKILL_DIR/scripts/sdd-state.sh\"     # SDD Fan-Out: state read-write
  \"\$SDD_SKILL_DIR/scripts/sdd-worktree.sh\" # SDD Fan-Out: worktree management
  \"\$SDD_SKILL_DIR/merge-fix-prompt.md\"      # SDD Fan-Out: merge conflict resolution template
```

---

### 统一提交

所有任务完成后，执行：

```bash
git add skills/subagent-driven-development/ skills/finishing-a-development-branch/SKILL.md skills/writing-plans/SKILL.md
git commit -m "feat(sdd): add Fan-Out parallel implementer dispatch

- New scripts: session-init.sh, sdd-state.sh, sdd-worktree.sh
- New prompt: merge-fix-prompt.md for conflict resolution
- review-package: add optional file-scope violation detection
- cleanup-workspace: extend to clean session worktree directories
- implementer-prompt: add worktree path + file scope constraints
- task-reviewer-prompt: add file-scope compliance check
- controller-guide: update red card to allow parallel with Blocking: none
- writing-plans: add Blocking: none / files: writing guide
- SKILL.md: add Fan-Out orchestrator workflow with DAG dispatch"
```
