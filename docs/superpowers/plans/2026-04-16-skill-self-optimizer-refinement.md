# Skill Self-Optimizer Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `skill-self-optimizer` reliably resolve near-miss session IDs, separate expected TDD failures from actionable repeated failures, generate more specific remediation guidance, and document the new behavior.

**Architecture:** Extend `extract-session.py` with exact-then-prefix session lookup while preserving provenance metadata. Refine `analyze-session.py` so actionable failures are grouped by failure category, expected TDD failures are reported as low-severity observations instead of high-severity repeated failures, and suggestions point to the correct layer. Lock the behavior with focused `unittest` coverage, then update `SKILL.md` so usage instructions match the implementation.

**Tech Stack:** Python 3, `unittest`, existing `extract-session.py` / `analyze-session.py` scripts, markdown skill docs

---

## File Structure

- Modify: `skills/skill-self-optimizer/scripts/extract-session.py`
  - Add prefix-based session lookup and ambiguous-candidate reporting without changing existing provenance fields.
- Modify: `skills/skill-self-optimizer/scripts/analyze-session.py`
  - Rework repeated-failure detection to group actionable failures by category, keep expected TDD failures separate, and improve suggestion text.
- Modify: `skills/skill-self-optimizer/tests/test_session_optimizer.py`
  - Add regression coverage for unique prefix matches, ambiguous prefix matches, expected test failure handling, category-based repeated failures, and more specific remediation suggestions.
- Modify: `skills/skill-self-optimizer/SKILL.md`
  - Update the documented extraction behavior, repeated-failure definition, and report examples.

### Task 1: Add prefix-aware session lookup

**Files:**
- Modify: `skills/skill-self-optimizer/tests/test_session_optimizer.py`
- Modify: `skills/skill-self-optimizer/scripts/extract-session.py`

- [x] **Step 1: Write the failing tests**

```python
    def test_find_session_file_accepts_unique_prefix_match(self):
        with tempfile.TemporaryDirectory() as tmp:
            projects_dir = Path(tmp)
            requested_dir = projects_dir / '-Users-arwen-Desktop-Arwen-evanfang-superpowers'
            requested_dir.mkdir()
            session_file = requested_dir / 'ac3a4a38-1ae1-4fcc-901d-929eef8e7661.jsonl'
            session_file.write_text('', encoding='utf-8')

            with patch.object(extract_session, 'get_claude_projects_dir', return_value=projects_dir):
                found = extract_session.find_session_file('ac3a4a38-1ae1-4fcc-901d-929eef8e766', requested_dir)

        self.assertEqual(found['path'], session_file)
        self.assertEqual(found['session_source'], 'requested-project')

    def test_find_session_file_reports_ambiguous_prefix_candidates(self):
        with tempfile.TemporaryDirectory() as tmp:
            projects_dir = Path(tmp)
            requested_dir = projects_dir / '-Users-arwen-Desktop-Arwen-evanfang-superpowers'
            requested_dir.mkdir()
            (requested_dir / 'abc123-one.jsonl').write_text('', encoding='utf-8')
            (requested_dir / 'abc123-two.jsonl').write_text('', encoding='utf-8')

            with patch.object(extract_session, 'get_claude_projects_dir', return_value=projects_dir):
                with self.assertRaisesRegex(ValueError, 'Multiple session matches for prefix'):
                    extract_session.find_session_file('abc123', requested_dir)
```

- [x] **Step 2: Run test to verify it fails**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests.test_find_session_file_accepts_unique_prefix_match skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests.test_find_session_file_reports_ambiguous_prefix_candidates -v`
Expected: FAIL because `find_session_file()` only supports exact `<session-id>.jsonl` matches and never raises an ambiguity error.

- [x] **Step 3: Write minimal implementation**

```python
def find_session_file(session_id: str, project_dir: Path | None = None) -> dict | None:
    """Find a session file, optionally falling back to all Claude project directories."""
    candidate_dirs = []
    if project_dir:
        candidate_dirs.append(project_dir)

    projects_dir = get_claude_projects_dir()
    if projects_dir.exists():
        candidate_dirs.extend(
            d for d in sorted(projects_dir.iterdir())
            if d.is_dir() and d not in candidate_dirs
        )

    target_name = f"{session_id}.jsonl"
    for index, directory in enumerate(candidate_dirs):
        candidate = directory / target_name
        if candidate.exists():
            return {
                "path": candidate,
                "actual_project_dir": directory,
                "session_source": "requested-project" if index == 0 and project_dir else "fallback-global-search",
            }

    prefix_matches = []
    for index, directory in enumerate(candidate_dirs):
        for candidate in sorted(directory.glob(f"{session_id}*.jsonl")):
            prefix_matches.append({
                "path": candidate,
                "actual_project_dir": directory,
                "session_source": "requested-project" if index == 0 and project_dir else "fallback-global-search",
            })

    if len(prefix_matches) == 1:
        return prefix_matches[0]
    if len(prefix_matches) > 1:
        candidates = ", ".join(match["path"].stem for match in prefix_matches[:5])
        raise ValueError(f"Multiple session matches for prefix {session_id}: {candidates}")

    return None
```

- [x] **Step 4: Run test to verify it passes**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests.test_find_session_file_accepts_unique_prefix_match skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests.test_find_session_file_reports_ambiguous_prefix_candidates -v`
Expected: PASS with one unique-prefix lookup success and one explicit ambiguity failure.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/tests/test_session_optimizer.py skills/skill-self-optimizer/scripts/extract-session.py
git commit -m "fix(skill-self-optimizer): support prefix session lookup"
```

### Task 2: Surface ambiguous prefix errors in CLI output

**Files:**
- Modify: `skills/skill-self-optimizer/tests/test_session_optimizer.py`
- Modify: `skills/skill-self-optimizer/scripts/extract-session.py`

- [x] **Step 1: Write the failing test**

```python
    def test_main_reports_ambiguous_prefix_candidates(self):
        with tempfile.TemporaryDirectory() as tmp:
            projects_dir = Path(tmp) / 'projects'
            projects_dir.mkdir()
            requested_dir = projects_dir / '-Users-arwen-Desktop-Arwen-evanfang-superpowers'
            requested_dir.mkdir()
            (requested_dir / 'abc123-one.jsonl').write_text('', encoding='utf-8')
            (requested_dir / 'abc123-two.jsonl').write_text('', encoding='utf-8')

            with patch.object(extract_session, 'get_claude_projects_dir', return_value=projects_dir), \
                 patch.object(extract_session, 'find_project_dir', return_value=requested_dir), \
                 patch.object(sys, 'argv', ['extract-session.py', '--session-id', 'abc123', '--project-path=-Users-arwen-Desktop-Arwen-evanfang-superpowers']), \
                 patch('sys.stderr', new_callable=io.StringIO) as stderr:
                with self.assertRaises(SystemExit) as exc:
                    extract_session.main()

        self.assertEqual(exc.exception.code, 1)
        self.assertIn('Multiple session matches for prefix abc123', stderr.getvalue())
```

- [x] **Step 2: Run test to verify it fails**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests.test_main_reports_ambiguous_prefix_candidates -v`
Expected: FAIL because `main()` currently assumes `find_session_file()` only returns `None` or a match and does not catch `ValueError`.

- [x] **Step 3: Write minimal implementation**

```python
    try:
        session_match = find_session_file(args.session_id, project_dir)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    if not session_match:
        print(f"Error: Session file not found: {args.session_id}.jsonl", file=sys.stderr)
        sys.exit(1)
```

- [x] **Step 4: Run test to verify it passes**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests.test_main_reports_ambiguous_prefix_candidates -v`
Expected: PASS with stderr containing the candidate error and exit code `1`.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/tests/test_session_optimizer.py skills/skill-self-optimizer/scripts/extract-session.py
git commit -m "fix(skill-self-optimizer): report ambiguous session prefixes"
```

### Task 3: Keep expected TDD failures out of repeated-failure alerts

**Files:**
- Modify: `skills/skill-self-optimizer/tests/test_session_optimizer.py`
- Modify: `skills/skill-self-optimizer/scripts/analyze-session.py`

- [x] **Step 1: Write the failing tests**

```python
    def test_expected_test_failures_do_not_create_repeated_failure_pattern(self):
        messages = [
            {'role': 'assistant', 'content': '先验证红灯，确认测试按预期失败。', 'timestamp': '2026-04-16T00:00:01Z', 'message_origin_hint': 'assistant_input'}
        ]
        tool_calls = [
            {
                'tool': 'Bash',
                'input': {'command': 'bun test shared/src/schema.test.ts'},
                'success': False,
                'error': 'Exit code 1\nTest failed',
                'id': 'bash-1',
                'timestamp': '2026-04-16T00:00:02Z',
            },
            {
                'tool': 'Bash',
                'input': {'command': 'bun test shared/src/schema.test.ts'},
                'success': False,
                'error': 'Exit code 1\nTest failed',
                'id': 'bash-2',
                'timestamp': '2026-04-16T00:00:03Z',
            },
            {
                'tool': 'Bash',
                'input': {'command': 'bun test shared/src/schema.test.ts'},
                'success': False,
                'error': 'Exit code 1\nTest failed',
                'id': 'bash-3',
                'timestamp': '2026-04-16T00:00:04Z',
            },
        ]

        patterns = analyze_session.detect_patterns(messages, tool_calls)

        self.assertEqual([p for p in patterns if p['type'] == 'repeated_failures'], [])

    def test_generate_report_marks_expected_test_failure_as_observation(self):
        session_data = {
            'session_id': 'demo',
            'duration_minutes': 12,
            'total_tokens': 0,
            'skills_used': [],
            'stats': {'total_messages': 1, 'user_messages': 1, 'assistant_messages': 0},
        }
        analysis = {
            'tool_usage': {
                'total': 1,
                'success_rate': 0.8,
                'by_tool': {'Bash': {'total': 1, 'success_rate': 0.0}},
                'repeated_failures': [
                    {
                        'tool': 'Bash',
                        'category': 'expected_test_failure',
                        'count': 3,
                        'errors': ['Exit code 1'],
                        'suggestion': 'Track expected TDD failures separately from actionable execution failures',
                        'evidence': {},
                    }
                ],
            },
            'patterns': [],
            'skill_usage': {'potential_missed_triggers': []},
        }

        report = analyze_session.generate_report(session_data, analysis)

        self.assertIn('🟡 Failure observation: Bash', report)
        self.assertIn('Count separately, do not treat as high-severity execution failure', report)
        self.assertNotIn('🔴 Failure: Bash', report)
```

- [x] **Step 2: Run test to verify it fails**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests.test_expected_test_failures_do_not_create_repeated_failure_pattern skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests.test_generate_report_marks_expected_test_failure_as_observation -v`
Expected: FAIL because `detect_patterns()` currently counts all failed `Bash` commands equally and the report still renders `expected_test_failure` using the generic `Failure:` heading.

- [x] **Step 3: Write minimal implementation**

```python
def detect_patterns(messages: list, tool_calls: list) -> list:
    patterns = []

    grouped_failures = defaultdict(list)
    for i, tc in enumerate(tool_calls):
        if tc.get('success', True):
            continue
        category = classify_tool_failure(tc.get('tool', 'unknown'), tc.get('error', 'Unknown error'), tc.get('input', {}))
        if is_expected_test_failure(tc, messages):
            category = 'expected_test_failure'
        if category == 'expected_test_failure':
            continue
        grouped_failures[(tc.get('tool', 'unknown'), category)].append(i)

    for (tool, category), indices in grouped_failures.items():
        if len(indices) < 3:
            continue
        consecutive = sum(1 for i in range(len(indices) - 1) if indices[i + 1] - indices[i] <= 2)
        if consecutive >= 2:
            patterns.append({
                'type': 'repeated_failures',
                'severity': 'high',
                'description': f'{category} repeated {len(indices)} times in {tool}',
                'suggestion': build_failure_suggestion(tool, category, ''),
            })

    return patterns
```

```python
                severity_icon = '🟡' if failure['category'] == 'expected_test_failure' else '🔴'
                heading = 'Failure observation' if failure['category'] == 'expected_test_failure' else 'Failure'
                lines.append(f"### {issue_num}. {severity_icon} {heading}: {failure['tool']}")
```

- [x] **Step 4: Run test to verify it passes**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests.test_expected_test_failures_do_not_create_repeated_failure_pattern skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests.test_generate_report_marks_expected_test_failure_as_observation -v`
Expected: PASS with no repeated-failure pattern for expected test failures and a report section labeled as an observation.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/tests/test_session_optimizer.py skills/skill-self-optimizer/scripts/analyze-session.py
git commit -m "fix(skill-self-optimizer): separate expected test failures"
```

### Task 4: Group repeated failures by actionable category

**Files:**
- Modify: `skills/skill-self-optimizer/tests/test_session_optimizer.py`
- Modify: `skills/skill-self-optimizer/scripts/analyze-session.py`

- [x] **Step 1: Write the failing tests**

```python
    def test_detect_patterns_groups_repeated_failures_by_category(self):
        tool_calls = [
            {
                'tool': 'Edit',
                'input': {'file_path': '/tmp/demo.py'},
                'success': False,
                'error': 'Found 2 matches of the string to replace, but replace_all is false.',
                'id': 'edit-1',
                'timestamp': '2026-04-16T00:00:00Z',
            },
            {
                'tool': 'Edit',
                'input': {'file_path': '/tmp/demo.py'},
                'success': False,
                'error': 'Found 2 matches of the string to replace, but replace_all is false.',
                'id': 'edit-2',
                'timestamp': '2026-04-16T00:00:01Z',
            },
            {
                'tool': 'Edit',
                'input': {'file_path': '/tmp/demo.py'},
                'success': False,
                'error': 'Found 2 matches of the string to replace, but replace_all is false.',
                'id': 'edit-3',
                'timestamp': '2026-04-16T00:00:02Z',
            },
        ]

        patterns = analyze_session.detect_patterns([], tool_calls)

        repeated = [p for p in patterns if p['type'] == 'repeated_failures']
        self.assertEqual(len(repeated), 1)
        self.assertIn('edit_match_ambiguity', repeated[0]['description'])

    def test_build_failure_suggestion_for_edit_match_ambiguity(self):
        suggestion = analyze_session.build_failure_suggestion(
            'Edit',
            'edit_match_ambiguity',
            'Found 2 matches of the string to replace, but replace_all is false.',
        )

        self.assertEqual(
            suggestion,
            'Widen the edit context, make the target snippet unique, or use replace_all when every match should change',
        )
```

- [x] **Step 2: Run test to verify it fails**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests.test_detect_patterns_groups_repeated_failures_by_category skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests.test_build_failure_suggestion_for_edit_match_ambiguity -v`
Expected: FAIL because duplicate-match Edit failures are still categorized as `unknown_failure` and repeated-failure descriptions still use only the tool name.

- [x] **Step 3: Write minimal implementation**

```python
    if tool == 'Edit' and 'found 2 matches' in error_lower:
        return 'edit_match_ambiguity'
    if tool == 'Edit' and 'no changes to make' in error_lower:
        return 'edit_match_ambiguity'
```

```python
    if category == 'edit_match_ambiguity':
        return 'Widen the edit context, make the target snippet unique, or use replace_all when every match should change'
```

```python
    category_failures = defaultdict(list)
    for i, tc in enumerate(tool_calls):
        if not tc.get('success', True):
            tool = tc.get('tool', 'unknown')
            category = classify_tool_failure(tool, tc.get('error', ''), tc.get('input', {}))
            if is_expected_test_failure(tc, messages):
                category = 'expected_test_failure'
            if category == 'expected_test_failure':
                continue
            category_failures[(tool, category)].append(i)

    for (tool, category), indices in category_failures.items():
        if len(indices) >= 3:
            consecutive = sum(1 for i in range(len(indices) - 1) if indices[i + 1] - indices[i] <= 2)
            if consecutive >= 2:
                patterns.append({
                    'type': 'repeated_failures',
                    'severity': 'high',
                    'description': f'{category} repeated {len(indices)} times in {tool}',
                    'suggestion': build_failure_suggestion(tool, category, ''),
                })
```

- [x] **Step 4: Run test to verify it passes**

Run: `python -m unittest skills/skill-self-optimizer/tests/test_session_optimizer.py -v`
Expected: PASS with `edit_match_ambiguity` surfaced directly in the repeated-failure description and remediation text.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/tests/test_session_optimizer.py skills/skill-self-optimizer/scripts/analyze-session.py
git commit -m "fix(skill-self-optimizer): group failures by category"
```

### Task 5: Update SKILL.md to match the implementation

**Files:**
- Modify: `skills/skill-self-optimizer/SKILL.md`

- [x] **Step 1: Write the doc update**

```markdown
**当 session ID 已知但项目目录不确定时：**
- 可以先照常传 `--project-path=<encoded-project-path>`
- 如果精确匹配失败，提取脚本会尝试同目录与全局项目目录中的前缀匹配
- 如果只有一个前缀候选，会自动命中并继续分析
- 如果前缀候选不止一个，脚本会列出候选并要求补全 session id
- 分析结果应在报告里注明真实命中的 `file_path`
```

```markdown
**常见问题：**
- `repeated_failures`: 同一 failure category 在短时间内重复出现 3+ 次（不含 `expected_test_failure`）
- `skill_not_triggered`: 应该使用 skill 但没有触发
- `excessive_tokens`: 单次任务消耗 > 50k tokens
- `user_corrections`: 用户频繁纠正
```

```markdown
1. **expected_test_failure** in Bash tool (4 times)
   - Context: TDD red phase / test verification
   - Handling: Count separately, do not treat as high-severity execution failure

2. **edit_match_ambiguity** repeated 3 times in Edit
   - Suggestion: Widen the edit context, make the target snippet unique, or use replace_all when every match should change
```
```

- [x] **Step 2: Review the doc for consistency**

Check that the extraction section mentions exact-then-prefix lookup, the repeated-failure definition excludes `expected_test_failure`, and the report example uses the updated remediation wording.
Expected: No stale wording like “同一工具连续失败 3+ 次” remains in the updated sections.

- [ ] **Step 3: Commit**

```bash
git add skills/skill-self-optimizer/SKILL.md
git commit -m "docs(skill-self-optimizer): document refined analysis behavior"
```

### Task 6: Run the focused verification suite

**Files:**
- Modify: `skills/skill-self-optimizer/tests/test_session_optimizer.py` (only if a final fix is needed)
- Read: `skills/skill-self-optimizer/scripts/extract-session.py`
- Read: `skills/skill-self-optimizer/scripts/analyze-session.py`
- Read: `skills/skill-self-optimizer/SKILL.md`

- [x] **Step 1: Run the full skill-self-optimizer test module**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer -v`
Expected: PASS with all `ExtractSessionTests` and `AnalyzeSessionTests` green.

- [ ] **Step 2: If a test fails, make the minimal fix and rerun**

```python
# Only if needed: adjust the implementation or expected strings in the touched test cases,
# then rerun the same unittest command until the suite is green.
```

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer -v`
Expected: PASS after the minimal follow-up fix.

- [ ] **Step 3: Commit the final green state**

```bash
git add skills/skill-self-optimizer/scripts/extract-session.py skills/skill-self-optimizer/scripts/analyze-session.py skills/skill-self-optimizer/tests/test_session_optimizer.py skills/skill-self-optimizer/SKILL.md
git commit -m "test(skill-self-optimizer): cover refined extraction and analysis behavior"
```

## Acceptance Checklist

- [x] A truncated but unique session id resolves correctly.
- [x] Ambiguous session prefixes fail with actionable candidate output.
- [x] Expected TDD red-phase failures are shown as observations, not repeated-failure alerts.
- [x] Repeated failures are described by failure category, not only by tool name.
- [x] Edit duplicate-match failures map to `edit_match_ambiguity` with specific remediation text.
- [x] `SKILL.md` matches the implementation behavior and report terminology.
