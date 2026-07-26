---
spec_topic: context-budget-and-memory-fixes
decision_summary: "session-start learnings 注入改为始终 top-N summary，demo learnings 迁移并按就近 .agent-harness 解析，修复 log-learning 丢字告警，并为 Fan-Out 三脚本与本次改动补纯脚本测试。"
design_approved: true
user_approved_at: 2026-07-26T00:00:00Z
gates: [user-review-passed]
domain_terms: [Learning, session-start, top-N summary, 就近解析, Fan-Out]
---

# 上下文预算瘦身 + memory/测试修复 设计

## 背景与问题

- `hooks/session-start` 实测向每个新会话注入 **~23KB** additionalContext，其中 Project Learnings 段占 **~16.9KB**。
- `.agent-harness/learnings.jsonl` 现有 37 条，其中 **10 条是 demo/fruit-shop 专属**（`files` 全部指向 `demo/fruit-shop/`），对顶层 harness 会话是纯噪音；反之 demo 内会话也看不到独立的知识域。
- 现有节流仅在条目数 `>= 50` 时触发 `--summary --max-entries --min-confidence`，37 条时全量注入，问题会随条目增长复现。
- `learnings.jsonl` 第 37 条（`eslint_plugin_react_version_flat_config`）insight 文本有空洞（"with , the version must be  or later"），根因是调用方用双引号传含反引号的 insight，shell 命令替换吃掉了内容。
- v6.5.0 引入的 SDD Fan-Out 三脚本（`session-init.sh` / `sdd-state.sh` / `sdd-worktree.sh`，共 225 行）零测试覆盖。

## 范围

### A. learnings 注入始终 top-N

- `hooks/session-start`：删除 `learnings_count >= 50` 阈值分支，无条件调用
  `search-learnings.sh --summary --max-entries 10 --min-confidence 7`。
- 复用现有 summary 模式的 confidence 冻结逻辑（issue #79），保持输出跨天稳定、prompt-cache 前缀友好；该语义不变。
- `search-learnings.sh` 不可执行时的 fallback 从 `tail -10` 改为 `tail -5`。
- 验收：learnings 段注入体积从 ~16.9KB 降至 ~4KB 量级；条目数上限 10。

### B. demo learnings 迁移 + 就近解析

- **数据迁移（一次性）**：将 10 条 `files` 指向 `demo/fruit-shop/` 的条目从顶层
  `.agent-harness/learnings.jsonl` 移入 `demo/fruit-shop/.agent-harness/learnings.jsonl`，
  保持 JSONL 原文不变（第 37 条除外，见 C）。
- **就近解析**：`hooks/session-start`、`scripts/log-learning.sh`、`scripts/search-learnings.sh`
  统一改为从 **cwd 向上查找最近的 `.agent-harness/` 目录**；找不到时回退现有逻辑
  （`CLAUDE_PROJECT_DIR` → `git rev-parse --show-toplevel`）。
- 解析逻辑提取为共享函数，放 `scripts/lib/`（与 `state.sh`/`worktree.sh` 并列），三处调用，
  避免三份拷贝漂移。
- 效果：demo 内会话读写 demo 的 learnings；顶层会话不再被 demo 条目污染。

### C. log-learning 丢字修复

- 根因：`log-learning.sh` 自身 env 传参安全；丢字发生在调用侧双引号 + 反引号命令替换。
- `log-learning.sh` 增加启发式告警：insight 命中疑似空洞模式（连续 "  "、" , "、" 空 or"
  等）时向 stderr 输出提示，不阻断写入。
- `skills/session-learnings` 的调用指引明确要求单引号传 insight
  （skill 文档中的操作指引更新，不改变 skill 行为逻辑，不需行为评估）。
- 迁移时补全第 37 条的空洞文本（补回 `eslint-plugin-react`、版本号等实际内容）。

### D. 纯脚本测试补齐（纳入 tests/plugin-infrastructure 套件）

1. `test-sdd-session-init.sh` — 会话初始化：state 文件生成、重复初始化幂等。
2. `test-sdd-state.sh` — state 读写：get/set 往返、非法 JSON 防护。
3. `test-sdd-worktree.sh` — worktree 创建/分支重名复用/清理。
4. `test-session-start-learnings-topn.sh` — A 的回归：注入条目 ≤10、summary 模式生效、
   learnings 段字节数上界断言。
5. `test-learnings-nearest-resolution.sh` — B 的回归：子目录 cwd 解析到就近
   `.agent-harness`，无 `.agent-harness` 时回退顶层。
6. 扩展 `tests/learnings-scripts/test-learnings.sh` — C 的告警分支（含空洞 insight 触发
   stderr 提示、正常 insight 不触发）。

所有测试为纯脚本断言，秒级完成，不消耗 Claude API 配额。

## 明确不做（本次范围外）

- CI 门禁（GitHub Actions）
- computational-sensors 升级为确定性 hook 层
- `using-agent-harness` skill 内容瘦身（skill 内容改动需行为评估，成本高）
- shellcheck 全量改造 / scripts 统一 `set -euo pipefail`
- `tests/skill-behavior/auto-loop/` API 行为测试

## 架构与数据流

```
会话启动
  └─ hooks/session-start
       ├─ scripts/lib/learnings-path.sh::resolve_learnings_root()   ← 新增共享函数
       │    cwd 向上找最近 .agent-harness/ → 回退 CLAUDE_PROJECT_DIR → git toplevel
       └─ search-learnings.sh --summary --max-entries 10 --min-confidence 7  ← 无条件
记录 learning
  └─ log-learning.sh
       ├─ resolve_learnings_root()（同上）
       └─ 空洞启发式告警（stderr，不阻断）
```

## 错误处理

- 就近解析失败（无 `.agent-harness`、非 git 仓库）：回退链保证与现行为一致，不新增失败路径。
- `search-learnings.sh` 缺失/不可执行：fallback `tail -5`，会话启动不中断。
- 告警仅 stderr 提示，绝不阻断 learning 写入。

## 测试策略

见范围 D。关键回归保护：改 session-start 注入逻辑必须有字节数/条目数断言兜底；
改路径解析必须有子目录/顶层双场景断言。

## 风险

- 就近解析改变了三个脚本的根目录语义：若用户在无关子目录（如 `tests/`）运行，仍会向上
  找到顶层 `.agent-harness`，行为不变；唯一行为变化点是存在嵌套 `.agent-harness` 的目录
  （目前仓库内仅 demo/fruit-shop 迁移后出现），符合预期。
- top-N 注入减少了低置信度条目曝光：接受，条目仍可通过 `search-learnings.sh` 按需检索。
