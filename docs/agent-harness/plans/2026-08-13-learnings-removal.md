---
spec_ref: ../specs/2026-08-13-learnings-removal-design.md
spec_topic: learnings-removal
status: active
task_count: 11
estimated_phases: [implementation, verification]
dod: "15 个 learnings 文件/目录删除；session-start/stop-hook/guard-staging/diagnose 无 learnings 逻辑；10 个 skill 无 learnings 引用；更新测试套件全绿；grep learnings 仅命中历史快照（plans/specs/contracts/CHANGELOG.md）；无替代机制"
---

# Learnings 移除实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完整移除 learnings 生态（skill、脚本、注入、数据文件）及全部下游引用，仓库无 learnings 运行时能力残留。

**Architecture:** 删除型重构。无新行为引入：先删 learnings 本体（脚本/skill/数据/测试），再清理 hooks/scripts/skills 中的引用，最后更新存量测试与现行文档。纯 shell/markdown 操作，无编译步骤。

**Tech Stack:** bash、markdown、python3（测试辅助）

**Commit 策略:** 最后统一提交（用户已确认）。Task 1-11 无 commit step，Final 阶段一次提交。

**GDD 跳过说明:** 本任务为纯删除/引用清理，无新行为或契约面；回归风险由存量测试套件 + grep 白名单检查覆盖（已在 contract Acceptance Criteria 定义），不生成 GDD artifact。

**受影响文件总览（Scope Scan 结果）:** 删除 15 项（见 spec 删除清单）；修改 21 项 —— `hooks/session-start`、`hooks/stop-hook.sh`、`scripts/guard-staging.sh`、`scripts/diagnose-failure.sh`、`scripts/lib/diagnose-lib.sh`、10 个 skill、4 个测试、`CLAUDE.md`、`README.md`、`README_EN.md`、`skills/CLAUDE.md`、`tests/CLAUDE.md`、`CONTEXT.md`（gitignored，本地清理不提交）。历史文档（plans/specs/contracts/CHANGELOG）保留不动。

---

### Task 1: 删除核心 learnings 基础设施

Blocking: none
Slice type: verification（删除 + grep 验证）
Seam: none（删除操作）

**Files:**
- Delete: `scripts/log-learning.sh`
- Delete: `scripts/search-learnings.sh`
- Delete: `scripts/index-learnings.sh`
- Delete: `scripts/trace-analyzer.sh`
- Delete: `skills/session-learnings/`（目录）
- Delete: `skills/trace-analysis/`（目录）
- Delete: `.agent-harness/learnings.jsonl`（当前为未提交 M 状态，git rm 一并移除工作区改动）

- [ ] **Step 1: 删除 4 个 learnings/trace 脚本**

```bash
git rm scripts/log-learning.sh scripts/search-learnings.sh scripts/index-learnings.sh scripts/trace-analyzer.sh
```

- [ ] **Step 2: 删除 2 个 skill 目录**

```bash
git rm -r skills/session-learnings skills/trace-analysis
```

- [ ] **Step 3: 删除数据文件**

```bash
git rm .agent-harness/learnings.jsonl
```

- [ ] **Step 4: 验证文件不存在**

Run: `ls scripts/log-learning.sh scripts/search-learnings.sh scripts/index-learnings.sh scripts/trace-analyzer.sh skills/session-learnings skills/trace-analysis .agent-harness/learnings.jsonl 2>&1`
Expected: 全部 "No such file or directory"（7 项）。

### Task 2: 删除 learnings 测试套件

Blocking: Task 1
Slice type: verification（删除 + 验证）
Seam: none

**Files:**
- Delete: `tests/learnings-scripts/`（目录）
- Delete: `tests/knowledge-base-scripts/test-index-learnings.sh`
- Delete: `tests/skill-behavior/session-learnings/`（目录）
- Delete: `tests/skill-behavior/trace-analysis/`（目录）
- Delete: `tests/skill-triggering/prompts/session-learnings.txt`

- [ ] **Step 1: 删除 3 个目录**

```bash
git rm -r tests/learnings-scripts tests/skill-behavior/session-learnings tests/skill-behavior/trace-analysis
```

- [ ] **Step 2: 删除 2 个单文件**

```bash
git rm tests/knowledge-base-scripts/test-index-learnings.sh tests/skill-triggering/prompts/session-learnings.txt
```

- [ ] **Step 3: 验证**

Run: `ls -d tests/learnings-scripts tests/skill-behavior/session-learnings tests/skill-behavior/trace-analysis 2>&1; ls tests/knowledge-base-scripts/test-index-learnings.sh tests/skill-triggering/prompts/session-learnings.txt 2>&1`
Expected: 全部 "No such file or directory"（5 项）。

### Task 3: 删除 demo learnings 数据文件

Blocking: none
Slice type: verification（删除 + 验证保留文件）
Seam: none

**Files:**
- Delete: `demo/.superpowers/learnings.jsonl`（保留同目录 sensors.json）
- Delete: `demo/fruit-shop/.agent-harness/learnings.jsonl`（保留同目录 sdd/）
- Delete: `demo/fruit-shop/packages/server/.superpowers/learnings.jsonl`

- [ ] **Step 1: 删除 3 个数据文件**

```bash
git rm demo/.superpowers/learnings.jsonl demo/fruit-shop/.agent-harness/learnings.jsonl demo/fruit-shop/packages/server/.superpowers/learnings.jsonl
```

- [ ] **Step 2: 验证非 learnings 文件保留**

Run: `ls demo/.superpowers/sensors.json demo/fruit-shop/.agent-harness/sdd demo/fruit-shop/packages/server/.superpowers/`
Expected: sensors.json 存在、sdd/ 存在、packages/server/.superpowers/ 目录为空（无 learnings.jsonl）。

### Task 4: 修改 hooks/session-start

Blocking: Task 1
Slice type: refactor（移除 learnings 注入逻辑）
Seam: session-start 输出契约（合法 JSON、无 learnings 段）

**Files:**
- Modify: `hooks/session-start`（learnings 注入相关：当前第 68-72、123-150、220、236-239 行）

**Interfaces:**
- Consumes: 无（仅移除）
- Produces: 三分支（startup/resume/precompact）additionalContext 无 learnings 段

- [ ] **Step 1: 移除 learnings 读取逻辑（保留 LEARNINGS_DIR）**

删除 `hooks/session-start` 中 learnings 读取块的第 123-127 行注释与 `learnings_content` 变量、第 129-150 行 if 块（learnings.jsonl 存在性检查、learnings_count 计数、search-learnings.sh --summary 调用含 ≥50 条 throttle 分支、fallback tail、`## Project Learnings` 拼装）。**必须保留第 128 行 `LEARNINGS_DIR` 变量定义** —— 它同时被 kb_hint（第 162 行 `$LEARNINGS_DIR/docs/agent-harness/index.md`）与 context_md_hint（第 172/174/183 行）使用，删除会使 startup/clear 分支在 `set -euo pipefail` 下 unset 变量报错。第 126-127 行注释改为纯 project-root 解析说明（不再提及 log/search-learnings.sh）。

- [ ] **Step 2: 移除 precompact checkpoint 中的 learnings 提及**

删除第 95 行 `echo "- Recent learnings: .agent-harness/learnings.jsonl (auto-injected next startup)"`（precompact checkpoint Recovery Hints 中 learnings 行不再存在）。

- [ ] **Step 3: 移除注入变量与拼装**

删除 `learnings_escaped=$(escape_for_json "$learnings_content")`（当前第 220 行）。在 resume 分支（第 237 行）与 startup 分支（第 239 行）的 session_context 拼装中移除 `${learnings_escaped}`。

- [ ] **Step 4: 更新 resume 分支注释**

将第 68-72 行注释中 "resume → only learnings delta; using-agent-harness already in context" 改为 "resume → inject nothing extra beyond warning/checkpoint; using-agent-harness already in context"。保留 `[ "$SESSION_SOURCE" = "resume" ]` 分支结构（warning + checkpoint_hint 仍注入）。

- [ ] **Step 5: 验证三分支输出合法且无 learnings**

```bash
# startup
echo '{"session_id":"t","source":"startup"}' | CLAUDE_PLUGIN_ROOT=. CLAUDE_PROJECT_DIR=. bash hooks/session-start | jq -r '.hookSpecificOutput.additionalContext // .additionalContext' | grep -c "Project Learnings"
# 期望输出 0
# resume
echo '{"session_id":"t","source":"resume"}' | CLAUDE_PLUGIN_ROOT=. CLAUDE_PROJECT_DIR=. bash hooks/session-start | jq -e .hookSpecificOutput
# 期望 exit 0 且无 learnings
# precompact
echo '{"session_id":"t","source":"precompact"}' | CLAUDE_PLUGIN_ROOT=. CLAUDE_PROJECT_DIR=. bash hooks/session-start | jq -e .hookSpecificOutput
# 期望 exit 0
```

Expected: 三分支 jq 解析成功，startup 输出无 "Project Learnings"（grep -c 返回 0）。

### Task 5: 修改 hooks/stop-hook.sh

Blocking: none
Slice type: refactor（移除 learnings 提示）
Seam: stop-hook promise 检测行为（保持）

**Files:**
- Modify: `hooks/stop-hook.sh`（第 125、156-166、196 行）

- [ ] **Step 1: 移除 learnings 提示并恢复正常结束**

将 promise 匹配成功块（当前第 156-166 行）改为：
```bash
if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph loop: Detected <promise>$COMPLETION_PROMISE</promise>"
    rm "$RALPH_STATE_FILE"
    exit 0
fi
```
即删除 "Prompt Claude to capture session learnings" 注释（第 159 行）、三行 learnings 提示 echo（第 161-164 行）、`exit 2` 改为 `exit 0`（第 165 行）。

- [ ] **Step 2: 清理 learnings 注释残留**

第 125 行注释 "(e.g. \"logged N learnings\")" 改为 "(e.g. a trailing progress note)"（保留注释对 join("\n") 语义的说明，去掉 learnings 示例）。第 196 行注释 "trap already present in search-learnings.sh (#19)" 改为指向仍存在的脚本或删除 "#19" 引用（search-learnings.sh 已删除，悬空引用）。

- [ ] **Step 3: 验证无 learnings 引用且测试通过**

Run: `grep -n "learnings\|session-learnings\|search-learnings" hooks/stop-hook.sh; cd tests/ralph-loop-scripts && ./test-stop-hook-promise.sh`
Expected: grep 无输出；测试 3/3 PASS（该测试仅测 jq+perl 提取逻辑，不受影响）。

### Task 6: 修改 guard-staging + 更新测试

Blocking: Task 1
Slice type: refactor（移除保护路径条目）
Seam: guard-staging 阻止规则（其余保护路径保持）

**Files:**
- Modify: `scripts/guard-staging.sh:10`（PROTECTED_PATHS）
- Modify: `tests/plugin-infrastructure/test-guard-staging.sh:31,35,61`（learnings 用例与 grep 断言）

- [ ] **Step 1: 移除 PROTECTED_PATHS 条目**

删除 `scripts/guard-staging.sh` 中 `.agent-harness/learnings.jsonl` 行，保留 `.agent-harness/sdd/` 与 `.agent-harness/loop-tracker.json`。

- [ ] **Step 2: 更新测试**

在 `tests/plugin-infrastructure/test-guard-staging.sh` 中：删除第 31 行 `git add .agent-harness/learnings.jsonl` 拦截用例、第 35 行 `-f` 放行用例；第 61 行 grep 断言 `"learnings\|agent-harness\|protected\|staging"` 中移除 `learnings\|`（agent-harness 仍覆盖其他路径）。

- [ ] **Step 3: 验证 guard 测试通过**

Run: `cd tests/plugin-infrastructure && bash test-guard-staging.sh`
Expected: 所有 guard 用例 PASS，无 learnings 相关用例。

### Task 7: 修改 diagnose + 更新测试

Blocking: Task 1
Slice type: refactor（移除 learnings/trace 信号源）
Seam: diagnose evidence 输出结构（移除 2 字段，保留 phase_history）

**Files:**
- Modify: `scripts/lib/diagnose-lib.sh`（移除 `diagnose_trace`、`diagnose_similar_learnings`，保留 `diagnose_phase_history`）
- Modify: `scripts/diagnose-failure.sh`（TRACE/LEARN 变量、evidence 字段、root_cause/fixes 中 trace 分支）
- Modify: `tests/diagnose-scripts/test-diagnose-failure.sh:54`（similar_learnings 断言）

- [ ] **Step 1: diagnose-lib.sh 移除两个函数**

删除 `diagnose_trace`（当前第 10-16 行）与 `diagnose_similar_learnings`（当前第 33-46 行）整个函数，保留 `diagnose_phase_history`。更新文件头注释（当前第 3-4 行）为仅提及 query-phase-metrics。

- [ ] **Step 2: diagnose-failure.sh 移除 trace/learn 信号**

删除：第 55 行 `TRACE=$(diagnose_trace "$CONTEXT")`、第 58 行 `LEARN=$(diagnose_similar_learnings ...)`、第 63 行环境变量中的 `TRACE`/`LEARN`、python 块中第 76-80 行 `trace`/`learn` 读取、第 115 行 `"trace_classification": trace[:200] if trace else ""`、第 117 行 `"similar_learnings": learn`。

root_cause 推断（当前第 91-97 行）改为仅基于 ctx：保留 `if "schema" in str(ctx).lower()` 分支，删除依赖 `trace.lower()` 的两个分支；`elif not trace:` 改为 `else:`（信号不足兜底）。fixes 块（当前第 99-107 行）：删除 `elif root_cause.startswith("门禁")` 分支（不再有 trace 产生该 root_cause），保留 `root_cause.startswith("frontmatter")` 与 phase_history failure_rate 分支。

- [ ] **Step 3: 更新诊断测试断言**

删除 `tests/diagnose-scripts/test-diagnose-failure.sh:54` 的 `assert isinstance(d['evidence']['similar_learnings'], list)` 行；如测试还断言 trace_classification 则一并删除。

- [ ] **Step 4: 验证 diagnose 套件通过**

Run: `cd tests/diagnose-scripts && ./run-all.sh`
Expected: 全部 PASS，输出 evidence 仅含 phase_history。

### Task 8: 修改 7 个单句 skill

Blocking: none
Slice type: refactor（移除 learnings 记录引导句）
Seam: none

**Files:**
- Modify: `skills/brainstorming/SKILL.md:286` — 删除 "Record it using `session-learnings` skill so future sessions respect these decisions."
- Modify: `skills/test-driven-development/SKILL.md:404` — 删除 "Record it using `session-learnings` skill (type: `tool` or `pattern`)."
- Modify: `skills/writing-plans/SKILL.md:124` — 默认 manual-commit 判断中删除 "(check session-learnings or project CLAUDE.md)" 改为 "(check project CLAUDE.md)"
- Modify: `skills/finishing-a-development-branch/SKILL.md:143` — 删除 "**session-learnings** to record reusable insights before completion."
- Modify: `skills/systematic-debugging/SKILL.md:309` — 删除 "echo '{"ts":...pitfall...}' >> .agent-harness/learnings.jsonl" 代码块及其说明句
- Modify: `skills/receiving-code-review/SKILL.md:224` — 删除 "Record it using `session-learnings` skill."
- Modify: `skills/post-deploy-monitoring/SKILL.md:150` — 删除 "**session-learnings** — Log operational insights discovered during monitoring"

- [ ] **Step 1: 逐个编辑 7 个 SKILL.md**

按上述行号用 Edit 工具删除对应句子/代码块。删除后检查所在小节是否因此空置，若空置则合并相邻小节（仅限直接相邻的空节）。

- [ ] **Step 2: 验证本组无 learnings 残留**

Run: `grep -rn "learnings\|session-learnings" skills/brainstorming skills/test-driven-development skills/writing-plans skills/finishing-a-development-branch skills/systematic-debugging skills/receiving-code-review skills/post-deploy-monitoring`
Expected: 无输出（本 7 个 skill 干净；retrospective/harness-init/harness-optimizer 属 Task 9）。

### Task 9: 修改 retrospective + harness-init + harness-optimizer

Blocking: none
Slice type: refactor（移除 learnings 数据引用与集成说明）
Seam: none

**Files:**
- Modify: `skills/retrospective/SKILL.md`（第 3、50-54、66、74、133、254-261、266 行）
- Modify: `skills/harness-init/SKILL.md:73`
- Modify: `skills/harness-optimizer/SKILL.md:214,232`
- Modify: `tests/skill-behavior/retrospective/prompts/naive-do-retro.txt:1`

- [ ] **Step 1: retrospective 移除 learnings 数据收集**

删除第 50-54 行 "Learnings (if using session-learnings)" 小节（标题 + ```bash 开始 + cat learnings.jsonl 命令 + ``` 闭合，第 54 行闭合不可遗漏）；删除第 66 行 trace-analyzer 调用 `bash "${CLAUDE_PLUGIN_ROOT}/scripts/trace-analyzer.sh"`；删除第 74 行 trace-analysis reference；删除第 133 行 "(From .agent-harness/learnings.jsonl)" 来源标注；删除第 254 行警示 "- No learnings being captured"；删除第 261 行 "If no learnings: start using session-learnings skill"；删除第 266 行 "**session-learnings** — Source of captured insights" integration 条目。第 3 行 description 中 "Analyzes commits, learnings, and patterns" 改为 "Analyzes commits and patterns"。

- [ ] **Step 2: harness-init 移除 learnings 说明**

删除第 73 行表格行 `| Skipping hooks-config | Hooks enable session-start learnings injection |`，改为描述 hooks 的真实用途（如 "Hooks enable session-start context injection"）。

- [ ] **Step 3: harness-optimizer 移除 learnings 节点**

删除第 214 行 ASCII 图内 `│     └─► session-learnings 存储` 节点及其边框行调整；删除第 232 行 integration 条目 `- **session-learnings**: 将分析发现存储为学习记录`。

- [ ] **Step 4: 更新 retrospective 行为测试 prompt**

`tests/skill-behavior/retrospective/prompts/naive-do-retro.txt:1` 中 "analyze patterns from commits and learnings" 改为 "analyze patterns from commits"（learnings 数据源已移除，prompt 不再要求分析 learnings）。

- [ ] **Step 5: 验证 skills 目录整体干净**

Run: `grep -rn "learnings\|session-learnings\|trace-analysis" skills/`
Expected: 无输出（skills 目录全部干净）。

### Task 10: 更新剩余测试

Blocking: Task 4
Slice type: verification（测试断言更新）
Seam: 测试通过

**Files:**
- Modify: `tests/plugin-infrastructure/test-session-start-cache-stable.sh`（第 8-9、41-90 行）
- Modify: `tests/knowledge-base-scripts/run-all.sh:7`

- [ ] **Step 1: 更新 cache-stable 测试**

删除第 8-9 行注释中 learnings 提及（改为仅描述 using-agent-harness 稳定前缀）；删除第 41-51 行 Assertion 2（learnings 顺序断言），或改写为断言"无 Project Learnings 段"；删除第 53-90 行 Assertion 3（search-learnings.sh --summary 确定性）整块。

- [ ] **Step 2: 更新 knowledge-base run-all**

删除 `tests/knowledge-base-scripts/run-all.sh:7` 的 `bash test-index-learnings.sh; RC2=$?` 行及对应 RC 汇总逻辑。

- [ ] **Step 3: 验证两个套件通过**

Run: `cd tests/plugin-infrastructure && ./run-all.sh && cd ../knowledge-base-scripts && ./run-all.sh`
Expected: 全部 PASS。

### Task 11: 更新现行文档

Blocking: Task 8, Task 9
Slice type: verification（文档清理 + grep 白名单）
Seam: 无

**Files:**
- Modify: `CLAUDE.md`（Learnings 小节、质量层、验证地图）
- Modify: `README.md` / `README_EN.md`（learnings/trace-analysis 描述）
- Modify: `skills/CLAUDE.md:98`
- Modify: `tests/CLAUDE.md`（速查表 learnings-scripts 行）
- Modify: `CONTEXT.md`（gitignored，仅本地清理不提交）

- [ ] **Step 1: CLAUDE.md 清理**

删除 "### Learnings（`.agent-harness/learnings.jsonl` + `scripts/*learnings.sh`）" 整段；质量层 `qa-testing → post-deploy-monitoring → retrospective → trace-analysis` 改为 `qa-testing → post-deploy-monitoring → retrospective`；验证地图"会话知识来源"删除 `.agent-harness/learnings.jsonl`、`skills/session-learnings/`；高层架构 Learnings 相关句（"使用 session-learnings skill 添加条目"）删除。

- [ ] **Step 2: README.md / README_EN.md 清理**

删除 learnings 描述与 trace-analysis 相关行：README.md 第 173（质量层架构图 trace-analysis 行）、179（核心理念）、288（失败自愈信号源 learnings 索引）、324（trace-analysis 描述）、336（session-learnings 条目）；README_EN.md 第 158、164、273（失败自愈 learnings 索引）、309。用 grep 以实际命中为准（行号可能因编辑漂移）。

- [ ] **Step 3: skills/CLAUDE.md 清理**

删除第 98 行 `- 不要手动编辑 `.agent-harness/learnings.jsonl`，用 `session-learnings` skill。`

- [ ] **Step 4: tests/CLAUDE.md 清理**

删除速查表中 `| `learnings-scripts/` | 纯脚本 | `./test-learnings.sh` | ... |` 行；"常用命令"中 `./learnings-scripts/test-learnings.sh` 行；Git 规范示例 scope 中 `learnings-scripts`（改为其他 scope）。

- [ ] **Step 5: CONTEXT.md 本地清理（gitignored）**

删除 "## Learning"（第 63-66 行）、"## top-N summary"（第 73-76 行）、"## 就近解析"（第 78-81 行）三个术语条目；第 4 行 Agent Harness 定义中 "and learnings infrastructure" 删除（改为 "and shell hooks"）；第 14 行 Hook 定义中 "injects Skills and Learnings" 改为 "injects Skills"；第 69 行 session-start 定义中 "the Learning summary" 删除；第 104 行闭环链路 "(phase-metrics, learnings, trace-analysis)" 改为 "(phase-metrics)"；第 164 行 relationship "and injects **Learnings**" 删除；第 165 行 "**session-start** applies the **top-N summary** policy and **就近解析**..." 删除；第 176 行 "**闭环链路** consumes **Learnings**..." 改为仅 phase metrics。不提交该文件（gitignored）。

- [ ] **Step 6: 验证现行文档白名单**

Run: `grep -rn "learnings\|session-learnings\|trace-analysis" CLAUDE.md README.md README_EN.md skills/CLAUDE.md tests/CLAUDE.md CONTEXT.md`
Expected: 无输出。

---

### Final: 全量验证 + 统一提交

Blocking: Task 1-11 全部完成
Slice type: verification
Seam: 测试全绿 + grep 白名单

- [ ] **Step 1: 跑全部更新测试套件**

Run: `tests/plugin-infrastructure/run-all.sh && tests/diagnose-scripts/run-all.sh && tests/knowledge-base-scripts/run-all.sh && tests/ralph-loop-scripts/test-stop-hook-promise.sh`
Expected: 全部 exit 0。

- [ ] **Step 2: 全仓库 grep 白名单检查**

Run: `grep -rn "learnings\|session-learnings\|trace-analyzer\|trace-analysis" --exclude-dir=.git --exclude=CHANGELOG.md . | grep -v "docs/agent-harness/plans/\|docs/agent-harness/specs/\|docs/agent-harness/contracts/\|CHANGELOG.md\|tests/ralph-loop-scripts/\|demo/fruit-shop/"`
Expected: 无输出。白名单接受路径及理由：`docs/agent-harness/plans|specs|contracts` 与 `CHANGELOG.md`（历史快照，spec 决策保留）；`tests/ralph-loop-scripts/test-stop-hook-promise.sh:92`（"已记录 4 条 learnings" 模拟文本，contract 明确保留，非 learnings 能力引用）；`demo/fruit-shop/CLAUDE.md:95`（demo 文档提及，spec 非目标禁止改 demo）。若 grep 命中白名单外的路径，回到对应 task 修复。

- [ ] **Step 3: 统一提交**

```bash
git add -A
git commit -m "chore(learnings): 移除 learnings 生态及全部下游引用

- 删除 learnings 脚本/skill/trace-analysis/数据文件/测试（15 项）
- session-start 移除 learnings 注入；stop-hook/guard-staging/diagnose 清理
- 10 个 skill 移除 learnings 引用；更新测试与现行文档
- demo learnings 数据文件一并删除"
```

- [ ] **Step 4: 复核提交不包含 CONTEXT.md**

Run: `git show --stat HEAD | grep CONTEXT`
Expected: 无输出（CONTEXT.md gitignored，不应入提交）。
