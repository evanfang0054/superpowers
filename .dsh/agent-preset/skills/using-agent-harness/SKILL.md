---
name: using-agent-harness
description: Use when starting any conversation — establishes skill discovery and requires Skill tool invocation before ANY response.
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill applies means invoke it to check.

## Instruction Priority

1. **User's explicit instructions** (CLAUDE.md, AGENTS.md, direct requests) — highest priority
2. **Agent Harness skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

## How to Access Skills

- **Claude Code:** Use the `Skill` tool. Never Read skill files directly.
- **DeepSeek Harness:** Use the `skill` tool (auto-discovered from the installed preset or `~/.dsh/skills`).

Codex: subagent setup, environment detection, and App finishing notes in `references/codex-tools.md`.

## Skill Selection

When multiple skills could apply, use this order:
1. **Process skills first** (brainstorming, debugging) — they determine HOW to approach the task.
2. **Implementation skills second** (design, mcp-builder) — they guide execution.

"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → debugging first, then domain-specific skills.

## Skill Types

- **Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.
- **Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

## Anti-Rationalization

These thoughts mean STOP — you're rationalizing:

- "This is just a simple question" → Questions are tasks. Check for skills.
- "I need more context first" → Skill check comes BEFORE clarifying questions.
- "Let me explore the codebase first" → Skills tell you HOW to explore. Check first.
- "This doesn't need a formal skill" → If a skill exists, use it.
- "I remember this skill" → Skills evolve. Read current version.

User instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
