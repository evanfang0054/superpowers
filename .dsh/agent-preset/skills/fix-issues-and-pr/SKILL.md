---
name: fix-issues-and-pr
description: Fix existing GitHub issues via SDD and ship as one PR. Trigger on "修 #12", "fix issue #15", "open issues 都修了".
argument-hint: "\"#12,#15\" or \"all\""
---

# Fix Issues And PR

## Overview

Pull existing GitHub issues, fix each via SDD workflow, and ship all fixes as **one PR** that closes every target issue — **no session analysis, no new issues.**

## When to Use

- 用户说："修一下 #12" / "把 open issues 都修了提 PR" / "拉 issue 来修" / "fix issue #15"
- 用户调用 `/fix-issues-and-pr #12,#15` 或 `/fix-issues-and-pr all`
- Issues already exist (人工或 `agent-harness:generate-issues` 创建的)，现在要批量修复

**When NOT to use:**
- 想从会话日志挖掘新问题 → 用 `agent-harness:generate-issues`
- 想一次完成 分析+修复+PR → 直接调用 `"${CLAUDE_PLUGIN_ROOT}/scripts/auto-loop.sh"`（不带 `--fix-only`）

## Key Constraint — One PR for All Issues

> 多 issue 一个 PR：所有修复打到同一分支 `feat/fix-issues-<first_issue>-<date>`，PR body 用 `closes #N`（每行一个，GitHub 自动关闭）。不要拆成多个 PR。

## Parameter Mapping

| 用户表达 | CLI 参数 |
|---------|---------|
| "修 #12 #15" | `--fix-only "#12,#15"` |
| "修所有 open issues" | `--fix-only "all"` |
| "修最多 5 个" | `--max-issues 5`（与 `all` 配合，默认 10） |

## Issue Source — Ask, Don't Guess

- **默认**：用户必须明确给 issue 号。如果用户说"修那个性能 issue"而没给号，**引导用户给号**，不要自己猜。
- **`all`**：拉取 `evanfang0054/agent-harness` 所有 open issues，按更新时间排序，受 `--max-issues` 限制。

## Examples

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/auto-loop.sh" --fix-only "#12,#15"
```

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/auto-loop.sh" --fix-only "all" --max-issues 10
```

## Prerequisites

同 `agent-harness:generate-issues`：`claude` / `gh`（已 `gh auth login`） / `jq` / `uv` 可用，工作区干净。

## Shell Portability — macOS BSD sed vs GNU sed

> **重要**：填充 PR 模板 / 改文件时，不要用 GNU sed 的 `c\` / `a\` / `i\` 多行替换语法。macOS 默认是 BSD sed，遇到 `sed -i '' "/pattern/c\ replacement"` 会报：
> ```
> sed: 1: "/pattern/c\...": extra characters after \ at the end of c command
> ```
>
> **推荐做法（跨平台）**：
> - 简单字符串替换：`sed 's/pattern/replacement/g'`（GNU 和 BSD 都支持）
> - 多行替换 / 模板填充：优先用 **Edit 工具** 或 **Python**（`python3 -c "..."`），不要用 `sed c\`
> - 写入新文件：直接用 Write 工具
>
> 该约束适用于整个 SDD 修复链路 —— orchestrator 派发的 Claude 也要遵守。

## Outputs

- 分支 `feat/fix-issues-<first_issue>-<date>`，PR body 含 `closes #12\ncloses #15\n...`
- `.claude/auto-loop/state.json` 的 `.progress.fixes_completed` 记录每个 issue 的 commit hash

## Scope Boundary (Do NOT)

- ❌ 不重新分析会话 → 用 `agent-harness:generate-issues`
- ❌ 不提新 issue → issue 来源是已存在的
- ❌ 不拆分多个 PR → 当前实现只支持单 PR

完整能力见 `"${CLAUDE_PLUGIN_ROOT}/scripts/auto-loop.sh"` 与 `skills/auto-loop/orchestrator-prompt.md` 的 `fix_only` 模式分支。
