---
spec_ref: ../specs/2026-07-29-upstream-v6-2-adaptation-design.md
spec_topic: upstream-v6-2-adaptation
status: completed
task_count: 8
estimated_phases: [tests, implementation, verification]
dod: "以逐能力适配方式同步已核验的 Superpowers v6.2.0 行为：确定性修复、计划专属 SDD workspace、计划身份 ledger、五轮 scoped re-review、受限 finishing 生命周期与 TDD/review 规则；不回退 Agent Harness 的品牌、多平台策略、Ralph Loop、双轴 review 和默认独立分支工作流。"
---

# 上游 v6.2.0 适配实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以文件级三方适配吸收已核验的 Superpowers v6.2.0 行为，同时保持 Agent Harness 的 `.agent-harness` 路径、Ralph Loop、多平台 hooks 与默认独立分支策略。

**Architecture:** 先用确定性 shell tests 固定脚本与配置契约，再按 expand → migrate → contract 升级 SDD artifact API：`sdd-workspace PLAN_FILE` 成为唯一路径解析点，所有 brief、report、review package 和 ledger 绑定同一 plan workspace。随后将 scoped re-review / 五轮 breaker 写入 SDD controller 契约，finishing 只消费已完成的 lifecycle 状态；最后单独以 behavior tests 证明 TDD/review/流程 skill 文案变更。

**Tech Stack:** Bash (`set -euo pipefail`), Git plumbing, JSON hook configuration, Markdown behavior-shaping skills, Claude Code headless tests.

**Commit strategy:** 不在任务中创建 commit。全部完成且用户审阅完整 diff、验证证据后再手动决定提交拆分。

---

## Source Facts and Design Sync

| 上游来源 | 本计划采用的事实 | Fork 适配 |
|---|---|---|
| `6015d37`, `c8921b5` | `find-polluter` 规范化前导 `./`、匹配 `**/` 的零层/嵌套层、空集合计数为 0 | 保持两个位置参数和 Agent Harness 路径 |
| `5151e7a`, `52f649e` | Claude SessionStart command 增加 `"shell": "bash"` | 保留本项目额外 hook；不改 Codex hook |
| `0e13ad8` | case-insensitive prose helpers、`assert_order` 完整输出诊断、SDD diff-trust patterns | 保留现有 macOS/Linux timeout fallback 与 900 秒 timeout |
| `6df8ba1`, `b8a2d84`, `2dbbaed` | `sdd-workspace PLAN_FILE`、`basename "$PLAN_FILE" .md`、plan ledger identity | `.superpowers/sdd` 映射为 `.agent-harness/sdd`；不虚称处理同名 basename 冲突 |
| `87e4050`, `ebdd4ec`, `28882fc` | `re-review-prompt.md`、五轮修复、4–5 轮升档、final one-fixer/one-re-review | 不能 resume 时显式传递 brief/report/findings；BLOCKED 停止 Ralph 当前 plan |
| `0b47219`, `9dff1a9`, `bcfe798` | 提前捕获 worktree path、explicit-only discard、owned-worktree cleanup、forge-neutral PR 文义 | 默认隔离为新分支；只有用户明确要求才使用 worktree |
| `9d8630d`, `caa1826`, `b9e75dd`, `cfb6281` | good-tests reference、Mutation Check、reviewer 精确上下文 | 保留 seam-first 与 Standards/Spec 双轴 |

## File Structure

- Create: `tests/systematic-debugging/test-find-polluter.sh` — upstream bugfix 的确定性回归测试。
- Modify: `skills/systematic-debugging/find-polluter.sh` — pattern 规范化、零层匹配与空集合计数。
- Modify: `hooks/hooks.json` — Claude SessionStart 条目加入 `shell: bash`。
- Modify: `docs/windows/polyglot-hooks.md` — 将示例收敛到实际 `run-hook.cmd session-start` 和 bash dispatch。
- Modify: `tests/plugin-infrastructure/test-hooks-config.sh` — hook JSON 契约断言。
- Modify: `tests/claude-code/test-helpers.sh` — prose assertion 与顺序失败诊断。
- Modify: `tests/claude-code/test-subagent-driven-development.sh` — SDD diff-trust 关键词兼容性。
- Modify: `skills/subagent-driven-development/scripts/sdd-workspace` — plan-first workspace resolver。
- Modify: `skills/subagent-driven-development/scripts/task-brief` — plan workspace 默认输出。
- Modify: `skills/subagent-driven-development/scripts/review-package` — `PLAN_FILE BASE HEAD` 接口。
- Modify: `skills/subagent-driven-development/scripts/cleanup-workspace` — current-plan-only cleanup。
- Modify: `tests/claude-code/test-sdd-workspace.sh` — plan API、隔离与范围契约。
- Modify: `tests/sdd-scripts/test-cleanup-workspace.sh` — plan cleanup 不影响 sibling workspace。
- Modify: `tests/claude-code/run-skill-tests.sh` — 登记 workspace 确定性测试。
- Modify: `skills/subagent-driven-development/SKILL.md` — plan ledger、review/fix/final-review 主流程。
- Modify: `skills/subagent-driven-development/references/controller-guide.md` — controller 的完整五轮和 call-site 契约。
- Modify: `skills/subagent-driven-development/implementer-prompt.md` — plan-scoped report 与修复追加契约。
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md` — 新 review-package 接口说明。
- Create: `skills/subagent-driven-development/re-review-prompt.md` — scoped re-review 专用 prompt。
- Modify: `tests/skill-behavior/subagent-driven-development/` fixtures and `run-test.sh` — SDD 行为压力测试。
- Modify: `skills/finishing-a-development-branch/SKILL.md` — explicit discard、worktree ownership、artifact cleanup 时序、独立分支默认。
- Modify: `skills/executing-plans/SKILL.md` — 默认新建独立分支、worktree 显式使用与 finishing 生命周期衔接。
- Modify: `tests/skill-behavior/finishing-a-development-branch/` fixtures and `run-test.sh` — finishing 行为压力测试。
- Create or modify: `tests/sdd-scripts/test-finishing-contract.sh` — 不依赖模型的 finishing lifecycle 文本/路径契约测试；并登记在现有确定性入口。
- Create: `skills/test-driven-development/writing-good-tests.md` — 按需 good-tests reference。
- Modify: `skills/test-driven-development/SKILL.md` — 任意测试写作时加载该 reference。
- Modify: `skills/requesting-code-review/SKILL.md` — reviewer 精确上下文与 diff 隔离。
- Modify: `skills/{brainstorming,writing-plans,writing-skills,verification-before-completion,dispatching-parallel-agents}/SKILL.md` — 仅已核验的重复 recap 删除/就近重排；不触碰 fork 专有质量门禁。
- Modify: corresponding `tests/skill-behavior/<skill>/` fixtures and `run-test.sh` — 各 skill 的 baseline / pressure evidence。
- Modify: `docs/agent-harness/plans/index.md` — 索引本计划。

---

### Task 1: 固定脚本、hook 与 headless helper 的 v6.2 稳定性补丁

Blocking: none  
Slice type: tracer-bullet  
Seam: `find-polluter.sh <target> <pattern>` 的 stdout / exit code、`hooks/hooks.json` 的 SessionStart 条目、helper assertion 返回状态。

**Source commits:** `6015d37`, `c8921b5`, `5151e7a`, `52f649e`, `0e13ad8`.

**Files:**
- Create: `tests/systematic-debugging/test-find-polluter.sh`
- Modify: `skills/systematic-debugging/find-polluter.sh`
- Modify: `hooks/hooks.json`
- Modify: `docs/windows/polyglot-hooks.md`
- Modify: `tests/plugin-infrastructure/test-hooks-config.sh`
- Modify: `tests/claude-code/test-helpers.sh`
- Modify: `tests/claude-code/test-subagent-driven-development.sh`

- [ ] **Step 1: 写 `find-polluter` 的失败回归测试**

创建临时 Git/Node fixture 和 stub `npm`，将被执行的测试文件记录到临时文件。测试必须断言如下四个可见结果：

```bash
run_polluter "src/**/*.test.ts"
assert_called "src/top.test.ts"
assert_called "src/nested/deep.test.ts"

run_polluter "./src/**/*.test.ts"
assert_same_called_files_as_previous

run_polluter "missing/**/*.test.ts"
assert_output_contains "Found 0 test files"
```

测试脚本使用与当前 shell suite 相同的 `pass` / `fail` / `cleanup` 模式，并在 `PATH` 最前注入 stub `npm`，避免运行真实 npm。

- [ ] **Step 2: 运行新测试，确认当前实现失败**

Run:

```bash
bash tests/systematic-debugging/test-find-polluter.sh
```

Expected: FAIL；至少零层 `src/top.test.ts` 或带 `./` pattern / 空集合断言失败。

- [ ] **Step 3: 以最小变更修复 pattern 解析与计数**

在调用 `find` 前标准化 pattern，并同时查询原 pattern 和移除一个 `**/` 的变体；以 `sort -u` 去重。空集合必须在 shell 中显式成为 `0`，不能再通过 `echo "" | wc -l` 计数。目标结构：

```bash
TEST_PATTERN="${TEST_PATTERN#./}"
TEST_FILES=$( {
  find . -path "./$TEST_PATTERN"
  find . -path "./${TEST_PATTERN//\*\*\//}"
} | sort -u )

if [[ -z "$TEST_FILES" ]]; then
  TOTAL=0
else
  TOTAL=$(printf '%s\n' "$TEST_FILES" | wc -l | tr -d ' ')
fi
```

保持两个位置参数、现有污染检测循环与非零 exit 语义不变。

- [ ] **Step 4: 将 Windows hook 实际配置与文档对齐**

在 Claude SessionStart 的现有 hook object 中、与 `command` 同级添加：

```json
"shell": "bash"
```

不得修改 `startup|clear|compact` matcher，不新增 `resume`，不移除 Session ID 写入、PreToolUse、SubagentStop、Stop 或 Codex hook。将 Windows 文档的主示例改为实际 wrapper 形式：

```json
{
  "matcher": "startup|clear|compact",
  "hooks": [{
    "type": "command",
    "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
    "shell": "bash"
  }]
}
```

解释 PowerShell/CMD fallback 的解析风险，但不要恢复已弃用的 `session-start.cmd` / `session-start.sh` 双文件示例为规范配置。

- [ ] **Step 5: 扩展 hook / headless helper 断言**

在 `test-hooks-config.sh` 中解析 JSON 并断言 Claude SessionStart object 的 command 仍以 `run-hook.cmd session-start` 结束且 `shell` 等于 `bash`。在 helpers 中将 prose regex 检查统一为 case-insensitive；`assert_order` 找不到任一模式时输出完整 `$RESULT`。在 SDD Test 5 的 reviewer skepticism 正则中接受 `not.*trust`、`read.*diff`、`trust.*diff` 等大小写变体，不删除现有断言。

- [ ] **Step 6: 运行确定性与 headless-helper 验证**

Run:

```bash
bash tests/systematic-debugging/test-find-polluter.sh
bash tests/plugin-infrastructure/test-hooks-config.sh
bash tests/claude-code/test-subagent-driven-development.sh
```

Expected: 前两个确定性测试 PASS；第三个若因 `claude`、API 配额或 headless 环境失败，保留完整真实输出并记录原因，不将环境失败标为通过。

---

### Task 2: 以 PLAN_FILE 扩展 SDD workspace API 并迁移所有活跃调用方

Blocking: Task 1  
Slice type: refactor  
Seam: `sdd-workspace PLAN_FILE`、`task-brief PLAN_FILE TASK_NUMBER` 和 `review-package PLAN_FILE BASE HEAD` 的 stdout、exit code 和默认 artifact 路径。

**Source commits:** `6df8ba1`, `b8a2d84`, `2dbbaed`.

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-workspace`
- Modify: `skills/subagent-driven-development/scripts/task-brief`
- Modify: `skills/subagent-driven-development/scripts/review-package`
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/subagent-driven-development/references/controller-guide.md`
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md`
- Modify: `tests/claude-code/test-sdd-workspace.sh`
- Modify: `tests/claude-code/run-skill-tests.sh`

- [ ] **Step 1: 扩展失败测试为 plan-first API 契约**

更新 `test-sdd-workspace.sh`：在 fixture repo 创建 `plan-a.md` 与 `plan-b.md`，新增如下断言：

```bash
assert_exit_2 "$SDD_SCRIPTS/sdd-workspace"
assert_exit_2 "$SDD_SCRIPTS/sdd-workspace" no-such-plan.md
assert_equals "$repo/.agent-harness/sdd/plan-a" "$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" plan-a.md)"
assert_not_equals "$repo/.agent-harness/sdd/plan-a" "$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace" plan-b.md)"
```

将 brief 调用改为 `task-brief plan-a.md 1`；将 package 调用改为 `review-package plan-a.md HEAD~1 HEAD`。断言所有默认 artifact 位于 `plan-a/`，并且 linked worktree 的同名 plan 解析到该 linked worktree 自己的根目录。

- [ ] **Step 2: 运行测试，确认旧无参 API 失败**

Run:

```bash
bash tests/claude-code/test-sdd-workspace.sh
```

Expected: FAIL；当前 `sdd-workspace` 仍接受无参数，且 artifact 位于共享 `.agent-harness/sdd/`。

- [ ] **Step 3: 实现唯一的 plan workspace resolver**

将 `sdd-workspace` usage 改为 `sdd-workspace PLAN_FILE`，并实现上游相同的 basename slug 规则：

```bash
if [ $# -ne 1 ]; then
  echo "usage: sdd-workspace PLAN_FILE" >&2
  exit 2
fi

plan=$1
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 2; }
slug=$(basename "$plan" .md)
[ -n "$slug" ] && [ "$slug" != "." ] && [ "$slug" != ".." ] \
  || { echo "cannot derive a workspace name from: $plan" >&2; exit 2; }
root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
base="$root/.agent-harness/sdd"
dir="$base/$slug"
mkdir -p "$dir"
printf '*\n' > "$base/.gitignore"
cd "$dir" && pwd
```

不得在此任务添加 hash、lowercase 或路径编码；同名 basename 冲突是明确保留的上游边界。

- [ ] **Step 4: 迁移 brief/package 脚本接口**

`task-brief` 无 `OUTFILE` 时必须调用：

```bash
dir=$("$(cd "$(dirname "$0")" && pwd)/sdd-workspace" "$plan")
out="$dir/task-${n}-brief.md"
```

`review-package` usage 与参数解析改为：

```bash
# Usage: review-package PLAN_FILE BASE HEAD [OUTFILE]
plan=$1
base=$2
head=$3
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 2; }
```

无 `OUTFILE` 时调用 `sdd-workspace "$plan"`，但继续使用 caller 给定的 `${base}..${head}` 生成 `git log`、`git diff --stat` 和 `git diff -U10`。不得替换为 `HEAD~1`。

- [ ] **Step 5: 全局迁移活跃 runtime/test 接口引用**

只改活跃实现与测试，不篡改历史 spec/plan。更新以下位置的命令与说明：

```text
skills/subagent-driven-development/SKILL.md
skills/subagent-driven-development/references/controller-guide.md
skills/subagent-driven-development/task-reviewer-prompt.md
tests/claude-code/test-sdd-workspace.sh
```

其中 final review 文义必须为：

```bash
scripts/review-package PLAN_FILE MERGE_BASE HEAD
```

在 `run-skill-tests.sh` 的 quick test array 中登记 `test-sdd-workspace.sh`，保证该确定性测试不再只靠人工手动执行。

- [ ] **Step 6: 验证 API 与全局调用迁移**

Run:

```bash
bash tests/claude-code/test-sdd-workspace.sh
bash tests/claude-code/run-skill-tests.sh --test test-sdd-workspace.sh
git grep -nE 'review-package(\.sh)?[[:space:]]+(HEAD|\$BASE|BASE)' -- skills tests
```

Expected: 两个 workspace 命令 PASS；最后一个搜索不应命中仍使用旧两参数运行接口的活跃实现/测试，历史文档不在搜索范围内。

---

### Task 3: 添加计划身份 Ledger、scoped re-review 与五轮 SDD 修复闭环

Blocking: Task 2  
Slice type: tracer-bullet  
Seam: 当前 plan 的 `progress.md`、`task-<n>-report.md`、`review-package PLAN_FILE FIX_BASE HEAD` 与 re-reviewer verdict。

**Source commits:** `b8a2d84`, `87e4050`, `ebdd4ec`, `28882fc`.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/subagent-driven-development/references/controller-guide.md`
- Modify: `skills/subagent-driven-development/implementer-prompt.md`
- Modify: `skills/subagent-driven-development/task-reviewer-prompt.md`
- Create: `skills/subagent-driven-development/re-review-prompt.md`
- Modify: `tests/skill-behavior/subagent-driven-development/prompts/*`
- Modify: `tests/skill-behavior/subagent-driven-development/run-test.sh`
- Modify: `tests/claude-code/test-subagent-driven-development.sh`

- [ ] **Step 1: 写 SDD 的 failing pressure scenarios**

在现有 SDD behavior suite 增加独立 fixtures，至少覆盖：

```text
Scenario A: 一个 task reviewer 返回 Important finding；期望 controller 使用 FIX_BASE..HEAD 创建 package，并调用 scoped re-review，不重新审全仓。
Scenario B: 连续三轮无法解决同一 finding；期望第 4 轮 fresh implementer，模型能力高一档。
Scenario C: 第五轮后 finding 仍是 load-bearing；期望 ledger 写 BLOCKED 且停止继续派发。
Scenario D: final whole-branch review 有 finding；期望最多一个 fixer 和一次 scoped re-review。
```

用输出中可观察的 command、round、`ADDRESSED` / `NOT ADDRESSED`、`BLOCKED` 断言；不要求测试虚构真实 Agent resume API。

- [ ] **Step 2: 运行 behavior test，确认缺少 v6.2 流程**

Run:

```bash
cd tests/skill-behavior/subagent-driven-development && ./run-test.sh
```

Expected: 新 scenarios FAIL，因为当前 skill 没有 re-review prompt、五轮 breaker、plan identity 或 final one-re-review 契约。

- [ ] **Step 3: 加入 plan identity 与 ledger 格式**

在 SDD pre-flight/controller guide 中要求 workspace 为：

```bash
scripts/sdd-workspace PLAN_FILE
```

并定义 ledger 的首行与恢复条件：

```markdown
# SDD ledger — plan: <plan file path>
```

仅这个值与 `PLAN_FILE` 一致时读取 completed tasks 或末轮修复状态。记录格式使用上游事实：

```markdown
Task <N>: minor (deferred): <one-liner>
Task <N>: fix round <R>/5 (<X> addressed, <Y> open — <finding one-liners>; commits <a7>..<b7>)
Task <N>: parked — <finding> — ruling: <why the code stands>
Task <N>: BLOCKED — <reason>
Task <N>: complete (commits <base7>..<head7>, review clean)
```

明确 `.agent-harness/sdd` 是 git-ignored，`git clean -fdx` 会删除 artifacts；恢复依据是 Git 历史，不承诺自动恢复。

- [ ] **Step 4: 新增 scoped re-review prompt 并接入 controller**

创建 `re-review-prompt.md`，输入必须为：原 open findings、brief path、同一 task report path、`FIX_BASE..HEAD` package path。输出固定包括：每个原 finding 的 `ADDRESSED` / `NOT ADDRESSED`、fix diff 新引入的 Critical/Important breakage、out-of-scope observation、round verdict。

明确禁止：将 re-review 扩大成 whole-branch review；将未触及代码的观察加入修复轮次；信任 implementer report 而不读 diff package。

在 task reviewer placeholder 文档中把 `[DIFF_FILE]` 的生成方式改为 `review-package PLAN_FILE BASE HEAD`；保留它作为初始全 task review，不以 re-review prompt 替代。

- [ ] **Step 5: 实现五轮与 final-review controller 契约**

在 `SKILL.md` 保持简短流程，在 `controller-guide.md` 写出完整路由：

```text
Trigger: spec ❌, Critical, Important, or controller-confirmed Cannot verify from diff.
Rounds 1–3: resume original implementer; without resume support, fresh dispatch carries brief + report + findings.
Rounds 4–5: fresh implementer, at least one model tier stronger.
Every round: append fix evidence to task-N-report.md; run review-package PLAN_FILE FIX_BASE HEAD; dispatch re-review.
Round 5: park only non-load-bearing / disputable findings with ruling; write BLOCKED and stop current plan for load-bearing findings.
Final review: review-package PLAN_FILE MERGE_BASE HEAD; one fixer; one scoped re-review; adjudicate residuals; never start a second fix wave.
```

明确 `BASE` 是 dispatch 前记录的 commit，不能以 `HEAD~1` 代替。current-plan workspace 仅在 final whole-branch review clean 且接受的修复已在当前实现分支时清理；该 cleanup 在进入 finishing options 前发生。

- [ ] **Step 6: 运行 SDD 行为与加载验证**

Run:

```bash
cd tests/skill-behavior/subagent-driven-development && ./run-test.sh
cd ../../claude-code && ./run-skill-tests.sh --test test-subagent-driven-development.sh
```

Expected: behavior scenarios PASS；headless 测试若因 CLI/API 环境失败，记录输出，不伪造通过。检查新 `re-review-prompt.md` 被 `SKILL.md` / controller guide 实际引用。

---

### Task 4: 收紧 finishing 生命周期并落实默认独立分支策略

Blocking: Task 3  
Slice type: tracer-bullet  
Seam: finishing 菜单文本、`WORKTREE_PATH` 捕获/ownership rule、current-plan cleanup 调用时机、执行计划前的隔离决策。

**Source commits:** `0b47219`, `9dff1a9`, `bcfe798`, `ebdd4ec`.

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`
- Modify: `skills/executing-plans/SKILL.md`
- Modify: `skills/subagent-driven-development/scripts/cleanup-workspace`
- Modify: `tests/sdd-scripts/test-cleanup-workspace.sh`
- Create: `tests/sdd-scripts/test-finishing-contract.sh`
- Modify: `tests/plugin-infrastructure/run-all.sh` or the existing deterministic test entry that owns `tests/sdd-scripts/`
- Modify: `tests/skill-behavior/finishing-a-development-branch/prompts/*`
- Modify: `tests/skill-behavior/finishing-a-development-branch/run-test.sh`

- [ ] **Step 1: 写失败的 cleanup / finishing contract tests**

扩展 cleanup 测试：创建 `plan-a/` 和 `plan-b/`，调用 plan-aware cleanup 后断言仅 `plan-a/` 被删除，`plan-b/` 和根 `.gitignore` 保留。新 finishing contract 测试以静态文本/脚本契约断言：

```text
- WORKTREE_PATH 在任何 `cd` 到主仓前捕获。
- 只有 `.worktrees/` 或 `worktrees/` 子路径能调用 `git worktree remove`。
- 默认菜单不包含 Discard。
- PR / Keep 不调用 cleanup-workspace。
- executing-plans 说明未指定位置时创建独立分支，worktree 只在用户明确请求时使用。
```

- [ ] **Step 2: 运行测试，确认当前共享 cleanup / 四选项行为失败**

Run:

```bash
bash tests/sdd-scripts/test-cleanup-workspace.sh
bash tests/sdd-scripts/test-finishing-contract.sh
```

Expected: FAIL；当前 cleanup 清空整个 `.agent-harness/sdd` 并移除 `.gitignore`，finishing 将 discard 作为标准第 4 项且所有选项 cleanup。

- [ ] **Step 3: 将 cleanup-workspace 收紧为 plan-aware 操作**

将接口改为 `cleanup-workspace PLAN_FILE`，通过同目录 `sdd-workspace "$plan"` 得到 current-plan workspace，并只删除该目录：

```bash
if [ $# -ne 1 ]; then
  echo "usage: cleanup-workspace PLAN_FILE" >&2
  exit 2
fi

workspace=$("$(cd "$(dirname "$0")" && pwd)/sdd-workspace" "$1")
rm -rf "$workspace"
```

如果清理失败，维持当前 warning + exit 0 的 best-effort 语义；不要删除 `.agent-harness/sdd/.gitignore` 或 sibling plan 目录。

- [ ] **Step 4: 重写 finishing 时序与安全选项**

在 `finishing-a-development-branch/SKILL.md`：

1. 在任何目录切换前计算 `GIT_DIR`、`GIT_COMMON`、`WORKTREE_PATH`。
2. 仅对已捕获路径且位于 `.worktrees/` / `worktrees/` 下的项目拥有 worktree 执行 `git worktree remove`；其他 workspace 保留。
3. 正常 / named worktree 菜单只保留 local merge、push + create PR、keep as-is；detached HEAD 只保留 push as new branch + create PR、keep as-is。
4. discard 只在用户明确提出时才展示 branch、commits、worktree，并要求精确输入 `discard`。
5. merge 后验证失败即停止并保留分支/worktree；PR/Keep 保留 worktree。
6. 删除所有 finishing option 内无参 `cleanup-workspace` 调用；current-plan cleanup 已由 Task 3 的 final-review-clean transition 处理。

PR 表述使用 forge-neutral 文义；实际可用时可用 `gh pr create`，但不得将 `gh` 当作唯一流程语义。

- [ ] **Step 5: 同步 executing-plans 的默认隔离约束**

在读取/执行实现 plan 前写出以下决策树：

```text
用户指定分支：在该分支执行。
用户未指定隔离位置：创建独立分支后执行。
用户明确请求 worktree：创建或进入 worktree。
未经用户明确请求：不使用 worktree。
```

保留现有“未经同意不得在 main/master 实现”约束。不得引用已删除的 `using-git-worktrees` skill。

- [ ] **Step 6: 运行确定性与 finishing behavior 验证**

Run:

```bash
bash tests/sdd-scripts/test-cleanup-workspace.sh
bash tests/sdd-scripts/test-finishing-contract.sh
cd tests/skill-behavior/finishing-a-development-branch && ./run-test.sh
```

Expected: 两个 shell contract tests PASS；behavior 测试展示 explicit-only discard、PR/Keep artifact 保留与 host-owned worktree 不删除。headless 环境失败时记录真实原因。

---

### Task 5: 恢复 TDD good-tests reference 并保持 seam-first

Blocking: Task 1  
Slice type: tracer-bullet  
Seam: 测试写作请求对 `writing-good-tests.md` 的按需读取，以及输出中可观察的 production-break / real-behavior / Mutation Check 约束。

**Source commits:** `e74961c`, `50025d1`, `9d8630d`, `517a9c6`, `caa1826`, `b9e75dd`.

**Files:**
- Create: `skills/test-driven-development/writing-good-tests.md`
- Modify: `skills/test-driven-development/SKILL.md`
- Modify: `tests/skill-behavior/test-driven-development/prompts/*`
- Modify: `tests/skill-behavior/test-driven-development/run-test.sh`

- [ ] **Step 1: 写 TDD pressure baseline / failing behavior test**

增加三个 prompts：

```text
- 只要求“给 helper 加测试”的任务：期望先选 observable seam，说明 production mutation 会如何导致测试失败。
- 要求断言 generated source string 的任务：期望改为运行脚本并检查 output / side effect / exit code。
- 要求 mock 内部 helper 并断言 mock 调用的任务：期望说明测试真实行为，复杂 mock 时转 integration test。
```

assertions 必须同时要求既有 seam-first / failing-test-first，避免新增 reference 覆盖现有硬门禁。

- [ ] **Step 2: 运行 baseline，确认 reference 尚不存在 / 行为不完整**

Run:

```bash
cd tests/skill-behavior/test-driven-development && ./run-test.sh
```

Expected: 新 scenario FAIL，或记录当前输出未引用/未执行 good-tests 约束。

- [ ] **Step 3: 创建按需 `writing-good-tests.md` reference**

参考文件必须覆盖上游已核验的规则：

```text
- 每个测试先命名它捕获的 production break；expected 是 literal 或 hand-checked fixture，不由被测实现/helper 计算。
- 不测试 source text；脚本以受控输入运行，测试 output / side effect / exit code。面向人的 prose 不需要测试。
- 先理解真实依赖副作用；只 mock 慢/外部边界，不断言 mock 本身；mock 过复杂时使用 integration test。
- 不为测试向生产类加入 test-only cleanup API。
- Mutation Check：对 realistic constant/argument/branch/side effect/validation mutation，至少一个测试应失败。
- 保留 TDD rationalization table 中“先写代码再补测试”反驳。
```

- [ ] **Step 4: 在 TDD skill 的测试写作入口添加按需加载规则**

在现有 Good Tests / RED 入口明确：任何新增或修改测试前读取 `writing-good-tests.md`，然后选择 seam，再写 failing test。保持 `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`、现有 seam 定义、禁止 test-only public API、phase metrics 与 learning capture。

- [ ] **Step 5: 运行 TDD behavior 与加载验证**

Run:

```bash
cd tests/skill-behavior/test-driven-development && ./run-test.sh
cd ../../claude-code && ./run-skill-tests.sh
```

Expected: behavior tests PASS；skill loading test 不因新增 reference 失败。若 headless 运行受环境/API 限制，记录实际输出。

---

### Task 6: 收紧 reviewer 上下文，并迁移已核验的 prose 去重而不回退 fork 门禁

Blocking: Task 5  
Slice type: refactor  
Seam: reviewer dispatch 输入与输出、各受影响 skill 的静态流程契约、对应 pressure tests。

**Source commits:** `cfb6281`, `05d90ac`, `1e14b23`, `153d618`, `3be5aad`, `6dbbbda`, `bc86802`, `03147d2`.

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md`
- Modify: `tests/skill-behavior/requesting-code-review/prompts/*`
- Modify: `tests/skill-behavior/requesting-code-review/run-test.sh`
- Modify: `skills/brainstorming/SKILL.md`
- Modify: `skills/writing-plans/SKILL.md`
- Modify: `skills/writing-skills/SKILL.md`
- Modify: `skills/verification-before-completion/SKILL.md`
- Modify: `skills/dispatching-parallel-agents/SKILL.md`
- Modify: corresponding existing `tests/skill-behavior/<skill>/` fixtures and `run-test.sh`

- [ ] **Step 1: 为 review 和每个受影响 prose skill 记录 baseline**

在各自既有 behavior suite 添加/更新一个最小 pressure case：

```text
requesting-code-review: coordinator 试图把完整 session reasoning 与 inline diff 传给 reviewer；期望只传 requirements/DoD/base/head/brief/report/package 并保留 Standards / Spec 输出。
brainstorming: 方案比较包含不必要 feature；期望在 Exploring approaches 位置执行 YAGNI，不删除 frontier batching。
writing-plans / writing-skills / verification / dispatching: 检查上游 recap 删除后，原有可操作硬门禁仍在，而不是仅变短。
```

保留用户已有 `skills/brainstorming/SKILL.md` 未提交改动；任何 edit 都从当前工作树内容三方合并，不能还原该文件。

- [ ] **Step 2: 运行 baseline 并记录缺口**

Run the affected suites individually:

```bash
for skill in requesting-code-review brainstorming writing-plans writing-skills verification-before-completion dispatching-parallel-agents; do
  (cd "tests/skill-behavior/$skill" && ./run-test.sh)
done
```

Expected: 对新增断言出现预期失败，或将当前输出作为 baseline artifact；不得在无 baseline 证据下直接压缩 skill 文案。

- [ ] **Step 3: 实现 reviewer 最小上下文契约**

在 `requesting-code-review/SKILL.md` 保持 Standards / Spec 双轴与现有 triggers，新增以下可观察规则：

```text
Dispatch reviewer with precisely constructed work-product context: requirements/DoD, BASE_SHA, HEAD_SHA, task brief/report and review package when available.
Never pass the coordinator's full session history.
Do not inline a review diff into coordinator context; the reviewer reads the package and returns findings only.
```

不得替换现有 `agents/code-reviewer.md` 或把 reviewer 改成不同 agent 类型，除非当前 behavior test 证明该文件是必要调用边界。

- [ ] **Step 4: 仅迁移已核验的 prose 重排**

逐文件对照 `3dcbd5c` 与当前内容：

- `brainstorming`：将 YAGNI 放在 `Exploring approaches`；只删除当前文件中确实在过程段重复的 Key Principles recap。保留 frontier rounds、facts/decisions、GDD、sprint contract、三次拒绝熔断和用户未提交 frontmatter。
- `writing-plans`：仅移除结尾重复 `Remember` recap；保留 `Interfaces`、Blocking、Slice type、Seam、GDD、contract、KB lookup 与 validation。
- `writing-skills`：仅移除重复 Bottom Line；保留 RED/GREEN/REFACTOR、predictability、load、progressive disclosure 和 no-op pruning。
- `verification-before-completion`：仅移除与 Iron Law/gate function 重复的宣传段；保留 computational sensors、loop detection、fresh evidence 规则。
- `dispatching-parallel-agents`：仅移除 Key Benefits / Time saved / Real-World Impact 等非操作性文字；保留同一 response dispatch 才并行、shared state 禁止并发。

不恢复 `using-git-worktrees`，不修改 manifest、Gemini、Codex hook、visual companion 或任何未核验上游路径。

- [ ] **Step 5: 运行各 behavior suite、静态保护检查和加载测试**

Run:

```bash
for skill in requesting-code-review brainstorming writing-plans writing-skills verification-before-completion dispatching-parallel-agents; do
  (cd "tests/skill-behavior/$skill" && ./run-test.sh)
done
git grep -nE 'using-git-worktrees|hooks[[:space:]]*[:=][[:space:]]*\{\}' -- skills .codex-plugin || true
git diff -- skills/brainstorming/SKILL.md
```

Expected: behavior suites PASS 或记录真实 headless failure；保护搜索不能显示新的 `using-git-worktrees` 引用或将 Codex manifest 改为 empty hooks；最后一个 diff 要人工确认保留用户原有 brainstorming 修改。

---

### Task 7: 运行全量受影响确定性验证并执行 Standards / Spec 双轴审查

Blocking: Tasks 1, 2, 3, 4, 5, 6  
Slice type: verification  
Seam: 所有 contract test 输出、受影响 skill behavior 输出、最终 Git diff 与 spec / sprint contract / GDD 的映射。

**Files:**
- Modify: `docs/agent-harness/plans/2026-07-29-upstream-v6-2-adaptation.md` — 在执行时勾选已完成步骤与记录真实结果；不改变历史 source facts。

- [ ] **Step 1: 运行确定性 suites**

Run:

```bash
bash tests/systematic-debugging/test-find-polluter.sh
bash tests/claude-code/test-sdd-workspace.sh
bash tests/sdd-scripts/test-cleanup-workspace.sh
bash tests/sdd-scripts/test-finishing-contract.sh
bash tests/plugin-infrastructure/run-all.sh
git diff --check
```

Expected: 所有命令 exit 0；若某一项失败，先修复其对应 task，不进入行为 review 或完成声明。

- [ ] **Step 2: 运行受影响的 Claude Code / behavior suites**

Run:

```bash
cd tests/claude-code && ./run-skill-tests.sh --test test-subagent-driven-development.sh
for skill in subagent-driven-development finishing-a-development-branch test-driven-development requesting-code-review brainstorming writing-plans writing-skills verification-before-completion dispatching-parallel-agents; do
  (cd "tests/skill-behavior/$skill" && ./run-test.sh)
done
```

Expected: 记录每个 suite 的 PASS 或完整真实失败原因；不得将 API 配额、缺少 `claude` 或 timeout 视为通过。

- [ ] **Step 3: Standards axis 审查**

审查最终 diff，确认：Bash 保持 `set -euo pipefail`；参数错误 exit 2 的接口一致；没有共享 workspace cleanup；没有未引用的 prompt/test；hooks JSON 有效；没有新增依赖、manifest/品牌变更或删除 Codex/Gemini 支持。

- [ ] **Step 4: Spec axis 审查**

逐项对照 spec、contract 和 GDD：

```text
find-polluter / SessionStart / helpers
PLAN_FILE workspace / basename / ledger identity / report package
five-round scoped re-review / final one-fixer-one-re-review
explicit discard / owned worktree / branch-default isolation
TDD good-tests / reviewer isolation / prose-only scope
```

任何缺项都回到所属 task；任何范围外改动都移除或获得用户新批准。

- [ ] **Step 5: 生成用户审阅材料并手动提交**

Run:

```bash
git status --short
git diff --stat
git diff --check
git diff -- . ':!docs/agent-harness/plans/2026-07-29-upstream-v6-2-adaptation.md'
```

Expected: 向用户展示完整 diff 与验证结果。**不要自动 commit**；由用户审阅后决定提交拆分和提交信息。

---

### Task 8: 同步知识库索引与实施状态

Blocking: Task 7  
Slice type: verification  
Seam: 知识库索引能够从 `docs/agent-harness/index.md` 定位此 plan，plan frontmatter 状态与实际实施状态一致。

**Files:**
- Modify: `docs/agent-harness/plans/index.md`
- Modify: `docs/agent-harness/plans/2026-07-29-upstream-v6-2-adaptation.md`

- [ ] **Step 1: 写入计划索引的失败检查**

Run:

```bash
grep -F "2026-07-29-upstream-v6-2-adaptation" docs/agent-harness/plans/index.md
```

Expected: 当前失败，因为索引尚未包含本计划。

- [ ] **Step 2: 添加索引条目**

在 `docs/agent-harness/plans/index.md` 追加：

```markdown
## upstream-v6-2-adaptation
- [2026-07-29-upstream-v6-2-adaptation](2026-07-29-upstream-v6-2-adaptation.md)
```

- [ ] **Step 3: 在实施结束后更新计划状态**

仅当 Task 7 的确定性验证通过、headless 结果已如实记录、双轴审查完成且用户已审阅完整 diff 后，将 frontmatter 改为：

```yaml
status: completed
```

若存在未解决 BLOCKED finding、失败测试或用户尚未审阅 diff，保持 `status: active`。

- [ ] **Step 4: 验证知识库链接与计划状态**

Run:

```bash
grep -F "2026-07-29-upstream-v6-2-adaptation" docs/agent-harness/plans/index.md
grep -n '^status:' docs/agent-harness/plans/2026-07-29-upstream-v6-2-adaptation.md
```

Expected: 索引输出一个链接；状态仅在所有完成条件满足后为 `completed`。

---

## Scope Scan

已对 `review-package` 旧接口执行全局扫描。实施时仅迁移活跃 runtime/test 调用：

```text
skills/subagent-driven-development/SKILL.md
skills/subagent-driven-development/references/controller-guide.md
skills/subagent-driven-development/task-reviewer-prompt.md
tests/claude-code/test-sdd-workspace.sh
```

历史 spec / plan 文件中的旧命令是当时的记录，不做机械替换。实施后再次运行 Task 2 的 `git grep`，确保活跃实现/测试没有旧两参数调用。

## GDD Traceability

| GDD assertions | 实施任务 |
|---|---|
| L3-1 / L2-1 plan workspace、API、ledger | Tasks 2–3 |
| L3-2 五轮/re-review/final review | Task 3 |
| L4-2 / L3-3 finishing 与 ownership | Task 4 |
| L4-3 / L2-2 stability、hook、TDD/review | Tasks 1, 5–6 |
| L1-1 protected platform / workflow boundaries | Tasks 4, 6–7 |

## Plan Self-Review

- **Spec coverage:** Tasks 1–6 覆盖 spec 的稳定性、SDD、finishing、TDD/review/prose 五个实施序列；Task 7 做 contract 与 GDD 的双轴回归；Task 8 保证知识库可发现性与状态真实性。
- **Contract coverage:** 每项 DoD 都映射到确定性 tests、headless pressure tests或最终双轴审查；无法运行 headless suite 时要求记录真实原因。
- **Placeholder scan:** 未包含 TBD、TODO 或“适当处理”类步骤；每个接口变更提供了参数、文件和验证命令。
- **Type/API consistency:** `sdd-workspace PLAN_FILE`、`task-brief PLAN_FILE TASK_NUMBER [OUTFILE]`、`review-package PLAN_FILE BASE HEAD [OUTFILE]`、`cleanup-workspace PLAN_FILE` 在所有任务中一致。
- **Isolation rule:** 计划明确默认独立分支、worktree 仅显式使用；没有引用删除的 `using-git-worktrees` skill。
- **Manual commit reminder:** 所有验证和用户完整 diff 审阅完成后，才由用户决定如何拆分并创建 commit。
