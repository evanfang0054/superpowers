---
name: sprint-contract
description: "Use after brainstorming produces a spec and before writing-plans — negotiates explicit Definition of Done to prevent ambiguity."
whenToUse: "[feedforward] Triggered between brainstorming and writing-plans for non-trivial tasks."
---

# Sprint Contract

## Overview

A sprint contract is a negotiated agreement on what "done" means, created before planning begins. Without it, "completed but not what was expected" is the default outcome.

**Core principle:** If you didn't negotiate Done, you don't know what Done means.

**Violating the letter of this rule is violating the spirit of this rule.**

## When to Use

**Required for:** All non-trivial tasks that pass through brainstorming.

**Skip ONLY for:**
- Single-line typo fix
- Pure documentation changes (no behavior modification)
- Truly trivial changes (no logic change)

If you are debating whether to skip, do not skip. Debate = non-trivial.

## Core Pattern: Generator-Evaluator Dialogue

The agent plays both roles in sequence. This is not a form to fill out -- it is a negotiation.

**Outcome statement prerequisite (issue #83):** Before generating the initial
Definition of Done, write one paragraph (2-4 sentences) describing the
**user-visible outcome** the feature should produce — what the user sees,
does, or avoids having to do once it ships. Write it in the user's voice, not
implementation terms. If you cannot write this paragraph, the spec is not
ready for a contract yet. **Do NOT push the user back into brainstorming** —
that risks a bounce loop between brainstorming's HARD-GATE and sprint-contract.
Instead:
1. Present the user with two options: (a) supplement the outcome description
   here and continue, or (b) invoke `agent-harness:office-hours` to re-align
   on goals before returning to the contract.
2. office-hours sits upstream of brainstorming in the workflow and avoids
   the loop.
This blocks the #83 failure mode of negotiating detailed acceptance criteria
for the wrong problem.

```
1. OUTCOME: Write the user-visible outcome paragraph (2-4 sentences).
2. GENERATOR: Read the spec + outcome. Produce initial Definition of Done.
3. EVALUATOR: Challenge every criterion. Is it testable? Is it unambiguous?
   Could two people disagree on whether it's met?
4. GENERATOR: Revise based on evaluator challenges.
5. EVALUATOR: Accept or challenge again.
6. Repeat until evaluator accepts without further challenges.
7. Save contract to docs/agent-harness/contracts/{feature-name}.contract.md
```

**Minimum 2 rounds of generator-evaluator.** If evaluator accepts on round 1, the criteria were too vague.

## Contract Template

```markdown
# Sprint Contract: <feature name>

## Definition of Done
- [ ] <specific verifiable criterion 1>
- [ ] <specific verifiable criterion 2>
- [ ] <specific verifiable criterion 3>

## Boundary Conditions
- Must support: <constraint 1>
- Must not break: <constraint 2>
- Performance: <constraint 3>

## Acceptance Criteria
- Computational: <sensor name and threshold>
- Inferential: <review method>

## Negotiation Record
- Generator: <initial proposal>
- Evaluator: <modifications>
- Final consensus: <agreed version>
```

## Quick Reference

| Step | Action | Output |
|------|--------|--------|
| 1 | Read spec, generate initial DoD | Draft criteria |
| 2 | Switch to evaluator, challenge each criterion | Challenges list |
| 3 | Revise criteria to address challenges | Revised DoD |
| 4 | Repeat 2-3 until consensus | Final DoD |
| 5 | Fill boundary conditions and acceptance criteria | Full contract |
| 6 | Save to `docs/agent-harness/contracts/{feature-name}.contract.md` | Committed file |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "Requirements are clear enough" | Clear to whom? Ambiguity kills. Two people, two interpretations. |
| "This is too simple for a contract" | Simple things go wrong too. If it's truly trivial, it meets skip conditions. |
| "I'll verify after" | After = too late to negotiate. Contract exists to prevent rework. |
| "Contract slows us down" | Rework is slower. 5 minutes of negotiation saves hours of rework. |
| Vague criteria ("works correctly") | Every criterion must be a yes/no question. |
| Skipping evaluator role | Without challenge, criteria will have holes. Minimum 2 rounds. |
| Filling template without negotiation | The dialogue IS the value, not the document. |

## Red Flags - STOP

- About to invoke writing-plans without a saved contract
- Saying "requirements are clear" without negotiation
- Template filled in one pass without evaluator challenge
- Skip rationale is anything other than the three skip conditions above

**All of these mean: Stop and complete the sprint contract first.**

## Bottom Line

No contract = no plan. Negotiate Done before planning how to get there.
