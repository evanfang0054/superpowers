#!/usr/bin/env bash
# coverage-metrics.sh - Measure harness coverage across dimensions
#
# Usage:
#   coverage-metrics.sh [project_root]
#
# Dimensions measured:
#   - Feedforward skill coverage
#   - Feedback skill coverage
#   - Computational sensor coverage
#   - Loop detection enabled
#   - Sprint contract usage
#   - Reasoning budget coverage

set -euo pipefail

# --- --trends: 委托给 query-phase-metrics ---
if [ "${1:-}" = "--trends" ]; then
  shift
  SCRIPT_DIR_CM="$(cd "$(dirname "$0")" && pwd)"
  exec "$SCRIPT_DIR_CM/query-phase-metrics.sh" "$@"
fi

PROJECT_ROOT="${1:-.}"
SKILLS_DIR="${PROJECT_ROOT}/skills"
SENSORS_FILE="${PROJECT_ROOT}/.agent-harness/sensors.json"
CONTRACTS_DIR="${PROJECT_ROOT}/docs/agent-harness/contracts"

echo "=== Harness Coverage Report ==="
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Count skills with when_to_use tags
ff_count=$(grep -rl "\[feedforward\]" "${SKILLS_DIR}"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)
fb_count=$(grep -rl "\[feedback\]" "${SKILLS_DIR}"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)
total_skills=$(ls -d "${SKILLS_DIR}"/*/ 2>/dev/null | wc -l | tr -d ' ')

echo "Feedforward Coverage:     ${ff_count} skills labeled"
echo "Feedback Coverage:        ${fb_count} skills labeled"
echo "Total Skills:             ${total_skills}"
echo ""

# Sensor coverage
if [ -f "${SENSORS_FILE}" ]; then
    # 用环境变量传 SENSORS_FILE，避免路径含撇号/反斜杠时触发 Python 源码注入（同 #17/#18/#19 bug class）
    sensor_count=$(SENSORS_FILE="${SENSORS_FILE}" python3 -c '
import json, os
try:
    with open(os.environ["SENSORS_FILE"]) as f:
        print(len(json.load(f).get("sensors", [])))
except Exception:
    print("?")
' 2>/dev/null || echo "?")
    echo "Computational Sensors:   ${sensor_count} configured"
else
    echo "Computational Sensors:   NOT CONFIGURED (.agent-harness/sensors.json missing)"
fi

# Loop detection
if [ -f "${PROJECT_ROOT}/scripts/loop-detector.sh" ]; then
    echo "Loop Detection:          ENABLED"
else
    echo "Loop Detection:          DISABLED"
fi

# Sprint contract usage
if [ -d "${CONTRACTS_DIR}" ]; then
    contract_count=$(ls "${CONTRACTS_DIR}"/*.contract.md 2>/dev/null | wc -l | tr -d ' ')
    echo "Sprint Contracts:        ${contract_count} files"
else
    echo "Sprint Contracts:        0 files (directory not created)"
fi

# Reasoning budget
effort_count=$(grep -rl "^effort:" "${SKILLS_DIR}"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)
echo "Reasoning Budget:         ${effort_count} skills configured"
echo ""
echo "=== Gaps ==="

if [ ! -f "${SENSORS_FILE}" ]; then
    echo "- Missing sensors.json (run /harness-init or /computational-sensors)"
fi
if [ ! -d "${CONTRACTS_DIR}" ]; then
    echo "- No sprint contracts directory (run /sprint-contract for next feature)"
fi
if [ "${effort_count}" -lt 7 ]; then
    echo "- Only ${effort_count}/7 recommended skills have effort configured"
fi
