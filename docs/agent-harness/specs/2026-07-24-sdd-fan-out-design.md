---
spec_topic: sdd-fan-out
decision_summary: "SDD 引入 Fan-Out：并行实现、自动 merge、自动修复回环、人工介入兜底"
design_approved: true
user_approved_at: "2026-07-24T15:30:00+08:00"
gates: [user-review-passed]
domain_terms:
  - sdd-fan-out
  - orchestrator-branch
  - implementer-worktree
  - fan-in-merge
  - auto-fix-loop
  - intervention-condition
  - file-scope-violation
  - session-worktree-namespace
---

# SDD Fan-Out：并行 Subagent 实现

## 动机

当前 SDD（Subagent-Driven Development）严格串行：一次 dispatch 一个 implementer，完成后再 dispatch 下一个。对于包含多个无依赖任务（独立文件、独立职责）的 plan，串行浪费了并行能力，也延长了整体完成时间。

Graph Engineering 的核心洞察：**由控制图（control flow graph）显式表达节点间的依赖关系，让系统可以安全地并行执行独立节点，并在汇合点做集成验证。**

本文设计 SDD 引入 Fan-Out 的能力——当 plan 中的任务没有数据/文件依赖时，orchestrator 自动并行 dispatch 多个 implementer，各自在隔离的 worktree 中实现，完成后自动 merge 回 orchestrator 分支，集成测试和 code review 在 merge 后统一进行。

## 设计

### 1. Plan 标注语法

复用 `writing-plans` 已有的 **Blocking** 字段，不再引入新语法：

| Blocking 值 | 含义 | 执行方式 |
|-------------|------|----------|
| `Blocking: none` | 无依赖 | 可与同级无依赖任务并行 |
| `Blocking: Task N` | 依赖 Task N | 等 Task N merge 完成后再执行 |
| 省略 | 默认串行 | 按 plan 顺序执行（当前行为） |

新增可选字段 **`files`**，标注任务预期修改的文件列表，用于冲突检测：

```markdown
### Task 1: 重构日志工具
Blocking: none
files: scripts/log.sh, tests/test-log.sh

实现日志工具的错误处理重构。

### Task 2: 添加性能指标收集
Blocking: Task 1
files: scripts/metrics.sh

新增性能数据采集模块，依赖 Task 1 的日志工具。

### Task 3: 修复 README 拼写错误
Blocking: none
files: README.md

修正文档中的拼写错误。
```

上述 plan 中，Task 1 和 Task 3 无依赖，可并行；Task 2 依赖 Task 1，必须在 Task 1 merge 之后执行。

**关于读后写依赖**：如果 Task B 需要**读取** Task A 修改的代码（即使 B 只写入不同文件），也必须把 Task A 写入 `Blocking: Task A`。这不是技术问题，是标注规范——Plan 作者负责识别语义依赖。Orchestrator 不做自动推断。

**省略标注的兼容**：如果 plan 中任何 Task 缺少 `Blocking:` 字段，orchestrator 回退到当前串行行为。现有 plan 不需要立刻修改。

**Task 标题格式**：plan 必须使用 `### Task N: Description` 格式（如 `### Task 1: 重构日志工具`）。Orchestrator 按 `### Task` 正则解析任务边界。偏离此格式的 plan（如 `### Step 1`）会退化为串行执行。

**`files:` 到 state 的映射**：plan 中 `files: scripts/log.sh, tests/test-log.sh` 由 parser 转换为 state 中的 `"file_scope": ["scripts/log.sh", "tests/test-log.sh"]`。实现时注意 parser 按逗号分割并 trim 前后空格即可。

### 2. 并行 dispatch 机制

Fan-Out 的核心问题是：**在 Claude Code 会话中如何让多个 implementer 同时运行？**

答案：**同一 message 中并行 dispatch 多个 Agent tool 调用**。Claude Code 的 Agent tool 支持在同一 message 中并发调用，每个 implementer subagent 独立工作，全部返回后 orchestrator 统一处理。

```
orchestrator 的 message：
├── Agent(implementer-1, worktree-path-1, branch-1)
├── Agent(implementer-2, worktree-path-2, branch-2)
└── Agent(implementer-3, worktree-path-3, branch-3)

三个 implementer 同时运行（真并行，非轮流），各自在自己的 worktree 中实现
全部返回后 → 进入 review / merge 阶段
```

这与 auto-loop 的 headless `claude -p` 模式完全不同。auto-loop 走 `claude -p` 是因为它需要独立闭环自我迭代；普通 SDD 的 Fan-Out 走 Agent tool，在同一个会话上下文中运行。

**并发上限**：默认 `concurrency_limit: 3`（一个 message 中最多 3 个并行 Agent 调用），避免同一会话 token 消耗激增。

### 3. Session 标识与 Worktree 命名

每轮 SDD 会话生成一个唯一的 **session ID**（如 `a3f8`，4 字符随机）。所有与该会话相关的 worktree 和状态文件都放在 session 命名空间下：

```
.claude/worktrees/sdd-{session-id}/
├── task-1/         ← implementer-1 的 worktree
├── task-2/         ← implementer-2 的 worktree
└── (session 完成后清理)

.agent-harness/sdd/{session-id}/
├── state.json      ← 会话状态（供 resume 使用）
├── review-task-1.diff
└── review-task-3.diff
```

Orchestrator 在启动时生成 `session-id`，写入 `os.environ["SDD_SESSION_ID"]`。所有子进程（subagent）可以从环境变量读取它。

### 4. 状态节点模型

Orchestrator 维护一份运行期状态，落盘到 `.agent-harness/sdd/{session-id}/state.json`。

```json
{
  "session_id": "a3f8",
  "orchestrator_branch": "feat/my-feature",
  "concurrency_limit": 3,
  "started_at": "2026-07-24T10:00:00Z",
  "session_dir": ".agent-harness/sdd/a3f8",
  "nodes": {
    "task-1": {
      "type": "implement",
      "status": "completed",
      "worktree_path": ".claude/worktrees/sdd-a3f8/task-1",
      "branch": "_sdd/a3f8/task-1",
      "base": "feat/my-feature",
      "blocking": [],
      "file_scope": ["scripts/log.sh", "tests/test-log.sh"],
      "evidence": {
        "review_passed": true,
        "review_diff": ".agent-harness/sdd/a3f8/review-task-1.diff"
      },
      "merge": { "status": "completed", "evidence": "git merge --no-ff 成功" },
      "cleanup": { "worktree_removed": true, "branch_deleted": true },
      "retry_count": 0,
      "intervention": null,
      "retry_findings_history": []
    },
    "task-2": { "...", "blocking": ["task-1"] },
    "task-3": { "status": "in_progress" }
  },
  "fan_in": {
    "status": "pending",
    "depends_on_nodes": ["task-1", "task-3"],
    "integration_test_passed": null
  }
}
```

**节点状态机**：

```
pending → in_progress → completed → merge → cleanup
                    ↘ intervention_needed
```

`blocking` 字段对应 plan 中的 `Blocking: Task N`，orchestrator 用它构建 DAG。

**`retry_findings_history`**：跨 retry 比较 findings 用。每次 review 的结果追加到该数组，`no_progress_detection` 比较最近两次的 findings 是否有重复。

### 5. Orchestrator 工作流

```
orchestrator 启动
│
├─ 0. 生成 session-id，创建 session 目录
│   └─ 写入 state.json（初始状态）
│
├─ 1. 读 plan，解析每个 Task 的 Blocking / files 字段
│
├─ 2. 构建依赖图（DAG），识别第一轮可并行的节点集合
│
├─ 3. 并行阶段循环（每次 dispatch 一轮）：
│   │
│   ├─ 检查 state 找出所有 status=pending 且 blocking 依赖已完成的节点
│   │
│   ├─ 选出前 concurrency_limit 个（不超过上限）
│   │
│   ├─ 对每个选中节点：
│   │   ├─ git worktree add -b _sdd/{session-id}/task-N {orchestrator-branch}
│   │   ├─ 更新 state: nodes.task-N.status = in_progress
│   │   └─ 收集到 dispatch 列表
│   │
│   ├─ **同一 message 中并行 dispatch 所有 implementer**：
│   │   ├─ Agent(implementer-1, ...)
│   │   ├─ Agent(implementer-2, ...)
│   │   └─ ...（并发调用）
│   │
│   ├─ 等待所有 implementer 返回
│   │
│   ├─ 对返回的每个任务，串行处理（因需要 dispatch review agent）：
│   │   ├─ 生成 review package (review-package BASE HEAD)
│   │   ├─ dispatch task reviewer
│   │   │   ├─ review 通过 → 标记 completed，追加 findings 到 history
│   │   │   ├─ review 不通过 → retry_count++
│   │   │   │   ├─ < max_retries → dispatch fix agent → 重新 review
│   │   │   │   └─ >= max_retries → 检查 intervention 条件
│   │   │   └─ file-scope 越界检测：
│   │   │       review-package 对比 diff 的文件列表与 file_scope，
│   │   │       任何越界文件标记为 file_scope_violation
│   │   │       → 严重违规，直接 intervention_needed
│   │   │
│   │   └─ 失败：标记 intervention_needed + 保留分支
│   │
│   └─ 回到步骤 3 开头，继续下一轮 dispatch，直到所有节点完成或被阻止
│
├─ 4. Merge 阶段（串行，按拓扑序）：
│   │
│   ├─ 对每个 review 通过的任务，按拓扑序执行 merge：
│   │   ├─ git merge --no-ff _sdd/{session-id}/task-N
│   │   ├─ 如果冲突：
│   │   │   ├─ dispatch merge-fix subagent
│   │   │   └─ merge-fix 也失败 → intervention_needed
│   │   ├─ 更新 state: merge.status = completed
│   │   ├─ git worktree remove
│   │   ├─ git branch -d（--no-ff 确保安全删除）
│   │   └─ 更新 state: cleanup 子节点 = completed
│   │
│   └─ 所有 merge 完成 → fan_in.status = completed
│
├─ 5. 集成验证：
│   ├─ 跑集成测试 / computational-sensors
│   ├─ 如果测试失败 → dispatch fix agent（非并行，在 orchestrator 分支上直接修）
│   └─ 测试通过 → 进入 finishing-a-development-branch
│
└─ 6. 完成
```

### 6. File-Scope 越界检查（两层防护）

| 层 | 时机 | 机制 |
|----|------|------|
| 事前 | implementer dispatch 时 | `file-scope` 列表注入 implementer prompt，明确限制"你只能改动这些文件" |
| 事后 | review 前自动执行 | review-package 脚本对比 diff 的文件列表 vs `file_scope`，输出差异报告 |

如果事后检查发现越界：
- 标记该 implementer 为 `file_scope_violation`
- 进入 `intervention_needed`（不自动 retry，因为越界是信任问题，不是实现质量）
- Review findings 中附上"以下文件不在 file-scope 范围内"的清单

不需要 pre-commit hook。prompt 限制 + 脚本后检的 KISS 组合已足够。

### 7. 自动修复回环

每个 review→fix→re-review 构成一条回环。回环的约束条件：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `max_retries` | 2 | 同一个节点 review 不通过后自动 retry 的最大次数 |
| `no_progress_detection` | 连续 2 次出现相同 finding | 对比 `retry_findings_history` 最近两次记录 |

**retry 逻辑**：
1. review 发现 N 个 findings
2. findings 追加到 `retry_findings_history`
3. 检查 `no_progress_detection`：如果历史中有 2 次连续相同的 finding → 停止 retry，intervention_needed
4. 否则 dispatch fix subagent（不是重新实现，而是根据 findings 修）
5. 生成新的 review package（增量 diff）
6. re-review：只检查 findings 是否已修复
7. 如果 findings 已修复 → 通过；如果有遗留 → retry_count++

### 8. 人工介入条件

当 retry 回环走不通或出现信任问题时触发。或关系，任一满足即触发：

| 条件 | 检测方式 | 示例 |
|------|----------|------|
| 同一 finding 连续 2 次 retry 仍出现 | 比较 `retry_findings_history` | implementer 反复改不对同一个逻辑错误 |
| merge 冲突涉及同一文件同一区域 | `git merge` 产生 conflict markers，merge-fix agent 无法解决 | Task 1 改 `config.ts` 第 50 行，Task 3 也改同一行 |
| implementer 主动报告"需求矛盾" | implementer 输出中检测信号词 | "Task 要求 A 但前提条件要求 not A" |
| file-scope 越界 | review-package 自动检查 + 标记 | 改日志工具的去改了数据库 schema |

**触发后的行为**：
1. 标记该节点 `intervention_needed` + 记录 `reason` + 保留本地分支
2. 清理 worktree 目录（分支保留，供人工 checkout 查看）
3. 其他未受影响的节点继续运行
4. 最终输出"以下任务需要人工检查"列表

### 9. 恢复协议（Resume）

Orchestrator 崩溃或中断后的恢复流程：

```
恢复流程：
1. 检查 .agent-harness/sdd/ 下是否有 state.json 文件
2. 如果有，读 session_id 和当前所有 nodes 状态
3. 扫描每个节点：
   ├─ status=in_progress:
   │   └─ worktree_path 还在吗？
   │       ├─ 在 → 重新 dispatch implementer（带上已有上下文）
   │       └─ 不在 → 标记 intervention_needed（无法恢复）
   ├─ status=completed 且 merge.status 不为 completed:
   │   └─ 执行 merge（git merge --no-ff）
   ├─ status=completed 且 merge.status=completed 但 cleanup 未完成:
   │   └─ 清理 worktree + 删分支（幂等操作）
   └─ status=pending:
       └─ 保持不变，继续执行
4. 从当前状态继续执行
```

**关键设计**：
- State 文件路径 = `.agent-harness/sdd/{session-id}/state.json`，orchestrator 启动时由 `SDD_SESSION_ID` 环境变量定位。如果 resume 时没有这个环境变量，orchestrator 扫描 `.agent-harness/sdd/` 找最新的 `state.json`
- 所有 git 操作都是幂等的（`git branch -d` 如果分支不存在不会报错；`git worktree remove` 同理）
- Merge 使用 `--no-ff`，保证即使重复 merge 也不会产生重复提交

### 10. 失败隔离

一个任务节点失败不影响其他并行的同批次任务：

- Implementer A 达到 `max_retries` → 标记 `intervention_needed`，implementer B 继续
- Implementer B 成功完成 → 正常 merge，正常进入集成测试
- 集成测试阶段，如果跑不过且 fix agent 也修不好 → 标记 `intervention_needed`，保留当前所有已 merge 的改动
- 并行中有一个必须人工介入 → 不阻塞其他节点继续执行，但最终停在集成验证或 finishing 阶段等人工

### 11. 清理策略

| 生命周期阶段 | worktree | 本地分支 | 说明 |
|-------------|----------|---------|------|
| 创建 | 存在 | 存在 | implementer 正在工作 |
| review 不通过，retry 中 | 保留 | 保留 | 还要 retry |
| review 通过，merge 完成 | 清理 | `git branch -d` | 已集成到 orchestrator 分支（`--no-ff` 保证安全删除） |
| intervention_needed | 清理 | **保留** | 人工可能需要 `git checkout _sdd/{session}/task-N` 查看 |
| orchestrator 崩溃/中断 | 保留 | 保留 | resume 流程处理后清理 |

### 12. 配套改动

| 文件 | 改动范围 |
|------|---------|
| `skills/subagent-driven-development/SKILL.md` | orchestrator prompt 加入 Fan-Out 工作流指令 |
| `skills/subagent-driven-development/implementer-prompt.md` | 加入 worktree 路径参数、file-scope 边界约束 |
| `skills/subagent-driven-development/task-reviewer-prompt.md` | 加入 file-scope 越界检查指令 |
| `skills/subagent-driven-development/scripts/` | 新增 session-init、state 管理、review-package 越界检测 |
| `skills/subagent-driven-development/references/controller-guide.md` | **删除**第 117 行"Dispatch multiple implementation subagents in parallel (conflicts)" 红牌，改为"仅在 plan 标注了 Blocking: none 时可并行" |
| `skills/finishing-a-development-branch/SKILL.md` | `cleanup-workspace` 覆盖 sdd worktree + session 目录 |
| `skills/writing-plans/SKILL.md` | Plan 模板中标注 `Blocking: none` 和可选 `files:` 的编写指导 |

## 不纳入本次范围

- Auto-Loop 的 Fan-Out（auto-loop.sh 已有一套独立的 state 和 worktree 机制，分属不同上下文）
- 跨仓库 SDD（当前 worktree 只支持同一仓库内）
- 动态 re-plan（实施过程中检测到新依赖后动态调整 DAG）
- Read-after-write 自动检测（由 `Blocking:` 标注的手动声明处理）
