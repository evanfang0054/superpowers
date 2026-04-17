---
name: harness-optimizer
description: "Use when用户提供 Claude Code 会话 ID，想复盘某次会话、生成分析报告，或基于该会话优化某个明确指定的项目、workflow、skill 或 harness。特别适用于需要区分分析样本来源与真正优化对象的场景，例如“根据这个会话优化我的项目”而不是默认优化分析器自身。"
---

# Skill Self-Optimizer

## Overview

从 Claude Code 历史会话中提取证据，由**子 agent**基于 JSON 样本生成分析报告，再由**主 agent**把建议优先对齐到**用户明确指定的优化对象**并实施优化。

**核心原则：** session 是分析样本，不等于优化对象。除非证据明确指向分析器或 `harness-optimizer` 本身，否则默认应先优化用户指定的项目、workflow、skill 体系或 harness。

**核心流程：** Session 提取 → 子 agent 分析并生成报告 → 识别真实优化对象 → 主 agent 基于报告优化目标对象 → 必要时再回收为自优化项

**启动时宣布：** "我正在使用 harness-optimizer 分析会话数据..."

## When to Use

**触发场景：**
- 用户想分析某个 session 的效果
- 用户提供 session id，并要求“根据这个会话优化某个项目/仓库/skill/workflow”
- 需要基于历史数据优化 skill
- 想了解 skill 的实际使用情况
- 调试 skill 不工作的原因
- 实现 harness 自我闭环

**目标对象判定：**
- 如果用户明确说“优化这个项目 / 这个仓库 / 这套 superpowers”，优先输出该对象的优化建议并在该对象上落地修改
- 如果用户明确说“优化这个 skill”或“优化分析器本身”，才把 `harness-optimizer` 当成主要优化对象
- 如果 session 命中了别的项目目录，要在分析报告里显式标注跨项目风险，避免把样本项目的问题误写成当前项目的问题

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
- 后续分析报告必须注明真实命中的 `file_path` / `actual_project_dir`

## Step 3: 启动子 agent 分析 JSON 并生成报告

不要使用 `analyze-session.py`。提取完 JSON 后，直接启动一个**只做分析、不写代码**的子 agent，读取 JSON 并输出 markdown 报告。

**要求：**
- 子 agent 只负责分析和写报告，不负责改代码
- 报告必须基于提取出的 JSON 证据，不要虚构结论
- 报告必须区分：样本 session 来自哪里、用户真正要优化的对象是什么
- 如果命中了跨项目 session，要明确提醒这是样本来源，不等于当前要修改的项目
- 如果证据不足，要明确写 `insufficient evidence`

**推荐子 agent 任务描述：**
```text
读取 .superpowers/session-analysis/<session-id>.json，生成 .superpowers/session-analysis/<session-id>-report.md。

目标：基于该 session 样本总结问题模式、关键证据、风险和优化建议。
限制：只做分析，不写代码，不修改目标项目。
必须包含：
1. Summary
2. Session Provenance
3. Issues Found
4. Optimization Recommendations
5. 明确说明建议应作用于哪个目标对象（用户指定项目 / workflow / skill / harness）
```

**报告建议结构：**
```markdown
# Session Analysis Report

## Summary
- Duration: ...
- Tool Success Signals: ...
- Skills Used: ...
- Primary Optimization Target: ...

## Session Provenance
- Requested Project: ...
- Actual Session File: ...
- Actual Project Directory: ...
- Session Source: ...

## Issues Found
1. ...
   - Evidence: ...
   - Impact: ...
   - Confidence: high / medium / low

## Optimization Recommendations
- [ ] ...
- [ ] ...

## Targeting Decision
- Why these recommendations should apply to `<user-target>` instead of the sampled session project / harness itself
```

## Step 4: 主 agent 基于报告优化用户指定对象

主 agent 读取报告后，先判断优化对象，再实施修改。

**执行规则：**
- 默认优先优化用户明确指定的项目 / 仓库 / workflow / skill
- 不要因为分析样本来自别的目录，就直接改样本目录
- 不要把 `harness-optimizer` 默认当成修复目标
- 只有当报告证据明确指出问题就在 `harness-optimizer` 自身时，才回收为自优化

**主 agent 的职责：**
1. 读取子 agent 报告
2. 提炼与用户目标对象最相关的建议
3. 在用户指定项目中搜索对应实现位置
4. 进行最小必要修改
5. 验证修改是否匹配报告结论

## Step 5: 验证优化

修改 skill 或项目后，验证改进效果：

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
│                     Skill Harness-Optimizer                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. INPUT: Session ID                                       │
│     └─► extract-session.py                                 │
│                                                             │
│  2. EXTRACT: 会话数据                                       │
│     └─► messages, tool_calls, skills_used                  │
│                                                             │
│  3. ANALYZE: 子 agent 读取 JSON 生成报告                    │
│     └─► issues, evidence, targeting decision               │
│                                                             │
│  4. OPTIMIZE: 主 agent 基于报告优化用户指定目标             │
│     └─► project / workflow / skill / harness               │
│                                                             │
│  5. VERIFY: 验证测试                                        │
│     └─► skill-creator eval 系统                            │
│                                                             │
│  6. LOOP: 记录学习                                          │
│     └─► session-learnings 存储                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Quick Reference

```bash
# 列出项目会话
ls -lt ~/.claude/projects/<project-path>/*.jsonl | head -10

# 提取特定会话
python ${SKILL_PATH}/scripts/extract-session.py --session-id <id>
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
