#!/usr/bin/env bash
# 从顶层 skills/ 生成 DeepSeek Harness 化副本（.dsh/agent-preset/skills/）。
#
# 设计原则（与 .codex-plugin/、.pi/ 的共享源模式一致）：
#   - 顶层 skills/ 是唯一真相源，本脚本不修改它，任何平台的行为都不受影响；
#   - DSH 不支持 manifest 引用目录，只认实际存在的 skills 目录，因此 agent
#     preset 需要一份实文件副本；
#   - 副本与顶层仅有的系统性差异都在 SKILL.md frontmatter：
#       1) when_to_use (Claude Code 认 snake_case) → whenToUse (DSH 只认 camelCase)；
#       2) 移除 disable-model-invocation: true —— Claude Code 中模型仍可显式
#          加载此类 skill，但 DSH 的 skill 工具对 modelInvocable=false 直接
#          拒绝，DSH 下模型调用是唯一通道，必须放开。
#     其余文件字节级一致，保证一致性测试简单可靠。
#   - auto-loop 不是标准 skill（orchestrator-prompt.md 由脚本注入），跳过。
#
# 用法：bash scripts/sync-dsh-skills.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/skills"
DST="$REPO_ROOT/.dsh/agent-preset/skills"

# 非标准 skill：没有 SKILL.md，由 scripts/auto-loop.sh 注入，DSH 下不适用
SKIP_DIRS=(auto-loop)

rm -rf "$DST"
mkdir -p "$DST"

converted=0
skipped=0
for dir in "$SRC"/*/; do
  name="$(basename "$dir")"
  if [[ " ${SKIP_DIRS[*]} " == *" $name "* ]]; then
    echo "  [skip] $name (非标准 skill)"
    skipped=$((skipped + 1))
    continue
  fi
  if [[ ! -f "$dir/SKILL.md" ]]; then
    echo "  [skip] $name (无 SKILL.md)"
    skipped=$((skipped + 1))
    continue
  fi

  cp -R "$dir" "$DST/$name"

  # frontmatter 区域（首个 --- 到第二个 ---）内做 DSH 化转换：
  #   1. when_to_use: → whenToUse:（DSH 只认 camelCase）
  #   2. 删除 disable-model-invocation: true（Claude Code 中模型仍可用 Skill
  #      工具显式加载此类 skill，但 DSH 的 skill 工具对 modelInvocable=false
  #      直接拒绝加载；DSH 下模型调用是唯一通道，必须放开）
  awk '
    BEGIN { infm = 0 }
    /^---[[:space:]]*$/ {
      if (infm == 0) { infm = 1 } else if (infm == 1) { infm = 0 }
      print
      next
    }
    infm == 1 && /^when_to_use:[[:space:]]*/ { sub(/^when_to_use:/, "whenToUse:") }
    infm == 1 && /^disable-model-invocation:[[:space:]]*true[[:space:]]*$/ { next }
    { print }
  ' "$dir/SKILL.md" > "$DST/$name/SKILL.md"

  converted=$((converted + 1))
done

echo "sync-dsh-skills: 生成 $converted 个 skill -> ${DST} (跳过 $skipped 个)"
