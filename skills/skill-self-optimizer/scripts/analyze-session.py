#!/usr/bin/env python3
"""
Analyze extracted session data and generate optimization report.

Usage:
    python analyze-session.py --input <extracted.json> [--output <report.md>]
"""

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path


IGNORED_FAILURE_CATEGORIES = {
    "invalid_read_pages_placeholder",
}


def classify_tool_failure(tool: str, error: str, tool_input: dict) -> str:
    """Classify failure mode for a tool call."""
    error_lower = error.lower()

    if tool == "Read" and tool_input.get("pages", None) == "" and "invalid pages parameter" in error_lower:
        return "invalid_read_pages_placeholder"
    if tool == "Skill" and "setup-ralph-loop.sh" in error:
        return "skill_shell_wrapper_failure"
    if tool == "Skill" and "orchestrator" in error_lower:
        return "skill_orchestrator_wrapper_failure"
    if "invalid" in error_lower or "expected one argument" in error_lower:
        return "invalid_tool_input"
    if "not found" in error_lower:
        return "missing_resource"
    if "shell command failed" in error_lower:
        return "shell_wrapper_failure"
    if "hook" in error_lower:
        return "hook_runtime_failure"
    if tool == "Skill":
        return "skill_runtime_failure"
    if any(marker in error_lower for marker in ("traceback", "exception", "runtime")):
        return "runtime_failure"
    return "unknown_failure"



def is_expected_test_failure(tool_call: dict, messages: list[dict]) -> bool:
    """Detect red-phase test failures that should not be treated as severe execution errors."""
    if tool_call.get("tool") != "Bash" or tool_call.get("success", True):
        return False

    command = tool_call.get("input", {}).get("command", "").lower()
    if not any(marker in command for marker in (" test", "pytest", "vitest", "bun test")):
        return False

    relevant_messages = [
        message for message in messages
        if message.get("message_origin_hint") not in {"hook_feedback", "resume_summary", "skill_payload", "empty"}
    ]
    for message in reversed(relevant_messages[-6:]):
        content = message.get("content", "").lower()
        if any(marker in content for marker in ("红灯", "按预期失败", "failing test first", "verify it fails")):
            return True
    return False



def summarize_tool_input(tool_input: dict) -> str:
    """Create a short, readable summary of tool input for reports."""
    if not tool_input:
        return "{}"

    priority_keys = [
        "skill", "file_path", "session_id", "project_path", "path", "pattern", "command", "pages",
    ]
    parts = []
    for key in priority_keys:
        value = tool_input.get(key)
        if value in (None, "", [], {}):
            continue
        rendered = repr(value)
        if len(rendered) > 60:
            rendered = rendered[:57] + "..."
        parts.append(f"{key}={rendered}")
        if len(parts) >= 3:
            break

    if not parts:
        return "{...}"
    return ", ".join(parts)

def build_failure_suggestion(tool: str, category: str, sample_error: str) -> str:
    """Generate concrete optimization suggestions for known failure classes."""
    if category == "invalid_read_pages_placeholder":
        return "Ignore empty `pages` placeholders for non-PDF Read calls, or normalize them out during extraction"
    if category in {"skill_shell_wrapper_failure", "skill_orchestrator_wrapper_failure"}:
        return "Inspect the skill shell wrapper/template invocation; validate fenced shell blocks and interpolated arguments before launch"
    if category == "invalid_tool_input":
        return f"Validate {tool} inputs before calling the tool"
    if category == "missing_resource":
        return "Check file/session/project paths before execution"
    if category == "shell_wrapper_failure":
        return "Capture the wrapped shell command separately and surface the failing template or script path"
    return f"Review {tool} failure handling and add pre-flight validation"


def analyze_tool_usage(tool_calls: list, messages: list | None = None) -> dict:
    """Analyze tool usage patterns."""
    messages = messages or []
    if not tool_calls:
        return {"total": 0, "success_rate": 1.0, "by_tool": {}, "failures": []}

    total = len(tool_calls)
    successful = len([t for t in tool_calls if t.get("success", True)])

    by_tool = defaultdict(lambda: {"total": 0, "success": 0, "failures": []})
    for tc in tool_calls:
        tool = tc.get("tool", "unknown")
        by_tool[tool]["total"] += 1
        if tc.get("success", True):
            by_tool[tool]["success"] += 1
        else:
            error = tc.get("error", "Unknown error")
            category = classify_tool_failure(tool, error, tc.get("input", {}))
            if is_expected_test_failure(tc, messages):
                category = "expected_test_failure"
            by_tool[tool]["failures"].append({
                "error": error,
                "input": tc.get("input", {}),
                "category": category,
                "id": tc.get("id"),
                "timestamp": tc.get("timestamp"),
                "input_summary": summarize_tool_input(tc.get("input", {})),
            })

    tool_stats = {}
    for tool, stats in by_tool.items():
        rate = stats["success"] / stats["total"] if stats["total"] > 0 else 1.0
        tool_stats[tool] = {
            "total": stats["total"],
            "success": stats["success"],
            "success_rate": round(rate, 2),
            "failure_count": len(stats["failures"]),
        }

    unique_failures = []
    seen = set()
    for tool, stats in by_tool.items():
        for failure in stats["failures"]:
            key = (tool, failure["category"])
            if key in seen:
                continue
            seen.add(key)
            related_failures = [f for f in stats["failures"] if f["category"] == failure["category"]]
            sample_failure = related_failures[0]
            if failure["category"] in IGNORED_FAILURE_CATEGORIES:
                continue
            unique_failures.append({
                "tool": tool,
                "count": len(related_failures),
                "category": failure["category"],
                "errors": [f["error"][:100] for f in related_failures[:3]],
                "suggestion": build_failure_suggestion(tool, failure["category"], sample_failure.get("error", "")),
                "evidence": {
                    "tool_use_id": sample_failure.get("id"),
                    "timestamp": sample_failure.get("timestamp"),
                    "input_summary": sample_failure.get("input_summary"),
                },
            })

    return {
        "total": total,
        "successful": successful,
        "success_rate": round(successful / total, 2) if total > 0 else 1.0,
        "by_tool": tool_stats,
        "repeated_failures": unique_failures,
    }


def detect_patterns(messages: list, tool_calls: list) -> list:
    """Detect problematic patterns in the session."""
    patterns = []
    
    # 1. Repeated tool failures
    tool_failures = defaultdict(list)
    for i, tc in enumerate(tool_calls):
        if not tc.get("success", True):
            tool_failures[tc.get("tool", "unknown")].append(i)
    
    for tool, indices in tool_failures.items():
        if len(indices) >= 3:
            # Check if consecutive
            consecutive = sum(1 for i in range(len(indices)-1) if indices[i+1] - indices[i] <= 2)
            if consecutive >= 2:
                patterns.append({
                    "type": "repeated_failures",
                    "severity": "high",
                    "description": f"{tool} failed {len(indices)} times with consecutive failures",
                    "suggestion": f"Check inputs before calling {tool}; add validation or pre-flight checks",
                })
    
    # 2. User corrections (looking for patterns like "no, I meant...", "that's wrong")
    correction_phrases = [
        "no,", "that's wrong", "not what i", "i meant", "incorrect",
        "不对", "错了", "不是这样", "我的意思是"
    ]
    user_corrections = 0
    for msg in messages:
        if msg["role"] == "user":
            content_lower = msg.get("content", "").lower()
            if any(phrase in content_lower for phrase in correction_phrases):
                user_corrections += 1
    
    if user_corrections >= 2:
        patterns.append({
            "type": "user_corrections",
            "severity": "medium",
            "description": f"User corrected {user_corrections} times during session",
            "suggestion": "Ask clarifying questions before taking action; confirm understanding",
        })
    
    # 3. Long response without tool use (might indicate overthinking)
    assistant_msgs = [m for m in messages if m["role"] == "assistant"]
    long_responses = 0
    for msg in assistant_msgs:
        content = msg.get("content", "")
        if len(content) > 3000:
            long_responses += 1
    
    if long_responses >= 3:
        patterns.append({
            "type": "verbose_responses",
            "severity": "low",
            "description": f"{long_responses} very long responses (>3000 chars)",
            "suggestion": "Consider being more concise; break into smaller steps",
        })
    
    # 4. High token consumption pattern
    # (This would need token data which might not be in all extractions)
    
    return patterns


def is_noise_message(content: str) -> bool:
    """Ignore command payloads and hook/system wrappers when analyzing triggers."""
    stripped = content.strip().lower()
    if not stripped:
        return True
    if stripped.startswith("stop hook feedback:"):
        return True
    if stripped.startswith("this session is being continued from a previous conversation"):
        return True

    noise_markers = (
        "<command-message>",
        "<command-name>",
        "<command-args>",
        "<local-command-caveat>",
        "base directory for this skill:",
        "# test-driven development",
        "# systematic debugging",
    )
    return any(marker in stripped for marker in noise_markers)



def detect_trigger_confidence(content: str, trigger: str) -> str:
    """Estimate confidence that a trigger should have fired."""
    strong_signals = ["failing", "error", "bug", "broken", "write tests", "add tests"]
    signal_count = sum(1 for signal in strong_signals if signal in content)
    if trigger in {"write tests", "add tests"} or signal_count >= 2:
        return "high"
    if signal_count == 1:
        return "medium"
    return "low"



def analyze_skill_usage(messages: list, skills_used: list) -> dict:
    """Analyze skill triggering patterns."""
    potential_triggers = {
        "brainstorming": ["design", "architect", "plan feature", "how should"],
        "systematic-debugging": ["bug", "error", "failing", "broken", "doesn't work"],
        "test-driven-development": ["test", "tdd", "write tests", "add tests"],
        "session-learnings": ["remember", "learn from", "don't forget"],
    }

    used_skills = set(skills_used)
    missed_triggers = []
    seen = set()
    for msg in messages:
        if msg["role"] != "user":
            continue

        content = msg.get("content", "")
        content_lower = content.lower()
        origin = msg.get("message_origin_hint", "")
        if origin in {"hook_feedback", "resume_summary", "skill_payload", "empty"}:
            continue
        if is_noise_message(content_lower):
            continue

        for skill, triggers in potential_triggers.items():
            if skill in used_skills or f"superpowers:{skill}" in used_skills:
                continue

            trigger = next((t for t in triggers if t in content_lower), None)
            if not trigger:
                continue

            key = (skill, trigger, content_lower[:100])
            if key in seen:
                continue
            seen.add(key)
            missed_triggers.append({
                "skill": skill,
                "trigger_phrase": trigger,
                "confidence": detect_trigger_confidence(content_lower, trigger),
                "context": content_lower[:100],
                "evidence": {
                    "timestamp": msg.get("timestamp"),
                    "message_excerpt": content[:160],
                },
            })

    return {
        "skills_triggered": sorted(used_skills),
        "potential_missed_triggers": missed_triggers,
    }


def append_session_provenance(lines: list[str], session_data: dict) -> None:
    """Append session provenance details when available."""
    requested_project = session_data.get("requested_project_path")
    actual_session_file = session_data.get("actual_session_file_path") or session_data.get("file_path")
    actual_project_dir = session_data.get("actual_project_dir")
    session_source = session_data.get("session_source")

    if not any([requested_project, actual_session_file, actual_project_dir, session_source]):
        return

    lines.append("## Session Provenance")
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("|-------|-------|")
    if requested_project:
        lines.append(f"| Requested Project | `{requested_project}` |")
    if actual_session_file:
        lines.append(f"| Actual Session File | `{actual_session_file}` |")
    if actual_project_dir:
        lines.append(f"| Actual Project Directory | `{actual_project_dir}` |")
    if session_source:
        lines.append(f"| Session Source | `{session_source}` |")
    lines.append("")



def dedupe_recommendations(items: list[str]) -> list[str]:
    """Deduplicate recommendations while preserving order."""
    deduped = []
    seen = set()
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        deduped.append(item)
    return deduped



def generate_report(session_data: dict, analysis: dict) -> str:
    """Generate markdown analysis report."""
    lines = []
    
    # Header
    lines.append(f"# Session Analysis Report")
    lines.append("")
    lines.append(f"**Session ID:** `{session_data.get('session_id', 'unknown')}`")
    lines.append(f"**Generated:** {datetime.now().isoformat()}")
    lines.append("")
    
    # Summary
    lines.append("## Summary")
    lines.append("")
    stats = session_data.get("stats", {})
    tool_analysis = analysis.get("tool_usage", {})
    
    lines.append(f"| Metric | Value |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Duration | {session_data.get('duration_minutes', 'N/A')} min |")
    lines.append(f"| Messages | {stats.get('total_messages', 0)} ({stats.get('user_messages', 0)} user, {stats.get('assistant_messages', 0)} assistant) |")
    lines.append(f"| Tool Calls | {tool_analysis.get('total', 0)} |")
    lines.append(f"| Tool Success Rate | {tool_analysis.get('success_rate', 1.0) * 100:.0f}% |")
    lines.append(f"| Total Tokens | {session_data.get('total_tokens', 'N/A')} |")
    lines.append(f"| Skills Used | {', '.join(session_data.get('skills_used', [])) or 'None'} |")
    lines.append("")
    
    append_session_provenance(lines, session_data)

    # Tool Usage Details
    if tool_analysis.get("by_tool"):
        lines.append("## Tool Usage")
        lines.append("")
        lines.append("| Tool | Calls | Success Rate |")
        lines.append("|------|-------|--------------|")
        for tool, stats in sorted(tool_analysis["by_tool"].items(), key=lambda x: x[1]["total"], reverse=True):
            lines.append(f"| {tool} | {stats['total']} | {stats['success_rate'] * 100:.0f}% |")
        lines.append("")
    
    # Issues Found
    patterns = analysis.get("patterns", [])
    repeated_failures = tool_analysis.get("repeated_failures", [])
    skill_analysis = analysis.get("skill_usage", {})
    missed_triggers = skill_analysis.get("potential_missed_triggers", [])
    
    if patterns or repeated_failures or missed_triggers:
        lines.append("## Issues Found")
        lines.append("")
        
        issue_num = 1
        
        for pattern in patterns:
            severity_icon = {"high": "🔴", "medium": "🟡", "low": "🟢"}.get(pattern["severity"], "⚪")
            lines.append(f"### {issue_num}. {severity_icon} {pattern['type']}")
            lines.append(f"- **Description:** {pattern['description']}")
            lines.append(f"- **Suggestion:** {pattern['suggestion']}")
            lines.append("")
            issue_num += 1
        
        for failure in repeated_failures:
            if failure not in [p.get("tool") for p in patterns if p["type"] == "repeated_failures"]:
                severity_icon = "🟡" if failure["category"] == "expected_test_failure" else "🔴"
                lines.append(f"### {issue_num}. {severity_icon} Failure: {failure['tool']}")
                lines.append(f"- **Category:** {failure['category']}")
                lines.append(f"- **Count:** {failure['count']} failures")
                lines.append(f"- **Sample errors:** {'; '.join(failure['errors'][:2])}")
                evidence = failure.get("evidence", {})
                if evidence.get("tool_use_id"):
                    lines.append(f"- **Evidence Tool ID:** `{evidence['tool_use_id']}`")
                if evidence.get("timestamp"):
                    lines.append(f"- **Evidence Timestamp:** {evidence['timestamp']}")
                if evidence.get("input_summary"):
                    lines.append(f"- **Evidence Input:** `{evidence['input_summary']}`")
                if failure.get("suggestion"):
                    if failure["category"] == "expected_test_failure":
                        lines.append("- **Handling:** Count separately, do not treat as high-severity execution failure")
                    lines.append(f"- **Suggestion:** {failure['suggestion']}")
                lines.append("")
                issue_num += 1

        for missed in missed_triggers[:3]:  # Limit to 3
            lines.append(f"### {issue_num}. 🟡 Skill not triggered: {missed['skill']}")
            lines.append(f"- **Trigger phrase found:** \"{missed['trigger_phrase']}\"")
            lines.append(f"- **Confidence:** {missed['confidence']}")
            evidence = missed.get("evidence", {})
            if evidence.get("timestamp"):
                lines.append(f"- **Evidence Timestamp:** {evidence['timestamp']}")
            if evidence.get("message_excerpt"):
                lines.append(f"- **Evidence Context:** {evidence['message_excerpt']}")
            lines.append(f"- **Suggestion:** Consider expanding skill description")
            lines.append("")
            issue_num += 1
    
    # Optimization Recommendations
    lines.append("## Optimization Recommendations")
    lines.append("")
    
    recommendations = []
    
    # From patterns
    for pattern in patterns:
        recommendations.append(f"- [ ] {pattern['suggestion']}")
    
    # From repeated failures
    for failure in repeated_failures:
        suggestion = failure.get("suggestion")
        if suggestion:
            recommendations.append(f"- [ ] {suggestion}")

    # From missed triggers
    if missed_triggers:
        skills_to_improve = set(m["skill"] for m in missed_triggers if m["confidence"] != "low")
        for skill in skills_to_improve:
            recommendations.append(f"- [ ] Review and expand `{skill}` skill description for better triggering")
    
    # From success rate
    if tool_analysis.get("success_rate", 1.0) < 0.9:
        recommendations.append("- [ ] Add pre-flight validation before tool calls")
    
    recommendations = dedupe_recommendations(recommendations)

    if not recommendations:
        recommendations.append("- [x] Session looks healthy - no major issues detected")
    
    lines.extend(recommendations)
    lines.append("")
    
    # Raw Data Reference
    lines.append("---")
    lines.append("")
    lines.append("*Generated by skill-self-optimizer*")
    
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Analyze extracted session data")
    parser.add_argument("--input", "-i", required=True, help="Input JSON file from extract-session.py")
    parser.add_argument("--output", "-o", help="Output markdown report file")
    parser.add_argument("--json", action="store_true", help="Output analysis as JSON instead of markdown")
    
    args = parser.parse_args()
    
    # Load extracted data
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    
    with open(input_path, 'r') as fp:
        session_data = json.load(fp)
    
    # Run analysis
    messages = session_data.get("messages", [])
    tool_calls = session_data.get("tool_calls", [])
    skills_used = session_data.get("skills_used", [])
    
    analysis = {
        "tool_usage": analyze_tool_usage(tool_calls, messages),
        "patterns": detect_patterns(messages, tool_calls),
        "skill_usage": analyze_skill_usage(messages, skills_used),
    }
    
    # Output
    if args.json:
        output = json.dumps(analysis, indent=2, ensure_ascii=False)
    else:
        output = generate_report(session_data, analysis)
    
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as fp:
            fp.write(output)
        print(f"Report written to: {output_path}")
    else:
        print(output)


if __name__ == "__main__":
    main()
