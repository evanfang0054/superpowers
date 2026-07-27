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

### P0 bugfix（8 项）
- [x] `5151e7a`：`hooks/hooks.json` 的 Claude SessionStart command 显式声明 `"shell": "bash"`，仍调用 `run-hook.cmd session-start`；`bash -n hooks/session-start` 通过
- [x] `52f649e` shell:bash hook 派发文档段落落入 `hooks/README.md` 或对应 doc，品牌 agent-harness
- [x] `d72560e` printf `|cat` EPIPE 修复落入 `hooks/session-start` 与 `hooks/session-start-codex`
- [x] `c8921b5` + `6015d37` `skills/systematic-debugging/find-polluter.sh` 支持 `./` 前缀
- [x] `0e13ad8` `tests/claude-code/test-helpers.sh` `assert_contains`/`assert_order` 大小写不敏感 + 失败 dump 输出
- [x] `tests/claude-code/test-worktree-native-preference.sh` 新落地（改品牌）
- [x] `tests/claude-code/test-worktree-path-policy.sh` 新落地（改品牌）
- [x] `d238a48`/`a60dc2f`/`a80b7b6`/`a868631` dead-link 候选逐项核对；仅修复本地仍存在的目标，其他项以具体理由记为 skipped

### P0.5 Codex（7 项）
- [x] `.codex-plugin/plugin.json` 对齐 upstream v6.2.0 字段/category，品牌保持 agent-harness
- [x] `scripts/sync-to-codex-plugin.sh` 落地，含 `.pi/` 排除 + `.agent-harness` 路径改造
- [x] `scripts/package-codex-plugin.sh` 落地，含 GNU tar 兼容、zip 默认、hooks 保留策略
- [x] `tests/codex/test-marketplace-manifest.sh` 落地并通过
- [x] `tests/codex/test-package-codex-plugin.sh` 落地并通过
- [x] Codex hooks 改进（`879ae59` bootstrap 匹配 startup/clear/compact）合并进 `hooks/session-start-codex`
- [x] `tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` 因源脚本到位真正生效并通过

### P1 skill 精华（7 项，每 skill 独立 commit）
- [x] `skills/brainstorming/SKILL.md`：新增 "Design for isolation and clarity" 独立小节 + "YAGNI ruthlessly" bullet；不含 Visual companion
- [x] `skills/writing-plans/SKILL.md`：新增 "Global Constraints" + "Interfaces (Consumes/Produces)" block；Task Right-Sizing 段并入本地 Tracer-Bullet
- [x] `skills/writing-skills/SKILL.md`：新增 "Match the Form to the Failure" 表 + "Micro-Test Wording Before Full Scenarios"；CSO → SDO 替换
- [x] `skills/requesting-code-review/SKILL.md`：新增 Common Rationalizations 表
- [x] `skills/finishing-a-development-branch/SKILL.md`：新增 Detect Environment + detached-HEAD 分支菜单 + provenance-based worktree cleanup + Common Rationalizations 表；保留 Option 4: Discard 与 SDD cleanup-workspace 集成
- [x] `skills/subagent-driven-development/SKILL.md`：新增 Model Selection + Task Loop 步骤 1-5 + Fix Loop 5 轮熔断段；不含 plan-scoped workspace 结构
- [x] `skills/systematic-debugging/SKILL.md` 内容零改动；仅允许 P0 的 `find-polluter.sh` 与对应测试发生变更

### P2 参考文档（2 项）
- [x] `skills/writing-good-tests/` 引入并改品牌
- [x] `skills/using-agent-harness/references/codex-tools.md` 对齐 upstream `28882fc`

### Provenance & 记录（3 项）
- [x] 每个吸收 upstream 变更的 commit message 含 `Refs: <upstream-sha 前 7 位>` trailer；纯本地记录/索引 commit 不伪造 upstream `Refs`
- [x] `docs/agent-harness/sync/v6.2.0-log.md` 落地，五类（P0/P0.5/P1/P2/P3）完整覆盖
- [x] `CLAUDE.md` 项目概述末尾追加 "Last upstream sync: v6.2.0 (2026-07-27)"

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
- 从 decision log 的 `adopted`/`adapted` 行抽取 SHA7 集合，与 `SYNC_BASE_SHA..HEAD` 所有合法 `Refs:` trailer 的 SHA7 集合排序去重后完全相等；trailer 格式仅允许 `Refs: SHA7[, SHA7...]`

**Inferential（人工审）**
- 每个 skill diff：本地魔改段落无误删、吸收段落无 "superpowers" 品牌残留
- `docs/agent-harness/sync/v6.2.0-log.md` 完整覆盖五类，P3 跳过项列出理由

## Negotiation Record

- Generator 轮 1：粗颗粒度 DoD，无可验证性
- Evaluator 轮 1：挑战颗粒度 / provenance / 决策日志完成标准 / P3 跳过验证
- Generator 轮 2：拆成 27 项可勾选原子标准，加计算/推断双重验收
- Final consensus：本 DoD + Boundary + Acceptance
