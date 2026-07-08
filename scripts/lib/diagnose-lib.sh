#!/usr/bin/env bash
# Shared helpers for diagnose-failure.sh.
# 封装对 trace-analyzer / query-phase-metrics / search-learnings 的调用，
# 三个信号源任一缺失都优雅降级（输出空字段，不崩）。

SCRIPT_DIR_DIAG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# diagnose_trace <context-json>
# 输出：失败模式分类字符串（无则空）
diagnose_trace() {
  local ctx="$1"
  local ta="$SCRIPT_DIR_DIAG/trace-analyzer.sh"
  [ ! -x "$ta" ] && { echo ""; return; }
  # trace-analyzer 接受文件或 stdin；这里传 ctx 字符串
  printf '%s' "$ctx" | "$ta" 2>/dev/null | head -50 || true
}

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

# diagnose_similar_learnings <keyword>
# 输出：top-N learnings json（数组）
diagnose_similar_learnings() {
  local kw="$1"
  local s="$SCRIPT_DIR_DIAG/search-learnings.sh"
  [ ! -x "$s" ] && { echo "[]"; return; }
  "$s" "$kw" 2>/dev/null | python3 -c '
import sys, json, re
out = []
for line in sys.stdin:
    m = re.match(r".*\[(\d+)\]\s+\*\*(.+?)\*\*\s+—\s+(.*)$", line)
    if m:
        out.append({"confidence": int(m.group(1)), "key": m.group(2), "insight": m.group(3)})
print(json.dumps(out[:5], ensure_ascii=False))
' 2>/dev/null || echo "[]"
}
