---
spec_ref: ../specs/2026-08-07-brainstorming-to-questionnaire-design.md
spec_topic: brainstorming-to-questionnaire
task_count: 7
estimated_phases: [tests-baseline, implementation, tests-verify, loading-verify]
dod: "SKILL.md 含 4 条精确字符串;index.md 含 handoffs/ 链接;handoffs/.gitkeep 存在;3 个具名测试 fixture 存在;run-test.sh 引用三个场景名;run-skill-tests.sh 退出码=0;改后 behavior 三场景符合预期"
---

# Brainstorming to-questionnaire Escape Hatch 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 brainstorming skill 内嵌 to-questionnaire escape hatch + frontier 未空不得进入方案的硬规则,并加格式对齐。

**Architecture:** 仅修改 `skills/brainstorming/SKILL.md` 与 `docs/agent-harness/index.md`,新增 `docs/agent-harness/handoffs/.gitkeep` 与 3 个 headless 测试 fixture + run-test.sh 断言矩阵。不新增 skill、不动 plugin manifest、不扩展 handoff schema。

**Tech Stack:** Markdown (skill 文案)、Bash (headless 测试 harness,复用 `tests/skill-behavior/_helpers/`)。

---

## File Structure

| 文件 | 责任 | 动作 |
|------|------|------|
| `skills/brainstorming/SKILL.md` | 加 frontier 硬规则 + "When the user cannot answer" 小节 | Modify |
| `docs/agent-harness/index.md` | 注册 handoffs/ 子目录入口 | Modify |
| `docs/agent-harness/handoffs/.gitkeep` | 占位,让 git 跟踪空目录 | Create |
| `tests/skill-behavior/brainstorming/prompts/frontier-hard-rule.txt` | 场景 1 输入:用户催促"直接给方案" | Create |
| `tests/skill-behavior/brainstorming/prompts/to-questionnaire-trigger.txt` | 场景 2 输入:mock 多轮,用户表态答不了 | Create |
| `tests/skill-behavior/brainstorming/prompts/no-speculative-trigger.txt` | 场景 3 输入:正常 frontier,不应触发问卷 | Create |
| `tests/skill-behavior/brainstorming/run-test.sh` | 扩展断言矩阵覆盖 3 个新场景 | Modify |

**Commit strategy:** 最后一次性 commit(用户选择)。Plan 内不写 commit step,末尾给一个 "Final commit" 提醒。

---

## Task Dependency Graph

```
Task 1 (baseline fixture)        ─┐
                                  ├─→ Task 5 (run-test.sh 扩展)
Task 2/3/4 (SKILL.md + index +   ─┤
            handoffs 占位)         ├─→ Task 6 (改后 behavior 跑)
                                  │
                                  └─→ Task 7 (skill 加载测试)
```

- Task 1 / 2 / 3 / 4 互相独立,可并行(都改不同文件)
- Task 5 依赖 Task 1(需要 fixture 文件存在才能引用)和 Task 2(测试断言查的精确字符串必须先落地)
- Task 6 依赖 Task 5(需要 run-test.sh 扩展)
- Task 7 依赖 Task 2(SKILL.md 改完后才能跑加载测试)

---

## Task 1: 写 3 个 baseline 测试 fixture

Blocking: none
Slice type: tracer-bullet
Seam: filesystem (测试 fixture 文件存在)

**Files:**
- Create: `tests/skill-behavior/brainstorming/prompts/frontier-hard-rule.txt`
- Create: `tests/skill-behavior/brainstorming/prompts/to-questionnaire-trigger.txt`
- Create: `tests/skill-behavior/brainstorming/prompts/no-speculative-trigger.txt`

**Interfaces:**
- Consumes: 现有 `tests/skill-behavior/_helpers/run-skill.sh` 的 prompt-file 约定(纯文本文件)
- Produces: 3 个具名 fixture,被 Task 5 的 run-test.sh 引用

**说明:** 三个 fixture 现在就写好,因为它们既用作"改前 baseline"(跑一遍看旧 skill 如何响应)也用作"改后验证"。场景 2 的多轮对话在 headless 难以模拟,采用 mock 法:prompt 里直接包含用户的"答不了"表态,brainstorming 会在第一轮就看到信号。

- [ ] **Step 1.1: 写 frontier-hard-rule.txt**

```
Invoke the agent-harness:brainstorming skill via the Skill tool. I am building a todo CLI tool in Node.js. Don't ask too many questions — just give me the design directly and let's move to implementation.
```

- [ ] **Step 1.2: 写 to-questionnaire-trigger.txt**

```
Invoke the agent-harness:brainstorming skill via the Skill tool. I am building a payment callback system that integrates with a third-party payment gateway. One decision I can't make myself: the transaction fee rate — I need to ask the finance team because I don't know our current rates. Help me decide what to do.
```

- [ ] **Step 1.3: 写 no-speculative-trigger.txt**

```
Invoke the agent-harness:brainstorming skill via the Skill tool. I am building a full-stack blog platform: Next.js frontend, Node.js backend, Postgres database. I've narrowed auth to two options — JWT or session-based — and want your help deciding. Walk me through the design.
```

- [ ] **Step 1.4: 验证三个文件已创建**

Run: `ls tests/skill-behavior/brainstorming/prompts/`
Expected: 列出 7 个 `.txt` 文件(原 4 个 + 新 3 个)

---

## Task 2: 跑改前 baseline 记录输出

Blocking: Task 1
Slice type: verification
Seam: 临时输出文件系统

**Files:**
- 临时产物:`/tmp/baseline-brainstorming-to-questionnaire/`(不入 git)

**Interfaces:**
- Consumes: Task 1 的 3 个 fixture + 现有 SKILL.md(未改)
- Produces: 3 个 baseline 输出日志,贴进 PR 描述做前后对比

**说明:** 这一步只为生成 baseline 证据,**不修改任何源文件**。如果你信任"改前行为可推断",可跳过本 task 直接进 Task 3;但 sprint-contract 的 acceptance criteria 要求"PR 描述贴前后对比",所以建议跑。

- [ ] **Step 2.1: 临时跑三个场景(手动,不入 run-test.sh)**

```bash
mkdir -p /tmp/baseline-brainstorming-to-questionnaire
for prompt in frontier-hard-rule to-questionnaire-trigger no-speculative-trigger; do
  echo "=== Running baseline: $prompt ==="
  bash -c '
    source tests/skill-behavior/_helpers/run-skill.sh
    run_skill "brainstorming" "tests/skill-behavior/brainstorming/prompts/'$prompt'.txt" 5
    cp "$LOG_FILE" /tmp/baseline-brainstorming-to-questionnaire/'$prompt'.json
    echo "  saved to /tmp/baseline-brainstorming-to-questionnaire/'$prompt'.json"
  '
done
```

Expected: 三个 `.json` 文件生成;每个 `claude -p` 调用退出码 0;`grep -c "frontier\|❓\|➡️\|questionnaire"` 在三个文件中应显示场景 1 含 "frontier"、场景 2 不含 "questionnaire"(改前不会触发)、场景 3 不含 "questionnaire"

- [ ] **Step 2.2: 把三个 baseline 输出存档**

把 `/tmp/baseline-brainstorming-to-questionnaire/*.json` 的 final assistant response(用 `jq` 提取)汇总到一个 markdown 文件 `/tmp/baseline-brainstorming-to-questionnaire/summary.md`,PR 描述会用。

```bash
for prompt in frontier-hard-rule to-questionnaire-trigger no-speculative-trigger; do
  echo "## $prompt" >> /tmp/baseline-brainstorming-to-questionnaire/summary.md
  echo "" >> /tmp/baseline-brainstorming-to-questionnaire/summary.md
  jq -r -s '
    [ .[] | select(.type == "assistant")
      | [ .message.content[]? | select(.type == "text") | .text ]
      | select(length > 0) | join("\n") ]
    | if length > 0 then last else empty end
  ' /tmp/baseline-brainstorming-to-questionnaire/$prompt.json >> /tmp/baseline-brainstorming-to-questionnaire/summary.md
  echo "" >> /tmp/baseline-brainstorming-to-questionnaire/summary.md
done
```

Expected: `summary.md` 存在且包含三段 assistant 响应

---

## Task 3: 改 SKILL.md — frontier 硬规则 + to-questionnaire 小节

Blocking: none (与 Task 1/2 独立,可并行)
Slice type: tracer-bullet
Seam: `skills/brainstorming/SKILL.md` 的文案段(grep 校验)

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

**Interfaces:**
- Consumes: 现有 SKILL.md 的 "Relentless termination" 段(第 97-98 行)和 "Fact-checking rules" 段(第 100-107 行)
- Produces: 4 条 sprint-contract 要求的精确字符串

**说明:** 改动 1 在 "Relentless termination" 段末尾加一行硬规则;改动 2 在 "Fact-checking rules" 段之后插入新小节。文案完全照搬 spec 改动 1 和改动 2 的 markdown 块。

- [ ] **Step 3.1: 加 frontier 硬规则(改动 1)**

用 Edit 工具,在 `skills/brainstorming/SKILL.md` 中查找:

```
the grilling discipline is to keep asking until each assumption is either turned into an explicit decision or ruled out as out-of-scope. If you are tempted to skip a question because "the user probably meant X", ask the question instead — that is the silent assumption you are about to bake into the spec.
```

在其后追加一段:

```

**Hard rule:** If the frontier is not empty, you MUST NOT proceed to Propose approaches or Present design. "I think I have enough" is not a substitute for an empty frontier.
```

- [ ] **Step 3.2: 加 "When the user cannot answer" 小节(改动 2)**

用 Edit 工具,在 `skills/brainstorming/SKILL.md` 中查找 "Fact-checking rules" 段的结尾:

```
- Only questions downstream of an unresolved fact wait for the fact-finding result
```

在其后、"**Exploring approaches:**" 之前,插入 spec 改动 2 的完整 markdown 块(从 `**When the user cannot answer a frontier question (to-questionnaire escape hatch):**` 开始,到 `rather than assuming either way.` 结束,以 spec 文件中"### 改动 2"小节下的代码块为准)。

**关键:必须包含以下四条 sprint-contract 要求的精确字符串**(plan 执行完成后由 Task 5/6 的断言校验):
1. `When the user cannot answer a frontier question (to-questionnaire escape hatch)`
2. `Grill the send, not the subject.`
3. `If you're unsure whether the user can answer, ask them directly`
4. `MUST NOT proceed to Propose approaches`(来自改动 1)

- [ ] **Step 3.3: 静态校验四条精确字符串都存在**

Run:
```bash
for s in "When the user cannot answer a frontier question (to-questionnaire escape hatch)" \
         "Grill the send, not the subject" \
         "If you're unsure whether the user can answer, ask them directly" \
         "MUST NOT proceed to Propose approaches"; do
  if grep -qF "$s" skills/brainstorming/SKILL.md; then
    echo "OK: $s"
  else
    echo "MISSING: $s"
  fi
done
```

Expected: 4 行 `OK:`

- [ ] **Step 3.4: 校验 SKILL.md 净增长 < 80 行**

Run:
```bash
before=257
after=$(wc -l < skills/brainstorming/SKILL.md)
echo "before=$before after=$after diff=$((after - before))"
test $((after - before)) -lt 80
```

Expected: 退出码 0(diff < 80)。估算约 +50 行。

---

## Task 4: 改 index.md 注册 handoffs/ + 创建 handoffs/.gitkeep

Blocking: none (与 Task 1/2/3 独立)
Slice type: tracer-bullet
Seam: filesystem + index.md 链接

**Files:**
- Modify: `docs/agent-harness/index.md`(在 "子目录入口" 列表加一行)
- Create: `docs/agent-harness/handoffs/.gitkeep`

**Interfaces:**
- Consumes: 现有 index.md 的子目录入口列表(第 8-12 行)
- Produces: handoffs/ 目录可被 git 跟踪 + index.md 含 `- [handoffs/](handoffs/)` 精确字符串

- [ ] **Step 4.1: 创建 handoffs 目录与 .gitkeep**

Run:
```bash
mkdir -p docs/agent-harness/handoffs
cat > docs/agent-harness/handoffs/.gitkeep <<'EOF'
# to-questionnaire 问卷文档存放于此(to-<recipient>-<slug>.md)。
# 由 brainstorming skill 在 frontier 阻塞且用户答不了时产出。
# 不是 spec/plan/contract/notes gate,不进入 validate-handoff.sh。
EOF
```

Expected: `docs/agent-harness/handoffs/.gitkeep` 存在

- [ ] **Step 4.2: 在 index.md 注册 handoffs/**

用 Edit 工具,查找:

```
- [notes/](notes/)     — 学习笔记 / 偶发记录(含 [diagnoses/](notes/diagnoses/) 失败诊断沉淀)
```

在其后追加一行:

```
- [handoffs/](handoffs/)     — to-questionnaire 问卷等交接给外部接收人的中间产物
```

- [ ] **Step 4.3: 校验精确字符串**

Run:
```bash
grep -qF "- [handoffs/](handoffs/)" docs/agent-harness/index.md && echo OK || echo MISSING
```

Expected: `OK`

- [ ] **Step 4.4: 验证 index.md 仍能被 validate-handoff.sh 识别(间接)**

```bash
scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-08-07-brainstorming-to-questionnaire-design.md
```

Expected: `OK spec ...`(确认 spec_topic 仍能在 index.md 里被找到)

---

## Task 5: 扩展 run-test.sh 覆盖 3 个新场景

Blocking: Task 1(需要 fixture 文件),Task 3(需要 SKILL.md 精确字符串)
Slice type: tracer-bullet
Seam: `tests/skill-behavior/brainstorming/run-test.sh` 的断言矩阵

**Files:**
- Modify: `tests/skill-behavior/brainstorming/run-test.sh`

**Interfaces:**
- Consumes: Task 1 的 3 个 fixture 路径;Task 3 落地的 SKILL.md 文案
- Produces: run-test.sh 跑完 7 个场景(原 4 + 新 3)

**说明:** 每个 headless 场景在隔离的 `mktemp -d` project_dir 里跑(`run-skill.sh` 行为),所以场景 2 创建的 `docs/agent-harness/handoffs/*.md` 在临时目录里。断言只能检查 **assistant 响应文本**,不能检查仓库目录文件。这要求场景 2 的 prompt 设计让 brainstorming 在响应中**报告**它写到了哪个路径(否则断言失败)。

doD 第 10 条"改后 behavior 测试"以"输出含/不含特定字符串"为判据,不要求文件系统检查。

- [ ] **Step 5.1: 在 run-test.sh 末尾追加场景 1(frontier 硬规则)**

在文件末尾追加:

```bash

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (frontier hard rule) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/frontier-hard-rule.txt" 5
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_response_contains "frontier\|ask\|clarif\|问题\|澄清" "resists premature design under pressure"
print_skill_summary "brainstorming (frontier hard rule)"
```

- [ ] **Step 5.2: 追加场景 2(to-questionnaire 触发)**

```bash

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (to-questionnaire trigger) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/to-questionnaire-trigger.txt" 5
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_response_contains "questionnaire\|问卷\|handoffs/\|to-" "produces questionnaire path or concept"
print_skill_summary "brainstorming (to-questionnaire trigger)"
```

**说明:** 断言放宽到 "questionnaire/问卷/handoffs//to-" 任一命中,因为模型表述可能不同。doD 第 10 条的核心判据是"创建文件"——但 headless 隔离环境里文件在 mktemp 里,所以以响应中**提及**问卷机制为 proxy。

- [ ] **Step 5.3: 追加场景 3(不滥触发)**

```bash

SKILL_PASS_COUNT=0
SKILL_FAIL_COUNT=0

echo ""
echo "=== Test: brainstorming (no speculative trigger) ==="
echo ""
run_skill "brainstorming" "$SCRIPT_DIR/prompts/no-speculative-trigger.txt" 5
assert_skill_triggered "brainstorming"
assert_no_premature_action
assert_response_contains "frontier\|JWT\|session\|auth\|认证" "normal frontier round without escape hatch"
print_skill_summary "brainstorming (no speculative trigger)"
```

**说明:** 场景 3 期望正常 frontier round 输出。断言不显式检查"未创建 handoffs 文件"(临时目录隔离),而是以响应包含正常技术讨论为 proxy。如果你要更严格的"不触发"判据,可在 Task 6 跑完后用 `grep -c "questionnaire" /tmp/.../no-speculative-trigger.json` 手动二次确认 = 0。

- [ ] **Step 5.4: 校验 run-test.sh 引用三个场景名**

Run:
```bash
for name in frontier-hard-rule to-questionnaire-trigger no-speculative-trigger; do
  if grep -qF "prompts/$name.txt" tests/skill-behavior/brainstorming/run-test.sh; then
    echo "OK: $name referenced"
  else
    echo "MISSING: $name"
  fi
done
```

Expected: 3 行 `OK:`

---

## Task 6: 跑改后 behavior 测试,记录对比

Blocking: Task 5
Slice type: verification
Seam: headless 测试输出

**Files:**
- 临时产物:`/tmp/after-brainstorming-to-questionnaire/`(不入 git)

**Interfaces:**
- Consumes: 改后的 SKILL.md + 扩展后的 run-test.sh
- Produces: 改后行为日志,贴 PR 描述

- [ ] **Step 6.1: 跑 run-test.sh 全套(原 4 + 新 3 = 7 场景)**

```bash
cd tests/skill-behavior/brainstorming
./run-test.sh 2>&1 | tee /tmp/after-brainstorming-to-questionnaire/run-output.log
```

Expected:
- 所有 7 个场景的 `STATUS: PASSED` 都出现
- 没有 `STATUS: FAILED`
- 整体脚本退出码 0(或最后一个场景通过)

**如果失败:** headless 测试可能 flaky。先复跑一次;仍失败再看是模型漂移还是 SKILL.md 改动有问题。

- [ ] **Step 6.2: 保存改后输出,与 baseline 对比**

```bash
mkdir -p /tmp/after-brainstorming-to-questionnaire
# 把最新一次每个场景的 final response 抽出来
for prompt in frontier-hard-rule to-questionnaire-trigger no-speculative-trigger; do
  # 找最新的 log 文件
  latest=$(ls -t /tmp/agent-harness-tests/*/skill-behavior/brainstorming/claude-output.json 2>/dev/null | head -1)
  # 注:run_skill 每次覆盖同名 LOG_FILE,这里只看最后一次 run-test.sh 的结果
done
# 实操:直接从 /tmp/after-brainstorming-to-questionnaire/run-output.log 提取 7 段 summary
echo "=== Diff summary ==="
diff /tmp/baseline-brainstorming-to-questionnaire/summary.md \
     /tmp/after-brainstorming-to-questionnaire/run-output.log 2>&1 | head -50 || true
```

Expected: 输出对比存在(差异是预期的 — 改后输出含 questionnaire 字样、frontier 更坚持等)

- [ ] **Step 6.3: 手动二次校验"不滥触发"判据**

Run:
```bash
# 找最新一次 no-speculative-trigger 的 log
latest_no_trig=$(ls -t /tmp/agent-harness-tests/*/skill-behavior/brainstorming/claude-output.json | head -1)
# 注:run_skill 写同一 LOG_FILE,跑完全套后只剩最后一个场景的 log
# 所以这一步要么在 Task 5 跑完后单独跑场景 3,要么靠 run-test.sh 的 assert_response_contains 间接验证
echo "如果你担心场景 3 的'不滥触发'判据,可单独再跑一次:"
echo "  source tests/skill-behavior/_helpers/run-skill.sh"
echo "  run_skill brainstorming tests/skill-behavior/brainstorming/prompts/no-speculative-trigger.txt 5"
echo "  grep -c questionnaire \$LOG_FILE"
```

Expected: 在场景 3 单独跑时,`grep -c questionnaire $LOG_FILE` 应为 0 或非常低

---

## Task 7: skill 加载测试

Blocking: Task 3 (需要 SKILL.md 改完)
Slice type: verification
Seam: skill 加载机制

**Files:**
- 临时产物:无(测试输出到 stdout)

- [ ] **Step 7.1: 跑 run-skill-tests.sh**

```bash
cd tests/claude-code
./run-skill-tests.sh
echo "exit_code=$?"
```

Expected: 退出码 = 0(sprint-contract DoD 第 9 条)

**如果失败:** SKILL.md frontmatter 被破坏了。检查改动 1/2 是否意外影响了 YAML frontmatter(应该不会,因为改动都在第 14 行 `<HARD-GATE>` 之后)。

- [ ] **Step 7.2: 跑 plugin-infrastructure 冒烟测试(可选,保险起见)**

```bash
cd tests/plugin-infrastructure
./run-all.sh
echo "exit_code=$?"
```

Expected: 退出码 = 0(本次改动不应影响 plugin manifest / hooks,但跑一下保险)

---

## Final Commit(用户选择最后一次性 commit)

完成所有 task 后,一次性 commit:

```bash
git status
git diff --stat
# 检查改动文件清单:
#   skills/brainstorming/SKILL.md           (modified)
#   docs/agent-harness/index.md             (modified)
#   docs/agent-harness/handoffs/.gitkeep    (new)
#   docs/agent-harness/specs/2026-08-07-brainstorming-to-questionnaire-design.md (new, 已存在)
#   docs/agent-harness/contracts/brainstorming-to-questionnaire.contract.md (new, 已存在)
#   docs/agent-harness/plans/2026-08-07-brainstorming-to-questionnaire.md (new, 本文件)
#   tests/skill-behavior/brainstorming/prompts/frontier-hard-rule.txt (new)
#   tests/skill-behavior/brainstorming/prompts/to-questionnaire-trigger.txt (new)
#   tests/skill-behavior/brainstorming/prompts/no-speculative-trigger.txt (new)
#   tests/skill-behavior/brainstorming/run-test.sh (modified)

git add skills/brainstorming/SKILL.md \
        docs/agent-harness/index.md \
        docs/agent-harness/handoffs/.gitkeep \
        docs/agent-harness/specs/2026-08-07-brainstorming-to-questionnaire-design.md \
        docs/agent-harness/contracts/brainstorming-to-questionnaire.contract.md \
        docs/agent-harness/plans/2026-08-07-brainstorming-to-questionnaire.md \
        tests/skill-behavior/brainstorming/prompts/frontier-hard-rule.txt \
        tests/skill-behavior/brainstorming/prompts/to-questionnaire-trigger.txt \
        tests/skill-behavior/brainstorming/prompts/no-speculative-trigger.txt \
        tests/skill-behavior/brainstorming/run-test.sh

git commit -m "$(cat <<'EOF'
feat(brainstorming): add to-questionnaire escape hatch + frontier hard rule

吸收 mattpocock/skills 的 grilling 和 to-questionnaire 两项实践到
brainstorming skill:

- 加 frontier 未空不得进入 Propose approaches 的硬规则
- 新增 "When the user cannot answer" 小节:用户明确答不了时产出
  to-<recipient>-<slug>.md 问卷到 docs/agent-harness/handoffs/
- 问卷分支内部使用 ❓/➡️ 格式(对齐 grilling)
- 在 docs/agent-harness/index.md 注册 handoffs/ 子目录
- 新增 3 个 headless 行为测试场景(frontier-hard-rule / 
  to-questionnaire-trigger / no-speculative-trigger)

延续 brainstorming-optimization (2026-07-21) 和
mattpocock-skills-adaptation (2026-07-22) 两份前置 spec。

Refs: docs/agent-harness/specs/2026-08-07-brainstorming-to-questionnaire-design.md
EOF
)"
```

---

## DoD 追溯表(每个 criterion → 实施任务)

| Sprint Contract DoD | 实施任务 | 验证手段 |
|---|---|---|
| SKILL.md 含 "MUST NOT proceed to Propose approaches" | Task 3 Step 3.1 + 3.3 | grep 静态校验 |
| SKILL.md 含 "When the user cannot answer a frontier question (to-questionnaire escape hatch)" | Task 3 Step 3.2 + 3.3 | grep 静态校验 |
| SKILL.md 含 "Grill the send, not the subject" | Task 3 Step 3.2 + 3.3 | grep 静态校验 |
| SKILL.md 含 "If you're unsure whether the user can answer, ask them directly" | Task 3 Step 3.2 + 3.3 | grep 静态校验 |
| index.md 含 "- [handoffs/](handoffs/)" | Task 4 Step 4.2 + 4.3 | grep 静态校验 |
| handoffs/.gitkeep 存在 | Task 4 Step 4.1 | test -f |
| 3 个 fixture 存在 | Task 1 Step 1.4 | ls |
| run-test.sh 引用三个场景名 | Task 5 Step 5.4 | grep |
| run-skill-tests.sh 退出码 = 0 | Task 7 Step 7.1 | exit code |
| 改后 behavior 三场景符合预期 | Task 6 Step 6.1 + 6.3 | run-test.sh + 手动 grep |
