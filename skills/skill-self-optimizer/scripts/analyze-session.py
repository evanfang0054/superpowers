#!/usr/bin/env python3
"""
Analyze extracted session data and generate optimization report.

Usage:
    python analyze-session.py --input <extracted.json> [--output <report.md>]
"""

import argparse
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


def analyze_tool_usage(tool_calls: list) -> dict:
    """Analyze tool usage patterns."""
    if not tool_calls:
        return {"total": 0, "success_rate": 1.0, "by_tool": {}, "failures": []}
    
    total = len(tool_calls)
    successful = len([t for t in tool_calls if t.get("success", True)])
    
    # Group by tool
    by_tool = defaultdict(lambda: {"total": 0, "success": 0, "failures": []})
    for tc in tool_calls:
        tool = tc.get("tool", "unknown")
        by_tool[tool]["total"] += 1
        if tc.get("success", True):
            by_tool[tool]["success"] += 1
        else:
            by_tool[tool]["failures"].append({
                "error": tc.get("error", "Unknown error"),
                "input": tc.get("input", {}),
            })
    
    # Calculate rates
    tool_stats = {}
    for tool, stats in by_tool.items():
        rate = stats["success"] / stats["total"] if stats["total"] > 0 else 1.0
        tool_stats[tool] = {
            "total": stats["total"],
            "success": stats["success"],
            "success_rate": round(rate, 2),
            "failure_count": len(stats["failures"]),
        }
    
    # Identify repeated failures
    failures = []
    for tool, stats in by_tool.items():
        if len(stats["failures"]) >= 2:
            failures.append({
                "tool": tool,
                "count": len(stats["failures"]),
                "errors": [f["error"][:100] for f in stats["failures"][:3]],
            })
    
    return {
        "total": total,
        "successful": successful,
        "success_rate": round(successful / total, 2) if total > 0 else 1.0,
        "by_tool": tool_stats,
        "repeated_failures": failures,
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


def analyze_skill_usage(messages: list, skills_used: list) -> dict:
    """Analyze skill triggering patterns."""
    # Detect potential skill triggers that weren't caught
    potential_triggers = {
        "brainstorming": ["design", "architect", "plan feature", "how should"],
        "systematic-debugging": ["bug", "error", "failing", "broken", "doesn't work"],
        "test-driven-development": ["test", "tdd", "write tests", "add tests"],
        "session-learnings": ["remember", "learn from", "don't forget"],
    }
    
    missed_triggers = []
    for msg in messages:
        if msg["role"] == "user":
            content_lower = msg.get("content", "").lower()
            for skill, triggers in potential_triggers.items():
                if skill not in skills_used:
                    if any(trigger in content_lower for trigger in triggers):
                        missed_triggers.append({
                            "skill": skill,
                            "trigger_phrase": next(t for t in triggers if t in content_lower),
                            "context": content_lower[:100],
                        })
    
    return {
        "skills_triggered": skills_used,
        "potential_missed_triggers": missed_triggers,
    }


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
                lines.append(f"### {issue_num}. 🔴 Repeated failures: {failure['tool']}")
                lines.append(f"- **Count:** {failure['count']} failures")
                lines.append(f"- **Sample errors:** {'; '.join(failure['errors'][:2])}")
                lines.append("")
                issue_num += 1
        
        for missed in missed_triggers[:3]:  # Limit to 3
            lines.append(f"### {issue_num}. 🟡 Skill not triggered: {missed['skill']}")
            lines.append(f"- **Trigger phrase found:** \"{missed['trigger_phrase']}\"")
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
    
    # From missed triggers
    if missed_triggers:
        skills_to_improve = set(m["skill"] for m in missed_triggers)
        for skill in skills_to_improve:
            recommendations.append(f"- [ ] Review and expand `{skill}` skill description for better triggering")
    
    # From success rate
    if tool_analysis.get("success_rate", 1.0) < 0.9:
        recommendations.append("- [ ] Add pre-flight validation before tool calls")
    
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
        "tool_usage": analyze_tool_usage(tool_calls),
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
