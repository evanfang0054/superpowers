#!/usr/bin/env python3
"""
Extract session data from Claude Code JSONL files.

Usage:
    python extract-session.py --session-id <id> [--project-path <path>] [--output <file>]
    python extract-session.py --list [--project-path <path>] [--limit 10]
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path


def get_claude_projects_dir() -> Path:
    """Get the Claude projects directory."""
    return Path.home() / ".claude" / "projects"


def encode_project_path(path: str) -> str:
    """Encode a project path to Claude's directory format."""
    return path.replace("/", "-").lstrip("-")


def find_project_dir(project_path: str | None = None) -> Path | None:
    """Find the project directory in Claude's storage."""
    projects_dir = get_claude_projects_dir()
    
    if project_path:
        encoded = encode_project_path(project_path)
        candidate = projects_dir / encoded
        if candidate.exists():
            return candidate
    
    # Try current working directory
    cwd = os.getcwd()
    encoded_cwd = encode_project_path(cwd)
    candidate = projects_dir / encoded_cwd
    if candidate.exists():
        return candidate
    
    # List available projects
    if projects_dir.exists():
        for d in projects_dir.iterdir():
            if d.is_dir() and encoded_cwd in d.name:
                return d
    
    return None


def list_sessions(project_dir: Path, limit: int = 10) -> list[dict]:
    """List available sessions in a project directory."""
    sessions = []
    
    for f in sorted(project_dir.glob("*.jsonl"), key=lambda x: x.stat().st_mtime, reverse=True):
        if limit and len(sessions) >= limit:
            break
        
        session_id = f.stem
        stat = f.stat()
        
        # Read first and last lines for timestamps
        first_ts = None
        last_ts = None
        message_count = 0
        
        try:
            with open(f, 'r') as fp:
                for line in fp:
                    message_count += 1
                    try:
                        data = json.loads(line)
                        ts = data.get("timestamp") or data.get("ts")
                        if ts:
                            if first_ts is None:
                                first_ts = ts
                            last_ts = ts
                    except json.JSONDecodeError:
                        continue
        except Exception:
            pass
        
        sessions.append({
            "session_id": session_id,
            "file_path": str(f),
            "file_size_kb": round(stat.st_size / 1024, 1),
            "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
            "message_count": message_count,
            "first_timestamp": first_ts,
            "last_timestamp": last_ts,
        })
    
    return sessions


def extract_session(session_file: Path) -> dict:
    """Extract and structure data from a session JSONL file."""
    messages = []
    tool_calls = []
    skills_used = set()
    total_tokens = 0
    start_time = None
    end_time = None
    
    with open(session_file, 'r') as fp:
        for line in fp:
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue
            
            msg_type = data.get("type")
            timestamp = data.get("timestamp") or data.get("ts")
            
            if timestamp:
                if start_time is None:
                    start_time = timestamp
                end_time = timestamp
            
            # Extract user/assistant messages
            if msg_type in ("user", "assistant"):
                message_data = data.get("message", {})
                content = message_data.get("content", "")
                
                # Handle content that's a list (Claude format)
                if isinstance(content, list):
                    text_parts = []
                    for part in content:
                        if isinstance(part, dict):
                            if part.get("type") == "text":
                                text_parts.append(part.get("text", ""))
                            elif part.get("type") == "tool_use":
                                # Extract tool call info
                                tool_calls.append({
                                    "tool": part.get("name", "unknown"),
                                    "input": part.get("input", {}),
                                    "timestamp": timestamp,
                                    "id": part.get("id"),
                                })
                            elif part.get("type") == "tool_result":
                                # Match with tool call by ID
                                tool_id = part.get("tool_use_id")
                                for tc in tool_calls:
                                    if tc.get("id") == tool_id:
                                        tc["output"] = part.get("content", "")[:500]  # Truncate
                                        tc["success"] = not part.get("is_error", False)
                                        if part.get("is_error"):
                                            tc["error"] = part.get("content", "")[:200]
                        elif isinstance(part, str):
                            text_parts.append(part)
                    content = "\n".join(text_parts)
                
                messages.append({
                    "role": msg_type,
                    "content": content[:2000] if content else "",  # Truncate long content
                    "timestamp": timestamp,
                })
                
                # Detect skill usage from content
                if msg_type == "assistant" and content:
                    if "using the" in content.lower() and "skill" in content.lower():
                        # Try to extract skill name
                        import re
                        match = re.search(r"using (?:the )?(\w+(?:-\w+)*) skill", content.lower())
                        if match:
                            skills_used.add(match.group(1))
            
            # Extract tool results
            elif msg_type == "tool_result":
                tool_id = data.get("tool_use_id")
                for tc in tool_calls:
                    if tc.get("id") == tool_id:
                        tc["output"] = str(data.get("content", ""))[:500]
                        tc["success"] = not data.get("is_error", False)
                        if data.get("is_error"):
                            tc["error"] = str(data.get("content", ""))[:200]
            
            # Track tokens
            if "usage" in data:
                usage = data["usage"]
                total_tokens += usage.get("input_tokens", 0) + usage.get("output_tokens", 0)
    
    # Calculate duration
    duration_minutes = None
    if start_time and end_time:
        try:
            start_dt = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
            end_dt = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
            duration_minutes = round((end_dt - start_dt).total_seconds() / 60, 1)
        except Exception:
            pass
    
    return {
        "session_id": session_file.stem,
        "file_path": str(session_file),
        "start_time": start_time,
        "end_time": end_time,
        "duration_minutes": duration_minutes,
        "messages": messages,
        "tool_calls": tool_calls,
        "skills_used": list(skills_used),
        "total_tokens": total_tokens,
        "stats": {
            "total_messages": len(messages),
            "user_messages": len([m for m in messages if m["role"] == "user"]),
            "assistant_messages": len([m for m in messages if m["role"] == "assistant"]),
            "total_tool_calls": len(tool_calls),
            "successful_tool_calls": len([t for t in tool_calls if t.get("success", True)]),
            "failed_tool_calls": len([t for t in tool_calls if not t.get("success", True)]),
        }
    }


def main():
    parser = argparse.ArgumentParser(description="Extract Claude Code session data")
    parser.add_argument("--session-id", "-s", help="Session ID to extract")
    parser.add_argument("--project-path", "-p", help="Project path (will be encoded)")
    parser.add_argument("--output", "-o", help="Output file path")
    parser.add_argument("--list", "-l", action="store_true", help="List available sessions")
    parser.add_argument("--limit", type=int, default=10, help="Limit for --list")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    
    args = parser.parse_args()
    
    # Find project directory
    project_dir = find_project_dir(args.project_path)
    if not project_dir:
        print(f"Error: Could not find project directory", file=sys.stderr)
        print(f"Available projects in {get_claude_projects_dir()}:", file=sys.stderr)
        for d in sorted(get_claude_projects_dir().iterdir())[:10]:
            print(f"  {d.name}", file=sys.stderr)
        sys.exit(1)
    
    # List sessions
    if args.list:
        sessions = list_sessions(project_dir, args.limit)
        if args.json:
            print(json.dumps(sessions, indent=2))
        else:
            print(f"Sessions in {project_dir.name}:\n")
            for s in sessions:
                print(f"  {s['session_id']}")
                print(f"    Modified: {s['modified']}")
                print(f"    Size: {s['file_size_kb']} KB, Messages: {s['message_count']}")
                print()
        return
    
    # Extract specific session
    if not args.session_id:
        print("Error: --session-id required (use --list to see available sessions)", file=sys.stderr)
        sys.exit(1)
    
    session_file = project_dir / f"{args.session_id}.jsonl"
    if not session_file.exists():
        print(f"Error: Session file not found: {session_file}", file=sys.stderr)
        sys.exit(1)
    
    result = extract_session(session_file)
    
    # Output
    output_json = json.dumps(result, indent=2, ensure_ascii=False)
    
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as fp:
            fp.write(output_json)
        print(f"Extracted to: {output_path}")
    else:
        print(output_json)


if __name__ == "__main__":
    main()
