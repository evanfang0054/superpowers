---
contract_topic: upstream-v6.2.0-sync
spec_ref: docs/agent-harness/specs/2026-07-27-upstream-v6.2.0-sync-design.md
agreed_at: 2026-07-27T00:00:00+08:00
gates: [outcome-defined, dod-negotiated]
---

# Sprint Contract: upstream-v6.2.0-sync

## User-Visible Outcome

同步完成后，我的 fork 在保留全部本地魔改（Fan-Out、auto-loop、多平台支持、`.agent-harness/` 命名空间、validate-handoff / phase-metrics 基础设施）的前提下，吸收了 upstream v6.2.0 的关键 bugfix（Windows Git Bash SessionStart、EPIPE 抗性、find-polluter、Codex GNU tar、SDD 测试 flake）和 skill 高价值段落（brainstorming YAGNI + isolation、writing-plans Global Constraints、writing-skills SDO + Match-Form-to-Failure 表、finishing-a-development-branch 环境探测 + rationalization 表、SDD 5 轮熔断），补齐了缺失的 Codex 打包/同步脚本与相关测试，且明确跳过了 Gemini 恢复、Visual companion、plan-scoped workspace 等不适用的变更。每处吸收在 commit 里留有 upstream sha 引用，决策全部记录在 `docs/agent-harness/sync/v6.2.0-log.md`。

## Definition of Done

### P0 bugfix（10 项）
- [ ] `5151e7a` Windows Git Bash SessionStart 落入 `hooks/session-start`，`bash -n` 通过
- [ ] `52f649e` shell:bash hook 派发文档段落落入 `hooks/README.md` 或对应 doc，品牌 agent-harness
- [ ] `d72560e` printf `|cat` EPIPE 修复落入 `hooks/session-start` 与 `hooks/session-start-codex`
- [ ] `c8921b5` + `6015d37` `scripts/find-polluter.sh` 支持 `./` 前缀
- [ ] `0e13ad8` `tests/claude-code/test-helpers.sh` `assert_contains`/`assert_order` 大小写不敏感 + 失败 dump 输出
- [ ] `tests/claude-code/test-worktree-native-preference.sh` 新落地（改品牌）
- [ ] `tests/claude-code/test-worktree-path-policy.sh` 新落地（改品牌）
- [ ] `d238a48`/`a60dc2f`/`a80b7b6`/`a868631` doc 死链修复（挑本地仍存在的锚点）

### P0.5 Codex（7 项）
- [ ] `.codex-plugin/plugin.json` 对齐 upstream v6.2.0 字段/category，品牌保持 agent-harness
- [ ] `scripts/sync-to-codex-plugin.sh` 落地，含 `.pi/` 排除 + `.agent-harness` 路径改造
- [ ] `scripts/package-codex-plugin.sh` 落地，含 GNU tar 兼容、zip 默认、hooks 保留策略
- [ ] `tests/codex/test-marketplace-manifest.sh` 落地并通过
- [ ] `tests/codex/test-package-codex-plugin.sh` 落地并通过
- [ ] Codex hooks 改进（`879ae59` bootstrap 匹配 startup/clear/compact）合并进 `hooks/session-start-codex`
- [ ] `tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` 因源脚本到位真正生效并通过

### P1 skill 精华（7 项，每 skill 独立 commit）
- [ ] `skills/brainstorming/SKILL.md`：新增 "Design for isolation and clarity" 独立小节 + "YAGNI ruthlessly" bullet；不含 Visual companion
- [ ] `skills/writing-plans/SKILL.md`：新增 "Global Constraints" + "Interfaces (Consumes/Produces)" block；Task Right-Sizing 段并入本地 Tracer-Bullet
- [ ] `skills/writing-skills/SKILL.md`：新增 "Match the Form to the Failure" 表 + "Micro-Test Wording Before Full Scenarios"；CSO → SDO 替换
- [ ] `skills/requesting-code-review/SKILL.md`：新增 Common Rationalizations 表
- [ ] `skills/finishing-a-development-branch/SKILL.md`：新增 Detect Environment + detached-HEAD 分支菜单 + provenance-based worktree cleanup + Common Rationalizations 表；保留 Option 4: Discard 与 SDD cleanup-workspace 集成
- [ ] `skills/subagent-driven-development/SKILL.md`：新增 Model Selection + Task Loop 步骤 1-5 + Fix Loop 5 轮熔断段；不含 plan-scoped workspace 结构
- [ ] `skills/systematic-debugging` 内容零改动，仅确认 P0 `test-helpers.sh` 已同步

### P2 参考文档（2 项）
- [ ] `skills/writing-good-tests/` 引入并改品牌
- [ ] `skills/using-agent-harness/references/codex-tools.md` 对齐 upstream `28882fc`

### Provenance & 记录（3 项）
- [ ] 每个 commit message 含 `Refs: <upstream-sha 前 7 位>` trailer
- [ ] `docs/agent-harness/sync/v6.2.0-log.md` 落地，五类（P0/P0.5/P1/P2/P3）完整覆盖
- [ ] `CLAUDE.md` 项目概述末尾追加 "Last upstream sync: v6.2.0 (2026-07-27)"

## Boundary Conditions

**Must support**
- 支持平台仅 Claude Code / Codex / Pi
- 本地 SDD Fan-Out 全部实现完好（`session-init.sh` / `sdd-state.sh` / `sdd-worktree.sh` / `Blocking: none` / `merge-fix-prompt.md`）
- `.agent-harness/` 命名空间与目录约定不变

**Must not break**
- `tests/plugin-infrastructure/run-all.sh` 全绿
- 本地 15+ 专属 skill 文件不动
- validate-handoff / phase-metrics / learnings 基础设施行为不变
- `docs/agent-harness/index.md` 主题速查已有条目不删

**Performance / 规模**
- 单批次 cherry-pick ≤ 5-8 commit
- 每 skill 独立 commit，单 diff 超 300 行拆两 commit

## Acceptance Criteria

**Computational**
- 所有落地 shell 脚本 `bash -n` 通过
- `tests/plugin-infrastructure/run-all.sh` 退出码 0
- `tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` 退出码 0
- `tests/codex/test-marketplace-manifest.sh` 与 `test-package-codex-plugin.sh` 退出码 0
- `tests/claude-code/test-worktree-native-preference.sh` 与 `test-worktree-path-policy.sh` 退出码 0
- `git log --grep='Refs: ' feat/agent-sup-v6.2.0` 覆盖每个 upstream 吸收 commit

**Inferential（人工审）**
- 每个 skill diff：本地魔改段落无误删、吸收段落无 "superpowers" 品牌残留
- `docs/agent-harness/sync/v6.2.0-log.md` 完整覆盖五类，P3 跳过项列出理由

## Negotiation Record

- Generator 轮 1：粗颗粒度 DoD，无可验证性
- Evaluator 轮 1：挑战颗粒度 / provenance / 决策日志完成标准 / P3 跳过验证
- Generator 轮 2：拆成 29 项可勾选原子标准，加计算/推断双重验收
- Final consensus：本 DoD + Boundary + Acceptance
