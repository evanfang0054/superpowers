#!/usr/bin/env bash
# handoff-schema.sh - 必填字段 + ref 校验规则
#
# 各 stage 的必填字段；校验函数返回 0 通过 / 1 失败（stderr 打印原因）。
# 依赖：yaml-parse.sh 已被 source；$ROOT 由调用方 export。

# spec stage 必填字段
HANDOFF_SPEC_FIELDS="spec_topic decision_summary design_approved user_approved_at"
# plan stage 必填字段
HANDOFF_PLAN_FIELDS="spec_ref spec_topic task_count estimated_phases dod"
# task stage 必填字段
HANDOFF_TASK_FIELDS="plan_ref implemented_tasks tests_passed evidence_paths"

# handoff_check_required <stage> <file>
# 用已加载的 YAML_FM（YAML_FM_CACHE）校验
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
        # $dir/$ref 解析（plan 在 plans/，spec_ref 形如 ../specs/x.md）
        local target="$dir/$ref"
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
      if [ -f "$idx" ] && ! grep -Fq -- "- $topic →" "$idx" 2>/dev/null; then
        echo "validate-handoff: spec_topic '$topic' not found in docs/agent-harness/index.md" >&2
        rc=1
      fi
    fi
  fi

  # domain_terms advisory check (spec stage only) — advisory: non-blocking
  # If spec frontmatter has domain_terms, verify each term appears as ## heading
  # in CONTEXT.md. Advisory only: WARNING to stderr, does not affect return code.
  if [ "$stage" = "spec" ]; then
    local terms; terms=$(yaml_parse_get "domain_terms")
    if [ -n "$terms" ]; then
      local context_md="$ROOT/CONTEXT.md"
      if [ ! -f "$context_md" ]; then
        echo "validate-handoff: WARNING — domain_terms specified but CONTEXT.md not found at $context_md" >&2
      else
        # Parse YAML inline flow sequence [Term1, Term2, Term3]
        # Strip brackets, split on comma, trim whitespace.
        # Use while-read (NOT 'for term in $term_list') so multi-word terms
        # like "Line Item" are not re-split on spaces (GDD L2-6-G1-A2).
        local term_list
        term_list=$(printf '%s' "$terms" | tr -d '[]' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$')
        printf '%s\n' "$term_list" | while IFS= read -r term; do
          [ -z "$term" ] && continue
          if ! grep -q "^## ${term}$" "$context_md" 2>/dev/null; then
            echo "validate-handoff: WARNING — domain_term '$term' not found as ## heading in CONTEXT.md" >&2
          fi
        done
      fi
    fi
  fi
  return $rc
}
