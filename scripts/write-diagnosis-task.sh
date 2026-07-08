#!/usr/bin/env bash
# write-diagnosis-task.sh - Convert a diagnosis JSON into a markdown task.
#
# Usage: write-diagnosis-task.sh --diagnosis <json-file> [--plan <path>]
#
# 默认 --plan 缺省时：写独立文件到 docs/agent-harness/notes/diagnoses/<ts>-<type>.md。
# 只有显式 --plan 才追加到计划文件。
# 不自动执行修复——只生成 task。

set -uo pipefail

DIAG=""; PLAN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --diagnosis) DIAG="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$DIAG" ] && { echo "write-diagnosis-task: --diagnosis required" >&2; exit 1; }
[ ! -f "$DIAG" ] && { echo "write-diagnosis-task: file not found: $DIAG" >&2; exit 1; }

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

DIAG="$DIAG" PLAN="$PLAN" ROOT="$ROOT" python3 <<'PY'
import json, os, datetime
diag = json.load(open(os.environ["DIAG"], encoding="utf-8"))
plan = os.environ["PLAN"]
root = os.environ["ROOT"]

lines = ["", "## Diagnosis Task (auto-generated)", ""]
lines.append(f"- **failure_type**: {diag.get('failure_type')}")
lines.append(f"- **spec_topic**: {diag.get('spec_topic','')}")
lines.append(f"- **summary**: {diag.get('failure_summary','')}")
lines.append(f"- **root_cause**: {diag.get('root_cause_hypothesis','')}")
lines.append(f"- **confidence**: {diag.get('confidence')}")
lines.append(f"- **ts**: {diag.get('ts')}")
lines.append("- **suggested fixes**:")
for fx in diag.get("suggested_fixes", []):
    lines.append(f"  - [ ] `{fx.get('action')}` — {fx.get('rationale')}")
lines.append("")

block = "\n".join(lines)

if plan and os.path.isfile(plan):
    with open(plan, "a", encoding="utf-8") as f:
        f.write(block + "\n")
    print(f"appended to {plan}")
else:
    out_dir = os.path.join(root, "docs/agent-harness/notes/diagnoses")
    os.makedirs(out_dir, exist_ok=True)
    ts = diag.get("ts", datetime.datetime.utcnow().isoformat()).replace(":", "").replace("-", "")[:15]
    ftype = diag.get("failure_type", "x")
    out = os.path.join(out_dir, f"{ts}-{ftype}.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write(f"# Diagnosis {ftype} @ {diag.get('ts')}\n")
        f.write(block + "\n")
    print(f"standalone: {out}")
PY
