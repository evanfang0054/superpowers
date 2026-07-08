#!/usr/bin/env bash
# search-learnings.sh - Search project learnings with confidence decay and dedup
#
# Usage:
#   search-learnings.sh <keyword>                    # Search by keyword
#   search-learnings.sh --type <type>                # Filter by type
#   search-learnings.sh --recent [N]                 # Show recent N entries (default: 10)
#   search-learnings.sh --all                        # Show all entries
#   search-learnings.sh --summary                    # Show formatted summary (for session-start)
#   search-learnings.sh --summary \
#       --max-entries 5 \
#       --min-confidence 7 \
#       --recent-within-days 30                      # Throttled summary (saves tokens)
#
# Features:
#   - Confidence decay: observed/inferred lose 1pt per 30 days
#   - Deduplication: latest entry wins per key+type
#   - Formatted output grouped by type
#   - Throttling: --max-entries / --min-confidence / --recent-within-days

set -euo pipefail

# Resolve project root: prefer CLAUDE_PROJECT_DIR (set by Claude Code harness),
# fall back to git rev-parse for manual runs / CI. Keep read location aligned
# with log-learning.sh write location.
LEARNINGS_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
LEARNINGS_FILE="$LEARNINGS_DIR/.agent-harness/learnings.jsonl"

# Cleanup any temp files we create (esp. for --recent branch which can leak
# under set -e if format_learnings raises Python exception on bad JSON).
_AGENT_HARNESS_TMP_CLEANUP=""
_agent_harness_cleanup() {
    if [ -n "$_AGENT_HARNESS_TMP_CLEANUP" ] && [ -f "$_AGENT_HARNESS_TMP_CLEANUP" ]; then
        rm -f "$_AGENT_HARNESS_TMP_CLEANUP"
    fi
}
trap _agent_harness_cleanup EXIT

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
    local max_entries="${3:-0}"          # 0 = no limit
    local min_confidence="${4:-0}"       # 0 = no filter
    local recent_within_days="${5:-0}"   # 0 = no filter
    LEARNINGS_FILTER="$filter" LEARNINGS_TYPE_FILTER="$type_filter" \
        LEARNINGS_MAX_ENTRIES="$max_entries" \
        LEARNINGS_MIN_CONFIDENCE="$min_confidence" \
        LEARNINGS_RECENT_WITHIN_DAYS="$recent_within_days" \
        python3 - "$LEARNINGS_FILE" << 'PYTHON'
import json
import sys
import os
from datetime import datetime, timedelta
from collections import defaultdict

file_path = sys.argv[1] if len(sys.argv) > 1 else '.agent-harness/learnings.jsonl'
filter_text = os.environ.get('LEARNINGS_FILTER', '').lower()
type_filter = os.environ.get('LEARNINGS_TYPE_FILTER', '').lower()
max_entries = int(os.environ.get('LEARNINGS_MAX_ENTRIES', '0') or '0')
min_confidence = int(os.environ.get('LEARNINGS_MIN_CONFIDENCE', '0') or '0')
recent_within_days = int(os.environ.get('LEARNINGS_RECENT_WITHIN_DAYS', '0') or '0')

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
# Sort: deterministic order so identical learning sets produce byte-equal
# summary output (cache-friendly prefix, issue #79). Confidence is still
# surfaced per-entry but no longer drives ordering.
results.sort(key=lambda x: (x.get('type', ''), x.get('key', '')))

# Apply throttle filters (--max-entries / --min-confidence / --recent-within-days)
if min_confidence > 0:
    results = [e for e in results if e.get('_effective_confidence', 0) >= min_confidence]

if recent_within_days > 0:
    cutoff = now - timedelta(days=recent_within_days)
    filtered = []
    for e in results:
        ts = e.get('ts', '')
        if not ts:
            continue
        try:
            ts_clean = ts.replace('Z', '+00:00')
            if '+' in ts_clean:
                ts_clean = ts_clean.split('+')[0]
            entry_date = datetime.fromisoformat(ts_clean)
            if entry_date >= cutoff:
                filtered.append(e)
        except Exception:
            continue
    results = filtered

if max_entries > 0 and len(results) > max_entries:
    results = results[:max_entries]

# Group by type
by_type = defaultdict(list)
for e in results:
    by_type[e['type']].append(e)

# Summary line
type_counts = [f"{len(arr)} {t}{'s' if len(arr) > 1 else ''}" for t, arr in by_type.items()]
print(f"LEARNINGS: {len(results)} loaded ({', '.join(type_counts)})")
print()

# Output by type. Groups are iterated in sorted order and entries within each
# group are sorted by key — both deterministic, so two runs over the same
# learning set produce byte-equal output (cache-friendly, issue #79).
for t in sorted(by_type.keys()):
    arr = sorted(by_type[t], key=lambda e: e.get('key', ''))
    print(f"## {t.capitalize()}s")
    for e in arr:
        files = f" (files: {', '.join(e.get('files', []))})" if e.get('files') else ""
        # Note: deliberately omit ts-derived date here. Including it would
        # make the summary non-stable across days and break prompt-cache
        # prefix matching (issue #79). Confidence/source are stable attrs.
        print(f"- [{e['key']}] (confidence: {e['_effective_confidence']}/10, {e.get('source', 'unknown')})")
        print(f"  {e.get('insight', '')}{files}")
    print()
PYTHON
}

# Throttle defaults (overridable via CLI flags appended after --summary/--all)
MAX_ENTRIES=0
MIN_CONFIDENCE=0
RECENT_WITHIN_DAYS=0

# Pre-scan args to capture throttle flags anywhere in argv
new_args=()
for a in "$@"; do
    case "$a" in
        --max-entries) shift_next=max_entries ;;
        --min-confidence) shift_next=min_confidence ;;
        --recent-within-days) shift_next=recent_within_days ;;
        --max-entries=*|-*max-entries=*) MAX_ENTRIES="${a#*=}"; shift_next="" ;;
        --min-confidence=*|-*min-confidence=*) MIN_CONFIDENCE="${a#*=}"; shift_next="" ;;
        --recent-within-days=*|-*recent-within-days=*) RECENT_WITHIN_DAYS="${a#*=}"; shift_next="" ;;
        *)
            if [ -n "${shift_next:-}" ]; then
                case "$shift_next" in
                    max_entries) MAX_ENTRIES="$a" ;;
                    min_confidence) MIN_CONFIDENCE="$a" ;;
                    recent_within_days) RECENT_WITHIN_DAYS="$a" ;;
                esac
                shift_next=""
            else
                new_args+=("$a")
            fi
            ;;
    esac
done
set -- "${new_args[@]}"

case "$1" in
    --summary)
        format_learnings "" "" "$MAX_ENTRIES" "$MIN_CONFIDENCE" "$RECENT_WITHIN_DAYS"
        ;;
    --all)
        echo "=== All Learnings ($total entries) ==="
        format_learnings "" "" "$MAX_ENTRIES" "$MIN_CONFIDENCE" "$RECENT_WITHIN_DAYS"
        ;;
    --recent)
        n="${2:-10}"
        echo "=== Recent $n Learnings ==="
        # For recent, just show last N lines formatted
        # NOTE: 之前用 `/tmp/agent_harness_recent_$$.jsonl`，set -e 下 format_learnings
        # 失败（如 JSON 损坏）时 rm 永不执行，临时文件泄漏。改用 mktemp + 全局 EXIT trap。
        tmp_recent=$(mktemp -t agent_harness_recent)
        _AGENT_HARNESS_TMP_CLEANUP="$tmp_recent"
        tail -"$n" "$LEARNINGS_FILE" > "$tmp_recent"
        LEARNINGS_FILE="$tmp_recent" format_learnings "" "" "$MAX_ENTRIES" "$MIN_CONFIDENCE" "$RECENT_WITHIN_DAYS"
        rm -f "$tmp_recent"
        _AGENT_HARNESS_TMP_CLEANUP=""
        ;;
    --type)
        if [ -z "${2:-}" ]; then
            echo "Error: --type requires a type argument" >&2
            echo "Valid types: pattern, pitfall, preference, architecture, tool, operational" >&2
            exit 1
        fi
        type="$2"
        echo "=== Learnings of type: $type ==="
        format_learnings "" "$type" "$MAX_ENTRIES" "$MIN_CONFIDENCE" "$RECENT_WITHIN_DAYS"
        ;;
    --help|-h)
        echo "Usage: $0 <keyword> | --type <type> | --recent [N] | --all | --summary"
        echo "       $0 --summary --max-entries 5 --min-confidence 7 --recent-within-days 30"
        echo ""
        echo "Options:"
        echo "  <keyword>                     Search by keyword (case-insensitive)"
        echo "  --type <type>                 Filter by type"
        echo "  --recent [N]                  Show recent N entries (default: 10)"
        echo "  --all                         Show all entries"
        echo "  --summary                     Formatted summary for session start"
        echo "  --max-entries N               (throttle) output top-N by confidence"
        echo "  --min-confidence N            (throttle) drop entries below N"
        echo "  --recent-within-days N        (throttle) drop entries older than N days"
        echo ""
        echo "Types: pattern, pitfall, preference, architecture, tool, operational"
        echo "Total learnings: $total"
        ;;
    *)
        # Keyword search
        keyword="$1"
        echo "=== Learnings matching '$keyword' ==="
        format_learnings "$keyword" "" "$MAX_ENTRIES" "$MIN_CONFIDENCE" "$RECENT_WITHIN_DAYS"
        ;;
esac
