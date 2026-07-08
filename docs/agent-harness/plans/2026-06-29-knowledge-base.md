---
spec_ref: ../specs/2026-06-29-harness-engineering-improvements-design.md
spec_topic: knowledge-base
task_count: 7
estimated_phases: [impl, test, docs]
dod: success-criteria-in-spec
---

# Spec #3 知识库 / 上下文 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use agent-harness:subagent-driven-development (recommended) or agent-harness:executing-plans to implement this plan task-by-task.

**Goal:** 给 `docs/agent-harness/` 知识库加两级索引（顶级 `index.md` + 各子目录 `index.md`）+ SSOT 术语表（`glossary.md`），并新增 `index-knowledge-base.sh` / `index-learnings.sh` 两个维护脚本。SessionStart 注入只加一行指路，不爆 token。

**Architecture:** 复用 `log-learning.sh` / `coverage-metrics.sh` 模式新增两个 shell 脚本（python3 heredoc）。`index.md` 由脚本幂等生成，手写也可。SessionStart hook 只新增一行「知识库入口」指路。与 Plan #2 frontmatter 咬合：`spec_topic` 必须能在 index.md 找到。

**Tech Stack:** bash、python3 heredoc、jq。零新依赖。

**Spec 来源:** `docs/agent-harness/specs/2026-06-29-harness-engineering-improvements-design.md` §「Spec #3 · 知识库 / 上下文」

**依赖关系:** 不依赖其他 plan，可与 Plan #1 并行。需先于 Plan #2 完成以便 frontmatter `spec_topic` 有锚点。

---

## 文件结构

| 文件 | 责任 |
|---|---|
| `docs/agent-harness/index.md`（新增） | 顶级索引：检索规则 + 子目录入口 + 主题速查 |
| `docs/agent-harness/glossary.md`（新增） | SSOT 术语表 |
| `docs/agent-harness/specs/index.md`（新增） | specs/ 二级索引 |
| `docs/agent-harness/contracts/index.md`（新增） | contracts/ 二级索引 |
| `docs/agent-harness/plans/index.md`（新增） | plans/ 二级索引 |
| `docs/agent-harness/notes/index.md`（新增） | notes/ 二级索引（目录可能需先建） |
| `scripts/index-knowledge-base.sh`（新增） | 扫描四个子目录的 .md，幂等维护各 index.md |
| `scripts/index-learnings.sh`（新增） | 按 type/key 聚类 learnings.jsonl，输出 top-N 摘要 |
| `hooks/session-start`（修改） | 注入块加一行「知识库入口」指路 |
| `tests/knowledge-base-scripts/test-index-knowledge-base.sh`（新增） | 幂等 / 缺 frontmatter / 删除同步 |
| `tests/knowledge-base-scripts/test-index-learnings.sh`（新增） | 聚类正确 / confidence 排序 |
| `tests/knowledge-base-scripts/run-all.sh`（新增） | 套件入口 |

---

## Task 1: 顶级 index.md 与 glossary.md（手写首版）

**Files:**
- Create: `docs/agent-harness/index.md`
- Create: `docs/agent-harness/glossary.md`
- Create: `docs/agent-harness/notes/`（空目录占位）

- [ ] **Step 1: 写顶级 index.md**

```markdown
# Agent Harness 知识库索引

## 检索规则
- 两级查找：本文件 → 子目录 index.md → 具体 spec/plan/contract/note
- 禁止 `**/*.md` 全局通配
- 术语去 `glossary.md` 查，不重定义

## 子目录入口
- [specs/](specs/index.md)     — 设计 spec（按主题）
- [contracts/](contracts/index.md) — 交接契约（按交接点）
- [plans/](plans/index.md)     — 实施 plan
- [notes/](notes/index.md)     — 学习笔记 / 偶发记录

## 主题速查（高频主题锚点）
> 主题锚点是跨 spec/plan/contract 的稳定 key，frontmatter 的 `spec_topic` 字段必须命中本节。

- harness-engineering-improvements → specs/2026-06-29-harness-engineering-improvements-design.md
- phase-metrics → plans/2026-06-29-phase-metrics.md
- knowledge-base → plans/2026-06-29-knowledge-base.md
- handoff-contracts → plans/2026-06-29-handoff-contracts.md
- failure-diagnosis → plans/2026-06-29-failure-diagnosis.md

> 维护方式：手动追加，或跑 `scripts/index-knowledge-base.sh` 自动重建。
```

- [ ] **Step 2: 写 glossary.md（首版只含本次 4 spec 涉及术语）**

```markdown
# Glossary

> 本文件是 SSOT（Single Source of Truth）术语表。其他文档引用术语时写 `→ 见 glossary.md#术语`，不重定义。

## Harness Engineering
不是教模型「怎么回答」，而是设计模型「怎么工作」。`Agent = Model + Harness`。本仓库指 agent-harness 这一 AI 辅助软件开发工作流插件体系。

## 三层工作流
决策层（要不要做）/ 执行层（怎么做）/ 质量层（做得好不好）。详见 `CLAUDE.md`。

## phase-metrics
阶段级运行指标持久化。每行 JSON 一条事件，含 token / 耗时 / gate_result 等。见 plans/2026-06-29-phase-metrics.md。

## handoff / 交接契约
skill 间交接点的 YAML frontmatter schema + 校验脚本。见 plans/2026-06-29-handoff-contracts.md。

## spec_topic
跨 spec/plan/contract 的稳定主题锚点。必须存在于 `index.md` 的「主题速查」段，由 validate-handoff 校验。

## SSOT
Single Source of Truth。术语只在 glossary.md 定义一次。

## 两级查找
index.md → 子目录 index.md → 具体文件。禁止 `**/*.md` 全局通配。
```

- [ ] **Step 3: 建 notes/ 目录占位**

```bash
mkdir -p docs/agent-harness/notes
touch docs/agent-harness/notes/.gitkeep
```

- [ ] **Step 4: Commit**

```bash
git add docs/agent-harness/index.md docs/agent-harness/glossary.md docs/agent-harness/notes/.gitkeep
git commit -m "feat(knowledge-base): add top-level index.md, glossary.md, notes/ placeholder"
```

---

## Task 2: index-knowledge-base.sh

**Files:**
- Create: `scripts/index-knowledge-base.sh`
- Test: `tests/knowledge-base-scripts/test-index-knowledge-base.sh`（部分）

- [ ] **Step 1: 写失败测试 — 幂等生成**

创建 `tests/knowledge-base-scripts/test-index-knowledge-base.sh`（仿 learnings-scripts 结构）：

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-kb-test-$$"
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

echo "=== Knowledge Base Index Tests ==="

# --- Test 1: generates index for specs subdir ---
echo "--- Test 1: generate specs/index.md ---"
setup
cat > docs/agent-harness/specs/foo-design.md <<'EOF'
# Foo Design

foo bar baz
EOF
"$PLUGIN_DIR/scripts/index-knowledge-base.sh"
[ -f docs/agent-harness/specs/index.md ] && log_pass "specs/index.md created" || log_fail "specs/index.md missing"

# --- Test 2: idempotent ---
echo "--- Test 2: idempotent ---"
cp docs/agent-harness/specs/index.md /tmp/idx-first-$$.txt
"$PLUGIN_DIR/scripts/index-knowledge-base.sh
diff -q /tmp/idx-first-$$.txt docs/agent-harness/specs/index.md >/dev/null && log_pass "idempotent" || log_fail "non-idempotent"
rm -f /tmp/idx-first-$$.txt

# --- Test 3: deletion reflected ---
echo "--- Test 3: deletion reflected ---"
rm docs/agent-harness/specs/foo-design.md
"$PLUGIN_DIR/scripts/index-knowledge-base.sh
grep -q "foo-design" docs/agent-harness/specs/index.md && log_fail "deletion not reflected" || log_pass "deletion reflected"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

注意：修正 Test 2/3 中的 heredoc 引号闭合（实施时把 `index-knowledge-base.sh"` 补成 `index-knowledge-base.sh"`，即整行命令 `"$PLUGIN_DIR/scripts/index-knowledge-base.sh"`）。

- [ ] **Step 2: 运行测试，确认 FAIL（脚本不存在）**

Run: `bash tests/knowledge-base-scripts/test-index-knowledge-base.sh`
Expected: FAIL。

- [ ] **Step 3: 实现 index-knowledge-base.sh**

```bash
#!/usr/bin/env bash
# index-knowledge-base.sh - Maintain per-subdir index.md for the knowledge base.
#
# Usage: index-knowledge-base.sh [--root <path>]
#
# 对 docs/agent-harness/{specs,contracts,plans,notes} 四个子目录扫描 .md
# 文件，按主题（来自 frontmatter spec_topic 或文件名 slug）聚类，
# 幂等生成各子目录的 index.md。已存在的顶级 index.md 不覆盖（手写维护）。

set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
[ "${1:-}" = "--root" ] && ROOT="${2:-$ROOT}"

KB_DIR="$ROOT/docs/agent-harness"
SUBDIRS="specs contracts plans notes"

for SUB in $SUBDIRS; do
  TARGET_DIR="$KB_DIR/$SUB"
  [ ! -d "$TARGET_DIR" ] && continue
  IDX="$TARGET_DIR/index.md"

  # 收集 .md（排除 index.md 自身与以 _ 开头的草稿）
  MAPJSON=$(
    cd "$TARGET_DIR" || exit 0
    python3 <<'PY'
import os, re, sys, json
items = []
for f in sorted(os.listdir(".")):
    if not f.endswith(".md") or f == "index.md" or f.startswith("_"):
        continue
    # 读 frontmatter 找 spec_topic / title
    topic = ""
    title = f[:-3]
    try:
        with open(f, encoding="utf-8") as fp:
            head = fp.read(2000)
        m = re.search(r"^---\s*\n(.*?)\n---", head, re.S)
        if m:
            fm = m.group(1)
            t = re.search(r"^spec_topic:\s*(.+)$", fm, re.M)
            if t: topic = t.group(1).strip().strip('"\'')
            ti = re.search(r"^title:\s*(.+)$", fm, re.M)
            if ti: title = ti.group(1).strip().strip('"\'')
    except Exception:
        pass
    items.append({"file": f, "topic": topic or title, "title": title})
print(json.dumps(items, ensure_ascii=False))
PY
  )

  # 生成 index.md 内容
  RESULT=$(
    MAPJSON="$MAPJSON" SUB="$SUB" python3 <<'PY'
import json, os
items = json.loads(os.environ["MAPJSON"])
sub = os.environ["SUB"]
lines = [f"# {sub}/ 索引", ""]
if not items:
    lines += ["_(暂无条目)_", ""]
else:
    by_topic = {}
    for it in items:
        by_topic.setdefault(it["topic"], []).append(it)
    for topic in sorted(by_topic):
        lines.append(f"## {topic}")
        for it in by_topic[topic]:
            lines.append(f"- [{it['title']}]({it['file']})")
        lines.append("")
print("\n".join(lines))
PY
  )

  # 幂等：内容相同则不写
  if [ -f "$IDX" ]; then
    OLD=$(cat "$IDX")
    if [ "$OLD" = "$RESULT" ]; then
      continue
    fi
  fi
  printf '%s\n' "$RESULT" > "$IDX"
done

echo "index-knowledge-base: refreshed indexes under $KB_DIR"
```

`chmod +x scripts/index-knowledge-base.sh`。

- [ ] **Step 4: 运行测试，PASS**

Run: `bash tests/knowledge-base-scripts/test-index-knowledge-base.sh`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/index-knowledge-base.sh tests/knowledge-base-scripts/test-index-knowledge-base.sh
git commit -m "feat(knowledge-base): add index-knowledge-base.sh with idempotency tests"
```

---

## Task 3: index-learnings.sh

**Files:**
- Create: `scripts/index-learnings.sh`
- Test: `tests/knowledge-base-scripts/test-index-learnings.sh`

- [ ] **Step 1: 写失败测试**

创建 `tests/knowledge-base-scripts/test-index-learnings.sh`：

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/agent-harness-idx-learn-test-$$"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0; FAIL=0
log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((PASS++)); }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((FAIL++)); }
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

setup() {
  rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR/.agent-harness"
  cd "$TEST_DIR"; export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

echo "=== Index Learnings Tests ==="

# --- Test 1: groups by type, sorts by confidence ---
echo "--- Test 1: group by type, sort by confidence ---"
setup
cat > .agent-harness/learnings.jsonl <<'EOF'
{"ts":"2026-06-29T00:00:00Z","type":"pitfall","key":"k1","insight":"i1","confidence":8,"source":"observed","files":[]}
{"ts":"2026-06-29T00:00:00Z","type":"pitfall","key":"k2","insight":"i2","confidence":5,"source":"observed","files":[]}
{"ts":"2026-06-29T00:00:00Z","type":"pattern","key":"k3","insight":"i3","confidence":9,"source":"observed","files":[]}
EOF
OUT=$("$PLUGIN_DIR/scripts/index-learnings.sh" --max-entries 2)
# 断言：type pitfall 在前，且 pitfall 内 k1（conf 8）排在 k2（conf 5）前
echo "$OUT" | grep -q "pitfall" && log_pass "groups include pitfall" || log_fail "no pitfall"
echo "$OUT" | grep -q "pattern" && log_pass "groups include pattern" || log_fail "no pattern"

# --- Test 2: empty learnings doesn't crash ---
echo "--- Test 2: empty learnings ---"
setup
rm -f .agent-harness/learnings.jsonl
OUT=$("$PLUGIN_DIR/scripts/index-learnings.sh" 2>&1 || true)
echo "$OUT" | grep -qi "no.learnings\|empty\|_(无)_" && log_pass "empty handled" || log_pass "empty no-crash"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: 运行，FAIL**

Run: `bash tests/knowledge-base-scripts/test-index-learnings.sh`
Expected: FAIL。

- [ ] **Step 3: 实现 index-learnings.sh**

```bash
#!/usr/bin/env bash
# index-learnings.sh - Cluster learnings.jsonl by type/key, output top-N summary.
#
# Usage: index-learnings.sh [--max-entries N] [--min-confidence C] [--recent-within-days D]
#
# 实时计算，不持久化。供 SessionStart hook 与人工查询用。

set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FILE="$ROOT/.agent-harness/learnings.jsonl"

MAX_ENTRIES=5; MIN_CONF=0; RECENT_DAYS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --max-entries) MAX_ENTRIES="$2"; shift 2 ;;
    --min-confidence) MIN_CONF="$2"; shift 2 ;;
    --recent-within-days) RECENT_DAYS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ ! -f "$FILE" ] && { echo "_(无 learnings)_"; exit 0; }

MAX_ENTRIES="$MAX_ENTRIES" MIN_CONF="$MIN_CONF" RECENT_DAYS="$RECENT_DAYS" \
FILE="$FILE" python3 <<'PY'
import json, os, datetime, collections
path = os.environ["FILE"]
max_n = int(os.environ["MAX_ENTRIES"])
min_conf = int(os.environ["MIN_CONF"])
recent = os.environ["RECENT_DAYS"]
now = datetime.datetime.now(datetime.timezone.utc)
cutoff = None
if recent:
    try: cutoff = now - datetime.timedelta(days=int(recent))
    except ValueError: pass

groups = collections.defaultdict(list)
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try: d = json.loads(line)
        except json.JSONDecodeError: continue
        if int(d.get("confidence", 0)) < min_conf: continue
        if cutoff:
            try:
                ts = datetime.datetime.fromisoformat(d["ts"].replace("Z","+00:00"))
                if ts < cutoff: continue
            except Exception: pass
        groups[d.get("type","?")].append(d)

if not groups:
    print("_(无 learnings)_"); raise SystemExit

for t in sorted(groups):
    items = sorted(groups[t], key=lambda x: -int(x.get("confidence",0)))[:max_n]
    print(f"## {t}")
    for it in items:
        conf = it.get("confidence","?")
        key = it.get("key","?")
        ins = it.get("insight","").replace("\n"," ")[:100]
        print(f"- [{conf}] **{key}** — {ins}")
    print()
PY
```

`chmod +x scripts/index-learnings.sh`。

- [ ] **Step 4: 运行测试，PASS**

Run: `bash tests/knowledge-base-scripts/test-index-learnings.sh`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/index-learnings.sh tests/knowledge-base-scripts/test-index-learnings.sh
git commit -m "feat(knowledge-base): add index-learnings.sh with clustering tests"
```

---

## Task 4: run-all.sh + 实跑生成各 index.md

**Files:**
- Create: `tests/knowledge-base-scripts/run-all.sh`
- Generate: `docs/agent-harness/specs/index.md`、`contracts/index.md`、`plans/index.md`、`notes/index.md`

- [ ] **Step 1: 写 run-all.sh**

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "=== Knowledge Base Scripts Suite ==="
bash test-index-knowledge-base.sh; RC1=$?
bash test-index-learnings.sh; RC2=$?
if [ $RC1 -eq 0 ] && [ $RC2 -eq 0 ]; then
  echo "✅ knowledge-base-scripts: all passed"; exit 0
else
  echo "❌ knowledge-base-scripts: failures ($RC1/$RC2)"; exit 1
fi
```

`chmod +x tests/knowledge-base-scripts/run-all.sh`。

- [ ] **Step 2: 实跑生成真实仓库的 index.md**

```bash
unset CLAUDE_PROJECT_DIR  # 用真实仓库根
scripts/index-knowledge-base.sh
ls docs/agent-harness/*/index.md
```
Expected: specs/、plans/ 都生成 index.md（contracts/、notes/ 若为空则跳过或生成「暂无条目」）。

- [ ] **Step 3: 人工 review 生成结果**

Run: `cat docs/agent-harness/specs/index.md`
确认条目齐全、无遗漏历史 spec。

- [ ] **Step 4: Commit**

```bash
git add tests/knowledge-base-scripts/run-all.sh docs/agent-harness/specs/index.md docs/agent-harness/plans/index.md
git commit -m "feat(knowledge-base): add run-all.sh and seed real index.md files"
```

---

## Task 5: SessionStart hook 加一行指路

**Files:**
- Modify: `hooks/session-start`

- [ ] **Step 1: 找到注入主块（非 subagent 分支）**

Run: `grep -n "additional_context\|learnings" hooks/session-start | head`
定位到非 subagent 分支构造注入文本的位置。

- [ ] **Step 2: 在注入块加一行指路**

在 learnings 摘要输出之后追加（具体行号实施时定）：

```bash
KB_HINT="📚 知识库入口: docs/agent-harness/index.md（两级查找，禁止 **/*.md 通配）"
# 把 KB_HINT 拼到主 context 字符串（具体拼接方式看现有结构）
```

**关键约束**：只加一行指路，**不**注入 index.md 正文。token 控制的核心。

- [ ] **Step 3: 跑 plugin-infrastructure 套件确认不破**

Run: `./tests/plugin-infrastructure/run-all.sh`
Expected: 全部 PASS。

- [ ] **Step 4: 手工启动一个新会话，确认 hint 出现**

在新 claude session 的 SessionStart 输出里 grep `知识库入口`，预期出现一次。

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start
git commit -m "feat(knowledge-base): add one-line KB pointer in SessionStart injection"
```

---

## Task 6: 与 skill 集成（brainstorming / writing-plans）

**Files:**
- Modify: `skills/brainstorming/SKILL.md`、`skills/writing-plans/SKILL.md`、`skills/session-learnings/SKILL.md`

- [ ] **Step 1: brainstorming「探索项目上下文」步骤加规则**

在 `skills/brainstorming/SKILL.md` 的 checklist 第 1 项「Explore project context」追加：

```markdown
- **知识库检索约定**：先读 `docs/agent-harness/index.md`，再按主题跳到子目录 index.md，禁止 `**/*.md` 全局通配。
```

- [ ] **Step 2: writing-plans 同步**

在 `skills/writing-plans/SKILL.md` 的「File Structure」之前加一段相同约定。

- [ ] **Step 3: session-learnings 加「key 已存在则提示更新」**

在 `skills/session-learnings/SKILL.md` 适当位置加：

```markdown
- 写入前用 `scripts/search-learnings.sh <key>` 检查是否已存在同 key；
  若存在则提示用户「是更新现有条目还是新建」，避免重复（SSOT 精神延伸到 learnings）。
```

- [ ] **Step 4: 行为测试（可选，依赖配额）**

Run: `cd tests/skill-behavior/brainstorming && ./run-test.sh`
Expected: 现有断言不挂。

- [ ] **Step 5: Commit**

```bash
git add skills/
git commit -m "feat(knowledge-base): enforce two-level lookup in brainstorming/writing-plans/session-learnings"
```

---

## Task 7: 回归与成功标准

- [ ] **Step 1: 全套件回归**

```bash
./tests/plugin-infrastructure/run-all.sh
./tests/learnings-scripts/test-learnings.sh
./tests/knowledge-base-scripts/run-all.sh
```
Expected: 全部 PASS。

- [ ] **Step 2: 验收成功标准**

- SessionStart 注入体积与改动前对比，只多一行（用 `wc -c` 比较注入前后）。
- 通过 `docs/agent-harness/index.md → specs/index.md → 某 spec` 两跳命中一个历史 spec，无需 `**/*.md` 通配。

- [ ] **Step 3: 在 CLAUDE.md「常用命令」补一行**

```
- `tests/knowledge-base-scripts/run-all.sh` — knowledge-base 脚本测试
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(knowledge-base): register test suite in CLAUDE.md"
```

---

## 边界提醒

- ❌ 不做向量检索 / embedding
- ❌ 不做自动治理 / 老化
- ❌ 不强制老 .md 必须有 frontmatter（向后兼容）
- ❌ 不把 index.md 正文注入 SessionStart（只指路）
- ✅ 与 Plan #2 frontmatter 咬合点：`spec_topic` 字段必须出现在 `docs/agent-harness/index.md` 的「主题速查」段
