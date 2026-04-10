---
name: documentation-sync
description: "Use after code changes are committed, before creating PR or merging. Scans all project documentation files, cross-references the diff, and updates README/ARCHITECTURE/CHANGELOG/CONTRIBUTING to match what shipped. Invoke when asked to 'sync docs', 'update documentation', or after finishing a feature branch."
---

# Documentation Sync

## Overview

Documentation drift is silent technical debt. Code changes without doc updates create confusion.

**Core principle:** Every code change that affects behavior should reflect in documentation.

**Announce at start:** "I'm using the documentation-sync skill to ensure docs match the code."

## When to Use

**Proactively invoke this skill:**
- After completing a feature branch (before `finishing-a-development-branch`)
- When asked to "sync docs", "update documentation", "post-ship docs"
- After merging a PR (to catch missed updates)
- When documentation seems stale

**Suggested integration point:** Between verification and PR creation in the development workflow.

## The Process

### Step 1: Gather the Diff

```bash
# Get the base branch
BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo "main")

# Get all changed files
git diff $BASE --name-only

# Get detailed diff for context
git diff $BASE --stat
```

Save the list of changed files and understand what changed.

### Step 2: Inventory Documentation Files

Scan the project for documentation files:

```bash
# Find all doc files
find . -maxdepth 3 -type f \( \
  -name "README.md" -o \
  -name "README*.md" -o \
  -name "ARCHITECTURE.md" -o \
  -name "CONTRIBUTING.md" -o \
  -name "CHANGELOG.md" -o \
  -name "CHANGELOG" -o \
  -name "*.md" -path "*/docs/*" \
\) 2>/dev/null | grep -v node_modules | grep -v vendor
```

Read each documentation file to understand current content.

### Step 3: Cross-Reference Analysis

For each documentation file, analyze:

| Check | Question |
|-------|----------|
| **Accuracy** | Does any statement contradict the new code? |
| **Completeness** | Are new features/APIs/configs documented? |
| **Examples** | Do code examples still work? |
| **References** | Are file paths, function names, class names still correct? |
| **Version** | Does VERSION file need update? |

**Build a change list:**
```
README.md:
  - [ ] Add new feature X to "Features" section
  - [ ] Update example in "Quick Start" (old API → new API)

ARCHITECTURE.md:
  - [ ] Add new module Y to component diagram description
  - [ ] Update data flow section

CHANGELOG.md:
  - [ ] Add entry for this release
```

### Step 4: Classify Changes

**Automatic updates (do directly):**
- Factual corrections clearly from the diff
- Adding items to existing tables/lists
- Updating file paths, function names, class names
- Fixing clearly outdated examples

**Ask before updating:**
- Narrative or philosophy changes
- Security-related documentation
- Large rewrites or removals
- Cross-doc contradictions that require judgment
- VERSION bump decisions
- New CHANGELOG entries (wording)

### Step 5: Execute Updates

For each file that needs updates:

1. Read current content
2. Make factual updates directly
3. For judgment calls, present options:

```
CHANGELOG.md needs an entry for this release.

Option A: "Added new authentication module with JWT support"
Option B: "feat(auth): JWT-based authentication system"

Which style matches your project?
```

### Step 6: Verify and Report

After updates:

```bash
# Show what changed in docs
git diff --name-only | grep -E '\.(md|txt)$'
```

Present summary:
```
Documentation sync complete:

Updated:
  - README.md: Added feature X, updated Quick Start example
  - CHANGELOG.md: Added release entry

No changes needed:
  - ARCHITECTURE.md: Already current
  - CONTRIBUTING.md: Not affected by this change

Skipped (awaiting input):
  - VERSION: Bump from 1.2.0 to 1.3.0? (y/n)
```

## Quick Reference

| Doc Type | Auto-Update | Ask First |
|----------|-------------|-----------|
| README feature lists | Yes | - |
| README examples | Yes | - |
| README philosophy/intro | - | Yes |
| ARCHITECTURE structure | Yes | - |
| ARCHITECTURE decisions | - | Yes |
| CHANGELOG entries | - | Yes (wording) |
| VERSION bumps | - | Yes |
| File paths/names | Yes | - |
| Security sections | - | Yes |

## Red Flags

**Never:**
- Remove documentation without explicit approval
- Change the project's voice or tone without asking
- Update security docs without review
- Assume you understand intent better than the author

**Always:**
- Read the full diff before making assumptions
- Preserve existing formatting style
- Keep CHANGELOG in the project's existing format
- Ask when uncertain

## Integration

**Called before:**
- **finishing-a-development-branch** - Sync docs before PR/merge
- **verification-before-completion** - Docs are part of completeness

**Works with:**
- **requesting-code-review** - Reviewer should check doc accuracy

## Common Mistakes

**Missing implicit documentation:**
- Problem: Config files, env vars, CLI flags changed but not documented
- Fix: Check for any user-facing changes, not just code

**Over-updating:**
- Problem: Rewriting docs that don't need changes
- Fix: Only update what the diff actually affects

**Format inconsistency:**
- Problem: New entries don't match existing style
- Fix: Follow the exact format already used in each file
