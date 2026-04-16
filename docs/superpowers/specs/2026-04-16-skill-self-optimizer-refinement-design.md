# Skill Self-Optimizer 精准修复设计

- 日期：2026-04-16
- 主题：修复 `harness-optimizerr` 在 session 定位、失败聚合和建议生成上的误报问题，并同步测试与文档
- 相关输入：`.superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661-report.md`

## 1. 背景

当前 `harness-optimizerr` 已能提取 Claude Code 历史会话并生成分析报告，但在本次样本中暴露出四个直接影响可用性的问题：

1. 用户提供的 session id 少一位时，`extract-session.py` 只能精确匹配，导致直接报错。
2. `analyze-session.py` 会把 TDD 红灯阶段的预期测试失败混入高严重度 `repeated_failures`。
3. repeated failure 目前主要按工具名聚合，导致报告出现类似 “Bash failed 52 times” 的粗粒度噪音，无法指向真实根因。
4. 报告建议过于泛化，缺少“该改哪个层级”的可执行指向；同时 `SKILL.md` 的说明与期望行为已经不完全一致。

本轮目标是让这个 skill 的输出更可靠、更可执行，而不是扩展分析范围。

## 2. 目标与非目标

### 2.1 目标

本轮实现完成后，系统应满足：

1. `extract-session.py` 支持 session id 前缀匹配。
2. 当精确匹配失败且前缀匹配只有一个候选时，自动命中该 session。
3. 当存在多个前缀候选时，给出清晰候选列表，提示用户补全 id。
4. `expected_test_failure` 保留统计，但不再进入高严重度 repeated failure 模式。
5. repeated failure 按 failure category 聚合，而不是只按工具名聚合。
6. recommendation 文案能直接指向 path / wrapper / edit 匹配歧义 / TDD 红灯等更具体的修复方向。
7. `tests/test_session_optimizer.py` 新增对应回归测试。
8. `SKILL.md` 与新行为保持一致。

### 2.2 非目标

以下内容不在本轮范围：

- 不修改其他 skill 的触发逻辑或内容。
- 不引入新的分析维度或评分体系。
- 不重构 `harness-optimizerr` 的整体架构。
- 不新增独立测试文件；沿用现有 `test_session_optimizer.py`。

## 3. 方案选型

### 方案 A（推荐）
同时修改脚本、测试与 `SKILL.md`。

优点：
- 行为、回归测试、文档一次对齐。
- 能完整修复本次暴露的使用断点。
- 后续维护成本最低。

缺点：
- 改动面比只修脚本略大，但仍集中在单一 skill 内。

### 方案 B
只修脚本和测试，文档做最小补丁。

优点：
- 改动更小。

缺点：
- 文档仍可能保留旧表述，用户继续按旧说明使用会再次踩坑。

### 方案 C
先修脚本/测试，文档后置。

优点：
- 变更节奏最保守。

缺点：
- 不符合这次“连文档一起修”的目标。

### 结论

采用 **方案 A**：脚本、测试、文档同步修复。

## 4. 设计细节

### 4.1 Session 定位

修改 `extract-session.py` 的 session 查找逻辑，采用两阶段匹配：

1. 先在候选项目目录中做精确匹配：`<session-id>.jsonl`
2. 若未命中，再做前缀匹配：`<session-id>*.jsonl`

前缀匹配结果处理：
- 0 个候选：保持 not found
- 1 个候选：直接返回该 session 文件
- 多个候选：返回明确的歧义信息，包含候选路径或候选 session id 列表

约束：
- 仍保留 `requested-project` / `fallback-global-search` 等 provenance 信息
- 不做模糊包含匹配，只做前缀匹配，避免误命中过宽

### 4.2 repeated failure 聚合

修改 `analyze-session.py` 中 failure 聚合与模式检测逻辑。

新的原则：
- failure 统计与 repeated failure 模式分开处理
- repeated failure 以 `failure category` 为主进行聚合
- 必要时保留 `tool` 作为补充上下文，但不再单靠工具名下结论

预期输出从：
- `Bash failed 52 times with consecutive failures`

改成更接近：
- `missing_resource repeated 5 times`
- `shell_wrapper_failure repeated 3 times`
- `edit_match_ambiguity repeated 4 times`

### 4.3 expected_test_failure 降噪

`expected_test_failure` 的处理规则：
- 保留在 failure 明细里，方便读者看到 TDD 红灯信号确实存在
- 不计入高严重度 repeated failure
- 不驱动通用型 “Bash 需要 pre-flight validation” 建议
- 在报告里明确标记为 TDD 红灯 / 测试验证阶段噪音

### 4.4 suggestion 文案细化

为主要 failure category 提供更具体的修复建议：

- `missing_resource`
  - 检查 file / session / project path
- `shell_wrapper_failure`
  - 检查 shell wrapper、模板插值或包装脚本路径
- `skill_shell_wrapper_failure` / `skill_orchestrator_wrapper_failure`
  - 优先检查 skill wrapper 模板和 skill 启动脚本
- `edit_match_ambiguity`
  - 扩大替换上下文、唯一化匹配片段，必要时使用 `replace_all`
- `expected_test_failure`
  - 单独统计，不作为高严重度执行失败

### 4.5 文档同步

更新 `SKILL.md` 的以下部分：

1. Session 提取步骤：补充前缀匹配和歧义候选说明
2. 问题模式识别：把 “同一工具连续失败 3+ 次” 改为更贴近实际的 failure category 聚合表述
3. 报告示例：体现 `expected_test_failure` 单独统计，以及更具体的 suggestion
4. Quick Reference / 注意事项：强调 session id 不完整时的处理行为

## 5. 测试设计

沿用 `skills/harness-optimizerr/tests/test_session_optimizer.py`，新增失败测试覆盖：

### 5.1 extract-session.py

1. 精确匹配失败，但唯一前缀候选存在时成功命中
2. 前缀匹配命中多个候选时返回歧义信息

### 5.2 analyze-session.py

1. `expected_test_failure` 不进入高严重度 repeated failure 模式
2. repeated failures 按 category 聚合，而不是只按工具名聚合
3. `edit_match_ambiguity` 等具体类别能给出更具体 suggestion

### 5.3 文档同步

不对 `SKILL.md` 做脆弱的全文快照测试；文档通过实现后人工 review 保证一致性。

## 6. 实施顺序

1. 先补 `extract-session.py` 的失败测试
2. 运行测试，确认红灯
3. 实现 session 前缀匹配与歧义提示
4. 再补 `analyze-session.py` 的失败测试
5. 运行测试，确认红灯
6. 实现 failure category 聚合与 `expected_test_failure` 降噪
7. 更新 `SKILL.md`
8. 跑相关测试，确认全绿

## 7. 风险与取舍

### 风险 1：前缀匹配命中过宽

通过“只接受唯一前缀候选，多候选直接报歧义”控制风险。

### 风险 2：降噪过度，掩盖真实测试失败

通过“保留 failure 明细，但不进入高严重度 repeated failure”控制风险。

### 风险 3：建议文案过细，导致维护负担上升

只对当前稳定可识别的 failure category 给出定制 suggestion；未知类别仍回退到通用建议。

## 8. 验收标准

本轮完成后，至少应满足：

1. 给定缺尾缀的 session id 时，唯一前缀候选可被成功提取。
2. 多候选前缀冲突时，错误信息能帮助用户补全 id。
3. 重新分析类似会话时，不再出现把 `expected_test_failure` 误报成高严重度 repeated Bash failure 的情况。
4. 报告中的 recommendation 更少、更具体、无明显重复。
5. `SKILL.md` 的说明与脚本真实行为一致。
