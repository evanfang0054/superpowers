# Sprint Contract: harness-cache-and-skill-optimization

Spec: docs/agent-harness/specs/2026-07-26-harness-cache-and-skill-optimization-design.md

## Outcome

每次新开会话时，注入的上下文更小更稳定——skill 注册表更瘦、大 skill 触发时不再一次性灌入 60KB 内容。auto-loop 长循环中稳定指令命中缓存。skill 反复失败时系统主动提示运行 harness-optimizer，且 optimizer 验证步骤真实可跑——闭环从纸面变为真实运转。

## Definition of Done

### P1 缓存前缀加固
- [ ] session-start 输出中，动态段（context_md_hint / warning / learnings / checkpoint_hint）全部位于静态段（using-agent-harness / headless_tip / kb_hint）之后
- [ ] 验证：同一项目连续两次模拟 startup 调用 `hooks/session-start`，截取输出开头至 kb_hint 结束的静态段，`diff` 字节一致
- [ ] `search-learnings.sh --summary` 输出仅含 `[confidence] 一句话结论` 格式，37 条 learnings 时注入体积 ≤ 4KB
- [ ] orchestrator-prompt.md 中 `{{REQUEST}}/{{SCOPE}}/{{SCAN_TARGET}}/{{BRANCH}}/{{MODE}}/{{FILTER}}/{{TARGET_ISSUES}}/{{MAX_ISSUES}}` 占位符全部位于稳定指令体之后（文件末尾区域）；稳定段内嵌 `{{REPO_ROOT}}` 保留原位
- [ ] `./scripts/auto-loop.sh --dry-run "测试"` 占位符填充正确、流程正常启动
- [ ] `tests/plugin-infrastructure/run-all.sh` 全部通过

### P2 注册表瘦身 + 渐进式披露
- [ ] harness-design SKILL.md ≤ 12KB；writing-skills / brainstorming / writing-plans SKILL.md 各有可测量缩减；移出内容全部位于各自 `references/` 下且 SKILL.md 内有硬指引
- [ ] circuit-breaker、检查清单、HARD-GATE、流程图仍在对应 SKILL.md 内（grep 可验证）
- [ ] 拆分前记录 4 个 skill 的 `tests/skill-behavior/<skill>/run-test.sh` baseline；拆分后重跑，结果不劣于 baseline
- [ ] harness-design / retrospective / domain-modeling 的 description < 120 字符
- [ ] generate-issues、fix-issues-and-pr 的 frontmatter 含 `disable-model-invocation: true`，且 `/generate-issues`、`/fix-issues-and-pr` slash 入口仍可调用（headless 验证一次）
- [ ] `tests/claude-code/run-skill-tests.sh` 全部通过

### P3 闭环修复
- [ ] harness-optimizer SKILL.md Step 5 不再引用 `skill_creator.scripts.run_eval`；改为 `tests/skill-behavior/<skill>/run-test.sh`，无对应测试时降级 `tests/claude-code/run-skill-tests.sh --test <skill>`
- [ ] `scripts/index-knowledge-base.sh` 重建后 specs/index.md 覆盖全部 27+ spec 文件，主题速查锚点与 frontmatter spec_topic 一致
- [ ] stop-hook.sh 在同一 skill/spec_topic 连续 3 次 `gate-result failed` 时输出一行提示（仅提示不执行）；手动构造 3 条 failed 记录可触发

## Boundary Conditions

- Must not break：三平台输出分支（Cursor / Claude Code / Copilot）；auto-loop.sh jq gsub 逻辑；subagent 早退路径
- Must not touch：demo/、已调优 skill 文案（只搬移不重写）、第三方依赖
- 降级许可：若 phase-metrics 数据不支持按 skill 聚合，stop-hook 检查允许降级为按 spec_topic 聚合（在 plan 中确认后执行）
- 拆分尺寸是目标不是硬门槛：为保留必要规则可超出，但 behavior test 必须不劣于 baseline

## Acceptance Criteria

- Computational：`tests/plugin-infrastructure/run-all.sh`、`tests/claude-code/run-skill-tests.sh` 退出码 0；session-start 静态段 diff 为空；SKILL.md 尺寸 `wc -c` 达标
- Inferential：4 个拆分 skill 的 behavior test 前后对比不劣化；auto-loop dry-run 人工确认流程正常

## Negotiation Record

- Generator 初稿：8 条粗粒度判据（"前缀稳定""完成拆分""所有测试通过"）
- Evaluator 第 1 轮：5 条不可测/模糊判据被打回（前缀稳定无验证方法、拆分无红线、disable-model-invocation 无 slash 验证、stop-hook 数据可行性未确认、测试清单不明），补漏 learnings 压缩项
- Generator 修订：全部改为 yes/no 可验证判据 + 明确验证命令
- Evaluator 第 2 轮：细化静态段 diff 截取范围；尺寸上限放宽为"≤12KB 且 test 不劣化"避免凑数砍规则；stop-hook 降级路径写入边界条件。接受。
- 最终共识：如上 DoD
