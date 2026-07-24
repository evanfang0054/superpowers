# Agent Harness

[English](README_EN.md)

Agent Harness 是一套完整的软件开发工作流，专为 AI 编程助手设计。它基于一系列可组合的"技能（skills）"构建，并通过初始指令确保你的 AI 助手能够正确使用它们。

## 工作原理

当你启动 AI 编程助手时，它不会立即开始写代码。相反，它会退一步，先问你真正想要实现什么。

在通过对话梳理出需求后，它会将设计方案分成易于阅读和理解的小块展示给你。

在你确认设计方案后，AI 助手会制定一个实现计划，这个计划清晰到即使是一个热情但缺乏经验、没有项目背景、不爱写测试的初级工程师也能遵循。它强调真正的红绿测试驱动开发（TDD）、YAGNI（你不会需要它）和 DRY（不要重复自己）原则。

接下来，当你说"开始"后，它会启动*子代理驱动开发*流程，让多个 AI 代理协作完成每个工程任务，检查和审查它们的工作，然后继续推进。Claude 通常可以自主工作几个小时而不偏离你们共同制定的计划。

这只是系统的核心部分，还有更多功能。由于技能会自动触发，你不需要做任何特别的事情。你的 AI 编程助手就拥有了 Agent Harness。

## 安装

**注意：** 不同平台的安装方式不同。Claude Code 和 Cursor 有内置的插件市场，Codex 和 OpenCode 需要手动设置。

### Claude Code 官方市场

Agent Harness 可通过 [Claude 官方插件市场](https://claude.com/plugins/agent-harness) 获取

从 Claude 市场安装插件：

```bash
/plugin install agent-harness@claude-plugins-official
```

### Claude Code（通过插件市场）

在 Claude Code 中，先注册市场：

```bash
/plugin marketplace add evanfang0054/agent-harness-marketplace
```

然后从该市场安装插件：

```bash
/plugin install agent-harness@agent-harness-marketplace
```

### Cursor（通过插件市场）

在 Cursor Agent 聊天中，从市场安装：

```text
/add-plugin agent-harness
```

或在插件市场中搜索 "agent-harness"。

### Codex App

在 Codex App 侧边栏点击 **Plugins**，在 **Coding** 区找到 `Agent Harness`，点击 `+` 安装。

### Codex CLI

打开插件搜索界面 `/plugins`，搜索 `agent-harness`，选择 `Install Plugin`。

**详细文档：** [docs/README.codex.md](docs/README.codex.md)

### Pi

从 GitHub 仓库安装：

```bash
pi install git:github.com/evanfang0054/agent-harness
```

本地开发模式：

```bash
pi -e /path/to/agent-harness
```

**详细文档：** [docs/README.pi.md](docs/README.pi.md)

### OpenCode

告诉 OpenCode：

```
Fetch and follow instructions from https://raw.githubusercontent.com/evanfang0054/agent-harness/refs/heads/main/.opencode/INSTALL.md
```

**详细文档：** [docs/README.opencode.md](docs/README.opencode.md)

### GitHub Copilot CLI

```bash
copilot plugin marketplace add evanfang0054/agent-harness-marketplace
copilot plugin install agent-harness@agent-harness-marketplace
```

### Gemini CLI

```bash
gemini extensions install https://github.com/evanfang0054/agent-harness
```

更新：

```bash
gemini extensions update agent-harness
```

### 验证安装

在你选择的平台上启动新会话，请求一些应该触发技能的操作（例如，"帮我规划这个功能"或"让我们调试这个问题"）。AI 助手应该会自动调用相关的 agent-harness 技能。

## 工作流概览

Agent Harness 采用分层架构：**决策层**确保"做对的事"，**执行层**确保"把事做对"，**质量层**确保"做得好"。

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           决策层（Decision Layer）                            │
│                         "该不该做？怎么定方向？"                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐      ┌─────────────────┐      ┌─────────────────┐        │
│   │office-hours │ ───► │ plan-ceo-review │ ───► │ plan-eng-review │        │
│   │ "值得做吗?" │      │  "10星产品?"    │      │  "架构可行?"    │        │
│   └─────────────┘      └─────────────────┘      └─────────────────┘        │
│         │                                              │                    │
│         │ 🟢 值得做                                     │ ✅ 架构锁定         │
│         ▼                                              ▼                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           执行层（Execution Layer）                           │
│                            "怎么设计？怎么实现？"                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐  ┌────────────────┐  ┌─────────────┐  ┌───────────────┐  │
│   │brainstorming│─►│ gate-driven-   │─►│writing-plans│─►│subagent-dev / │  │
│   │ "怎么设计?" │  │ test-design *  │  │ "拆分任务"  │  │ exec-plans    │  │
│   └─────────────┘  └────────────────┘  └─────────────┘  └───────────────┘  │
│                     * 可选：递归生成                                       │
│                       测试金字塔                                          │
│                                                         │                   │
│   ┌─────────────────────────────────────────────────────┼───────────────┐  │
│   │                    实现循环                          ▼               │  │
│   │  ┌─────┐  ┌───────────┐  ┌─────────────┐  ┌──────┐  ┌─────────┐   │  │
│   │  │ TDD │─►│comp-sensor│─►│code-review  │─►│verify│─►│finishing│   │  │
│   │  └─────┘  └───────────┘  └─────────────┘  └──────┘  └─────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ harness-init (初始化) · harness-design (原型) · harness-optimizer   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            质量层（Quality Layer）                            │
│                              "做得好不好？"                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐      ┌─────────────────────┐      ┌─────────────────┐    │
│   │ qa-testing  │ ───► │ post-deploy-monitor │ ───► │  retrospective  │    │
│   │ "找bug修bug"│      │   "部署后监控"      │      │   "复盘改进"    │    │
│   └─────────────┘      └─────────────────────┘      └─────────────────┘    │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ trace-analysis (跨 Session 失败模式分析)                             │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**核心理念：** 决策层把关"前门"（确保方向正确），执行层管"车间"（确保实现规范），质量层守"后门"（确保交付质量）。`sprint-contract` 确保设计到计划间有明确的完成标准，`computational-sensors` 在代码审查前跑确定性检查，`trace-analysis` 从历史数据中发现反复出现的失败模式。

## 基本工作流程

1. **brainstorming（头脑风暴）** - 在写代码之前激活。通过提问细化粗略想法，探索替代方案，分段展示设计供验证。保存设计文档。

2. **sprint-contract（冲刺合约）** - 在设计批准后、编写计划前激活。协商明确的完成标准（Definition of Done），防止模糊的验收条件。

3. **writing-plans（编写计划）** - 在冲刺合约确认后激活。将工作分解为小任务（每个 2-5 分钟）。每个任务都有精确的文件路径、完整的代码和验证步骤。

4. **subagent-driven-development（子代理驱动开发）** 或 **executing-plans（执行计划）** - 有计划时激活。两者均由 ralph-loop 驱动确保完成。subagent-driven-development 作为协调者派发子代理（实现 → 统一审查），executing-plans 在主 session 内直接执行。均支持用户自定义额外规则。SDD 采用 v6.0 统一审查机制：单一 `task-reviewer` 一次返回规格合规 + 代码质量双 verdict，配合 `scripts/task-brief` 和 `scripts/review-package` 把任务文本与 diff 写入文件，避免控制器上下文污染。**SDD Fan-Out（v6.5.0+）**：当 plan 标注 `Blocking: none` 时，orchestrator 可并行 dispatch 多个 implementer 在隔离 worktree 中工作，完成后自动 merge。

5. **test-driven-development（测试驱动开发）** - 在实现过程中激活。强制执行红-绿-重构循环：编写失败的测试，观察失败，编写最少代码，观察通过，提交。删除在测试之前编写的代码。

6. **computational-sensors（计算传感器）** - 在代码审查前激活。运行 lint、类型检查、测试、覆盖率等确定性检查，为语义审查提供计算证据。

7. **requesting-code-review（请求代码审查）** - 在任务之间激活。根据计划审查，按严重程度报告问题。关键问题会阻止进度。

8. **finishing-a-development-branch（完成开发分支）** - 在任务完成时激活。验证测试，提供选项（合并/PR/保留/丢弃）。

**AI 助手在执行任何任务前都会检查相关技能。** 这是强制性的工作流程，而非建议。

## Auto-Loop：全自动自我提升闭环

`scripts/auto-loop.sh` 是一个独立的自动化工具，不依赖 skill 自动触发，需要手动运行。它把「从会话发现问题 → 提 issue → SDD 修复 → PR」这条链路完全自动化。

### 快速开始

```bash
# 分析当前项目今天的会话，找出问题、修复、提 PR
./scripts/auto-loop.sh "分析今天的会话，找出问题并修复"

# 扫描指定项目
./scripts/auto-loop.sh --project ~/code/my-app "分析本周会话"

# 扫描所有项目（~/.claude/projects/）
./scripts/auto-loop.sh --all-projects "找出所有项目最近的问题"

# 只分析特定类型的会话（自然语言筛选）
./scripts/auto-loop.sh --filter "调用了 superpower 相关 skill" "只盘点相关会话"

# 只分析+提 issue，不修复（dry-run）
./scripts/auto-loop.sh --dry-run "分析今天的会话"

# 跳过分析，直接修复指定 issue（fix-only）
./scripts/auto-loop.sh --fix-only "#12,#15"

# 拉取所有 open issues 修复（最多 10 个）
./scripts/auto-loop.sh --fix-only "all" --max-issues 10

# 恢复中断的运行
./scripts/auto-loop.sh --resume

# 清理 state 和 worktree
./scripts/auto-loop.sh --cleanup
```

### 工作流程

```
你输入一句话需求
    ↓
[1] 创建 git worktree（隔离工作区，不碰当前目录）
    ↓
[2] 调用 claude-code-log 导出筛选后的会话内容
    ↓
[3] Claude 分析会话，识别问题模式
    ↓
[4] 自动提 issue 到 evanfang0054/agent-harness
    ↓
[5] 逐个 issue 走 SDD 修复（brainstorming → writing-plans → 实现）
    ↓
[6] 验证 → push → 创建 PR（关联 closes #N）
    ↓
清理 worktree，输出 PR 链接，等你审核
```

### 特性

- **git worktree 隔离** — 所有修复在独立 worktree 进行，当前工作区零污染
- **断点恢复** — 任何中断（崩溃/休眠/Ctrl+C）后 `--resume` 从断点继续
- **三层可观测性** — 实时事件流 + 心跳检测 + 完整日志文件，绝不静默卡死
- **介入协议** — 遇到 4 种触发点（不可逆风险/矛盾/低置信度/架构变更）自动退出等待人类决策
- **最保守决策** — AI 在所有决策点取最小改动、最低风险方案
- **自保护机制** — PreToolUse hook (`guard-auto-loop.sh`) 拦截 Claude 误删自身运行态的命令，防止"自毁"

### 实际运行效果

在项目自身的实战测试中，auto-loop 已自动发现并修复了 30+ 个 shell 脚本 bug（涵盖 Python 源码注入、信号路径资源泄漏、set -u 边界、frontmatter 边界污染等），全部由 Claude 自主识别 → 提 issue → SDD 修复 → push → 创建 PR。平均单轮运行 15-40 分钟，输出一个可直接审核的 PR。

详见 [设计文档](docs/agent-harness/specs/2026-06-24-auto-loop-self-improvement-design.md)。

## Harness Engineering：可观测、可校验、可诊断的工程层

Agent Harness 不仅是一组 skill 的集合，更在模型外搭建了一层工程环境，让 AI 在你的工程体系里能**可执行、可约束、可验证、可反馈**地持续工作。这层被业界称为 Harness Engineering——不是教模型"怎么回答"，而是设计模型"怎么工作"（`Agent = Model + Harness`）。

围绕三层工作流，agent-harness 提供四个互相咬合的子系统：

| 子系统 | 解决的问题 | 关键产物 |
|---|---|---|
| **可监测性** | 把阶段门禁、耗时等可记录信号从零散感受沉淀为可查询数据 | `.agent-harness/phase-metrics.jsonl` + `log-phase-metric.sh` / `query-phase-metrics.sh`；在显式接入的阶段记录 `gate_result`、`duration_ms`，并在可用时保留 token / cost 字段 |
| **协议层契约** | skill 间交接从"自然语言软校验"升级为"机器可校验的 schema 前置" | spec / plan / task 三交接点 YAML frontmatter + `validate-handoff.sh` 硬前置校验；与现有 reviewer 子代理并行不替代 |
| **知识库 / 上下文** | 上下文注入从"塞得越多越好"变成"每一步只送该看见的那一片" | 顶级 `index.md` + 各子目录二级索引 + `glossary.md`（SSOT）；SessionStart 只加一行指路，不爆 token |
| **失败自愈** | 失败处理从"报警 + 人工介入"升级为"诊断报告 → 可执行修复任务"闭环 | `diagnose-failure.sh` 收敛 loop / gate / test 三类失败信号为结构化 JSON + `write-diagnosis-task.sh` 回写为 task；不自动执行，闭环可被人工打断 |

**四个子系统的咬合点：**

- 协议层的 `gate_result` 由 `validate-handoff.sh` 驱动，emit 到 phase-metrics
- 协议层的 `spec_topic` 必须命中知识库的 `index.md`，否则硬前置退回
- 失败自愈的信号源复用 phase-metrics 与知识库的 learnings 索引，命中相似历史故障

设计文档见 `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md`，四个实施 plan 在 `docs/agent-harness/plans/2026-06-29-*.md`。

## 包含内容

### 技能库

**测试**
- **test-driven-development** - 红-绿-重构循环（包含测试反模式参考）

**调试**
- **systematic-debugging** - 4 阶段根因分析流程（包含根因追踪、纵深防御、基于条件的等待技术）
- **verification-before-completion** - 确保问题真正修复
- **loop-detection** - 检测代理反复编辑同一文件无法收敛的死循环

**决策层**（灵感来自 gstack）
- **office-hours** - YC 办公时间模式，回答"该不该做"，六个强迫性问题验证想法
- **plan-ceo-review** - CEO 视角战略审查，10 星思维，挑战前提
- **plan-eng-review** - 工程经理架构审查，锁定技术方案

**协作**
- **brainstorming** - 苏格拉底式设计细化（含 6 个强制性问题框架）
- **gate-driven-test-design** - 头脑风暴后、编写计划前，从设计 spec 递归生成基于风险的测试覆盖树（Level Items + Gates + Assertions），树状结构天然构成测试金字塔
- **writing-plans** - 详细的实现计划
- **sprint-contract** - 头脑风暴后、编写计划前协商明确的完成标准
- **executing-plans** - Ralph-loop 驱动执行，强制 TDD/Review/完成流程，支持自定义规则
- **dispatching-parallel-agents** - 并发子代理工作流
- **requesting-code-review** - 预审查清单
- **receiving-code-review** - 响应反馈
- **finishing-a-development-branch** - 合并/PR 决策工作流
- **subagent-driven-development** - Ralph-loop 驱动协调者模式，派发子代理 + v6.0 统一审查（单 reviewer 双 verdict，`task-brief` / `review-package` 脚本支撑）。v6.5.0+ 支持 Fan-Out：plan 中 `Blocking: none` 的任务可并行 dispatch，隔离 worktree 实现，自动 merge
- **computational-sensors** - 在语义审查前运行确定性检查（lint/类型检查/测试/覆盖率）

**质量保证**
- **qa-testing** - 系统化 QA 测试 Web 应用，自动修复 bug 并提交
- **trace-analysis** - 跨 Session 失败模式分析，基于历史 learnings 数据

**文档与运维**
- **documentation-sync** - 代码变更后自动同步文档
- **post-deploy-monitoring** - 部署后健康检查和监控
- **retrospective** - 工程回顾，分析工作成果和改进点

**自动化**
- **generate-issues** - 分析 Claude Code 会话并生成 GitHub issues（封装 auto-loop --dry-run）
- **fix-issues-and-pr** - 拉取已有 issues 并用 SDD 修复，多 issue 单 PR（封装 auto-loop --fix-only）

**知识管理**
- **session-learnings** - 跨 Session 知识积累和复用

**元技能**
- **writing-skills** - 按照最佳实践创建新技能（包含测试方法论）
- **using-agent-harness** - 技能系统介绍

**Harness 工具**
- **harness-init** - 初始化项目 harness 配置，支持 React/Python/Go 等技术栈模板
- **harness-design** - HTML 高保真原型与交互 Demo 设计能力
- **harness-optimizer** - 基于会话分析优化项目 workflow、skill 或 harness

## 设计理念

- **测试驱动开发** - 始终先写测试
- **系统化优于临时方案** - 流程优于猜测
- **降低复杂性** - 简单是首要目标
- **证据优于声明** - 在宣布成功之前先验证

## 贡献

技能直接存放在此仓库中。要贡献代码：

1. Fork 此仓库
2. 为你的技能创建分支
3. 按照 `writing-skills` 技能创建和测试新技能
4. 提交 PR

完整指南请参阅 `skills/writing-skills/SKILL.md`。

## 更新

当你更新插件时，技能会自动更新：

```bash
/plugin update agent-harness
```

## 许可证

MIT 许可证 - 详见 LICENSE 文件

## 支持

- **Issues**: https://github.com/evanfang0054/agent-harness/issues

## 致谢

本项目基于 [Jesse Vincent](https://github.com/obra) 的 [Superpowers](https://github.com/obra/superpowers) 项目开发。感谢原作者创建了如此优秀的项目。
