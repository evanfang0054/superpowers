---
spec_topic: upstream-v6-2-adaptation
decision_summary: "以逐能力三方适配方式吸收 Superpowers v6.2.0 中已核验的行为，保留 Agent Harness 的品牌、多平台策略、Ralph Loop 与独立分支默认工作流。"
design_approved: true
user_approved_at: "2026-07-29T00:00:00+08:00"
gates: [user-review-passed]
domain_terms: [计划专属 SDD 工作区, 计划身份 Ledger, 修复轮次, 承重问题, 停驻裁决]
---

# 上游 v6.2.0 适配设计

## 背景

Agent Harness 是 Superpowers 的深度定制 fork，不以 Git 历史 merge 同步上游，而按能力做文件级适配。上游比较基线为 `b62616f`（v6.0.2）到 `3dcbd5c`（v6.2.0）。本次仅纳入经上游源码与 commit diff 核验的行为；不将 fork 自有能力或设计推断表述为上游实现。

适配以当前 Agent Harness 为主：保留 `.agent-harness` 品牌、Ralph Loop、双轴 review、frontier brainstorming、GDD、sprint contract、computational sensors、learnings 和现有多平台策略。上游 `.superpowers` 路径仅作为来源，不进入 fork 实现。

## 目标

- 修复上游已验证的 `find-polluter` 路径匹配与空结果计数问题。
- 将 SDD artifacts 从共享目录改为按计划隔离的计划专属 SDD 工作区。
- 引入上游 v6.2 的计划身份 Ledger、五轮修复闭环、范围复审和最终审查边界。
- 恢复上游 finishing 的明确丢弃流程、环境识别和工作树所有权保护。
- 吸收经核验的 TDD、review 和测试稳定性规则，不回退 fork 已验证的流程增强。

## 非目标

- 不执行 `git merge upstream/main` 或机械 cherry-pick。
- 不新增 Codex Git-source marketplace、porting guide 或任何新的分发入口。
- 不替换 Agent Harness 的 manifest、版本、品牌、路径或平台策略。
- 不将上游最终的 Codex hooks 空对象策略应用到本项目；fork 的 Codex SessionStart 策略保持不变。
- 不删除 Gemini 支持或以中间 commit 代替 v6.2.0 tag 的最终状态。
- 不重新引入 visual companion。
- 不把 worktree 作为默认隔离方式；未指定位置时默认创建独立分支，只有用户明确请求时才使用 worktree。
- 不把 fork 自有的 `Interfaces`、failure-to-guidance-form 或 controller-guide 归因为上游 v6.2.0。

## 上游事实与适配映射

| 上游提交 | 已核验行为 | Agent Harness 适配 |
|---|---|---|
| `6015d37`, `c8921b5` | `find-polluter` 规范化 `./`、覆盖 `**/` 的零层匹配、空结果为 0，并新增确定性测试 | 保持脚本的两个入参，移植最终匹配与计数行为及测试 |
| `5151e7a`, `52f649e` | Claude SessionStart hook 使用 `shell: bash`，并记录 Windows fallback shell 风险 | 仅向现有 Claude SessionStart 条目增加该字段；保留 fork 的其他 hooks 并更新现有文档/测试 |
| `0e13ad8` | headless helpers 的文本断言不区分大小写；`assert_order` 在失败时显示完整输出；SDD Test 5 扩展 diff-trust 模式 | 合并这些断言与诊断行为；保留 fork 的 900 秒 timeout 和跨平台 timeout fallback |
| `6df8ba1`, `b8a2d84`, `2dbbaed` | plan-scoped workspace、`PLAN_FILE` 参数契约、计划身份 ledger、按计划清理 | 路径根替换为 `.agent-harness/sdd`，其余 artifact/ledger 契约对齐上游 |
| `87e4050`, `ebdd4ec`, `28882fc` | `re-review-prompt.md`、五轮修复闭环、模型升级、范围复审、最终审查单修复波 | 在保留 Ralph Loop 与本地 prompt 边界的前提下做三方合并 |
| `0b47219`, `9dff1a9`, `bcfe798` | finishing 环境识别、路径捕获、explicit-only discard、forge-neutral PR、owned-worktree cleanup | 恢复安全语义；默认隔离改为新分支，worktree 仅在用户明确要求时使用 |
| `9d8630d`, `caa1826`, `b9e75dd` | `writing-good-tests.md`、production break、真实行为测试、Mutation Check、TDD rationalization | 恢复按需参考文件和规则，保留 fork 的 seam-first 与既有度量/学习规则 |
| `cfb6281` | reviewer 使用精确上下文而非完整会话；diff 留在 reviewer context | 保留 Standards / Spec 双轴 review，并补强该隔离约束 |
| `05d90ac`, `1e14b23`, `153d618`, `3be5aad`, `6dbbbda`, `bc86802`, `03147d2` | 去重 recap、就近放置 YAGNI、worktree 安全流程与并行 skill 的非操作性文案压缩 | 仅迁移确实重复的文案或可映射的安全规则；不得删除 fork 的质量门禁或引用已删除 skill |

## 设计

### 稳定性补丁与测试工具

`find-polluter.sh` 保持 `<file_or_dir_to_check> <test_pattern>` 接口。实现对用户 pattern 去除单个前导 `./`，并对带与不带 `**/` 的 `find -path` 变体去重匹配；无文件时显式计数为 0。新增或适配上游确定性 shell 测试，覆盖嵌套匹配、零层匹配、输入含 `./` 和无匹配四种情形。

Claude Code 的 SessionStart hook 只在对应条目加入 `"shell": "bash"`，避免 Windows 默认 shell 解析 hook command 的问题。现有 PreToolUse、SubagentStop、Stop、session ID 等 fork hooks 不变。现有 Windows 文档和项目测试改用实际 hook 文件结构更新。

`tests/claude-code/test-helpers.sh` 采用大小写不敏感的 prose assertions；`assert_order` 在任一 pattern 缺失时打印完整响应，方便定位 headless 行为漂移。保留 fork 的 timeout portability 逻辑。

### 计划专属 SDD 工作区

每个 plan 使用一个 workspace：

```text
.agent-harness/sdd/<plan-basename>/
  progress.md
  task-<n>-brief.md
  task-<n>-report.md
  review-<base7>..<head7>.diff
```

`<plan-basename>` 精确遵循上游规则：`basename "$PLAN_FILE" .md`。这是兼容性选择，不引入 hash、路径编码或额外唯一化；同名但不同目录的 plan 仍是已知边界。

`sdd-workspace PLAN_FILE` 是唯一 workspace 解析入口。它验证文件存在、创建 `.agent-harness/sdd/<plan-basename>/`，并在 `.agent-harness/sdd/.gitignore` 写入 `*`。`task-brief` 保持 `task-brief PLAN_FILE TASK_NUMBER [OUTFILE]`；`review-package` 改为 `review-package PLAN_FILE BASE HEAD [OUTFILE]`。所有默认 artifacts 必须由 helper 解析并进入当前 plan 的目录。

计划身份 Ledger 固定在 `<workspace>/progress.md`，首行必须为：

```markdown
# SDD ledger — plan: <plan file path>
```

只有身份与当前 plan 一致的 ledger 才能恢复。旧共享路径或其他 plan 的 ledger 不得读取。Ledger 记录完成、deferred minor、修复轮次、parked ruling 和 BLOCKED 状态；`git clean -fdx` 会删除该忽略目录，恢复依据为 Git 历史而非虚构的自动恢复。

### SDD 审查与修复闭环

每个 task 继续以 brief、report、review package 和全局约束为 reviewer 输入，且必须同时给出 spec compliance 与 task quality verdict。实现 task 的 review package 必须用 implementer dispatch 前记录的 `BASE..HEAD`，不能使用 `HEAD~1`。

新增 `re-review-prompt.md`。修复后的范围复审通过 `review-package PLAN_FILE FIX_BASE HEAD` 生成 fix-range package；它仅裁定原 open findings 的 `ADDRESSED` 或 `NOT ADDRESSED`，并检查 fix diff 是否引入新的 Critical/Important breakage。未触及代码上的新观察记录为 out-of-scope，不延长修复循环。

以下情况进入修复闭环：spec verdict 失败、任一 Critical/Important finding，或 controller 核实为真实缺口的 `⚠️ Cannot verify from diff`。Minor 不进入循环，写入 ledger；与 plan 冲突的 finding 交由用户决策。

每 task 最多五个修复轮次：

1. 第 1–3 轮优先 resume 原 implementer；平台不支持 resume 时，新派发者必须得到 brief、report 和 findings。
2. 第 4–5 轮必须使用 fresh implementer，且模型能力至少比卡住的 implementer 高一档。
3. 每轮 implementer 把 fix 内容、覆盖测试、命令和输出追加到同一 `task-<n>-report.md`；短回传只报告状态、commit、单行测试、concerns 和 report path。
4. 第五轮仍有 finding 时停止派发并逐项裁决：非承重问题可写入停驻裁决；承重问题写入 `BLOCKED`，停止该 plan 后续派发并请求用户决定。

Final whole-branch review 使用 `review-package PLAN_FILE MERGE_BASE HEAD`，由最高能力模型执行，并读取 ledger 中 deferred / parked 记录。final review 有问题时只派遣一个 fixer、只进行一次 scoped re-review；残余 finding 按同一裁决规则处理，不开启第二波修复。

仅当 final whole-branch review clean 且所有接受的修复已进入当前实现分支时，删除**当前 plan** workspace；不得删除同级的其他 plan workspace。该清理发生在进入 finishing 选项前，不由 PR / Keep 选项触发。

### Finishing 与隔离

finishing 先识别 normal repository、named worktree 或 detached HEAD，并在改变目录前捕获 `WORKTREE_PATH`。若启用 worktree cleanup，只能清理由本项目拥有、且位于 `.worktrees/` 或 `worktrees/` 下的 worktree；宿主拥有的 workspace 保留。

普通仓库和 named worktree 的标准选项为 local merge、push + create PR、keep as-is；detached HEAD 为 push as new branch + create PR、keep as-is。PR 创建表达为 forge-neutral，具体命令基于当前可用 forge 工具。discard 不作为标准菜单项，只有用户明确要求时才展示分支、commits、worktree 并要求精确输入 `discard`。

merge 后必须验证合并结果；失败则停止并保留分支/worktree。PR 与 Keep 保留 worktree。fork 的 SDD artifact cleanup 不得在 PR / Keep 时无条件运行，且必须遵循当前 plan 的 final-review-clean 生命周期。

执行实现计划前的默认隔离规则为：用户指定分支时在其上执行；用户未指定时创建独立分支；只有用户明确要求时才创建或使用 worktree。该规则取代上游将 worktree 作为默认隔离手段的实现细节。

### Skill 规则适配

TDD 恢复 `writing-good-tests.md` 作为任何测试新增或修改前按需加载的参考。它至少包括：每个测试先说明可捕获的 production break；expected value 不由被测代码或其 helper 计算；不测试 source text；模拟仅隔离慢/外部副作用且不对 mock 本身断言；生产类不添加 test-only cleanup API；完成前执行 Mutation Check。现有 seam-first、test-first、phase metrics 与 learnings 规则保留。

review 保留 Standards / Spec 双轴；新增 reviewer 不接收完整 session history、controller 不 inline review diff 的约束。reviewer 获得精确构造的需求、DoD、brief、report、review package 和必要范围上下文，只回传 findings。

对 brainstorming、writing-plans、writing-skills、verification-before-completion 和 dispatching-parallel-agents，只删除确实重复的 recap / 宣传文字或把 YAGNI 移到对应方案比较位置。不得删除本 fork 的 frontier questioning、GDD、sprint contract、Interfaces、computational sensors、loop detection、phase metrics 或 learnings。`using-git-worktrees` 已删除，本次不恢复它；executing-plans 不得引用该 skill。

## 测试策略

### 确定性测试

- `find-polluter` 测试覆盖 pattern 的 `./`、零层、嵌套和空匹配。
- SDD workspace 测试覆盖缺失/错误 plan 的 exit 2、按 basename 的目录、根 `.gitignore`、Git 不可见性、两个 plan 隔离、brief/review package 默认位置、`review-package` 的 plan 首参和 linked worktree 隔离。
- SDD script 调用契约、ledger 身份拒绝和只删除当前 plan workspace 采用不依赖模型的 shell 断言。
- finishing contract 测试覆盖：路径在目录切换前捕获、非拥有 worktree 不删除、discard 非标准菜单项、PR / Keep 不清理活跃 plan 的 ledger。
- hook JSON 与 Windows 文档测试验证 Claude SessionStart 的 `shell: bash`。

### Headless 行为测试

- SDD：task reviewer 同时产生两个 verdict；修复循环仅 scope fix range；轮次 4 升级 fresh agent；第五轮对承重问题报告 BLOCKED。
- TDD：对写/改测试请求先加载 good-tests reference，选择可观察 seam，且不产生 source-text 或 mock-only test。
- review：reviewer context 不包含协调器完整会话，输出仍按 Standards / Spec 分区。

### 回归

先运行相关确定性 shell 测试和 `tests/plugin-infrastructure/run-all.sh`；随后运行受影响的 Claude Code skill 加载测试。修改 skills 时，按 writing-skills 规则记录 baseline/压力场景，并只对已观察到的行为缺口改文案。

## 风险与缓解

| 风险 | 缓解 |
|---|---|
| 机械同步覆盖 fork 能力 | 所有改动按上游事实表三方合并；禁止整体替换 SKILL.md 或 manifest |
| 同名 plan 目录冲突 | 明确沿用上游 basename 边界；本次不虚称已解决 |
| Ralph Loop 在 BLOCKED finding 上空转 | BLOCKED 停止当前 plan 的后续派发并请求用户决定 |
| PR / Keep 后 artifacts 被过早清除 | 将 cleanup 收紧到当前 plan、final review clean、已合入的时点 |
| worktree cleanup 删除宿主目录 | 目录所有权检查和目录切换前路径捕获 |
| skill 文案修改无评估证据 | 先建立/更新压力场景，再做最小 prompt 改动并运行受影响行为测试 |
| 上游压缩移除 fork 质量门禁 | 仅删除明确重复的文案；保留 fork 的 quality signals 和流程 gate |

## 实施顺序

1. 稳定性补丁：find-polluter、hook、headless helpers 和确定性测试。
2. SDD workspace API、ledger 和 script 测试。
3. SDD prompts、fix-loop、scoped re-review、final review 与行为测试。
4. finishing 生命周期、独立分支默认策略和 contract 测试。
5. TDD / review / prose 就近重排，逐项按 skill baseline 与压力场景验证。

每阶段独立审阅和验证；不以单一大 diff 取代分阶段证据。

## Gate Driven Development

### ROOT

本设计以逐能力适配方式将已核验的 Superpowers v6.2.0 行为引入 Agent Harness：确定性脚本与 hook 修复、计划专属 SDD artifacts、可收敛的 review/fix 生命周期，以及不回退本地多平台与质量流程的 skill 规则。每个高风险契约由最便宜的确定性 gate 负责细节断言；headless gate 只证明 agent 能走到代表性行为，最终人工双轴 review 验证三方适配没有越界。

### Level Items

#### L4-1

PARENT_ID：ROOT  
视角下的需求：执行 SDD 的用户能够对单一计划安全恢复和完成 review/fix 流程，而不会读取其他计划的 artifacts 或无限重试。  
Gate Items：

- Gate：`e2e gate`
  Covers：代表性的 plan → task review → fix-range re-review → final review 路径。  
  Assertions：
  1. 代表性 SDD 行为测试显示 task reviewer 同时输出 spec compliance 与 task quality verdict。
  2. 代表性修复路径只将 `FIX_BASE..HEAD` 交给 re-reviewer，并对既有 finding 输出裁定。
  3. 第五轮未解决的承重 finding 产生 `BLOCKED` 并停止当前 plan 后续派发。

#### L3-1

PARENT_ID：L4-1  
视角下的需求：同一 worktree 中的每个 plan 有独立的 SDD artifact 边界和可验证的脚本接口。  
Gate Items：

- Gate：`contract gate`
  Covers：`sdd-workspace`、`task-brief`、`review-package` 的 `PLAN_FILE` 参数契约和默认 artifact 位置。  
  Assertions：
  1. `sdd-workspace PLAN_FILE` 对缺失或不存在的 plan 返回 exit 2；有效 plan 输出 `.agent-harness/sdd/<plan-basename>`。
  2. `task-brief PLAN_FILE TASK_NUMBER` 与 `review-package PLAN_FILE BASE HEAD` 的默认输出位于该 plan 的 workspace。
  3. `review-package` 使用 caller 给定的完整 `BASE..HEAD`，而非隐式 `HEAD~1` 范围。

- Gate：`integration gate`
  Covers：workspace 根忽略、两个 plan 和 linked worktree 的 artifact 隔离。  
  Assertions：
  1. `.agent-harness/sdd/.gitignore` 为 `*`，artifacts 不出现在 `git status` 或 `git add -A` 中。
  2. 两个 basename 不同的 plan 写入不同 workspace，互不覆盖 brief、report、review package 或 ledger。
  3. linked worktree 解析自己的仓库根和自己的 plan workspace。

#### L2-1

PARENT_ID：L3-1  
视角下的需求：计划身份 Ledger 只恢复属于活动 plan 的状态，并在修复流程中保留可裁定的状态记录。  
Gate Items：

- Gate：`fixture gate`
  Covers：ledger 首行身份、恢复拒绝、fix / parked / BLOCKED 状态格式。  
  Assertions：
  1. 首行为 `# SDD ledger — plan: <plan file path>` 且与活动 plan 一致的 ledger 才可恢复。
  2. 身份不符的 ledger 与旧共享路径 ledger 不会使 controller 跳过活动 plan 的 task。
  3. 修复轮次、停驻裁决、BLOCKED 和 complete 记录均保留 task identity 与相应结论。

#### L3-2

PARENT_ID：L4-1  
视角下的需求：修复循环在固定轮次内可靠收敛，并让 final review 的修复范围保持有限。  
Gate Items：

- Gate：`contract gate`
  Covers：SDD prompt 与 controller 的五轮、模型和 re-review 边界。  
  Assertions：
  1. 第 1–3 轮优先 resume 原 implementer；不可 resume 时派发输入包含 brief、report 和 findings。
  2. 第 4–5 轮使用 fresh implementer，且模型能力至少高一档。
  3. 每轮将 fix evidence 追加到同一 `task-<n>-report.md`，re-review 不扩大为全量代码审查。
  4. final review 使用 `MERGE_BASE..HEAD`，最多一波 fixer 与一次 scoped re-review。

#### L4-2

PARENT_ID：ROOT  
视角下的需求：完成分支时，用户不会被默认引导到破坏性 discard，且本项目不会删除宿主拥有的 worktree 或仍需保留的 SDD artifacts。  
Gate Items：

- Gate：`e2e gate`
  Covers：finishing 的代表性用户选项与分支隔离规则。  
  Assertions：
  1. 正常 finishing 菜单只提供 merge、PR、keep；discard 只在用户明确请求后要求精确确认。
  2. 用户未指定位置时，执行实现工作流要求创建独立分支；worktree 只在用户明确要求时使用。
  3. PR 或 Keep 路径不触发活跃 plan ledger/artifact 的无条件清理。

#### L3-3

PARENT_ID：L4-2  
视角下的需求：worktree 生命周期操作只作用于在目录切换前捕获、且由项目拥有的路径。  
Gate Items：

- Gate：`contract gate`
  Covers：finishing 环境识别、路径捕获与 ownership 限制。  
  Assertions：
  1. `WORKTREE_PATH` 在进入主仓目录前取得，并在 cleanup 阶段复用。
  2. 只有位于 `.worktrees/` 或 `worktrees/` 下的已捕获路径可被 `git worktree remove`。
  3. final review clean 后只清理当前 plan workspace，不影响 sibling plan workspace。

#### L4-3

PARENT_ID：ROOT  
视角下的需求：用户得到上游稳定性修复和更可靠的测试/review 行为，同时保留 Agent Harness 的平台与质量边界。  
Gate Items：

- Gate：`e2e gate`
  Covers：脚本、Claude hook、TDD 和 review 的代表性可见行为。  
  Assertions：
  1. `find-polluter` 对带或不带 `./` 的 pattern、零层与嵌套匹配给出相同正确文件集合；无匹配显示 0。
  2. Claude SessionStart 配置通过 `shell: bash` 保持 Windows 可分发性，且现有 hook 注册仍在。
  3. 代表性 TDD / review 行为测试保留 seam-first 与 Standards / Spec 双轴，并采用 good-tests reference 和隔离 reviewer context。

#### L2-2

PARENT_ID：L4-3  
视角下的需求：文本匹配和 reviewer 上下文规则不会因自由 prose 大小写、完整会话泄漏或 mock/source-text 测试而退化。  
Gate Items：

- Gate：`unit gate`
  Covers：headless assertion helper 和 `find-polluter` 的输入分支。  
  Assertions：
  1. prose assertion helper 对同一语义的大小写变体给出相同判断，`assert_order` 失败显示完整结果。
  2. `find-polluter` 的空集合计数为 0，且 `**/` 同时覆盖零层和嵌套层。

- Gate：`contract gate`
  Covers：TDD reference 和 review prompt 的行为边界。  
  Assertions：
  1. 测试写作规则要求说明可捕获的 production break、独立 expected value、真实行为和 Mutation Check，且不移除 seam-first。
  2. reviewer 输入不含完整 coordinator session history 或 inline review diff，输出仍分 Standards / Spec 两轴。

#### L1-1

PARENT_ID：L4-3  
视角下的需求：本次同步不会静态回退 Agent Harness 的平台、品牌和质量流程。  
Gate Items：

- Gate：`lint gate`
  Covers：显式非目标与受保护路径。  
  Assertions：
  1. 最终 diff 不移除 Codex SessionStart hook、Gemini 支持或 Agent Harness manifest/品牌配置。
  2. `executing-plans` 不引用已删除的 `using-git-worktrees` skill，且不将 worktree 写成默认隔离方式。
  3. brainstorming、GDD、sprint contract、Interfaces、computational sensors、loop detection、phase metrics 和 learnings 的既有规则未因上游 prose 压缩删除。
