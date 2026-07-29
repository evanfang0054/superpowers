# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 你在哪，测什么

这是 **Agent Harness** 的 `tests/` 目录 —— 测试目标是**非编译型行为塑造产物**（skills / hooks / 插件 manifest / shell 脚本），不是常规应用代码。顶层 `../CLAUDE.md` 是项目宪法，冲突时以顶层为准。

测试分两类，**区分清楚至关重要**：

- **纯脚本断言测试**（秒级，确定性）：`bats`/`bash` 风格 `grep` 断言，**不调用模型**。失败 = 脚本/配置真的错了。
- **headless 行为测试**（消耗 Claude API 配额，1-40 分钟，结果取决于模型当前行为）：通过 `claude -p` 真实触发 skill 行为。失败可能是 flaky，需复跑而非盲改。

## 套件速查表

| 目录 | 类型 | 运行入口 | 测什么 |
|------|------|---------|--------|
| `plugin-infrastructure/` | 纯脚本 | `./run-all.sh` | hooks 配置、plugin/marketplace manifest、commands/agents frontmatter、`sync-plugin-versions.sh`、changesets 配置、脚本冒烟 |
| `learnings-scripts/` | 纯脚本 | `./test-learnings.sh` | `scripts/*learnings.sh` 行为 |
| `codex-plugin-sync/` | 纯脚本 | `./test-sync-to-codex-plugin.sh` | Codex plugin manifest 与 Claude Code 一致性 |
| `sdd-scripts/` | 纯脚本 | `./test-cleanup-workspace.sh` | SDD 工作区清理脚本 |
| `ralph-loop-scripts/` | 纯脚本 | `./test-stop-hook-promise.sh` | stop hook 行为 |
| `pi/` | 纯脚本 (tsx) | `npx tsx --test tests/pi/test-pi-extension.mjs` | `.pi/extensions/agent-harness.ts` 与 `skills/using-agent-harness/references/pi-tools.md` 一致性 |
| `claude-code/` | 混合 | `./run-skill-tests.sh [--integration\|--test <f>\|--verbose]` | skill 加载/集成（用 headless `claude -p`） |
| `skill-behavior/` | headless 行为 | `<skill>/run-test.sh` 或全量 `./run-all-tests.sh` | 每个 skill 的真实行为触发与合规 |
| `explicit-skill-requests/` | headless 行为 | `./run-all.sh` | 多轮显式 `/skill` 调用 |
| `skill-triggering/` | headless 行为 | `./run-all.sh` | 隐式 skill 触发 |
| `subagent-driven-dev/` | headless 行为 | `./run-test.sh` | SDD 端到端（用 `go-fractals` / `svelte-todo` 示例项目） |

## 常用命令

```bash
# 快速纯脚本全套（秒级）
./plugin-infrastructure/run-all.sh
./learnings-scripts/test-learnings.sh
./codex-plugin-sync/test-sync-to-codex-plugin.sh
npx tsx --test pi/test-pi-extension.mjs

# 单个 skill 行为测试（1-3 分钟，耗配额）
cd skill-behavior/<skill-name> && ./run-test.sh

# skill 加载测试
cd claude-code && ./run-skill-tests.sh
cd claude-code && ./run-skill-tests.sh --test <test-file>
cd claude-code && ./run-skill-tests.sh --integration

# headless 行为全套（15-40 分钟，重配额）
./skill-behavior/run-all-tests.sh
./explicit-skill-requests/run-all.sh
./skill-triggering/run-all.sh
```

## 关键基础设施

### `claude-code/test-helpers.sh`（headless 测试工具函数）
- `run_claude "prompt" [timeout] [allowed_tools]` — 在 `--permission-mode bypassPermissions` 下跑 `claude -p`，跨平台兼容 `timeout`/`gtimeout`/python 回退。
- 断言族：`assert_contains`、`assert_not_contains`、`assert_count`、`assert_order`。
- **新写 headless 测试时优先复用这些函数**，不要重造。

### `skill-behavior/_helpers/`
- `run-skill.sh` — 用 `run_claude` 触发 skill。
- `assert-skill-triggered.sh` — 检测 skill 是否被调用；计数器 `SKILL_PASS_COUNT`/`SKILL_FAIL_COUNT` 全局，跨场景需手动重置（见 `brainstorming/run-test.sh` 的 naive→explicit 重置）。

### 模式约定
- 每个套件自带 `run-all.sh` / `run-test.sh`（`set -uo pipefail`，`SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` 定位）。
- headless 测试用 `prompts/*.txt` 存放输入，避免内联长 prompt。
- 行为测试常用场景拆分：**naive**（看是否被触发）+ **explicit**（看显式调用是否工作）+ **pressure**（对抗性压力）。

## 写新测试

1. **先选对类型**：断言配置/脚本/manifest 一致性 → 纯脚本；断言 agent 行为 → headless 行为（无替代，因为行为只有真模型能验）。
2. **纯脚本**：放对应目录，在 `run-all.sh` 的 `TESTS=()` 数组里登记，每测独立退出码。
3. **headless 行为**：放 `skill-behavior/<skill>/`，复用 `_helpers/`，prompt 落 `prompts/*.txt`，naive + explicit + pressure 三场景齐全。
4. **新 skill 的行为测试是 `skill-behavior/` 的默认义务** —— 修改 skill 而不补/更新对应行为测试违反顶层 CLAUDE.md 的评估要求。

## 不要做

- 不要把 headless flaky 失败当脚本 bug 改 —— 先复跑、再判断是模型行为漂移还是真回归。
- 不要为 headless 测试 mock 掉模型调用 —— 那就不是行为测试了，失去意义。
- 不要新增第三方依赖（除非支持新 harness），测试也要守顶层红线。
- 不要把项目特定 / 个人测试塞进核心套件。

## Git 规范

- Commit：`test(<scope>): <subject>`，scope 例如 `skill-behavior`、`plugin-infrastructure`、`learnings-scripts`。
- 分支：`feat/*` / `test/*`（参考当前 `feat/skill-tests`）。
