# Skill Self-Optimizer 准确性优化设计

- 日期：2026-04-16
- 主题：提升 `harness-optimizerr` 对历史会话的分析可信度，避免误报驱动错误的 skill 改造
- 相关输入：`.superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661.json`、`.superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661-report.md`

## 1. 背景

当前 `harness-optimizerr` 能从 Claude Code 历史会话中提取消息、工具调用和已使用 skill，并生成汇总报告。但在分析 `ac3a4a38-1ae1-4fcc-901d-929eef8e7661` 这个会话时，报告把多类“开发过程中的正常噪音”混入了真实问题，导致输出看似具体，但不适合直接指导 skill 改造。

本次优化目标不是让报告更“严厉”，而是让它更可靠：只在证据足够时才把问题归因到 skill 或流程缺陷，否则明确标记为探索成本、TDD 红灯、hook 噪音或跨项目上下文污染。

## 2. 设计目标

### 2.1 主目标

把 `harness-optimizerr` 从粗粒度会话摘要器提升为可用于指导仓库内 skill 改造的可靠分析器。

### 2.2 成功标准

对同一会话重新分析后，报告应满足：

1. 不再把 TDD 过程中的预期测试失败大量计入严重 Bash 失败。
2. 不再把 stop hook、resume summary、skill 注入长文当成真实用户意图来检测 missed trigger。
3. 明确展示“用户要求分析的项目”和“实际命中的 session 所属项目”之间的差异。
4. recommendation 数量明显减少，且不再出现同类建议重复堆叠。
5. “应修改哪个 skill”的结论只保留高置信项；证据不足时明确写成候选项或不下结论。

## 3. 非目标

以下内容不在本轮直接改造范围内：

- 不直接重写 `systematic-debugging`、`executing-plans` 或其他 skill 文案。
- 不根据单个会话就修改全局 skill 触发策略。
- 不构建通用的会话质量评分系统。
- 不尝试修复会话中业务仓库（如 `hapi`）本身的实现问题。

## 4. 发现的问题分层

### 4.1 属于分析器误报的问题

1. **TDD 红灯被当成严重 Bash 失败**  
   在 TDD 过程中，`bun test` / `vitest` 的失败本来就是红灯验证的一部分，不应与真实执行失败等价对待。

2. **hook / summary 文本被当成真实触发上下文**  
   当前 missed trigger 检测把 stop hook feedback、续聊 summary 等文本视作用户输入，导致 `systematic-debugging` 等 skill 可能被误判为“应该触发但未触发”。

3. **长会话 duration 被直接解释为低效率**  
   续聊、Ralph loop、跨段恢复会显著拉长持续时间。原始时长可以保留，但不应直接驱动效率结论。

4. **跨项目 session 被模糊处理**  
   当前请求发生在 `superpowers` 仓库，但命中的 session 文件实际属于 `hapi` 项目。若报告不显式展示这一点，用户容易把业务会话问题误认为 `superpowers` 仓库问题。

5. **建议重复且粒度不统一**  
   相同根因被拆成多条 recommendation，降低了报告的可读性和执行性。

### 4.2 属于脚本缺陷的问题

1. 提取层没有充分保留“消息来源”与“session 来源”的元信息。
2. 分析层对失败类型的语义分类过于粗糙。
3. 模式检测过度依赖失败次数，缺少上下文判断。
4. recommendation 聚合逻辑过弱，未按根因合并。

### 4.3 暂列为候选的 skill 问题

以下问题在分析器修正前不应直接定为 skill 缺陷：

- `superpowers:systematic-debugging` 是否真的漏触发
- Ralph loop / executing-plans 是否需要调整输出方式
- 某些 skill shell wrapper 是否存在稳定性问题

这些结论必须在分析器重新跑出更干净的报告后再判断。

## 5. 方案概览

改造分三层进行：

1. **提取层校准**：让提取出的 JSON 保留足够上下文，供分析层判断。对应 `extract-session.py`。
2. **分析层校准**：识别噪音、预期失败和跨项目上下文，输出更可信的报告。对应 `analyze-session.py`。
3. **验证与分流**：用同一会话重新分析，再决定是否需要修改任何具体 skill。

## 6. 提取层设计

### 6.1 新增元数据字段

在提取结果中新增或明确以下字段：

- `requested_project_path`：用户请求分析时传入的项目路径或编码目录
- `actual_session_file_path`：最终命中的 session 文件绝对路径
- `actual_project_dir`：命中的 session 所属 Claude 项目目录
- `session_source`：命中来源，例如 `requested-project` 或 `fallback-global-search`
- `message_origin_hint`：消息来源提示，例如 `user_input`、`hook_feedback`、`resume_summary`、`skill_payload`

### 6.2 提取规则

- 当 `--project-path` 指向的目录中未找到 session，脚本回退全局查找时，必须保留这一事实。
- 对明显属于系统包装层的文本进行轻量打标，但不在提取阶段删除内容。
- `messages` 中要优先保证“后续分析所需的上下文保真”，而不是过早归因。

### 6.3 设计理由

当前误判的重要原因之一，是分析层拿不到“这条文本其实来自 hook / summary / skill payload”的信息。提取层必须先补齐信号，否则分析层只能靠脆弱的字符串启发式判断。

## 7. 分析层设计

### 7.1 失败分类升级

在现有 `invalid_tool_input`、`missing_resource`、`runtime_failure` 等类别之外，补充下列语义类别：

- `expected_test_failure`：TDD/测试验证阶段的预期失败
- `exploratory_path_miss`：探索性路径尝试未命中
- `edit_match_ambiguity`：`Edit` 因匹配不唯一、old/new 相同等引发的编辑定位问题
- `session_context_noise`：由 hook / summary / injected payload 造成的非真实任务信号
- `cross_project_session`：当前项目请求与实际 session 项目不一致

### 7.2 测试失败识别

对 `Bash` 命令按以下逻辑降噪：

- 若命令明显是测试命令（如包含 `test`、`vitest`、`bun test`）
- 且前后文显示处于 TDD/红灯阶段
- 则将失败归类为 `expected_test_failure`
- 该类失败应保留计数，但不进入高严重度 repeated failure，也不触发泛化的 Bash 质量建议

### 7.3 trigger 检测净化

`missed_triggers` 只基于真实用户输入判断，不使用以下消息源：

- stop hook feedback
- resumed conversation summary
- skill 的原文注入内容
- command wrapper 元信息

这样可以把“分析系统自身注入的文本”与“用户真实表达的需求”分开。

### 7.4 duration / efficiency 处理

- 保留原始 duration 字段
- 若检测到续聊、loop、summary 注入等情况，则将效率解释标记为 `distorted`
- 在 markdown 报告中提示“该时长不宜直接用于效率判断”
- 不基于此类 session 自动生成效率改进建议

### 7.5 recommendation 聚合

recommendation 生成按“根因桶”而不是按“单条失败”聚合。预期输出 3-6 条高质量建议，避免：

- 同一类 Bash 建议重复出现
- 分类不同但动作相同的建议并列堆叠
- 报告结尾变成无优先级的流水账

## 8. 报告层设计

报告顶部新增一个“Session Provenance”区块，展示：

- 请求分析的项目
- 实际命中的 session 文件
- 实际 session 所属项目目录
- 是否经过 fallback 查找

在 Issues 区块中，将问题按三类展示：

1. 已确认问题
2. 降噪后的观测项
3. 候选 skill 问题（证据不足，待复核）

这样可以避免“所有条目看起来都一样严重”。

## 9. 验证方案

### 9.1 回归样本

至少用这次会话重新分析一次，作为主回归样本：

- `ac3a4a38-1ae1-4fcc-901d-929eef8e7661`

### 9.2 重点验证项

重新生成报告后，需要人工确认：

1. `Bash failed 52 times` 不再以高严重度直接出现。
2. `systematic-debugging 未触发` 若仅由 hook/summary 支撑，应消失或降级为不确定候选项。
3. 报告明确写出该 session 来自 `hapi` 项目。
4. recommendation 数量减少，并且无重复。
5. 若仍出现“建议修改 skill”，必须能指出具体、干净的证据来源。

### 9.3 验收结论

只有在重新分析后的报告仍能稳定指向某个具体 skill 时，才进入下一轮 skill 改造讨论。否则，本轮工作视为“分析器可信度修复完成”。

## 10. 实施优先级

### P0

- 噪音消息过滤
- TDD 预期失败识别
- session provenance 展示
- recommendation 去重

### P1

- Read / Edit 探索性失败分类
- duration / efficiency 降权

### P2

- 基于修正后的报告再评估 `systematic-debugging` 等 skill 是否要改

## 11. 风险与取舍

### 风险 1：降噪过度，掩盖真实问题

如果规则过于激进，可能把真实失败误当成“预期失败”。因此设计上不删除原始失败记录，只改变其分类和报告优先级。

### 风险 2：消息来源判断仍然不稳定

某些 injected 文本可能格式多变。因此提取层和分析层都需要容忍“不确定”状态，而不是强制二分类。

### 风险 3：单会话样本过少

本次设计以一个会话为主要驱动样本，因此最终实现后应至少再找一两个不同类型会话做 spot check，防止规则只对当前样本有效。

## 12. 后续计划边界

本设计完成后，下一步应进入 implementation plan，而不是直接修改 skill 文案。实现计划应聚焦：

1. `extract-session.py` 需要新增哪些字段和判定逻辑
2. `analyze-session.py` 需要怎样重构分类与 recommendation 聚合
3. 如何用这个 session 做回归验证
4. 在何种条件下，才继续改某个具体 skill
