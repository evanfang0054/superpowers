#!/usr/bin/env bash
# log-phase-metric.sh - Record a phase-boundary event to phase-metrics.jsonl
#
# Usage:
#   log-phase-metric.sh --phase <name> --action <start|end|gate> \
#     [--duration-ms <n>] [--tokens-in <n>] [--tokens-out <n>] \
#     [--model <name>] [--spec-topic <t>] [--gate-result <passed|failed>] \
#     [--retries <n>] [--lines-added <n>] [--lines-deleted <n>] [--files-changed <n>]
#
# 缺省时 lines/files 自动从 git diff --numstat 统计；tokens/cost 缺省为 0。
# 失败静默（stderr 警告），绝不阻断主流程。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/phase-metrics-lib.sh
. "$SCRIPT_DIR/lib/phase-metrics-lib.sh"

# 解析参数
PHASE=""; ACTION=""; DURATION_MS=0; TOKENS_IN=0; TOKENS_OUT=0
MODEL="default"; SPEC_TOPIC=""; GATE_RESULT=""; RETRIES=0
LINES_ADDED=""; LINES_DELETED=""; FILES_CHANGED=""

while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --duration-ms) DURATION_MS="$2"; shift 2 ;;
    --tokens-in) TOKENS_IN="$2"; shift 2 ;;
    --tokens-out) TOKENS_OUT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --spec-topic) SPEC_TOPIC="$2"; shift 2 ;;
    --gate-result) GATE_RESULT="$2"; shift 2 ;;
    --retries) RETRIES="$2"; shift 2 ;;
    --lines-added) LINES_ADDED="$2"; shift 2 ;;
    --lines-deleted) LINES_DELETED="$2"; shift 2 ;;
    --files-changed) FILES_CHANGED="$2"; shift 2 ;;
    *) echo "log-phase-metric: unknown arg '$1'" >&2; shift ;;
  esac
done

# 基本校验（失败不抛异常，警告后 exit 0）
if [ -z "$PHASE" ] || [ -z "$ACTION" ]; then
  echo "log-phase-metric: --phase and --action required" >&2
  exit 0
fi

# 自动 git diffstat（仅当未显式传值）
if [ -z "$LINES_ADDED" ] || [ -z "$LINES_DELETED" ] || [ -z "$FILES_CHANGED" ]; then
  read -r _LA _LD _FC < <(phase_metrics_diffstat | tr '\n' ' ')
  [ -z "$LINES_ADDED" ]   && LINES_ADDED="${_LA:-0}"
  [ -z "$LINES_DELETED" ] && LINES_DELETED="${_LD:-0}"
  [ -z "$FILES_CHANGED" ] && FILES_CHANGED="${_FC:-0}"
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
mkdir -p "$ROOT/.agent-harness"
OUT="$ROOT/.agent-harness/phase-metrics.jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SID=$(phase_metrics_session_id)

# 通过环境变量传给 python，避免 heredoc 注入（同 log-learning.sh 模式）
TS="$TS" SID="$SID" PHASE="$PHASE" ACTION="$ACTION" \
DURATION_MS="$DURATION_MS" TOKENS_IN="$TOKENS_IN" TOKENS_OUT="$TOKENS_OUT" \
MODEL="$MODEL" SPEC_TOPIC="$SPEC_TOPIC" GATE_RESULT="$GATE_RESULT" \
RETRIES="$RETRIES" LINES_ADDED="$LINES_ADDED" LINES_DELETED="$LINES_DELETED" \
FILES_CHANGED="$FILES_CHANGED" RATE_TABLE="$PHASE_METRICS_RATE_TABLE" \
python3 <<'PYTHON' >> "$OUT" 2>/dev/null || { echo "log-phase-metric: write failed" >&2; exit 0; }
import json, os
rate = json.loads(os.environ["RATE_TABLE"])
m = os.environ["MODEL"]
rates = rate.get(m, rate["default"])
cost = (int(os.environ["TOKENS_IN"]) * rates["input"]
        + int(os.environ["TOKENS_OUT"]) * rates["output"]) / 1_000_000.0
entry = {
    "ts": os.environ["TS"],
    "session_id": os.environ["SID"],
    "spec_topic": os.environ["SPEC_TOPIC"],
    "phase": os.environ["PHASE"],
    "action": os.environ["ACTION"],
    "duration_ms": int(os.environ["DURATION_MS"]),
    "input_tokens": int(os.environ["TOKENS_IN"]),
    "output_tokens": int(os.environ["TOKENS_OUT"]),
    "estimated_cost_usd": round(cost, 6),
    "model": m,
    "lines_added": int(os.environ["LINES_ADDED"]),
    "lines_deleted": int(os.environ["LINES_DELETED"]),
    "files_changed": int(os.environ["FILES_CHANGED"]),
    "gate_result": os.environ["GATE_RESULT"],
    "retries": int(os.environ["RETRIES"]),
}
print(json.dumps(entry, ensure_ascii=False))
PYTHON

exit 0
