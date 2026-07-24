#!/usr/bin/env bash
# Test: task-brief.sh — section-based plan task extraction
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

echo "=== Test: task-brief.sh ==="

TB="$REPO_ROOT/skills/subagent-driven-development/scripts/task-brief"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# ---------- Create a test plan with multiple edge cases ----------
cat > "$WORKDIR/test-plan.md" << 'PLANEOF'
# Test Plan

## Section: Overview

This plan tests various task heading formats and code fence edge cases.

### Task 1: Simple task (H3 format)

Blocking: none
Slice type: verification

**Files:**
- Modify: `src/foo.py`

- [ ] **Step 1: Do a thing**

Run: `echo "hello"`
Expected: `hello`

---

### Task 2: Task with code block

Blocking: none
Slice type: refactor

**Files:**
- Modify: `src/bar.py`

- [ ] **Step 1: Add a function**

```python
def hello():
    print("hello")
```

- [ ] **Step 2: Verify**

Run: `python -c "import bar"`

---

### Task 3: Task with H1-looking code comments

Blocking: none
Slice type: refactor

**Files:**
- Modify: `src/config.sh`

- [ ] **Step 1: Test edge case — code comments with # prefix**

```bash
# This is a comment that looks like an H1 heading
# So is this — should not stop extraction
echo "hello"
```

- [ ] **Step 2: Verify**

Run: `bash src/config.sh`

---

### Task 4: Task with nested backtick examples

Blocking: Task 1, Task 2
Slice type: verification

Demonstrates showing backtick content inside a code block:

```markdown
### Task X: Example
Blocking: none
```

The code block above contains ### Task X: which should NOT trigger
extraction to stop.

### Task 5: Task with ## format (H2)

Blocking: none

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update docs**

Run: `cat README.md`

---
PLANEOF

# Also create a plan with ## Task N: format (dragonpass-style)
cat > "$WORKDIR/test-plan-h2.md" << 'PLANEOF'
## Task 1: First task (H2 format)

Blocking: none

**Files:**
- Modify: `src/a.ts`

- [ ] **Step 1: Implement**

---

## Task 2: Second task

Blocking: none

**Files:**
- Modify: `src/b.ts`

- [ ] **Step 1: Implement**

---

## Task 3: Third task with code fence

Blocking: none

**Files:**
- Modify: `src/c.ts`

- [ ] **Step 1: Code with # comments**

```typescript
// # this is a comment
const x = 1;
```

---

## Task 4: Fourth task

Blocking: none

**Files:**
- Modify: `src/d.ts`

- [ ] **Step 1: Verify**

---
PLANEOF

PASS_COUNT=0
FAIL_COUNT=0
SDD_DIR="$REPO_ROOT/.agent-harness/sdd"
mkdir -p "$SDD_DIR"

# ========== Test 1: H3 plan — all 5 tasks extract ==========
echo ""
echo "--- H3 (### Task N:) format ---"
for i in 1 2 3 4 5; do
  brief="$SDD_DIR/task-${i}-brief.md"
  rm -f "$brief"
  output=$("$TB" "$WORKDIR/test-plan.md" $i 2>&1)
  if [ $? -eq 0 ] && [ -s "$brief" ]; then
    first=$(head -1 "$brief" | head -c 60)
    pass "H3 Task $i extracted: $first"
  else
    fail "H3 Task $i failed: $output"
  fi
done

# ========== Test 2: H2 plan — all 4 tasks extract ==========
echo ""
echo "--- H2 (## Task N:) format ---"
for i in 1 2 3 4; do
  brief="$SDD_DIR/task-${i}-brief.md"
  rm -f "$brief"
  output=$("$TB" "$WORKDIR/test-plan-h2.md" $i 2>&1)
  if [ $? -eq 0 ] && [ -s "$brief" ]; then
    first=$(head -1 "$brief" | head -c 60)
    pass "H2 Task $i extracted: $first"
  else
    fail "H2 Task $i failed: $output"
  fi
done

# ========== Test 3: Non-existent task ==========
echo ""
echo "--- Edge cases ---"
output=$("$TB" "$WORKDIR/test-plan.md" 99 2>&1) && rc=$? || rc=$?
if [ "$rc" -eq 3 ]; then
  pass "Non-existent Task 99 exits with code 3"
else
  fail "Non-existent Task 99 should exit 3, got $rc: $output"
fi

# ========== Test 4: Empty plan file ==========
output=$("$TB" "$WORKDIR/nonexistent.md" 1 2>&1) && rc=$? || rc=$?
if [ "$rc" -eq 2 ]; then
  pass "Missing plan file exits with code 2"
else
  fail "Missing plan file should exit 2, got $rc: $output"
fi

# ========== Test 5: Nested fences don't truncate ==========
echo ""
echo "--- Nested fence handling ---"
brief="$SDD_DIR/task-4-brief.md"
rm -f "$brief"
"$TB" "$WORKDIR/test-plan.md" 4 > /dev/null 2>&1
if [ -f "$brief" ]; then
  lines=$(wc -l < "$brief" | tr -d ' ')
  # Task 4 has content after the nested fence — should be more than 10 lines
  if [ "$lines" -ge 10 ]; then
    pass "Task 4 (nested fence) complete: $lines lines"
  else
    fail "Task 4 truncated: only $lines lines (expected >= 10)"
  fi
  # Verify no stray "### Task" in the body (the example inside code fence is OK)
  body_lines=$(sed -n '2,$p' "$brief" | grep -c '### Task' || true)
  # The example "### Task X:" inside code block should NOT cause the task to end
  # Verify Task 4 stops before Task 5 (the example "### Task X:" inside code
  # block should NOT cause premature stop; only ### Task 5: at top level should)
  if ! grep -q '### Task 5:' "$brief"; then
    pass "Task 4 does not overshoot into Task 5"
  else
    fail "Task 4 missing content — may have stopped at example fence"
  fi
else
  fail "Task 4 brief not created"
fi

# ========== Test 6: Comments with # prefix don't trigger H1 stop ==========
brief="$SDD_DIR/task-3-brief.md"
rm -f "$brief"
"$TB" "$WORKDIR/test-plan.md" 3 > /dev/null 2>&1
if [ -f "$brief" ]; then
  has_step2=$(grep -c 'Step 2' "$brief" || true)
  if [ "$has_step2" -ge 1 ]; then
    pass "Task 3 (H1-looking comments) has Step 2 content"
  else
    fail "Task 3 truncated by H1-looking comments"
  fi
else
  fail "Task 3 brief not created"
fi

# ========== Test 7: Extract from SDD Fan-Out plan (real-world) ==========
echo ""
echo "--- Real-world: SDD Fan-Out plan ---"
SFD_PLAN="$REPO_ROOT/docs/agent-harness/plans/2026-07-24-sdd-fan-out.md"
if [ -f "$SFD_PLAN" ]; then
  for i in 1 2 3 4 9 10; do
    brief="$SDD_DIR/task-${i}-brief.md"
    rm -f "$brief"
    output=$("$TB" "$SFD_PLAN" $i 2>&1) && rc=$? || rc=$?
    if [ "$rc" -eq 0 ] && [ -s "$brief" ]; then
      lines=$(wc -l < "$brief" | tr -d ' ')
      # Each task should have at least some content
      if [ "$lines" -ge 3 ]; then
        pass "SFD Task $i: $lines lines"
      else
        fail "SFD Task $i too short: $lines lines"
      fi
    else
      fail "SFD Task $i failed (exit=$rc)"
    fi
  done
else
  echo "  [SKIP] SDD Fan-Out plan not found"
fi

# ========== Summary ==========
print_summary "task-brief.sh"
