---
spec_ref: ../specs/2026-07-21-brainstorming-optimization-design.md
spec_topic: brainstorming-optimization
task_count: 5
estimated_phases: [tests, implementation, verification]
dod: "brainstorming skill uses frontier rounds with recommended answers and facts/decisions separation, preserves existing agent-harness gates and integrations, removes conflicting single-question prompt text, and passes or records the required skill verification gates."
status: completed
---

# Brainstorming Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimize `skills/brainstorming/SKILL.md` so clarification uses decision-tree frontier rounds with recommended answers and agent-owned fact lookup while preserving Agent Harness handoff gates.

**Architecture:** This is a single-skill behavior update. The implementation edits only `skills/brainstorming/SKILL.md` plus existing knowledge-base indexes already touched for the approved spec/contract. Verification uses static text checks and the existing skill behavior/loading test harnesses; no new runtime code, dependencies, or helper scripts are introduced.

**Tech Stack:** Markdown skill prompt, YAML frontmatter, shell-based validation scripts, Claude Code headless skill tests.

---

## File Structure

- Modify: `skills/brainstorming/SKILL.md` — source-of-truth behavioral prompt for brainstorming.
- Modify: `docs/agent-harness/specs/2026-07-21-brainstorming-optimization-design.md` — already updated with GDD section before this plan.
- Create: `docs/agent-harness/contracts/brainstorming-optimization.contract.md` — already created before this plan.
- Modify: `docs/agent-harness/contracts/index.md` — already updated with the contract link before this plan.
- Create: `docs/agent-harness/plans/2026-07-21-brainstorming-optimization.md` — this plan.
- Modify: `docs/agent-harness/plans/index.md` — add this plan to the plans index.

## Commit Strategy

Manual commit. Do not include per-task commit steps. After all tasks pass verification and the user reviews the diff, create one final commit if the user explicitly asks.

## GDD Traceability

- `L4-1`, `L3-1`, `L2-1`: Tasks 1-2 implement frontier rounds, recommended answers, and facts/decisions separation.
- `L3-2`, `L2-2`: Task 3 preserves existing Agent Harness gates, domain-modeling, circuit-breaker, and Six Forcing Questions.
- `L1-1`, `L1-2`: Task 4 removes conflicting prompt text and verifies prompt-size reduction.
- All contract acceptance criteria: Task 5 runs or records the required validation commands.

---

### Task 1: Rewrite clarification contract around frontier rounds

**Files:**
- Modify: `skills/brainstorming/SKILL.md:10`
- Modify: `skills/brainstorming/SKILL.md:24-33`
- Modify: `skills/brainstorming/SKILL.md:71-80`

- [ ] **Step 1: Update the overview sentence**

Replace the current overview sentence:

```markdown
Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.
```

with:

```markdown
Start by understanding the current project context, then clarify decisions in frontier rounds: ask every currently-unblocked question together, each with a recommended answer, then recompute the frontier after the user responds. Once you understand what you're building, present the design and get user approval.
```

Expected: the top-level summary no longer teaches one-question-at-a-time behavior.

- [ ] **Step 2: Update checklist step 2 and insert decision-tree step**

Replace checklist items 2-8:

```markdown
2. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
   - When domain terms crystallize (user defines a concept, or you propose a precise term to replace fuzzy language), invoke `agent-harness:domain-modeling` to update `CONTEXT.md` inline. If `CONTEXT.md` doesn't exist yet, the skill creates it lazily. Spec output should use `CONTEXT.md` vocabulary and include a `domain_terms` field in frontmatter listing the core terms.
3. **Propose 2-3 approaches** — with trade-offs and your recommendation
4. **Present design** — in sections scaled to their complexity, get user approval after each section
5. **Write design doc** — save to `docs/agent-harness/specs/YYYY-MM-DD-<topic>-design.md` (check if target directory is gitignored before committing; if so, inform user and save anyway)
6. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
7. **User reviews written spec** — ask user to review the spec file before proceeding
8. **Transition to implementation** — invoke writing-plans skill to create implementation plan
```

with:

```markdown
2. **Map decision tree** — optional, complex tasks only (3+ decision dimensions): sketch the key decision dependencies before questioning
3. **Ask clarifying questions** — work the current frontier in rounds; ask all unblocked decision questions together, each with a recommended answer and reason
   - When domain terms crystallize (user defines a concept, or you propose a precise term to replace fuzzy language), invoke `agent-harness:domain-modeling` to update `CONTEXT.md` inline. If `CONTEXT.md` doesn't exist yet, the skill creates it lazily. Spec output should use `CONTEXT.md` vocabulary and include a `domain_terms` field in frontmatter listing the core terms.
4. **Propose 2-3 approaches** — with trade-offs and your recommendation
5. **Present design** — in sections scaled to their complexity, get user approval after each section
6. **Write design doc** — save to `docs/agent-harness/specs/YYYY-MM-DD-<topic>-design.md` (check if target directory is gitignored before committing; if so, inform user and save anyway)
7. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
8. **User reviews written spec** — ask user to review the spec file before proceeding
9. **Transition to implementation** — invoke writing-plans skill to create implementation plan
```

Expected: `domain-modeling` instruction remains intact; checklist now includes decision-tree mapping and frontier rounds.

- [ ] **Step 3: Update the process flow diagram labels**

In the DOT graph, replace:

```dot
    "Ask clarifying questions" [shape=box];
```

with:

```dot
    "Map decision tree\n(optional)" [shape=box];
    "Ask frontier questions\nin rounds" [shape=box];
```

Replace these edges:

```dot
    "Explore project context" -> "Ask clarifying questions";
    "Ask clarifying questions" -> "Propose 2-3 approaches";
```

with:

```dot
    "Explore project context" -> "Map decision tree\n(optional)";
    "Map decision tree\n(optional)" -> "Ask frontier questions\nin rounds";
    "Ask frontier questions\nin rounds" -> "Propose 2-3 approaches";
```

Expected: the process diagram matches the new checklist without changing later gates.

- [ ] **Step 4: Replace the old “Understanding the idea” question rules**

In `**Understanding the idea:**`, replace the five bullets starting at “Check out the current project state first” through “Focus on understanding” with:

```markdown
- Check out the current project state first (files, docs, recent commits)
- Before asking detailed questions, assess scope: if the request describes multiple independent subsystems (e.g., "build a platform with chat, file storage, billing, and analytics"), flag this immediately. Don't spend questions refining details of a project that needs to be decomposed first.
- For large tasks (full-stack project, multiple apps, backend + frontend + AI, or likely >8 implementation tasks), do **大型任务分段** first: present a directory-level **execution map** with the proposed sub-plans and confirmation gates. Do not write a monolithic spec/plan. Default split: infrastructure / backend / frontend / design-polish, adjusted to the project.
- If the project is too large for a single spec, help the user decompose into sub-projects: what are the independent pieces, how do they relate, what order should they be built? Then brainstorm the first sub-project through the normal design flow. Each sub-project gets its own spec → plan → implementation cycle.
- For complex tasks with 3+ decision dimensions, map the **decision tree** before questioning: identify what must be decided first and which later questions depend on each branch. Simple tasks can keep this tree implicit.
```

Expected: scope/decomposition behavior remains, but old single-question rules are gone.

---

### Task 2: Add frontier batching and facts/decisions rules

**Files:**
- Modify: `skills/brainstorming/SKILL.md:71-90`

- [ ] **Step 1: Insert the new clarifying question block**

Immediately after the updated `Understanding the idea` bullets, insert:

```markdown
**Ask clarifying questions:**

- Build the current **frontier**: every decision whose prerequisites are already settled and can be answered now
- Ask the whole frontier in one round: number each question and include a recommended answer with the reason
- Wait for the user's answers, then recompute the frontier; settled decisions unblock dependent questions for the next round
- If question B depends on question A's answer, B belongs to a later round, not the current one
- Do not force 3+ questions per round: when the real frontier has only one question, ask one question
- Recommended answers are defaults, not constraints: the user may accept, modify, or reject them
```

Expected: GDD `L3-1-G1-A1` through `L3-1-G1-A3` are directly represented.

- [ ] **Step 2: Insert the facts/decisions rule block**

Immediately after the clarifying question block, insert:

```markdown
**Fact-checking rules:**

- Separate **facts** from **decisions**
- Facts are things you can look up: project file structure, existing API endpoints, config files, codebase patterns
- Decisions require human judgment: technology choices, business logic, product trade-offs, design preferences
- Facts are your job: use tools or dispatch subagents to check them; never ask the user for facts you can inspect
- Do not block unnecessarily: while a fact-finding subagent runs, keep asking frontier questions that do not depend on that fact
- Only questions downstream of an unresolved fact wait for the fact-finding result
```

Expected: GDD `L2-1-G1-A1` through `L2-1-G1-A4` are directly represented.

- [ ] **Step 3: Verify no accidental implementation permission was added**

Read `skills/brainstorming/SKILL.md:12-14` and confirm this exact block still exists:

```markdown
<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>
```

Expected: no task modifies the hard gate.

---

### Task 3: Preserve existing Agent Harness integrations while adapting retained sections

**Files:**
- Modify: `skills/brainstorming/SKILL.md:88-178`
- Modify: `skills/brainstorming/SKILL.md:189-245`

- [ ] **Step 1: Condense design isolation into presenting design**

In `**Presenting the design:**`, keep the existing bullets and add this bullet after `Cover: architecture, components, data flow, error handling, testing`:

```markdown
- Keep units isolated and understandable: each component should have one clear purpose, explicit dependencies, and boundaries a reader can understand without reading internals
```

Expected: isolation guidance remains but is no longer a long standalone section.

- [ ] **Step 2: Delete the standalone design isolation section**

Remove this entire section:

```markdown
**Design for isolation and clarity:**

- Break the system into smaller units that each have one clear purpose, communicate through well-defined interfaces, and can be understood and tested independently
- For each unit, you should be able to answer: what does it do, how do you use it, and what does it depend on?
- Can someone understand what a unit does without reading its internals? Can you change the internals without breaking consumers? If not, the boundaries need work.
- Smaller, well-bounded units are also easier for you to work with - you reason better about code you can hold in context at once, and your edits are more reliable when files are focused. When a file grows large, that's often a signal that it's doing too much.
```

Expected: GDD `L1-2-G1-A2` is satisfied.

- [ ] **Step 3: Keep the handoff pipeline unchanged**

Read the `## After the Design` section and confirm these exact strings still appear:

```text
scripts/validate-handoff.sh --stage spec --file <spec-path>
scripts/log-phase-metric.sh --phase brainstorming --action gate --gate-result passed --spec-topic "$SPEC_TOPIC"
agent-harness:sprint-contract
writing-plans skill
```

Expected: GDD `L3-2-G1-A3` and `L3-2-G1-A4` remain satisfied.

- [ ] **Step 4: Adapt the circuit-breaker opening sentence**

In `## Clarification Loop Circuit-Breaker (issue #83)`, replace:

```markdown
If the user rejects your proposed options **3 times in a row** (clear rejection
```

with:

```markdown
If the user rejects your proposed options or recommended frontier answers **3 times in a row** (clear rejection
```

Expected: GDD `L2-2-G1-A1` is compatible with recommended answers.

- [ ] **Step 5: Adapt Six Forcing Questions to facts/decisions separation**

Replace:

```markdown
**How to use:** Ask these questions one at a time during the "Ask clarifying questions" phase. Not every question needs a long answer — some can be quick. But each must be addressed.
```

with:

```markdown
**How to use:** Ask these during the frontier questioning phase when they are decision questions. Do not use them to ask for facts the agent can inspect. Not every question needs a long answer — some can be quick. But each must be addressed.
```

Expected: GDD `L2-2-G1-A2` and `L2-2-G1-A3` remain satisfied.

---

### Task 4: Remove conflicting prompt sediment and verify static constraints

**Files:**
- Modify: `skills/brainstorming/SKILL.md:180-188`

- [ ] **Step 1: Delete the Key Principles section**

Remove this entire section:

```markdown
## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design, get approval before moving on
- **Be flexible** - Go back and clarify when something doesn't make sense
```

Expected: GDD `L1-1-G1-A3` is satisfied; non-conflicting principles already exist in process sections.

- [ ] **Step 2: Run static phrase checks**

Run:

```bash
if grep -F "Only one question per message" skills/brainstorming/SKILL.md; then exit 1; fi
if grep -F "One question at a time" skills/brainstorming/SKILL.md; then exit 1; fi
```

Expected: exit 0 with no output.

- [ ] **Step 3: Verify prompt line count decreased**

Run:

```bash
wc -l skills/brainstorming/SKILL.md
```

Expected: first number is less than `257`.

- [ ] **Step 4: Verify no unrelated files were introduced**

Run:

```bash
git diff --name-only
```

Expected: changed files are limited to the brainstorming skill and the approved spec/contract/plan/index files for this workflow.

---

### Task 5: Run validation gates and capture evidence

**Files:**
- Read/execute only: `scripts/validate-handoff.sh`
- Read/execute only: `tests/skill-behavior/brainstorming/run-test.sh`
- Read/execute only: `tests/claude-code/run-skill-tests.sh`

- [ ] **Step 1: Validate the approved spec handoff**

Run:

```bash
scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-07-21-brainstorming-optimization-design.md
```

Expected: output contains `OK spec 2026-07-21-brainstorming-optimization-design.md` and exit code 0.

- [ ] **Step 2: Validate this implementation plan**

Run:

```bash
scripts/validate-handoff.sh --stage plan --file docs/agent-harness/plans/2026-07-21-brainstorming-optimization.md
```

Expected: output contains `OK plan 2026-07-21-brainstorming-optimization.md` and exit code 0.

- [ ] **Step 3: Run brainstorming behavior test**

Run:

```bash
cd tests/skill-behavior/brainstorming && ./run-test.sh
```

Expected: exit code 0. If it fails because Claude API/headless environment/quota is unavailable, capture the full command output and mark this gate as “not runnable in current environment” rather than silently skipping it.

- [ ] **Step 4: Run Claude Code skill loading tests**

Run:

```bash
cd tests/claude-code && ./run-skill-tests.sh
```

Expected: exit code 0. If it fails because Claude API/headless environment/quota is unavailable, capture the full command output and mark this gate as “not runnable in current environment” rather than silently skipping it.

- [ ] **Step 5: Emit writing-plans phase metric**

Run:

```bash
if scripts/validate-handoff.sh --stage plan --file docs/agent-harness/plans/2026-07-21-brainstorming-optimization.md; then
  scripts/log-phase-metric.sh --phase writing-plans --action gate --gate-result passed --spec-topic brainstorming-optimization
else
  scripts/log-phase-metric.sh --phase writing-plans --action gate --gate-result failed --spec-topic brainstorming-optimization
fi
```

Expected: validation output appears and metric command exits 0.

---

## Final Commit Reminder

After implementation, tests, and human diff review, make one explicit commit only if the user asks for it. Suggested message:

```bash
git add skills/brainstorming/SKILL.md docs/agent-harness/specs/2026-07-21-brainstorming-optimization-design.md docs/agent-harness/contracts/brainstorming-optimization.contract.md docs/agent-harness/contracts/index.md docs/agent-harness/plans/2026-07-21-brainstorming-optimization.md docs/agent-harness/plans/index.md
git commit -m "$(cat <<'EOF'
feat(brainstorming): optimize clarification flow
EOF
)"
```
