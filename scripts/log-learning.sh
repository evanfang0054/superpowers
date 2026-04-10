#!/usr/bin/env bash
# log-learning.sh - Record a learning to the project's learnings file
#
# Usage:
#   log-learning.sh <type> <key> <insight> [confidence] [source] [files...]
#
# Types: pattern, pitfall, preference, architecture, tool, operational
# Sources: observed, user-stated, inferred, error, docs (default: observed)
# Confidence: 1-10 (default: 7)
#
# Examples:
#   log-learning.sh pattern "api_validation" "All API routes use zod for validation"
#   log-learning.sh pitfall "async_middleware" "Don't use async DB calls in middleware" 9 error
#   log-learning.sh preference "explicit_types" "User wants explicit return types" 10 user-stated

set -euo pipefail

# Validate arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <type> <key> <insight> [confidence] [source] [files...]" >&2
    echo "" >&2
    echo "Types: pattern, pitfall, preference, architecture, tool, operational" >&2
    echo "Sources: observed, user-stated, inferred, error, docs" >&2
    echo "Confidence: 1-10 (default: 7)" >&2
    exit 1
fi

TYPE="$1"
KEY="$2"
INSIGHT="$3"
CONFIDENCE="${4:-7}"
SOURCE="${5:-observed}"
shift 5 2>/dev/null || shift $#

# Validate type
case "$TYPE" in
    pattern|pitfall|preference|architecture|tool|operational) ;;
    *)
        echo "Error: Invalid type '$TYPE'" >&2
        echo "Valid types: pattern, pitfall, preference, architecture, tool, operational" >&2
        exit 1
        ;;
esac

# Validate source
case "$SOURCE" in
    observed|user-stated|inferred|error|docs) ;;
    *)
        echo "Error: Invalid source '$SOURCE'" >&2
        echo "Valid sources: observed, user-stated, inferred, error, docs" >&2
        exit 1
        ;;
esac

# Validate confidence
if ! [[ "$CONFIDENCE" =~ ^[0-9]+$ ]] || [ "$CONFIDENCE" -lt 1 ] || [ "$CONFIDENCE" -gt 10 ]; then
    echo "Error: Confidence must be a number between 1 and 10" >&2
    exit 1
fi

# Create directory if needed
mkdir -p .superpowers

# Generate timestamp
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build JSON using python3 (more portable than jq)
FILES_ARGS=""
if [ $# -gt 0 ]; then
    FILES_ARGS=$(printf '%s\n' "$@" | python3 -c "import sys, json; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))")
else
    FILES_ARGS="[]"
fi

python3 << PYTHON >> .superpowers/learnings.jsonl
import json
entry = {
    "ts": "$TS",
    "type": "$TYPE",
    "key": "$KEY",
    "insight": """$INSIGHT""",
    "confidence": $CONFIDENCE,
    "source": "$SOURCE",
    "files": $FILES_ARGS
}
print(json.dumps(entry, ensure_ascii=False))
PYTHON

echo "Learning recorded: $KEY ($TYPE, confidence: $CONFIDENCE)"
