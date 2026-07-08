# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作提供指导。

## 如果你是一个 AI Agent

停下来，在做任何事之前先读完本节。

本仓库的 PR 拒绝率高达 94%。几乎所有被拒绝的 PR 都是由没有阅读或没有遵循这些指南的 Agent 提交的。维护者会在几小时内关闭低质量 PR，公开评论如 "This pull request is slop that's made of lies."

**你的职责是保护你的人类搭档免遭这种尴尬。** 提交低质量 PR 没有帮助——它浪费维护者的时间，损害你搭档的声誉，而且 PR 最终会被关闭。那不是在帮忙，那是在制造尴尬。

## 项目概述

**Agent Harness** 是一套完整的 AI 辅助软件开发工作流，以插件形式分发，支持多个 AI 编码助手（Claude Code、Cursor、Codex、OpenCode、GitHub Copilot CLI、Gemini CLI）。核心是一组行为塑造型 "skills"（markdown 文件）加上基于 shell 的 hooks 和 learnings 基础设施——不是编译型应用。基于 Jesse Vincent 的原版 [Superpowers](https://github.com/obra/superpowers) 项目。

- 顶层 `package.json` 极简（仅一个 `release` 脚本）。无构建步骤、无顶层 lint、无顶层测试运行器。
- `AGENTS.md` 是指向本文件的符号链接——编辑本文件即可同步。

## 常用命令

### Skill 测试（在 `tests/claude-code/` 目录下运行）
- `./run-skill-tests.sh` — 快速 skill 加载测试，使用 Claude Code CLI headless 模式 (`claude -p`)
- `./run-skill-tests.sh --integration` — 集成测试
- `./run-skill-tests.sh --test <test-file>` — 运行单个测试
- `./run-skill-tests.sh --verbose` — 详细输出
- 测试工具函数在 `tests/claude-code/test-helpers.sh`：`run_claude`、`assert_contains`、`assert_not_contains`、`assert_count`、`assert_order`

### 其他测试套件
- `tests/plugin-infrastructure/run-all.sh` — 纯脚本套件，秒级完成，覆盖 hooks/scripts/manifest/commands/agents
- `tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` — Codex plugin manifest 一致性测试
- `tests/explicit-skill-requests/run-all.sh` — 多轮显式 skill 调用测试（依赖 `claude -p` headless 模式实际调用 Claude API）
- `tests/skill-triggering/run-all.sh` — 隐式 skill 触发测试（依赖 `claude -p` headless 模式实际调用 Claude API）
- `tests/learnings-scripts/test-learnings.sh` — learnings shell 脚本测试
- `tests/phase-metrics-scripts/run-all.sh` — phase-metrics 脚本测试
- `tests/knowledge-base-scripts/run-all.sh` — knowledge-base 脚本测试
- `tests/handoff-scripts/run-all.sh` — handoff schema 校验测试
- `tests/diagnose-scripts/run-all.sh` — 失败诊断脚本测试
- `tests/subagent-driven-dev/run-test.sh` — SDD 端到端测试，使用示例项目（依赖 `claude -p` headless 模式实际调用 Claude API）
- `tests/skill-behavior/` — 全部 skill 的 headless 行为测试（依赖 `claude -p` + Claude API 配额，全量运行约 15-40 分钟；单 skill 可独立运行 `cd tests/skill-behavior/<skill> && ./run-test.sh`）
- `tests/pi/` — Pi 平台扩展测试，运行：`npx tsx --test tests/pi/test-pi-extension.mjs`

> 注：`explicit-skill-requests` / `skill-triggering` / `subagent-driven-dev` 套件需要消耗 Claude API 配额并在 headless 模式下真实触发 skill 行为，结果取决于模型当前行为，非纯脚本断言。

### 发布
- `npm run release`（执行 `./scripts/bump-version.sh`）

### Auto-Loop（`scripts/auto-loop.sh`）

全自动会话分析→提 issue→SDD 修复→PR 闭环。把 Claude 当「主大脑」放在一个独立 git worktree 里跑 `claude -p`，通过 stream-json 输出解析信号驱动主循环。

**常用调用：**
```bash
./scripts/auto-loop.sh "<自然语言需求>"            # 扫描当前仓库
./scripts/auto-loop.sh --project <path> "<需求>"   # 扫描指定项目
./scripts/auto-loop.sh --all-projects "<需求>"     # 扫描 ~/.claude/projects/
./scripts/auto-loop.sh --filter "<条件>" "<需求>"  # 自然语言筛选会话（如"调用了 superpower 相关 skill"）
./scripts/auto-loop.sh --resume                    # 从中断点恢复（Ctrl+C 后）
./scripts/auto-loop.sh --dry-run "<需求>"          # 只分析+提 issue，不做 SDD 修复
./scripts/auto-loop.sh --fix-only "#12,#15"         # 跳过分析，直接修复指定 issue
./scripts/auto-loop.sh --fix-only "all"              # 拉取所有 open issues 修复
./scripts/auto-loop.sh --dry-run --max-issues 5      # 最多提 5 个 issue
./scripts/auto-loop.sh --cleanup                   # 清理 state.json 和所有 worktree
```

**前置依赖：** `claude` CLI、`gh`（已 `gh auth login`）、`jq`、`uv`/`uvx`（跑 `claude-code-log`）。

**运行态文件（绝不入 git）：**
- `.claude/auto-loop/state.json` — 每步 checkpoint，用 `jq` 更新（不要文本编辑器直改），`--resume` 读它续跑
- `.claude/auto-loop/runs/<run_id>/` — 单次运行的 artifacts（sessions.md / analysis.json / issues.json / stream.log）
- `.claude/worktrees/auto-loop-<run_id>/` — 隔离 worktree，正常完成会自动清理；Ctrl+C / 介入 / 失败时保留以便排查

**关键信号（Claude 在 result 文本里输出，主循环检测后路由）：**
- `AUTO_LOOP_COMPLETE` — 正常完成，清理 worktree
- `AUTO_LOOP_INTERVENTION_NEEDED` — 请求人工介入（写 state.intervention），保留 worktree
- `AUTO_LOOP_PUSH_FAILED` / `AUTO_LOOP_STATE_ERROR` — 失败保留 worktree，`--resume` 续跑

**自毁防护：** `scripts/guard-auto-loop.sh` 是 PreToolUse hook（`hooks/hooks.json` 注册）。`auto-loop.sh` 在派发 Claude 时导出 `AUTO_LOOP_ACTIVE=1`，hook 拦截任何 `rm -rf .claude/auto-loop` / `git worktree remove` / 自调 `auto-loop.sh` 的命令。日常开发不受影响（环境变量未设时 hook 直接放行）。

**模块拆分：**
- `scripts/lib/state.sh` — `state_init` / `state_get` / `state_set`（jq 安全注入）
- `scripts/lib/worktree.sh` — `worktree_create`（分支重名/已存在自动复用）/ `worktree_remove` / `worktree_cleanup_all`
- `scripts/lib/observe.sh` — `process_line`（解析 stream-json）、`emit_event`（三层可观测性）、`check_heartbeat`（30s 心跳，通过 `HEARTBEAT_TIMESTAMP_FILE` 解决子 shell 变量隔离）
- `skills/auto-loop/orchestrator-prompt.md` — 注入 Claude 的主大脑指令（含生存规则、state.json 操作协议、8 步链路、会话筛选协议），由 auto-loop.sh 用 jq `gsub` 填充 `{{REQUEST}}` / `{{SCOPE}}` / `{{BRANCH}}` / `{{STATE_FILE}}` / `{{REPO_ROOT}}` / `{{FILTER}}` / `{{MODE}}` / `{{TARGET_ISSUES}}` / `{{MAX_ISSUES}}` 占位符

**开发注意：**
- 修改 orchestrator-prompt.md 后，至少跑一次 `./scripts/auto-loop.sh --dry-run "测试"` 验证占位符填充正确
- 新增信号必须在 `observe.sh` 的 `process_line` 里加 grep 分支，否则主循环检测不到
- 新增 `{{PLACEHOLDER}}` 必须同时在 auto-loop.sh 的 jq `gsub` 调用里添加对应分支
- `--fix-only` 与 `--dry-run` 互斥（脚本侧 check_mode_mutex 校验）
- `--filter` 条件会持久化到 state.json，`--resume` 时自动读取（除非 CLI 显式覆盖）
- 不要把 state.json 纳入 git 跟踪，会污染 PR diff（仅 `--resume` 读本地文件，不跨机器同步）

### Demo 项目（`demo/fruit-shop/`）
Demo 是一个独立的全栈 monorepo（pnpm workspace）。在 demo 目录内运行命令；它有自己的 `CLAUDE.md` 提供详细指导。顶层 agent-harness 的开发工作通常不应触碰 demo。

## 高层架构

项目围绕 **三层开发工作流** 组织：

1. **决策层**（"要不要做？"）：`office-hours` → `plan-ceo-review` → `plan-eng-review`
2. **执行层**（"怎么做？"）：`brainstorming` → `sprint-contract` → `writing-plans` → `subagent-driven-development` / `executing-plans`
   - 内循环：`test-driven-development` → `computational-sensors` → `requesting-code-review` → `verification-before-completion` → `finishing-a-development-branch`
3. **质量层**（"做得好不好？"）：`qa-testing` → `post-deploy-monitoring` → `retrospective` → `trace-analysis`

### 关键架构模式

- **Skills（`skills/<name>/SKILL.md`）** — 每个 skill 是一个目录，包含 `SKILL.md`（YAML frontmatter：`name`、`description`、`when_to_use`，可选 `argument-hint`、`disable-model-invocation`、`effort`）加 markdown 指令。通过 `Skill` 工具调用，根据上下文自动触发。许多 skill 带有辅助文件（子代理提示、参考资料、脚本）。
- **插件打包（`.claude-plugin/`）** — `plugin.json` + `marketplace.json` 使 agent-harness 可作为 Claude Code 插件安装。多平台支持内置于 hook 层。
- **Hooks（`hooks/`）** — 会话生命周期管理。`hooks/hooks.json`（Claude Code）和 `hooks/hooks-cursor.json`（Cursor）定义 `sessionStart` 和 `Stop` 钩子。`hooks/session-start` 读取 `using-agent-harness` skill 内容及项目 learnings（`.agent-harness/learnings.jsonl`），以平台特定格式（Cursor / Claude Code / Copilot CLI）输出 JSON。`hooks/stop-hook.sh` 在会话结束时运行。
- **Learnings（`.agent-harness/learnings.jsonl` + `scripts/*learnings.sh`）** — 持久化的项目知识，通过 session-start hook 注入每个新会话。使用 `session-learnings` skill 添加条目；不要手动编辑 JSONL 文件。
- **子代理驱动开发（"Ralph Loop"）** — `skills/subagent-driven-development/` 编排专用子代理（implementer、spec reviewer、code quality reviewer）。通过 `scripts/setup-ralph-loop.sh` 设置。子代理提示与 SKILL.md 同目录存放。
- **Slash 命令（`commands/`）** — 用户可调用：`ralph-loop`、`cancel-ralph`、`help`、`generate-issues`、`fix-issues-and-pr`。
- **Agents（`agents/`）** — 专用 agent 定义，如 `code-reviewer.md`。
- **Templates（`templates/）** — 技术栈起步模板（react-typescript、python-fastapi、go-cli）。
- **Scripts（`scripts/`）** — Shell 工具：版本号管理、learnings 搜索/记录、循环检测、trace 分析、覆盖率指标。
- **Auto-Loop（`scripts/auto-loop.sh` + `scripts/lib/*.sh` + `skills/auto-loop/`）** — 自动化「会话分析→提 issue→SDD 修复→PR」闭环。独立 worktree 隔离运行 Claude，stream-json 信号驱动主循环。详见下方「Auto-Loop」一节。

## 配置与验证地图

- 仓库贡献规则：`CLAUDE.md`（本文件）
- Claude Code hooks 配置：`hooks/hooks.json`
- Cursor 兼容 hooks 配置：`hooks/hooks-cursor.json`
- 项目本地配置入口：复制 `.claude/settings.local.json.example` → `.claude/settings.local.json`
- 插件启用：`.claude/settings.json` 设置 `enabledPlugins.agent-harness@agent-harness`
- 会话知识来源：`.agent-harness/learnings.jsonl`、`skills/session-learnings/`、`skills/retrospective/`、`scripts/*learnings.sh`

验证规则：
- 涉及配置或会话注入的改动，需验证项目设置能正确引用 `hooks/hooks.json`。
- 如果修改了 `SessionStart` / learnings 路径，需验证新会话能收到包含 `using-agent-harness` skill 和 learnings 块的 `hookSpecificOutput.additionalContext`。
- 仅当改动影响 brainstorming skill 本体或其执行流程时才参考相关 skill 文档进行验证。

## 核心贡献规则

在向本仓库提交 PR 之前，你必须：

1. **阅读完整 PR 模板** `.github/PULL_REQUEST_TEMPLATE.md`，用真实、具体的内容填写每个 section。
2. **搜索已有 PR**（开放的和已关闭的）是否已解决同样的问题。如有重复，停下来告诉你的搭档。
3. **确认这是真实问题**，不要提交推测性或纯理论的修复。
4. **确认改动属于核心仓库**。领域特定的、工具特定的或第三方相关的工作应作为独立插件。
5. **向你的搭档展示完整 diff** 并获得明确批准后再提交。

以上任何一项未通过，都不要提交 PR。

## PR 要求

- 每个 PR 必须完整填写 `.github/PULL_REQUEST_TEMPLATE.md`。
- 在模板的 "Existing PRs" 部分引用相关的开放和已关闭 PR。
- 提交前必须有人类审查完整 diff。
- 一个 PR 解决一个问题。
- 至少在一个 harness 上测试，并在环境表中报告结果。
- 描述你解决了什么问题，而不仅仅是改了什么。

## 会被拒绝的 PR

- 添加第三方依赖的 PR（除非是为了支持新的 harness）。
- 将项目特定或个人配置加入核心的 PR。
- 批量、撒网式或捆绑无关改动的 PR。
- Fork 特定的同步或定制 PR。
- 伪造的问题描述或虚构的功能。
- 仅为了 Anthropic 风格的"合规"而重写 skill、没有评估证据的 PR。

## Skill 改动需要评估

Skills 是行为塑造代码。如果你修改了 skill 内容：

- 使用 `agent-harness:writing-skills` 开发和测试改动。
- 跨多个会话运行对抗性压力测试。
- 在 PR 中展示改动前后的评估结果。
- 没有证据表明改动能改善效果时，不要修改已精心调优的内容。
