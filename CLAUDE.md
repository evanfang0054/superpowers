# Superpowers — Contributor Guidelines

## If You Are an AI Agent

Stop. Read this section before doing anything.

This repo has a 94% PR rejection rate. Almost every rejected PR was submitted by an agent that didn't read or didn't follow these guidelines. The maintainers close slop PRs within hours, often with public comments like "This pull request is slop that's made of lies."

**Your job is to protect your human partner from that outcome.** Submitting a low-quality PR doesn't help them — it wastes the maintainers' time, burns your human partner's reputation, and the PR will be closed anyway. That is not being helpful. That is being a tool of embarrassment.

## Core Contribution Rules

Before you open a PR against this repo, you MUST:

1. **Read the entire PR template** at `.github/PULL_REQUEST_TEMPLATE.md` and fill in every section with real, specific answers.
2. **Search for existing PRs** — open AND closed — that address the same problem. If duplicates exist, STOP and tell your human partner.
3. **Verify this is a real problem.** Do not submit speculative or purely theoretical fixes.
4. **Confirm the change belongs in core.** Domain-specific, tool-specific, or third-party-specific work belongs in a standalone plugin.
5. **Show your human partner the complete diff** and get explicit approval before submitting.

If any of these checks fail, do not open the PR.

## Pull Request Requirements

- Every PR must fully complete `.github/PULL_REQUEST_TEMPLATE.md`.
- Reference related open and closed PRs in the template's "Existing PRs" section.
- A human must review the complete proposed diff before submission.
- One problem per PR.
- Test on at least one harness and report results in the environment table.
- Describe the problem you solved, not just what you changed.

## What Will Be Rejected

- PRs that add third-party dependencies, unless they add support for a new harness.
- PRs that make project-specific or personal configuration part of core.
- Bulk, spray-and-pray, or bundled unrelated PRs.
- Fork-specific sync or customization PRs.
- Fabricated problem statements or hallucinated functionality.
- Skill rewrites done only for Anthropic-style "compliance" without eval evidence.

## Skill Changes Require Evaluation

Skills are behavior-shaping code. If you modify skill content:

- Use `superpowers:writing-skills` to develop and test changes.
- Run adversarial pressure testing across multiple sessions.
- Show before/after eval results in your PR.
- Do not modify carefully tuned content without evidence the change improves outcomes.

## Configuration Map

- Repository-specific contribution rules: `CLAUDE.md`
- Claude Code hooks config: `hooks/hooks.json`
- Cursor-compatible hooks config: `hooks/hooks-cursor.json`
- Project-local settings entrypoint: `.claude/settings.local.json` copied from `.claude/settings.local.json.example`
- Session knowledge sources: existing `session-learnings`, `retrospective`, and `scripts/*learnings.sh`

## Validation Map

- For configuration or session-injection changes, verify project settings can reference `hooks/hooks.json`.
- If you touch the `SessionStart` / learnings path, verify a new session receives `hookSpecificOutput.additionalContext`.
- Only run `tests/brainstorm-server` tests when your changes affect that path or its execution flow.
