# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 你是谁，在哪

你正在编辑 **Agent Harness** 的 `skills/` 目录。这里存放的不是编译型代码，而是 **行为塑造型 skill 文档**（Markdown）—— 每个 skill 是一个目录，核心是 `SKILL.md`（带 YAML frontmatter），可附带子代理提示、参考资料、脚本。

顶层 `../CLAUDE.md` 是项目宪法（AI Agent 贡献规则、PR 拒绝红线、跨平台架构）。**本文件只补充 skill 本地开发的具体规则**，与顶层文档冲突时以顶层为准。动手前请先读完顶层 `CLAUDE.md` 的 "如果你是一个 AI Agent" 一节。

## 目录结构

```
skills/
├── <skill-name>/
│   ├── SKILL.md                     # 唯一入口（YAML frontmatter + Markdown 指令）
│   ├── *.md                         # 辅助资料（子代理提示、参考资料）
│   ├── examples/                    # 示例（可选）
│   └── *.sh / *.js / *.dot          # 脚本与图表（可选）
└── CLAUDE.md                        # 本文件
```

共 29 个 skill，围绕三层工作流组织（决策 / 执行 / 质量），详见顶层 CLAUDE.md 的 "高层架构"。

## SKILL.md 格式

```markdown
---
name: <kebab-case-name>              # 必须等于目录名
description: Use when ...            # 触发条件，决定模型何时自动调用
# 可选字段：
# when_to_use: ...                  # 更详细的触发说明
# argument-hint: ...                # slash 命令参数提示
# disable-model-invocation: true    # 禁止自动调用，仅显式 /skill
# effort: ...                       # 提示词强度
---

# Skill 标题

## Overview / When to Use / ...
```

## 核心规则

1. **Skills 是代码，不是文档。** 每一行都会被注入会话上下文、塑造 agent 行为。修改前先读 `writing-skills/SKILL.md` —— 它把 skill 开发映射成 TDD（RED-GREEN-REFACTOR）。
2. **没有评估证据，不要改已调优的内容。** 跨多会话做对抗性压力测试，在 PR 中展示前后对比。这是顶层 CLAUDE.md 明确的拒绝红线。
3. **一个 skill 一个目录，`name` 字段 = 目录名。** 目录自包含，辅助文件与 SKILL.md 同级。
4. **不要新增第三方依赖**（除非为了支持新 harness）。
5. **不要把项目特定 / 个人配置塞进 skill。** 这类内容应放独立插件或项目级 CLAUDE.md。
6. **KISS / YAGNI 优先于 SOLID。** 描述触发条件要具体，不要预留无需求的通用扩展点。

## 开发与测试 Skill

### 改动流程（TDD for skills）
1. **RED**：写压力场景（子代理提示 + 任务），在**没有** skill 时跑一遍，记录 agent 的违规与 rationalization。
2. **GREEN**：写 / 改 skill 文档，只针对观察到的违规补最小内容。
3. **REFACTOR**：堵漏洞，保持 agent 合规。
4. 参考工具：`writing-skills/testing-skills-with-subagents.md`、`writing-skills/anthropic-best-practices.md`。

### 运行测试
```bash
# 单 skill headless 行为测试（消耗 Claude API 配额，约 1-3 分钟）
cd tests/skill-behavior/<skill-name> && ./run-test.sh

# 全部 skill 行为测试（约 15-40 分钟）
cd tests/skill-behavior && ./run-all-tests.sh

# skill 加载测试（快）
cd tests/claude-code && ./run-skill-tests.sh
```

> `tests/skill-behavior/` 与 `tests/claude-code/` 在仓库根目录，不在 `skills/` 内。

## 贡献前置清单

提交 PR 前（顶层 CLAUDE.md "核心贡献规则" 的本地化）：

- [ ] 改动前已读 `writing-skills/SKILL.md`
- [ ] 已有 baseline（无 skill 时 agent 表现），不是凭空修改
- [ ] 改动针对观察到的具体问题，不是推测性优化
- [ ] 没有引入新依赖或项目特定配置
- [ ] PR 模板 `.github/PULL_REQUEST_TEMPLATE.md` 每段都有真实内容
- [ ] 已搜索已有 PR，排除重复
- [ ] 至少一个 harness 已测试并报告结果

## Git 规范

- Commit 格式：`<type>(<scope>): <subject>`
- 类型：`feat | fix | docs | refactor | test | chore`
- 示例 scope：`skill-behavior`、`writing-skills`、`brainstorming`
- 分支：`feat/*` / `fix/*` / `chore/*`（参考当前 `feat/skill-tests`）

## 不要做

- 不要为 "合规" 而重写已调优 skill 文案 —— 除非有评估证据。
- 不要批量 / 捆绑无关 skill 改动到一个 PR。一个 PR 一个问题。
- 不要伪造问题描述或虚构功能。
