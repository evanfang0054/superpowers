# Sprint Contract: brainstorming-to-questionnaire

**Spec:** docs/agent-harness/specs/2026-08-07-brainstorming-to-questionnaire-design.md
**Date:** 2026-08-07

## Outcome (user-visible)

当 brainstorming 追问到一个我答不了的决策时(比如"这个手续费率要问财务"),brainstorming 不再强行逼我假设一个值、也不再 skip 这个问题,而是当场帮我生成一份 Markdown 问卷(写明给谁、需要拿回什么、每个问题用 ❓/➡️ 标注),保存到 `docs/agent-harness/handoffs/to-<recipient>-<slug>.md`,然后暂停那个 frontier 节点等我去找人填。回来填完,brainstorming 继续推进。同时,它在 frontier 还没空时再也不会跳过追问直接给方案。

## Definition of Done

- [ ] SKILL.md 包含精确字符串 "MUST NOT proceed to Propose approaches"(frontier 硬规则)
- [ ] SKILL.md 包含精确字符串 "When the user cannot answer a frontier question (to-questionnaire escape hatch)"
- [ ] SKILL.md 包含精确字符串 "Grill the send, not the subject"
- [ ] SKILL.md 包含精确字符串 "If you're unsure whether the user can answer, ask them directly"
- [ ] docs/agent-harness/index.md 包含精确字符串 "- [handoffs/](handoffs/)"
- [ ] docs/agent-harness/handoffs/.gitkeep 存在
- [ ] tests/skill-behavior/brainstorming/prompts/ 下存在 frontier-hard-rule.txt、to-questionnaire-trigger.txt、no-speculative-trigger.txt
- [ ] tests/skill-behavior/brainstorming/run-test.sh 引用上述三个场景名
- [ ] cd tests/claude-code && ./run-skill-tests.sh 退出码 = 0
- [ ] 改后 behavior 测试:场景 1 输出含 "frontier";场景 2 在 docs/agent-harness/handoffs/ 创建 .md 文件且内容含 "❓" 和 "➡️";场景 3 不创建该目录下任何文件

## Boundary Conditions

- Must support: brainstorming 现有 frontier round 编号风格、Assumption Audit、Circuit-Breaker、Six Forcing Questions、domain-modeling 触发
- Must not break: tests/claude-code/run-skill-tests.sh 加载、tests/skill-behavior/brainstorming/ 现有 4 场景通过、validate-handoff.sh spec stage
- Performance: SKILL.md 净增长 < 80 行(避免 prompt 膨胀抵消收益)
- 不可引入新依赖、新 slash command、新 plugin manifest 项、新 handoff schema 字段

## Acceptance Criteria

- Computational: grep 静态校验上述 4 条精确字符串;test -f 校验文件存在;run-skill-tests.sh 退出码 = 0
- Inferential: PR 描述贴场景 1/2/3 改前/改后输出对比,人工审阅 frontier 终止、问卷触发、不滥触发三条行为符合预期

## Negotiation Record

- Generator: 初版 8 条 DoD(基于 spec 改动清单 + 测试落地)
- Evaluator round 1: 8 条全部挑战(过宽、模糊、缺退出码),全部接受并精化
- Evaluator round 2: 7-8 调整 run-test.sh 断言粒度(放给 plan),新增第 10 条 behavior 通过判据
- Final consensus: 10 条 DoD + 4 类 boundary + computational/inferential 双轴
