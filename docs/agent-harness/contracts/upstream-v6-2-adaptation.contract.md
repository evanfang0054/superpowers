# Sprint Contract: 上游 v6.2.0 适配

## Outcome

用户完成本次适配后，可以在不失去 Agent Harness 自有工作流的前提下，获得 Superpowers v6.2.0 已验证的稳定性修复与 SDD 能力：测试污染定位不再漏匹配，计划之间的 SDD artifacts 不会相互恢复或覆盖，review finding 的修复会有明确的收敛上限和人工阻塞出口。用户仍默认在独立分支实施工作；只有明确要求时才使用 worktree，且现有 Ralph Loop、多平台 hooks、双轴 review 和质量门禁不会被上游同步覆盖。

## Definition of Done

- [ ] `find-polluter.sh` 保持两个位置参数，并正确处理 `src/**/*.test.ts`、`./src/**/*.test.ts`、零层匹配和无匹配结果；无匹配时报告 0。
- [ ] Claude Code 的现有 SessionStart hook 条目包含 `"shell": "bash"`，且 PreToolUse、SubagentStop、Stop 和现有 Codex hook 配置保持存在。
- [ ] `test-helpers.sh` 的 prose assertions 不区分大小写，`assert_order` 在 pattern 缺失时显示完整被测输出；现有 timeout portability 仍可用。
- [ ] `sdd-workspace PLAN_FILE` 只接受存在的 plan 文件，输出 `.agent-harness/sdd/<plan-basename>`；根 `.agent-harness/sdd/.gitignore` 为 `*`。
- [ ] `task-brief PLAN_FILE TASK_NUMBER [OUTFILE]` 和 `review-package PLAN_FILE BASE HEAD [OUTFILE]` 的默认 artifacts 均写入对应计划工作区；review package 保留完整 `BASE..HEAD` 范围。
- [ ] 每个计划的 `progress.md` 首行绑定 plan 身份；身份不符的 ledger 不会被恢复。
- [ ] SDD 提供 `re-review-prompt.md`；修复复审仅处理 `FIX_BASE..HEAD`、原 open findings 和 fix 引入的新 Critical/Important breakage。
- [ ] 修复循环遵守五轮上限：第 1–3 轮优先 resume，第 4–5 轮使用 fresh 且能力至少高一档的 implementer；第五轮后非承重 finding 记录停驻裁决，承重 finding 记录 BLOCKED 并停止当前 plan 后续派发。
- [ ] final whole-branch review 使用 `review-package PLAN_FILE MERGE_BASE HEAD`；最终 finding 只允许一波 fixer 和一次 scoped re-review。
- [ ] 仅当 final review clean 且修复已在当前实现分支时，删除当前计划 workspace；PR / Keep 不会无条件删除活跃计划的 ledger 或 artifacts。
- [ ] finishing 的正常菜单不列出 discard；用户明确请求 discard 时才进入精确 `discard` 确认。worktree cleanup 只作用于已捕获且位于 `.worktrees/` 或 `worktrees/` 的项目拥有目录。
- [ ] 实施默认在用户指定分支或新建独立分支上进行；仅用户明确要求时创建或使用 worktree。
- [ ] TDD 的任意测试写作会按需加载 `writing-good-tests.md`；该 reference 覆盖 production break、真实行为、独立 expected value、非 source-text 测试和 Mutation Check，同时保留 seam-first 规则。
- [ ] review 保持 Standards / Spec 双轴，并禁止把完整 coordinator session history 或 inline review diff 交给 reviewer。
- [ ] 仅迁移上游已核验的 prose 去重或规则就近调整；不删除 frontier brainstorming、GDD、sprint contract、Interfaces、computational sensors、loop detection、phase metrics、learnings、Gemini 支持、Codex hooks 或 fork 品牌配置。
- [ ] 每个修改的 skill 具备已记录的 baseline / pressure scenario 证据，且运行适用的 headless 行为测试；无法运行时记录真实环境或配额失败。

## Boundary Conditions

- Must support: `PLAN_FILE` 的 basename 规则与上游一致，不增加 hash、路径编码或声称解决同名 plan 冲突。
- Must support: SDD workspace、ledger、brief、report、review package 在 `.agent-harness` 根下保持同一计划边界。
- Must support: final review 和 finishing 的 workspace cleanup 是不同生命周期步骤，不能混为一个无条件 cleanup。
- Must not break: Ralph Loop 的完成信号、BLOCKED 人工介入语义、既有 prompt 路径规则和 `CRITICAL BOUNDARIES`。
- Must not break: 当前多平台配置，尤其 Codex SessionStart hook 与 Gemini 支持策略。
- Must not break: 当前未提交的 `skills/brainstorming/SKILL.md` 内容；若该文件纳入改动，须在最终 diff 中保留并审阅用户已有变更。
- Must not break: 未明确请求时不使用 worktree 的协作偏好。
- Performance: 不新增第三方依赖；只把高频操作规则留在 SKILL.md，长篇 TDD 细节置于按需 reference。

## Acceptance Criteria

- Computational: `scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-07-29-upstream-v6-2-adaptation-design.md` 通过。
- Computational: 运行 `tests/systematic-debugging/test-find-polluter.sh`、受影响的 SDD workspace / finishing contract 测试、hook / plugin-infrastructure 测试，并报告真实结果。
- Computational: 运行 `tests/claude-code/run-skill-tests.sh` 或受影响的单测；运行受影响 skill 的 `tests/skill-behavior/<skill>/run-test.sh`。无法运行的 headless 测试必须记录实际原因。
- Computational: `git diff --check` 通过，且所有新增/修改脚本通过相应 shell 语法或项目既有确定性测试。
- Inferential: 按 Standards / Spec 双轴审查最终 diff，确认每项上游来源的适配没有被误写为上游原样实现。
- Inferential: 人工检查完整 diff，确认未引入 marketplace、porting guide、manifest / 品牌同步、visual companion、Codex hooks 移除或 Gemini 支持移除。

## Negotiation Record

### Round 1

- Generator: 初始 DoD 按稳定性补丁、计划专属 SDD 工作区、五轮修复闭环、finishing 生命周期、TDD/review 规则和分阶段验证列出要求。
- Evaluator: 初稿有四个歧义：一是 workspace cleanup 的“已合入”可能误解为必须合入 main；二是 PR / Keep 与 SDD artifact 生命周期未分开；三是默认分支隔离与 worktree 的用户偏好缺少可判定标准；四是 skill 文案改动未强制 baseline / pressure scenario 证据。

### Round 2

- Generator: 将 cleanup 收紧为“final review clean 且修复已在当前实现分支”，明确 PR / Keep 不触发活跃 ledger cleanup；将隔离规则写为“用户指定分支或新建独立分支，只有明确请求时使用 worktree”；将 baseline / pressure scenario 和 headless 运行证据加入 DoD。
- Evaluator: 仍有三处边界需固定：计划目录必须明确沿用 basename 的已知冲突边界；上游最终 Codex/Gemini 状态不能被流程同步误覆盖；用户已有 brainstorming 未提交变更需要受保护。

### Round 3

- Generator: 在 Boundary Conditions 中固定 basename 规则、不虚称同名冲突已解决；明确保护 Codex hook / Gemini 策略；将 brainstorming 现有未提交改动纳入最终 diff 审阅约束。
- Evaluator: 接受。所有 criteria 均可由脚本输出、文件内容、headless 结果或双轴 review 判定。

## Final Consensus

本 sprint 完成的定义是：通过按能力三方适配，而非机械合并，将已核验的 Superpowers v6.2.0 稳定性、SDD、finishing、TDD/review 行为引入 Agent Harness；每项都有确定性或 headless 证据，且不回退本项目的品牌、多平台策略、Ralph Loop、质量门禁和默认独立分支工作流。
