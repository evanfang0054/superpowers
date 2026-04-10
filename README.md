# Superpowers

[English](README_EN.md)

Superpowers 是一套完整的软件开发工作流，专为 AI 编程助手设计。它基于一系列可组合的"技能（skills）"构建，并通过初始指令确保你的 AI 助手能够正确使用它们。

## 工作原理

当你启动 AI 编程助手时，它不会立即开始写代码。相反，它会退一步，先问你真正想要实现什么。

在通过对话梳理出需求后，它会将设计方案分成易于阅读和理解的小块展示给你。

在你确认设计方案后，AI 助手会制定一个实现计划，这个计划清晰到即使是一个热情但缺乏经验、没有项目背景、不爱写测试的初级工程师也能遵循。它强调真正的红绿测试驱动开发（TDD）、YAGNI（你不会需要它）和 DRY（不要重复自己）原则。

接下来，当你说"开始"后，它会启动*子代理驱动开发*流程，让多个 AI 代理协作完成每个工程任务，检查和审查它们的工作，然后继续推进。Claude 通常可以自主工作几个小时而不偏离你们共同制定的计划。

这只是系统的核心部分，还有更多功能。由于技能会自动触发，你不需要做任何特别的事情。你的 AI 编程助手就拥有了 Superpowers。

## 安装

**注意：** 不同平台的安装方式不同。Claude Code 和 Cursor 有内置的插件市场，Codex 和 OpenCode 需要手动设置。

### Claude Code 官方市场

Superpowers 可通过 [Claude 官方插件市场](https://claude.com/plugins/superpowers) 获取

从 Claude 市场安装插件：

```bash
/plugin install superpowers@claude-plugins-official
```

### Claude Code（通过插件市场）

在 Claude Code 中，先注册市场：

```bash
/plugin marketplace add evanfang0054/superpowers-marketplace
```

然后从该市场安装插件：

```bash
/plugin install superpowers@superpowers-marketplace
```

### Cursor（通过插件市场）

在 Cursor Agent 聊天中，从市场安装：

```text
/add-plugin superpowers
```

或在插件市场中搜索 "superpowers"。

### Codex

告诉 Codex：

```
Fetch and follow instructions from https://raw.githubusercontent.com/evanfang0054/superpowers/refs/heads/main/.codex/INSTALL.md
```

**详细文档：** [docs/README.codex.md](docs/README.codex.md)

### OpenCode

告诉 OpenCode：

```
Fetch and follow instructions from https://raw.githubusercontent.com/evanfang0054/superpowers/refs/heads/main/.opencode/INSTALL.md
```

**详细文档：** [docs/README.opencode.md](docs/README.opencode.md)

### GitHub Copilot CLI

```bash
copilot plugin marketplace add evanfang0054/superpowers-marketplace
copilot plugin install superpowers@superpowers-marketplace
```

### Gemini CLI

```bash
gemini extensions install https://github.com/evanfang0054/superpowers
```

更新：

```bash
gemini extensions update superpowers
```

### 验证安装

在你选择的平台上启动新会话，请求一些应该触发技能的操作（例如，"帮我规划这个功能"或"让我们调试这个问题"）。AI 助手应该会自动调用相关的 superpowers 技能。

## 基本工作流程

1. **brainstorming（头脑风暴）** - 在写代码之前激活。通过提问细化粗略想法，探索替代方案，分段展示设计供验证。保存设计文档。

2. **using-git-worktrees（使用 Git 工作树）** - 在设计批准后激活。在新分支上创建隔离的工作空间，运行项目设置，验证测试基线。

3. **writing-plans（编写计划）** - 在设计批准后激活。将工作分解为小任务（每个 2-5 分钟）。每个任务都有精确的文件路径、完整的代码和验证步骤。

4. **subagent-driven-development（子代理驱动开发）** 或 **executing-plans（执行计划）** - 有计划时激活。为每个任务分派新的子代理，进行两阶段审查（规格合规性，然后代码质量），或分批执行并设置人工检查点。

5. **test-driven-development（测试驱动开发）** - 在实现过程中激活。强制执行红-绿-重构循环：编写失败的测试，观察失败，编写最少代码，观察通过，提交。删除在测试之前编写的代码。

6. **requesting-code-review（请求代码审查）** - 在任务之间激活。根据计划审查，按严重程度报告问题。关键问题会阻止进度。

7. **finishing-a-development-branch（完成开发分支）** - 在任务完成时激活。验证测试，提供选项（合并/PR/保留/丢弃），清理工作树。

**AI 助手在执行任何任务前都会检查相关技能。** 这是强制性的工作流程，而非建议。

## 包含内容

### 技能库

**测试**
- **test-driven-development** - 红-绿-重构循环（包含测试反模式参考）

**调试**
- **systematic-debugging** - 4 阶段根因分析流程（包含根因追踪、纵深防御、基于条件的等待技术）
- **verification-before-completion** - 确保问题真正修复

**协作**
- **brainstorming** - 苏格拉底式设计细化（含 6 个强制性问题框架）
- **writing-plans** - 详细的实现计划
- **executing-plans** - 带检查点的批量执行
- **dispatching-parallel-agents** - 并发子代理工作流
- **requesting-code-review** - 预审查清单
- **receiving-code-review** - 响应反馈
- **using-git-worktrees** - 并行开发分支
- **finishing-a-development-branch** - 合并/PR 决策工作流
- **subagent-driven-development** - 快速迭代，两阶段审查（规格合规性，然后代码质量）

**文档与运维**
- **documentation-sync** - 代码变更后自动同步文档
- **post-deploy-monitoring** - 部署后健康检查和监控
- **retrospective** - 工程回顾，分析工作成果和改进点

**知识管理**
- **session-learnings** - 跨 Session 知识积累和复用

**元技能**
- **writing-skills** - 按照最佳实践创建新技能（包含测试方法论）
- **using-superpowers** - 技能系统介绍

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
/plugin update superpowers
```

## 许可证

MIT 许可证 - 详见 LICENSE 文件

## 支持

- **Issues**: https://github.com/evanfang0054/superpowers/issues

## 致谢

本项目基于 [Jesse Vincent](https://github.com/obra) 的 [Superpowers](https://github.com/obra/superpowers) 项目开发。感谢原作者创建了如此优秀的项目。
