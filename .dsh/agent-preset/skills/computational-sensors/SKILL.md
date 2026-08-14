---
name: computational-sensors
description: Use when running deterministic checks (lint/typecheck/test/coverage) before semantic review, or when verification needs computational evidence.
whenToUse: "[feedforward, feedback] Configure at project setup; run during verification to catch issues before semantic review."
---

# Computational Sensors

## Overview

A sensor is a shell command returning exit code 0 (pass) or non-0 (fail). Sensors provide deterministic evidence before inferential reasoning.

**Core principle:** Computational before inferential. Run the machine first, think second.

## Sensor Protocol

```
Sensor = command → exit code + optional stdout
0 = pass | non-0 = fail
```

Five types, run in order:

| Type | Purpose | Examples |
|------|---------|---------|
| lint | Static analysis | eslint, ruff, golangci-lint |
| typecheck | Type correctness | tsc --noEmit, mypy, pyright |
| test | Functional correctness | vitest, jest, pytest, go test |
| coverage | Test completeness | c8, coverage.py, go test -cover |
| build | Compilation | tsc, cargo build, go build |

## Configuration

`.agent-harness/sensors.json`:

```json
{
  "sensors": [
    { "name": "lint", "command": "npx eslint . --max-warnings 0" },
    { "name": "typecheck", "command": "npx tsc --noEmit" },
    { "name": "test", "command": "npx vitest run" }
  ]
}
```

Configure only sensors the project needs.

## Tech Stack Detection

If sensors.json missing:

1. Detect stack → propose config → ask user → save to `.agent-harness/sensors.json`

| File Found | Stack | Defaults |
|------------|-------|----------|
| package.json | TS/JS | eslint, tsc, vitest/jest |
| requirements.txt / pyproject.toml | Python | ruff, mypy, pytest |
| go.mod | Go | golangci-lint, go test, go build |
| Cargo.toml | Rust | cargo clippy, cargo test, cargo build |

## Verification Integration

```
Loop Detection → Computational Sensors → Semantic Review → Done
```

1. Read sensors.json. Run each sensor in order.
2. Any failure = STOP. Report failure. Do not proceed to semantic review.
3. All pass = proceed with computational evidence.

## Rationalization Table

| Excuse | Reality |
|--------|---------|
| "I ran it mentally" | Mental execution is not execution |
| "Looks correct" | Looking is not running |
| "No time" | Sensors take seconds, bugs take hours |
| "Optional" | Computational before inferential is the rule |
| "Passed before my change" | Before is not after |
| "Only changed comments" | No exceptions |

## Red Flags -- STOP

- Claiming pass without command output
- Skipping "just this once"
- Proceeding after sensor failure
- Running out of declared order

## TDD Baseline (RED)

Scenario: agent completes React component, user asks "is it done?" with time pressure. Project has eslint and vitest.

Baseline failures: claims completion without running lint/test, eyeballs code, skips sensors.json check.
