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

## Domain Glossary Setup

After configuring sensors and hooks, set up the domain glossary. **This step is idempotent** — safe to re-run on existing projects (only creates what's missing, never overwrites).

1. **Check & create CONTEXT.md:**
   - If `CONTEXT.md` already exists at project root: skip (don't overwrite user's glossary)
   - If missing: ask user "Create a domain glossary (CONTEXT.md)? (y/n)"
     - If `y`: create `CONTEXT.md` at project root with scaffold:
       ```markdown
       # <Project> Domain Glossary

       <!-- Domain terms go here.
            Use /domain-modeling to maintain this file.
            Glossary only — no implementation details. -->
       ```
2. **Check & create ADR directory:**
   - If `docs/agent-harness/adr/` already exists: skip
   - If missing and `docs/agent-harness/` exists: create `docs/agent-harness/adr/.gitkeep`
3. **Ask about gitignore** (only if CONTEXT.md was just created):
   - "Add CONTEXT.md to .gitignore? (y/n)"
   - If `y`: append `CONTEXT.md` to `.gitignore` (some projects don't commit domain vocabulary — proprietary terminology)
   - If `n`: CONTEXT.md will be tracked by git (default for shared glossaries)

**For existing projects that never ran harness-init with this step:** simply re-run `/harness-init`. The idempotent check ensures only missing files are created — existing configs, sensors, and hooks are not touched. Alternatively, run `/domain-modeling` directly — it will create `CONTEXT.md` lazily on first term crystallization.

The `domain-modeling` skill maintains CONTEXT.md during design work. See `skills/domain-modeling/SKILL.md` for the glossary format and ADR creation criteria.

## Auto-detection

Check for `package.json`, `requirements.txt`/`pyproject.toml`, `go.mod` in project root to suggest the right template. Auto-detection is a hint, not a rule -- the user may override the suggestion.

## Post-setup

Remind user to customize `sensors.json` paths and thresholds for their specific project.

## Common Mistakes

| Mistake | Guidance |
|---|---|
| Copying without reviewing | Always review sensor commands match your project |
| Using wrong template | Auto-detection is a hint, not a rule. Pick what fits. |
| Skipping hooks-config | Hooks enable session-start context injection |
