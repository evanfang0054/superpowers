#!/usr/bin/env bash
# Shared helpers for diagnose-failure.sh.
# 封装对 query-phase-metrics 的调用，信号源缺失时优雅降级（输出空字段，不崩）。

SCRIPT_DIR_DIAG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# diagnose_phase_history <phase> [spec-topic]
# 输出：jsonl 段（同阶段历史失败信息）
diagnose_phase_history() {
  local phase="$1" topic="${2:-}"
  local q="$SCRIPT_DIR_DIAG/query-phase-metrics.sh"
  [ ! -x "$q" ] && { echo "{}"; return; }
  if [ -n "$topic" ]; then
    "$q" --phase "$phase" --by-spec "$topic" --json 2>/dev/null || echo "{}"
  else
    "$q" --phase "$phase" --json 2>/dev/null || echo "{}"
  fi
}
