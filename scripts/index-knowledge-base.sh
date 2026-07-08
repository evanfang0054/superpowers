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

# Single python implementation: scan each subdir, emit index.md in-place.
ROOT="$KB_DIR" python3 - <<'PY'
import os, re, json
kb = os.environ["ROOT"]
subdirs = ["specs", "contracts", "plans", "notes"]
for sub in subdirs:
    target = os.path.join(kb, sub)
    if not os.path.isdir(target):
        continue
    idx = os.path.join(target, "index.md")
    items = []
    for f in sorted(os.listdir(target)):
        if not f.endswith(".md") or f == "index.md" or f.startswith("_"):
            continue
        topic = ""
        title = f[:-3]
        try:
            with open(os.path.join(target, f), encoding="utf-8") as fp:
                head = fp.read(2000)
            m = re.search(r"^---\s*\n(.*?)\n---", head, re.S)
            if m:
                fm = m.group(1)
                t = re.search(r"^spec_topic:\s*(.+)$", fm, re.M)
                if t:
                    topic = t.group(1).strip().strip('"\'')
                ti = re.search(r"^title:\s*(.+)$", fm, re.M)
                if ti:
                    title = ti.group(1).strip().strip('"\'')
        except Exception:
            pass
        items.append({"file": f, "topic": topic or title, "title": title})

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
    result = "\n".join(lines) + "\n"

    # Idempotent: write only if content differs
    old = ""
    if os.path.isfile(idx):
        with open(idx, encoding="utf-8") as fp:
            old = fp.read()
    if old != result:
        with open(idx, "w", encoding="utf-8") as fp:
            fp.write(result)
PY

echo "index-knowledge-base: refreshed indexes under $KB_DIR"
