#!/usr/bin/env bash
# Universal headless runner for skill-behavior tests.
# Usage (after `source`):
#   run_skill <skill-name> <prompt-file> [max-turns]
# After return, $LOG_FILE points to the captured stream-json log.

# macOS 兼容 timeout（复用 tests/claude-code/run-skill-tests.sh 的 fallback）
# 注意：perl `alarm` 默认退出码 142 (128+14)，必须捕获 SIGALRM 并 exit 124，
# 否则上游 run-skill-tests.sh 的 `[ $exit_code -eq 124 ]` 判断永远不匹配。
if ! command -v timeout &> /dev/null; then
    if command -v gtimeout &> /dev/null; then
        timeout() { gtimeout "$@"; }
    else
        timeout() {
            local dur="$1"; shift
            perl -e '
                $SIG{ALRM} = sub { exit 124 };
                alarm shift @ARGV;
                my $rc = system(@ARGV);
                exit($rc >> 8) if $rc != -1;
                exit 127;
            ' "$dur" "$@"
        }
    fi
fi

# Resolve repo root (skill-behavior is three levels below root)
_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_BEHAVIOR_DIR="$(cd "$_HELPERS_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_BEHAVIOR_DIR/../.." && pwd)"

# check_claude_available: exit early if claude CLI missing
check_claude_available() {
    if ! command -v claude &> /dev/null; then
        echo "ERROR: Claude Code CLI not found. Install from https://code.claude.com" >&2
        exit 1
    fi
}

# run_skill <skill-name> <prompt-file> [max-turns]
run_skill() {
    local skill_name="$1"
    local prompt_file="$2"
    local max_turns="${3:-3}"

    check_claude_available

    if [ -z "$skill_name" ] || [ -z "$prompt_file" ] || [ ! -f "$prompt_file" ]; then
        echo "ERROR: run_skill <skill-name> <prompt-file> [max-turns]" >&2
        echo "  prompt_file '$prompt_file' missing or invalid" >&2
        exit 1
    fi

    local prompt
    prompt=$(cat "$prompt_file")

    local output_root="/tmp/agent-harness-tests"
    local output_dir
    mkdir -p "$output_root"
    output_dir=$(mktemp -d "$output_root/skill-behavior-${skill_name}.XXXXXX")

    # 隔离 HOME 避免用户配置污染（参考 explicit-skill-requests/run-test.sh）
    local isolated_home
    isolated_home=$(mktemp -d)
    local project_dir
    project_dir=$(mktemp -d)

    LOG_FILE="$output_dir/claude-output.json"

    echo "=== Skill Behavior Test ===" >&2
    echo "Skill: $skill_name" >&2
    echo "Prompt file: $prompt_file" >&2
    echo "Max turns: $max_turns" >&2
    echo "Log: $LOG_FILE" >&2
    echo "" >&2

    cd "$project_dir"
    HOME="$isolated_home" timeout 300 claude -p "$prompt" \
        --plugin-dir "$REPO_ROOT" \
        --permission-mode bypassPermissions \
        --max-turns "$max_turns" \
        --output-format stream-json \
        --verbose \
        > "$LOG_FILE" 2>&1 || true

    # stream-json 为行缓冲，claude 退出后可能仍有内核页缓存未刷盘；
    # 给文件系统 2 秒时间完成最终 flush
    sleep 2
    cd "$SKILL_BEHAVIOR_DIR"
    # 注意：不清理 isolated_home 和 project_dir，供事后排查
    echo "Skill run complete. Log: $LOG_FILE" >&2
}

# Export LOG_FILE 让 source 方可见
export LOG_FILE
