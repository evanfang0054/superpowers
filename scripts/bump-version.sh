#!/usr/bin/env bash
#
# bump-version.sh — bump version numbers across all declared files,
# with drift detection and repo-wide audit for missed files.
#
# 双面 CLI: 同时服务人类（TTY 友好的彩色文本）与 agent（JSON envelope 契约）。
# 默认行为保持人类体验；加 --json 切换为 agent 路径，stdout 只输出单一 envelope。
#
# Usage (人类):
#   bump-version.sh <new-version>           交互式输入 changelog，bump + 写 RELEASE-NOTES
#   bump-version.sh --check                 报告当前版本，检测 drift
#   bump-version.sh --audit                 check + grep 仓库找未声明文件
#
# Usage (agent):
#   bump-version.sh bump <ver> --json --yes --notes "..." [--dry-run]
#   bump-version.sh check --json
#   bump-version.sh audit --json
#   bump-version.sh schema                  自省命令清单
#
# 退出码:
#   0 成功
#   1 脚本错误（bug / 配置错）
#   2 数据状态非零退出（drift / undeclared / aborted）— agent 可分支，非 bug
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/.version-bump.json"
RELEASE_NOTES="$REPO_ROOT/RELEASE-NOTES.md"

# --- envelope helpers (agent-native 路径) ---

# emit_ok <command> <data-json> [--extra key=val ...]
# 输出成功 envelope 到 stdout
emit_ok() {
  local cmd="$1" data="$2"
  printf '{"ok":true,"command":"%s","data":%s}\n' "$cmd" "$data"
}

# emit_err <code> <message> <hint>
# 输出错误 envelope 到 stdout，退出码 1
emit_err() {
  local code="$1" msg="$2" hint="${3:-}"
  local hint_json
  if [ -n "$hint" ]; then
    hint_json=$(printf '%s' "$hint" | jq -Rs '.')
  else
    hint_json='""'
  fi
  printf '{"ok":false,"error":{"code":"%s","message":%s,"hint":%s}}\n' \
    "$code" \
    "$(printf '%s' "$msg" | jq -Rs '.')" \
    "$hint_json"
}

# --- json helpers ---

read_json_field() {
  local file="$1" field="$2"
  local jq_path
  jq_path=$(echo "$field" | sed -E 's/\.([0-9]+)/[\1]/g' | sed 's/^/./' | sed 's/\.\././g')
  jq -r "$jq_path" "$file"
}

write_json_field() {
  local file="$1" field="$2" value="$3"
  local jq_path
  jq_path=$(echo "$field" | sed -E 's/\.([0-9]+)/[\1]/g' | sed 's/^/./' | sed 's/\.\././g')
  local tmp="${file}.tmp"
  jq "$jq_path = \"$value\"" "$file" > "$tmp" && mv "$tmp" "$file"
}

declared_files() {
  jq -r '.files[] | "\(.path)\t\(.field)"' "$CONFIG"
}

audit_excludes() {
  jq -r '.audit.exclude[]' "$CONFIG" 2>/dev/null
}

# --- config guard ---

guard_config() {
  local json_mode="${1:-0}"
  if [[ ! -f "$CONFIG" ]]; then
    if [ "$json_mode" = "1" ]; then
      emit_err "missing_config" ".version-bump.json not found at $CONFIG" \
        "ensure .version-bump.json exists at repo root"
    else
      echo "error: .version-bump.json not found at $CONFIG" >&2
    fi
    exit 1
  fi
}

# --- changelog 获取：agent 走参数/文件，人类走 TTY ---

# get_changelog <source> <value>
#   source=args: value 即 changelog 文本
#   source=file:  value=- 表示 stdin，否则是文件路径
#   source=tty:   TTY 交互式输入
get_changelog() {
  local source="$1" value="$2"
  case "$source" in
    args)
      printf '%s\n' "$value"
      ;;
    file)
      if [ "$value" = "-" ]; then cat
      else
        [ -f "$value" ] || { emit_err "changelog_file_missing" "notes file not found: $value" ""; exit 1; }
        cat "$value"
      fi
      ;;
    tty)
      get_user_changelog_tty
      ;;
  esac
}

# 人类 TTY 交互（无 TTY 时报错，避免 agent 误入）
get_user_changelog_tty() {
  if [ ! -t 0 ]; then
    emit_err "not_a_tty" \
      "interactive changelog requires a TTY; agent callers must pass --notes or --notes-file" \
      "use: bump-version.sh bump <ver> --yes --notes \"...\""
    exit 1
  fi
  echo "" >&2
  echo "📝 请输入本次更新的内容:" >&2
  echo "   每行一条记录，直接按 Enter（空行）结束输入" >&2
  echo "" >&2

  local changes=""
  while IFS= read -r line; do
    [ -z "$line" ] && break
    if [[ "$line" != -* ]]; then
      line="- $line"
    fi
    changes="${changes}${line}"$'\n'
  done
  printf '%s' "$changes"
}

# --- RELEASE-NOTES 更新 ---

update_release_notes() {
  local new_version="$1" changelog="$2" json_mode="${3:-0}"

  if [ -z "$changelog" ]; then
    changelog="- Minor updates"
  fi

  local date_str
  date_str=$(date "+%Y-%m-%d")

  local new_entry="## v$new_version ($date_str)

### Changes

$changelog
"

  local header="# Agent Harness Release Notes"
  local existing_content
  if [ -f "$RELEASE_NOTES" ]; then
    existing_content=$(tail -n +3 "$RELEASE_NOTES" 2>/dev/null || true)
  else
    existing_content=""
  fi

  printf '%s\n\n' "$header" > "$RELEASE_NOTES"
  printf '%s\n' "$new_entry" >> "$RELEASE_NOTES"
  printf '%s\n' "$existing_content" >> "$RELEASE_NOTES"

  if [ "$json_mode" = "0" ]; then
    echo "  ✓ Updated RELEASE-NOTES.md"
  fi
}

# --- commands ---

# check: 报告所有声明文件的当前版本
# 退出码: 0=in sync, 2=drift/missing
cmd_check() {
  local json_mode="${1:-0}"

  local has_drift=0
  local versions=()
  local rows_json="[]"

  while IFS=$'\t' read -r path field; do
    local fullpath="$REPO_ROOT/$path"
    if [[ ! -f "$fullpath" ]]; then
      if [ "$json_mode" = "0" ]; then
        printf "  %-45s  MISSING\n" "$path ($field)"
      fi
      rows_json=$(echo "$rows_json" | jq --arg p "$path" --arg f "$field" --arg v "" --arg st "missing" \
        '. + [{"path":$p,"field":$f,"version":$v,"status":$st}]')
      has_drift=1
      continue
    fi
    local ver
    ver=$(read_json_field "$fullpath" "$field")
    versions+=("$ver")
    rows_json=$(echo "$rows_json" | jq --arg p "$path" --arg f "$field" --arg v "$ver" --arg st "ok" \
      '. + [{"path":$p,"field":$f,"version":$v,"status":$st}]')
    if [ "$json_mode" = "0" ]; then
      printf "  %-45s  %s\n" "$path ($field)" "$ver"
    fi
  done < <(declared_files)

  local unique
  unique=$(printf '%s\n' "${versions[@]}" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  local status="in_sync"
  local current_version="${versions[0]:-}"

  if [[ "$unique" -gt 1 ]]; then
    status="drift"
    has_drift=1
  fi

  if [ "$json_mode" = "0" ]; then
    echo ""
    if [[ "$unique" -gt 1 ]]; then
      echo "DRIFT DETECTED — versions are not in sync:"
      printf '%s\n' "${versions[@]}" | sort | uniq -c | sort -rn | while read -r count ver; do
        echo "  $ver ($count files)"
      done
    else
      echo "All declared files are in sync at ${versions[0]:-<none>}"
    fi
  fi

  if [ "$json_mode" = "1" ]; then
    local data
    data=$(jq -n --argjson rows "$rows_json" --arg st "$status" --arg cv "$current_version" \
      '{files:$rows, status:$st, current_version:$cv}')
    emit_ok "check" "$data"
  fi

  if [ "$has_drift" = "1" ]; then exit 2; fi
}

# audit: check + grep 仓库找未声明文件
cmd_audit() {
  local json_mode="${1:-0}"

  # 先跑 check 收集状态（不 emit）
  local check_output
  if [ "$json_mode" = "1" ]; then
    check_output=$(cmd_check_silent) || true
  else
    cmd_check || true
    echo ""
    check_output=""
  fi

  local current_version
  current_version=$(
    while IFS=$'\t' read -r path field; do
      local fullpath="$REPO_ROOT/$path"
      [[ -f "$fullpath" ]] && read_json_field "$fullpath" "$field"
    done < <(declared_files) | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
  )

  if [[ -z "$current_version" ]]; then
    if [ "$json_mode" = "1" ]; then
      emit_err "undetermined_version" "could not determine current version" \
        "ensure all declared files have a version field"
    else
      echo "error: could not determine current version" >&2
    fi
    exit 1
  fi

  if [ "$json_mode" = "0" ]; then
    echo "Audit: scanning repo for version string '$current_version'..."
    echo ""
  fi

  local -a exclude_args=()
  while IFS= read -r pattern; do
    exclude_args+=("--exclude=$pattern" "--exclude-dir=$pattern")
  done < <(audit_excludes)
  exclude_args+=("--exclude-dir=.git" "--exclude-dir=node_modules" "--binary-files=without-match")

  local -a declared_paths=()
  while IFS=$'\t' read -r path _field; do
    declared_paths+=("$path")
  done < <(declared_files)

  local undeclared_json="[]"
  local found_undeclared=0
  while IFS= read -r match; do
    local match_file rel_path
    match_file=$(echo "$match" | cut -d: -f1)
    rel_path="${match_file#$REPO_ROOT/}"

    local is_declared=0
    for dp in "${declared_paths[@]}"; do
      if [[ "$rel_path" == "$dp" ]]; then
        is_declared=1
        break
      fi
    done

    if [[ "$is_declared" -eq 0 ]]; then
      if [ "$json_mode" = "0" ] && [[ "$found_undeclared" -eq 0 ]]; then
        echo "UNDECLARED files containing '$current_version':"
      fi
      found_undeclared=1
      if [ "$json_mode" = "0" ]; then
        echo "  $match"
      else
        local lineno content
        lineno=$(echo "$match" | cut -d: -f2)
        content=$(echo "$match" | cut -d: -f3-)
        undeclared_json=$(echo "$undeclared_json" | jq --arg p "$rel_path" --argjson n "$lineno" --arg c "$content" \
          '. + [{"path":$p,"line":$n,"content":$c}]')
      fi
    fi
  done < <(grep -rn "${exclude_args[@]}" -F "$current_version" "$REPO_ROOT" 2>/dev/null || true)

  if [ "$json_mode" = "0" ]; then
    if [[ "$found_undeclared" -eq 0 ]]; then
      echo "No undeclared files contain the version string. All clear."
    else
      echo ""
      echo "Review the above files — if they should be bumped, add them to .version-bump.json"
      echo "If they should be skipped, add them to the audit.exclude list."
    fi
  fi

  if [ "$json_mode" = "1" ]; then
    local status="clean"
    [ "$found_undeclared" = "1" ] && status="undeclared_found"
    local data
    data=$(jq -n --arg v "$current_version" --arg st "$status" --argjson u "$undeclared_json" \
      '{version:$v, status:$st, undeclared:$u}')
    emit_ok "audit" "$data"
  fi

  # 仅在 agent (json) 模式下用 exit 2 区分数据状态；人类模式保持旧 exit 0 语义以向后兼容
  if [ "$found_undeclared" = "1" ] && [ "$json_mode" = "1" ]; then exit 2; fi
}

# check 的静默版（json 模式 audit 内部用）
cmd_check_silent() {
  cmd_check 1
}

# bump: 写入新版本到所有声明文件 + 更新 RELEASE-NOTES
# 参数:
#   $1 = new_version
#   $2 = json_mode (0/1)
#   $3 = dry_run (0/1)
#   $4 = yes (0/1) — agent 显式确认
#   $5 = changelog source (args/file/none)
#   $6 = changelog value
cmd_bump() {
  local new_version="$1"
  local json_mode="${2:-0}"
  local dry_run="${3:-0}"
  local yes_flag="${4:-0}"
  local notes_source="${5:-none}"
  local notes_value="${6:-}"

  # 校验 semver-ish
  if ! echo "$new_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    if [ "$json_mode" = "1" ]; then
      emit_err "invalid_version" "'$new_version' doesn't look like a version (expected X.Y.Z)" \
        "pass a semver string like 6.3.0"
    else
      echo "error: '$new_version' doesn't look like a version (expected X.Y.Z)" >&2
    fi
    exit 1
  fi

  # changelog 获取
  local changelog=""
  case "$notes_source" in
    args)  changelog=$(get_changelog args "$notes_value") ;;
    file)  changelog=$(get_changelog file "$notes_value") ;;
    tty)
      # 人类交互：dry_run 时跳过 changelog 收集
      if [ "$dry_run" = "0" ]; then
        changelog=$(get_changelog tty "")
      fi
      ;;
    none)
      # 无 changelog 来源：dry_run 允许，否则人类默认 TTY、agent 报错
      if [ "$dry_run" = "1" ]; then
        changelog=""
      elif [ "$yes_flag" = "1" ]; then
        # agent 显式 --yes 但未传 notes：允许，用默认条目
        changelog=""
      else
        changelog=$(get_changelog tty "")
      fi
      ;;
  esac

  # 写入前确认（agent --yes 跳过，dry_run 跳过）
  if [ "$dry_run" = "0" ] && [ "$yes_flag" = "0" ]; then
    if [ ! -t 0 ]; then
      if [ "$json_mode" = "1" ]; then
        emit_err "not_a_tty" \
          "non-interactive invocation requires --yes for writes" \
          "add --yes to confirm the write, or use --dry-run to preview"
      else
        echo "error: non-interactive shell detected; pass --yes or use TTY" >&2
      fi
      exit 1
    fi
    # 人类 TTY 确认
    echo "" >&2
    echo "About to bump version to $new_version across $(declared_files | wc -l | tr -d ' ') files." >&2
    read -r -p "Proceed? [y/N] " confirm >&2
    case "$confirm" in
      y|Y|yes|YES) ;;
      *)
        if [ "$json_mode" = "1" ]; then
          emit_ok "bump" '{"aborted":true}'
        fi
        exit 2
        ;;
    esac
  fi

  if [ "$json_mode" = "0" ] && [ "$dry_run" = "0" ]; then
    echo "Bumping all declared files to $new_version..."
    echo ""
  elif [ "$json_mode" = "0" ] && [ "$dry_run" = "1" ]; then
    echo "DRY RUN — would bump to $new_version (no files written)"
    echo ""
  fi

  local changes_json="[]"
  while IFS=$'\t' read -r path field; do
    local fullpath="$REPO_ROOT/$path"
    if [[ ! -f "$fullpath" ]]; then
      if [ "$json_mode" = "0" ]; then
        echo "  SKIP (missing): $path"
      fi
      changes_json=$(echo "$changes_json" | jq --arg p "$path" --arg f "$field" --arg st "missing" \
        '. + [{"path":$p,"field":$f,"status":$st}]')
      continue
    fi
    local old_ver
    old_ver=$(read_json_field "$fullpath" "$field")
    if [ "$dry_run" = "0" ]; then
      write_json_field "$fullpath" "$field" "$new_version"
    fi
    changes_json=$(echo "$changes_json" \
      | jq --arg p "$path" --arg f "$field" --arg o "$old_ver" --arg n "$new_version" --arg st "bumped" \
        '. + [{"path":$p,"field":$f,"old":$o,"new":$n,"status":$st}]')
    if [ "$json_mode" = "0" ]; then
      printf "  %-45s  %s -> %s\n" "$path ($field)" "$old_ver" "$new_version"
    fi
  done < <(declared_files)

  # RELEASE-NOTES
  if [ "$dry_run" = "0" ]; then
    update_release_notes "$new_version" "$changelog" "$json_mode"
  elif [ "$json_mode" = "0" ]; then
    echo "  (skip) would update RELEASE-NOTES.md"
  fi

  if [ "$json_mode" = "1" ]; then
    local data
    data=$(jq -n --arg v "$new_version" --argjson dr "$dry_run" --argjson c "$changes_json" \
      '{new_version:$v, dry_run:($dr == 1), files_changed:$c}')
    emit_ok "bump" "$data"
  elif [ "$dry_run" = "1" ]; then
    echo ""
    echo "Dry run complete. Re-run without --dry-run to apply."
  else
    echo ""
    echo "Done. Running audit to check for missed files..."
    echo ""
    cmd_audit 0
  fi
}

# schema: 自省命令清单（agent 跑陌生命令前先查）
cmd_schema() {
  cat <<'JSON'
{
  "name": "bump-version",
  "description": "Bump version numbers across declared files with drift detection",
  "commands": {
    "bump": {
      "args": [{"name": "version", "required": true, "format": "X.Y.Z"}],
      "flags": {
        "--json": "output JSON envelope to stdout",
        "--dry-run": "preview changes without writing",
        "--yes": "skip confirmation (required for non-TTY agent calls)",
        "--notes <text>": "changelog from inline string (agent path)",
        "--notes-file <path|->": "changelog from file or stdin"
      },
      "exit_codes": {"0": "success", "1": "error", "2": "aborted or data state requires attention"}
    },
    "check": {
      "flags": {"--json": "output JSON envelope"},
      "exit_codes": {"0": "in sync", "1": "error", "2": "drift detected"}
    },
    "audit": {
      "flags": {"--json": "output JSON envelope"},
      "exit_codes": {"0": "clean", "1": "error", "2": "undeclared files found"}
    },
    "schema": {"description": "self-introspection of command list"}
  },
  "envelope_success": {"ok": true, "command": "<cmd>", "data": {}},
  "envelope_error": {"ok": false, "error": {"code": "<snake_case>", "message": "...", "hint": "..."}},
  "error_codes": [
    "invalid_version", "missing_config", "file_not_found",
    "drift_detected", "undeclared_files", "aborted", "not_a_tty",
    "changelog_file_missing", "undetermined_version"
  ]
}
JSON
}

# --- 人类向后兼容入口 ---

cmd_bump_legacy() {
  local new_version="$1"
  # 旧行为：TTY 交互式 changelog，无 --yes、无 --json
  cmd_bump "$new_version" 0 0 0 tty ""
}

# --- arg parser ---

# 解析新式子命令与标志，回填全局变量后由各 cmd_* 处理
parse_and_dispatch() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    bump)
      local json_mode=0 dry_run=0 yes_flag=0 notes_source=none notes_value=""
      local new_version=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --json) json_mode=1; shift ;;
          --dry-run) dry_run=1; shift ;;
          --yes) yes_flag=1; shift ;;
          --notes)
            notes_source=args; notes_value="${2:-}"
            [ -z "$notes_value" ] && { emit_err "invalid_args" "--notes requires a value" ""; exit 1; }
            shift 2 ;;
          --notes-file)
            notes_source=file; notes_value="${2:-}"
            [ -z "$notes_value" ] && { emit_err "invalid_args" "--notes-file requires a value" ""; exit 1; }
            shift 2 ;;
          --*) emit_err "unknown_flag" "unknown flag: $1" "run: bump-version.sh schema"; exit 1 ;;
          *)
            [ -n "$new_version" ] && { emit_err "invalid_args" "unexpected extra arg: $1" ""; exit 1; }
            new_version="$1"; shift ;;
        esac
      done
      [ -z "$new_version" ] && { emit_err "invalid_args" "missing version" "usage: bump-version.sh bump <X.Y.Z> [--json --yes]"; exit 1; }
      guard_config "$json_mode"
      cmd_bump "$new_version" "$json_mode" "$dry_run" "$yes_flag" "$notes_source" "$notes_value"
      ;;
    check)
      local json_mode=0
      while [ $# -gt 0 ]; do
        case "$1" in
          --json) json_mode=1; shift ;;
          *) emit_err "unknown_flag" "unknown flag: $1" ""; exit 1 ;;
        esac
      done
      guard_config "$json_mode"
      cmd_check "$json_mode"
      ;;
    audit)
      local json_mode=0
      while [ $# -gt 0 ]; do
        case "$1" in
          --json) json_mode=1; shift ;;
          *) emit_err "unknown_flag" "unknown flag: $1" ""; exit 1 ;;
        esac
      done
      guard_config "$json_mode"
      cmd_audit "$json_mode"
      ;;
    schema)
      cmd_schema
      ;;
    "")
      echo "Usage: bump-version.sh <command|new-version> [flags]" >&2
      echo "" >&2
      echo "Commands:" >&2
      echo "  bump <ver> [--dry-run] [--yes] [--notes \"...\"]   bump version" >&2
      echo "  check [--json]                                     report versions, detect drift" >&2
      echo "  audit [--json]                                     check + grep repo for undeclared" >&2
      echo "  schema                                             self-introspection" >&2
      echo "" >&2
      echo "Legacy (backward-compatible):" >&2
      echo "  <new-version>     interactive bump (TTY)" >&2
      echo "  --check           alias for 'check'" >&2
      echo "  --audit           alias for 'audit'" >&2
      echo "  --help, -h        show this help" >&2
      exit 0
      ;;
    *)
      echo "error: unknown command '$cmd'" >&2
      echo "run: bump-version.sh schema" >&2
      exit 1
      ;;
  esac
}

# --- main ---

main() {
  local first="${1:-}"

  # Legacy 短选项向后兼容
  case "$first" in
    --check)
      guard_config 0
      cmd_check 0
      ;;
    --audit)
      guard_config 0
      cmd_audit 0
      ;;
    --help|-h)
      parse_and_dispatch ""
      ;;
    --*)
      echo "error: unknown flag '$first'" >&2
      exit 1
      ;;
    *)
      if [ -z "$first" ]; then
        parse_and_dispatch ""
        return
      fi
      # 裸版本号 → 旧式人类交互入口；子命令 → 新式入口
      if echo "$first" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
        guard_config 0
        cmd_bump_legacy "$first"
      else
        parse_and_dispatch "$@"
      fi
      ;;
  esac
}

main "$@"
