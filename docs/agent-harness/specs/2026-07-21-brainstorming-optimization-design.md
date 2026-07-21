---
spec_topic: brainstorming-optimization
decision_summary: "对 brainstorming skill 进行全面优化：引入前沿批次提问、推荐答案、事实/决策分离、决策树映射、Prompt 精简"
design_approved: true
user_approved_at: "2026-07-21T16:00:00+08:00"
gates: [user-review-passed]
---

# Brainstorming Skill 优化设计 Spec

## 背景

对 Matt Pocock's batch-grill-me 进行深度调研后，发现其核心优势在于更高效的提问模式。当前 agent-harness 的 brainstorming skill 流程完整但提问效率偏低、prompt 体积大。本次优化聚焦于加速需求澄清、减少来回次数、精简上下文负载。

## 优化 A：提问模式重构（前沿批次 + 推荐答案 + 事实分离）

### A-1 前沿批次提问

**改动文件**：`skills/brainstorming/SKILL.md` 第 72-81 行（"Understanding the idea" 节）

**现状**：强制"一次一个问题"（第 80 行），导致需求澄清需要 15-20 个来回

**改为**：

```markdown
**Ask clarifying questions:**

- 先建立当前可问问题集（**前沿 frontier**）：列出所有先决条件已满足、可以立即回答的决策
- **批次提问**：一轮中询问整个前沿，每个问题编号，附带推荐答案
- 等待用户回答后，重新计算前沿（已决策的节点开放依赖它的子问题），进入下一轮
- 问题之间若有依赖关系：B 依赖 A 的答案 → B 属于下轮，不在本轮询问
- 不强制每轮必须 3+ 个问题——当实际前沿只有 1 个问题时，仍只问 1 个
```

**删除**：第 183 行 `- **One question at a time**`（与前沿批次冲突）、第 184 行 `- **Multiple choice preferred**`（被推荐答案取代）

### A-2 推荐答案

**现状**：抛出开放问题（"用什么技术栈？"），用户需要自行思考

**改为**：每个前沿问题附带推荐答案——

```
Round 1:
1) 数据存在本地文件还是托管数据库？推荐：本地 JSON 文件，个人工具不需要 DB 运维
2) 需要提醒功能吗？推荐：暂不实现，MVP 优先
3) CLI 还是 Web 界面？推荐：CLI 优先，Web 后加
```

原则：推荐答案必须附理由。用户可接受、修改或否决。目的是给用户一个"默认选项"而非开放大脑风暴。

### A-3 事实是你的工作

**改动**：在"Ask clarifying questions" 节新增独立指令块

```markdown
**事实查证规则：**
- 区分**事实**（fact）和**决策**（decision）
- 事实：能从环境中查到的事——项目文件结构、现有 API 端点、配置文件、代码库模式
- 决策：需要人判断的事——技术选型、业务逻辑、设计取舍
- 事实是你的工作：派生子代理去查，**永远不要问用户**
- 但不要阻塞：子代理在后台跑的同时，你可以继续问已可回答的前沿问题
- 只有依赖于查的事实的问题，才等待子代理结果
```

## 优化 B：决策树映射（可选步骤）

**改动**：在第1步"Explore project context"和第2步"Ask clarifying questions"之间，插入可选步骤；保留现有 scope assessment（"大型任务分段"）逻辑

```markdown
3. **Map decision tree** (optional, complex tasks only)
   - 当需求涉及 3+ 决策维度（技术栈、数据模型、交互方式等），花一小步向用户呈现决策树
   - 用自然语言描述关键分叉点：先决定什么，再决定什么
   - 目的：让用户看到决策的依赖关系，避免过早深入细节
   - 简单需求（1-2 个决策维度）可跳过此步骤
```

**说明**：batching 需要决策树才能工作，所以决策树映射是前沿批次提问的前提。简单需求时模型隐式构建即可，复杂需求显式呈现。

## 优化 C：Prompt 精简 + no-op 清除

### C-1 删除冗余段落

| 段落 | 操作 | 理由 |
|------|------|------|
| `Key Principles`（第 181-188 行） | **删除** | `One question at a time` 已被 A-1 取代；`Multiple choice preferred` 被 A-2 取代；`YAGNI`/`Explore alternatives` 已在步骤中；`Be flexible` 是 no-op |
| `Design for isolation`（第 97-102 行） | **精简为 1-2 句**，移入 `Presenting the design` 节 | 通用设计教导，不必单独成段 |
| `Prefer multiple choice`（第 79 行） | **删除** | 被 A-2 推荐答案取代 |

### C-2 保留内容

- Clarification Loop Circuit-Breaker（第 190-218 行）——**保留**，issue #83 有数据支撑
- Six Forcing Questions（第 220-246 行）——**保留**，特有产品验证能力，但与 A-3 事实规则整合：Six Forcing Questions 只能问决策类问题（"谁有这个问题？"），不能问事实类
- `When domain terms crystallize`（第 28 行）——**保留**，领域建模入口重要
- Spec 校验 + 门禁流程（第 112-179 行）——**保留**，agent-harness 核心集成
- GDD 门禁 + Sprint Contract 流程——**保留**
- Capture Learnings（第 248-256 行）——**保留**，精简措辞

### C-3 前置校验 + 阶段指标

保留现有结构前置校验和阶段指标 emit 逻辑（第 132-155 行），这两项是 agent-harness 基础设施，与 batch-grill-me 无冲突。

## 综合效果对比

| 指标 | 当前 | 优化后 |
|------|------|--------|
| 需求澄清来回次数 | 15-20 轮 | 3-6 轮（2-3 个前沿批次） |
| Prompt 体积 | ~15KB / ~5500 tokens | ~10KB / ~3500 tokens |
| 用户手动回复事实问题 | 常见 | 降为 0 |
| 决策树可见性 | 隐式 | 复杂时显式 |
| 原有关键集成 | 完备 | 全部保留 |
| 提问效率 | 一次一个，无方向 | 前沿批次+推荐答案 |

## 实施顺序

1. A-1 + A-2 + A-3：核心提问模式重构（最影响行为）
2. C：Prompt 精简（删除冗余、收紧措辞）
3. B：决策树映射步骤插入
4. 集成测试：跑 `tests/skill-behavior/brainstorming/run-test.sh`
5. 验证循环检测 cross-reference 不失效
