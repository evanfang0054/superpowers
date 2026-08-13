---
spec_topic: learnings-removal
decision_summary: "完整移除 learnings 生态：session-learnings skill、log/search/index-learnings 脚本、trace-analysis skill+脚本、session-start 注入、learnings.jsonl 数据文件，连带清理 diagnose/retrospective/guard-staging/stop-hook 下游消费者与现行文档，demo 数据文件一并删除"
design_approved: true
user_approved_at: "2026-08-13T06:00:49Z"
gates: [user-review-passed]
domain_terms: [Learning, session-start, top-N summary, 就近解析, 闭环链路]
---

# 移除 learnings 能力设计 Spec

## 背景

Agent Harness 的 learnings 能力是一个跨层级的子系统：`session-learnings` skill 引导 agent 记录项目知识到 `.agent-harness/learnings.jsonl`，SessionStart hook 在每个新会话注入 learnings 摘要，`search-learnings.sh` / `log-learning.sh` / `index-learnings.sh` 提供读写索引，`trace-analysis` skill 与 `trace-analyzer.sh` 完全依赖 learnings 数据做失败模式分析，`diagnose-failure.sh` 与 `retrospective` skill 也消费 learnings。

用户决策移除该能力：learnings 不再注入、不再记录、不再作为任何分析的数据源。

## 设计决策（来自 brainstorming 对话）

| # | 决策 | 选项 | 理由 |
|---|------|------|------|
| 1 | 移除范围 | 完整移除生态（learnings 子系统 + trace-analysis + 下游消费者引用） | 引用网状交错，拆分留下悬空引用 |
| 2 | 数据文件 `.agent-harness/learnings.jsonl` | 删除（不迁移、不保留） | 移除能力后无消费者 |
| 3 | 文档 | 现行文档清理 + 历史快照（plans/specs/contracts）保留 | 历史快照是时间记录，篡改会丢失真实 |
| 4 | demo 项目 | 连带清理 demo 下 learnings.jsonl 数据文件 | 用户明确要求保持仓库一致 |
| 5 | diagnose | 保留 diagnose-failure.sh，降级为单信号源（phase_history） | phase-metrics 独立于 learnings，保留价值 |
| 6 | trace-analysis | skill + trace-analyzer.sh 一并移除 | 完全依赖 learnings 数据源，无 learnings 即无意义 |
| 7 | 替代机制 | 不引入任何替代记录/注入机制 | YAGNI |

## 非目标

- 不新增任何 learnings 的替代能力（记录、注入、分析）。
- 不修改 demo 项目中的其他文件（sensors.json、sdd/ 等非 learnings 内容保留）。
- 不修改历史文档（docs/agent-harness/plans/、specs/、contracts/、CHANGELOG.md 中的 learnings 提及保留）。
- 不移除知识库（knowledge-base）本体：`docs/agent-harness/index.md` 两级检索机制与 learnings 无关，保留；仅新增 learnings-removal topic。
- 不修改 `.agent-harness/sdd/`、`.agent-harness/loop-tracker.json` 等非 learnings 运行态文件。

## 删除清单（15 个文件/目录）

### 核心基础设施（7）
| 路径 | 类型 |
|------|------|
| `scripts/log-learning.sh` | 记录脚本 |
| `scripts/search-learnings.sh` | 搜索/摘要脚本（session-start 调用） |
| `scripts/index-learnings.sh` | 聚类索引脚本 |
| `scripts/trace-analyzer.sh` | trace-analysis 数据源脚本 |
| `skills/session-learnings/`（含 SKILL.md） | skill |
| `skills/trace-analysis/`（含 SKILL.md） | skill |
| `.agent-harness/learnings.jsonl` | 数据文件 |

### 测试（5）
| 路径 | 类型 |
|------|------|
| `tests/learnings-scripts/`（整个目录） | 纯脚本测试 |
| `tests/knowledge-base-scripts/test-index-learnings.sh` | index-learnings 测试 |
| `tests/skill-behavior/session-learnings/` | headless 行为测试 |
| `tests/skill-behavior/trace-analysis/` | headless 行为测试 |
| `tests/skill-triggering/prompts/session-learnings.txt` | 未被引用的遗留 prompt 文件 |

### demo（3）
| 路径 | 说明 |
|------|------|
| `demo/.superpowers/learnings.jsonl` | 仅删 learnings.jsonl，保留 sensors.json |
| `demo/fruit-shop/.agent-harness/learnings.jsonl` | 仅删 learnings.jsonl，保留 sdd/ |
| `demo/fruit-shop/packages/server/.superpowers/learnings.jsonl` | 目录仅含 learnings.jsonl |

## 修改清单

### hooks（2）
| 路径 | 改动 |
|------|------|
| `hooks/session-start` | 移除 learnings 注入段（learnings.jsonl 读取 + search-learnings.sh 调用 + learnings_content 拼装 + resume 分支的 learnings 注释）。注入结构变为：startup = using-agent-harness + headless_tip + kb_hint + context_md_hint + warning + checkpoint_hint；resume = warning + checkpoint_hint。稳定前缀（缓存友好排序，issue #79）不受影响。 |
| `hooks/stop-hook.sh` | 移除 ralph loop 完成时"用 session-learnings 记录"的提示（约第 159-165 行），恢复为正常结束。 |

### scripts（3）
| 路径 | 改动 |
|------|------|
| `scripts/guard-staging.sh` | PROTECTED_PATHS 移除 `.agent-harness/learnings.jsonl` 条目 |
| `scripts/diagnose-failure.sh` | 移除 TRACE/LEARN 变量与 `evidence.trace_classification` / `evidence.similar_learnings` 输出字段；root_cause 推断中依赖 trace 的分支改为仅基于 context |
| `scripts/lib/diagnose-lib.sh` | 移除 `diagnose_trace`、`diagnose_similar_learnings` 函数，保留 `diagnose_phase_history` |

### skills（10 处，移除 learnings 引用/记录引导句）
| 路径 | 改动 |
|------|------|
| `skills/brainstorming/SKILL.md` | 移除"用 session-learnings 记录"句 |
| `skills/test-driven-development/SKILL.md` | 同上 |
| `skills/writing-plans/SKILL.md` | 同上 |
| `skills/finishing-a-development-branch/SKILL.md` | 同上 |
| `skills/systematic-debugging/SKILL.md` | 同上 |
| `skills/receiving-code-review/SKILL.md` | 同上 |
| `skills/post-deploy-monitoring/SKILL.md` | 同上 |
| `skills/retrospective/SKILL.md` | 移除 learnings 数据收集、trace-analyzer 调用、learnings 警示与 integration 引用 |
| `skills/harness-init/SKILL.md` | 移除"hooks 启用 learnings 注入"说明 |
| `skills/harness-optimizer/SKILL.md` | 移除 ASCII 图中 session-learnings 存储节点与 integration 引用 |

### 测试更新（4）
| 路径 | 改动 |
|------|------|
| `tests/plugin-infrastructure/test-session-start-cache-stable.sh` | 移除 learnings 段断言（改为"无 learnings 注入"）；移除 search-learnings.sh --summary 确定性断言 |
| `tests/plugin-infrastructure/test-guard-staging.sh` | 移除 learnings.jsonl 保护路径用例 |
| `tests/knowledge-base-scripts/run-all.sh` | 移除 test-index-learnings.sh 引用 |
| `tests/diagnose-scripts/test-diagnose-failure.sh` | 移除 `similar_learnings` 断言 |

### 现行文档（6）
| 路径 | 改动 |
|------|------|
| `CLAUDE.md` | 移除 Learnings 小节、质量层 trace-analysis、验证地图中 learnings 提及 |
| `README.md` / `README_EN.md` | 移除 learnings / trace-analysis 描述 |
| `skills/CLAUDE.md` | 移除第 98 行 learnings.jsonl 编辑规则 |
| `tests/CLAUDE.md` | 套件速查表移除 learnings-scripts 行 |
| `docs/agent-harness/index.md` | 已新增 learnings-removal topic |
| `CONTEXT.md` | 移除 Learning、top-N summary、就近解析 三个术语条目；调整 session-start、闭环链路 中的 learnings 引用 |

## 数据流变化

session-start 注入结构（移除前后）：

```
移除前:
  startup = using-agent-harness + headless_tip + kb_hint + context_md_hint
            + warning + learnings + checkpoint_hint
  resume  = warning + learnings + checkpoint_hint
  precompact = checkpoint 文件 + 空注入

移除后:
  startup = using-agent-harness + headless_tip + kb_hint + context_md_hint
            + warning + checkpoint_hint
  resume  = warning + checkpoint_hint
  precompact = 不变
```

移除 learnings 后，会话注入体积减小（学习摘要段消失），稳定前缀不变。resume 分支的"only learnings delta"语义删除，resume 与 startup 的差异仅剩 using-agent-harness 本体是否重复注入。

## 错误处理

纯移除操作，无新增运行时错误路径。session-start 移除 learnings 读取后不再有 search-learnings.sh 依赖；guard-staging 移除 learnings 保护条目后不再误拦。

## 测试与验证策略

- **删除**的测试套件随文件移除。
- **更新**的测试跑：`tests/plugin-infrastructure/run-all.sh`、`tests/diagnose-scripts/run-all.sh`、`tests/knowledge-base-scripts/run-all.sh`、`tests/ralph-loop-scripts/`（stop-hook 无 learnings 断言，模拟文本保留）。
- **session-start 冒烟**：`CLAUDE_PLUGIN_ROOT` 注入两次，确认无 learnings 段、JSON 合法、startup/resume/precompact 三分支输出正确。
- **guard-staging 冒烟**：`git add .agent-harness/learnings.jsonl`（文件已删）不再被拦。
- **全局引用检查**：grep `learnings` 确认仅剩历史文档与 demo 无关残留（如有非目标内残留需说明）。

## 影响分析

- 移除后，会话上下文成本降低（无 learnings 摘要段）。
- `trace-analysis` skill 从质量层移除：质量层流程变为 `qa-testing → post-deploy-monitoring → retrospective`。
- `diagnose-failure.sh` 降级为 phase_history 单信号，`evidence` 结构移除 trace_classification / similar_learnings 字段。
- CONTEXT.md 领域术语收敛：移除 Learning 相关术语，闭环链路改为仅消费 phase-metrics。
