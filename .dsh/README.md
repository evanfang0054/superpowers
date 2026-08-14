# DeepSeek Harness 适配层

[English](README_EN.md)

本目录是 Agent Harness 的 **DeepSeek Harness（dsh）适配层**，与
`.claude-plugin/`（Claude Code）、`.codex-plugin/`（Codex）、`.pi/`（Pi）同级，
遵循同一哲学：**顶层 `skills/` 是唯一真相源，各平台只加薄适配层，互不影响。**

## 安装（二选一）

### 方式 A：仓库内即用（零安装）

`.dsh/skills` 是指向顶层 `skills/` 的软链。`cd` 到本仓库后启动 dsh，
DSH 会自动发现项目级 skills 目录（`<projectRoot>/.dsh/skills`），
项目级目录会被自动发现，其中 **19 个 skill 立即可调用**（`auto-loop` 非标准
skill 被跳过；11 个流程类 skill 因顶层 `disable-model-invocation` 语义在
DSH 下不可加载——要获得完整 30 个，请用 preset 或 `--user-skills`）：

```bash
cd agent-harness
dsh web
```

### 方式 B：一键全局安装（任何项目可用）

```bash
bash scripts/install-dsh.sh          # 安装 agent preset
bash scripts/install-dsh.sh --user-skills   # 额外安装用户级 skills（任何 preset 下全局可用）
bash scripts/install-dsh.sh --check  # dry-run 查看状态
bash scripts/install-dsh.sh --uninstall     # 卸载
```

安装后：

1. 启动 `dsh web`，在预设（preset）列表中切换到 **「Agent Harness 工作流」**；
2. 或直接使用默认预设 —— 用户级 skills（平铺于 `~/.dsh/skills/`，30 个独立
   skill 目录）在任何预设下都会出现在可用技能目录中。

## 结构

```
.dsh/
├── skills -> ../skills          # 项目级软链：仓库内开箱即用
├── README.md                    # 中文文档
├── README_EN.md                 # English docs
└── agent-preset/                # 分发单元，拷入 ~/.dsh/.agent-presets/agent-harness/
    ├── preset.yml               # 预设清单（name/description/order）
    ├── agent.cordis.yml         # 组合文件：persona + 工具行 + skills 挂载
    └── skills/                  # DSH 化副本（由 sync 脚本生成，勿手改）
```

## 与 Claude Code 版本的行为差异

| 能力 | Claude Code 版本 | DeepSeek Harness 版本 |
|---|---|---|
| 会话启动注入 | `hooks/session-start` 注入 `using-agent-harness` | preset 的 `persona` 提示段（见 `agent.cordis.yml`） |
| skill 加载 | `Skill` 工具 | `skill` 工具（目录自动注入模型） |
| Ralph 循环 | `/ralph-loop` slash 命令 | 原生 `ralph` 工具（preset 已启用） |
| 子代理定义 | `agents/code-reviewer.md` | 由各 skill 正文按需以完整 prompt 传入 `subagent` 工具 |
| skill 格式 | `when_to_use`（snake_case） | `whenToUse`（camelCase，副本内转换） |

## 维护

- **改 skill**：只改顶层 `skills/<name>/`，然后运行
  `bash scripts/sync-dsh-skills.sh` 重新生成副本（自动转换：
  `when_to_use` → `whenToUse`；移除 `disable-model-invocation: true`
  —— Claude Code 中模型仍可显式加载此类 skill，但 DSH 的 skill 工具对
  `modelInvocable=false` 直接拒绝，必须放开；跳过非标准 skill `auto-loop`）。
- **验证**：`bash tests/dsh-plugin-sync/run-all.sh`（纯脚本断言，
  秒级，不消耗模型配额）。
- **不要**手动编辑 `.dsh/agent-preset/skills/` 下的文件 —— 会被
  sync 脚本覆盖。
