# Sprint Contract: learnings-removal

## Definition of Done
- [ ] 下列 15 个文件/目录已删除：`scripts/log-learning.sh`、`scripts/search-learnings.sh`、`scripts/index-learnings.sh`、`scripts/trace-analyzer.sh`、`skills/session-learnings/`、`skills/trace-analysis/`、`.agent-harness/learnings.jsonl`、`tests/learnings-scripts/`、`tests/knowledge-base-scripts/test-index-learnings.sh`、`tests/skill-behavior/session-learnings/`、`tests/skill-behavior/trace-analysis/`、`tests/skill-triggering/prompts/session-learnings.txt`、`demo/.superpowers/learnings.jsonl`、`demo/fruit-shop/.agent-harness/learnings.jsonl`、`demo/fruit-shop/packages/server/.superpowers/learnings.jsonl`
- [ ] `hooks/session-start` 无 learnings 读取/注入逻辑；startup/resume/precompact 三分支输出合法 JSON 且不含 learnings 段
- [ ] `hooks/stop-hook.sh` 不再提示 session-learnings
- [ ] `scripts/guard-staging.sh` 的 PROTECTED_PATHS 不含 learnings.jsonl；`test-guard-staging.sh` 对应用例已更新
- [ ] `scripts/diagnose-failure.sh` 输出 `evidence` 不含 trace_classification / similar_learnings；`scripts/lib/diagnose-lib.sh` 不含 `diagnose_trace` / `diagnose_similar_learnings`
- [ ] 以下 10 个 skill 的 learnings 引用全部移除：brainstorming、test-driven-development、writing-plans、finishing-a-development-branch、systematic-debugging、receiving-code-review、post-deploy-monitoring、retrospective、harness-init、harness-optimizer
- [ ] 更新后的测试套件全部通过：`tests/plugin-infrastructure/run-all.sh`、`tests/diagnose-scripts/run-all.sh`、`tests/knowledge-base-scripts/run-all.sh`、`tests/ralph-loop-scripts/`
- [ ] 现行文档（CLAUDE.md、README.md、README_EN.md、skills/CLAUDE.md、tests/CLAUDE.md、CONTEXT.md）无 learnings 能力描述残留
- [ ] 全局 grep `learnings`（工作区）仅命中：`docs/agent-harness/plans/`、`docs/agent-harness/specs/`、`docs/agent-harness/contracts/`、`CHANGELOG.md` 历史快照
- [ ] 无新增 learnings 替代机制文件（YAGNI）

## Boundary Conditions
- Must support: demo 非 learnings 文件（sensors.json、sdd/）保留
- Must not break: 知识库（knowledge-base）两级检索机制；phase-metrics 独立功能；session-start 稳定前缀（缓存友好排序）
- Must not break: 现有 git 历史（不重写已提交历史）

## Acceptance Criteria
- Computational: `tests/plugin-infrastructure/run-all.sh`、`tests/diagnose-scripts/run-all.sh`、`tests/knowledge-base-scripts/run-all.sh`、`tests/ralph-loop-scripts/` 全绿；grep 残留白名单检查
- Inferential: 人工审查 diff——每个删除文件有对应引用清理，无悬空引用

## Negotiation Record
- Generator: 初始 9 条 DoD（删除文件、session-start、stop-hook、guard-staging、diagnose、skill 引用、测试通过、文档、grep 白名单）
- Evaluator: 挑战 C1 "10 个 skill" 计数模糊 → 明确列出 10 个路径；C2 "仅命中历史快照" 边界不清 → 精确定义允许残留路径集合；C3 缺 YAGNI 约束 → 加"无替代机制"；C4 demo 边界 → 明确只删 learnings.jsonl；C5 resume 分支语义 → 不再是 learnings delta
- Final consensus: 上表修订版 9 条 DoD + 边界 + 验收标准
