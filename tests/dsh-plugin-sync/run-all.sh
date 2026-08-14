#!/usr/bin/env bash
# DSH 插件同步一致性测试
# 验证 .dsh/ 适配层结构完整、DSH 化副本与顶层 skills/ 一致（除 frontmatter
# 键名 when_to_use → whenToUse 外字节级一致）、安装脚本可用。
# 运行：./run-all.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SRC="$REPO_ROOT/skills"
DST="$REPO_ROOT/.dsh/agent-preset/skills"
PRESET="$REPO_ROOT/.dsh/agent-preset"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

assert_exists() {
    local path="$1"
    local desc="$2"
    if [[ -e "$path" ]]; then
        pass "$desc"
    else
        fail "$desc (路径不存在: $path)"
    fi
}

echo "=== Test: DSH 适配层结构 ==="

# 1. 项目级软链
if [[ -L "$REPO_ROOT/.dsh/skills" ]]; then
    pass ".dsh/skills 是符号链接"
else
    fail ".dsh/skills 不是符号链接"
fi
if [[ "$(readlink "$REPO_ROOT/.dsh/skills")" == "../skills" ]]; then
    pass ".dsh/skills -> ../skills"
else
    fail ".dsh/skills 指向 $(readlink "$REPO_ROOT/.dsh/skills" 2>/dev/null || echo 无)"
fi

# 2. preset 清单
assert_exists "$PRESET/preset.yml" "preset.yml 存在"
assert_exists "$PRESET/agent.cordis.yml" "agent.cordis.yml 存在"
if [[ -f "$PRESET/preset.yml" ]]; then
    for key in "name:" "description:" "order:"; do
        grep -q "^$key" "$PRESET/preset.yml" && pass "preset.yml 含 $key" || fail "preset.yml 缺 $key"
    done
fi
grep -q "customSkillDirs" "$PRESET/agent.cordis.yml" && pass "agent.cordis.yml 挂载 customSkillDirs" || fail "agent.cordis.yml 缺 customSkillDirs"
grep -q "dsh-tool-ralph" "$PRESET/agent.cordis.yml" && pass "agent.cordis.yml 启用 tool-ralph" || fail "agent.cordis.yml 缺 tool-ralph"

# 3. 安装脚本
assert_exists "$REPO_ROOT/scripts/install-dsh.sh" "install-dsh.sh 存在"
[[ -x "$REPO_ROOT/scripts/install-dsh.sh" ]] && pass "install-dsh.sh 可执行" || fail "install-dsh.sh 不可执行"
# --user-skills 必须平铺复制到 ~/.dsh/skills/ 根下（DSH 只做一层目录发现，
# 不支持递归嵌套；agent-harness/ 子目录包装会被当成缺 SKILL.md 的 bundle 整体跳过）
if grep -q 'for skill_dir in "$PRESET_SRC/skills"/\*/' "$REPO_ROOT/scripts/install-dsh.sh"; then
    pass "install-dsh.sh --user-skills 使用平铺复制"
else
    fail "install-dsh.sh --user-skills 未使用平铺复制"
fi
if grep -q 'cp -R "$PRESET_SRC/skills" "$SKILLS_DST/agent-harness"' "$REPO_ROOT/scripts/install-dsh.sh"; then
    fail "install-dsh.sh 仍含 agent-harness 子目录包装复制"
else
    pass "install-dsh.sh 无子目录包装复制"
fi

echo "=== Test: DSH 化副本与顶层一致性 ==="

# 4. skill 集合一致：顶层「含 SKILL.md 的目录集合」必须等于副本目录集合
#    （sync 脚本按此规则跳过非标准目录，不假设差值恒为 1）
src_skill_dirs=$(find "$SRC" -mindepth 2 -maxdepth 2 -name SKILL.md | sed "s|$SRC/||;s|/SKILL.md||" | sort)
dst_dirs=$(find "$DST" -mindepth 1 -maxdepth 1 -type d | sed "s|$DST/||" | sort)
if [[ "$src_skill_dirs" == "$dst_dirs" ]]; then
    pass "skill 集合一致（$(echo "$dst_dirs" | grep -c .) 个）"
else
    fail "skill 集合不一致"
    diff <(echo "$src_skill_dirs") <(echo "$dst_dirs") || true
fi
if [[ -d "$SRC/auto-loop" && ! -d "$DST/auto-loop" ]]; then
    pass "auto-loop 已按预期跳过"
else
    fail "auto-loop 跳过逻辑异常"
fi

# 5. 每个副本 skill 的 frontmatter 转换
MISMATCH=0
for dir in "$DST"/*/; do
    name="$(basename "$dir")"
    src_skill="$SRC/$name/SKILL.md"
    dst_skill="$dir/SKILL.md"

    if grep -q '^when_to_use:' "$dst_skill" 2>/dev/null; then
        echo "  [FAIL] $name: SKILL.md 仍含 when_to_use 键"
        MISMATCH=$((MISMATCH + 1))
    fi
    # DSH 下模型调用是唯一通道：disable-model-invocation 必须被移除
    if grep -q '^disable-model-invocation:' "$dst_skill" 2>/dev/null; then
        echo "  [FAIL] $name: SKILL.md 仍含 disable-model-invocation（DSH 下模型将无法加载）"
        MISMATCH=$((MISMATCH + 1))
    fi
    # whenToUse 值必须与顶层 when_to_use 值一致
    src_val=$(grep '^when_to_use:' "$src_skill" 2>/dev/null | sed 's/^when_to_use:[[:space:]]*//' || true)
    if [[ -n "$src_val" ]]; then
        dst_val=$(grep '^whenToUse:' "$dst_skill" 2>/dev/null | sed 's/^whenToUse:[[:space:]]*//' || true)
        if [[ "$src_val" != "$dst_val" ]]; then
            echo "  [FAIL] $name: whenToUse 值与顶层不一致"
            MISMATCH=$((MISMATCH + 1))
        fi
    fi
done
if [[ "$MISMATCH" -eq 0 ]]; then
    pass "全部副本 SKILL.md frontmatter 转换正确"
else
    fail "$MISMATCH 个副本 frontmatter 转换异常"
fi

# 6. 副本其余文件与顶层字节级一致（跳过 SKILL.md 的 frontmatter 键名差异）
DIFFS=0
for dir in "$DST"/*/; do
    name="$(basename "$dir")"
    # SKILL.md：忽略 when_to_use / whenToUse 键名行与 disable-model-invocation
    # 行（副本按 DSH 语义转换）后应无差异
    src_skill="$SRC/$name/SKILL.md"
    dst_skill="$dir/SKILL.md"
    if ! diff <(grep -v '^when_to_use:\|^disable-model-invocation:' "$src_skill") <(grep -v '^whenToUse:' "$dst_skill") >/dev/null 2>&1; then
        echo "  [FAIL] $name: SKILL.md 与顶层存在非 frontmatter 差异"
        DIFFS=$((DIFFS + 1))
    fi
    # 其余文件直接 diff
    while IFS= read -r -d '' rel; do
        if [[ "$rel" == "SKILL.md" ]]; then continue; fi
        if ! diff "$SRC/$name/$rel" "$dir/$rel" >/dev/null 2>&1; then
            echo "  [FAIL] $name: $rel 与顶层不一致"
            DIFFS=$((DIFFS + 1))
        fi
    done < <(cd "$dir" && find . -type f -not -name SKILL.md -print0 | sed 's|^\./||')
done
if [[ "$DIFFS" -eq 0 ]]; then
    pass "副本与顶层字节级一致（仅 frontmatter 键名转换）"
else
    fail "$DIFFS 个文件与顶层不一致"
fi

# 7. 可重新生成（幂等）
if bash "$REPO_ROOT/scripts/sync-dsh-skills.sh" >/dev/null 2>&1; then
    pass "sync-dsh-skills.sh 可重新生成"
else
    fail "sync-dsh-skills.sh 执行失败"
fi

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
    echo "=== 全部通过 ==="
    exit 0
else
    echo "=== $FAILURES 项失败 ==="
    exit 1
fi
