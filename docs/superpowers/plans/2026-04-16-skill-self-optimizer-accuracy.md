# Skill Self-Optimizer Accuracy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `skill-self-optimizer` produce trustworthy session analysis by preserving session provenance, filtering hook/summary noise, recognizing expected TDD test failures, and deduplicating recommendations.

**Architecture:** Extend extraction to emit provenance and message-origin metadata, then refactor analysis to classify noisy versus actionable failures before generating the markdown report. Validate the behavior with focused unit tests and a regression rerun against session `ac3a4a38-1ae1-4fcc-901d-929eef8e7661`.

**Tech Stack:** Python 3, `unittest`, existing `extract-session.py` / `analyze-session.py` scripts, markdown session reports

---

## File Structure

- Modify: `skills/skill-self-optimizer/scripts/extract-session.py`
  - Add session provenance fields and message origin hints to extracted JSON.
- Modify: `skills/skill-self-optimizer/scripts/analyze-session.py`
  - Add richer failure classification, trigger noise filtering, recommendation dedupe, and provenance-aware reporting.
- Modify: `skills/skill-self-optimizer/tests/test_session_optimizer.py`
  - Add unit coverage for provenance extraction, noisy message filtering, expected test failure handling, and deduplicated recommendations.
- Modify: `skills/skill-self-optimizer/SKILL.md`
  - Update the documented output/report shape so it matches the new analysis behavior.
- Read during verification: `.superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661.json`
  - Use as the regression fixture input for the final report rerun.
- Update during verification: `.superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661-report.md`
  - Re-generate and inspect after the code changes land.

### Task 1: Add provenance metadata to extraction

**Files:**
- Modify: `skills/skill-self-optimizer/scripts/extract-session.py`
- Test: `skills/skill-self-optimizer/tests/test_session_optimizer.py`

- [x] **Step 1: Write the failing tests**

```python
    def test_find_session_file_reports_fallback_source_and_actual_project_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            projects_dir = Path(tmp)
            requested_dir = projects_dir / '-Users-arwen-Desktop-Arwen-evanfang-superpowers'
            actual_dir = projects_dir / '-Users-arwen-Desktop-Arwen-evanfang-hapi'
            requested_dir.mkdir()
            actual_dir.mkdir()
            session_file = actual_dir / 'session-1.jsonl'
            session_file.write_text('', encoding='utf-8')

            with patch.object(extract_session, 'get_claude_projects_dir', return_value=projects_dir):
                found = extract_session.find_session_file('session-1', requested_dir)

            self.assertEqual(found['path'], session_file)
            self.assertEqual(found['session_source'], 'fallback-global-search')
            self.assertEqual(found['actual_project_dir'], actual_dir)

    def test_extract_session_includes_requested_and_actual_provenance_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            session_file = Path(tmp) / 'session.jsonl'
            session_file.write_text(
                json.dumps({
                    'type': 'user',
                    'timestamp': '2026-04-16T00:00:00Z',
                    'message': {'content': 'Stop hook feedback:\n\nTask: demo'}
                }),
                encoding='utf-8',
            )

            extracted = extract_session.extract_session(
                session_file,
                requested_project_path='-Users-arwen-Desktop-Arwen-evanfang-superpowers',
                actual_project_dir='-Users-arwen-Desktop-Arwen-evanfang-hapi',
                session_source='fallback-global-search',
            )

            self.assertEqual(extracted['requested_project_path'], '-Users-arwen-Desktop-Arwen-evanfang-superpowers')
            self.assertEqual(extracted['actual_project_dir'], '-Users-arwen-Desktop-Arwen-evanfang-hapi')
            self.assertEqual(extracted['session_source'], 'fallback-global-search')
            self.assertEqual(extracted['messages'][0]['message_origin_hint'], 'hook_feedback')
```

- [x] **Step 2: Run tests to verify they fail**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests -v`
Expected: FAIL because `find_session_file()` still returns only a `Path`, and `extract_session()` does not accept provenance arguments or emit `message_origin_hint`.

- [x] **Step 3: Write the minimal implementation**

```python
def classify_message_origin(role: str, content: str) -> str:
    lowered = content.strip().lower()
    if lowered.startswith('stop hook feedback:'):
        return 'hook_feedback'
    if lowered.startswith('this session is being continued from a previous conversation'):
        return 'resume_summary'
    if lowered.startswith('base directory for this skill:') or '<command-message>' in lowered:
        return 'skill_payload'
    if not content.strip():
        return 'empty'
    return 'user_input' if role == 'user' else 'assistant_input'


def find_session_file(session_id: str, project_dir: Path | None = None) -> dict | None:
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
                'path': candidate,
                'actual_project_dir': directory,
                'session_source': 'requested-project' if index == 0 and project_dir else 'fallback-global-search',
            }

    return None


def extract_session(
    session_file: Path,
    requested_project_path: str | None = None,
    actual_project_dir: str | Path | None = None,
    session_source: str = 'requested-project',
) -> dict:
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

            msg_type = data.get('type')
            timestamp = data.get('timestamp') or data.get('ts')
            if timestamp:
                if start_time is None:
                    start_time = timestamp
                end_time = timestamp

            if msg_type in ('user', 'assistant'):
                message_data = data.get('message', {})
                content = message_data.get('content', '')
                if isinstance(content, list):
                    text_parts = []
                    for part in content:
                        if isinstance(part, dict) and part.get('type') == 'text':
                            text_parts.append(part.get('text', ''))
                        elif isinstance(part, str):
                            text_parts.append(part)
                    content = '\n'.join(text_parts)

                messages.append({
                    'role': msg_type,
                    'content': content[:2000] if content else '',
                    'timestamp': timestamp,
                    'message_origin_hint': classify_message_origin(msg_type, content if isinstance(content, str) else ''),
                })

    return {
        'session_id': session_file.stem,
        'actual_session_file_path': str(session_file),
        'requested_project_path': requested_project_path,
        'actual_project_dir': str(actual_project_dir) if actual_project_dir else str(session_file.parent),
        'session_source': session_source,
        'start_time': start_time,
        'end_time': end_time,
        'duration_minutes': None,
        'messages': messages,
        'tool_calls': tool_calls,
        'skills_used': list(skills_used),
        'total_tokens': total_tokens,
    }
```

- [x] **Step 4: Run tests to verify they pass**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.ExtractSessionTests -v`
Expected: PASS with the two new provenance tests green and the previous extraction tests still passing.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/scripts/extract-session.py skills/skill-self-optimizer/tests/test_session_optimizer.py
git commit -m "feat: capture session provenance in optimizer extraction"
```

### Task 2: Classify expected test failures and noisy triggers

**Files:**
- Modify: `skills/skill-self-optimizer/scripts/analyze-session.py`
- Test: `skills/skill-self-optimizer/tests/test_session_optimizer.py`

- [x] **Step 1: Write the failing tests**

```python
    def test_classifies_expected_test_failures_from_tdd_red_phase(self):
        tool_calls = [
            {
                'tool': 'Bash',
                'input': {'command': 'bun test shared/src/schema.test.ts'},
                'success': False,
                'error': 'Exit code 1\nTest failed',
                'id': 'bash-1',
                'timestamp': '2026-04-16T00:00:02Z',
            }
        ]
        messages = [
            {'role': 'assistant', 'content': '先验证红灯，确认测试按预期失败。', 'timestamp': '2026-04-16T00:00:01Z', 'message_origin_hint': 'assistant_input'}
        ]

        analysis = analyze_session.analyze_tool_usage(tool_calls, messages)

        failures = {failure['category']: failure for failure in analysis['repeated_failures']}
        self.assertIn('expected_test_failure', failures)
        self.assertEqual(failures['expected_test_failure']['count'], 1)

    def test_ignores_hook_feedback_and_skill_payload_when_detecting_missed_triggers(self):
        messages = [
            {'role': 'user', 'content': 'Stop hook feedback:\n\nTask: demo failing', 'timestamp': '2026-04-16T00:00:00Z', 'message_origin_hint': 'hook_feedback'},
            {'role': 'user', 'content': 'Base directory for this skill: /tmp/skill\n# Test-Driven Development', 'timestamp': '2026-04-16T00:00:01Z', 'message_origin_hint': 'skill_payload'},
            {'role': 'user', 'content': 'Please fix this bug in the sync flow', 'timestamp': '2026-04-16T00:00:02Z', 'message_origin_hint': 'user_input'},
        ]

        analysis = analyze_session.analyze_skill_usage(messages, [])

        self.assertEqual(len(analysis['potential_missed_triggers']), 1)
        self.assertEqual(analysis['potential_missed_triggers'][0]['evidence']['timestamp'], '2026-04-16T00:00:02Z')
```

- [x] **Step 2: Run tests to verify they fail**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests -v`
Expected: FAIL because `analyze_tool_usage()` does not inspect message context, and `analyze_skill_usage()` does not yet honor `message_origin_hint`.

- [x] **Step 3: Write the minimal implementation**

```python
def is_expected_test_failure(tool_call: dict, messages: list[dict]) -> bool:
    if tool_call.get('tool') != 'Bash' or tool_call.get('success', True):
        return False

    command = tool_call.get('input', {}).get('command', '').lower()
    if not any(marker in command for marker in (' test', 'pytest', 'vitest', 'bun test')):
        return False

    relevant_messages = [
        message for message in messages
        if message.get('message_origin_hint') not in {'hook_feedback', 'resume_summary', 'skill_payload', 'empty'}
    ]
    for message in reversed(relevant_messages[-6:]):
        content = message.get('content', '')
        if any(marker in content for marker in ('红灯', '按预期失败', 'failing test first', 'verify it fails')):
            return True
    return False


def analyze_tool_usage(tool_calls: list, messages: list | None = None) -> dict:
    messages = messages or []
    ...
            error = tc.get('error', 'Unknown error')
            category = classify_tool_failure(tool, error, tc.get('input', {}))
            if is_expected_test_failure(tc, messages):
                category = 'expected_test_failure'
            by_tool[tool]['failures'].append({
                'error': error,
                'input': tc.get('input', {}),
                'category': category,
                ...
            })


def analyze_skill_usage(messages: list, skills_used: list) -> dict:
    ...
        origin = msg.get('message_origin_hint', '')
        if origin in {'hook_feedback', 'resume_summary', 'skill_payload', 'empty'}:
            continue
```

- [x] **Step 4: Run tests to verify they pass**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests -v`
Expected: PASS with the new expected-test-failure and message-origin filtering tests green.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/scripts/analyze-session.py skills/skill-self-optimizer/tests/test_session_optimizer.py
git commit -m "feat: reduce optimizer noise from tdd and hook context"
```

### Task 3: Deduplicate recommendations and report session provenance

**Files:**
- Modify: `skills/skill-self-optimizer/scripts/analyze-session.py`
- Test: `skills/skill-self-optimizer/tests/test_session_optimizer.py`

- [x] **Step 1: Write the failing tests**

```python
    def test_generate_report_includes_session_provenance_block(self):
        session_data = {
            'session_id': 'demo',
            'requested_project_path': '-Users-arwen-Desktop-Arwen-evanfang-superpowers',
            'actual_session_file_path': '/Users/arwen/.claude/projects/-Users-arwen-Desktop-Arwen-evanfang-hapi/demo.jsonl',
            'actual_project_dir': '/Users/arwen/.claude/projects/-Users-arwen-Desktop-Arwen-evanfang-hapi',
            'session_source': 'fallback-global-search',
            'duration_minutes': 10,
            'total_tokens': 0,
            'skills_used': [],
            'stats': {'total_messages': 1, 'user_messages': 1, 'assistant_messages': 0},
        }
        analysis = {
            'tool_usage': {'total': 0, 'success_rate': 1.0, 'by_tool': {}, 'repeated_failures': []},
            'patterns': [],
            'skill_usage': {'skills_triggered': [], 'potential_missed_triggers': []},
        }

        report = analyze_session.generate_report(session_data, analysis)

        self.assertIn('## Session Provenance', report)
        self.assertIn('fallback-global-search', report)
        self.assertIn('-Users-arwen-Desktop-Arwen-evanfang-hapi', report)

    def test_generate_report_deduplicates_recommendations(self):
        session_data = {
            'session_id': 'demo',
            'duration_minutes': 10,
            'total_tokens': 0,
            'skills_used': [],
            'stats': {'total_messages': 1, 'user_messages': 1, 'assistant_messages': 0},
        }
        analysis = {
            'tool_usage': {
                'total': 2,
                'success_rate': 0.5,
                'by_tool': {},
                'repeated_failures': [
                    {'tool': 'Bash', 'category': 'shell_wrapper_failure', 'count': 1, 'errors': ['a'], 'suggestion': 'Capture the wrapped shell command separately and surface the failing template or script path', 'evidence': {}},
                    {'tool': 'Skill', 'category': 'shell_wrapper_failure', 'count': 1, 'errors': ['b'], 'suggestion': 'Capture the wrapped shell command separately and surface the failing template or script path', 'evidence': {}},
                ],
            },
            'patterns': [],
            'skill_usage': {'skills_triggered': [], 'potential_missed_triggers': []},
        }

        report = analyze_session.generate_report(session_data, analysis)

        self.assertEqual(report.count('Capture the wrapped shell command separately and surface the failing template or script path'), 1)
```

- [x] **Step 2: Run tests to verify they fail**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests -v`
Expected: FAIL because the report has no provenance section and recommendation lines are emitted once per failure bucket.

- [x] **Step 3: Write the minimal implementation**

```python
def dedupe_recommendations(patterns: list, repeated_failures: list, missed_triggers: list, success_rate: float) -> list[str]:
    ordered = []
    seen = set()

    for pattern in patterns:
        suggestion = pattern.get('suggestion')
        if suggestion and suggestion not in seen:
            seen.add(suggestion)
            ordered.append(suggestion)

    for failure in repeated_failures:
        suggestion = failure.get('suggestion')
        if suggestion and suggestion not in seen:
            seen.add(suggestion)
            ordered.append(suggestion)

    if missed_triggers:
        for skill in sorted({m['skill'] for m in missed_triggers if m['confidence'] != 'low'}):
            suggestion = f"Review and expand `{skill}` skill description for better triggering"
            if suggestion not in seen:
                seen.add(suggestion)
                ordered.append(suggestion)

    if success_rate < 0.9 and 'Add pre-flight validation before tool calls' not in seen:
        seen.add('Add pre-flight validation before tool calls')
        ordered.append('Add pre-flight validation before tool calls')

    return ordered


def generate_report(session_data: dict, analysis: dict) -> str:
    ...
    lines.append('## Session Provenance')
    lines.append('')
    lines.append(f"- Requested project: `{session_data.get('requested_project_path', 'unknown')}`")
    lines.append(f"- Actual session file: `{session_data.get('actual_session_file_path', session_data.get('file_path', 'unknown'))}`")
    lines.append(f"- Actual project dir: `{session_data.get('actual_project_dir', 'unknown')}`")
    lines.append(f"- Session source: `{session_data.get('session_source', 'requested-project')}`")
    lines.append('')
    ...
    recommendations = dedupe_recommendations(patterns, repeated_failures, missed_triggers, tool_analysis.get('success_rate', 1.0))
    lines.extend(f"- [ ] {suggestion}" for suggestion in recommendations)
```

- [x] **Step 4: Run tests to verify they pass**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests -v`
Expected: PASS with provenance and recommendation dedupe tests green.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/scripts/analyze-session.py skills/skill-self-optimizer/tests/test_session_optimizer.py
git commit -m "feat: surface provenance in optimizer reports"
```

### Task 4: Update skill documentation and rerun the regression report

**Files:**
- Modify: `skills/skill-self-optimizer/SKILL.md`
- Read: `.superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661.json`
- Update: `.superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661-report.md`

- [x] **Step 1: Write the failing documentation/test expectation**

Add this assertion to `skills/skill-self-optimizer/tests/test_session_optimizer.py`:

```python
    def test_generate_report_surfaces_session_source_and_tdd_noise_handling(self):
        session_data = {
            'session_id': 'demo',
            'requested_project_path': 'requested-project',
            'actual_session_file_path': '/tmp/demo.jsonl',
            'actual_project_dir': '/tmp/project',
            'session_source': 'fallback-global-search',
            'duration_minutes': 1411.1,
            'total_tokens': 0,
            'skills_used': [],
            'stats': {'total_messages': 1, 'user_messages': 1, 'assistant_messages': 0},
        }
        analysis = {
            'tool_usage': {
                'total': 1,
                'success_rate': 1.0,
                'by_tool': {},
                'repeated_failures': [
                    {'tool': 'Bash', 'category': 'expected_test_failure', 'count': 4, 'errors': ['Exit code 1'], 'suggestion': 'Track expected TDD failures separately from actionable execution failures', 'evidence': {}},
                ],
            },
            'patterns': [],
            'skill_usage': {'skills_triggered': [], 'potential_missed_triggers': []},
        }

        report = analyze_session.generate_report(session_data, analysis)

        self.assertIn('Track expected TDD failures separately from actionable execution failures', report)
        self.assertIn('fallback-global-search', report)
```

- [x] **Step 2: Run tests to verify it fails**

Run: `python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer.AnalyzeSessionTests.test_generate_report_surfaces_session_source_and_tdd_noise_handling -v`
Expected: FAIL until the report and documentation reflect the new reporting model consistently.

- [x] **Step 3: Write the minimal implementation**

Update `skills/skill-self-optimizer/SKILL.md` so the documented report shape includes provenance and distinguishes expected TDD failures from actionable failures:

```markdown
## Session Provenance
- Requested project: `-Users-arwen-Desktop-Arwen-evanfang-superpowers`
- Actual session file: `~/.claude/projects/-Users-arwen-Desktop-Arwen-evanfang-hapi/ac3a4...jsonl`
- Session source: `fallback-global-search`

## Issues Found
1. **expected_test_failure** in Bash tool (4 times)
   - Context: TDD red phase / test verification
   - Handling: Count separately, do not treat as high-severity execution failure
```

Then rerun the regression report with the exact command below:

```bash
python skills/skill-self-optimizer/scripts/analyze-session.py \
  --input .superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661.json \
  --output .superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661-report.md
```

- [x] **Step 4: Run verification to confirm the final behavior**

Run both commands:

```bash
python -m unittest skills.skill-self-optimizer.tests.test_session_optimizer -v
python skills/skill-self-optimizer/scripts/analyze-session.py \
  --input .superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661.json \
  --output .superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661-report.md
```

Expected:
- All tests PASS
- The regenerated report includes a `Session Provenance` section
- The report no longer treats hook/summary-derived trigger evidence as a real missed trigger
- The report does not emit duplicate recommendations

- [ ] **Step 5: Commit**

```bash
git add skills/skill-self-optimizer/SKILL.md skills/skill-self-optimizer/tests/test_session_optimizer.py .superpowers/session-analysis/ac3a4a38-1ae1-4fcc-901d-929eef8e7661-report.md
git commit -m "docs: align optimizer skill output with noise-aware analysis"
```

## Self-Review

- **Spec coverage:**
  - Provenance fields and cross-project visibility are covered by Task 1 and Task 3.
  - Hook/summary/skill payload noise filtering and TDD expected-failure recognition are covered by Task 2.
  - Recommendation dedupe and report restructuring are covered by Task 3.
  - Regression validation against `ac3a4a38-1ae1-4fcc-901d-929eef8e7661` and documentation alignment are covered by Task 4.
- **Placeholder scan:** No `TODO`/`TBD` placeholders remain; every code-changing step includes exact code or markdown to add and exact commands to run.
- **Type consistency:** The plan consistently uses `requested_project_path`, `actual_session_file_path`, `actual_project_dir`, `session_source`, and `message_origin_hint` across extraction, analysis, tests, and report generation.
