#!/usr/bin/env bash
# auto-loop.sh — 全自动会话分析到 PR 闭环
#
# Usage:
#   ./auto-loop.sh "<自然语言需求>"
#   ./auto-loop.sh --project <path> "<需求>"
#   ./auto-loop.sh --all-projects "<需求>"
#   ./auto-loop.sh --resume
#   ./auto-loop.sh --cleanup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# PLUGIN_ROOT: 脚本所在的插件源仓库根 —— 用于定位插件自带文件
# （orchestrator-prompt.md、--plugin-dir 加载点）。全局安装下指向
# ~/.claude/plugins/cache/.../agent-harness/<ver>/，开发期指向源仓库。
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# OPERATION_REPO: auto-loop 自身运行、state、worktree、issue/PR 所属仓库。
# SCAN_TARGET: 要导出/分析会话的项目路径。--project 只改变 SCAN_TARGET，
# 不改变 OPERATION_REPO，避免跨仓库 dry-run 被外部项目 git 状态阻断。
TARGET_REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="$TARGET_REPO/.claude/auto-loop"
STATE_FILE="$STATE_DIR/state.json"

source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/observe.sh"
source "$SCRIPT_DIR/lib/worktree.sh"

# ---------- 参数解析 ----------
PROJECT=""
ALL_PROJECTS=false
RESUME=false
CLEANUP=false
DRY_RUN=false
FIX_ONLY=""
MAX_ISSUES=""
REQUEST=""
FILTER=""
ORIGINAL_PWD="$PWD"

usage() {
    cat << 'EOF'
用法: auto-loop.sh [选项] "<需求>"

选项:
  --project <path>      扫描指定项目（默认当前目录）
  --all-projects        扫描所有项目
  --filter "<条件>"     会话过滤条件（自然语言），只分析符合的会话
  --resume              恢复中断的运行
  --cleanup             清理 state 和 runs/
  --dry-run             只分析+提 issue，不修复
  --fix-only "[list]"   跳过分析，直接修复指定 issue（"all" 或 "#12,#15"，与 --dry-run 互斥）
  --max-issues N        最多提/修 N 个 issue（A 模式限噪音，B 模式 all 限批量）
  -h, --help            显示帮助

示例:
  auto-loop.sh "分析今天的会话"
  auto-loop.sh --project ~/code/foo "分析本周会话"
  auto-loop.sh --all-projects "找出所有项目的问题"
  auto-loop.sh --filter "调用了 agent-harness 相关 skill" "只盘点相关会话"
  auto-loop.sh --resume
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            # 防御 set -u 下的 unbound variable（#29）：缺参数给友好提示而非裸崩溃
            if [ -z "${2:-}" ]; then
                echo "错误: --project 需要一个路径参数" >&2
                exit 1
            fi
            PROJECT="$2"; shift 2 ;;
        --all-projects) ALL_PROJECTS=true; shift ;;
        --resume) RESUME=true; shift ;;
        --cleanup) CLEANUP=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --fix-only)
            if [ -z "${2:-}" ]; then
                echo "错误: --fix-only 需要一个参数（\"all\" 或 \"#12,#15\"）" >&2
                exit 1
            fi
            FIX_ONLY="$2"; shift 2 ;;
        --max-issues)
            if [ -z "${2:-}" ]; then
                echo "错误: --max-issues 需要一个正整数参数" >&2
                exit 1
            fi
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
                echo "错误: --max-issues 必须是正整数" >&2
                exit 1
            fi
            MAX_ISSUES="$2"; shift 2 ;;
        --filter) FILTER="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) REQUEST="$1"; shift ;;
    esac
done

# ---------- 清理模式 ----------
if $CLEANUP; then
    worktree_cleanup_all "$TARGET_REPO" 2>/dev/null || true
    rm -rf "$STATE_DIR"
    echo "已清理 $STATE_DIR 和所有 worktree"
    exit 0
fi

# ---------- 前置检查 ----------
check_mode_mutex() {
    if $DRY_RUN && [ -n "$FIX_ONLY" ]; then
        echo "错误: --dry-run 与 --fix-only 互斥" >&2
        exit 1
    fi
}

check_prerequisites() {
    command -v claude >/dev/null 2>&1 || { echo "错误: 未找到 claude CLI" >&2; exit 1; }
    command -v gh >/dev/null 2>&1 || { echo "错误: 未找到 gh CLI" >&2; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "错误: 未找到 jq" >&2; exit 1; }
    command -v uv >/dev/null 2>&1 || { echo "错误: 未找到 uv（claude-code-log 依赖）" >&2; exit 1; }
    gh auth status >/dev/null 2>&1 || { echo "错误: gh 未认证，请运行 gh auth login" >&2; exit 1; }
}

check_clean_workspace() {
    if [ -n "$(git -C "$TARGET_REPO" status --porcelain 2>/dev/null)" ]; then
        echo "错误: 工作区不干净，请 commit 或 stash 后重试" >&2
        git -C "$TARGET_REPO" status --short >&2
        exit 1
    fi
}

check_git_remote() {
    if ! git -C "$TARGET_REPO" remote get-url origin >/dev/null 2>&1; then
        echo "错误: 未配置 git remote origin" >&2
        exit 1
    fi
    # 验证 origin 指向用户 fork（evanfang0054/agent-harness），而非 upstream
    local origin_url
    origin_url=$(git -C "$TARGET_REPO" remote get-url origin 2>/dev/null)
    if ! echo "$origin_url" | grep -q "evanfang0054/agent-harness"; then
        echo "警告: origin ($origin_url) 不是 evanfang0054/agent-harness" >&2
        echo "PR 将推到此 remote。如需推到 fork，请先配置:" >&2
        echo "  git remote set-url origin <your-fork-url>" >&2
        echo "继续运行? (y/N)" >&2
        read -r CONFIRM
        [ "$CONFIRM" = "y" ] || exit 1
    fi
}

# ---------- 恢复模式 ----------
if $RESUME; then
    if [ ! -f "$STATE_FILE" ]; then
        echo "无可恢复的运行（$STATE_FILE 不存在）"
        exit 0
    fi
    check_prerequisites
    # 恢复运行也检查工作区，避免脏改动混入 auto-loop 提交（#12）
    check_clean_workspace
    INTERVENTION=$(state_get "$STATE_DIR" '.intervention')
    if [ "$INTERVENTION" != "null" ]; then
        # 显示介入请求
        REASON=$(echo "$INTERVENTION" | jq -r '.reason // "unknown"')
        CURRENT=$(echo "$INTERVENTION" | jq -r '.current_issue // "?"')
        echo "⚠️  需要你的介入"
        echo "─────────────────────────────────────"
        echo "运行 ID: $(state_get "$STATE_DIR" '.run_id')"
        echo "当前步骤: $CURRENT"
        echo "介入原因: $REASON"
        echo ""
        echo "请处理后重新运行 --resume"
        exit 0
    fi
    echo "检测到未完成运行，从 $(state_get "$STATE_DIR" '.current_step') 继续..."
    # 恢复 scope 描述，避免下游 prompt 组装时空串
    SCOPE_DESC="(从上次运行恢复)"
    # SCAN_TARGET 从 state.json 读取（首次运行时已持久化），避免恢复时丢失
    SCAN_TARGET=$(state_get "$STATE_DIR" '.scan_target // ""' 2>/dev/null || echo "")
    FILTER=$(state_get "$STATE_DIR" '.filter // ""' 2>/dev/null || echo "")
    MODE_VAL=$(state_get "$STATE_DIR" '.mode // "full"' 2>/dev/null || echo "full")
    FIX_ONLY=$(state_get "$STATE_DIR" '.target_issues | if . == ["all"] then "all" elif length == 0 then "" else join(",") end' 2>/dev/null || echo "")
    MAX_ISSUES=$(state_get "$STATE_DIR" '.max_issues // ""' 2>/dev/null || echo "")
    # 继续 fall-through 到主流程
else
    # ---------- 全新运行 ----------
    check_mode_mutex
    check_prerequisites
    check_clean_workspace
    check_git_remote

    if [ -z "$REQUEST" ]; then
        echo "错误: 缺少需求描述" >&2
        usage
        exit 1
    fi

    # 确定 scope 和扫描目标路径
    SCOPE_DESC=""
    SCAN_TARGET=""
    if $ALL_PROJECTS; then
        SCOPE_DESC="扫描所有项目 (~/.claude/projects/)"
        SCAN_TARGET="$HOME/.claude/projects/"
    elif [ -n "$PROJECT" ]; then
        SCOPE_DESC="扫描指定项目: $PROJECT"
        SCAN_TARGET="$PROJECT"
    else
        SCOPE_DESC="扫描当前项目: $TARGET_REPO"
        SCAN_TARGET="$TARGET_REPO"
    fi

    RUN_ID="run-$(date +%Y-%m-%d-%H%M%S)"
    BRANCH="feat/auto-improvement-$(date +%Y-%m-%d)"
    # 推算 mode 字符串供 state_init 与 prompt 组装使用
    if $DRY_RUN; then
        MODE_VAL="dry_run"
    elif [ -n "$FIX_ONLY" ]; then
        MODE_VAL="fix_only"
    else
        MODE_VAL="full"
    fi
    state_init "$RUN_ID" "$BRANCH" "$REQUEST" "$STATE_DIR" "$SCAN_TARGET" "$FILTER" \
        "$MODE_VAL" "$FIX_ONLY" "$MAX_ISSUES"

    # fix-only 模式用首个 issue 号命名分支，便于追溯；多 issue 单 PR
    if [ "$MODE_VAL" = "fix_only" ] && [ "$FIX_ONLY" != "all" ] && [ -n "$FIX_ONLY" ]; then
        first_issue=$(echo "$FIX_ONLY" | sed 's/#//;s/,.*//;s/ *//')
        BRANCH="feat/fix-issues-${first_issue}-$(date +%Y-%m-%d)"
        state_set_str "$STATE_DIR" '.branch' "$BRANCH"
    fi

    # 注意：state.json 是本地运行态文件（--resume 时读本地文件即可），不纳入 git 跟踪，
    # 否则会混进 PR diff。详见 orchestrator-prompt.md 的 State.json 操作协议。

    # ---------- 创建 worktree 隔离工作区 ----------
    WORKTREE_PATH=$(worktree_create "$TARGET_REPO" "$RUN_ID" "$BRANCH")
    # 用 state_set_str（jq --arg 安全转义）而不是手拼 JSON 字符串字面量。
    # 若 WORKTREE_PATH/ORIGINAL_PWD 含双引号或反斜杠，手拼的 "\"$VAR\"" 会让
    # state.sh 的 `jq "$path = $value"` 解析失败，set -e 直接退出。详见 #30。
    state_set_str "$STATE_DIR" '.worktree_path' "$WORKTREE_PATH"
    state_set_str "$STATE_DIR" '.original_pwd' "$ORIGINAL_PWD"
    emit_event "📂" "[1/8]" "worktree 已创建: $WORKTREE_PATH"

    # cd 进 worktree，所有后续操作在此进行
    cd "$WORKTREE_PATH"

    echo "✅ 已初始化运行: $RUN_ID"
    echo "   分支: $BRANCH"
    echo "   worktree: $WORKTREE_PATH"
    echo "   范围: $SCOPE_DESC"
fi

# ---------- 恢复模式下 cd 到已有 worktree ----------
if $RESUME; then
    WORKTREE_PATH=$(state_get "$STATE_DIR" '.worktree_path')
    if [ -n "$WORKTREE_PATH" ] && [ "$WORKTREE_PATH" != "null" ] && worktree_exists "$WORKTREE_PATH"; then
        cd "$WORKTREE_PATH"
        emit_event "📂" "" "恢复到 worktree: $WORKTREE_PATH"
    else
        echo "警告: worktree 不存在 ($WORKTREE_PATH)，重新创建"
        BRANCH=$(state_get "$STATE_DIR" '.branch')
        WORKTREE_PATH=$(worktree_create "$TARGET_REPO" "$(state_get "$STATE_DIR" '.run_id')" "$BRANCH")
        state_set_str "$STATE_DIR" '.worktree_path' "$WORKTREE_PATH"
        cd "$WORKTREE_PATH"
    fi
fi

# ---------- mode 提示 ----------
if [ "${DRY_RUN:-false}" = "true" ]; then
    PROMPT_DRY_RUN_NOTE="

注意：这是 --dry-run 模式。只执行到步骤 4（提 issue）后停止，不执行 SDD 修复。
完成步骤 4 后：
1. jq 更新 state.json 的 current_step = 'dry_run_done'
2. 输出 AUTO_LOOP_COMPLETE（脚本侧检测后会跳过 worktree 清理，因为 dry-run 不改代码）
"
    emit_event "🏃" "" "模式: dry-run（只生成 issue，不修复）"
elif [ -n "${FIX_ONLY:-}" ]; then
    PROMPT_FIX_ONLY_NOTE="

注意：这是 --fix-only 模式。跳过步骤 1-4（扫描/分析/提 issue），直接从步骤 5 开始。
issue 来源是 state.target_issues（不是 state.progress.issues_created）。
如果 state.target_issues = [\"all\"]，先在步骤 5 之前用 gh issue list 拉取 open issues 填充。
所有修复打到同一分支，最终一个 PR 关联多个 closes #N。
"
    emit_event "🔧" "" "模式: fix-only（直接修复，目标: ${FIX_ONLY:-}）"
fi

# ---------- 组装 prompt（用 jq 安全注入，避免 sed 特殊字符问题） ----------
RUN_ID=$(state_get "$STATE_DIR" '.run_id')
BRANCH=$(state_get "$STATE_DIR" '.branch')
REQUEST_VAL=$(state_get "$STATE_DIR" '.request')
SCOPE_VAL="$SCOPE_DESC"
# scan_target 优先用本次 CLI 传入的，resume 时从 state.json 读
SCAN_TARGET_VAL="${SCAN_TARGET:-$(state_get "$STATE_DIR" '.scan_target // ""' 2>/dev/null || echo "")}"
# 空时回退到 TARGET_REPO（向后兼容旧 state.json）
[ -z "$SCAN_TARGET_VAL" ] && SCAN_TARGET_VAL="$TARGET_REPO"
# filter 优先用本次 CLI 传入的，resume 时从 state.json 读
FILTER_VAL="${FILTER:-$(state_get "$STATE_DIR" '.filter // ""' 2>/dev/null || echo "")}"

# 读模板，用 jq --raw-input slurp 把整个文件作为一个字符串读取
# （jq -R 默认逐行读，input 只取第一行；--slurp 把所有行合成一个 JSON 字符串）
PROMPT=$(jq --raw-input --slurp \
    --arg req "$REQUEST_VAL" \
    --arg scope "$SCOPE_VAL" \
    --arg branch "$BRANCH" \
    --arg state "$STATE_FILE" \
    --arg repo "$PLUGIN_ROOT" \
    --arg scan_target "$SCAN_TARGET_VAL" \
    --arg filter "$FILTER_VAL" \
    --arg mode "$MODE_VAL" \
    --arg target_issues "$FIX_ONLY" \
    --arg max_issues "$MAX_ISSUES" \
    'gsub("{{REQUEST}}"; $req)
     | gsub("{{SCOPE}}"; $scope)
     | gsub("{{BRANCH}}"; $branch)
     | gsub("{{STATE_FILE}}"; $state)
     | gsub("{{REPO_ROOT}}"; $repo)
     | gsub("{{SCAN_TARGET}}"; $scan_target)
     | gsub("{{FILTER}}"; $filter)
     | gsub("{{MODE}}"; $mode)
     | gsub("{{TARGET_ISSUES}}"; $target_issues)
     | gsub("{{MAX_ISSUES}}"; $max_issues)' \
    < "$PLUGIN_ROOT/skills/auto-loop/orchestrator-prompt.md")

PROMPT="${PROMPT}${PROMPT_DRY_RUN_NOTE:-}${PROMPT_FIX_ONLY_NOTE:-}"

# ---------- 运行 claude -p（用进程替换避免子 shell 隔离） ----------
LOG_FILE="$STATE_DIR/runs/$RUN_ID/stream.log"
mkdir -p "$(dirname "$LOG_FILE")"

# 信号处理：Ctrl+C 写 checkpoint 退出
cleanup_on_signal() {
    echo ""
    emit_event "🛑" "" "收到中断信号，正在保存 checkpoint..."
    # 清理心跳子进程，避免成为孤儿（#22 修复的副效应：信号路径必须显式 kill）
    if [ -n "${HEARTBEAT_PID:-}" ]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
    fi
    # 清理 mktemp 创建的 EXIT_CODE_FILE（#28：信号路径原本跳过 line 289 的 rm -f）
    rm -f "${EXIT_CODE_FILE:-}" 2>/dev/null || true
    echo "运行已暂停。恢复: $0 --resume"
    cd "$ORIGINAL_PWD" 2>/dev/null || true
    exit 130
}
trap cleanup_on_signal INT TERM

# 主调用：tee 写日志 + while read 逐行喂 process_line（主 shell，心跳可见）
emit_event "🚀" "" "启动 Claude 主大脑 (run_id=$RUN_ID)"

# 心跳后台进程：每 30s 检查一次
# TODO(follow-up): emit_status 尚未在此调用——加入后可每 30s 刷新状态行，
# 当前仅 check_heartbeat 做最小存活检测，避免引入未测试的状态行刷新逻辑。
# 注意：子 shell 无法共享父 shell 的 LAST_EVENT_TIME 变量，process_line 会把
# 最新时间戳写入 HEARTBEAT_TIMESTAMP_FILE，子 shell 通过该文件读取（#22 修复）。
HEARTBEAT_TIMESTAMP_FILE="$STATE_DIR/.heartbeat.timestamp"
echo "$(date +%s)" > "$HEARTBEAT_TIMESTAMP_FILE"
(
    while true; do
        sleep 30
        check_heartbeat "[$(state_get "$STATE_DIR" '.current_step' 2>/dev/null || echo '?')]"
    done
) &
HEARTBEAT_PID=$!

LAST_SIGNAL=""
# 进程替换下 $? 拿不到 claude 退出码。
# 关键：在 <() 内把 claude 的退出码直接写入文件，再写结束标记。
# 之前用 `; echo $? > file` 会捕获 tee 的退出码（进程替换的副作用），是 bug。
EXIT_CODE_FILE=$(mktemp)
LOG_FILE_FOR_CLAUDE="$LOG_FILE"

# 主循环：进程替换让 while 在主 shell（LAST_SIGNAL 可见），
# claude 的 stderr 直接重定向到 LOG_FILE（不用 tee，避免退出码干扰）
# 注意：LOG_FILE 在运行中可能被 Claude 删除（它有时会误执行 --cleanup），
# 用 `>> "$LOG_FILE" 2>/dev/null || true` 防止脚本因文件缺失而崩溃
while IFS= read -r line; do
    echo "$line" >> "$LOG_FILE" 2>/dev/null || true
    # 如果 LOG_FILE 被删，重新创建
    [ -f "$LOG_FILE" ] || : > "$LOG_FILE" 2>/dev/null || true
    process_line "$line"
done < <(
    # 导出 AUTO_LOOP_ACTIVE=1 让 guard-auto-loop.sh PreToolUse hook 拦截
    # Claude 删除 .claude/auto-loop/ 或调用 auto-loop.sh 本身的尝试
    AUTO_LOOP_ACTIVE=1 claude -p "$PROMPT" \
        --plugin-dir "$PLUGIN_ROOT" \
        --permission-mode bypassPermissions \
        --output-format stream-json \
        --verbose \
        2>>"$LOG_FILE_FOR_CLAUDE"
    # 紧跟在 claude 后（分号前无其他命令），$? 是 claude 的真实退出码
    echo $? > "$EXIT_CODE_FILE"
)
EXIT_CODE=$(cat "$EXIT_CODE_FILE" 2>/dev/null || echo 0)
EXIT_CODE=${EXIT_CODE:-0}  # claude 被 SIGKILL 时 echo 不执行，文件为空（#14）
rm -f "$EXIT_CODE_FILE"
kill "$HEARTBEAT_PID" 2>/dev/null || true

# 判断结束状态：优先看 LAST_SIGNAL，其次看 state.intervention
INTERVENTION=$(state_get "$STATE_DIR" '.intervention' 2>/dev/null || echo "null")

if [ "$LAST_SIGNAL" = "COMPLETE" ]; then
    emit_event "🏁" "" "Auto-Loop 完成（Claude 输出 COMPLETE）"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        # dry-run 模式保留 worktree，让用户检查 analysis.json/sessions.md（#13）
        emit_event "📦" "" "dry-run 模式：保留 worktree 供检查：$WORKTREE_PATH"
        emit_event "   " "" "恢复全新运行: $0 --resume 会先要求干净工作区"
    else
        # 正常完成 → 清理 worktree
        emit_event "🧹" "" "清理 worktree..."
        worktree_remove "$TARGET_REPO" "$WORKTREE_PATH"
        emit_event "✨" "" "worktree 已清理，当前工作区已恢复"
    fi
    cd "$ORIGINAL_PWD"
elif [ "$LAST_SIGNAL" = "INTERVENTION" ] || { [ "$INTERVENTION" != "null" ] && [ -n "$INTERVENTION" ]; }; then
    echo ""
    echo "⚠️  需要介入: $(echo "$INTERVENTION" | jq -r '.reason // "见 state.json"')"
    echo "恢复: $0 --resume"
    # 介入时保留 worktree
    cd "$ORIGINAL_PWD"
elif [ "$LAST_SIGNAL" = "PUSH_FAILED" ]; then
    emit_event "❌" "" "push 失败，worktree 保留。修复后 --resume"
    cd "$ORIGINAL_PWD"
    exit 1
elif [ "$LAST_SIGNAL" = "STATE_ERROR" ]; then
    emit_event "❌" "" "state.json 损坏，手动检查 $STATE_FILE"
    cd "$ORIGINAL_PWD"
    exit 1
else
    emit_event "❌" "" "Claude 退出码 $EXIT_CODE，未输出完成信号。state 已保存。恢复: $0 --resume"
    # 失败时保留 worktree 便于排查
    cd "$ORIGINAL_PWD"
    exit "$EXIT_CODE"
fi
