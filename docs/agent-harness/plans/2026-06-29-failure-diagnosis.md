---
spec_ref: ../specs/2026-06-29-harness-engineering-improvements-design.md
spec_topic: failure-diagnosis
task_count: 7
estimated_phases: [impl, test, docs]
dod: success-criteria-in-spec
---

# Spec #4 失败自愈 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task.

**Goal:** 在 loop-detector / phase-metrics gate / test 失败三类信号与人工介入之间，插入 `diagnose-failure.sh`（收敛成结构化诊断 JSON）+ `write-diagnosis-task.sh`（回写为 task）。不自动执行修复，闭环可被人工打断。

**Architecture:** 复用已有信号源（loop-detector / phase-metrics / verification），新增收敛层 + 回写层，两个 shell 脚本。诊断 JSON 与 phase-metrics 同风格。回写默认：plan.md 存在则追加，否则独立文件。

**Tech Stack:** bash、python3 heredoc、jq。复用 `scripts/trace-analyzer.sh` / `query-phase-metrics.sh` / `search-learnings.sh`。

**Spec 来源:** `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md` §「Spec #4 · 失败自愈」

**依赖关系:** 依赖 Plan #1（query-phase-metrics + gate_result=failed 信号）、Plan #2（spec_topic 锚点）、Plan #3（learnings 索引）。

---

## 文件结构

| 文件 | 责任 |
|---|---|
| `scripts/diagnose-failure.sh`（新增） | 入口：`--type <loop\|gate\|test> --context <json/file> [--spec-topic <t>]` |
| `scripts/write-diagnosis-task.sh`（新增） | 诊断 JSON → markdown task；plan.md 存在则追加，否则独立文件 |
| `scripts/lib/diagnose-lib.sh`（新增） | 共享：trace-analyzer / query-phase-metrics / search-learnings 的封装调用 |
| `.agent-harness/diagnoses/`（运行态目录） | 存放 `<ts>-<type>-<slug>.json` 诊断报告（不入 git） |
| `docs/agent-harness/notes/diagnoses/`（产物目录） | 独立 task 文件产物（入 git，被 index.md 收录） |
| `skills/systematic-debugging/SKILL.md`（修改） | 调试结束调 diagnose-failure + write-diagnosis-task |
| `skills/loop-detection/SKILL.md`（修改） | HARD STOP 时触发 diagnose-failure |
| `tests/diagnose-scripts/test-diagnose-failure.sh`（新增） | 三类失败 / 优雅降级 |
| `tests/diagnose-scripts/test-write-diagnosis-task.sh`（新增） | JSON→task / 追加 vs 独立 |
| `tests/diagnose-scripts/run-all.sh`（新增） | 套件入口 |

---

## Task 1: diagnose-lib 共享封装

**Files:**
- Create: `scripts/lib/diagnose-lib.sh`

- [ ] **Step 1: 写 lib**

```bash
#!/usr/bin/env bash
# Shared helpers for diagnose-failure.sh.
# 封装对 trace-analyzer / query-phase-metrics / search-learnings 的调用，
# 三个信号源任一缺失都优雅降级（输出空字段，不崩）。

SCRIPT_DIR_DIAG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# diagnose_trace <context-json>
# 输出：失败模式分类字符串（无则空）
diagnose_trace() {
  local ctx="$1"
  local ta="$SCRIPT_DIR_DIAG/trace-analyzer.sh"
  [ ! -x "$ta" ] && { echo ""; return; }
  # trace-analyzer 接受文件或 stdin；这里传 ctx 字符串
  printf '%s' "$ctx" | "$ta" 2>/dev/null | head -50 || true
}

# diagnose_phase_history <phase> [spec-topic]
# 输出：jsonl 段（同阶段历史失败信息）
diagnose_phase_history() {
  local phase="$1" topic="${2:-}"
  local q="$SCRIPT_DIR_DIAG/query-phase-metrics.sh"
  [ ! -x "$q" ] && { echo "{}"; return; }
  if [ -n "$topic" ]; then
    "$q" --phase "$phase" --by-spec "$topic" --json 2>/dev/null || echo "{}"
  else
    "$q" --phase "$phase" --json 2>/dev/null || echo "{}"
  fi
}

# diagnose_similar_learnings <keyword>
# 输出：top-N learnings json（数组）
diagnose_similar_learnings() {
  local kw="$1"
  local s="$SCRIPT_DIR_DIAG/search-learnings.sh"
  [ ! -x "$s" ] && { echo "[]"; return; }
  "$s" "$kw" 2>/dev/null | python3 -c '
import sys, json, re
out = []
for line in sys.stdin:
    m = re.match(r".*\[(\d+)\]\s+\*\*(.+?)\*\*\s+—\s+(.*)$", line)
    if m:
        out.append({"confidence": int(m.group(1)), "key": m.group(2), "insight": m.group(3)})
print(json.dumps(out[:5], ensure_ascii=False))
' 2>/dev/null || echo "[]"
}
```

- [ ] **Step 2: 冒烟测试**

Run:
```bash
bash -c '. scripts/lib/diagnose-lib.sh
echo "trace=[$(diagnose_trace "dummy")]"
echo "hist=[$(diagnose_phase_history brainstorming)]"
echo "lrn=[$(diagnose_similar_learnings test)]"'
```
Expected: 三行都打印（可能为空字符串/空 json），不崩。

- [ ] **Step 3: Commit**

```bash
git add scripts/lib/diagnose-lib.sh
git commit -m "feat(diagnose): add shared lib wrapping trace-analyzer/query-phase-metrics/search-learnings"
```

---

## Task 2: diagnose-failure.sh

**Files:**
- Create: `scripts/diagnose-failure.sh`
- Test: `tests/diagnose-scripts/test-diagnose-failure.sh`

- [ ] **Step 1: 写失败测试**

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-diag-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

echo "=== Diagnose Failure Tests ==="

# --- Test 1: type loop, outputs valid JSON ---
echo "--- Test 1: type loop ---"
setup
CTX='{"file":"spec.md","edits":3,"last_error":"schema-mismatch"}'
OUT=$("$PLUGIN_DIR/scripts/diagnose-failure.sh" --type loop --context "$CTX" --spec-topic t1 2>&1)
echo "$OUT" | grep -q '"failure_type": "loop"' && log_pass "loop type stamped" || log_fail "loop type missing"

# 找到产物文件
F=$(ls .agent-harness/diagnoses/*.json 2>/dev/null | head -1)
[ -n "$F" ] && log_pass "diagnosis file created" || log_fail "no diagnosis file"
[ -n "$F" ] && python3 -c "import json; json.load(open('$F'))" 2>/dev/null && log_pass "JSON valid" || log_fail "JSON invalid"

# --- Test 2: type gate, context from file ---
echo "--- Test 2: type gate from file ---"
setup
echo '{"phase":"writing-plans","validate_error":"missing field spec_ref"}' > ctx.json
"$PLUGIN_DIR/scripts/diagnose-failure.sh" --type gate --context ctx.json --spec-topic t2 2>&1 >/dev/null
F=$(ls .agent-harness/diagnoses/*.json 2>/dev/null | head -1)
echo "$F" | grep -q "gate" && log_pass "gate file named" || log_fail "gate file naming wrong"

# --- Test 3: graceful when all signals missing ---
echo "--- Test 3: empty warehouse ---"
setup
"$PLUGIN_DIR/scripts/diagnose-failure.sh" --type test --context '{"cmd":"pytest","exit_code":1}' 2>&1 >/dev/null
F=$(ls .agent-harness/diagnoses/*.json 2>/dev/null | head -1)
[ -n "$F" ] && python3 -c "
import json
d = json.load(open('$F'))
assert d['failure_type']=='test'
assert isinstance(d['evidence']['similar_learnings'], list)
print('OK')
" 2>/dev/null && log_pass "graceful empty" || log_fail "crashed on empty"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: 运行，FAIL**

Run: `bash tests/diagnose-scripts/test-diagnose-failure.sh`
Expected: FAIL（脚本不存在）。

- [ ] **Step 3: 实现 diagnose-failure.sh**

```bash
#!/usr/bin/env bash
# diagnose-failure.sh - Converge failure signals into a structured diagnosis JSON.
#
# Usage:
#   diagnose-failure.sh --type <loop|gate|test> --context <json-string|@file>
#                       [--spec-topic <t>] [--phase <name>]
#
# 产物：.agent-harness/diagnoses/<ts>-<type>-<slug>.json

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/diagnose-lib.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

TYPE=""; CONTEXT_RAW=""; SPEC_TOPIC=""; PHASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE="$2"; shift 2 ;;
    --context) CONTEXT_RAW="$2"; shift 2 ;;
    --spec-topic) SPEC_TOPIC="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$TYPE" ] && { echo "diagnose-failure: --type required" >&2; exit 0; }

# context 接受字符串或文件路径
CONTEXT=""
if [ -n "$CONTEXT_RAW" ]; then
  if [ -f "$CONTEXT_RAW" ]; then
    CONTEXT=$(cat "$CONTEXT_RAW")
  else
    CONTEXT="$CONTEXT_RAW"
  fi
fi

mkdir -p "$ROOT/.agent-harness/diagnoses"

TS=$(date -u +%Y%m%dT%H%M%SZ)
SLUG=$(printf '%s' "$SPEC_TOPIC$TYPE" | python3 -c 'import sys,re; print(re.sub(r"[^a-z0-9]+","-",sys.stdin.read().lower()).strip("-") or "x') 2>/dev/null || echo "x")
OUT="$ROOT/.agent-harness/diagnoses/${TS}-${TYPE}-${SLUG}.json"

# 推断 phase（gate/test 类型可从 context 提取）
[ -z "$PHASE" ] && PHASE=$(printf '%s' "$CONTEXT" | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin); print(d.get("phase",""))
except Exception: print("")' 2>/dev/null || true)

TRACE=$(diagnose_trace "$CONTEXT")
HIST="{}"
[ -n "$PHASE" ] && HIST=$(diagnose_phase_history "$PHASE" "$SPEC_TOPIC")
LEARN=$(diagnose_similar_learnings "${SPEC_TOPIC:-$TYPE}")

TS_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

TS_ISO="$TS_ISO" TYPE="$TYPE" SPEC_TOPIC="$SPEC_TOPIC" PHASE="$PHASE" \
CONTEXT="$CONTEXT" TRACE="$TRACE" HIST="$HIST" LEARN="$LEARN" \
OUT="$OUT" python3 <<'PY'
import json, os
ts = os.environ["TS_ISO"]
ftype = os.environ["TYPE"]
topic = os.environ["SPEC_TOPIC"]
phase = os.environ["PHASE"]
ctx_raw = os.environ["CONTEXT"]
try:
    ctx = json.loads(ctx_raw) if ctx_raw else {}
except Exception:
    ctx = {"raw": ctx_raw}

trace = os.environ["TRACE"]
try: hist = json.loads(os.environ["HIST"] or "{}")
except Exception: hist = {}
try: learn = json.loads(os.environ["LEARN"] or "[]")
except Exception: learn = []

summary_bits = []
if ftype == "loop":
    summary_bits.append(f"{ctx.get('edits','?')} 次编辑 {ctx.get('file','?')} 未收敛")
elif ftype == "gate":
    summary_bits.append(f"phase={phase} 门禁失败: {ctx.get('validate_error', ctx.get('last_error',''))}")
elif ftype == "test":
    summary_bits.append(f"测试/验证失败 exit={ctx.get('exit_code','?')}: {ctx.get('cmd', ctx.get('last_error',''))}")
summary = " | ".join(summary_bits) or "未知失败"

root_cause = ""
if "schema" in trace.lower() or "schema" in str(ctx).lower():
    root_cause = "frontmatter schema 与 spec #2 要求不匹配"
elif "gate" in trace.lower():
    root_cause = "门禁前置校验失败，需回到上一阶段"
elif not trace:
    root_cause = "信号不足，需人工根因分析"

fixes = []
if root_cause.startswith("frontmatter"):
    fixes.append({"action": "revisit-brainstorming", "rationale": "补全 frontmatter 必填字段"})
elif root_cause.startswith("门禁"):
    fixes.append({"action": "revisit-prior-phase", "rationale": "回到失败阶段的上游"})
if hist.get("failure_rate", 0) > 0.3:
    fixes.append({"action": "manual-intervention", "rationale": f"历史失败率 {hist.get('failure_rate')} 过高"})
if not fixes:
    fixes.append({"action": "manual-intervention", "rationale": "信号不足"})

out = {
    "ts": ts,
    "failure_type": ftype,
    "spec_topic": topic,
    "failure_summary": summary,
    "evidence": {
        "trace_classification": trace[:200] if trace else "",
        "phase_history": hist,
        "similar_learnings": learn,
    },
    "root_cause_hypothesis": root_cause,
    "suggested_fixes": fixes,
    "confidence": 7 if root_cause else 3,
}
with open(os.environ["OUT"], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print(os.environ["OUT"])
PY

echo "diagnosis written: $OUT" >&2
```

`chmod +x scripts/diagnose-failure.sh`。

- [ ] **Step 4: 运行测试，PASS**

Run: `bash tests/diagnose-scripts/test-diagnose-failure.sh`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/diagnose-failure.sh tests/diagnose-scripts/test-diagnose-failure.sh
git commit -m "feat(diagnose): add diagnose-failure.sh with 3-type tests"
```

---

## Task 3: write-diagnosis-task.sh

**Files:**
- Create: `scripts/write-diagnosis-task.sh`
- Test: `tests/diagnose-scripts/test-write-diagnosis-task.sh`

- [ ] **Step 1: 写失败测试**

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-wdt-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() { rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR"; cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"; }

echo "=== Write Diagnosis Task Tests ==="

# --- Test 1: append to existing plan ---
echo "--- Test 1: append to plan.md ---"
setup
mkdir -p docs/agent-harness/plans
cat > docs/agent-harness/plans/p.md <<EOF
# Plan
EOF
cat > diag.json <<'EOF'
{"ts":"2026-06-29T00:00:00Z","failure_type":"loop","spec_topic":"t1","failure_summary":"3 edits","evidence":{},"root_cause_hypothesis":"h","suggested_fixes":[{"action":"revisit-brainstorming","rationale":"r"}],"confidence":7}
EOF
"$PLUGIN_DIR/scripts/write-diagnosis-task.sh" --diagnosis diag.json --plan docs/agent-harness/plans/p.md
grep -q "Diagnosis" docs/agent-harness/plans/p.md && log_pass "appended to plan" || log_fail "not appended"
grep -q "revisit-brainstorming" docs/agent-harness/plans/p.md && log_pass "task action present" || log_fail "action missing"

# --- Test 2: standalone when no plan ---
echo "--- Test 2: standalone when no plan ---"
setup
"$PLUGIN_DIR/scripts/write-diagnosis-task.sh" --diagnosis diag.json 2>&1
F=$(ls docs/agent-harness/notes/diagnoses/*.md 2>/dev/null | head -1)
[ -n "$F" ] && log_pass "standalone created" || log_fail "no standalone file"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: 运行，FAIL**

Run: `bash tests/diagnose-scripts/test-write-diagnosis-task.sh`
Expected: FAIL。

- [ ] **Step 3: 实现 write-diagnosis-task.sh**

```bash
#!/usr/bin/env bash
# write-diagnosis-task.sh - Convert a diagnosis JSON into a markdown task.
#
# Usage: write-diagnosis-task.sh --diagnosis <json-file> [--plan <path>]
#
# 默认 --plan 缺省时：若当前目录存在 docs/agent-harness/plans/<最新>.md 则追加；
# 否则写独立文件到 docs/agent-harness/notes/diagnoses/<ts>-<type>.md。
# 不自动执行修复——只生成 task。

set -uo pipefail

DIAG=""; PLAN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --diagnosis) DIAG="$2"; shift 2 ;;
    --plan) PLAN="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$DIAG" ] && { echo "write-diagnosis-task: --diagnosis required" >&2; exit 1; }
[ ! -f "$DIAG" ] && { echo "write-diagnosis-task: file not found: $DIAG" >&2; exit 1; }

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# 若未指定 plan，尝试找最新 plan
if [ -z "$PLAN" ]; then
  LATEST=$(ls -t "$ROOT"/docs/agent-harness/plans/*.md 2>/dev/null | head -1 || true)
  PLAN="$LATEST"
fi

DIAG="$DIAG" PLAN="$PLAN" ROOT="$ROOT" python3 <<'PY'
import json, os, datetime
diag = json.load(open(os.environ["DIAG"], encoding="utf-8"))
plan = os.environ["PLAN"]
root = os.environ["ROOT"]

lines = ["", "## 🔧 Diagnosis Task (auto-generated)", ""]
lines.append(f"- **failure_type**: {diag.get('failure_type')}")
lines.append(f"- **spec_topic**: {diag.get('spec_topic','')}")
lines.append(f"- **summary**: {diag.get('failure_summary','')}")
lines.append(f"- **root_cause**: {diag.get('root_cause_hypothesis','')}")
lines.append(f"- **confidence**: {diag.get('confidence')}")
lines.append(f"- **ts**: {diag.get('ts')}")
lines.append("- **suggested fixes**:")
for fx in diag.get("suggested_fixes", []):
    lines.append(f"  - [ ] `{fx.get('action')}` — {fx.get('rationale')}")
lines.append("")

block = "\n".join(lines)

if plan and os.path.isfile(plan):
    with open(plan, "a", encoding="utf-8") as f:
        f.write(block + "\n")
    print(f"appended to {plan}")
else:
    out_dir = os.path.join(root, "docs/agent-harness/notes/diagnoses")
    os.makedirs(out_dir, exist_ok=True)
    ts = diag.get("ts", datetime.datetime.utcnow().isoformat()).replace(":", "").replace("-", "")[:15]
    ftype = diag.get("failure_type", "x")
    out = os.path.join(out_dir, f"{ts}-{ftype}.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write(f"# Diagnosis {ftype} @ {diag.get('ts')}\n")
        f.write(block + "\n")
    print(f"standalone: {out}")
PY
```

`chmod +x scripts/write-diagnosis-task.sh`。

- [ ] **Step 4: 运行测试，PASS**

Run: `bash tests/diagnose-scripts/test-write-diagnosis-task.sh`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/write-diagnosis-task.sh tests/diagnose-scripts/test-write-diagnosis-task.sh
git commit -m "feat(diagnose): add write-diagnosis-task.sh with append/standalone tests"
```

---

## Task 4: run-all.sh + .gitignore

**Files:**
- Create: `tests/diagnose-scripts/run-all.sh`
- Modify: `.gitignore`（加 `.agent-harness/diagnoses/`）

- [ ] **Step 1: 写 run-all.sh**

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; cd "$SCRIPT_DIR"
echo "=== Diagnose Scripts Suite ==="
bash test-diagnose-failure.sh; RC1=$?
bash test-write-diagnosis-task.sh; RC2=$?
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
  echo "✅ diagnose-scripts: all passed"; exit 0
else
  echo "❌ diagnose-scripts: failures ($RC1/$RC2)"; exit 1
fi
```

`chmod +x tests/diagnose-scripts/run-all.sh`。

- [ ] **Step 2: 加 .gitignore**

```
.agent-harness/diagnoses/
```

- [ ] **Step 3: Commit**

```bash
git add tests/diagnose-scripts/run-all.sh .gitignore
git commit -m "test(diagnose): add run-all.sh and gitignore rule for diagnoses/"
```

---

## Task 5: 集成 systematic-debugging skill

**Files:**
- Modify: `skills/systematic-debugging/SKILL.md`

- [ ] **Step 1: 读现状定位**

Run: `grep -n "root cause\|根因\|STOP\|fix" skills/systematic-debugging/SKILL.md | head`

- [ ] **Step 2: 在调试结束段加调用**

在 SKILL.md 的调试结束段（找到合适锚点）追加：

```markdown
- **沉淀诊断（不自动执行）**：调试结束时调用：
  ```bash
  scripts/diagnose-failure.sh --type test --context '<json>' --spec-topic "$SPEC_TOPIC"
  scripts/write-diagnosis-task.sh --diagnosis <上一步输出的 json 路径>
  ```
  目的：把「这次怎么修的」回写为 task，避免下次同类问题重复根因分析。诊断 JSON 路径在 stderr，便于脚本管道传递。
```

- [ ] **Step 3: 行为测试（可选）**

Run: `cd tests/skill-behavior/systematic-debugging && ./run-test.sh`
Expected: 现有断言不挂。

- [ ] **Step 4: Commit**

```bash
git add skills/systematic-debugging/SKILL.md
git commit -m "feat(diagnose): systematic-debugging emits diagnosis on completion"
```

---

## Task 6: 集成 loop-detection skill

**Files:**
- Modify: `skills/loop-detection/SKILL.md`

- [ ] **Step 1: 读现状**

Run: `grep -n "HARD STOP\|STOP" skills/loop-detection/SKILL.md | head`

- [ ] **Step 2: 在 HARD STOP 输出后加触发**

```markdown
- HARD STOP 触发时，除原警告外，额外调：
  ```bash
  scripts/diagnose-failure.sh --type loop --context '{"file":"<path>","edits":<n>}' --spec-topic "$SPEC_TOPIC"
  ```
  诊断报告路径在警告里告知用户，便于后续追溯。
```

- [ ] **Step 3: 回归**

Run: `./tests/plugin-infrastructure/run-all.sh`
Expected: 全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add skills/loop-detection/SKILL.md
git commit -m "feat(diagnose): loop-detection triggers diagnose-failure on HARD STOP"
```

---

## Task 7: 回归与成功标准

- [ ] **Step 1: 全套件回归**

```bash
./tests/plugin-infrastructure/run-all.sh
./tests/phase-metrics-scripts/run-all.sh
./tests/knowledge-base-scripts/run-all.sh
./tests/handoff-scripts/run-all.sh
./tests/diagnose-scripts/run-all.sh
```
Expected: 全部 PASS。

- [ ] **Step 2: 验收成功标准**

模拟一次完整失败链：

```bash
export CLAUDE_PROJECT_DIR=/tmp/diag-verify && mkdir -p $CLAUDE_PROJECT_DIR
cd $CLAUDE_PROJECT_DIR
# 模拟门禁失败 context
echo '{"phase":"writing-plans","validate_error":"missing spec_ref"}' > ctx.json
/path/to/repo/scripts/diagnose-failure.sh --type gate --context ctx.json --spec-topic t1
F=$(ls .agent-harness/diagnoses/*.json | head -1)
/path/to/repo/scripts/write-diagnosis-task.sh --diagnosis "$F"
```

预期：JSON 合法、suggested_fixes 非空、task 文件生成。

- [ ] **Step 3: 在 CLAUDE.md「常用命令」补一行**

```
- `tests/diagnose-scripts/run-all.sh` — 失败诊断脚本测试
```

- [ ] **Step 4: 更新 docs/agent-harness/index.md**

把 `notes/diagnoses/` 段加入子目录入口（或由 `index-knowledge-base.sh` 自动收录）。

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/agent-harness/
git commit -m "docs(diagnose): register test suite and notes/diagnoses/ in index"
```

---

## 边界提醒

- ❌ 不自动执行修复（只生成 task，人审决定）
- ❌ 不引入新检测机制（复用 loop-detector / phase-metrics / verification）
- ❌ 不做 UI 像素校准 / API debugger（业务栈特定）
- ❌ 不做跨项目诊断共享
- ✅ 诊断 JSON 与 phase-metrics 风格统一（小写、下划线、ts/spec_topic/confidence）
- ✅ 闭环可被人工打断（write-diagnosis-task 只写不执行）
