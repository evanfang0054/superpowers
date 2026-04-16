---
name: skill-self-optimizer
description: "从 Claude Code 历史会话中提取数据，分析 skill 使用效果，自动生成优化建议。当用户说'分析这个会话'、'优化 skill'、'从历史学习'、'session 分析'、'skill 效果评估'时使用。支持基于特定 session ID 的精准分析，实现 harness 自我闭环。"
---

# Skill Self-Optimizer

## Overview

从 Claude Code 历史会话中学习，分析 skill 使用效果，生成优化建议，实现自我闭环。

**核心流程：** Session 提取 → 效果分析 → Skill 优化 → 验证测试

**启动时宣布：** "我正在使用 skill-self-optimizer 分析会话数据..."

## When to Use

**触发场景：**
- 用户想分析某个 session 的效果
- 需要基于历史数据优化 skill
- 想了解 skill 的实际使用情况
- 调试 skill 不工作的原因
- 实现 harness 自我闭环

## Session 数据位置

Claude Code 会话存储在：
```
~/.claude/projects/<encoded-project-path>/<session-id>.jsonl
```

每个项目路径会被编码（斜杠变连字符），例如：
```
/Users/user/Desktop/project → -Users-user-Desktop-project
```

## Step 1: 获取 Session ID

**方法1：当前会话**
```bash
# 环境变量（在 skill 中可用）
echo $CLAUDE_SESSION_ID
```

**方法2：列出项目会话**
```bash
# 列出项目的所有会话（按时间排序）
ls -lt ~/.claude/projects/<project-path>/*.jsonl | head -20
```

**方法3：用户直接提供**
用户可以从 Claude Code 的 `/resume` 命令或 Ctrl+R 界面获取 session ID。

## Step 2: 提取会话数据

使用提取脚本：
```bash
python ${SKILL_PATH}/scripts/extract-session.py \
  --session-id <session-id> \
  --project-path=<encoded-project-path> \
  --output .superpowers/session-analysis/<session-id>.json
```

**注意：** 当 `project-path` 本身以 `-` 开头（Claude 编码路径通常如此）时，必须使用 `--project-path=<value>` 这种等号写法，避免被 argparse 误识别为新选项。

**输出格式：**
```json
{
  "session_id": "xxx",
  "start_time": "2024-01-01T10:00:00Z",
  "end_time": "2024-01-01T11:00:00Z",
  "duration_minutes": 60,
  "messages": [
    {"role": "user", "content": "...", "timestamp": "..."},
    {"role": "assistant", "content": "...", "timestamp": "..."}
  ],
  "tool_calls": [
    {"tool": "Read", "input": {...}, "output": "...", "success": true},
    {"tool": "Edit", "input": {...}, "output": "...", "success": false, "error": "..."}
  ],
  "skills_used": ["skill-name", ...],
  "total_tokens": 50000
}
```

**当 session ID 已知但项目目录不确定时：**
- 可以先照常传 `--project-path=<encoded-project-path>`
- 如果精确匹配失败，提取脚本会先尝试请求目录中的前缀匹配，再回退到 `~/.claude/projects/*` 中全局查找
- 如果只有一个前缀候选，会自动命中并继续分析
- 如果前缀候选不止一个，脚本会列出候选并要求补全 session id
- 分析结果应在报告里注明真实命中的 `file_path`

## Step 3: 分析效果

使用分析脚本：
```bash
python ${SKILL_PATH}/scripts/analyze-session.py \
  --input .superpowers/session-analysis/<session-id>.json \
  --output .superpowers/session-analysis/<session-id>-report.md
```

### 分析维度

| 维度 | 指标 | 健康值 |
|------|------|--------|
| 工具成功率 | 成功调用 / 总调用 | > 90% |
| 任务完成度 | 用户确认完成 / 总任务 | > 80% |
| 效率 | tokens / 完成任务 | 越低越好 |
| Skill 触发率 | 实际触发 / 应该触发 | > 70% |
| 用户纠正率 | 被纠正次数 / 总回复 | < 10% |

### 问题模式识别

**常见问题：**
- `repeated_failures`: 同一 failure category 在短时间内重复出现 3+ 次（不含 `expected_test_failure`）
- `skill_not_triggered`: 应该使用 skill 但没有触发
- `excessive_tokens`: 单次任务消耗 > 50k tokens
- `user_corrections`: 用户频繁纠正

**输出报告：**
```markdown
# Session Analysis Report

## Summary
- Duration: 60 min
- Tool Success Rate: 85%
- Tasks Completed: 3/4
- Skills Used: brainstorming, systematic-debugging

## Session Provenance
| Field | Value |
|-------|-------|
| Requested Project | `-Users-example-Desktop-project-superpowers` |
| Actual Session File | `~/.claude/projects/-Users-example-Desktop-project-target/ac3a4...jsonl` |
| Actual Project Directory | `~/.claude/projects/-Users-example-Desktop-project-target` |
| Session Source | `fallback-global-search` |

## Issues Found
1. **expected_test_failure** in Bash tool (4 times)
   - Context: TDD red phase / test verification
   - Handling: Count separately, do not treat as high-severity execution failure

2. **edit_match_ambiguity** repeated 3 times in Edit
   - Suggestion: Widen the edit context, make the target snippet unique, or use replace_all when every match should change

3. **skill_not_triggered**: test-driven-development
   - Context: Real user request only; hook/summary/skill payload noise excluded
   - Suggestion: Improve skill description

## Optimization Recommendations
- [ ] Track expected TDD failures separately from actionable execution failures
- [ ] Check file/session/project paths before execution
- [ ] Widen edit-match context or switch to `replace_all` when every occurrence should change
```

**不要把工具层占位错误当成真实问题：**
- `Read` 非 PDF 文件时若出现 `pages: ""`，这是调用层占位值，不应在报告中当成高优先级失败
- `Skill` 若报 `shell command failed`，优先检查 skill shell wrapper、模板插值和脚本路径，而不是笼统归类成 runtime failure

## Step 4: 生成优化建议

基于分析结果，生成针对特定 skill 的优化建议：

### Skill Description 优化

如果发现 skill 触发率低：
```bash
# 分析 skill 触发失败的上下文
grep -A5 "should_trigger.*false" .superpowers/session-analysis/*-report.md
```

**优化方向：**
- 扩展触发关键词
- 添加常见变体表达
- 增加"推动性"描述

### Skill Content 优化

如果发现执行效果差：
- 检查指令是否清晰
- 添加更多示例
- 简化过于复杂的步骤
- 解释"为什么"而不只是"做什么"

## Step 5: 验证优化

修改 skill 后，验证改进效果：

```bash
# 使用 skill-creator 的 eval 系统
# 创建测试用例
mkdir -p .superpowers/skill-evals/<skill-name>/

# 运行测试
python -m skill_creator.scripts.run_eval \
  --skill-path skills/<skill-name> \
  --eval-set .superpowers/skill-evals/<skill-name>/evals.json
```

## 完整闭环流程

```
┌─────────────────────────────────────────────────────────────┐
│                     Skill Self-Optimization                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. INPUT: Session ID                                        │
│     └─► extract-session.py                                  │
│                                                              │
│  2. EXTRACT: 会话数据                                        │
│     └─► messages, tool_calls, skills_used                   │
│                                                              │
│  3. ANALYZE: 效果分析                                        │
│     └─► 成功率, 完成度, 问题模式                            │
│                                                              │
│  4. OPTIMIZE: 生成建议                                       │
│     └─► description 优化, content 改进                      │
│                                                              │
│  5. VERIFY: 验证测试                                         │
│     └─► skill-creator eval 系统                             │
│                                                              │
│  6. LOOP: 记录学习                                           │
│     └─► session-learnings 存储                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Quick Reference

```bash
# 列出项目会话
ls -lt ~/.claude/projects/<project-path>/*.jsonl | head -10

# 提取特定会话
python ${SKILL_PATH}/scripts/extract-session.py --session-id <id>

# 分析效果
python ${SKILL_PATH}/scripts/analyze-session.py --input <extracted.json>

# 搜索问题模式
grep -r "repeated_failures\|skill_not_triggered" .superpowers/session-analysis/
```

## Integration

**与其他 skill 协作：**
- **session-learnings**: 将分析发现存储为学习记录
- **skill-creator**: 使用其 eval 系统验证优化
- **retrospective**: 纳入定期回顾

## Red Flags

**立即分析当：**
- Skill 完全没有触发（应该触发时）
- 同一任务重试 3+ 次
- 用户明确表示不满
- Token 消耗异常高

**不要分析：**
- 正常成功的会话（除非要学习成功模式）
- 非常短的测试会话
- 与 skill 无关的纯对话
