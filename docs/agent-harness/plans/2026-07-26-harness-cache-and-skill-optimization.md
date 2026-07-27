---
spec_ref: ../specs/2026-07-26-harness-cache-and-skill-optimization-design.md
spec_topic: harness-cache-and-skill-optimization
task_count: 11
estimated_phases: [tests, implementation, verification]
status: active
dod: "P1 静态前缀字节级稳定+learnings≤4KB+占位符置尾；P2 四 skill 拆分后 behavior test 不劣于 baseline+description<120 字符；P3 optimizer 验证链路真实可跑+index 全覆盖+stop-hook 连续失败提示"
---

# Harness 缓存与 Skill 体系优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 加固会话注入的缓存稳定前缀、瘦身 skill 注册表并对 4 个大 skill 做渐进式披露、修复 harness 自优化闭环的断裂环节。

**Architecture:** 三阶段串行（P1 缓存 → P2 披露 → P3 闭环）保证测试归因；阶段内任务可并行。所有 skill 改动只做内容搬移不重写文案，以 behavior test 前后对比为回归证据。

**Tech Stack:** bash、jq、markdown（SKILL.md + references/）、现有测试套件（plugin-infrastructure / claude-code / skill-behavior）。

**契约映射：** 每个任务标注对应 contract DoD 条目（见 `../contracts/harness-cache-and-skill-optimization.contract.md`）。

**并行 spec 协调：** 仓库存在 `context-budget-and-memory-fixes` spec（2026-07-26），主题为 top-N summary + 就近解析，与 P1 的 Task 1/2 同区域（session-start / search-learnings.sh）。执行顺序约定：本 plan P1 先执行完毕；对方写 plan 时，其 top-10 注入与本 plan Task 2 的压缩格式叠加后重新标定字节断言。

---

## P1 缓存前缀加固

### Task 1: session-start 动态段置尾

Blocking: none
Slice type: refactor
Seam: `hooks/session-start` 的 stdout JSON（startup 模式下静态段字节稳定）
files: hooks/session-start

**Files:**
- Modify: `hooks/session-start:236-240`（session_context 拼接处）

- [ ] **Step 1: 记录改动前基线输出**

```bash
echo '{"source":"startup"}' | CLAUDE_PLUGIN_ROOT=. hooks/session-start > /tmp/ss-before.json
```

- [ ] **Step 2: 调整拼接顺序**

将 `hooks/session-start` 第 239 行的 startup/clear 分支改为（动态段 context_md_hint / warning / learnings / checkpoint_hint 全部移到静态段之后）：

```bash
session_context="<EXTREMELY_IMPORTANT>\nYou have agent-harness.\n\n**Below is the full content of your 'agent-harness:using-agent-harness' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${using_agent_harness_escaped}${headless_tip_escaped}${kb_hint_escaped}\n\n${context_md_hint_escaped}${warning_escaped}${learnings_escaped}${checkpoint_hint_escaped}\n</EXTREMELY_IMPORTANT>"
```

注意：`context_md_hint` 从静态区（原来紧跟 kb_hint）移入动态区首位；其余顺序不变。resume 分支（第 237 行）不改。

- [ ] **Step 3: 验证静态段字节稳定**

```bash
echo '{"source":"startup"}' | CLAUDE_PLUGIN_ROOT=. hooks/session-start > /tmp/ss-run1.json
echo '{"source":"startup"}' | CLAUDE_PLUGIN_ROOT=. hooks/session-start > /tmp/ss-run2.json
# 截取开头到 kb_hint 结束（即 context_md_hint 之前）的静态段对比
python3 -c "
import json,sys
a=json.load(open('/tmp/ss-run1.json'))['hookSpecificOutput']['additionalContext']
b=json.load(open('/tmp/ss-run2.json'))['hookSpecificOutput']['additionalContext']
cut=a.find('## Domain Glossary') if '## Domain Glossary' in a else len(a)
assert a[:cut]==b[:cut], 'STATIC PREFIX DIFFERS'
print('STATIC PREFIX STABLE, len=', cut)"
```

Expected: `STATIC PREFIX STABLE`

- [ ] **Step 4: 跑 plugin-infrastructure 测试**

Run: `tests/plugin-infrastructure/run-all.sh`
Expected: 全部通过

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start
git commit -m "perf(hooks): session-start 动态段统一置尾，保证缓存前缀字节稳定"
```

### Task 2: learnings 摘要压缩至 ≤4KB

Blocking: none
Slice type: tracer-bullet
Seam: `scripts/search-learnings.sh --summary` 的 stdout
files: scripts/search-learnings.sh

**Files:**
- Modify: `scripts/search-learnings.sh`（summary 格式化的 python 段）
- Test: `tests/learnings-scripts/test-learnings.sh`

- [ ] **Step 1: 记录当前体积（预期 ~16.8KB）**

```bash
scripts/search-learnings.sh --summary | wc -c
```

- [ ] **Step 2: 修改 summary 格式（以 summary_mode 条件分支实现，不影响 --all/--recent/关键词模式）**

在 `search-learnings.sh` 内嵌 python 的条目输出段，将条目打印改为条件分支——`summary_mode` 时紧凑格式，否则保持原样：

```python
# 条目打印改为 summary_mode 条件分支
if summary_mode:
    # summary: 单行紧凑，首句截断 ≤120 字符，无 files 尾注
    insight = e.get('insight', '')
    for sep in ('\u3002', '. '):
        idx = insight.find(sep)
        if 0 < idx < 120:
            insight = insight[:idx + len(sep)].strip()
            break
    else:
        insight = insight[:120].strip()
    print(f"- [{e['key']}] ({e['_effective_confidence']}/10) {insight}")
else:
    # 非 summary 模式（--all / --recent / 关键词搜索）保持原格式
    files = f" (files: {', '.join(e.get('files', []))})" if e.get('files') else ""
    print(f"- [{e['key']}] (confidence: {e['_effective_confidence']}/10, {e.get('source', 'unknown')})")
    print(f"  {e.get('insight', '')}{files}")
```

- [ ] **Step 3: 验证体积与格式**

```bash
scripts/search-learnings.sh --summary | wc -c        # Expected: ≤ 4096
scripts/search-learnings.sh --summary | head -8      # Expected: 每条一行 "- [key] (N/10) 一句话"
```

- [ ] **Step 4: 跑 learnings 脚本测试**

Run: `tests/learnings-scripts/test-learnings.sh`
Expected: 全部通过（若测试断言旧格式，同步更新断言为新格式——断言改动限于格式字符串）

- [ ] **Step 5: Commit**

```bash
git add scripts/search-learnings.sh tests/learnings-scripts/test-learnings.sh
git commit -m "perf(learnings): summary 输出压缩为单行首句格式，37 条时 ≤4KB"
```

### Task 3: orchestrator-prompt 动态占位符置尾

Blocking: none
Slice type: refactor
Seam: `./scripts/auto-loop.sh --dry-run` 启动日志（占位符填充正确）
files: skills/auto-loop/orchestrator-prompt.md

**Files:**
- Modify: `skills/auto-loop/orchestrator-prompt.md`

File note: `{{SCAN_TARGET}}`/`{{FILTER}}`/`{{MODE}}`/`{{STATE_FILE}}` 在稳定指令体内散落多处（53-149 行），填充后单次 run 内全文本就是静态的；跨 run 前缀仍会被体内散留占位符打断，此改动收益有限——但靠近文件顶部的集中上下文块（37-49 行）移走可减少每次 run 前缀的变异性，仍是正确做法。auto-loop.sh 的 jq gsub 做全文替换，与位置无关，无需同步修改。

- [ ] **Step 1: 结构重排**

将第 37-49 行区域的运行上下文块（含 `{{REQUEST}}` `{{SCOPE}}` `{{SCAN_TARGET}}` `{{BRANCH}}` `{{MODE}}` `{{FILTER}}` `{{TARGET_ISSUES}}` `{{MAX_ISSUES}}` `{{STATE_FILE}}` 的整段）剪切，移到文件末尾，标题改为 `## 本次运行上下文（每次运行不同，置于文件末尾以保护缓存前缀）`。稳定指令体（生存规则、state.json 协议、8 步链路、会话筛选协议）保持在前部原顺序。稳定段内嵌的 `{{REPO_ROOT}}`（约第 21-30 行示例命令处）保留原位。

- [ ] **Step 2: 验证占位符仍全部存在**

```bash
for p in REQUEST SCOPE SCAN_TARGET BRANCH MODE FILTER TARGET_ISSUES MAX_ISSUES REPO_ROOT STATE_FILE; do
  grep -q "{{$p}}" skills/auto-loop/orchestrator-prompt.md || echo "MISSING: $p"
done
```

Expected: 无输出（全部存在）

- [ ] **Step 3: dry-run 验证填充**

Run: `./scripts/auto-loop.sh --dry-run "测试占位符填充"`
Expected: 正常启动、无未替换的 `{{` 出现在派发 prompt 中（检查 `.claude/auto-loop/runs/<run_id>/` 下日志），Ctrl+C 或等待分析完成后 `./scripts/auto-loop.sh --cleanup`

- [ ] **Step 4: Commit**

```bash
git add skills/auto-loop/orchestrator-prompt.md
git commit -m "perf(auto-loop): 动态占位符块移至 prompt 末尾，稳定指令体前置命中缓存"
```

## P2 注册表瘦身 + 渐进式披露

> 拆分守则（每个任务共同遵守）：只搬移不重写；硬约束/检查清单/HARD-GATE/流程图留 SKILL.md；跨 skill 引用章节禁止移出；SKILL.md 内插入硬指引行 `> 需要 <主题> 时，读 references/<file>.md`。

### Task 4: harness-design 拆分

Blocking: Task 1, Task 2, Task 3
Slice type: refactor
Seam: `tests/skill-behavior/harness-design/run-test.sh` 前后对比
files: skills/harness-design/SKILL.md, skills/harness-design/references/

**Files:**
- Modify: `skills/harness-design/SKILL.md`
- Create: `skills/harness-design/references/brand-spec-template.md`、`references/design-advisor-fallback.md`、`references/app-ios-rules.md`、`references/starter-components.md`、`references/design-md-generation.md`、`references/cross-agent-adaptation.md`、`references/watermark.md`

- [ ] **Step 1: 记录 baseline**

```bash
cd tests/skill-behavior/harness-design && ./run-test.sh | tee /tmp/harness-design-baseline.log; cd -
```

- [ ] **Step 2: 搬移章节**

从 SKILL.md 整段剪切以下章节到对应 references/ 文件（原文不改一字），原位置各留一行硬指引：
- `# <Brand> · Brand Spec` 模板（约 223-381 行）→ `references/brand-spec-template.md`
- `## 设计方向顾问（Fallback 模式）` → `references/design-advisor-fallback.md`
- `## App / iOS 原型专属守则` → `references/app-ios-rules.md`
- `## Starter Components（assets/下）` → `references/starter-components.md`
- `## 工作流末尾 · 生成 DESIGN.md` → `references/design-md-generation.md`
- `## 跨 Agent 环境适配说明` → `references/cross-agent-adaptation.md`
- `## Skill 推广水印（仅动画产出）` → `references/watermark.md`

保留在 SKILL.md：使用前提、handoff contract、核心原则 #0、核心哲学、架构选型、工作流程、异常处理、反AI slop速查、技术红线、References路由表（更新路由表加入新文件）、产出要求、核心提醒。

- [ ] **Step 3: 验证尺寸、保留项与硬指引**

```bash
wc -c skills/harness-design/SKILL.md   # Expected: ≤ 12288
grep -c "核心原则 #0\|技术红线\|References路由表" skills/harness-design/SKILL.md  # Expected: ≥ 3
grep -c "^> 需要.*读 references/" skills/harness-design/SKILL.md  # Expected: ≥ 3（每移出一个章节一条硬指引）
```

- [ ] **Step 4: 重跑 behavior test 对比 baseline**

```bash
cd tests/skill-behavior/harness-design && ./run-test.sh | tee /tmp/harness-design-after.log; cd -
```

Expected: 结果不劣于 baseline；若劣化，将导致劣化的章节搬回 SKILL.md 后重测

- [ ] **Step 5: Commit**

```bash
git add skills/harness-design/
git commit -m "refactor(harness-design): 渐进式披露拆分，SKILL.md 61KB→≤12KB，细节移入 references/"
```

### Task 5: writing-skills 拆分

Blocking: Task 1, Task 2, Task 3
Slice type: refactor
Seam: `tests/skill-behavior/writing-skills/run-test.sh` 前后对比
files: skills/writing-skills/SKILL.md, skills/writing-skills/references/

**Files:**
- Modify: `skills/writing-skills/SKILL.md`
- Create: `skills/writing-skills/references/description-examples.md`、`references/cso-details.md`

- [ ] **Step 1: 记录 baseline**

```bash
cd tests/skill-behavior/writing-skills && ./run-test.sh | tee /tmp/writing-skills-baseline.log; cd -
```

- [ ] **Step 2: 搬移章节**

- `## Claude Search Optimization (CSO)` 中的 BAD/GOOD 示例块（保留规则文字与各 1 个最典型示例）→ `references/cso-details.md`
- SKILL.md Structure 之后的成组 `# ❌ BAD / # ✅ GOOD` 示例块 → `references/description-examples.md`

保留：Overview、TDD Mapping、When to Create、Skill Types、Directory Structure、SKILL.md Structure 骨架、CSO 规则文字。已有的顶层辅助文件（anthropic-best-practices.md 等）不动。

- [ ] **Step 3: 验证尺寸、保留项与硬指引**

```bash
wc -c skills/writing-skills/SKILL.md   # Expected: 明显小于 23857（目标 ~8KB，超出可接受）
grep -c "TDD Mapping\|RED\|GREEN" skills/writing-skills/SKILL.md  # Expected: ≥ 3（TDD 流程保留）
grep -c "^> 需要.*读 references/" skills/writing-skills/SKILL.md  # Expected: ≥ 2（每移出一个章节一条硬指引）
```

- [ ] **Step 4: 重跑 behavior test 对比**

```bash
cd tests/skill-behavior/writing-skills && ./run-test.sh | tee /tmp/writing-skills-after.log; cd -
```

Expected: 不劣于 baseline

- [ ] **Step 5: Commit**

```bash
git add skills/writing-skills/
git commit -m "refactor(writing-skills): 示例块移入 references/，规则留主干"
```

### Task 6: brainstorming 六问表格移出

Blocking: Task 1, Task 2, Task 3
Slice type: refactor
Seam: `tests/skill-behavior/brainstorming/run-test.sh` 前后对比
files: skills/brainstorming/SKILL.md, skills/brainstorming/references/

**Files:**
- Modify: `skills/brainstorming/SKILL.md`
- Create: `skills/brainstorming/references/six-forcing-questions.md`

- [ ] **Step 1: 记录 baseline**

```bash
cd tests/skill-behavior/brainstorming && ./run-test.sh | tee /tmp/brainstorming-baseline.log; cd -
```

- [ ] **Step 2: 搬移**

仅剪切 `## Six Forcing Questions (Product Ideas)` 的六问表格与"After the six questions"细节 → `references/six-forcing-questions.md`。SKILL.md 原位保留触发条件（"When to use" 段）+ 硬指引：

```markdown
## Six Forcing Questions (Product Ideas)

**When to use:** User says "I have an idea", "is this worth building", or describes a new product/feature concept. Skip for bug fixes, small improvements, refactoring, validated requirements.

> 命中触发条件时，读 `references/six-forcing-questions.md` 获取六问表格与后续处理流程，逐问执行。
```

**禁止移出**：Checklist、Process Flow 流程图、HARD-GATE、Clarification Loop Circuit-Breaker（loop-detection 交叉引用）、The Process、After the Design。

- [ ] **Step 3: 验证保留项与硬指引**

```bash
grep -c "HARD-GATE\|Circuit-Breaker\|digraph" skills/brainstorming/SKILL.md  # Expected: ≥ 3
grep -c "^> .*读 references/" skills/brainstorming/SKILL.md  # Expected: ≥ 1（六问表格硬指引）
```

- [ ] **Step 4: 重跑 behavior test 对比**

```bash
cd tests/skill-behavior/brainstorming && ./run-test.sh | tee /tmp/brainstorming-after.log; cd -
```

Expected: 不劣于 baseline

- [ ] **Step 5: Commit**

```bash
git add skills/brainstorming/
git commit -m "refactor(brainstorming): 六问表格移入 references/，circuit-breaker 等规则保留主干"
```

### Task 7: writing-plans 拆分

Blocking: Task 1, Task 2, Task 3
Slice type: refactor
Seam: `tests/skill-behavior/writing-plans/run-test.sh` 前后对比
files: skills/writing-plans/SKILL.md, skills/writing-plans/references/

**Files:**
- Modify: `skills/writing-plans/SKILL.md`
- Create: `skills/writing-plans/references/task-examples.md`

- [ ] **Step 1: 记录 baseline**

```bash
cd tests/skill-behavior/writing-plans && ./run-test.sh | tee /tmp/writing-plans-baseline.log; cd -
```

- [ ] **Step 2: 搬移**

- `## Task Structure` 的完整示例代码块（python 测试示例部分）→ `references/task-examples.md`，SKILL.md 保留结构骨架（Task 标题格式、Blocking/Slice type/Seam/Files 字段说明、步骤粒度要求）+ 硬指引
- `## SDD Fan-Out Annotations` 的三任务示例块 → 同一 references 文件；注解规则文字（Blocking/files 字段语义、read-after-write 规则、标题正则要求）**必须保留**

**禁止移出**：No Placeholders、Scope Check、单会话承载上限、GDD gate、Self-Review、Execution Handoff。

- [ ] **Step 3: 验证保留项与硬指引**

```bash
grep -c "No Placeholders\|Blocking:\|### Task N:" skills/writing-plans/SKILL.md  # Expected: ≥ 3
grep -c "^> .*读 references/" skills/writing-plans/SKILL.md  # Expected: ≥ 2（task-examples.md 和 fan-out 示例各一条）
```

- [ ] **Step 4: 重跑 behavior test 对比**

```bash
cd tests/skill-behavior/writing-plans && ./run-test.sh | tee /tmp/writing-plans-after.log; cd -
```

Expected: 不劣于 baseline

- [ ] **Step 5: Commit**

```bash
git add skills/writing-plans/
git commit -m "refactor(writing-plans): 示例块移入 references/，任务结构规则保留主干"
```

### Task 8: description 压缩 + disable-model-invocation

Blocking: Task 4, Task 5, Task 6, Task 7
Slice type: refactor
Seam: `tests/claude-code/run-skill-tests.sh` + headless slash 调用
files: skills/harness-design/SKILL.md, skills/retrospective/SKILL.md, skills/domain-modeling/SKILL.md, skills/generate-issues/SKILL.md, skills/fix-issues-and-pr/SKILL.md

**Files:**
- Modify: 上述 5 个 SKILL.md 的 frontmatter

- [ ] **Step 1: 压缩 3 个超长 description（保留触发关键词）**

- harness-design（288 字符）→ `用HTML做高保真原型、Demo、幻灯片、动画。触发词：做原型、设计Demo、UI mockup、prototype、iOS/移动端原型、设计风格、做个HTML页面、导出MP4/GIF。`
- retrospective → 保留 'do a retro' / 'review the week' / sprint 结束触发词，压缩到 <120 字符
- domain-modeling → 保留术语定义/架构决策/glossary 触发词，压缩到 <120 字符

```bash
for s in harness-design retrospective domain-modeling; do
  awk '/^description:/{sub(/^description: */,""); print; exit}' skills/$s/SKILL.md | wc -c
done   # Expected: 每个 < 120
```

- [ ] **Step 2: 命令型 skill 加 disable-model-invocation**

在 `skills/generate-issues/SKILL.md` 和 `skills/fix-issues-and-pr/SKILL.md` frontmatter 加：

```yaml
disable-model-invocation: true
```

- [ ] **Step 3: 验证 slash 入口仍可用**

`disable-model-invocation: true` 后 skill 从 Skill 工具自动触发池移除，但 slash 入口（`/agent-harness:generate-issues`）不受影响。验证命令：

```bash
claude -p "/agent-harness:generate-issues --help, then stop and report" --max-turns 3 2>&1 | tail -5
```

Expected: skill 内容成功加载（无 "skill not found" 或 "not recognized"）

- [ ] **Step 4: 跑 skill 加载测试**

Run: `cd tests/claude-code && ./run-skill-tests.sh`
Expected: 全部通过

- [ ] **Step 5: Commit**

```bash
git add skills/harness-design/SKILL.md skills/retrospective/SKILL.md skills/domain-modeling/SKILL.md skills/generate-issues/SKILL.md skills/fix-issues-and-pr/SKILL.md
git commit -m "perf(skills): 注册表瘦身——压缩超长 description，命令型 skill 退出自动触发池"
```

## P3 闭环修复

### Task 9: harness-optimizer 验证链路修复

Blocking: Task 8
Slice type: tracer-bullet
Seam: SKILL.md Step 5 文本（引用真实存在的测试命令）
files: skills/harness-optimizer/SKILL.md

**Files:**
- Modify: `skills/harness-optimizer/SKILL.md:177-189`（Step 5 验证优化段）

- [ ] **Step 1: 替换 Step 5 内容**

将引用 `skill_creator.scripts.run_eval` 的整段替换为：

````markdown
## Step 5: 验证优化

修改 skill 后，用真实测试链路验证：

```bash
# 优先：目标 skill 的 headless 行为测试（消耗 API 配额，1-3 分钟）
cd tests/skill-behavior/<skill-name> && ./run-test.sh

# 无对应行为测试时降级：skill 加载测试
cd tests/claude-code && ./run-skill-tests.sh --test <skill-name>
```

修改前先跑一次记录 baseline，修改后对比；劣化则回滚改动。
````

- [ ] **Step 2: 验证无残留引用**

```bash
grep -rn "skill_creator" skills/harness-optimizer/  # Expected: 无输出
ls tests/skill-behavior/ tests/claude-code/run-skill-tests.sh  # Expected: 路径真实存在
```

- [ ] **Step 3: Commit**

```bash
git add skills/harness-optimizer/SKILL.md
git commit -m "fix(harness-optimizer): 验证环节改指向真实测试链路，修复闭环断点"
```

### Task 10: specs/index.md 锚点补全

Blocking: none
Slice type: verification
Seam: index.md 主题速查覆盖率
files: docs/agent-harness/index.md, docs/agent-harness/specs/index.md

- [ ] **Step 1: 重建索引**

Run: `scripts/index-knowledge-base.sh`
Expected: specs/index.md 覆盖全部 spec 文件

- [ ] **Step 2: 手动核对主题锚点**

对每个含 `spec_topic` frontmatter 的 spec，确认 `docs/agent-harness/index.md` 主题速查有对应锚点；缺失的补一行 `- <topic> → specs/<file>.md`：

```bash
for f in docs/agent-harness/specs/2026-*.md; do
  t=$(awk '/^spec_topic:/{print $2; exit}' "$f")
  [ -n "$t" ] && ! grep -q "^- $t " docs/agent-harness/index.md && echo "MISSING: $t → $f"
done
```

Expected: 补全后再跑无输出

- [ ] **Step 3: Commit**

```bash
git add docs/agent-harness/index.md docs/agent-harness/specs/index.md
git commit -m "docs(kb): 补全 specs 主题锚点，两级检索全覆盖"
```

### Task 11: stop-hook 连续失败提示

Blocking: none
Slice type: tracer-bullet
Seam: 构造 3 条 failed 记录后运行 stop-hook 的 stdout
files: hooks/stop-hook.sh

**Files:**
- Modify: `hooks/stop-hook.sh`（非 ralph 早退分支 exit 0 之前插入）

- [ ] **Step 1: 写检查逻辑（插入 hooks/stop-hook.sh:32-35 的 `[[ ! -f "$RALPH_STATE_FILE" ]]` → `exit 0` 块内，紧贴 exit 0 之前）**

```bash
# 闭环信号：同一 spec_topic 最近 3 次 gate 全 failed → 提示运行 harness-optimizer（仅提示不执行）
# 采用 spec_topic 聚合（contact boundary conditions 降级许可，因 phase-metrics.jsonl 无 skill 级字段）
METRICS_FILE="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}/.agent-harness/phase-metrics.jsonl"
if [ -f "$METRICS_FILE" ] && command -v jq >/dev/null 2>&1; then
  failed_topic=$(tail -50 "$METRICS_FILE" | jq -rs '
    map(select(.action=="gate")) | group_by(.spec_topic)
    | map(select(length>=3) | sort_by(.ts) | .[-3:]
          | select(all(.gate_result=="failed")) | .[0].spec_topic)
    | .[0] // empty' 2>/dev/null || true)
  if [ -n "$failed_topic" ]; then
    jq -n --arg t "$failed_topic" \
      '{systemMessage: ("⚠ spec_topic \($t) 最近连续 3 次 gate failed — 建议运行 harness-optimizer 分析原因")}'
    exit 0
  fi
fi
```

注意：插入点在 `exit 0` 之前、`[[ ! -f "$RALPH_STATE_FILE" ]]` 块内——当 ralph loop 激活时此块被跳过，新逻辑不受影响。

- [ ] **Step 2: 手动构造数据验证触发**

```bash
mkdir -p /tmp/sh-test/.agent-harness && cd /tmp/sh-test && git init -q
for i in 1 2 3; do
  echo "{\"ts\":\"2026-07-26T0$i:00:00Z\",\"spec_topic\":\"test-topic\",\"action\":\"gate\",\"gate_result\":\"failed\"}" >> .agent-harness/phase-metrics.jsonl
done
CLAUDE_PROJECT_DIR=/tmp/sh-test bash /Users/arwen/Desktop/Arwen/evanfang/agent-harness/hooks/stop-hook.sh </dev/null
```

Expected: 输出含 `test-topic 最近连续 3 次 gate failed`

- [ ] **Step 3: 验证正常路径不受影响**

```bash
cd /Users/arwen/Desktop/Arwen/evanfang/agent-harness && bash hooks/stop-hook.sh </dev/null   # 无 ralph state、无连续失败
```

Expected: 原有行为不变（静默退出或原有输出）；另跑 `tests/phase-metrics-scripts/run-all.sh` 确认无回归

- [ ] **Step 4: Commit**

```bash
git add hooks/stop-hook.sh
git commit -m "feat(hooks): stop-hook 检测连续 3 次 gate failed，提示运行 harness-optimizer 闭环"
```

---

## 最终验收（对照 contract）

- [ ] `tests/plugin-infrastructure/run-all.sh`、`tests/claude-code/run-skill-tests.sh` 退出码 0
- [ ] session-start 静态段 diff 为空（Task 1 Step 3 脚本）
- [ ] 4 个 skill behavior test 不劣于 baseline（/tmp/*-baseline.log vs *-after.log）
- [ ] `./scripts/auto-loop.sh --dry-run "测试"` 正常
- [ ] 逐条勾选 contract DoD 后，将 contract 各项打勾并 commit
