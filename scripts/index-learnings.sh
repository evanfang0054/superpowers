#!/usr/bin/env bash
# index-learnings.sh - Cluster learnings.jsonl by type/key, output top-N summary.
#
# Usage: index-learnings.sh [--max-entries N] [--min-confidence C] [--recent-within-days D]
#
# 实时计算，不持久化。供 SessionStart hook 与人工查询用。

set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FILE="$ROOT/.agent-harness/learnings.jsonl"

MAX_ENTRIES=5; MIN_CONF=0; RECENT_DAYS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --max-entries) MAX_ENTRIES="$2"; shift 2 ;;
    --min-confidence) MIN_CONF="$2"; shift 2 ;;
    --recent-within-days) RECENT_DAYS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ ! -f "$FILE" ] && { echo "_(无 learnings)_"; exit 0; }

MAX_ENTRIES="$MAX_ENTRIES" MIN_CONF="$MIN_CONF" RECENT_DAYS="$RECENT_DAYS" \
FILE="$FILE" python3 - <<'PY'
import json, os, datetime, collections
path = os.environ["FILE"]
max_n = int(os.environ["MAX_ENTRIES"])
min_conf = int(os.environ["MIN_CONF"])
recent = os.environ["RECENT_DAYS"]
now = datetime.datetime.now(datetime.timezone.utc)
cutoff = None
if recent:
    try: cutoff = now - datetime.timedelta(days=int(recent))
    except ValueError: pass

groups = collections.defaultdict(list)
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try: d = json.loads(line)
        except json.JSONDecodeError: continue
        if int(d.get("confidence", 0)) < min_conf: continue
        if cutoff:
            try:
                ts = datetime.datetime.fromisoformat(d["ts"].replace("Z","+00:00"))
                if ts < cutoff: continue
            except Exception: pass
        groups[d.get("type","?")].append(d)

if not groups:
    print("_(无 learnings)_"); raise SystemExit

for t in sorted(groups):
    items = sorted(groups[t], key=lambda x: -int(x.get("confidence",0)))[:max_n]
    print(f"## {t}")
    for it in items:
        conf = it.get("confidence","?")
        key = it.get("key","?")
        ins = it.get("insight","").replace("\n"," ")[:100]
        print(f"- [{conf}] **{key}** — {ins}")
    print()
PY
