#!/usr/bin/env bash
# session-init.sh -- SDD Fan-Out session initialization
# Creates session ID, session directory, initial state.json
#
# Usage: session-init.sh <orchestrator-branch> <plan-file>
# Output: echo session directory path
# Env: exports SDD_SESSION_ID, SDD_SESSION_DIR

set -euo pipefail

if [ $# -lt 2 ] || [ "$1" = "--help" ]; then
  echo "usage: session-init.sh <orchestrator-branch> <plan-file>" >&2
  exit 1
fi

ORCH_BRANCH="$1"
PLAN_FILE="$2"

# plan file must exist and be readable
if [ ! -f "$PLAN_FILE" ]; then
  echo "error: plan file not found: $PLAN_FILE" >&2
  exit 1
fi

SESSION_ID=$(openssl rand -hex 4 2>/dev/null || echo "$(date +%s | shasum | head -c8)")
export SDD_SESSION_ID="$SESSION_ID"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
SESSION_DIR="$REPO_ROOT/.agent-harness/sdd/$SESSION_ID"
mkdir -p "$SESSION_DIR"

export SDD_SESSION_DIR="$SESSION_DIR"

# Parse tasks from plan: extract ### Task N: headings and
# Blocking / Files field values
parse_tasks_from_plan() {
  local plan="$1"
  local in_task=0
  local current_task=""
  local task_count=0

  while IFS= read -r line; do
    if echo "$line" | grep -qE '^### Task [0-9]+:'; then
      [ -n "$current_task" ] && echo "$current_task"
      task_count=$((task_count + 1))
      current_task=$(echo "$line" | sed -E 's/^### (Task [0-9]+):.*/\1/')
    elif echo "$line" | grep -qE '^Blocking: '; then
      current_task="$current_task|blocking:$(echo "$line" | sed 's/^Blocking: //')"
    elif echo "$line" | grep -qE '^[Ff]iles: '; then
      current_task="$current_task|files:$(echo "$line" | sed 's/^[Ff]iles: //')"
    fi
  done < "$plan"
  [ -n "$current_task" ] && echo "$current_task"
}

# Write initial state.json
cat > "$SESSION_DIR/state.json" << STATEEOF
{
  "session_id": "$SESSION_ID",
  "orchestrator_branch": "$ORCH_BRANCH",
  "concurrency_limit": 3,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_dir": "$SESSION_DIR",
  "plan_file": "$PLAN_FILE",
  "nodes": {},
  "phases": {
    "dispatch": "pending",
    "merge": "pending",
    "integration": "pending"
  }
}
STATEEOF

# Parse tasks from plan and populate state.json nodes
while IFS= read -r task_line; do
  task_key=$(echo "$task_line" | cut -d'|' -f1 | tr ' ' '_')
  node_json='{"status": "pending"'

  if echo "$task_line" | grep -q '|blocking:'; then
    blocking_val=$(echo "$task_line" | sed 's/.*|blocking:\([^|]*\).*/\1/' | xargs)
    node_json="$node_json, \"blocking\": \"$blocking_val\""
  fi
  if echo "$task_line" | grep -q '|files:'; then
    files_val=$(echo "$task_line" | sed 's/.*|files:\([^|]*\).*/\1/' | xargs)
    node_json="$node_json, \"files\": \"$files_val\""
  fi
  node_json="$node_json}"

  jq --arg key "$task_key" --argjson val "$node_json" \
    '.nodes[$key] = $val' "$SESSION_DIR/state.json" > "$SESSION_DIR/state.json.tmp" \
    && mv "$SESSION_DIR/state.json.tmp" "$SESSION_DIR/state.json"
done < <(parse_tasks_from_plan "$PLAN_FILE")

echo "$SESSION_DIR"
