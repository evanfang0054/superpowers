---
name: retrospective
description: "Engineering retrospective for analyzing recent work. Use when asked to 'do a retro', 'review the week', 'what did we accomplish', or at the end of a sprint/milestone. Analyzes commits, learnings, and patterns to improve future work."
---

# Retrospective

## Overview

Regular retrospectives help teams improve continuously. This skill guides a structured review of recent engineering work to identify what went well, what didn't, and what to improve.

**Core principle:** Reflection without action is wasted time. Every retro ends with concrete improvements.

**Announce at start:** "I'm using the retrospective skill to analyze our recent work."

## When to Use

**Invoke this skill:**
- End of sprint/iteration
- End of week
- After shipping a major feature
- When asked "what did we accomplish" or "let's do a retro"
- After a significant incident or debugging session

## The Process

### Step 1: Define the Time Period

```
What period should we review?
- Last week
- Last sprint (2 weeks)
- Since last retro
- Since <specific date>
- This feature/project
```

### Step 2: Gather Data

**Commits:**
```bash
# Get commit summary for the period
git log --oneline --since="1 week ago" --author="$(git config user.email)"

# Get stats
git log --stat --since="1 week ago" --author="$(git config user.email)" | tail -20
```

**Learnings (if using session-learnings):**
```bash
# Check for captured learnings
cat .superpowers/learnings.jsonl 2>/dev/null | tail -20
```

**Files changed:**
```bash
git diff --stat HEAD~50 --name-only | sort | uniq -c | sort -rn | head -20
```

### Step 3: Structured Review

Present findings in this format:

#### What We Shipped
```
Features/Changes:
- [ ] Feature A — brief description
- [ ] Feature B — brief description
- [ ] Bug fix C — brief description

Commits: N
Lines changed: +X / -Y
Files touched: Z
```

#### What Went Well
```
+ Pattern/practice that worked
+ Tool/approach that saved time
+ Decision that paid off
```

#### What Didn't Go Well
```
- Problem encountered
- Time sink or blocker
- Mistake made
```

#### Learnings Captured
```
(From .superpowers/learnings.jsonl)
- key: insight
- key: insight
```

### Step 4: Identify Patterns

Look for recurring themes:

| Pattern | Frequency | Impact |
|---------|-----------|--------|
| Testing saved time | 3 times | High |
| Unclear requirements caused rework | 2 times | Medium |
| Manual deployment was slow | 4 times | Medium |

### Step 5: Action Items

**Every retro must produce at least one concrete action item:**

```
Action Items:
1. [ ] <specific action> — Owner: <who> — Due: <when>
2. [ ] <specific action> — Owner: <who> — Due: <when>

Examples of good action items:
- "Add pre-commit hook for linting" (not "improve code quality")
- "Create template for feature specs" (not "write better specs")
- "Set up CI for the analytics module" (not "more testing")
```

### Step 6: Save the Retro

Write the retrospective to a file:

```bash
mkdir -p docs/retros
```

Save to `docs/retros/YYYY-MM-DD-retro.md`:

```markdown
# Retrospective: YYYY-MM-DD

## Period
<start> to <end>

## What We Shipped
- ...

## What Went Well
- ...

## What Didn't Go Well
- ...

## Learnings
- ...

## Action Items
- [ ] ...

## Metrics
- Commits: N
- Lines: +X/-Y
- Features: N
```

Commit the retro:
```bash
git add docs/retros/YYYY-MM-DD-retro.md
git commit -m "docs(retro): add retrospective for YYYY-MM-DD"
```

## Quick Templates

### Mini Retro (5 min)
```
Since last time:
- Shipped: <list>
- Blocked by: <list>
- Next: <list>
- One thing to improve: <action>
```

### Full Retro (30 min)
Use the complete process above.

### Incident Retro
```
Incident: <description>
Timeline:
- <time>: <event>
- <time>: <event>

Root cause: <analysis>
What we'll change: <actions>
```

## Metrics to Track Over Time

If you do retros regularly, track these trends:

| Metric | This Period | Last Period | Trend |
|--------|-------------|-------------|-------|
| Commits | N | N | ↑↓→ |
| Features shipped | N | N | ↑↓→ |
| Bugs fixed | N | N | ↑↓→ |
| Rework items | N | N | ↑↓→ |
| Action items completed | N/M | N/M | ↑↓→ |

## Red Flags

**Signs of unhealthy patterns:**
- Same problems appearing in multiple retros
- Action items never completed
- "What went well" is always empty
- No learnings being captured
- Retros getting skipped

**What to do:**
- If same problem repeats: escalate priority of fixing it
- If actions not completed: make them smaller/more specific
- If no positives: actively look for wins, even small ones
- If no learnings: start using session-learnings skill

## Integration

**Works with:**
- **session-learnings** — Source of captured insights
- **systematic-debugging** — Incident retros use debugging insights
- **writing-plans** — Action items can become planned work

**Good cadence:**
- Solo developer: Weekly mini-retros
- Small team: Bi-weekly full retros
- After incidents: Always do incident retros
