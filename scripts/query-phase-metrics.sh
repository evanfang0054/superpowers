#!/usr/bin/env bash
# query-phase-metrics.sh - Aggregate-query .agent-harness/phase-metrics.jsonl
#
# Usage:
#   query-phase-metrics.sh --phase <name> [--summary]
#                          [--by-spec <topic>] [--recent <days>]
#                          [--json]
#
# 输出：count / avg_duration_ms / p50 / p95 / failed / failure_rate /
#       total_input_tokens / total_output_tokens / total_cost_usd / retries

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/phase-metrics-lib.sh" 2>/dev/null || true

PHASE=""; SUMMARY="no"; BY_SPEC=""; RECENT_DAYS=""; JSON_OUT="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --summary) SUMMARY="yes"; shift ;;
    --by-spec) BY_SPEC="$2"; shift 2 ;;
    --recent) RECENT_DAYS="$2"; shift 2 ;;
    --json) JSON_OUT="yes"; shift ;;
    *) echo "query-phase-metrics: unknown arg '$1'" >&2; shift ;;
  esac
done

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FILE="$ROOT/.agent-harness/phase-metrics.jsonl"

[ -z "$PHASE" ] && PHASE="all"
[ ! -f "$FILE" ] && {
  if [ "$JSON_OUT" = "yes" ]; then
    echo '{"count":0}'
  else
    echo "count: 0 (no metrics file)"
  fi
  exit 0
}

PHASE="$PHASE" BY_SPEC="$BY_SPEC" RECENT_DAYS="$RECENT_DAYS" \
JSON_OUT="$JSON_OUT" SUMMARY="$SUMMARY" FILE="$FILE" \
python3 <<'PYTHON'
import json, os, sys, datetime
phase = os.environ["PHASE"]
by_spec = os.environ["BY_SPEC"]
recent = os.environ["RECENT_DAYS"]
json_out = os.environ["JSON_OUT"] == "yes"
summary = os.environ["SUMMARY"] == "yes"
path = os.environ["FILE"]

now = datetime.datetime.now(datetime.timezone.utc)
cutoff = None
if recent:
    try:
        cutoff = now - datetime.timedelta(days=int(recent))
    except ValueError:
        pass

rows = []
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if phase != "all" and d.get("phase") != phase:
            continue
        if by_spec and d.get("spec_topic") != by_spec:
            continue
        if cutoff:
            try:
                ts = datetime.datetime.fromisoformat(d["ts"].replace("Z", "+00:00"))
                if ts < cutoff:
                    continue
            except (KeyError, ValueError):
                pass
        rows.append(d)

def pct(p, xs):
    if not xs: return 0
    xs = sorted(xs)
    k = max(0, min(len(xs) - 1, int(round((p/100.0) * (len(xs) - 1)))))
    return xs[k]

durations = [int(r.get("duration_ms", 0)) for r in rows]
failed = sum(1 for r in rows if r.get("gate_result") == "failed")
tok_in = sum(int(r.get("input_tokens", 0)) for r in rows)
tok_out = sum(int(r.get("output_tokens", 0)) for r in rows)
cost = sum(float(r.get("estimated_cost_usd", 0)) for r in rows)
retries = sum(int(r.get("retries", 0)) for r in rows)
count = len(rows)

result = {
    "phase": phase,
    "count": count,
    "avg_duration_ms": int(sum(durations) / count) if count else 0,
    "p50_duration_ms": pct(50, durations),
    "p95_duration_ms": pct(95, durations),
    "failed": failed,
    "failure_rate": round(failed / count, 3) if count else 0,
    "total_input_tokens": tok_in,
    "total_output_tokens": tok_out,
    "total_cost_usd": round(cost, 6),
    "retries": retries,
}

if json_out:
    print(json.dumps(result, ensure_ascii=False))
else:
    for k, v in result.items():
        print(f"{k}: {v}")
PYTHON
