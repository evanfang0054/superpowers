#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MARKETPLACE="$REPO_ROOT/.agents/plugins/marketplace.json"

python3 - "$MARKETPLACE" "$REPO_ROOT" <<'PY'
import json
import sys
from pathlib import Path

marketplace_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2])

if not marketplace_path.exists():
    raise AssertionError(".agents/plugins/marketplace.json must exist")

marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))

def assert_equal(actual, expected, label):
    if actual != expected:
        raise AssertionError(f"{label}: expected {expected!r}, got {actual!r}")

assert_equal(marketplace.get("name"), "agent-harness-dev", "marketplace name")
assert_equal(
    marketplace.get("interface", {}).get("displayName"),
    "Superpowers Dev",
    "marketplace display name",
)

plugins = marketplace.get("plugins")
if not isinstance(plugins, list):
    raise AssertionError("plugins must be a list")

matching_plugins = [plugin for plugin in plugins if plugin.get("name") == "agent-harness"]
assert_equal(len(matching_plugins), 1, "agent-harness plugin entry count")

plugin = matching_plugins[0]
assert_equal(plugin.get("source"), {"source": "url", "url": "./"}, "plugin source")
assert_equal(
    plugin.get("policy"),
    {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
    "plugin policy",
)
assert_equal(plugin.get("category"), "Developer Tools", "plugin category")

plugin_manifest = repo_root / ".codex-plugin" / "plugin.json"
if not plugin_manifest.exists():
    raise AssertionError(".codex-plugin/plugin.json must exist")

manifest = json.loads(plugin_manifest.read_text(encoding="utf-8"))
assert_equal(manifest.get("name"), plugin.get("name"), "plugin manifest name")

hooks_value = manifest.get("hooks")
assert isinstance(hooks_value, str), f"Codex manifest hooks must be a string path, got {type(hooks_value).__name__}"

# The manifest hooks field points to an explicit hooks config file.
# Codex auto-discovers a plugin's hooks/hooks.json whenever the Codex manifest
# has no `hooks` field: load_plugin_hooks falls back to a hardcoded
# DEFAULT_HOOKS_CONFIG_FILE = "hooks/hooks.json" and registers it. That file is
# the Claude Code SessionStart hook, it is tracked in this repo, and this
# marketplace installs the whole repo root (source url "./"), so on Codex the
# fallback re-registers the SessionStart hook and its install-time trust prompt.
# An explicit string path overrides the fallback so Codex reads the designated
# hooks file instead. An empty inline object ({}) would suppress auto-discovery
# entirely; a string path must point to a valid existing file.
hooks_path = repo_root / hooks_value.lstrip("./")
assert hooks_path.exists(), f"hooks path must exist: {hooks_value} (resolved: {hooks_path})"
assert hooks_path.suffix == ".json", f"hooks path must be a JSON file: {hooks_value}"

# Verify the hooks file is valid JSON with SessionStart hook
hooks_content = json.loads(hooks_path.read_text(encoding="utf-8"))
session_start = hooks_content.get("hooks", {}).get("SessionStart")
assert session_start, "hooks file must declare SessionStart hook(s)"
assert isinstance(session_start, list), "hooks file SessionStart must be a list"
assert len(session_start) > 0, "hooks file SessionStart must not be empty"

print(f"Codex manifest hooks OK: points to existing file {hooks_value} with SessionStart hook(s)")

print("Codex marketplace manifest looks good")
PY
