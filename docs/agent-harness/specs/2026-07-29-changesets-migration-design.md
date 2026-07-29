---
spec_topic: changesets-migration
decision_summary: "用 @changesets/cli + @changesets/changelog-github 替换自研 bump-version.sh + RELEASE-NOTES.md 体系，保留精简 sync 脚本同步3个非 package.json 插件 manifest，全量迁移64个历史版本到 CHANGELOG.md。"
design_approved: true
user_approved_at: "2026-07-29T21:30:00+08:00"
gates: [user-review-passed]
domain_terms: [changeset, changelog-github, sync-plugin-versions, drift 检测, beyond-npm]
---

# Changesets 版本管理迁移设计

## 背景

Agent Harness 当前使用自研 `scripts/bump-version.sh`（656行双面 CLI：人类 TTY + agent JSON envelope）+ `.version-bump.json` 配置 + `RELEASE-NOTES.md`（1305行，64个版本）管理版本。该方案不标准：changelog 手动维护、无 PR 链接、无结构化变更分类、双面 CLI 维护负担重。

社区标准方案是 `@changesets/cli` + `@changesets/changelog-github`：开发者用 `changeset` 命令添加变更描述文件，`changeset version` 消费这些文件自动 bump 版本 + 生成 GitHub 风格 changelog（含 PR 链接 + 贡献者致谢）。

**核心挑战：** changesets 原生只 bump `package.json`。本项目有4个版本承载文件，其中3个是非 package.json 的插件 manifest（`.claude-plugin/plugin.json`、`.codex-plugin/plugin.json`、`.claude-plugin/marketplace.json` 嵌套字段 `plugins[0].version`），changesets 不会自动同步它们。

## 目标

- 用 `@changesets/cli` + `@changesets/changelog-github` 替换自研 bump-version.sh 体系
- 保留 `pnpm release` 肌肉记忆，工作流为 `changeset version && sync`
- 用精简 `sync-plugin-versions.sh` 同步3个插件 manifest，保留 drift 检测能力
- 全量迁移64个历史版本到 `CHANGELOG.md`，旧条目保留原文
- 本地手动模式（无 CI/CD）

## 非目标

- 不添加 GitHub Actions 自动发布工作流（本地 `pnpm release` 足够）
- 不发布到 npm（这是插件分发，非 npm 包）
- 不自定义 changelog 生成器（用官方 `@changesets/changelog-github`）
- 不回溯64个历史版本的 GitHub PR 链接（不可靠归因，保留原文）
- 不保留 bump-version.sh 的 agent JSON envelope 契约（changesets 接管后无此需求）
- 不保留 `--audit` grep 扫描（changesets 接管后版本只存在于4个已知文件，audit 价值下降）

## 架构

### 职责分工

```
changesets          → package.json 版本 + CHANGELOG.md 生成 + .changeset/*.md 消费
sync-plugin-versions → 3个插件 manifest 版本同步 + drift 检测
pnpm release         = changeset version && ./scripts/sync-plugin-versions.sh
pnpm changeset       = changeset (交互式添加 changeset 文件)
```

### 文件清单

**新增：**
- `.changeset/config.json` — changesets 配置
- `scripts/sync-plugin-versions.sh` — 精简同步脚本（约60行）
- `scripts/migrate-release-notes.sh` — 一次性迁移脚本（迁移后删除）
- `CHANGELOG.md` — changesets 生成的 changelog（由迁移脚本初始化）
- `tests/plugin-infrastructure/test-sync-plugin-versions.sh` — 同步脚本测试（约40行）

**删除：**
- `scripts/bump-version.sh`（656行）
- `.version-bump.json`（23行）
- `tests/plugin-infrastructure/test-bump-version.sh`（69行）
- `tests/plugin-infrastructure/test-bump-version-agent.sh`（140行）
- `RELEASE-NOTES.md`（1305行，内容迁移到 CHANGELOG.md 后删除）

**修改：**
- `package.json` — 加 `"private": true`，改 `"release"` 脚本，新增 `"changeset"` 脚本，加 devDependencies
- `tests/plugin-infrastructure/run-all.sh` — 移除2个旧测试条目，新增1个新测试条目
- `CLAUDE.md` — 发布章节改为 changesets 工作流
- `tests/CLAUDE.md` — 套件表 `bump-version.sh` → `sync-plugin-versions.sh` + changesets
- `docs/agent-harness/index.md` — 新增 `changesets-migration` 主题锚点
- `docs/agent-harness/specs/index.md` — 新增 spec 条目

## 组件设计

### 1. `.changeset/config.json`

```json
{
  "changelog": ["@changesets/changelog-github", { "repo": "evanfang0054/agent-harness" }],
  "commit": false,
  "access": "restricted",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": [],
  "privatePackages": { "version": true, "tag": false }
}
```

- `changelog`：GitHub 风格，`evanfang0054/agent-harness` 仓库
- `commit: false`：本地手动模式，changesets 不自动 git commit
- `privatePackages.version: true`：让 changesets 版本化根 package.json（"beyond npm" 用例必需）
- `tag: false`：不创建 npm dist-tag（不发布到 npm）

### 2. `package.json`

```json
{
  "name": "agent-harness",
  "version": "6.4.4",
  "private": true,
  "description": "Agent Harness skills and runtime bootstrap for coding agents",
  "type": "module",
  "scripts": {
    "release": "changeset version && ./scripts/sync-plugin-versions.sh",
    "changeset": "changeset"
  },
  "devDependencies": {
    "@changesets/cli": "^2.27.0",
    "@changesets/changelog-github": "^0.5.0"
  },
  ...
}
```

- `"private": true`：防止误 `npm publish`（插件分发，非 npm 包）
- `"release"`：`changeset version`（bump package.json + 生成 CHANGELOG.md）后接 sync 脚本（同步3个 manifest）
- `"changeset"`：快捷入口，`pnpm changeset` 等价于 `npx changeset`

### 3. `scripts/sync-plugin-versions.sh`

精简同步脚本，保留 bump-version.sh 的核心 jq 逻辑，删除 agent envelope / TTY changelog / audit。

**功能：**
- 默认（无参数）：读 `package.json` 的 `version`，用 jq 写入3个目标文件
  - `.claude-plugin/plugin.json` → `.version`
  - `.codex-plugin/plugin.json` → `.version`
  - `.claude-plugin/marketplace.json` → `.plugins[0].version`
- `--check`：只读检测 drift，版本不一致时 exit 2 + 报告哪个文件 drift

**保留自 bump-version.sh：** `read_json_field` / `write_json_field` 的 jq 安全注入逻辑

**删除自 bump-version.sh：** agent JSON envelope（`emit_ok`/`emit_err`）、TTY changelog 收集、`update_release_notes`、`cmd_audit` grep 扫描、`cmd_schema` 自省、`parse_and_dispatch` 子命令分发、legacy 兼容入口

### 4. `scripts/migrate-release-notes.sh`（一次性，迁移后删除）

解析 `RELEASE-NOTES.md`，转换格式：
- `## vX.Y.Z (date)` → `## X.Y.Z`（去 `v` 前缀和日期，匹配 changesets 格式）
- 保留 `### Changes` 下 bullet 原文
- 输出到 `CHANGELOG.md`，顶部加 `# agent-harness` 标题行

**格式取舍：** 旧条目用 `### Changes`（无 major/minor/patch 分类），新版本由 changesets 生成时用 `### Patch/Minor/Major Changes`。两种格式共存可接受 —— 无法可靠回溯64个历史版本的变更分类。

### 5. `tests/plugin-infrastructure/test-sync-plugin-versions.sh`

替代旧 `test-bump-version.sh` + `test-bump-version-agent.sh`：

- 测1：sync 后4文件版本一致（在临时沙箱复制4个 manifest，运行 sync，断言3个目标文件版本 == package.json 版本）
- 测2：`--check` 检测 drift（手动改一个 manifest 版本，断言 exit 2 + 输出报告 drift 文件）
- 测3（可选）：`changeset version` 在临时沙箱跑通（预置 `.changeset/*.md`，验证 package.json + CHANGELOG.md 被正确更新）

## 数据流

```
开发完功能
  ↓
pnpm changeset  →  生成 .changeset/<random>-changes.md（含 minor/major/patch + 描述）
  ↓
pnpm release
  ├→ changeset version
  │    ├→ 读 .changeset/*.md
  │    ├→ bump package.json version
  │    ├→ 生成 CHANGELOG.md 条目（changelog-github 格式，含 PR 链接）
  │    └→ 删除已消费的 .changeset/*.md
  └→ ./scripts/sync-plugin-versions.sh
       └→ 读 package.json version → 写入3个插件 manifest
  ↓
git add -A && git commit -m "chore(release): vX.Y.Z" && git tag vX.Y.Z（手动）
```

## 错误处理

- **sync 失败（目标文件缺失）：** 报告哪个文件缺失，exit 1，不静默跳过
- **drift 检测（`--check`）：** 版本不一致时 exit 2（数据状态，非 bug），报告每个 drift 文件的期望值 vs 实际值
- **changeset version 无 changeset 文件：** changesets 自身报错 "No unreleased changesets found" + exit 1
- **migrate 脚本解析失败：** RELEASE-NOTES.md 格式异常时报告行号 + exit 1

## 测试

- 纯脚本测试 `test-sync-plugin-versions.sh`（秒级，确定性）
- 不需要 headless 行为测试（这是脚本/配置变更，非 skill 行为变更）
- 迁移脚本 `migrate-release-notes.sh` 验证：迁移后 `CHANGELOG.md` 版本数 == 64，首个版本 == 6.4.4，格式匹配 `## X.Y.Z`

## 实施顺序

1. 加 devDependencies + `.changeset/config.json` + `package.json` 改动
2. 写 `scripts/sync-plugin-versions.sh` + `test-sync-plugin-versions.sh`
3. 写 `scripts/migrate-release-notes.sh`，运行迁移生成 `CHANGELOG.md`，验证64版本
4. 删除旧文件（bump-version.sh、.version-bump.json、2个旧测试、RELEASE-NOTES.md）
5. 更新 `run-all.sh` 测试注册 + CLAUDE.md / tests/CLAUDE.md 文档
6. 删除 `scripts/migrate-release-notes.sh`（一次性脚本）
7. 运行 `./tests/plugin-infrastructure/run-all.sh` 全套验证
8. 手动验证 `pnpm changeset` + `pnpm release` 端到端（dry-run 模式）

## 验证清单

- [ ] `pnpm changeset` 能交互式生成 `.changeset/*.md`
- [ ] `pnpm release` 后4文件版本一致
- [ ] `CHANGELOG.md` 由 changesets 正确更新
- [ ] `./scripts/sync-plugin-versions.sh --check` drift 时 exit 2
- [ ] `./tests/plugin-infrastructure/run-all.sh` 全绿
- [ ] `CHANGELOG.md` 含64个历史版本，格式为 `## X.Y.Z`
- [ ] 旧文件已删除：bump-version.sh、.version-bump.json、RELEASE-NOTES.md、2个旧测试
- [ ] CLAUDE.md 发布章节反映 changesets 工作流
