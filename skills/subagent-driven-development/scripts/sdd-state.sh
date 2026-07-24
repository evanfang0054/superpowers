#!/usr/bin/env bash
# sdd-state.sh -- SDD Fan-Out state read/write library
# Usage: source sdd-state.sh
#
# Depends on SDD_SESSION_DIR (set by session-init.sh)

# Guard against direct execution: return only works in sourced context
(return 2>/dev/null) || {
  echo "error: sdd-state.sh is a library to be sourced, not executed directly" >&2
  echo "usage: source sdd-state.sh" >&2
  exit 1
}

# Guard against missing SDD_SESSION_DIR
: "${SDD_SESSION_DIR:?SDD_SESSION_DIR not set}"

# sdd_state_get <jq_path> -- read a value from state.json
sdd_state_get() {
  local path="$1"
  jq -r "$path" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_set <jq_path> <value_json> -- write a JSON value to state.json
sdd_state_set() {
  local path="$1" value="$2"
  local tmp="$SDD_SESSION_DIR/state.json.tmp"
  jq "$path = $value" "$SDD_SESSION_DIR/state.json" > "$tmp" && mv "$tmp" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_set_str <jq_path> <raw_string> -- safe string write (auto-jq-escape)
sdd_state_set_str() {
  local path="$1" raw="$2"
  local tmp="$SDD_SESSION_DIR/state.json.tmp"
  jq --arg v "$raw" "$path = \$v" "$SDD_SESSION_DIR/state.json" > "$tmp" && mv "$tmp" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_add_node <task-key> <json-object> -- add a node to state.nodes
sdd_state_add_node() {
  local key="$1" value="$2"
  local tmp="$SDD_SESSION_DIR/state.json.tmp"
  jq ".nodes[\"$key\"] = $value" "$SDD_SESSION_DIR/state.json" > "$tmp" && mv "$tmp" "$SDD_SESSION_DIR/state.json"
}

# sdd_state_exists -- check if state.json exists and has a session_id field
sdd_state_exists() {
  [ -f "$SDD_SESSION_DIR/state.json" ] && jq -e '.session_id' "$SDD_SESSION_DIR/state.json" >/dev/null 2>&1
}
