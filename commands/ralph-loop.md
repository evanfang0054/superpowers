---
description: "Start Ralph Loop in current session"
argument-hint: "任务描述或Plan路径"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command

Execute the setup script to initialize the Ralph loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" \
  "$ARGUMENTS

=== GENERAL Rules ===
1. Each iteration: focus on ONE concrete step forward, then let the loop continue.
2. Verify your work actually works before claiming it's done.
3. When encountering unfamiliar or new APIs, use context7 to query the latest documentation.
4. Stay in the current directory—do not cd unless absolutely necessary.
5. If blocked, clearly state what's blocking and what you need.
6. When task is GENUINELY complete, output <promise>COMPLETE</promise>.
" \
  --completion-promise "COMPLETE" \
  --max-iterations 40
```

When you try to exit, the Ralph loop will feed the SAME PROMPT back to you for the next iteration. You'll see your previous work in files and git history, allowing you to iterate and improve.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop, even if you think you're stuck or should exit for other reasons. The loop is designed to continue until genuine completion.
