#!/usr/bin/env bash
# diagnose-failure.sh - Converge failure signals into a structured diagnosis JSON.
#
# Usage:
#   diagnose-failure.sh --type <loop|gate|test> --context <json-string|@file>
#                       [--spec-topic <t>] [--phase <name>]
#
# 产物：.agent-harness/diagnoses/<ts>-<type>-<slug>.json

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/diagnose-lib.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

TYPE=""; CONTEXT_RAW=""; SPEC_TOPIC=""; PHASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE="$2"; shift 2 ;;
    --context) CONTEXT_RAW="$2"; shift 2 ;;
    --spec-topic) SPEC_TOPIC="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$TYPE" ] && { echo "diagnose-failure: --type required" >&2; exit 0; }

# context 接受字符串、文件路径或 @file
CONTEXT=""
if [ -n "$CONTEXT_RAW" ]; then
  if [ "${CONTEXT_RAW#@}" != "$CONTEXT_RAW" ]; then
    CONTEXT_FILE="${CONTEXT_RAW#@}"
    [ -f "$CONTEXT_FILE" ] && CONTEXT=$(cat "$CONTEXT_FILE")
  elif [ -f "$CONTEXT_RAW" ]; then
    CONTEXT=$(cat "$CONTEXT_RAW")
  else
    CONTEXT="$CONTEXT_RAW"
  fi
fi

mkdir -p "$ROOT/.agent-harness/diagnoses"

TS=$(date -u +%Y%m%dT%H%M%SZ)
SLUG=$(printf '%s' "$SPEC_TOPIC$TYPE" | python3 -c 'import sys,re; print(re.sub(r"[^a-z0-9]+","-",sys.stdin.read().lower()).strip("-") or "x")' 2>/dev/null || echo "x")
OUT="$ROOT/.agent-harness/diagnoses/${TS}-${TYPE}-${SLUG}.json"

# 推断 phase（gate/test 类型可从 context 提取）
[ -z "$PHASE" ] && PHASE=$(printf '%s' "$CONTEXT" | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin); print(d.get("phase",""))
except Exception: print("")' 2>/dev/null || true)

TRACE=$(diagnose_trace "$CONTEXT")
HIST="{}"
[ -n "$PHASE" ] && HIST=$(diagnose_phase_history "$PHASE" "$SPEC_TOPIC")
LEARN=$(diagnose_similar_learnings "${SPEC_TOPIC:-$TYPE}")

TS_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

TS_ISO="$TS_ISO" TYPE="$TYPE" SPEC_TOPIC="$SPEC_TOPIC" PHASE="$PHASE" \
CONTEXT="$CONTEXT" TRACE="$TRACE" HIST="$HIST" LEARN="$LEARN" \
OUT="$OUT" python3 <<'PY'
import json, os
ts = os.environ["TS_ISO"]
ftype = os.environ["TYPE"]
topic = os.environ["SPEC_TOPIC"]
phase = os.environ["PHASE"]
ctx_raw = os.environ["CONTEXT"]
try:
    ctx = json.loads(ctx_raw) if ctx_raw else {}
except Exception:
    ctx = {"raw": ctx_raw}

trace = os.environ["TRACE"]
try: hist = json.loads(os.environ["HIST"] or "{}")
except Exception: hist = {}
try: learn = json.loads(os.environ["LEARN"] or "[]")
except Exception: learn = []

summary_bits = []
if ftype == "loop":
    summary_bits.append(f"{ctx.get('edits','?')} 次编辑 {ctx.get('file','?')} 未收敛")
elif ftype == "gate":
    summary_bits.append(f"phase={phase} 门禁失败: {ctx.get('validate_error', ctx.get('last_error',''))}")
elif ftype == "test":
    summary_bits.append(f"测试/验证失败 exit={ctx.get('exit_code','?')}: {ctx.get('cmd', ctx.get('last_error',''))}")
summary = " | ".join(summary_bits) or "未知失败"

root_cause = ""
if "schema" in trace.lower() or "schema" in str(ctx).lower():
    root_cause = "frontmatter schema 与 spec #2 要求不匹配"
elif "gate" in trace.lower():
    root_cause = "门禁前置校验失败，需回到上一阶段"
elif not trace:
    root_cause = "信号不足，需人工根因分析"

fixes = []
if root_cause.startswith("frontmatter"):
    fixes.append({"action": "revisit-brainstorming", "rationale": "补全 frontmatter 必填字段"})
elif root_cause.startswith("门禁"):
    fixes.append({"action": "revisit-prior-phase", "rationale": "回到失败阶段的上游"})
if isinstance(hist, dict) and hist.get("failure_rate", 0) > 0.3:
    fixes.append({"action": "manual-intervention", "rationale": f"历史失败率 {hist.get('failure_rate')} 过高"})
if not fixes:
    fixes.append({"action": "manual-intervention", "rationale": "信号不足"})

out = {
    "ts": ts,
    "failure_type": ftype,
    "spec_topic": topic,
    "failure_summary": summary,
    "evidence": {
        "trace_classification": trace[:200] if trace else "",
        "phase_history": hist,
        "similar_learnings": learn,
    },
    "root_cause_hypothesis": root_cause,
    "suggested_fixes": fixes,
    "confidence": 7 if root_cause else 3,
}
with open(os.environ["OUT"], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print(os.environ["OUT"])
PY

echo "diagnosis written: $OUT" >&2
