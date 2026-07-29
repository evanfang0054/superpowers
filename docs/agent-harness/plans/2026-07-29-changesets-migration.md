---
spec_ref: ../specs/2026-07-29-changesets-migration-design.md
spec_topic: changesets-migration
task_count: 7
estimated_phases: [tests, implementation, verification, cleanup]
dod: "17条 DoD 见 docs/agent-harness/contracts/changesets-migration.contract.md；核心：changesets 接管 package.json+CHANGELOG，sync 脚本同步3个 manifest，64历史版本迁移，旧文件全删，run-all.sh exit 0"
status: active
---

# Changesets 版本管理迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 @changesets/cli + @changesets/changelog-github 替换自研 bump-version.sh 体系，保留精简 sync-plugin-versions.sh 同步3个非 package.json 插件 manifest，全量迁移64个历史版本到 CHANGELOG.md。

**Architecture:** changesets 管 package.json 版本 + CHANGELOG.md 生成；`pnpm release` = `changeset version && ./scripts/sync-plugin-versions.sh`；sync 脚本用 jq 把 package.json 版本写入3个插件 manifest（plugin.json x2 + marketplace.json 嵌套字段），保留 `--check` drift 检测。一次性 migrate 脚本把 RELEASE-NOTES.md 转格式生成 CHANGELOG.md 后删除。

**Tech Stack:** Bash + jq（sync 脚本）；@changesets/cli + @changesets/changelog-github（devDependencies）；pnpm。

**Commit strategy:** 手动提交（用户选择）。本 plan 不含 commit 步骤；末尾有一次性 commit 提示。

**GDD:** 跳过。纯脚本工具迁移，无行为/契约/回归风险，确定性 shell 测试足够。

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新增 | `.changeset/config.json` | changesets 配置（changelog-github、privatePackages、baseBranch） |
| 新增 | `scripts/sync-plugin-versions.sh` | 精简同步脚本：读 package.json 版本→写3个 manifest；`--check` drift 检测 |
| 新增 | `scripts/migrate-release-notes.sh` | 一次性迁移脚本：RELEASE-NOTES.md→CHANGELOG.md 格式转换（迁移后删除） |
| 新增 | `CHANGELOG.md` | changesets 生成的 changelog（由 migrate 脚本初始化64条） |
| 新增 | `tests/plugin-infrastructure/test-sync-plugin-versions.sh` | sync 脚本测试：同步、drift、缺失文件 |
| 修改 | `package.json` | 加 `private:true`、devDeps、改 `release` 脚本、加 `changeset` 脚本 |
| 修改 | `tests/plugin-infrastructure/run-all.sh` | TESTS 数组：移除2条旧测试、新增1条新测试 |
| 修改 | `CLAUDE.md` | 发布章节改为 changesets 工作流 |
| 修改 | `tests/CLAUDE.md` | 套件表 bump-version→sync-plugin-versions |
| 删除 | `scripts/bump-version.sh` | 旧版本脚本（656行） |
| 删除 | `.version-bump.json` | 旧配置（23行） |
| 删除 | `RELEASE-NOTES.md` | 旧 changelog（迁移后删除） |
| 删除 | `tests/plugin-infrastructure/test-bump-version.sh` | 旧测试（69行） |
| 删除 | `tests/plugin-infrastructure/test-bump-version-agent.sh` | 旧测试（140行） |
| 删除 | `scripts/migrate-release-notes.sh` | 一次性脚本（迁移后删除） |

---

## Task 1: changesets 依赖与配置

Blocking: none
Slice type: tracer-bullet（foundation）
Seam: `pnpm changeset` 二进制可解析

**Files:**
- Create: `.changeset/config.json`
- Modify: `package.json`

**Interfaces:**
- Produces: changesets 工作目录 `.changeset/`、`pnpm changeset`/`pnpm release` 入口

- [ ] **Step 1: 创建 `.changeset/config.json`**

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

- [ ] **Step 2: 修改 `package.json`**

加 `"private": true`、devDependencies、改 `release` 脚本、加 `changeset` 脚本。完整 package.json：

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
  "keywords": [
    "pi-package",
    "skills",
    "tdd",
    "debugging",
    "collaboration",
    "workflow"
  ],
  "pi": {
    "extensions": [
      "./.pi/extensions/agent-harness.ts"
    ],
    "skills": [
      "./skills"
    ]
  }
}
```

- [ ] **Step 3: 安装依赖并验证**

Run: `pnpm install`
Expected: 安装 `@changesets/cli` + `@changesets/changelog-github`，生成/更新 pnpm-lock.yaml

- [ ] **Step 4: 冒烟测试 changesets 二进制**

Run: `pnpm changeset --help`
Expected: exit 0，输出 changeset 命令帮助（证明二进制可解析、config.json 有效）

---

## Task 2: sync-plugin-versions.sh（TDD）

Blocking: Task 1
Slice type: tracer-bullet（TDD）
Seam: 3个插件 manifest 的 version 字段

**Files:**
- Create: `tests/plugin-infrastructure/test-sync-plugin-versions.sh`（先写测试）
- Create: `scripts/sync-plugin-versions.sh`（后写实现）

**Interfaces:**
- Consumes: package.json `.version`（Task 1 的 package.json）
- Produces: `sync-plugin-versions.sh`（默认模式同步、`--check` 模式检测 drift）；3个 manifest 的 version 字段被同步

- [ ] **Step 1: 写失败测试 `tests/plugin-infrastructure/test-sync-plugin-versions.sh`**

```bash
#!/usr/bin/env bash
# test-sync-plugin-versions.sh — verify sync-plugin-versions.sh syncs + detects drift
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC="$REPO_ROOT/scripts/sync-plugin-versions.sh"

PASS=0; FAIL=0
assert() { if eval "$1" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $2"; fi; }

# Test 1: --check passes on real repo (all manifests at 6.4.4)
"$SYNC" --check >/dev/null 2>&1
assert '[ $? -eq 0 ]' "--check exits 0 when all 4 files in sync"

# Test 2: sandbox — sync writes package.json version to 3 manifests
TMP=$(mktemp -d)
mkdir -p "$TMP/scripts" "$TMP/.claude-plugin" "$TMP/.codex-plugin"
cp "$SYNC" "$TMP/scripts/sync-plugin-versions.sh"
echo '{"version":"9.9.9"}' > "$TMP/package.json"
echo '{"version":"0.0.0"}' > "$TMP/.claude-plugin/plugin.json"
echo '{"version":"0.0.0"}' > "$TMP/.codex-plugin/plugin.json"
echo '{"plugins":[{"version":"0.0.0"}]}' > "$TMP/.claude-plugin/marketplace.json"
"$TMP/scripts/sync-plugin-versions.sh" >/dev/null 2>&1
v1=$(jq -r '.version' "$TMP/.claude-plugin/plugin.json")
v2=$(jq -r '.version' "$TMP/.codex-plugin/plugin.json")
v3=$(jq -r '.plugins[0].version' "$TMP/.claude-plugin/marketplace.json")
assert '[ "$v1" = "9.9.9" ]' "sync writes .claude-plugin/plugin.json → 9.9.9"
assert '[ "$v2" = "9.9.9" ]' "sync writes .codex-plugin/plugin.json → 9.9.9"
assert '[ "$v3" = "9.9.9" ]' "sync writes marketplace.json plugins[0].version → 9.9.9"

# Test 3: sandbox — --check detects drift (exit 2)
echo '{"version":"0.0.0"}' > "$TMP/.claude-plugin/plugin.json"
"$TMP/scripts/sync-plugin-versions.sh" --check >/dev/null 2>&1
assert '[ $? -eq 2 ]' "--check exits 2 when a manifest drifts"

# Test 4: sandbox — missing target file → exit 1
rm "$TMP/.claude-plugin/marketplace.json"
"$TMP/scripts/sync-plugin-versions.sh" >/dev/null 2>&1
assert '[ $? -eq 1 ]' "sync exits 1 when a target file is missing"
rm -rf "$TMP"

echo "sync-plugin-versions: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: 运行测试，验证失败（脚本不存在）**

Run: `bash tests/plugin-infrastructure/test-sync-plugin-versions.sh`
Expected: FAIL，因 `scripts/sync-plugin-versions.sh` 不存在（cp 报错或 4 个 assert 全失败）

- [ ] **Step 3: 写实现 `scripts/sync-plugin-versions.sh`**

```bash
#!/usr/bin/env bash
#
# sync-plugin-versions.sh — sync package.json version to 3 plugin manifests.
# Usage:
#   sync-plugin-versions.sh           # sync (write)
#   sync-plugin-versions.sh --check   # check drift (exit 0 in-sync, 2 drift, 1 missing)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PKG="$REPO_ROOT/package.json"
# 格式: "相对路径|jq字段路径"
TARGETS=(
  ".claude-plugin/plugin.json|.version"
  ".codex-plugin/plugin.json|.version"
  ".claude-plugin/marketplace.json|.plugins[0].version"
)

cmd_sync() {
  local pkg_ver; pkg_ver=$(jq -r '.version' "$PKG")
  for entry in "${TARGETS[@]}"; do
    local rel="${entry%|*}" field="${entry#*|}"
    local file="$REPO_ROOT/$rel"
    if [ ! -f "$file" ]; then
      echo "error: missing target file: $rel" >&2
      exit 1
    fi
    local tmp="${file}.tmp"
    jq "$field = \"$pkg_ver\"" "$file" > "$tmp" && mv "$tmp" "$file"
    echo "  synced $rel ($field) → $pkg_ver"
  done
}

cmd_check() {
  local pkg_ver; pkg_ver=$(jq -r '.version' "$PKG")
  local drift=0
  for entry in "${TARGETS[@]}"; do
    local rel="${entry%|*}" field="${entry#*|}"
    local file="$REPO_ROOT/$rel"
    if [ ! -f "$file" ]; then
      echo "MISSING: $rel" >&2
      drift=1
      continue
    fi
    local ver; ver=$(jq -r "$field" "$file")
    if [ "$ver" != "$pkg_ver" ]; then
      echo "DRIFT: $rel field=$field expected=$pkg_ver actual=$ver" >&2
      drift=1
    fi
  done
  if [ "$drift" = "0" ]; then
    echo "All manifests in sync at $pkg_ver"
    return 0
  fi
  return 2
}

case "${1:-sync}" in
  sync|"") cmd_sync ;;
  --check|check) cmd_check ;;
  *) echo "usage: sync-plugin-versions.sh [sync|--check]" >&2; exit 1 ;;
esac
```

- [ ] **Step 4: 运行测试，验证通过**

Run: `bash tests/plugin-infrastructure/test-sync-plugin-versions.sh`
Expected: `sync-plugin-versions: PASS=4 FAIL=0`，exit 0

- [ ] **Step 5: 在真实仓库验证 `--check`（4文件应同步在 6.4.4）**

Run: `./scripts/sync-plugin-versions.sh --check`
Expected: `All manifests in sync at 6.4.4`，exit 0

---

## Task 3: 迁移 RELEASE-NOTES.md → CHANGELOG.md

Blocking: Task 1（需要 package.json 确认版本基线）
Slice type: tracer-bullet（data migration）
Seam: `grep -c '^## ' CHANGELOG.md` == 64

**Files:**
- Create: `scripts/migrate-release-notes.sh`（一次性，Task 7 删除）
- Create: `CHANGELOG.md`（由脚本生成）
- Delete: `RELEASE-NOTES.md`（迁移后删除）

**Interfaces:**
- Consumes: `RELEASE-NOTES.md`（1305行，64个 `## vX.Y.Z (date)` 块）
- Produces: `CHANGELOG.md`（64个 `## X.Y.Z` 块，顶部 `# agent-harness` 标题）

- [ ] **Step 1: 写迁移脚本 `scripts/migrate-release-notes.sh`**

```bash
#!/usr/bin/env bash
#
# migrate-release-notes.sh — one-time migration: RELEASE-NOTES.md → CHANGELOG.md
# 转换格式: `## vX.Y.Z (date)` → `## X.Y.Z`（去 v 前缀和日期，匹配 changesets 格式）
# 保留 `### Changes` 下 bullet 原文。迁移后本脚本应删除。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/RELEASE-NOTES.md"
DST="$REPO_ROOT/CHANGELOG.md"

[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }
[ -f "$DST" ] && { echo "error: $DST already exists, refusing to overwrite" >&2; exit 1; }

{
  echo "# agent-harness"
  echo ""
  awk '
    /^# Agent Harness Release Notes/ { next }
    /^## v[0-9]/ {
      line=$0
      sub(/^## v/, "## ", line)
      sub(/ \([0-9]{4}-[0-9]{2}-[0-9]{2}\)/, "", line)
      print line
      next
    }
    { print }
  ' "$SRC"
} > "$DST"

count=$(grep -c '^## ' "$DST" || true)
echo "migrated $count versions to $DST"
echo "first entry: $(grep -m1 '^## ' "$DST")"
```

- [ ] **Step 2: 运行迁移脚本**

Run: `./scripts/migrate-release-notes.sh`
Expected: `migrated 64 versions to .../CHANGELOG.md` + `first entry: ## 6.4.4`

- [ ] **Step 3: 验证迁移结果**

Run: `grep -c '^## ' CHANGELOG.md`
Expected: `64`

Run: `head -8 CHANGELOG.md`
Expected: 前几行为 `# agent-harness` + 空行 + `## 6.4.4` + 空行 + `### Changes` + 空行 + bullet

- [ ] **Step 4: 删除 RELEASE-NOTES.md**

迁移验证通过后，删除旧 changelog。Run: `rm RELEASE-NOTES.md`
（git 历史保留旧文件，可随时回溯）

---

## Task 4: 删除旧版本管理文件 + 更新 run-all.sh

Blocking: Task 2（新测试已写）、Task 3（RELEASE-NOTES 已删）
Slice type: refactor（contract phase — 移除旧路径）
Seam: `grep -rn 'bump-version\|RELEASE-NOTES\|version-bump' scripts/ tests/ CLAUDE.md tests/CLAUDE.md` 返回0匹配

**Files:**
- Delete: `scripts/bump-version.sh`
- Delete: `.version-bump.json`
- Delete: `tests/plugin-infrastructure/test-bump-version.sh`
- Delete: `tests/plugin-infrastructure/test-bump-version-agent.sh`
- Modify: `tests/plugin-infrastructure/run-all.sh`（TESTS 数组：移除2条、新增1条）

**Interfaces:**
- Consumes: Task 2 产出的 `test-sync-plugin-versions.sh`（注册到 run-all.sh）
- Produces: run-all.sh 不再引用 bump-version，引用 sync-plugin-versions

- [ ] **Step 1: 删除4个旧文件**

Run: `rm scripts/bump-version.sh .version-bump.json tests/plugin-infrastructure/test-bump-version.sh tests/plugin-infrastructure/test-bump-version-agent.sh`

- [ ] **Step 2: 修改 `tests/plugin-infrastructure/run-all.sh` 的 TESTS 数组**

把这两行：
```
    "test-bump-version.sh"
    "test-bump-version-agent.sh"
```
替换为：
```
    "test-sync-plugin-versions.sh"
```

即 TESTS 数组中 `test-bump-version.sh` 和 `test-bump-version-agent.sh` 两行合并为 `test-sync-plugin-versions.sh` 一行（保持数组其他元素顺序不变）。

- [ ] **Step 3: 验证无旧引用残留**

Run: `grep -rn 'bump-version\|RELEASE-NOTES\|version-bump' scripts/ tests/ CLAUDE.md tests/CLAUDE.md`
Expected: 0 行匹配（spec 文件 `docs/agent-harness/specs/2026-07-29-changesets-migration-design.md` 提及旧系统名属正常，不在本 grep 范围内）

> 注：若 CLAUDE.md / tests/CLAUDE.md 有匹配，Task 5 会处理。

---

## Task 5: 更新文档

Blocking: Task 4
Slice type: verification
Seam: CLAUDE.md 发布章节 + tests/CLAUDE.md 套件表 反映 changesets 工作流

**Files:**
- Modify: `CLAUDE.md`（发布章节）
- Modify: `tests/CLAUDE.md`（套件速查表第18行）

**Interfaces:**
- Consumes: Task 1-4 的最终工作流

- [ ] **Step 1: 更新 `CLAUDE.md` 发布章节**

找到发布章节（当前为）：
```
### 发布
- `pnpm run release`（执行 `./scripts/bump-version.sh`）
```

替换为：
```
### 发布
- `pnpm changeset` — 交互式添加 changeset（选择 minor/major/patch + 写变更描述，生成 `.changeset/*.md`）
- `pnpm release` — 消费 changesets（`changeset version` bump package.json + 生成 CHANGELOG.md），再 `./scripts/sync-plugin-versions.sh` 同步3个插件 manifest 版本
- `./scripts/sync-plugin-versions.sh --check` — 检测4个版本文件是否 drift
```

- [ ] **Step 2: 更新 `tests/CLAUDE.md` 套件速查表**

找到第18行（当前为）：
```
| `plugin-infrastructure/` | 纯脚本 | `./run-all.sh` | hooks 配置、plugin/marketplace manifest、commands/agents frontmatter、`bump-version.sh`、脚本冒烟 |
```

替换 `bump-version.sh` 为 `sync-plugin-versions.sh` + changesets：
```
| `plugin-infrastructure/` | 纯脚本 | `./run-all.sh` | hooks 配置、plugin/marketplace manifest、commands/agents frontmatter、`sync-plugin-versions.sh`、changesets 配置、脚本冒烟 |
```

- [ ] **Step 3: 验证文档无旧引用残留**

Run: `grep -n 'bump-version\|RELEASE-NOTES\|version-bump' CLAUDE.md tests/CLAUDE.md`
Expected: 0 行匹配

---

## Task 6: 删除一次性迁移脚本

Blocking: Task 3（迁移已完成）
Slice type: refactor（cleanup）
Seam: `scripts/migrate-release-notes.sh` 不存在

**Files:**
- Delete: `scripts/migrate-release-notes.sh`

- [ ] **Step 1: 删除迁移脚本**

Run: `rm scripts/migrate-release-notes.sh`

- [ ] **Step 2: 验证脚本已删除**

Run: `ls scripts/migrate-release-notes.sh 2>&1`
Expected: `No such file or directory`（exit 非零）

---

## Task 7: 全量验证

Blocking: Task 1-6 全部完成
Slice type: verification
Seam: sprint contract 的17条 DoD 全部满足

**Files:** 无修改（纯验证）

- [ ] **Step 1: 运行 plugin-infrastructure 全套测试**

Run: `cd tests/plugin-infrastructure && ./run-all.sh`
Expected: exit 0，所有测试 PASS（含新增 test-sync-plugin-versions.sh、codex-plugin-sync manifest 一致性）

- [ ] **Step 2: 验证 changesets 二进制**

Run: `pnpm changeset --help`
Expected: exit 0

- [ ] **Step 3: 验证4个 manifest 版本同步在 6.4.4**

Run: `./scripts/sync-plugin-versions.sh --check`
Expected: `All manifests in sync at 6.4.4`，exit 0

- [ ] **Step 4: 验证 CHANGELOG.md 含64个版本**

Run: `grep -c '^## ' CHANGELOG.md`
Expected: `64`

Run: `grep -m1 '^## ' CHANGELOG.md`
Expected: `## 6.4.4`

- [ ] **Step 5: 验证旧文件已删除**

Run: `ls scripts/bump-version.sh .version-bump.json RELEASE-NOTES.md tests/plugin-infrastructure/test-bump-version.sh tests/plugin-infrastructure/test-bump-version-agent.sh scripts/migrate-release-notes.sh 2>&1`
Expected: 全部 `No such file or directory`

- [ ] **Step 6: 验证无旧引用残留**

Run: `grep -rn 'bump-version\|RELEASE-NOTES\|version-bump' scripts/ tests/ CLAUDE.md tests/CLAUDE.md`
Expected: 0 行匹配

- [ ] **Step 7: 验证 `.changeset/` 被 git 跟踪**

Run: `git check-ignore .changeset/config.json && echo IGNORED || echo tracked`
Expected: `tracked`（.changeset/ 不被 .gitignore 忽略）

---

## Final Commit（手动）

本 plan 采用手动提交策略。所有 task 完成后，一次性提交：

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(versioning): 迁移到 changesets 版本管理

- 用 @changesets/cli + @changesets/changelog-github 替换自研 bump-version.sh
- 新增 sync-plugin-versions.sh 同步3个插件 manifest，保留 --check drift 检测
- 迁移64个历史版本 RELEASE-NOTES.md → CHANGELOG.md（去 v 前缀和日期）
- 删除 bump-version.sh、.version-bump.json、2个旧测试、RELEASE-NOTES.md、迁移脚本
- package.json 加 private:true，release 脚本改为 changeset version && sync
- CLAUDE.md / tests/CLAUDE.md 文档同步更新
EOF
)"
```

也可按逻辑阶段拆分多次提交（推荐，符合仓库 commit 风格）：
1. `chore(deps): add changesets cli + changelog-github`
2. `feat(scripts): add sync-plugin-versions.sh + tests`
3. `chore(versioning): migrate RELEASE-NOTES to CHANGELOG, delete bump-version`
4. `docs: update CLAUDE.md release section for changesets workflow`

---

## Self-Review

**Spec coverage:**
- spec 第1节（依赖与配置）→ Task 1 ✓
- spec 第2节（sync-plugin-versions.sh）→ Task 2 ✓
- spec 第3节（历史迁移）→ Task 3 + Task 6 ✓
- spec 第4节（测试与文档）→ Task 4 + Task 5 ✓
- spec 实施顺序8步 → Task 1-7 覆盖（步骤8手动 e2e 合并到 Task 7 Step 2-3）✓

**Sprint contract DoD 追溯:**
- 17条 DoD 全部映射到 Task 1-7 的验证步骤 ✓

**Placeholder scan:** 无 TBD/TODO，所有代码块含完整实现 ✓

**Type consistency:** sync 脚本中 `TARGETS` 数组的3条目格式 `rel|field` 在 cmd_sync/cmd_check/test 中一致使用；jq 字段路径 `.plugins[0].version` 与 marketplace.json 结构匹配 ✓

**Scope scan:** 无全局 token 替换；删除的4个文件 + 修改的 run-all.sh 已在 Task 4 列全 ✓
