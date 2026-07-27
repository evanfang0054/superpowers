# Sprint Contract: domain-modeling

## Outcome Statement

当用户在项目（如 standard-benefit-fe）中运行 agent-harness 做 brainstorming 时，领域术语自动沉淀到根目录 `CONTEXT.md`，跨会话持久。每个新会话启动时 agent 已知项目领域词汇，用精确术语而非每次重新推导 jargon。难逆转的架构决策被捕获为 ADR 存入知识库，防止未来 agent 重新质疑已定决策。

## Definition of Done

### 核心组件

- [ ] `skills/domain-modeling/SKILL.md` 存在，frontmatter 含 `name: domain-modeling`、`description`（非空，≤500 字符，以 "Use when..." 或等价触发短语开头）、`when_to_use`，且**不含** `disable-model-invocation: true`（保持 model-invoked）
- [ ] `skills/domain-modeling/SKILL.md` body 含以下具名 section：File structure / During-session behaviors（6 项：challenge / sharpen / scenarios / cross-reference / update inline / offer ADRs sparingly）/ CONTEXT.md format / ADR format / Integration points
- [ ] `hooks/session-start` 读取项目根 `CONTEXT.md`（若存在），提取 `##` heading + 首行定义，注入到 `static_context` 变量的 `## Domain Glossary` 段；注入代码在 learnings 读取代码**之前**执行
- [ ] `hooks/session-start` 当 CONTEXT.md 含 >20 个 `##` heading 时，截断到前 20 + 指针文案（含 "see CONTEXT.md" 字样）
- [ ] `hooks/session-start` 当项目根无 CONTEXT.md 时，不注入 `## Domain Glossary` 段，hook 退出码仍为 0
- [ ] `skills/harness-init/SKILL.md` 流程含：问 "Create a domain glossary (CONTEXT.md)?"，选 y 则创建 `CONTEXT.md`（内容含 `# <Project> Domain Glossary` + HTML comment 说明用法）+ 创建 `docs/agent-harness/adr/.gitkeep`；问 "Add CONTEXT.md to .gitignore?"，选 y 则追加到 `.gitignore`
- [ ] `scripts/lib/handoff-schema.sh` 在 `handoff_check_required` 函数中，当 stage=spec 且 frontmatter 含 `domain_terms` 字段时，逐个检查 term 是否为 CONTEXT.md 的 `##` heading；不在则打 WARNING 到 stderr；**不改变函数返回值**（advisory，退出码仍由现有必填字段校验决定）
- [ ] `skills/brainstorming/SKILL.md` 澄清环节 checklist 第 2 项含调用 domain-modeling 的指令文本（含 "domain-modeling" 字样）
- [ ] `docs/agent-harness/index.md` 主题速查段含 `- domain-modeling →` 锚点（已完成）

### 测试覆盖（映射 GDD assertions）

- [ ] `tests/plugin-infrastructure/` 新增以下 5 个 test case，全部通过：
  - `test-harness-init-creates-context-md`
  - `test-harness-init-gitignore-option`
  - `test-session-start-injects-context-md`
  - `test-validate-handoff-domain-terms-advisory`
  - `test-index-knowledge-base-adr`
- [ ] `tests/skill-behavior/domain-modeling/run-test.sh` 存在且可执行（`ls -la` 显示 `-rwxr` 或 `chmod +x` 通过）
- [ ] 现有 `tests/plugin-infrastructure/run-all.sh` 全部通过（无回归）
- [ ] 现有 `tests/handoff-scripts/run-all.sh` 全部通过（无回归）
- [ ] 现有 `tests/knowledge-base-scripts/run-all.sh` 全部通过（无回归）

### 手动验证（PR 描述中提交结果）

- [ ] 在 `demo/fruit-shop` 跑 brainstorming 一个小 feature，验证 CONTEXT.md 被更新（≥1 新 `## <Term>` heading + `_Avoid_` 别名行）
- [ ] 在 `demo/fruit-shop` 启动新会话，验证 session-start hook 输出含 `## Domain Glossary` 段
- [ ] `scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-07-21-domain-modeling-design.md` 退出码 0（已验证）

## Boundary Conditions

- Must support: Claude Code / Cursor / Codex 三平台（session-start hook 已有多平台分支，CONTEXT.md 注入须走相同分支逻辑，不硬编码单平台路径）
- Must not break: 现有 session-start hook 行为（learnings 注入、KB pointer、subagent 检测、precompact 恢复点）
- Must not break: 现有 validate-handoff 对无 `domain_terms` 字段的 spec 仍 exit 0（advisory 不改退出码）
- Must not break: 现有 `index-knowledge-base.sh` 对现有 spec_topic（非 adr）的索引行为
- Performance: CONTEXT.md 注入 ≤ 20 term + pointer（防止 token 超预算）
- Performance: prompt cache 稳定性不退化（CONTEXT.md 注入在静态段，issue #79）

## Acceptance Criteria

- Computational: `tests/plugin-infrastructure/run-all.sh` exit 0
- Computational: `tests/handoff-scripts/run-all.sh` exit 0
- Computational: `tests/knowledge-base-scripts/run-all.sh` exit 0
- Computational: `grep -c "disable-model-invocation" skills/domain-modeling/SKILL.md` = 0（model-invoked）
- Computational: `grep "domain-modeling" skills/brainstorming/SKILL.md` 命中（brainstorming 调用点存在）
- Inferential: PR diff 由人类审查（CLAUDE.md 核心贡献规则 #5）
- Inferential: brainstorming 改动按 CLAUDE.md "Skill 改动需要评估" 要求提供 before/after 评估（至少在 demo/fruit-shop 跑一次对比）

## Negotiation Record

### Round 1 — Generator initial proposal

初始 DoD 含 15 条 criteria：6 个核心组件（SKILL.md / hook / harness-init / validate-handoff / brainstorming / index.md）+ "所有 GDD L1-L4 assertions pass" + 5 个 test case + 现有套件无回归 + 3 项手动验证。

### Round 1 — Evaluator challenges

1. "model-invoked frontmatter" 是 jargon，不可测 → 需改为具体字段列表（name/description/when_to_use + 不含 disable-model-invocation）
2. "documented in SKILL.md body" 模糊 → 需指向具名 section（File structure / During-session behaviors 等）
3. "docs/agent-harness/adr/ directory exists" 混淆插件源 vs 每项目 → 插件源不创建 adr/，由 harness-init 在每项目创建
4. "static segment" 如何验证 → 改为 "注入到 static_context 变量 + 在 learnings 之前执行"
5. "scaffold" 需具体内容 → 指定 `# <Project> Domain Glossary` + HTML comment
6. "when terms crystallize" 主观（spec self-review 已标注）→ 改为 "brainstorming SKILL.md 含调用指令文本" + grep 验证
7. "所有 GDD assertions pass" 循环（GDD 定义测试，DoD 说测试 pass）→ 拆为 5 个具名 test case + 3 个现有套件
8. "manual test" 不是 gate → 改为 PR 描述中提交结果的可选验证，含具体检查项
9. "harness-init asks gitignore" 需指定行为 → 选 y 则追加到 .gitignore

### Round 2 — Generator revised

按 challenges 修订：每条 criterion 改为 yes/no 可测问题。测试覆盖明确映射 5 个具名 test case。Boundary conditions 含三平台支持 + 4 项无回归约束。Acceptance criteria 含 5 个 computational（脚本套件 + grep）+ 2 个 inferential（人类审查 + skill 评估）。

### Round 2 — Evaluator accepts

所有 criterion 可测、无歧义、无循环。Boundary conditions 覆盖三平台 + 无回归。Acceptance criteria 含 computational + inferential 两维。接受。

## Out of Scope

- grilling skill（P0-3，后续独立 brainstorming → spec → PR）
- two-axis review（P0-2，后续独立 brainstorming → spec → PR）
- domain_terms advisory 升级为 block（需社区反馈，后续独立 PR）
- CONTEXT.md 语义检索 / embedding（需外部服务，永久 out of scope）
- demo/fruit-shop 的 CONTEXT.md 实际内容（由 demo 项目自身维护，非本 PR 职责）
- 多 context（CONTEXT-MAP.md）的 skill-behavior 测试（spec 文档化，测试暂只覆盖单 context）
