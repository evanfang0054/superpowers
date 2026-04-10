---
name: post-deploy-monitoring
description: "Use after deploying code to production. Monitors for console errors, performance regressions, and page failures. Invoke when asked to 'monitor deploy', 'check production', 'canary check', or after running deployment commands."
---

# Post-Deploy Monitoring

## Overview

Deploying code is not the end — verification that it works in production is essential. This skill provides a structured approach to post-deployment monitoring.

**Core principle:** Deploy is not done until production health is verified.

**Announce at start:** "I'm using the post-deploy-monitoring skill to verify production health."

## When to Use

**Invoke this skill after:**
- Running deployment commands (`git push`, `deploy`, etc.)
- Merging PRs that trigger auto-deploy
- When asked to "check if deploy is healthy"
- When asked to "monitor the canary"

## The Process

### Step 1: Identify What to Monitor

Ask or determine:
```
1. What URL(s) should I check?
2. How long should I monitor? (default: 5 minutes)
3. What's the expected behavior?
4. Are there specific endpoints or pages that changed?
```

### Step 2: Baseline Check

Before monitoring, establish baseline:

```bash
# Check if site is reachable
curl -s -o /dev/null -w '%{http_code}' <URL>

# Check response time
curl -s -o /dev/null -w '%{time_total}' <URL>
```

Record:
- HTTP status code (expect 200)
- Response time baseline
- Any initial errors

### Step 3: Monitoring Loop

Run periodic checks during the monitoring window:

**Health Checks:**
```
Every 30 seconds for <duration>:
  1. HTTP status check — all monitored URLs return expected codes
  2. Response time check — no significant degradation (>2x baseline)
  3. Error log check — if accessible, scan for new errors
```

**What to Watch For:**

| Signal | Healthy | Unhealthy |
|--------|---------|-----------|
| HTTP Status | 200, 201, 204 | 500, 502, 503, 504 |
| Response Time | Within 2x baseline | >2x baseline or timeout |
| Error Rate | Same as pre-deploy | Increased after deploy |
| Page Load | Complete render | Partial or failed |

### Step 4: Report Findings

**If Healthy:**
```
Post-deploy monitoring complete (5 minutes):

✓ All endpoints returning 200
✓ Response times within baseline (avg: 245ms)
✓ No new errors detected

Production health verified. Deploy successful.
```

**If Issues Found:**
```
Post-deploy monitoring detected issues:

✗ /api/users returning 500 (was 200)
✗ Response time degraded: 1.2s (baseline: 200ms)
✗ New error in logs: "TypeError: Cannot read property 'id' of undefined"

Recommendation: Consider rollback or hotfix.
```

### Step 5: Suggest Next Actions

**On Success:**
- Close monitoring
- Update any status dashboards
- Notify team if applicable

**On Failure:**
- Suggest rollback command
- Identify which commit likely caused the issue
- Offer to help debug with `systematic-debugging` skill

## Quick Reference

| Check | Command | Expected |
|-------|---------|----------|
| HTTP status | `curl -s -o /dev/null -w '%{http_code}' URL` | 200 |
| Response time | `curl -s -o /dev/null -w '%{time_total}' URL` | < baseline × 2 |
| DNS resolution | `dig +short domain` | Returns IP |
| SSL validity | `curl -vI https://URL 2>&1 \| grep expire` | Not expired |

## Monitoring Duration Guidelines

| Deploy Type | Suggested Duration |
|-------------|-------------------|
| Hotfix | 2-3 minutes |
| Feature | 5-10 minutes |
| Major release | 15-30 minutes |
| Infrastructure | 30+ minutes |

## Red Flags

**Stop and alert immediately if:**
- 500 errors on critical paths
- Response time > 10x baseline
- Error rate spike > 5x normal
- Complete page failures
- SSL/TLS errors

**Don't ignore:**
- Intermittent failures (may indicate race condition)
- Slow degradation (may indicate memory leak)
- Increased latency on specific endpoints

## Integration

**Called after:**
- **finishing-a-development-branch** (Option 2: Create PR → merge → deploy)
- Manual deployment commands

**Works with:**
- **systematic-debugging** — If issues found, use for root cause analysis
- **session-learnings** — Log operational insights discovered during monitoring

## Limitations

This skill provides basic HTTP-level monitoring. For comprehensive monitoring:
- Use dedicated APM tools (DataDog, New Relic, etc.)
- Check application-specific metrics
- Review cloud provider dashboards
- Check database performance

This skill is a quick sanity check, not a replacement for proper observability infrastructure.
