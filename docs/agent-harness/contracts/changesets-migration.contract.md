# Sprint Contract: changesets-migration

## Definition of Done

- [ ] `@changesets/cli` + `@changesets/changelog-github` 在 package.json devDependencies，`pnpm install` 成功
- [ ] `.changeset/config.json` 有效：changelog-github repo=`evanfang0054/agent-harness`，`privatePackages.version: true`，`baseBranch: main`，`commit: false`
- [ ] `package.json` 有 `"private": true`；`release` 脚本 = `changeset version && ./scripts/sync-plugin-versions.sh`；`changeset` 脚本 = `changeset`
- [ ] `scripts/sync-plugin-versions.sh` 读 package.json version，写入3个 manifest（`.claude-plugin/plugin.json` `.version`、`.codex-plugin/plugin.json` `.version`、`.claude-plugin/marketplace.json` `.plugins[0].version`）；任一目标文件缺失时 exit 1（不静默跳过）
- [ ] `sync-plugin-versions.sh --check`：版本一致时 exit 0；任一 manifest drift 时 exit 2 + 报告文件名 + 期望值 vs 实际值
- [ ] `CHANGELOG.md` 是新文件（迁移前不存在）；迁移后 `grep -c '^## ' CHANGELOG.md` == 64；首条为 `## 6.4.4`（此校验在任何新 `changeset version` 运行之前完成）
- [ ] `RELEASE-NOTES.md` 已删除
- [ ] `scripts/bump-version.sh` + `.version-bump.json` 已删除
- [ ] `tests/plugin-infrastructure/test-bump-version.sh` + `test-bump-version-agent.sh` 已删除；`test-sync-plugin-versions.sh` 已新增
- [ ] `tests/plugin-infrastructure/run-all.sh` 的 TESTS 数组：移除2条旧测试，新增1条 `test-sync-plugin-versions.sh`
- [ ] `grep -rn 'bump-version\|RELEASE-NOTES\|version-bump' scripts/ tests/ CLAUDE.md tests/CLAUDE.md docs/agent-harness/specs/2026-07-29-changesets-migration-design.md` 返回0匹配（无遗留引用；spec 自身标题提及旧系统名属正常，排除 spec 本身）
- [ ] 4个 manifest 均读 `6.4.4`（版本号不变，仅管理系统迁移）
- [ ] `./tests/plugin-infrastructure/run-all.sh` exit 0（全套，含 codex-plugin-sync manifest 一致性测试）
- [ ] `pnpm changeset --help` 成功（二进制可解析，冒烟测试）
- [ ] `scripts/migrate-release-notes.sh` 最终状态不存在（一次性脚本，迁移后删除）
- [ ] `.changeset/` 目录被 git 跟踪（changeset 文件需入 git，不被 .gitignore 忽略）
- [ ] `CLAUDE.md` 发布章节文档化 `pnpm changeset` + `pnpm release` 工作流；`tests/CLAUDE.md` 套件表更新

## Boundary Conditions

- **必须支持**：`pnpm release` 保留肌肉记忆，`pnpm changeset` 作为新入口
- **必须不破坏**：codex-plugin-sync 测试（3个 manifest 版本一致性）；hooks/session-start 行为；auto-loop 不依赖 bump-version.sh
- **版本约束**：迁移期间版本号保持 6.4.4 不变，下一个版本由首次 `changeset version` 生成
- **环境**：jq 必须可用（sync 脚本依赖）；pnpm 作为包管理器
- **不引入 CI/CD**：本地手动模式，无 GitHub Actions

## Acceptance Criteria

- **计算性（传感器）**：
  - `./tests/plugin-infrastructure/run-all.sh` exit 0（纯脚本套件，秒级确定性）
  - `grep -c '^## ' CHANGELOG.md` == 64
  - `sync-plugin-versions.sh --check` exit 0（4文件同步）
  - `pnpm changeset --help` exit 0
  - 旧引用 grep 返回0匹配
- **推断性（审查方法）**：
  - spec 文件 `docs/agent-harness/specs/2026-07-29-changesets-migration-design.md` 已获用户确认
  - diff 审查：删除的文件清单 + 新增的文件清单与 spec 文件清单一致

## Negotiation Record

- **Generator R1**：初版9条 DoD，覆盖依赖/配置/脚本/迁移/删除/测试/文档
- **Evaluator R1**：挑战4点——"sync 同步"对缺失文件行为未定义；64版本数会被后续 changeset version 污染需限定校验时机；codex-plugin-sync 测试需纳入；缺"无遗留引用"grep 闸门；缺"4 manifest 版本不变"确认
- **Generator R2**：补齐——缺目标 exit 1；迁移后立即校验 grep==64（在任何新 changeset version 前）；run-all.sh 全套含 codex-sync；grep 旧引用返回0；4 manifest 读 6.4.4
- **Evaluator R2**：接受 R2，补2点——迁移脚本本身要删；.changeset/ 要入 git
- **Generator R3**：补齐 migrate-release-notes.sh 删除 + .changeset/ git 跟踪，达成共识
- **Final consensus**：17条 DoD + 5条边界条件 + 计算性/推断性验收标准
