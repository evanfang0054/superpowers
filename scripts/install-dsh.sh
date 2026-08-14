#!/usr/bin/env bash
# 将 agent-harness 安装为 DeepSeek Harness 的全局能力。
#
# 做什么（默认）：
#   1. 运行 scripts/sync-dsh-skills.sh，从顶层 skills/ 生成 DSH 化副本；
#   2. 将 .dsh/agent-preset/ 整体复制到 $DSH_HOME/.agent-presets/agent-harness/，
#      注册为 DSH 的「Agent Harness 工作流」agent preset（GUI roster 可选可换）。
#
# 可选：
#   --user-skills  额外把 skills 副本复制到 $DSH_HOME/skills/，让 30 个 skill
#                  在任何 preset（含默认标准模式）下都全局可用。
#   --uninstall    删除上面安装的全部内容（不影响仓库内任何文件）。
#   --check        dry-run：只显示当前状态与将要执行的动作，不写入。
#
# 不修改仓库任何现有文件；顶层 skills/ 保持唯一真相源。
# 用法：bash scripts/install-dsh.sh [--user-skills|--uninstall|--check]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"

PRESET_NAME="agent-harness"
PRESET_SRC="$REPO_ROOT/.dsh/agent-preset"
PRESET_DST="$DSH_HOME/.agent-presets/$PRESET_NAME"
SKILLS_DST="$DSH_HOME/skills"

MODE="install"
USER_SKILLS=0

for arg in "$@"; do
  case "$arg" in
    --user-skills) USER_SKILLS=1 ;;
    --uninstall) MODE="uninstall" ;;
    --check) MODE="check" ;;
    *) echo "未知参数: $arg" >&2; exit 1 ;;
  esac
done

say() { printf '\033[1;36m[dsh]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[dsh]\033[0m %s\n' "$*"; }

if [[ "$MODE" == "uninstall" ]]; then
  rm -rf "$PRESET_DST"
  if [[ "$USER_SKILLS" == "1" ]]; then
    # 只删除本包平铺安装的 skill（按副本清单），不误删用户其他 skill
    for skill_dir in "$PRESET_SRC/skills"/*/; do
      name="$(basename "$skill_dir")"
      rm -rf "$SKILLS_DST/$name"
    done
  fi
  say "已卸载: $PRESET_DST"
  [[ "$USER_SKILLS" == "1" ]] && say "已卸载用户级 skills（按副本清单平铺删除）"
  exit 0
fi

user_skills_installed() {
  local count=0
  for skill_dir in "$PRESET_SRC/skills"/*/; do
    local name
    name="$(basename "$skill_dir")"
    [[ -d "$SKILLS_DST/$name" ]] && count=$((count + 1))
  done
  [[ "$count" -eq "$(ls "$PRESET_SRC/skills" | wc -l | tr -d ' ')" ]]
}

if [[ "$MODE" == "check" ]]; then
  echo "--- 当前状态 ---"
  [[ -d "$PRESET_DST" ]] && echo "  [已安装] preset: $PRESET_DST" || echo "  [未安装] preset: $PRESET_DST"
  if user_skills_installed; then
    echo "  [已安装] 用户级 skills（平铺于 $SKILLS_DST）"
  else
    echo "  [未安装] 用户级 skills"
  fi
  command -v dsh >/dev/null 2>&1 && echo "  dsh CLI: $(command -v dsh)" || warn "未找到 dsh 命令（可用 npx @deepseek-ai/dsh web 启动）"
  echo "--- 将要执行 ---"
  echo "  1) sync-dsh-skills.sh 生成 DSH 化副本"
  echo "  2) 复制 $PRESET_SRC -> $PRESET_DST"
  if [[ "$USER_SKILLS" == "1" ]]; then
    count="$(ls "$PRESET_SRC/skills" | wc -l | tr -d ' ')"
    echo "  3) 平铺复制 skills -> $SKILLS_DST（${count} 个）"
  fi
  exit 0
fi

# 1. 确保副本最新
say "同步 skills 副本..."
bash "$REPO_ROOT/scripts/sync-dsh-skills.sh"

# 2. 安装 agent preset（幂等：直接覆盖）
mkdir -p "$DSH_HOME/.agent-presets"
rm -rf "$PRESET_DST"
cp -R "$PRESET_SRC" "$PRESET_DST"
say "已安装 agent preset -> $PRESET_DST"

# 3. 可选：用户级 skills（任何 preset 下全局可用）
# 注意：DSH 的本地发现只支持一层目录 bundle（<name>/SKILL.md），不支持
# 递归嵌套，所以 30 个 skill 必须平铺到 ~/.dsh/skills/ 根下，不能用
# agent-harness/ 包装层（那会被当成一个缺 SKILL.md 的 bundle 而整体跳过）。
if [[ "$USER_SKILLS" == "1" ]]; then
  mkdir -p "$SKILLS_DST"
  installed=0
  for skill_dir in "$PRESET_SRC/skills"/*/; do
    name="$(basename "$skill_dir")"
    rm -rf "$SKILLS_DST/$name"
    cp -R "$skill_dir" "$SKILLS_DST/$name"
    installed=$((installed + 1))
  done
  say "已安装用户级 skills（${installed} 个，平铺）-> $SKILLS_DST"
fi

say "完成。启动方式：dsh web 后切换 preset 为「Agent Harness 工作流」，"
say "或在仓库目录内直接使用（项目级 .dsh/skills 自动发现）。"
