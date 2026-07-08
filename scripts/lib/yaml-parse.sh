#!/usr/bin/env bash
# Minimal YAML frontmatter parser (python3 helper, no third-party deps).
#
# 用法（source 后）：
#   yaml_parse_load <file>      # 解析 frontmatter，缓存到全局变量 YAML_FM_CACHE
#   yaml_parse_get <key>        # 打印某个字段值（无则空字符串）
#
# 仅支持扁平 key: value 与 key: [a, b, c] 列表；不支持嵌套。
# 复杂 schema 请手动结构化（本项目的 frontmatter 都保持扁平）。
#
# 实现：用 awk 提取首对 --- 之间的 frontmatter，交给同目录 python3 脚本
# yaml_parse_flat.py（纯标准库，无 PyYAML 依赖）解析为 KEY=VALUE 行，
# 缓存到 shell 变量 YAML_FM_CACHE。查询时用 grep 提取。
# 无临时文件，无并发竞态，无 symlink 注入面。

YAML_FM_CACHE=""
_YAML_PARSE_HELPER="$(dirname "${BASH_SOURCE[0]:-$0}")/yaml_parse_flat.py"

yaml_parse_load() {
  local file="$1"
  [ ! -f "$file" ] && { YAML_FM_CACHE=""; return 1; }

  YAML_FM_CACHE=$(awk '
    /^---[[:space:]]*$/ { c++; next }
    c == 1 { print }
    c >= 2 { exit }
  ' "$file" 2>/dev/null | python3 "$_YAML_PARSE_HELPER" 2>/dev/null || true)

  [ -z "$YAML_FM_CACHE" ] && return 1
  return 0
}

yaml_parse_get() {
  local key="$1"
  [ -z "$key" ] && { printf '%s' ""; return; }
  local line
  line=$(printf '%s\n' "$YAML_FM_CACHE" | grep -m1 "^${key}=" 2>/dev/null || true)
  printf '%s' "${line#*=}"
}
