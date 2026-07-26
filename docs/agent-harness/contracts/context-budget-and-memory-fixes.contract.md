# Sprint Contract: context-budget-and-memory-fixes

## Definition of Done

- [ ] `hooks/session-start` 无条件调用 `search-learnings.sh --summary --max-entries 10 --min-confidence 7`，源码中不再存在 `>= 50` 阈值分支；注入的 learnings 条目 ≤ 10
- [ ] 顶层仓库实测：session-start 输出的 Project Learnings 段 ≤ 6KB（当前 16.9KB）
- [ ] `search-learnings.sh` 不可执行时 fallback 为 `tail -5`（不是 `tail -10`）
- [ ] 顶层 `.agent-harness/learnings.jsonl` 中 `files` 指向 `demo/fruit-shop/` 的条目数为 0；`demo/fruit-shop/.agent-harness/learnings.jsonl` 包含迁移的 10 条，且第 37 条（`eslint_plugin_react_version_flat_config`）空洞文本已补全（insight 中不再出现 "with , the" / "must be  or" 模式）
- [ ] `scripts/lib/` 存在共享解析函数；`hooks/session-start`、`scripts/log-learning.sh`、`scripts/search-learnings.sh` 三处均通过它解析 learnings 根目录，无各自拷贝
- [ ] 在 `demo/fruit-shop/` 内运行 log-learning 写入 demo 的 learnings.jsonl；在顶层运行写入顶层的；在无 `.agent-harness` 的独立目录中回退链（`CLAUDE_PROJECT_DIR` → git toplevel）行为与现状一致
- [ ] `log-learning.sh` 对命中空洞模式的 insight 输出 stderr 警告且仍写入成功（exit 0）；正常 insight 不触发警告
- [ ] `skills/session-learnings` 调用指引明确要求单引号传 insight
- [ ] 新增 5 个测试脚本（3 个 Fan-Out + 2 个本次回归）纳入 `tests/plugin-infrastructure/run-all.sh`，`tests/learnings-scripts/test-learnings.sh` 扩展告警用例；全量运行 0 失败
- [ ] 存量测试无回归：`tests/plugin-infrastructure/run-all.sh` 原 25 个套件 + `tests/learnings-scripts/test-learnings.sh` 全部通过

## Boundary Conditions

- Must support: summary 输出跨天字节稳定（confidence 冻结语义不变，issue #79 prompt-cache 前缀友好）
- Must not break: 无嵌套 `.agent-harness` 场景下三脚本的现行为（解析结果与改动前一致）；`session-start` 对 4 种 source（startup/clear/resume/precompact）的分支语义
- Must not: 修改任何 SKILL.md 的行为逻辑（session-learnings 仅更新调用指引文案）；引入第三方依赖
- Performance: 所有新增测试为纯脚本断言，不调用 `claude -p`，单套件秒级完成

## Acceptance Criteria

- Computational: `tests/plugin-infrastructure/run-all.sh` 30 个子套件（25 存量 + 5 新增）全部 PASS；`tests/learnings-scripts/test-learnings.sh` PASS
- Computational: `CLAUDE_PLUGIN_ROOT=$PWD hooks/session-start < /dev/null` 输出中 learnings 段 ≤ 6KB 且条目 ≤ 10（由 `test-session-start-learnings-topn.sh` 断言）
- Inferential: code review 确认共享函数无三份拷贝漂移、回退链与现行为等价

## Negotiation Record

- Generator: 初稿 4 条（top-N 生效 / 迁移完成 / 有告警 / 测试通过）
- Evaluator: 第 1 轮全部驳回——不可测、无具体数字、无双场景断言、未覆盖存量回归；第 2 轮补充跨天稳定与回退链等价两条边界后接受
- Final consensus: 上述 10 条 DoD + 4 条边界条件
