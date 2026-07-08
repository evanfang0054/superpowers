---
name: harness-init
description: Use when initializing agent-harness in a new project or reconfiguring for a specific tech stack.
when_to_use: "[feedforward] Triggered at project setup to bootstrap harness configuration from templates."
user-invocable: true
disable-model-invocation: true
---

# Harness Init

## Overview

Bootstraps harness configuration from preset templates. Copies sensor configs and recommended skills list to `.agent-harness/`.

## Available Templates

| Template | Stack |
|---|---|
| `react-typescript` | React 18+ / TypeScript 5+ / Vite / Vitest / ESLint |
| `python-fastapi` | Python 3.11+ / FastAPI / pytest / ruff / mypy |
| `go-cli` | Go 1.21+ / golangci-lint / go test |

## Flow

1. List available templates
2. Ask user to select one (or detect from project files: `package.json` -> react-typescript, `requirements.txt`/`pyproject.toml` -> python-fastapi, `go.mod` -> go-cli)
3. Copy `templates/{selected}/sensors.json` -> `.agent-harness/sensors.json`
4. Copy `templates/{selected}/hooks-config.json` -> project hooks config (if not already configured)
5. Show recommended skills from `templates/{selected}/skills-recommended.md`
6. Prompt user to review and customize

## Auto-detection

Check for `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod` in project root to suggest the right template. Auto-detection is a hint, not a rule -- the user may override the suggestion.

## Post-setup

Remind user to customize `sensors.json` paths and thresholds for their specific project.

## Common Mistakes

| Mistake | Guidance |
|---|---|
| Copying without reviewing | Always review sensor commands match your project |
| Using wrong template | Auto-detection is a hint, not a rule. Pick what fits. |
| Skipping hooks-config | Hooks enable session-start learnings injection |
