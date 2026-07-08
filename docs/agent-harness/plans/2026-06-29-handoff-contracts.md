---
spec_ref: ../specs/2026-06-29-harness-engineering-improvements-design.md
spec_topic: handoff-contracts
task_count: 7
estimated_phases: [impl, test, docs]
dod: success-criteria-in-spec
---

# Spec #2 协议层契约 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task.

**Goal:** 在 brainstorming → writing-plans → executing-plans 三个关键交接点加 YAML frontmatter schema 与 `validate-handoff.sh` 硬前置校验。结构错必退回，不浪费 reviewer 子代理 token。

**Architecture:** 在 spec.md / plan.md / task 三类文档顶部加 YAML frontmatter（与 SKILL.md 风格一致）。新增 `validate-handoff.sh` 用 yq（缺则 sed fallback）做结构校验。与现有 spec-document-reviewer / plan-document-reviewer 子代理**并行不替代**：结构前置（shell 秒级），语义后置（子代理）。

**Tech Stack:** bash、yq（可 sed fallback）、python3 heredoc。零新依赖。

**Spec 来源:** `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md` §「Spec #2 · 协议层契约」

**依赖关系:** 依赖 Plan #1（log-phase-metric 的 gate_result 信号）+ Plan #3（index.md 提供 spec_topic 锚点校验）。

---

## 文件结构

| 文件 | 责任 |
|---|---|
| `scripts/lib/handoff-schema.sh`（新增） | 三个 stage 的 schema 定义（必填字段、类型、ref 校验） |
| `scripts/validate-handoff.sh`（新增） | 入口：`--stage <spec\|plan\|task> --file <path>` |
| `scripts/lib/yaml-parse.sh`（新增） | yq 优先 / sed fallback 的极简 YAML frontmatter 解析 |
| `skills/brainstorming/SKILL.md`（修改） | 写完 spec 后强制跑 validate-handoff |
| `skills/writing-plans/SKILL.md`（修改） | 写完 plan 后强制跑 validate-handoff |
| `skills/executing-plans/SKILL.md`（修改） | 任务完成时跑 validate-handoff --stage task |
| `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md`（修改） | 补 frontmatter 样例 |
| `tests/handoff-scripts/test-validate-handoff.sh`（新增） | 各 stage 缺字段 / ref 失效 / 合法通过 |
| `tests/handoff-scripts/run-all.sh`（新增） | 套件入口 |

---

## Task 1: yaml-parse lib

**Files:**
- Create: `scripts/lib/yaml-parse.sh`

- [ ] **Step 1: 写 lib**

```bash
#!/usr/bin/env bash
# Minimal YAML frontmatter parser: yq preferred, sed fallback.
#
# 用法（source 后）：
#   yaml_parse_load <file>      # 把 frontmatter 加载到全局关联数组 YAML_FM
#   yaml_parse_get <key>        # 打印某个字段值（无则空字符串）
#
# 仅支持扁平 key: value 与 key: [a, b, c] 列表；不支持嵌套。
# 复杂 schema 请手动结构化（本项目的 frontmatter 都保持扁平）。

declare -gA YAML_FM=()

yaml_parse_load() {
  local file="$1"
  YAML_FM=()
  [ ! -f "$file" ] && return 1

  # 提取首对 --- ... --- 之间的内容
  local body
  body=$(awk '
    /^---[[:space:]]*$/ { c++; next }
    c == 1 { print }
    c >= 2 { exit }
  ' "$file" 2>/dev/null || true)
  [ -z "$body" ] && return 1

  if command -v yq >/dev/null 2>&1; then
    # yq 路径：把每行 key 输出为 KEY=VALUE
    while IFS='=' read -r k v; do
      [ -n "$k" ] && YAML_FM["$k"]="$v"
    done < <(printf '%s\n' "$body" | yq -o=props '.' 2>/dev/null || true)
  else
    # sed/awk fallback：扁平 key: value
    while IFS= read -r line; do
      line="${line%%#*}"  # 去行尾注释
      case "$line" in
        *:[[:space:]]*)
          local k="${line%%:*}"
          local v="${line#*:}"
          k="${k// /}"
          v="${v#"${v%%[![:space:]]*}"}"  # 去前导空格
          # 列表值 [a, b] → 保留原样
          YAML_FM["$k"]="$v"
          ;;
      esac
    done <<< "$body"
  fi
  return 0
}

yaml_parse_get() {
  printf '%s' "${YAML_FM[$1]:-}"
}
```

- [ ] **Step 2: 冒烟测试**

Run:
```bash
bash -c '
. scripts/lib/yaml-parse.sh
cat > /tmp/t.md <<EOF
---
spec_topic: foo
design_approved: true
gates: [a, b]
---
body
EOF
yaml_parse_load /tmp/t.md
echo "topic=[$(yaml_parse_get spec_topic)] approved=[$(yaml_parse_get design_approved)] gates=[$(yaml_parse_get gates)]"
'
```
Expected: 输出 `topic=[foo] approved=[true] gates=[[a, b]]`。

- [ ] **Step 3: Commit**

```bash
git add scripts/lib/yaml-parse.sh
git commit -m "feat(handoff): add yaml-parse lib with yq+sed fallback"
```

---

## Task 2: handoff-schema 定义

**Files:**
- Create: `scripts/lib/handoff-schema.sh`

- [ ] **Step 1: 写 schema lib**

```bash
#!/usr/bin/env bash
# handoff-schema.sh - 必填字段 + ref 校验规则
#
# 各 stage 的必填字段；校验函数返回 0 通过 / 1 失败（stderr 打印原因）。

# spec stage 必填字段
HANDOFF_SPEC_FIELDS="spec_topic decision_summary design_approved user_approved_at"
# plan stage 必填字段
HANDOFF_PLAN_FIELDS="spec_ref task_count estimated_phases dod"
# task stage 必填字段
HANDOFF_TASK_FIELDS="plan_ref implemented_tasks tests_passed evidence_paths"

# handoff_check_required <stage> <file>
# 用已加载的 YAML_FM 校验
handoff_check_required() {
  local stage="$1" file="$2"
  local fields=""
  case "$stage" in
    spec) fields="$HANDOFF_SPEC_FIELDS" ;;
    plan) fields="$HANDOFF_PLAN_FIELDS" ;;
    task) fields="$HANDOFF_TASK_FIELDS" ;;
    *) echo "validate-handoff: unknown stage '$stage'" >&2; return 1 ;;
  esac
  local rc=0
  for f in $fields; do
    local v; v=$(yaml_parse_get "$f")
    if [ -z "$v" ]; then
      echo "validate-handoff: $file missing required field '$f'" >&2
      rc=1
    fi
  done
  # ref 校验：plan.spec_ref / task.plan_ref 必须指向存在的文件
  case "$stage" in
    plan)
      local ref; ref=$(yaml_parse_get "spec_ref")
      if [ -n "$ref" ]; then
        local dir; dir="$(dirname "$file")"
        # 相对 docs/agent-harness/plans/ 解析到 specs/
        local target="$dir/../$ref"
        [ -f "$target" ] || { echo "validate-handoff: spec_ref '$ref' not found ($target)" >&2; rc=1; }
      fi
      ;;
    task)
      local ref; ref=$(yaml_parse_get "plan_ref")
      if [ -n "$ref" ]; then
        local dir; dir="$(dirname "$file")"
        local target="$dir/$ref"
        [ -f "$target" ] || { echo "validate-handoff: plan_ref '$ref' not found" >&2; rc=1; }
      fi
      ;;
  esac
  # spec_topic 与知识库 index.md 咬合（仅 spec/plan stage）
  if [ "$stage" = "spec" ] || [ "$stage" = "plan" ]; then
    local topic; topic=$(yaml_parse_get "spec_topic")
    if [ -n "$topic" ]; then
      local idx="$ROOT/docs/agent-harness/index.md"
      if [ -f "$idx" ] && ! grep -q "$topic" "$idx" 2>/dev/null; then
        echo "validate-handoff: spec_topic '$topic' not found in docs/agent-harness/index.md" >&2
        rc=1
      fi
    fi
  fi
  return $rc
}
```

注意：`$ROOT` 由调用方（validate-handoff.sh）export。

- [ ] **Step 2: Commit**

```bash
git add scripts/lib/handoff-schema.sh
git commit -m "feat(handoff): add schema definitions for spec/plan/task stages"
```

---

## Task 3: validate-handoff.sh 入口

**Files:**
- Create: `scripts/validate-handoff.sh`
- Test: `tests/handoff-scripts/test-validate-handoff.sh`

- [ ] **Step 1: 写失败测试**

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-handoff-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR/docs/agent-harness/specs"
  cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

echo "=== Validate Handoff Tests ==="

# --- Test 1: valid spec passes ---
echo "--- Test 1: valid spec frontmatter ---"
setup
# 先在 index.md 注册 topic
mkdir -p docs/agent-harness
cat > docs/agent-harness/index.md <<EOF
- good-topic → specs/x.md
EOF
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: good-topic
decision_summary: "做了 A 决定"
design_approved: true
user_approved_at: 2026-06-29T10:00:00Z
gates: [review]
---
# 内容
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md
[ $? -eq 0 ] && log_pass "valid spec passes" || log_fail "valid spec rejected"

# --- Test 2: missing field fails ---
echo "--- Test 2: missing field fails ---"
setup
mkdir -p docs/agent-harness
cat > docs/agent-harness/index.md <<EOF
- good-topic → specs/x.md
EOF
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: good-topic
decision_summary: "x"
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md 2>/dev/null
[ $? -ne 0 ] && log_pass "missing field rejected" || log_fail "missing field accepted"

# --- Test 3: plan spec_ref not found ---
echo "--- Test 3: plan spec_ref broken ---"
setup
mkdir -p docs/agent-harness/plans docs/agent-harness/specs
cat > docs/agent-harness/index.md <<EOF
- t1 → specs/s.md
EOF
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: t1
EOF
cat > docs/agent-harness/plans/p.md <<'EOF'
---
spec_ref: ../specs/missing.md
spec_topic: t1
task_count: 3
estimated_phases: [impl]
dod: contract-x
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage plan --file docs/agent-harness/plans/p.md 2>/dev/null
[ $? -ne 0 ] && log_pass "broken spec_ref rejected" || log_fail "broken spec_ref accepted"

# --- Test 4: spec_topic not in index ---
echo "--- Test 4: topic not registered ---"
setup
mkdir -p docs/agent-harness/specs
echo "- other → x" > docs/agent-harness/index.md
cat > docs/agent-harness/specs/s.md <<'EOF'
---
spec_topic: unregistered
decision_summary: x
design_approved: true
user_approved_at: 2026-06-29T10:00:00Z
gates: []
---
EOF
"$PLUGIN_DIR/scripts/validate-handoff.sh" --stage spec --file docs/agent-harness/specs/s.md 2>/dev/null
[ $? -ne 0 ] && log_pass "unregistered topic rejected" || log_fail "unregistered topic accepted"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: 运行，FAIL**

Run: `bash tests/handoff-scripts/test-validate-handoff.sh`
Expected: FAIL（脚本不存在）。

- [ ] **Step 3: 实现 validate-handoff.sh**

```bash
#!/usr/bin/env bash
# validate-handoff.sh - Structural validation of handoff frontmatter.
#
# Usage: validate-handoff.sh --stage <spec|plan|task> --file <path>
#
# 退出码：0 通过（stdout 一行摘要）/ 1 失败（stderr 列出所有问题）。
# 不调用子代理；语义审稿仍由 spec-document-reviewer / plan-document-reviewer 负责。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/yaml-parse.sh"
. "$SCRIPT_DIR/lib/handoff-schema.sh"

export ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

STAGE=""; FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    *) echo "validate-handoff: unknown arg '$1'" >&2; shift ;;
  esac
done

[ -z "$STAGE" ] || [ -z "$FILE" ] && { echo "usage: $0 --stage <spec|plan|task> --file <path>" >&2; exit 1; }
[ ! -f "$FILE" ] && { echo "validate-handoff: file not found: $FILE" >&2; exit 1; }

yaml_parse_load "$FILE" || { echo "validate-handoff: no frontmatter in $FILE" >&2; exit 1; }

if handoff_check_required "$STAGE" "$FILE"; then
  echo "OK $STAGE $(basename "$FILE")"
  exit 0
else
  exit 1
fi
```

`chmod +x scripts/validate-handoff.sh`。

- [ ] **Step 4: 运行测试，PASS**

Run: `bash tests/handoff-scripts/test-validate-handoff.sh`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-handoff.sh tests/handoff-scripts/test-validate-handoff.sh
git commit -m "feat(handoff): add validate-handoff.sh with stage-specific schema tests"
```

---

## Task 4: run-all.sh

**Files:**
- Create: `tests/handoff-scripts/run-all.sh`

- [ ] **Step 1: 写入口**

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "=== Handoff Scripts Suite ==="
bash test-validate-handoff.sh; RC=$?
[ $RC -eq 0 ] && echo "✅ handoff-scripts: all passed" || echo "❌ handoff-scripts: failures ($RC)"
exit $RC
```

`chmod +x tests/handoff-scripts/run-all.sh`。

- [ ] **Step 2: Commit**

```bash
git add tests/handoff-scripts/run-all.sh
git commit -m "test(handoff): add run-all.sh suite entry"
```

---

## Task 5: 给现有 spec 文档补 frontmatter

**Files:**
- Modify: `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md`
- Modify: 对应的 4 份 plan 文件（加 plan frontmatter）

- [ ] **Step 1: 给主 spec 加 frontmatter**

在文件最顶部插入：

```yaml
---
spec_topic: harness-engineering-improvements
decision_summary: "把参考文章方法论翻译成 agent-harness 文件式架构；4 个 spec 覆盖可监测性/协议层/知识库/失败自愈，零新依赖。"
design_approved: true
user_approved_at: 2026-06-29T00:00:00Z
gates: [user-review-passed]
---
```

并把 `harness-engineering-improvements` 加入 `docs/agent-harness/index.md` 主题速查段（Task 1 已加）。

- [ ] **Step 2: 给 4 份 plan 加 frontmatter**

每个 plan 文件顶部加（替换各自字段）：

```yaml
---
spec_ref: ../specs/2026-06-29-harness-engineering-improvements-design.md
spec_topic: phase-metrics      # 或 knowledge-base / handoff-contracts / failure-diagnosis
task_count: 7
estimated_phases: [impl, test, docs]
dod: success-criteria-in-spec
---
```

- [ ] **Step 3: 跑 validate-handoff 校验**

```bash
scripts/validate-handoff.sh --stage spec --file docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md
for p in phase-metrics knowledge-base handoff-contracts failure-diagnosis; do
  scripts/validate-handoff.sh --stage plan --file docs/agent-harness/plans/2026-06-29-$p.md
done
```
Expected: 全部 `OK ...`。

- [ ] **Step 4: Commit**

```bash
git add docs/agent-harness/
git commit -m "feat(handoff): add frontmatter to current spec and plans"
```

---

## Task 6: skill 集成（强制跑 validate-handoff）

**Files:**
- Modify: `skills/brainstorming/SKILL.md`、`skills/writing-plans/SKILL.md`、`skills/executing-plans/SKILL.md`

- [ ] **Step 1: brainstorming 加硬前置**

在「After the Design → Documentation」段（spec 文档写完之后、spec self-review 之前）插入：

```markdown
- **结构前置校验（硬门禁）**：写完 spec 文档后立即跑：
  ```bash
  scripts/validate-handoff.sh --stage spec --file <spec-path>
  ```
  退出码非 0 时，回到「Documentation」步骤补全 frontmatter，**不得**进入 spec self-review。
```

- [ ] **Step 2: writing-plans 加硬前置**

在 plan-document-reviewer 调用之前插入：

```markdown
- **结构前置校验（硬门禁）**：
  ```bash
  scripts/validate-handoff.sh --stage plan --file <plan-path>
  ```
  失败则回到 plan 写作步骤。通过后再交 plan-document-reviewer 做语义审稿。
```

- [ ] **Step 3: executing-plans 加 task 校验（可选）**

在 verification 之前插入 task stage 校验提示。task stage 字段最易在 executing-plans 内动态生成，先加软提示（不做硬阻断）。

- [ ] **Step 4: 行为测试（可选，依赖配额）**

Run: `cd tests/skill-behavior/brainstorming && ./run-test.sh`
确认 skill 在 spec 写完后跑了 validate-handoff（看 transcript 是否含 `OK spec`）。

- [ ] **Step 5: Commit**

```bash
git add skills/
git commit -m "feat(handoff): enforce validate-handoff as hard gate in brainstorming/writing-plans"
```

---

## Task 7: 与 phase-metrics 咬合

**Files:**
- Modify: `skills/brainstorming/SKILL.md`、`skills/writing-plans/SKILL.md`（微调上一 task 加的 emit）

- [ ] **Step 1: gate_result 关联**

把 Plan #1 加的 `log-phase-metric.sh --action gate` 调用改为**校验通过后**才 emit，并在 gate-result 字段写真实结果：

```bash
if scripts/validate-handoff.sh --stage spec --file "$SPEC"; then
  scripts/log-phase-metric.sh --phase brainstorming --action gate --gate-result passed --spec-topic "$SPEC_TOPIC"
else
  scripts/log-phase-metric.sh --phase brainstorming --action gate --gate-result failed --spec-topic "$SPEC_TOPIC"
fi
```

- [ ] **Step 2: 回归 phase-metrics 套件**

Run: `./tests/phase-metrics-scripts/run-all.sh`
Expected: 全部 PASS（字段没动）。

- [ ] **Step 3: Commit**

```bash
git add skills/
git commit -m "feat(handoff): tie validate-handoff result to phase-metrics gate_result"
```

---

## Task 8: 回归与成功标准

- [ ] **Step 1: 全套件回归**

```bash
./tests/plugin-infrastructure/run-all.sh
./tests/handoff-scripts/run-all.sh
./tests/phase-metrics-scripts/run-all.sh
./tests/knowledge-base-scripts/run-all.sh
```
Expected: 全部 PASS。

- [ ] **Step 2: 验收成功标准**

- 3 个交接点（spec / plan / task）都有 schema 校验
- 缺字段 / ref 失效 / topic 未注册三种错误都能退回
- 现有 `tests/explicit-skill-requests/` 不退化（任选一个测试复跑）

- [ ] **Step 3: 在 CLAUDE.md「常用命令」补一行**

```
- `tests/handoff-scripts/run-all.sh` — handoff schema 校验测试
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(handoff): register test suite in CLAUDE.md"
```

---

## 边界提醒

- ❌ 只覆盖 3 个核心交接点，不给 33 个 skill 全上 schema
- ❌ 不引入 JSON Schema 规范、不做版本号
- ❌ 不替换 spec-document-reviewer / plan-document-reviewer（并行）
- ❌ task stage 不做硬阻断（先软提示）
