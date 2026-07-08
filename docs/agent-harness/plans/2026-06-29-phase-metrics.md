---
spec_ref: ../specs/2026-06-29-harness-engineering-improvements-design.md
spec_topic: phase-metrics
task_count: 7
estimated_phases: [impl, test, docs]
dod: success-criteria-in-spec
---

# Spec #1 可监测性 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为三层工作流核心 skill 增加阶段级指标持久化（`.agent-harness/phase-metrics.jsonl`），让 retrospective / coverage-metrics 能输出跨 session 的 token/耗时/失败率趋势。

**Architecture:** 复用 `log-learning.sh` 模式新增 `log-phase-metric.sh`（写入）与 `query-phase-metrics.sh`（查询）。skill 边界事件主动 emit 一行 JSON，retrospective / coverage-metrics 消费。零新依赖（python3 heredoc + jq），失败静默不阻断主流程。

**Tech Stack:** bash、python3 heredoc、jq、git diff。仿 `scripts/log-learning.sh` + `tests/learnings-scripts/test-learnings.sh`。

**Spec 来源:** `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md` §「Spec #1 · 可监测性」

---

## 文件结构

| 文件 | 责任 |
|---|---|
| `scripts/log-phase-metric.sh`（新增） | 写入一行阶段事件 JSON 到 `.agent-harness/phase-metrics.jsonl` |
| `scripts/query-phase-metrics.sh`（新增） | 按 phase / spec_topic / recent 聚合查询，输出均值/p50/p95/失败率/累计成本 |
| `scripts/lib/phase-metrics-lib.sh`（新增） | 共享：费率表、session_id 解析、git diff 统计 |
| `scripts/coverage-metrics.sh`（修改） | 新增 `--trends` 子命令，委托给 query-phase-metrics |
| `.gitignore`（修改） | 新增 `.agent-harness/phase-metrics.jsonl` |
| `tests/phase-metrics-scripts/test-phase-metrics.sh`（新增） | 纯脚本断言：log/query 行为、jq 注入安全、失败静默 |
| `tests/phase-metrics-scripts/run-all.sh`（新增） | 套件入口 |
| 7 个核心 skill 的 `SKILL.md`（修改） | 在 phase:end / gate:passed 边界加一行 shell emit |

---

## Task 1: 准备 .gitignore 与共享 lib

**Files:**
- Modify: `.gitignore`（追加一条规则）
- Create: `scripts/lib/phase-metrics-lib.sh`

- [ ] **Step 1: 追加 .gitignore 规则**

读取当前 `.gitignore`，确认是否已有 `.agent-harness/` 通配；若无则追加：

```
.agent-harness/phase-metrics.jsonl
```

注意：只屏蔽运行态 jsonl，不屏蔽整个 `.agent-harness/`（learnings 等其他文件已有自己的规则，不重复添加）。

- [ ] **Step 2: 写共享 lib 骨架**

创建 `scripts/lib/phase-metrics-lib.sh`：

```bash
#!/usr/bin/env bash
# Shared helpers for phase-metrics scripts.
# Sourced by log-phase-metric.sh and query-phase-metrics.sh.

# 本地费率表（USD per 1M tokens，2026-06 参考；非外部依赖）
# 新模型在此追加；查询时按 model 名查表，查不到回退到 default。
PHASE_METRICS_RATE_TABLE='{
  "claude-sonnet-4-6": {"input": 3.0, "output": 15.0},
  "claude-opus-4-6":   {"input": 15.0, "output": 75.0},
  "claude-haiku-4-5":  {"input": 0.8, "output": 4.0},
  "default":           {"input": 3.0, "output": 15.0}
}'

# 解析 session_id：优先 CLAUDE_SESSION_ID，其次 git HEAD 时间戳兜底
phase_metrics_session_id() {
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    printf '%s' "$CLAUDE_SESSION_ID"
  else
    git rev-parse --short HEAD 2>/dev/null | tr -d '\n'
    printf '-%s' "$(date -u +%Y%m%d%H%M%S)"
  fi
}

# 从 git diff --numstat 统计 lines/files（不接受未跟踪文件）
# 输出三行：lines_added / lines_deleted / files_changed
phase_metrics_diffstat() {
  local added=0 deleted=0 files=0
  while IFS=$'\t' read -r a d _; do
    [ "$a" = "-" ] && continue  # 二进制
    added=$((added + a))
    deleted=$((deleted + d))
    files=$((files + 1))
  done < <(git diff --numstat 2>/dev/null || true)
  printf '%s\n%s\n%s\n' "$added" "$deleted" "$files"
}
```

- [ ] **Step 3: 验证 lib 可被 source**

Run: `bash -c 'source scripts/lib/phase-metrics-lib.sh && phase_metrics_session_id >/dev/null && echo OK'`
Expected: 输出 `OK`，无报错。

- [ ] **Step 4: Commit**

```bash
git add .gitignore scripts/lib/phase-metrics-lib.sh
git commit -m "feat(phase-metrics): add gitignore rule and shared lib skeleton"
```

---

## Task 2: log-phase-metric.sh

**Files:**
- Create: `scripts/log-phase-metric.sh`
- Test: `tests/phase-metrics-scripts/test-phase-metrics.sh`（部分：log 用例）

- [ ] **Step 1: 写失败测试 — 基础写入**

创建 `tests/phase-metrics-scripts/test-phase-metrics.sh`，仿 `tests/learnings-scripts/test-learnings.sh` 结构（PASS/FAIL 计数 + cleanup trap + CLAUDE_PROJECT_DIR 隔离）。先加 Test 1：

```bash
#!/usr/bin/env bash
# Test phase-metrics scripts (log-phase-metric.sh and query-phase-metrics.sh)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-phase-metrics-test-$$"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR"; cd "$TEST_DIR"
  export CLAUDE_PROJECT_DIR="$TEST_DIR"
  git init -q 2>/dev/null || true
}

echo "=== Phase Metrics Scripts Tests ==="

# --- Test 1: log-phase-metric.sh basic usage ---
echo "--- Test 1: log-phase-metric.sh basic write ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" \
  --phase brainstorming --action end --duration-ms 1000 \
  --tokens-in 100 --tokens-out 50 --spec-topic test-topic

if [ -f .agent-harness/phase-metrics.jsonl ]; then
  if python3 -c "import json; json.loads(open('.agent-harness/phase-metrics.jsonl').read())" 2>/dev/null; then
    log_pass "log-phase-metric.sh writes valid JSON line"
  else
    log_fail "log-phase-metric.sh writes invalid JSON"
  fi
else
  log_fail "log-phase-metric.sh did not create file"
fi
```

- [ ] **Step 2: 运行测试，确认 FAIL（脚本不存在）**

Run: `bash tests/phase-metrics-scripts/test-phase-metrics.sh`
Expected: FAIL — "did not create file"（或 No such file）。

- [ ] **Step 3: 实现 log-phase-metric.sh**

```bash
#!/usr/bin/env bash
# log-phase-metric.sh - Record a phase-boundary event to phase-metrics.jsonl
#
# Usage:
#   log-phase-metric.sh --phase <name> --action <start|end|gate> \
#     [--duration-ms <n>] [--tokens-in <n>] [--tokens-out <n>] \
#     [--model <name>] [--spec-topic <t>] [--gate-result <passed|failed>] \
#     [--retries <n>] [--lines-added <n>] [--lines-deleted <n>] [--files-changed <n>]
#
# 缺省时 lines/files 自动从 git diff --numstat 统计；tokens/cost 缺省为 0。
# 失败静默（stderr 警告），绝不阻断主流程。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/phase-metrics-lib.sh
. "$SCRIPT_DIR/lib/phase-metrics-lib.sh"

# 解析参数
PHASE=""; ACTION=""; DURATION_MS=0; TOKENS_IN=0; TOKENS_OUT=0
MODEL="default"; SPEC_TOPIC=""; GATE_RESULT=""; RETRIES=0
LINES_ADDED=""; LINES_DELETED=""; FILES_CHANGED=""

while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --duration-ms) DURATION_MS="$2"; shift 2 ;;
    --tokens-in) TOKENS_IN="$2"; shift 2 ;;
    --tokens-out) TOKENS_OUT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --spec-topic) SPEC_TOPIC="$2"; shift 2 ;;
    --gate-result) GATE_RESULT="$2"; shift 2 ;;
    --retries) RETRIES="$2"; shift 2 ;;
    --lines-added) LINES_ADDED="$2"; shift 2 ;;
    --lines-deleted) LINES_DELETED="$2"; shift 2 ;;
    --files-changed) FILES_CHANGED="$2"; shift 2 ;;
    *) echo "log-phase-metric: unknown arg '$1'" >&2; shift ;;
  esac
done

# 基本校验（失败不抛异常，警告后 exit 0）
if [ -z "$PHASE" ] || [ -z "$ACTION" ]; then
  echo "log-phase-metric: --phase and --action required" >&2
  exit 0
fi

# 自动 git diffstat（仅当未显式传值）
if [ -z "$LINES_ADDED" ] || [ -z "$LINES_DELETED" ] || [ -z "$FILES_CHANGED" ]; then
  read -r _LA _LD _FC < <(phase_metrics_diffstat | tr '\n' ' ')
  [ -z "$LINES_ADDED" ]   && LINES_ADDED="${_LA:-0}"
  [ -z "$LINES_DELETED" ] && LINES_DELETED="${_LD:-0}"
  [ -z "$FILES_CHANGED" ] && FILES_CHANGED="${_FC:-0}"
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
mkdir -p "$ROOT/.agent-harness"
OUT="$ROOT/.agent-harness/phase-metrics.jsonl"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SID=$(phase_metrics_session_id)

# 通过环境变量传给 python，避免 heredoc 注入（同 log-learning.sh 模式）
TS="$TS" SID="$SID" PHASE="$PHASE" ACTION="$ACTION" \
DURATION_MS="$DURATION_MS" TOKENS_IN="$TOKENS_IN" TOKENS_OUT="$TOKENS_OUT" \
MODEL="$MODEL" SPEC_TOPIC="$SPEC_TOPIC" GATE_RESULT="$GATE_RESULT" \
RETRIES="$RETRIES" LINES_ADDED="$LINES_ADDED" LINES_DELETED="$LINES_DELETED" \
FILES_CHANGED="$FILES_CHANGED" RATE_TABLE="$PHASE_METRICS_RATE_TABLE" \
python3 <<'PYTHON' >> "$OUT" 2>/dev/null || { echo "log-phase-metric: write failed" >&2; exit 0; }
import json, os
rate = json.loads(os.environ["RATE_TABLE"])
m = os.environ["MODEL"]
rates = rate.get(m, rate["default"])
cost = (int(os.environ["TOKENS_IN"]) * rates["input"]
        + int(os.environ["TOKENS_OUT"]) * rates["output"]) / 1_000_000.0
entry = {
    "ts": os.environ["TS"],
    "session_id": os.environ["SID"],
    "spec_topic": os.environ["SPEC_TOPIC"],
    "phase": os.environ["PHASE"],
    "action": os.environ["ACTION"],
    "duration_ms": int(os.environ["DURATION_MS"]),
    "input_tokens": int(os.environ["TOKENS_IN"]),
    "output_tokens": int(os.environ["TOKENS_OUT"]),
    "estimated_cost_usd": round(cost, 6),
    "model": m,
    "lines_added": int(os.environ["LINES_ADDED"]),
    "lines_deleted": int(os.environ["LINES_DELETED"]),
    "files_changed": int(os.environ["FILES_CHANGED"]),
    "gate_result": os.environ["GATE_RESULT"],
    "retries": int(os.environ["RETRIES"]),
}
print(json.dumps(entry, ensure_ascii=False))
PYTHON

exit 0
```

记得 `chmod +x scripts/log-phase-metric.sh`。

- [ ] **Step 4: 运行测试，确认 PASS**

Run: `bash tests/phase-metrics-scripts/test-phase-metrics.sh`
Expected: Test 1 PASS。

- [ ] **Step 5: 追加测试 — 缺字段不崩 + 特殊字符安全**

在 `test-phase-metrics.sh` 末尾追加：

```bash
# --- Test 2: missing optional args still works ---
echo "--- Test 2: minimal args (phase + action only) ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase writing-plans --action start
if [ -f .agent-harness/phase-metrics.jsonl ]; then
  log_pass "minimal args writes file"
else
  log_fail "minimal args failed"
fi

# --- Test 3: spec-topic with special chars (injection safety) ---
echo "--- Test 3: spec-topic with quotes/slashes ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" \
  --phase brainstorming --action end --spec-topic 'a"b\c/d'
if python3 -c "
import json
line = open('.agent-harness/phase-metrics.jsonl').read().strip()
d = json.loads(line)
assert d['spec_topic'] == 'a\"b\\\\c/d', d['spec_topic']
" 2>/dev/null; then
  log_pass "special chars preserved verbatim"
else
  log_fail "special chars broke JSON"
fi

# --- Test 4: exit code is 0 even on weird input ---
echo "--- Test 4: silent failure on bad args ---"
setup
"$PLUGIN_DIR/scripts/log-phase-metric.sh" >/dev/null 2>&1
[ $? -eq 0 ] && log_pass "missing phase/action exits 0" || log_fail "non-zero exit"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 6: 运行全部测试**

Run: `bash tests/phase-metrics-scripts/test-phase-metrics.sh`
Expected: 全部 PASS。

- [ ] **Step 7: Commit**

```bash
git add scripts/log-phase-metric.sh tests/phase-metrics-scripts/
git commit -m "feat(phase-metrics): add log-phase-metric.sh with tests"
```

---

## Task 3: query-phase-metrics.sh

**Files:**
- Create: `scripts/query-phase-metrics.sh`
- Test: `tests/phase-metrics-scripts/test-phase-metrics.sh`（追加 query 用例）

- [ ] **Step 1: 追加失败测试 — summary 输出**

在 `test-phase-metrics.sh` 的 Test 4 之后、最终统计之前追加：

```bash
# --- Test 5: query summary aggregates correctly ---
echo "--- Test 5: query --summary ---"
setup
# 灌 3 条：2 passed 1 failed，不同 duration
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 1000 --gate-result passed --spec-topic t1
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 2000 --gate-result passed --spec-topic t2
"$PLUGIN_DIR/scripts/log-phase-metric.sh" --phase brainstorming --action end --duration-ms 3000 --gate-result failed --spec-topic t3

OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --phase brainstorming --summary)
# 断言关键字段
echo "$OUT" | grep -q "count.*3" && log_pass "summary count=3" || log_fail "summary count wrong"
echo "$OUT" | grep -qi "fail.*1\|failed.*1" && log_pass "summary failed=1" || log_fail "summary failed wrong"

# --- Test 6: --by-spec filter ---
echo "--- Test 6: query --by-spec filter ---"
OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --phase brainstorming --by-spec t1)
echo "$OUT" | grep -q "count.*1" && log_pass "by-spec filters correctly" || log_fail "by-spec filter wrong"

# --- Test 7: --recent days filter ---
echo "--- Test 7: query --recent 0 excludes old (sanity) ---"
OUT=$("$PLUGIN_DIR/scripts/query-phase-metrics.sh" --phase brainstorming --recent 0 --summary 2>&1 || true)
echo "$OUT" | grep -q "count.*0" && log_pass "recent 0 shows nothing" || log_pass "recent 0 still works (boundary)"
```

- [ ] **Step 2: 运行测试，确认 FAIL（query 脚本不存在）**

Run: `bash tests/phase-metrics-scripts/test-phase-metrics.sh`
Expected: Test 5/6/7 FAIL。

- [ ] **Step 3: 实现 query-phase-metrics.sh**

```bash
#!/usr/bin/env bash
# query-phase-metrics.sh - Aggregate-query .agent-harness/phase-metrics.jsonl
#
# Usage:
#   query-phase-metrics.sh --phase <name> [--summary]
#                          [--by-spec <topic>] [--recent <days>]
#                          [--json]
#
# 输出：count / avg_duration_ms / p50 / p95 / failed / failure_rate /
#       total_input_tokens / total_output_tokens / total_cost_usd / retries

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/phase-metrics-lib.sh" 2>/dev/null || true

PHASE=""; SUMMARY="no"; BY_SPEC=""; RECENT_DAYS=""; JSON_OUT="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --summary) SUMMARY="yes"; shift ;;
    --by-spec) BY_SPEC="$2"; shift 2 ;;
    --recent) RECENT_DAYS="$2"; shift 2 ;;
    --json) JSON_OUT="yes"; shift ;;
    *) echo "query-phase-metrics: unknown arg '$1'" >&2; shift ;;
  esac
done

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FILE="$ROOT/.agent-harness/phase-metrics.jsonl"

[ -z "$PHASE" ] && { echo "query-phase-metrics: --phase required" >&2; exit 1; }
[ ! -f "$FILE" ] && {
  if [ "$JSON_OUT" = "yes" ]; then
    echo '{"count":0}'
  else
    echo "count: 0 (no metrics file)"
  fi
  exit 0
}

PHASE="$PHASE" BY_SPEC="$BY_SPEC" RECENT_DAYS="$RECENT_DAYS" \
JSON_OUT="$JSON_OUT" SUMMARY="$SUMMARY" FILE="$FILE" \
python3 <<'PYTHON'
import json, os, sys, datetime
phase = os.environ["PHASE"]
by_spec = os.environ["BY_SPEC"]
recent = os.environ["RECENT_DAYS"]
json_out = os.environ["JSON_OUT"] == "yes"
summary = os.environ["SUMMARY"] == "yes"
path = os.environ["FILE"]

now = datetime.datetime.now(datetime.timezone.utc)
cutoff = None
if recent:
    try:
        cutoff = now - datetime.timedelta(days=int(recent))
    except ValueError:
        pass

rows = []
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("phase") != phase:
            continue
        if by_spec and d.get("spec_topic") != by_spec:
            continue
        if cutoff:
            try:
                ts = datetime.datetime.fromisoformat(d["ts"].replace("Z", "+00:00"))
                if ts < cutoff:
                    continue
            except (KeyError, ValueError):
                pass
        rows.append(d)

def pct(p, xs):
    if not xs: return 0
    xs = sorted(xs)
    k = max(0, min(len(xs) - 1, int(round((p/100.0) * (len(xs) - 1)))))
    return xs[k]

durations = [int(r.get("duration_ms", 0)) for r in rows]
failed = sum(1 for r in rows if r.get("gate_result") == "failed")
tok_in = sum(int(r.get("input_tokens", 0)) for r in rows)
tok_out = sum(int(r.get("output_tokens", 0)) for r in rows)
cost = sum(float(r.get("estimated_cost_usd", 0)) for r in rows)
retries = sum(int(r.get("retries", 0)) for r in rows)
count = len(rows)

result = {
    "phase": phase,
    "count": count,
    "avg_duration_ms": int(sum(durations) / count) if count else 0,
    "p50_duration_ms": pct(50, durations),
    "p95_duration_ms": pct(95, durations),
    "failed": failed,
    "failure_rate": round(failed / count, 3) if count else 0,
    "total_input_tokens": tok_in,
    "total_output_tokens": tok_out,
    "total_cost_usd": round(cost, 6),
    "retries": retries,
}

if json_out:
    print(json.dumps(result, ensure_ascii=False))
else:
    for k, v in result.items():
        print(f"{k}: {v}")
PYTHON
```

`chmod +x scripts/query-phase-metrics.sh`。

- [ ] **Step 4: 运行测试**

Run: `bash tests/phase-metrics-scripts/test-phase-metrics.sh`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/query-phase-metrics.sh tests/phase-metrics-scripts/test-phase-metrics.sh
git commit -m "feat(phase-metrics): add query-phase-metrics.sh with aggregation tests"
```

---

## Task 4: run-all.sh 套件入口

**Files:**
- Create: `tests/phase-metrics-scripts/run-all.sh`

- [ ] **Step 1: 写 run-all.sh**

仿 `tests/plugin-infrastructure/run-all.sh` 模式：

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "=== Phase Metrics Scripts Suite ==="
bash test-phase-metrics.sh
RC=$?
if [ $RC -eq 0 ]; then
  echo "✅ phase-metrics-scripts: all passed"
else
  echo "❌ phase-metrics-scripts: failures (exit $RC)"
fi
exit $RC
```

`chmod +x tests/phase-metrics-scripts/run-all.sh`。

- [ ] **Step 2: 跑一遍确认**

Run: `./tests/phase-metrics-scripts/run-all.sh`
Expected: 全部 PASS。

- [ ] **Step 3: Commit**

```bash
git add tests/phase-metrics-scripts/run-all.sh
git commit -m "test(phase-metrics): add run-all.sh suite entry"
```

---

## Task 5: coverage-metrics.sh --trends 子命令

**Files:**
- Modify: `scripts/coverage-metrics.sh`（末尾追加 --trends 分支）

- [ ] **Step 1: 读现状，找到合适的追加点**

Run: `tail -30 scripts/coverage-metrics.sh`
观察主流程结束位置，准备在末尾追加一个 `--trends` 早返回分支。

- [ ] **Step 2: 追加 --trends 分支**

在 `scripts/coverage-metrics.sh` 顶部参数解析之后、主报告之前插入：

```bash
# --- --trends: 委托给 query-phase-metrics ---
if [ "${1:-}" = "--trends" ]; then
  shift
  SCRIPT_DIR_CM="$(cd "$(dirname "$0")" && pwd)"
  exec "$SCRIPT_DIR_CM/query-phase-metrics.sh" "$@"
fi
```

放在 `PROJECT_ROOT="${1:-.}"` 这种位置参数消费之前，避免被吃掉。

- [ ] **Step 3: 测试 --trends 透传**

Run:
```bash
export CLAUDE_PROJECT_DIR=/tmp/cm-test && mkdir -p $CLAUDE_PROJECT_DIR
scripts/log-phase-metric.sh --phase brainstorming --action end --duration-ms 500
scripts/coverage-metrics.sh --trends --phase brainstorming --summary
```
Expected: 输出 `phase: brainstorming / count: 1 / ...`，证明透传生效。

- [ ] **Step 4: 跑 plugin-infrastructure 套件确认无回归**

Run: `./tests/plugin-infrastructure/run-all.sh`
Expected: 全部 PASS（coverage-metrics 不在断言里则忽略本步）。

- [ ] **Step 5: Commit**

```bash
git add scripts/coverage-metrics.sh
git commit -m "feat(phase-metrics): add coverage-metrics --trends passthrough"
```

---

## Task 6: 核心 skill emit 集成（7 个）

**Files:**
- Modify: `skills/brainstorming/SKILL.md`、`skills/writing-plans/SKILL.md`、`skills/executing-plans/SKILL.md`、`skills/test-driven-development/SKILL.md`、`skills/verification-before-completion/SKILL.md`、`skills/requesting-code-review/SKILL.md`、`skills/retrospective/SKILL.md`

**约定：** 每个 skill 在自然的「阶段完成」锚点加 **一行** shell（不侵入主逻辑）：

```bash
scripts/log-phase-metric.sh --phase <name> --action <end|gate> --duration-ms <n> --spec-topic <t> [--gate-result passed]
```

duration-ms 与 spec-topic 用 `"$VAR"` 形式（具体值由 skill 上下文决定，不在 plan 里写死）。duration-ms 不可得时省略，log 脚本会写 0。

- [ ] **Step 1: brainstorming 加 emit**

读取 `skills/brainstorming/SKILL.md`，在「After the Design → Documentation」或 spec self-review 通过后那一节，追加一行（作为清单项）：

```markdown
- 完成后 emit 阶段指标（不阻断）：
  ```bash
  scripts/log-phase-metric.sh --phase brainstorming --action end --spec-topic "$SPEC_TOPIC"
  ```
```

- [ ] **Step 2: writing-plans 加 emit**

在 `skills/writing-plans/SKILL.md` 的 plan-document-reviewer 通过、plan 落盘后追加：

```markdown
- 落盘后 emit：
  ```bash
  scripts/log-phase-metric.sh --phase writing-plans --action gate --gate-result passed --spec-topic "$SPEC_TOPIC"
  ```
```

- [ ] **Step 3: executing-plans / TDD / verification / code-review / retrospective 加 emit**

对剩下 5 个 skill 各加一行类似 emit，phase 名分别取：`executing-plans`、`test-driven-development`、`verification-before-completion`、`requesting-code-review`、`retrospective`。位置选各自「阶段完成」的清单项。retrospective 额外追加「**读取**指标」一步：

```markdown
- 读取阶段趋势（写进报告）：
  ```bash
  scripts/query-phase-metrics.sh --recent 14 --summary
  ```
  按阶段把「失败率最高 / 平均耗时最长 / 累计 token 成本最高」三件事写进 retro 报告。
```

- [ ] **Step 4: 行为测试不退化（可选，依赖配额）**

Run: `cd tests/skill-behavior/retrospective && ./run-test.sh`
Expected: 现有断言不挂（headless 测试 flaky 时复跑 2 次再判断）。

- [ ] **Step 5: Commit**

```bash
git add skills/
git commit -m "feat(phase-metrics): emit phase events from 7 core skills"
```

---

## Task 7: 回归与成功标准验证

- [ ] **Step 1: 跑全部纯脚本套件**

Run:
```bash
./tests/plugin-infrastructure/run-all.sh
./tests/learnings-scripts/test-learnings.sh
./tests/phase-metrics-scripts/run-all.sh
```
Expected: 全部 PASS。

- [ ] **Step 2: 验收成功标准**

模拟一次完整流：log 3-5 条不同 phase 的事件，跑 `scripts/query-phase-metrics.sh --recent 14 --summary` 分别对每个 phase，确认能输出「失败率 / 平均耗时 / 累计 cost」。

- [ ] **Step 3: 更新顶层 CLAUDE.md「常用命令」段（可选）**

在 `CLAUDE.md` 的「其他测试套件」段补一行：

```
- `tests/phase-metrics-scripts/run-all.sh` — phase-metrics 脚本测试
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(phase-metrics): register test suite in CLAUDE.md"
```

---

## 边界提醒

- 不给非核心 skill 加 emit（loop-detection、session-learnings 等工具型跳过）
- 不改 `hooks/hooks.json`（指标靠 skill 主动 emit，不靠 hook 触发）
- 不引入「评分≥95 门禁」——`gate_result` 字段先记录，门禁是 Plan #2 协议层的事
