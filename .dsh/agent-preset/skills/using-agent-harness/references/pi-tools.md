# Pi 工具映射

Skills 用「动作」描述需求（"分发子 agent"、"创建 todo"、"读取文件"）。在 Pi 上这些动作对应下面的工具。

| Skill 请求的动作 | Pi 等价物 |
| --- | --- |
| 调用 skill | Pi 原生 skills：用 `read` 加载相关 `SKILL.md`，或让人类显式调用 `/skill:name` |
| 读取文件 | `read` |
| 创建文件 | `write` |
| 编辑文件 | `edit` |
| 运行 shell 命令 | `bash` |
| 搜索文件内容 | 可用时 `grep`；否则用 `bash` 配合 `rg` / `grep` |
| 按名查找文件 | 可用时 `find`；否则用 `bash` 配合 shell glob |
| 列出文件和子目录 | 可用时 `ls`；否则用 `bash` 配合 `ls` |
| 分发子 agent（`Subagent (general-purpose):` 模板） | 如果安装了 `pi-subagents` 包提供的 `subagent` 工具，则使用它 |
| 任务跟踪（"创建 todo"、"标记完成"） | 如果安装了 todo/task 工具则使用；否则在 plan 文件或仓库内 `TODO.md` 中跟踪 |

## Skills

Pi 从配置的 skill 目录和已安装的 Pi 包发现 skills。Agent Harness Pi 包应通过其 `pi.skills` manifest 条目暴露 `skills/`。Pi 不暴露 Claude Code 的 `Skill` 工具，但 agent 仍应遵循 Agent Harness 规则：当某个 skill 适用时，在响应前加载并遵循它。

## Subagents

Pi 核心不提供标准 subagent 工具。`pi-subagents` 包是强有力的可选 companion，提供支持单 agent、链式、并行、异步、forked-context、resume/status 工作流的 `subagent` 工具。如果没有可用的 subagent 工具，不要伪造 `Task` 调用；在当前 session 中顺序执行，或说明该可选 subagent 能力未安装。

## Task lists

Pi 核心不提供标准 task-list 工具。如果安装了 todo/task 扩展，使用其文档化的工具。否则使用 Agent Harness plan 文件、Markdown checklist，或仓库内 `TODO.md` 做任务跟踪。较老的 Agent Harness 文档可能引用 `TodoWrite`；将其视为上述任务跟踪动作。
