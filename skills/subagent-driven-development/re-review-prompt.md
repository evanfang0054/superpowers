# Scoped Re-Review Prompt Template

Use after a task fix, or after the single final-review fixer. This is not a
whole-branch review.

```
Subagent (general-purpose):
  description: "Re-review Task N findings"
  model: [MODEL — REQUIRED]
  prompt: |
    Re-review only the findings below after their attempted fix.

    Read: [BRIEF_FILE], [REPORT_FILE], and [FIX_PACKAGE]. The package covers
    `FIX_BASE..HEAD`; read it before judging the implementer's report. The
    report is evidence to verify, never a substitute for reading the package.

    ## Original open findings
    [OPEN_FINDINGS]

    For every original finding, return exactly `ADDRESSED` or `NOT ADDRESSED`
    with package evidence. Also report only Critical/Important breakage newly
    introduced by the fix diff. Put anything else under `Out-of-scope
    observations`; it must not enter this fix loop.

    Do NOT turn this into a whole-branch review. Do NOT inspect unchanged code
    except where a concrete risk from this fix diff requires one focused check.

    ## Output
    ### Original findings
    - [finding]: ADDRESSED | NOT ADDRESSED — [evidence]

    ### New Critical/Important breakage in fix diff
    - [finding, or None]

    ### Out-of-scope observations
    - [observation, or None]

    ### Round verdict
    [Clean | Needs fixes | BLOCKED]
```

**Inputs:** `[OPEN_FINDINGS]`, brief path, the same task report path, and the
`FIX_BASE..HEAD` review package path. The controller creates it with
`"$SDD_SKILL_DIR/scripts/review-package" PLAN_FILE FIX_BASE HEAD`.
