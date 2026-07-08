#!/usr/bin/env bash
# Shared helpers for phase-metrics scripts.
# Sourced by log-phase-metric.sh and query-phase-metrics.sh.

# 本地费率表（USD per 1M tokens，2026-06 参考；非外部依赖）
# 新模型在此追加；查询时按 model 名查表，查不到回退到 default。
PHASE_METRICS_RATE_TABLE='{
  "claude-sonnet-4-6": {"input": 3.0, "output": 15.0},
  "claude-opus-4-6":   {"input": 15.0, "output": 75.0},
  "claude-haiku-4-5":  {"input": 0.8, "output": 4.0},
  "default":           {"input": 3.0, "output": 15.0}
}'

# 解析 session_id：优先 CLAUDE_SESSION_ID，其次 git HEAD 时间戳兜底
phase_metrics_session_id() {
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    printf '%s' "$CLAUDE_SESSION_ID"
  else
    git rev-parse --short HEAD 2>/dev/null | tr -d '\n'
    printf '-%s' "$(date -u +%Y%m%d%H%M%S)"
  fi
}

# 从 git diff --numstat 统计 lines/files（不接受未跟踪文件）
# 输出三行：lines_added / lines_deleted / files_changed
phase_metrics_diffstat() {
  local added=0 deleted=0 files=0
  while IFS=$'\t' read -r a d _; do
    [ "$a" = "-" ] && continue  # 二进制
    added=$((added + a))
    deleted=$((deleted + d))
    files=$((files + 1))
  done < <(git diff --numstat 2>/dev/null || true)
  printf '%s\n%s\n%s\n' "$added" "$deleted" "$files"
}
