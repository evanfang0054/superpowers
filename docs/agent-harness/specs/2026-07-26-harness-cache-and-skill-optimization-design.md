---
spec_topic: harness-cache-and-skill-optimization
decision_summary: "三阶段优化 harness：KV 缓存前缀加固、skill 注册表瘦身与渐进式披露、闭环链路修复，一次 spec 全部落地"
design_approved: true
user_approved_at: 2026-07-26T00:00:00Z
gates: [user-review-passed]
domain_terms: [稳定前缀, 渐进式披露, Skill 注册表, 闭环链路]
---

# Harness 缓存与 Skill 体系优化设计

## 背景与目标

调研结论（KV-cache aware prompt engineering 实验数据）：稳定前缀可带来约 65% TTFT 中位数改善、约 70% 成本差异。核心原则：**静态在前、动态在后、字节级稳定**。

本项目现状问题（按收益排序）：

1. 大 skill 未做渐进式披露：`harness-design` 61KB、`writing-skills` 24KB、`brainstorming` 16KB、`writing-plans` 15KB，触发即全量注入。
2. skill 注册表偏胖：33 个 skill description 每会话固定注入，最长 288 字符；纯命令型 skill 仍在自动触发池。
3. session-start 注入的动态段（context_md_hint / checkpoint_hint / learnings）与静态段交错，破坏缓存前缀稳定性。
4. auto-loop orchestrator prompt 动态占位符（`{{REQUEST}}` 等）位于文件前部，长循环中稳定指令体无法命中缓存。
5. harness-optimizer Step 5 引用不存在的 `skill_creator.scripts.run_eval`，闭环"验证"环节断裂。
6. 闭环缺"度量→触发"自动化：无机制把连续失败信号路由到 harness-optimizer。
7. specs/index.md 主题锚点仅覆盖 10 个主题，specs/ 实有 27 个文件，两级检索会漏。

目标：一次 spec 全部落地（用户决策：自用闭环体系，机会有限，做彻底），内部按 P1→P2→P3 顺序实施以保证测试归因。

## P1 缓存前缀加固

### session-start hook（hooks/session-start）

- 注入顺序调整：`using-agent-harness`（静态）→ `headless_tip`（静态）→ `kb_hint`（半静态）→ 动态段统一置尾：`context_md_hint` → `warning` → `learnings` → `checkpoint_hint`。
- learnings 摘要压缩：`search-learnings.sh --summary` 输出只保留 `[confidence] 一句话结论`，37 条时预计从 ~8KB 降到 ~3KB。
- 保持 Cursor / Claude Code / Copilot 三平台输出分支不变。
- 验证规则（CLAUDE.md）：改动后必须验证新会话收到完整 `hookSpecificOutput.additionalContext`（含 using-agent-harness 与 learnings 块）。

### auto-loop orchestrator prompt（skills/auto-loop/orchestrator-prompt.md）

- 结构重排：稳定指令体（生存规则、state.json 协议、8 步链路、会话筛选协议）放前部；`{{REQUEST}}/{{SCOPE}}/{{SCAN_TARGET}}/{{BRANCH}}/{{MODE}}/{{FILTER}}/{{TARGET_ISSUES}}/{{MAX_ISSUES}}` 动态上下文块整体移到文件末尾。
- 稳定段内嵌的 `{{REPO_ROOT}}` 占位符保留原位（单次 run 内不变，不影响 run 内多轮缓存）。
- auto-loop.sh 的 jq gsub 逻辑不改（占位符名不变，只挪位置）。

## P2 注册表瘦身 + 渐进式披露

### 拆分守则（硬规则）

- **规则留主干、资料进 references/**：硬约束、检查清单、HARD-GATE、流程图必须留在 SKILL.md；只移案例、模板、边界情况等"执行到那一步才需要"的内容。
- **跨 skill 引用的章节禁止移出**：如 brainstorming 的 circuit-breaker 被 loop-detection/SKILL.md:22,72 引用，必须保留。
- 只做内容搬移，不重写已调优文案（满足"无证据不重写"红线）。
- SKILL.md 内用硬指引（"需要 X 时读 references/x.md"）实现按需加载，沿用 harness-design 已验证的 references/ 模式。

### 拆分清单

| Skill | 现状 | SKILL.md 保留 | 移入 references/ |
|-------|------|---------------|------------------|
| harness-design | 61KB | 流程主干+触发条件（~8KB） | 模板库、风格细节、导出流程 |
| writing-skills | 24KB | TDD 流程+核心规则（~6KB） | 测试细节、案例、反模式清单 |
| brainstorming | 16KB | 检查清单、流程图、HARD-GATE、circuit-breaker（~11KB） | 仅六问表格（office-hours 有独立副本，无依赖） |
| writing-plans | 15KB | 计划格式+任务结构（~6KB） | 示例、边界情况 |

### 注册表瘦身

- 压缩 3 个超长 description：harness-design 288→<120 字符、retrospective 234→<120、domain-modeling 220→<120，保留触发关键词。
- `generate-issues`、`fix-issues-and-pr` 补 `disable-model-invocation: true`（已确认 orchestrator-prompt / auto-loop.sh / commands/ 无模型自动触发依赖；slash 入口不受影响）。

## P3 闭环修复

- **harness-optimizer Step 5**：验证环节改为真实链路——`cd tests/skill-behavior/<skill> && ./run-test.sh`；无对应测试时降级 `tests/claude-code/run-skill-tests.sh --test <skill>`。
- **specs/index.md 锚点补全**：跑 `scripts/index-knowledge-base.sh` 重建 + 手动核对，为 27 个 spec 补齐主题速查锚点。
- **度量→触发自动化**：stop-hook.sh 末尾加轻量检查——读 phase-metrics 最近记录，同一 skill 连续 3 次 `gate-result failed` 时输出一行提示建议运行 harness-optimizer。只提示不自动执行。

## 测试与验收

| 阶段 | 验收 |
|------|------|
| P1 | `tests/plugin-infrastructure/run-all.sh` 通过；`./scripts/auto-loop.sh --dry-run "测试"` 占位符填充正确；新会话 additionalContext 完整 |
| P2 | 拆分前先跑 4 个 skill 的 `tests/skill-behavior/<skill>/run-test.sh` 记录 baseline；拆分后 `tests/claude-code/run-skill-tests.sh` + behavior test 对比；红了说明移错内容，搬回 SKILL.md |
| P3 | harness-optimizer behavior test；stop-hook 手动触发验证 |

## 风险与边界

- behavior test 即回归证据：测试红 = 移错内容，回滚对应段落。
- session-start 只读 `using-agent-harness/SKILL.md`（不在拆分名单），hook 不受拆分影响。
- 按需加载增加运行时 Read 依赖，靠 SKILL.md 硬指引 + 已验证的 harness-design 模式缓解。
- 不动 demo/、不加第三方依赖、不改平台输出分支。

## 影响分析（用户追问后修订）

1. 跨 skill 引用指空 → circuit-breaker 不移出；六问表格可移（office-hours 有独立副本）。
2. references/ 内容需 agent 主动 Read → 硬约束全部留主干。
3. behavior test 可能红 → 作为验收手段而非风险。
4. 已确认无影响：disable-model-invocation 两处、session-start 与拆分名单无交集。
