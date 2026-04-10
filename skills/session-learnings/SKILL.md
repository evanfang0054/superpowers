---
name: session-learnings
description: "Capture and reuse project-specific knowledge across sessions. Use when you discover a non-obvious pattern, pitfall, or architectural insight. Also automatically read learnings at session start to avoid repeating mistakes. PROACTIVELY invoke this skill after debugging sessions, when user corrects your approach, or when you discover undocumented project conventions."
---

# Session Learnings

## Overview

Knowledge discovered in one session shouldn't be lost. Learnings accumulate project-specific insights that help future sessions work more effectively.

**Core principle:** Capture knowledge when discovered, apply knowledge when relevant.

## When to Capture

**Log a learning when you discover:**
- A reusable pattern in this codebase
- A pitfall that wasted time (so you don't repeat it)
- A user preference (coding style, naming conventions, etc.)
- An architectural decision and its rationale
- A tool/library insight specific to this project
- Operational knowledge (CLI quirks, environment setup, workflow)

**Don't log:**
- General programming knowledge (not project-specific)
- Obvious things any developer would know
- Temporary fixes or workarounds

## Learning Types

| Type | Description | Example |
|------|-------------|---------|
| `pattern` | Reusable approach that works well | "API handlers follow decorator pattern in handlers/" |
| `pitfall` | What NOT to do | "Don't use sync file ops in event handlers - causes deadlock" |
| `preference` | User-stated preference | "User prefers explicit types over inference" |
| `architecture` | Structural decision | "All state lives in Redux, components are pure" |
| `tool` | Library/framework insight | "This project uses vitest not jest for testing" |
| `operational` | Environment/CLI/workflow | "Run `pnpm prepare` before tests or hooks won't work" |

## How to Record

### Storage Location

Learnings are stored in `.superpowers/learnings.jsonl` at the project root.

### Using the Script (Recommended)

```bash
# Basic usage
${CLAUDE_PLUGIN_ROOT}/scripts/log-learning.sh <type> <key> <insight> [confidence] [source] [files...]

# Examples
${CLAUDE_PLUGIN_ROOT}/scripts/log-learning.sh pattern "api_validation" "All API routes use zod for validation"
${CLAUDE_PLUGIN_ROOT}/scripts/log-learning.sh pitfall "async_middleware" "Don't use async DB calls in middleware" 9 error
${CLAUDE_PLUGIN_ROOT}/scripts/log-learning.sh preference "explicit_types" "User wants explicit return types" 10 user-stated
```

### Manual Record Format

```bash
# Create directory if needed
mkdir -p .superpowers

# Append learning
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","type":"TYPE","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":N,"source":"SOURCE","files":["path/to/relevant/file"]}' >> .superpowers/learnings.jsonl
```

### Field Definitions

| Field | Required | Description |
|-------|----------|-------------|
| `ts` | Yes | ISO timestamp when discovered |
| `type` | Yes | One of: pattern, pitfall, preference, architecture, tool, operational |
| `key` | Yes | Short identifier (2-4 words, snake_case) |
| `insight` | Yes | Clear description of what was learned |
| `confidence` | Yes | 1-10 scale (see below) |
| `source` | Yes | How you learned this |
| `files` | No | Related file paths |

### Confidence Levels

| Score | Meaning |
|-------|---------|
| 9-10 | Verified in code, tested, confirmed by user |
| 7-8 | Observed pattern, strong evidence |
| 5-6 | Inferred from context, reasonable confidence |
| 3-4 | Uncertain, needs verification |
| 1-2 | Guess, low confidence |

### Source Values

- `observed` - Found this directly in the code
- `user-stated` - User explicitly told you
- `inferred` - Deduced from behavior/context
- `error` - Discovered via an error or failure
- `docs` - Found in project documentation

## How to Use Learnings

### At Session Start

Learnings are automatically loaded via session-start hook. You'll see them in your context.

### During Work

Before making changes in an area, search for relevant learnings:

```bash
# Using the search script (recommended)
${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh <keyword>
${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh --type pitfall
${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh --recent 5

# Or manual grep
grep -i "keyword" .superpowers/learnings.jsonl 2>/dev/null
```

### Updating Learnings

If a learning becomes outdated or wrong:

```bash
# Mark as superseded by adding a new learning
echo '{"ts":"...","type":"pattern","key":"old_key_v2","insight":"Updated understanding: ...","confidence":8,"source":"observed","supersedes":"old_key"}' >> .superpowers/learnings.jsonl
```

Don't delete old learnings - add superseding entries so history is preserved.

## Examples

### Pattern Discovery

After noticing all API routes follow a pattern:
```json
{"ts":"2024-03-15T10:30:00Z","type":"pattern","key":"api_route_structure","insight":"All API routes in src/routes/ export a default handler and use zod for validation. Always import { z } from 'zod' and define schema before handler.","confidence":9,"source":"observed","files":["src/routes/users.ts","src/routes/posts.ts"]}
```

### Pitfall Capture

After debugging for an hour:
```json
{"ts":"2024-03-15T14:20:00Z","type":"pitfall","key":"async_db_in_middleware","insight":"Never use async database calls in Express middleware - causes request to hang. Use req.locals to pass data instead.","confidence":10,"source":"error","files":["src/middleware/auth.ts"]}
```

### User Preference

After user corrects your code style:
```json
{"ts":"2024-03-15T16:00:00Z","type":"preference","key":"explicit_return_types","insight":"User wants explicit return types on all exported functions, even when TypeScript could infer them.","confidence":10,"source":"user-stated"}
```

## Integration

**Works with:**
- **systematic-debugging** - Capture pitfalls discovered during debugging
- **brainstorming** - Recall architectural decisions when designing
- **writing-plans** - Apply learned patterns to new implementation plans

## Quick Reference

```bash
# Record
${CLAUDE_PLUGIN_ROOT}/scripts/log-learning.sh <type> <key> <insight> [confidence] [source]

# Search
${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh <keyword>
${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh --type pitfall
${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh --recent 5
${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh --all

# Manual
cat .superpowers/learnings.jsonl                    # Read all
grep -i "keyword" .superpowers/learnings.jsonl      # Search
```

## Red Flags

**Capture immediately when:**
- You just spent 30+ minutes debugging something
- User corrects your approach
- You find an undocumented project convention
- Something "just works" but the reason isn't obvious

**Don't capture:**
- General knowledge not specific to this project
- Temporary workarounds that will be removed
- Speculation without evidence
