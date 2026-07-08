# Agent Harness

[中文文档](README.md)

Agent Harness is a complete software development workflow for your coding agents, built on top of a set of composable "skills" and some initial instructions that make sure your agent uses them.

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it steps back and asks you what you're really trying to do. 

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read and digest. 

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI (You Aren't Gonna Need It), and DRY. 

Next up, once you say "go", it launches a *subagent-driven-development* process, having agents work through each engineering task, inspecting and reviewing their work, and continuing forward. It's not uncommon for Claude to be able to work autonomously for a couple hours at a time without deviating from the plan you put together.

There's a bunch more to it, but that's the core of the system. And because the skills trigger automatically, you don't need to do anything special. Your coding agent just has Agent Harness.


## Installation

**Note:** Installation differs by platform. Claude Code or Cursor have built-in plugin marketplaces. Codex and OpenCode require manual setup.

### Claude Code Official Marketplace

Agent Harness is available via the [official Claude plugin marketplace](https://claude.com/plugins/agent-harness)

Install the plugin from Claude marketplace:

```bash
/plugin install agent-harness@claude-plugins-official
```

### Claude Code (via Plugin Marketplace)

In Claude Code, register the marketplace first:

```bash
/plugin marketplace add evanfang0054/agent-harness-marketplace
```

Then install the plugin from this marketplace:

```bash
/plugin install agent-harness@agent-harness-marketplace
```

### Cursor (via Plugin Marketplace)

In Cursor Agent chat, install from marketplace:

```text
/add-plugin agent-harness
```

or search for "agent-harness" in the plugin marketplace.

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/evanfang0054/agent-harness/refs/heads/main/.codex/INSTALL.md
```

**Detailed docs:** [docs/README.codex.md](docs/README.codex.md)

### OpenCode

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/evanfang0054/agent-harness/refs/heads/main/.opencode/INSTALL.md
```

**Detailed docs:** [docs/README.opencode.md](docs/README.opencode.md)

### GitHub Copilot CLI

```bash
copilot plugin marketplace add evanfang0054/agent-harness-marketplace
copilot plugin install agent-harness@agent-harness-marketplace
```

### Gemini CLI

```bash
gemini extensions install https://github.com/evanfang0054/agent-harness
```

To update:

```bash
gemini extensions update agent-harness
```

### Verify Installation

Start a new session in your chosen platform and ask for something that should trigger a skill (for example, "help me plan this feature" or "let's debug this issue"). The agent should automatically invoke the relevant agent-harness skill.

## Workflow Overview

Agent Harness uses a layered architecture: **Decision Layer** ensures "doing the right thing", **Execution Layer** ensures "doing things right", **Quality Layer** ensures "doing things well".

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Decision Layer                                     │
│                    "Should we build? What direction?"                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐      ┌─────────────────┐      ┌─────────────────┐        │
│   │office-hours │ ───► │ plan-ceo-review │ ───► │ plan-eng-review │        │
│   │"Worth it?"  │      │  "10-star?"     │      │  "Feasible?"    │        │
│   └─────────────┘      └─────────────────┘      └─────────────────┘        │
│         │                                              │                    │
│         │ 🟢 Go                                        │ ✅ Locked          │
│         ▼                                              ▼                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Execution Layer                                    │
│                      "How to design? How to build?"                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐  ┌────────────────┐  ┌─────────────┐  ┌───────────────┐  │
│   │brainstorming│─►│gate-driven-    │─►│writing-plans│─►│subagent-dev / │  │
│   │  "Design?"  │  │ test-design *  │  │ "Break tasks"│  │ exec-plans    │  │
│   └─────────────┘  └────────────────┘  └─────────────┘  └───────────────┘  │
│                     * optional: recursively derive                         │
│                       test pyramid                                        │
│                                                         │                   │
│   ┌─────────────────────────────────────────────────────┼───────────────┐  │
│   │                  Implementation Loop                 ▼               │  │
│   │  ┌─────┐  ┌───────────┐  ┌─────────────┐  ┌──────┐  ┌─────────┐   │  │
│   │  │ TDD │─►│comp-sensor│─►│code-review  │─►│verify│─►│finishing│   │  │
│   │  └─────┘  └───────────┘  └─────────────┘  └──────┘  └─────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ harness-init (bootstrap) · harness-design (prototype) · harness-opt│  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Quality Layer                                     │
│                          "Is it good enough?"                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐      ┌─────────────────────┐      ┌─────────────────┐    │
│   │ qa-testing  │ ───► │ post-deploy-monitor │ ───► │  retrospective  │    │
│   │ "Find/fix"  │      │   "Monitor deploy"  │      │   "Improve"     │    │
│   └─────────────┘      └─────────────────────┘      └─────────────────┘    │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ trace-analysis (cross-session failure pattern analysis)              │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Core philosophy:** Decision layer guards the "front door" (ensure right direction), Execution layer runs the "workshop" (ensure disciplined implementation), Quality layer guards the "back door" (ensure delivery quality). `sprint-contract` ensures clear Definition of Done between design and planning, `computational-sensors` runs deterministic checks before code review, `trace-analysis` surfaces recurring failure patterns from historical data.

## The Basic Workflow

1. **brainstorming** - Activates before writing code. Refines rough ideas through questions, explores alternatives, presents design in sections for validation. Saves design document.

2. **sprint-contract** - Activates after design approval, before writing plans. Negotiates explicit Definition of Done to prevent ambiguous completion criteria.

3. **writing-plans** - Activates with sprint contract confirmed. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, verification steps.

4. **subagent-driven-development** or **executing-plans** - Activates with plan. Both driven by ralph-loop to ensure completion. subagent-driven-development acts as orchestrator dispatching subagents (implementer → spec review → quality review), executing-plans runs directly in main session. Both support user-defined additional rules. SDD adopts the v6.0 unified review mechanism: a single `task-reviewer` returns a double verdict (spec compliance + code quality) in one pass, backed by `scripts/task-brief` and `scripts/review-package` which write task text and diff to files, avoiding controller context pollution.

5. **test-driven-development** - Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests.

6. **computational-sensors** - Activates before code review. Runs lint, typecheck, test, coverage and other deterministic checks to provide computational evidence for semantic review.

7. **requesting-code-review** - Activates between tasks. Reviews against plan, reports issues by severity. Critical issues block progress.

8. **finishing-a-development-branch** - Activates when tasks complete. Verifies tests, presents options (merge/PR/keep/discard).

**The agent checks for relevant skills before any task.** Mandatory workflows, not suggestions.

## Auto-Loop: Autonomous Self-Improvement Loop

`scripts/auto-loop.sh` is a standalone automation tool — it does not rely on automatic skill triggering and must be invoked manually. It fully automates the chain: "discover problems from sessions → file issues → SDD fix → create PR".

### Quick Start

```bash
# Analyze today's sessions for the current project, find issues, fix, create PR
./scripts/auto-loop.sh "Analyze today's sessions, find and fix issues"

# Scan a specific project
./scripts/auto-loop.sh --project ~/code/my-app "Analyze this week's sessions"

# Scan all projects (~/.claude/projects/)
./scripts/auto-loop.sh --all-projects "Find recent issues across all projects"

# Filter sessions by natural language condition
./scripts/auto-loop.sh --filter "sessions that invoked superpower skills" "Only inventory relevant sessions"

# Analyze + file issues only, no fixes (dry-run)
./scripts/auto-loop.sh --dry-run "Analyze today's sessions"

# Skip analysis, directly fix specified issues (fix-only)
./scripts/auto-loop.sh --fix-only "#12,#15"

# Pull all open issues and fix (up to 10)
./scripts/auto-loop.sh --fix-only "all" --max-issues 10

# Resume an interrupted run
./scripts/auto-loop.sh --resume

# Clean up state and worktrees
./scripts/auto-loop.sh --cleanup
```

### How It Works

```
You provide a natural language request
    ↓
[1] Create a git worktree (isolated workspace, never touches your CWD)
    ↓
[2] Call claude-code-log to export filtered session content
    ↓
[3] Claude analyzes sessions, identifies problem patterns
    ↓
[4] File issues to evanfang0054/agent-harness
    ↓
[5] Fix each issue via SDD (brainstorming → writing-plans → implement)
    ↓
[6] Verify → push → create PR (with closes #N references)
    ↓
Clean up worktree, output PR link, wait for your review
```

### Features

- **Git worktree isolation** — All fixes happen in an isolated worktree; your current workspace stays untouched
- **Checkpoint recovery** — Any interruption (crash/sleep/Ctrl+C) can be resumed with `--resume`
- **Three-layer observability** — Real-time event stream + heartbeat detection + full log file, never silent
- **Intervention protocol** — Automatically stops on 4 trigger conditions (irreversible risk/conflict/low confidence/architectural change)
- **Conservative decisions** — AI picks the smallest, lowest-risk option at every decision point
- **Self-protection** — PreToolUse hook (`guard-auto-loop.sh`) blocks Claude from deleting its own runtime state, preventing self-destruction

### Proven in Production

In real-world testing on this project itself, auto-loop has autonomously discovered and fixed 30+ shell script bugs (covering Python source injection, signal-path resource leaks, set -u boundary issues, frontmatter boundary corruption, and more). Each bug was identified by Claude → filed as an issue → fixed via SDD → pushed → wrapped in a PR. Average run takes 15-40 minutes and produces a ready-to-review PR.

See the [design spec](docs/agent-harness/specs/2026-06-24-auto-loop-self-improvement-design.md) for details.

## Harness Engineering: Observable, Verifiable, Self-Healing Engineering Layer

Agent Harness is more than a collection of skills — it builds an engineering environment around the model so AI can work in your engineering system in a way that is **executable, constrained, verifiable, and feedback-driven**. This layer is what the industry calls Harness Engineering — not teaching the model "how to answer", but designing "how it works" (`Agent = Model + Harness`).

Around the three-layer workflow, agent-harness provides four interlocking subsystems:

| Subsystem | Problem it solves | Key artifacts |
|---|---|---|
| **Observability** | Turn "is this harness any good, how expensive, where does it keep failing" from feelings into data | `.agent-harness/phase-metrics.jsonl` (token / duration / failure-rate persistence) + `log-phase-metric.sh` / `query-phase-metrics.sh`; 7 core skills actively emit at phase boundaries |
| **Protocol Contracts** | Upgrade skill-to-skill handoff from "natural-language soft review" to "machine-verifiable schema precondition" | YAML frontmatter at spec / plan / task handoff points + `validate-handoff.sh` hard precondition; runs in parallel with existing reviewer subagents, does not replace them |
| **Knowledge Base / Context** | Shift context injection from "the more the better" to "only what each step needs to see" | Top-level `index.md` + per-subdir secondary indexes + `glossary.md` (SSOT); SessionStart adds only a one-line pointer, no token bloat |
| **Failure Self-Healing** | Upgrade failure handling from "alert + manual intervention" to "diagnosis report → executable fix task" closed loop | `diagnose-failure.sh` converges loop / gate / test failure signals into structured JSON + `write-diagnosis-task.sh` writes it back as a task; never auto-executes, the loop can be interrupted by humans at any point |

**How the four subsystems interlock:**

- The protocol layer's `gate_result` is driven by `validate-handoff.sh` and emitted to phase-metrics
- The protocol layer's `spec_topic` must be present in the knowledge base's `index.md`, otherwise the hard precondition rejects it
- Failure self-healing reuses phase-metrics and the knowledge base's learnings index as signal sources to match similar historical failures

Design spec: `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md`. Four implementation plans: `docs/agent-harness/plans/2026-06-29-*.md`.

## What's Inside

### Skills Library

**Testing**
- **test-driven-development** - RED-GREEN-REFACTOR cycle (includes testing anti-patterns reference)

**Debugging**
- **systematic-debugging** - 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)
- **verification-before-completion** - Ensure it's actually fixed
- **loop-detection** - Detect when an agent is stuck editing the same file repeatedly without converging

**Decision Layer** (inspired by gstack)
- **office-hours** - YC office hours mode, answers "should we build this?", six forcing questions
- **plan-ceo-review** - CEO-level strategic review, 10-star thinking, challenge premises
- **plan-eng-review** - Eng manager architecture review, lock in technical approach

**Collaboration**
- **brainstorming** - Socratic design refinement
- **gate-driven-test-design** - Between brainstorming and writing-plans, recursively derive a risk-based test coverage tree (Level Items + Gates + Assertions) from the design spec; the tree structure naturally forms a test pyramid
- **writing-plans** - Detailed implementation plans
- **sprint-contract** - Negotiate explicit Definition of Done between brainstorming and writing-plans
- **executing-plans** - Ralph-loop driven execution, enforces TDD/Review/finishing workflow, supports custom rules
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Pre-review checklist
- **receiving-code-review** - Responding to feedback
- **finishing-a-development-branch** - Merge/PR decision workflow
- **subagent-driven-development** - Ralph-loop driven orchestrator mode, dispatches subagents + v6.0 unified review (single reviewer, double verdict, backed by `task-brief` / `review-package` scripts)
- **computational-sensors** - Run deterministic checks (lint/typecheck/test/coverage) before semantic review

**Quality Assurance**
- **qa-testing** - Systematically QA test web apps, auto-fix bugs with atomic commits
- **trace-analysis** - Cross-session failure pattern analysis based on historical learnings data

**Automation**
- **generate-issues** - Analyze Claude Code sessions and generate GitHub issues (wraps auto-loop --dry-run)
- **fix-issues-and-pr** - Pull existing issues and fix with SDD workflow, one PR for all (wraps auto-loop --fix-only)

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-agent-harness** - Introduction to the skills system

**Harness Tools**
- **harness-init** - Bootstrap harness configuration from templates for React, Python, Go, etc.
- **harness-design** - HTML hi-fi prototyping, interactive demos, and design exploration
- **harness-optimizer** - Optimize project workflow, skills, or harness based on session analysis

## Philosophy

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success



## Contributing

Skills live directly in this repository. To contribute:

1. Fork the repository
2. Create a branch for your skill
3. Follow the `writing-skills` skill for creating and testing new skills
4. Submit a PR

See `skills/writing-skills/SKILL.md` for the complete guide.

## Updating

Skills update automatically when you update the plugin:

```bash
/plugin update agent-harness
```

## License

MIT License - see LICENSE file for details

## Support

- **Issues**: https://github.com/evanfang0054/agent-harness/issues

## Acknowledgements

This project is based on [Superpowers](https://github.com/obra/superpowers) by [Jesse Vincent](https://github.com/obra). Thanks to the original author for creating such an excellent project.
