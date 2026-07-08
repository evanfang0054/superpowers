---
spec_ref: ../specs/2026-06-29-harness-engineering-improvements-design.md
spec_topic: harness-engineering-improvements
task_count: 6
estimated_phases: [tests, implementation, verification, pr-update]
dod: "PR #73 review findings are fixed with script regression tests, truthful README claims, and updated PR description."
---

# PR #73 Logic Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the concrete logic gaps found in PR #73 without expanding Harness Engineering scope.

**Architecture:** Keep the current shell + markdown architecture. Add focused script behavior where existing docs already promise it, narrow project-specific hints to agent-harness projects only, and downgrade claims that current code cannot support.

**Tech Stack:** Bash, Python stdlib snippets inside shell scripts, jq-compatible JSONL conventions, markdown skills/docs.

---

## File Responsibility Map

- `scripts/query-phase-metrics.sh` — aggregate phase metrics; must support both per-phase and all-phase summaries.
- `scripts/coverage-metrics.sh` — delegates `--trends` to `query-phase-metrics.sh`; tests prove the delegation supports summary mode.
- `skills/retrospective/SKILL.md` — calls phase metrics in a way the script actually supports.
- `scripts/lib/handoff-schema.sh` — validates handoff frontmatter and matches `spec_topic` safely against the KB index.
- `skills/brainstorming/SKILL.md` — documents a spec frontmatter template before the hard gate requires validation.
- `skills/writing-plans/SKILL.md` — documents a plan frontmatter template before the title/header.
- `hooks/session-start` — injects KB hint only when the current project actually has `docs/agent-harness/index.md`.
- `scripts/diagnose-failure.sh` — aligns CLI usage and stdout/stderr contract.
- `scripts/write-diagnosis-task.sh` — appends only to an explicit `--plan`, otherwise writes a standalone diagnosis note; no emoji heading.
- `README.md` — describes shipped Harness Engineering capabilities truthfully.
- `tests/phase-metrics-scripts/test-phase-metrics.sh` — regression coverage for all-phase summary and trends delegation.
- `tests/handoff-scripts/test-validate-handoff.sh` — regression coverage for literal topic matching.
- `tests/diagnose-scripts/test-diagnose-failure.sh` — regression coverage for diagnosis stdout and file context behavior.
- `tests/diagnose-scripts/test-write-diagnosis-task.sh` — regression coverage for standalone default and explicit append behavior.

## Contract Trace

- Observability claims in the design (`query-phase-metrics.sh --recent 14 --summary`) must execute successfully.
- Handoff gates must be usable by the skills that instruct agents to run them.
- Knowledge-base lookup rules must not leak as a global constraint into non-agent-harness projects.
- Failure diagnosis must produce machine-readable paths and avoid silently mutating unrelated plans.
- README / PR copy must not claim token, duration, cost, or skill-emission behavior beyond what the scripts actually implement.

## Manual Commit Strategy

Do not commit after each task. After all tests pass and the diff is reviewed, create one focused fix commit for PR #73 and push it to `feat/harness-engineering-improvements`.

---

### Task 1: Add failing regressions for metrics summary and README-safe claims

**Files:**
- Modify: `tests/phase-metrics-scripts/test-phase-metrics.sh`

- [ ] **Step 1: Add all-phase summary assertions**

Append this after the existing `--recent` test:

```bash
# --- Test 8: global --summary without --phase ---
echo "--- Test 8: global --summary without --phase ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 1000 --gate-result passed --spec-topic t1
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase writing-plans --action end --duration-ms 2000 --gate-result failed --spec-topic t1
OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --summary)
echo "$OUT" | grep -q "phase: all" && log_pass "global summary reports phase all" || log_fail "global summary phase missing"
echo "$OUT" | grep -q "count.*2" && log_pass "global summary count=2" || log_fail "global summary count wrong"
echo "$OUT" | grep -q "failed.*1" && log_pass "global summary failed=1" || log_fail "global summary failed wrong"
```

- [ ] **Step 2: Add coverage trends delegation assertion**

Append immediately after Test 8:

```bash
# --- Test 9: coverage --trends supports global summary ---
echo "--- Test 9: coverage --trends global summary ---"
OUT=$("$PLUGIN_DIR/scripts/coverage-metrics.sh" --trends --summary)
echo "$OUT" | grep -q "phase: all" && log_pass "coverage trends delegates global summary" || log_fail "coverage trends global summary failed"
```

- [ ] **Step 3: Run the test and observe failure**

Run:

```bash
tests/phase-metrics-scripts/run-all.sh
```

Expected before implementation: failure from `query-phase-metrics.sh: --phase required`.

- [ ] **Step 4: Implement global summary support**

In `scripts/query-phase-metrics.sh`, change the required phase behavior:

```bash
# old behavior rejects missing PHASE
# [ -z "$PHASE" ] && { echo "query-phase-metrics: --phase required" >&2; exit 1; }

# new behavior treats missing PHASE as an all-phase aggregate
[ -z "$PHASE" ] && PHASE="all"
```

Then in the Python row filter, replace:

```python
if d.get("phase") != phase:
    continue
```

with:

```python
if phase != "all" and d.get("phase") != phase:
    continue
```

Keep the existing result shape so callers get `phase: all`, `count`, durations, failure rate, tokens, cost, and retries.

- [ ] **Step 5: Verify metrics tests pass**

Run:

```bash
tests/phase-metrics-scripts/run-all.sh
```

Expected: all phase metrics tests pass.

---

### Task 2: Fix handoff gates and skill templates

**Files:**
- Modify: `tests/handoff-scripts/test-validate-handoff.sh`
- Modify: `scripts/lib/handoff-schema.sh`
- Modify: `skills/brainstorming/SKILL.md`
- Modify: `skills/writing-plans/SKILL.md`

- [ ] **Step 1: Add literal topic matching regression**

Append this to `tests/handoff-scripts/test-validate-handoff.sh` before the final results block:

```bash
# --- Test 5: topic matching is literal and anchored ---
echo "--- Test 5: literal topic matching ---"
setup
mkdir -p docs/agent-harness/specs
echo "- alpha.beta → specs/real.md" > docs/agent-harness/index.md
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: alphaXbeta
decision_summary: x
design_approved: true
user_approved_at: 2026-06-29T10:00:00Z
gates: []
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md 2>/dev/null
[ $? -ne 0 ] && log_pass "regex-like near match rejected" || log_fail "regex-like near match accepted"
```

- [ ] **Step 2: Run handoff tests and observe failure**

Run:

```bash
tests/handoff-scripts/run-all.sh
```

Expected before implementation: Test 5 fails because `grep` treats `.` as regex wildcard.

- [ ] **Step 3: Fix topic matching**

In `scripts/lib/handoff-schema.sh`, replace the `grep -q "$topic"` check with fixed-string matching against the canonical topic bullet prefix:

```bash
if [ -f "$idx" ] && ! grep -Fq -- "- $topic →" "$idx" 2>/dev/null; then
  echo "validate-handoff: spec_topic '$topic' not found in docs/agent-harness/index.md" >&2
  rc=1
fi
```

- [ ] **Step 4: Add spec frontmatter template to brainstorming**

In `skills/brainstorming/SKILL.md`, under `Write design doc`, add:

```markdown
Every spec document must start with YAML frontmatter before the title:

```yaml
---
spec_topic: <topic-from-docs-agent-harness-index>
decision_summary: "<one sentence decision summary>"
design_approved: true
user_approved_at: <ISO-8601 timestamp>
gates: [user-review-passed]
---
```
```

Use a real topic from `docs/agent-harness/index.md`; if this is a new topic, add it to the index before running `validate-handoff.sh`.

- [ ] **Step 5: Replace plan header contract in writing-plans**

In `skills/writing-plans/SKILL.md`, change “Every plan MUST start with this header” to “Every plan MUST start with this frontmatter, followed by this header” and show:

```markdown
---
spec_ref: ../specs/<spec-file>.md
spec_topic: <topic-from-docs-agent-harness-index>
task_count: <number>
estimated_phases: [tests, implementation, verification]
dod: "<definition of done from sprint contract>"
---

# [Feature Name] Implementation Plan
```

Keep the existing agentic-worker block after the title.

- [ ] **Step 6: Verify handoff tests pass**

Run:

```bash
tests/handoff-scripts/run-all.sh
```

Expected: all handoff tests pass.

---

### Task 3: Scope SessionStart KB hint to agent-harness projects

**Files:**
- Modify: `hooks/session-start`
- Modify: `tests/plugin-infrastructure/run-all.sh` if it already registers hook tests by file list
- Add or modify the existing SessionStart hook test under `tests/plugin-infrastructure/`

- [ ] **Step 1: Locate the existing SessionStart hook test**

Run a targeted search:

```bash
grep -R "session-start\|Knowledge Base\|additionalContext" tests/plugin-infrastructure hooks -n
```

Use the existing test file if present; otherwise create `tests/plugin-infrastructure/test-session-start-kb-hint.sh` and register it in `tests/plugin-infrastructure/run-all.sh`.

- [ ] **Step 2: Add regression test for non-agent-harness projects**

The test should create a temporary `CLAUDE_PROJECT_DIR` without `docs/agent-harness/index.md`, run `hooks/session-start` with startup payload, and assert the output does not contain `Knowledge Base` or `**/*.md`.

```bash
TMP=$(mktemp -d)
OUT=$(printf '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$TMP" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/session-start")
printf '%s' "$OUT" | grep -q "Knowledge Base" && fail "KB hint omitted outside agent-harness projects" || pass "KB hint omitted outside agent-harness projects"
printf '%s' "$OUT" | grep -q "\*\*/\*.md" && fail "glob warning omitted outside agent-harness projects" || pass "glob warning omitted outside agent-harness projects"
```

Also create `$TMP/docs/agent-harness/index.md` and assert the hint appears for agent-harness projects.

- [ ] **Step 3: Implement scoped KB hint**

In `hooks/session-start`, replace the unconditional startup/clear hint block with:

```bash
kb_hint=""
if { [ "$SESSION_SOURCE" = "startup" ] || [ "$SESSION_SOURCE" = "clear" ]; } \
   && [ -f "$LEARNINGS_DIR/docs/agent-harness/index.md" ]; then
    kb_hint="\n\n## Knowledge Base\nAgent Harness 知识库入口: docs/agent-harness/index.md（仅用于本项目知识库检索：两级查找，不要对 docs/agent-harness 使用 **/*.md 全局通配）\n"
fi
```

- [ ] **Step 4: Verify plugin infrastructure tests pass**

Run:

```bash
tests/plugin-infrastructure/run-all.sh
```

Expected: all plugin infrastructure tests pass.

---

### Task 4: Fix diagnosis CLI contracts and task writing behavior

**Files:**
- Modify: `tests/diagnose-scripts/test-diagnose-failure.sh`
- Modify: `tests/diagnose-scripts/test-write-diagnosis-task.sh`
- Modify: `scripts/diagnose-failure.sh`
- Modify: `scripts/write-diagnosis-task.sh`
- Modify: `skills/systematic-debugging/SKILL.md` if it documents the old contract
- Modify: `skills/loop-detection/SKILL.md` if it documents the old contract

- [ ] **Step 1: Add diagnosis stdout contract test**

In `tests/diagnose-scripts/test-diagnose-failure.sh`, after Test 1 captures `OUT`, assert stdout is only the JSON path:

```bash
echo "$OUT" | grep -Eq '^\.agent-harness/diagnoses/.+\.json$|^/.+\.agent-harness/diagnoses/.+\.json$' \
  && log_pass "stdout is diagnosis path" \
  || log_fail "stdout should be diagnosis path only"
```

- [ ] **Step 2: Add explicit `@file` context test or remove the promise**

Keep the documented `@file` form and add a test:

```bash
setup
echo '{"phase":"writing-plans","validate_error":"missing field spec_ref"}' > ctx.json
OUT=$("$PLUGIN_DIR/scripts/diagnose-failure.sh" --type gate --context @ctx.json --spec-topic t2 2>/dev/null)
F="$OUT"
grep -q 'missing field spec_ref' "$F" && log_pass "@file context supported" || log_fail "@file context not loaded"
```

- [ ] **Step 3: Add write-diagnosis default no-append regression**

In `tests/diagnose-scripts/test-write-diagnosis-task.sh`, create an existing latest plan, call `write-diagnosis-task.sh --diagnosis diag.json` without `--plan`, and assert the plan remains unchanged while a standalone note is created.

```bash
setup
mkdir -p docs/agent-harness/plans
printf '# Plan\n' > docs/agent-harness/plans/latest.md
cat > diag.json <<'EOF'
{"ts":"2026-06-29T00:00:00Z","failure_type":"loop","spec_topic":"t1","failure_summary":"3 edits","evidence":{},"root_cause_hypothesis":"h","suggested_fixes":[{"action":"revisit-brainstorming","rationale":"r"}],"confidence":7}
EOF
"$PLUGIN_DIR/scripts/write-diagnosis-task.sh" --diagnosis diag.json >/dev/null
if [ "$(cat docs/agent-harness/plans/latest.md)" = "# Plan" ]; then log_pass "default does not append latest plan"; else log_fail "default mutated latest plan"; fi
F=$(ls docs/agent-harness/notes/diagnoses/*.md 2>/dev/null | head -1)
[ -n "$F" ] && log_pass "default writes standalone note" || log_fail "default standalone note missing"
```

- [ ] **Step 4: Run diagnose tests and observe failures**

Run:

```bash
tests/diagnose-scripts/run-all.sh
```

Expected before implementation: `@file` and default no-append tests fail.

- [ ] **Step 5: Implement `@file` and clean stdout in diagnose-failure**

In `scripts/diagnose-failure.sh`, replace context loading with:

```bash
CONTEXT=""
if [ -n "$CONTEXT_RAW" ]; then
  if [ "${CONTEXT_RAW#@}" != "$CONTEXT_RAW" ]; then
    CONTEXT_FILE="${CONTEXT_RAW#@}"
    [ -f "$CONTEXT_FILE" ] && CONTEXT=$(cat "$CONTEXT_FILE")
  elif [ -f "$CONTEXT_RAW" ]; then
    CONTEXT=$(cat "$CONTEXT_RAW")
  else
    CONTEXT="$CONTEXT_RAW"
  fi
fi
```

Keep the Python `print(os.environ["OUT"])` as the only stdout. Keep `echo "diagnosis written: $OUT" >&2` on stderr.

- [ ] **Step 6: Implement standalone-by-default task writing**

In `scripts/write-diagnosis-task.sh`, remove the latest-plan lookup and update the comment:

```bash
# 默认 --plan 缺省时：写独立文件到 docs/agent-harness/notes/diagnoses/<ts>-<type>.md。
# 只有显式 --plan 才追加到计划文件。
```

Remove this block:

```bash
if [ -z "$PLAN" ]; then
  LATEST=$(ls -t "$ROOT"/docs/agent-harness/plans/*.md 2>/dev/null | head -1 || true)
  PLAN="$LATEST"
fi
```

Change the generated heading:

```python
lines = ["", "## Diagnosis Task (auto-generated)", ""]
```

- [ ] **Step 7: Align skill references**

Search:

```bash
grep -R "diagnose-failure\|write-diagnosis-task\|@file\|latest plan\|Diagnosis Task" skills scripts tests -n
```

Update any skill text that says diagnosis auto-appends to the latest plan so it says standalone by default and append only with explicit `--plan`.

- [ ] **Step 8: Verify diagnose tests pass**

Run:

```bash
tests/diagnose-scripts/run-all.sh
```

Expected: all diagnose tests pass.

---

### Task 5: Make README and retrospective claims truthful

**Files:**
- Modify: `README.md`
- Modify: `skills/retrospective/SKILL.md`

- [ ] **Step 1: Update retrospective wording**

Keep the command:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/query-phase-metrics.sh" --recent 14 --summary
```

Change the interpretation bullets so they are conditional and truthful:

```markdown
Write the top available signals into the retro report:
- 失败率最高的阶段（from recorded `gate_result` values）
- 平均耗时最长的阶段（when `duration_ms` is recorded）
- 累计 token / cost 最高的阶段（only when token or cost fields were recorded）

If the metrics file is empty, say that no phase metrics have been recorded yet instead of inferring trends.
```

- [ ] **Step 2: Downgrade README capability table**

In `README.md`, replace claims like “token / 耗时 / 失败率持久化” and “7 个核心 skill 在阶段边界主动 emit” with wording that matches current implementation:

```markdown
`.agent-harness/phase-metrics.jsonl` 可记录阶段事件；`log-phase-metric.sh` / `query-phase-metrics.sh` 支持查询已记录的 duration、gate_result、token/cost 字段。当前只有接入点显式调用时才会产生数据，不承诺自动覆盖所有核心 skill。
```

- [ ] **Step 3: Clarify SessionStart KB behavior in README if mentioned**

If README claims SessionStart always injects KB guidance, change it to:

```markdown
在包含 `docs/agent-harness/index.md` 的项目中，SessionStart 只注入一行知识库入口提示；普通项目不会收到 agent-harness 知识库检索约束。
```

- [ ] **Step 4: Search for overclaims**

Run:

```bash
grep -R "7 个核心 skill\|自动.*emit\|token / 耗时 / 失败率\|累计 token 成本" README.md skills docs/agent-harness -n
```

Update only shipped-facing or active skill text. Leave historical design docs alone unless they are directly used as current documentation.

---

### Task 6: Final verification, commit, push, and PR update

**Files:**
- `.github/PULL_REQUEST_TEMPLATE.md` — read before updating PR body.
- No source edits unless verification exposes a real defect.

- [ ] **Step 1: Run focused test suites**

Run:

```bash
tests/phase-metrics-scripts/run-all.sh
tests/handoff-scripts/run-all.sh
tests/diagnose-scripts/run-all.sh
tests/plugin-infrastructure/run-all.sh
```

Expected: all pass.

- [ ] **Step 2: Inspect diff**

Run:

```bash
git diff -- README.md hooks/session-start scripts/query-phase-metrics.sh scripts/coverage-metrics.sh scripts/lib/handoff-schema.sh scripts/diagnose-failure.sh scripts/write-diagnosis-task.sh skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/retrospective/SKILL.md tests/phase-metrics-scripts/test-phase-metrics.sh tests/handoff-scripts/test-validate-handoff.sh tests/diagnose-scripts/test-diagnose-failure.sh tests/diagnose-scripts/test-write-diagnosis-task.sh
```

Verify the diff contains only PR #73 review fixes.

- [ ] **Step 3: Commit**

Run:

```bash
git add README.md hooks/session-start scripts/query-phase-metrics.sh scripts/lib/handoff-schema.sh scripts/diagnose-failure.sh scripts/write-diagnosis-task.sh skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/retrospective/SKILL.md tests/phase-metrics-scripts/test-phase-metrics.sh tests/handoff-scripts/test-validate-handoff.sh tests/diagnose-scripts/test-diagnose-failure.sh tests/diagnose-scripts/test-write-diagnosis-task.sh

git commit -m "$(cat <<'EOF'
fix(harness-engineering): close PR review logic gaps
EOF
)"
```

Include `scripts/coverage-metrics.sh` or plugin-infrastructure test files in `git add` only if they changed.

- [ ] **Step 4: Push to PR #73 branch**

Run:

```bash
git push origin feat/harness-engineering-improvements
```

- [ ] **Step 5: Update PR #73 body truthfully**

Read `.github/PULL_REQUEST_TEMPLATE.md`, then update PR #73 with:

- Existing PRs: mention the searched duplicates or state the exact search performed.
- Summary: list metrics summary, handoff frontmatter, scoped KB hint, diagnosis contract, topic matching, and README truthfulness fixes.
- Tests: include the four focused suites and their pass status.
- Environment table: mark the harness used for script tests.
- Limitations: explicitly state token/cost fields are reported only when recorded; no claim of full automatic skill coverage.

Use `gh pr edit 73 --body-file <file>` after preparing the body locally.
