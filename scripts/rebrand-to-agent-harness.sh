#!/usr/bin/env bash
# Rebrand: superpowers → agent-harness
# Spec: docs/agent-harness/specs/2026-06-27-rebrand-to-agent-harness-design.md
# (注：脚本编写时 docs/superpowers 尚未重命名，运行时第3阶段会同步改名)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# --- 平台检测：macOS BSD sed vs Linux GNU sed ---
if [[ "$(uname)" == "Darwin" ]]; then
    SED_INPLACE=(-i '')
else
    SED_INPLACE=(-i)
fi

# --- 安全检查：working tree 必须 clean ---
if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ Working tree not clean. Commit or stash first." >&2
    git status --short >&2
    exit 1
fi

# --- 安全检查：必须在仓库根 ---
if [[ ! -f "package.json" ]] || [[ ! -d ".claude-plugin" ]]; then
    echo "❌ Not at repo root (no package.json / .claude-plugin)." >&2
    exit 1
fi

echo "✓ 安全检查通过"

# --- 阶段 1：git mv 目录与文件（最长路径优先） ---
echo "▶ 阶段 1/5：git mv 目录与文件重命名"

# demo 子项目（先改，避免主项目 docs/superpowers 先改后路径歧义）
[[ -d "demo/fruit-shop/.superpowers" ]] && git mv "demo/fruit-shop/.superpowers" "demo/fruit-shop/.agent-harness"
[[ -d "demo/fruit-shop/docs/superpowers" ]] && git mv "demo/fruit-shop/docs/superpowers" "demo/fruit-shop/docs/agent-harness"
[[ -d "demo/docs/superpowers" ]] && git mv "demo/docs/superpowers" "demo/docs/agent-harness"

# 主项目顶层目录
[[ -d "docs/superpowers" ]] && git mv "docs/superpowers" "docs/agent-harness"
[[ -d ".superpowers" ]] && git mv ".superpowers" ".agent-harness"

# skill 目录与测试目录
[[ -d "skills/using-superpowers" ]] && git mv "skills/using-superpowers" "skills/using-agent-harness"
[[ -d "tests/skill-behavior/using-superpowers" ]] && git mv "tests/skill-behavior/using-superpowers" "tests/skill-behavior/using-agent-harness"

# pi 扩展文件
[[ -f ".pi/extensions/superpowers.ts" ]] && git mv ".pi/extensions/superpowers.ts" ".pi/extensions/agent-harness.ts"

echo "✓ 阶段 1 完成（目录/文件重命名）"

# --- 阶段 2a：预览待改文件清单 ---
echo "▶ 阶段 2/5：预览待改文件清单"

# 收集所有文本文件（排除 .git、LICENSE、二进制）
FILES_TO_PROCESS=$(find . \
    -type f \
    -not -path './.git/*' \
    -not -name 'LICENSE' \
    -not -name '.DS_Store' \
    -not -name '*.png' -not -name '*.jpg' -not -name '*.jpeg' \
    -not -name '*.gif' -not -name '*.icns' -not -name '*.pdf' \
    -not -name '*.svg' -not -name '*.ai' \
    -not -name 'rebrand-to-agent-harness.sh' \
    | sort)

# 统计含 superpowers 的文件（不区分大小写）
AFFECTED=$(echo "$FILES_TO_PROCESS" | xargs grep -li 'superpowers' 2>/dev/null | wc -l | tr -d ' ')
echo "  将处理 $AFFECTED 个文件"
echo "$FILES_TO_PROCESS" | xargs grep -li 'superpowers' 2>/dev/null | head -30
echo "..."
echo ""
read -r -p "确认执行 sed 替换？(Enter 继续 / Ctrl+C 中止): " _CONFIRM

# --- 阶段 2b：分层 sed 替换（按优先级从高到低） ---
echo "▶ 阶段 2/5：执行分层 sed 替换"

# 将文件列表写入临时文件，供 xargs 分批处理
TMP_FILELIST="$(mktemp)"
echo "$FILES_TO_PROCESS" > "$TMP_FILELIST"

apply_sed() {
    local pattern="$1"
    local replacement="$2"
    local label="$3"
    echo "  ↳ $label"
    xargs < "$TMP_FILELIST" grep -li "$pattern" 2>/dev/null | while read -r f; do
        # 跳过 README.md / README_EN.md / CLAUDE.md（阶段 4 单独处理致敬段）
        case "$f" in
            ./README.md|./README_EN.md|./CLAUDE.md) continue ;;
        esac
        sed "${SED_INPLACE[@]}" -e "s|${pattern}|${replacement}|g" "$f"
    done
}

# 规则 1（复合 token）
apply_sed 'superpowers:using-superpowers' 'agent-harness:using-agent-harness' '规则1: 复合 token'

# 规则 2（命名空间）
apply_sed 'superpowers:' 'agent-harness:' '规则2: 命名空间 superpowers: → agent-harness:'

# 规则 3（skill 名标识符）
apply_sed 'using-superpowers' 'using-agent-harness' '规则3: skill 名 using-superpowers'

# 规则 4（隐藏目录路径）
apply_sed '\.superpowers/' '.agent-harness/' '规则4: 路径 .superpowers/'

# 规则 5（docs 路径）
apply_sed 'docs/superpowers/' 'docs/agent-harness/' '规则5: 路径 docs/superpowers/'

# 规则 6（marketplace name）
apply_sed 'superpowers-dev' 'agent-harness' '规则6: marketplace name superpowers-dev'

# 规则 7（settings 插件引用，已被规则 6 覆盖一半，此处显式补全）
apply_sed 'superpowers@agent-harness-dev' 'agent-harness@agent-harness' '规则7: settings 插件引用'

# 规则 8（大驼峰单词，用词边界）
# 注：macOS BSD sed -E 不识别 \b（GNU 扩展），改用 perl 跨平台一致
xargs < "$TMP_FILELIST" grep -liE '\bSuperpowers\b' 2>/dev/null | while read -r f; do
    case "$f" in
        ./README.md|./README_EN.md|./CLAUDE.md) continue ;;
    esac
    perl -C -pi -e 's/\bSuperpowers\b/Agent Harness/g' "$f"
done

# 规则 9（全小写兜底，用词边界）
xargs < "$TMP_FILELIST" grep -liE '\bsuperpowers\b' 2>/dev/null | while read -r f; do
    case "$f" in
        ./README.md|./README_EN.md|./CLAUDE.md) continue ;;
    esac
    perl -C -pi -e 's/\bsuperpowers\b/agent-harness/g' "$f"
done

rm -f "$TMP_FILELIST"
echo "✓ 阶段 2 完成（sed 替换）"

# --- 阶段 3：README / CLAUDE.md 专用处理（先 sed，再注入致敬段） ---
echo "▶ 阶段 3/5：README / CLAUDE.md 致敬段处理"

TRIBUTE_ZH='## 致谢 / Acknowledgements

本项目 fork 自 Jesse Vincent（[@obra](https://github.com/obra)）的 [Superpowers](https://github.com/obra/superpowers)，保留了其工作流理念与 skill 架构。感谢原作者的开创性工作。'

TRIBUTE_EN="## Acknowledgements

This project is forked from Jesse Vincent ([@obra](https://github.com/obra))'s [Superpowers](https://github.com/obra/superpowers). We retain its workflow philosophy and skill architecture. Credit to the original author."

# README.md：先应用规则 8/9 的替换，再注入致敬段
if [[ -f "README.md" ]]; then
    # 替换大驼峰与小写（致敬词会在最后注入，无需保留）
    # 注：macOS BSD sed -E 不识别 \b，改用 perl
    perl -C -pi -e 's/\bSuperpowers\b/Agent Harness/g' README.md
    perl -C -pi -e 's/\bsuperpowers\b/agent-harness/g' README.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers:using-superpowers/agent-harness:using-agent-harness/g' README.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers:/agent-harness:/g' README.md
    sed "${SED_INPLACE[@]}" -E 's/using-superpowers/using-agent-harness/g' README.md
    sed "${SED_INPLACE[@]}" -E 's|\.superpowers/|.agent-harness/|g' README.md
    sed "${SED_INPLACE[@]}" -E 's|docs/superpowers/|docs/agent-harness/|g' README.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers-dev/agent-harness/g' README.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers@agent-harness-dev/agent-harness@agent-harness/g' README.md
    # 在第一个一级标题后插入致敬段（若尚未存在）
    if ! grep -q '^## 致谢' README.md; then
        # 用 awk 在第一个 ## 标题（目录或 About）前插入
        awk -v tribute="$TRIBUTE_ZH" '
            NR==1 { print; next }
            /^#/ && !inserted { print tribute; print ""; inserted=1 }
            { print }
        ' README.md > README.md.tmp && mv README.md.tmp README.md
    fi
fi

# README_EN.md：同步处理
if [[ -f "README_EN.md" ]]; then
    perl -C -pi -e 's/\bSuperpowers\b/Agent Harness/g' README_EN.md
    perl -C -pi -e 's/\bsuperpowers\b/agent-harness/g' README_EN.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers:using-superpowers/agent-harness:using-agent-harness/g' README_EN.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers:/agent-harness:/g' README_EN.md
    sed "${SED_INPLACE[@]}" -E 's/using-superpowers/using-agent-harness/g' README_EN.md
    sed "${SED_INPLACE[@]}" -E 's|\.superpowers/|.agent-harness/|g' README_EN.md
    sed "${SED_INPLACE[@]}" -E 's|docs/superpowers/|docs/agent-harness/|g' README_EN.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers-dev/agent-harness/g' README_EN.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers@agent-harness-dev/agent-harness@agent-harness/g' README_EN.md
    if ! grep -q '^## Acknowledgements' README_EN.md; then
        awk -v tribute="$TRIBUTE_EN" '
            NR==1 { print; next }
            /^#/ && !inserted { print tribute; print ""; inserted=1 }
            { print }
        ' README_EN.md > README_EN.md.tmp && mv README_EN.md.tmp README_EN.md
    fi
fi

# CLAUDE.md：保留"基于 Jesse Vincent 的原版 Superpowers 项目"一句作为致敬上下文
# 其余 superpowers 字眼做替换
if [[ -f "CLAUDE.md" ]]; then
    # 用占位符保护致敬句
    sed "${SED_INPLACE[@]}" -E 's/基于 Jesse Vincent 的原版 Superpowers 项目/__TRIBUTE_SENTINEL__/g' CLAUDE.md
    # 注：macOS BSD sed -E 不识别 \b，改用 perl
    perl -C -pi -e 's/\bSuperpowers\b/Agent Harness/g' CLAUDE.md
    perl -C -pi -e 's/\bsuperpowers\b/agent-harness/g' CLAUDE.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers:using-superpowers/agent-harness:using-agent-harness/g' CLAUDE.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers:/agent-harness:/g' CLAUDE.md
    sed "${SED_INPLACE[@]}" -E 's/using-superpowers/using-agent-harness/g' CLAUDE.md
    sed "${SED_INPLACE[@]}" -E 's|\.superpowers/|.agent-harness/|g' CLAUDE.md
    sed "${SED_INPLACE[@]}" -E 's|docs/superpowers/|docs/agent-harness/|g' CLAUDE.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers-dev/agent-harness/g' CLAUDE.md
    sed "${SED_INPLACE[@]}" -E 's/superpowers@agent-harness-dev/agent-harness@agent-harness/g' CLAUDE.md
    # 恢复致敬句
    sed "${SED_INPLACE[@]}" -E 's/__TRIBUTE_SENTINEL__/基于 Jesse Vincent 的原版 Superpowers 项目/g' CLAUDE.md
fi

# skills/CLAUDE.md / tests/CLAUDE.md / tests/claude-code/README.md：标准 sed（无致敬保留）
for f in "skills/CLAUDE.md" "tests/CLAUDE.md" "tests/claude-code/README.md"; do
    [[ -f "$f" ]] || continue
    # 注：macOS BSD sed -E 不识别 \b，改用 perl
    perl -C -pi -e 's/\bSuperpowers\b/Agent Harness/g' "$f"
    perl -C -pi -e 's/\bsuperpowers\b/agent-harness/g' "$f"
    sed "${SED_INPLACE[@]}" -E 's/superpowers:using-superpowers/agent-harness:using-agent-harness/g' "$f"
    sed "${SED_INPLACE[@]}" -E 's/superpowers:/agent-harness:/g' "$f"
    sed "${SED_INPLACE[@]}" -E 's/using-superpowers/using-agent-harness/g' "$f"
    sed "${SED_INPLACE[@]}" -E 's|\.superpowers/|.agent-harness/|g' "$f"
    sed "${SED_INPLACE[@]}" -E 's|docs/superpowers/|docs/agent-harness/|g' "$f"
    sed "${SED_INPLACE[@]}" -E 's/superpowers-dev/agent-harness/g' "$f"
    sed "${SED_INPLACE[@]}" -E 's/superpowers@agent-harness-dev/agent-harness@agent-harness/g' "$f"
done

echo "✓ 阶段 3 完成（README / CLAUDE.md 致敬段处理）"

# --- 阶段 4：JSON 合法性校验 ---
echo "▶ 阶段 4/5：JSON 合法性校验"

JSON_FILES=(
    ".claude-plugin/plugin.json"
    ".claude-plugin/marketplace.json"
    ".codex-plugin/plugin.json"
    "package.json"
    "hooks/hooks.json"
    ".claude/settings.json"
)

for jf in "${JSON_FILES[@]}"; do
    if [[ -f "$jf" ]]; then
        if ! jq . "$jf" > /dev/null 2>&1; then
            echo "❌ JSON 校验失败：$jf" >&2
            jq . "$jf" >&2 || true
            exit 1
        fi
        echo "  ✓ $jf"
    fi
done

# settings.local.json.example（若存在）
if [[ -f ".claude/settings.local.json.example" ]]; then
    if ! jq . ".claude/settings.local.json.example" > /dev/null 2>&1; then
        echo "❌ JSON 校验失败：.claude/settings.local.json.example" >&2
        exit 1
    fi
    echo "  ✓ .claude/settings.local.json.example"
fi

echo "✓ 阶段 4 完成（JSON 合法）"

# --- 阶段 5：残留扫描 ---
echo "▶ 阶段 5/5：残留 superpowers 字眼扫描"

# 白名单：LICENSE、README.md、README_EN.md、CLAUDE.md（致敬段）
RESIDUAL=$(grep -rni 'superpowers' \
    --exclude-dir=.git \
    --exclude=LICENSE \
    --exclude=README.md \
    --exclude=README_EN.md \
    --exclude=CLAUDE.md \
    --exclude=rebrand-to-agent-harness.sh \
    . 2>/dev/null || true)

if [[ -n "$RESIDUAL" ]]; then
    echo "⚠️  发现残留 superpowers 字眼（非白名单）：" >&2
    echo "$RESIDUAL" >&2
    echo "" >&2
    echo "请人工检查上述命中是否为致敬上下文。若非致敬，回到阶段 2 补充 sed 规则。" >&2
    exit 1
fi

echo "✓ 阶段 5 完成（无残留）"

# 致敬段位置确认
echo ""
echo "📋 致敬段确认（应保留 Superpowers 字样）："
echo "--- README.md ---"
grep -A2 '^## 致谢' README.md 2>/dev/null || echo "(未找到致敬段，请检查)"
echo "--- README_EN.md ---"
grep -A2 '^## Acknowledgements' README_EN.md 2>/dev/null || echo "(未找到致敬段，请检查)"
echo "--- CLAUDE.md 致敬句 ---"
grep '基于 Jesse Vincent' CLAUDE.md 2>/dev/null || echo "(未找到致敬句)"

echo ""
echo "🎉 rebrand 完成。下一步：运行 plugin 基础设施测试（见 Task 9）"
