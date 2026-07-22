# Sprint Contract: brainstorming-optimization

## Outcome Statement

当用户使用优化后的 `brainstorming` skill 时，需求澄清阶段不再被迫 15-20 轮单问单答，而是按决策树前沿分批提问，并为每个决策问题给出带理由的推荐答案。用户只需要回答真正需要人判断的决策；项目结构、现有 API、配置和代码模式等事实由 agent 自己查证。优化后应减少来回次数和 prompt 负载，同时保留 agent-harness 现有的 spec 校验、GDD 门禁、sprint contract、domain-modeling 和 learnings 集成。

## Definition of Done

### Brainstorming 行为改造

- [ ] `skills/brainstorming/SKILL.md` 的澄清问题规则明确使用 **frontier / decision tree / rounds**：每轮询问所有先决条件已满足的问题，等待用户回答后重新计算下一轮 frontier。
- [ ] `skills/brainstorming/SKILL.md` 删除或改写与批次提问冲突的规则，包括 "ask questions one at a time"、"Only one question per message"、`Key Principles` 中的 `One question at a time`。
- [ ] 每个 frontier 问题必须要求附带推荐答案和理由；文案明确用户可以接受、修改或否决推荐答案。
- [ ] `skills/brainstorming/SKILL.md` 明确区分 **facts** 与 **decisions**：facts 由 agent 通过文件/工具/子代理查证，不问用户；decisions 才问用户。
- [ ] fact 查证规则明确支持非阻塞并行：后台查证未完成时，只阻塞依赖该 fact 的问题，其余 frontier 问题照常提出。
- [ ] 复杂任务（至少 3 个决策维度）时，流程中包含可选的 decision tree 映射步骤；简单任务不强制显式展示树。

### 保留现有 Agent Harness 集成

- [ ] `<HARD-GATE>` 仍然存在，且仍禁止在用户批准设计前进入实现、写代码、脚手架或实现 skill。
- [ ] Checklist 仍包含：Explore project context、Ask clarifying questions、Propose approaches、Present design、Write design doc、Spec self-review、User reviews written spec、Transition to implementation。
- [ ] `domain-modeling` 调用规则仍存在，并仍要求 spec frontmatter 在适用时使用 `domain_terms` 字段。
- [ ] spec 写入路径、frontmatter 模板、`scripts/validate-handoff.sh --stage spec --file <spec-path>` 硬门禁仍存在。
- [ ] spec self-review 后的 `scripts/log-phase-metric.sh --phase brainstorming --action gate` 指标 emit 逻辑仍存在。
- [ ] GDD 可选门禁与 sprint-contract → writing-plans 的后续流程仍存在。
- [ ] Clarification Loop Circuit-Breaker（issue #83）仍存在，并与批次提问兼容：连续 3 次拒绝选项/推荐时停止继续列选项，改问 outcome question。
- [ ] Six Forcing Questions 仍存在，但只用于 product idea / major feature 的**决策类**问题，不要求用户回答 agent 可查证的事实。

### Prompt 精简

- [ ] 删除 `Key Principles` 段或将其中非冗余内容合并到对应流程段，避免保留与新规则冲突的原则。
- [ ] `Design for isolation and clarity` 不再作为长独立教导段；压缩为 1-2 句并合并到 design presentation 或 working-in-existing-codebases 相关位置。
- [ ] 删除被新规则替代的 `Prefer multiple choice questions` 类文案，避免同时存在“multiple choice preferred”和“recommended answer required”两套提问风格。
- [ ] 改动后的 `skills/brainstorming/SKILL.md` 行数少于改动前 257 行，且不新增外部依赖或辅助脚本。

### 测试与验证

- [ ] `tests/skill-behavior/brainstorming/run-test.sh` 运行完成并退出 0，或若因 Claude API/配额/环境原因无法运行，记录完整失败原因和命令输出。
- [ ] `tests/claude-code/run-skill-tests.sh` 运行完成并退出 0，或若因 Claude API/配额/环境原因无法运行，记录完整失败原因和命令输出。
- [ ] 至少执行一次静态检查，确认 `skills/brainstorming/SKILL.md` 不再包含精确短语 `Only one question per message` 和 `One question at a time`。
- [ ] 人类审查最终 diff，重点确认行为语义不是“把所有问题一次问完”，而是“只问当前 frontier”。

## Boundary Conditions

- Must support: Claude Code 插件加载方式，`skills/brainstorming/SKILL.md` frontmatter 保持有效。
- Must support: 已批准 spec 中定义的三类优化（A 前沿批次+推荐答案+事实分离、B decision tree 映射、C prompt 精简）全部落地在同一个 PR 范围内。
- Must not break: brainstorming 的设计审批硬门禁；不得让优化后的 skill 跳过用户批准直接实现。
- Must not break: agent-harness 知识库索引、spec frontmatter 校验、阶段指标记录、GDD 可选流程、sprint contract 流程。
- Must not break: issue #83 的 clarification loop circuit-breaker。
- Must not add: 第三方依赖、项目特定配置、与 brainstorming 无关的 skill 改动。
- Performance: prompt 文案净减少；目标是减少上下文负载，不用新增大段解释抵消精简收益。

## Acceptance Criteria

- Computational: `scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-07-21-brainstorming-optimization-design.md` exit 0。
- Computational: `tests/skill-behavior/brainstorming/run-test.sh` exit 0，或在结果中明确记录不可运行原因。
- Computational: `tests/claude-code/run-skill-tests.sh` exit 0，或在结果中明确记录不可运行原因。
- Computational: `grep -F "Only one question per message" skills/brainstorming/SKILL.md` 无命中。
- Computational: `grep -F "One question at a time" skills/brainstorming/SKILL.md` 无命中。
- Inferential: 人类审查确认 frontier batching、facts-vs-decisions、recommended answers 三者语义准确。
- Inferential: PR 描述包含 skill 行为改动的 before/after 评估证据，符合仓库 CLAUDE.md 的 Skill 改动要求。

## Negotiation Record

### Round 1 — Generator initial proposal

初始 DoD 包含 4 类完成标准：brainstorming 行为改造、保留现有 Agent Harness 集成、prompt 精简、测试验证。核心要求是把单问单答改为 decision tree frontier rounds，每个问题附推荐答案，facts 由 agent 查证，同时保留 HARD-GATE、spec 校验、GDD、sprint-contract、writing-plans、domain-modeling 和 loop circuit-breaker。

### Round 1 — Evaluator challenges

1. “批次提问”容易被误解为一次问完整棵树 → 必须明确只问当前 frontier，依赖未满足的问题进入后续 rounds。
2. “推荐答案”若只写 preferred option，仍可能退化为 multiple choice → 必须要求每个推荐附理由，且用户可接受/修改/否决。
3. “事实是 agent 的工作”若没有非阻塞规则，可能导致 agent 等子代理而停住 → 必须明确只阻塞依赖该 fact 的问题。
4. “prompt 精简”不可测 → 必须用改动前 257 行作为上限，并列出要删除/合并的冲突段。
5. “测试通过”对 headless skill behavior 可能受 API 配额影响 → 必须允许记录不可运行原因，但不能静默跳过。
6. “保留集成”太笼统 → 必须逐项列出 HARD-GATE、domain-modeling、validate-handoff、phase metric、GDD、sprint contract、loop circuit-breaker。

### Round 2 — Generator revised

修订后 DoD 将行为要求拆成 yes/no 条目：frontier/decision tree/rounds、删除冲突单问规则、推荐答案+理由、facts/decisions 分离、非阻塞查证、复杂任务 decision tree 映射。集成保留拆为 8 个具体验证项。Prompt 精简以删除冲突段、合并长教导段、行数少于 257 行为可测标准。测试接受 API/环境不可运行时记录完整原因。

### Round 2 — Evaluator accepts

所有 criteria 已可测且与 spec 一致。最大歧义点“批次提问不是一次问完整树”已通过 frontier 约束解决。测试标准既保留 computational gate，又处理 headless 行为测试的不稳定外部依赖。接受。

## Out of Scope

- 修改 `skills/productivity/grill-me`、`grilling` 或 Matt Pocock upstream 仓库。
- 为 brainstorming 新增第三方依赖、脚本 harness 或新子代理定义。
- 重写 agent-harness 的整体 brainstorming → planning 工作流。
- 修改 domain-modeling、sprint-contract、writing-plans、gate-driven-test-design 等其他 skill 的行为。
- 将 batch-grill-me 做成独立新 skill；本次只优化现有 `brainstorming`。
