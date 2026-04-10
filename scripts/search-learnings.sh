#!/usr/bin/env bash
# search-learnings.sh - Search project learnings with confidence decay and dedup
#
# Usage:
#   search-learnings.sh <keyword>           # Search by keyword
#   search-learnings.sh --type <type>       # Filter by type
#   search-learnings.sh --recent [N]        # Show recent N entries (default: 10)
#   search-learnings.sh --all               # Show all entries
#   search-learnings.sh --summary           # Show formatted summary (for session-start)
#
# Features:
#   - Confidence decay: observed/inferred lose 1pt per 30 days
#   - Deduplication: latest entry wins per key+type
#   - Formatted output grouped by type

set -euo pipefail

LEARNINGS_FILE=".superpowers/learnings.jsonl"

# Check if learnings file exists
if [ ! -f "$LEARNINGS_FILE" ]; then
    exit 0
fi

# Count total
total=$(wc -l < "$LEARNINGS_FILE" 2>/dev/null | tr -d ' ')
if [ "$total" -eq 0 ]; then
    exit 0
fi

# Parse arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <keyword> | --type <type> | --recent [N] | --all | --summary"
    echo ""
    echo "Total learnings: $total"
    exit 0
fi

# Format learnings with Python (reads file directly, filter via env var)
format_learnings() {
    local filter="${1:-}"
    local type_filter="${2:-}"
    LEARNINGS_FILTER="$filter" LEARNINGS_TYPE_FILTER="$type_filter" python3 - "$LEARNINGS_FILE" << 'PYTHON'
import json
import sys
import os
from datetime import datetime
from collections import defaultdict

file_path = sys.argv[1] if len(sys.argv) > 1 else '.superpowers/learnings.jsonl'
filter_text = os.environ.get('LEARNINGS_FILTER', '').lower()
type_filter = os.environ.get('LEARNINGS_TYPE_FILTER', '').lower()

try:
    with open(file_path, 'r') as f:
        lines = f.read().strip().split('\n')
except FileNotFoundError:
    sys.exit(0)

entries = []
now = datetime.now()

for line in lines:
    if not line.strip():
        continue
    try:
        e = json.loads(line)
        if 'key' not in e or 'type' not in e:
            continue
        
        # Apply type filter if specified
        if type_filter and e.get('type', '').lower() != type_filter:
            continue
        
        # Apply keyword filter if specified
        if filter_text:
            text_to_search = json.dumps(e).lower()
            if filter_text not in text_to_search:
                continue
        
        # Calculate effective confidence with decay
        conf = e.get('confidence', 5)
        source = e.get('source', '')
        ts = e.get('ts', '')
        
        if source in ('observed', 'inferred') and ts:
            try:
                # Handle ISO format with Z suffix
                ts_clean = ts.replace('Z', '+00:00')
                if '+' in ts_clean:
                    ts_clean = ts_clean.split('+')[0]
                entry_date = datetime.fromisoformat(ts_clean)
                days = (now - entry_date).days
                conf = max(1, conf - (days // 30))
            except:
                pass
        
        e['_effective_confidence'] = conf
        entries.append(e)
    except json.JSONDecodeError:
        continue

if not entries:
    if filter_text:
        print(f"No learnings matching '{filter_text}' found.")
    sys.exit(0)

# Dedup: keep latest per key+type
seen = {}
for e in entries:
    dk = e['key'] + '|' + e['type']
    if dk not in seen:
        seen[dk] = e
    else:
        existing_ts = seen[dk].get('ts', '')
        new_ts = e.get('ts', '')
        if new_ts > existing_ts:
            seen[dk] = e

results = list(seen.values())
results.sort(key=lambda x: x.get('_effective_confidence', 0), reverse=True)

# Group by type
by_type = defaultdict(list)
for e in results:
    by_type[e['type']].append(e)

# Summary line
type_counts = [f"{len(arr)} {t}{'s' if len(arr) > 1 else ''}" for t, arr in by_type.items()]
print(f"LEARNINGS: {len(results)} loaded ({', '.join(type_counts)})")
print()

# Output by type
for t, arr in sorted(by_type.items()):
    print(f"## {t.capitalize()}s")
    for e in arr:
        files = f" (files: {', '.join(e.get('files', []))})" if e.get('files') else ""
        date = e.get('ts', '')[:10] if e.get('ts') else 'unknown'
        print(f"- [{e['key']}] (confidence: {e['_effective_confidence']}/10, {e.get('source', 'unknown')}, {date})")
        print(f"  {e.get('insight', '')}{files}")
    print()
PYTHON
}

case "$1" in
    --summary)
        format_learnings ""
        ;;
    --all)
        echo "=== All Learnings ($total entries) ==="
        format_learnings ""
        ;;
    --recent)
        n="${2:-10}"
        echo "=== Recent $n Learnings ==="
        # For recent, just show last N lines formatted
        tail -"$n" "$LEARNINGS_FILE" > /tmp/superpowers_recent_$$.jsonl
        LEARNINGS_FILE="/tmp/superpowers_recent_$$.jsonl" format_learnings ""
        rm -f /tmp/superpowers_recent_$$.jsonl
        ;;
    --type)
        if [ -z "${2:-}" ]; then
            echo "Error: --type requires a type argument" >&2
            echo "Valid types: pattern, pitfall, preference, architecture, tool, operational" >&2
            exit 1
        fi
        type="$2"
        echo "=== Learnings of type: $type ==="
        format_learnings "" "$type"
        ;;
    --help|-h)
        echo "Usage: $0 <keyword> | --type <type> | --recent [N] | --all | --summary"
        echo ""
        echo "Options:"
        echo "  <keyword>        Search by keyword (case-insensitive)"
        echo "  --type <type>    Filter by type"
        echo "  --recent [N]     Show recent N entries (default: 10)"
        echo "  --all            Show all entries"
        echo "  --summary        Formatted summary for session start"
        echo ""
        echo "Types: pattern, pitfall, preference, architecture, tool, operational"
        echo "Total learnings: $total"
        ;;
    *)
        # Keyword search
        keyword="$1"
        echo "=== Learnings matching '$keyword' ==="
        format_learnings "$keyword"
        ;;
esac
