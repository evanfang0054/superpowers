# Sprint Contract: Matt Pocock Skills Adaptation

## Outcome

用户在后续实现完成后，可以继续使用 agent-harness 的现有开发链路，但四个关键 skill 会更稳定地产生高质量行为：TDD 会先找可观察 seam，review 会分开检查代码标准和 spec 符合度，planning 会产出可验证的 vertical slices 与显式依赖，writing-skills 会更关注行为可预测性和 prompt 负载。用户不需要学习一套新的外部 workflow，也不会看到 mattpocock/skills 被整仓复制进项目；这些借鉴点会自然融入现有 harness。

## Definition of Done

- [ ] `skills/test-driven-development/SKILL.md` 明确要求写失败测试前先选择 observable seam，并定义 seam 为 public 或 agreed boundary。
- [ ] `skills/test-driven-development/SKILL.md` 明确禁止为了测试创建 test-only public APIs，并保留现有 failing-test-first 硬门禁。
- [ ] `skills/requesting-code-review/SKILL.md` 明确 review 必须覆盖 Standards axis 与 Spec axis，且任一轴有 Critical finding 都不能通过。
- [ ] code-reviewer 子代理提示要求输出 `Standards findings`、`Spec findings`、`Verdict` 或等价结构，并继续支持 Critical / Important / Minor 严重级别。
- [ ] `skills/writing-plans/SKILL.md` 明确 feature work 优先 tracer-bullet vertical slices，而不是默认水平切片。
- [ ] `skills/writing-plans/SKILL.md` 要求显式声明 blocking edges，并为 TDD 任务提供 `Seam` 或等价 seam 描述。
- [ ] `skills/writing-plans/SKILL.md` 对宽重构说明 expand-contract 路径，避免把 refactor 伪装成普通 feature slice。
- [ ] `skills/writing-skills/SKILL.md` 明确 skill 优化目标是 pressure scenarios 下的 predictable behavior，而不是润色文案。
- [ ] `skills/writing-skills/SKILL.md` 明确区分 model-invoked context load 与 user-invoked cognitive load。
- [ ] `skills/writing-skills/SKILL.md` 包含 progressive disclosure、no-op pruning、leading words 的可执行准则。
- [ ] 改动不新增第三方依赖，不复制 mattpocock/skills 整仓，不修改 plugin hooks、release 配置或 demo 项目。
- [ ] 至少运行一个适用 harness 验证；若新增或修改行为测试，则运行对应 `tests/skill-behavior/<skill>/run-test.sh`。
- [ ] 快速 skill 加载测试 `tests/claude-code/run-skill-tests.sh` 通过，或若因环境/API 配额失败，记录真实失败原因。

## Boundary Conditions

- Must support: 现有 `brainstorming → sprint-contract → writing-plans → SDD/TDD/review/verification` 主流程不变。
- Must support: 四项 P1 增强均以最小 skill 文案或 reviewer prompt 契约修改实现。
- Must support: 后续 implementation plan 能把四项增强拆成独立、可验证任务。
- Must not break: `brainstorming` 已有 frontier batching、recommended answers、facts-vs-decisions、domain-modeling 触发规则。
- Must not break: `writing-plans` 现有 spec frontmatter、GDD、sprint-contract、validation 交接规则。
- Must not break: `test-driven-development` 现有 Red-Green-Refactor 硬纪律。
- Must not break: `requesting-code-review` 现有 Critical / Important / Minor 修复优先级。
- Must not break: `writing-skills` 现有 RED baseline → GREEN minimal prompt change → REFACTOR pressure test 流程。
- Performance: 不引入运行时代码路径或依赖；prompt 增量应保持局部、短小，避免长篇外部资料塞入 always-loaded skill。

## Acceptance Criteria

- Computational: `scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-07-22-mattpocock-skills-adaptation-design.md` 已通过。
- Computational: `tests/claude-code/run-skill-tests.sh` 在实现后运行并报告结果。
- Computational: 对新增/修改的 skill behavior tests，运行相应 `tests/skill-behavior/<skill>/run-test.sh` 并报告结果；若测试目录不存在，implementation plan 必须明确新增或复用的测试路径。
- Inferential: 对最终 diff 做人工 review，确认只覆盖 spec 中四项 P1 增强，没有引入 P2/P3 范围。
- Inferential: review 输出必须能按 Standards / Spec 两轴判断是否满足本 contract。

## Negotiation Record

### Round 1

- Generator: 初始 DoD 覆盖四个目标 skill：TDD seam-first、code review 双轴、writing-plans vertical slices/blocking edges、writing-skills predictability/load rules；同时要求不新增依赖、不复制外部仓库、运行 skill 加载测试。
- Evaluator: 初始 DoD 仍有三处模糊：一是 reviewer prompt 的具体输出结构不够可验证；二是 writing-plans 与 TDD 的 seam 交接没有明确字段；三是测试要求没有说明行为测试目录不存在时怎么办。

### Round 2

- Generator: 修订 DoD，加入 reviewer 输出必须包含 `Standards findings`、`Spec findings`、`Verdict` 或等价结构；加入 writing-plans 必须输出 `Seam` 或等价 seam 描述；加入如果 skill behavior test 目录不存在，implementation plan 必须明确新增或复用测试路径。
- Evaluator: 修订后 criteria 均为 yes/no 可判断，但仍需防止范围漂移到 Wayfinder、research、architecture report 或 hook/plugin 改动，因此要求 Boundary Conditions 明确禁止 P2/P3 和基础设施改动。

### Round 3

- Generator: 增加 Boundary Conditions：只做四项 P1；不修改 `brainstorming`、plugin hooks、release 配置或 demo；不改变主流程；prompt 增量保持短小。
- Evaluator: 接受。Final DoD 可以用于 writing-plans，且每项 criteria 都能通过文件 diff、测试输出或 review 判断。

## Final Consensus

本 sprint 完成的定义是：把 mattpocock/skills 的四项已选实践以最小、可验证、适配 agent-harness 的方式嵌入现有四个 skill/reviewer 契约中；保留现有工作流和门禁；不扩展到 P2/P3；最终通过结构验证、skill 加载验证、相关行为测试或真实失败记录，以及双轴人工 review。
