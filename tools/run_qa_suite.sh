#!/usr/bin/env bash
# Tea in the Hegemony — QA suite entrypoint
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.local/bin:${PATH}"

STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_DIR="${QA_OUT_DIR:-}"
if [[ -z "${OUT_DIR}" ]]; then
  # Prefer project store when mounted
  if [[ -d /cursor/stores/self/internal/qa ]]; then
    OUT_DIR="/cursor/stores/self/internal/qa"
  else
    OUT_DIR="${ROOT}/tests/validation/reports"
  fi
fi
mkdir -p "${OUT_DIR}"

echo "=== QA Suite ${STAMP} ==="
echo "repo=${ROOT}"
echo "out=${OUT_DIR}"

PASS=0
FAIL=0
RESULTS=()

run_check() {
  local name="$1"
  shift
  local logfile="${OUT_DIR}/${name}.json"
  local rc=0
  set +e
  "$@" >"${logfile}" 2>"${OUT_DIR}/${name}.stderr.txt"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    echo "PASS  ${name}"
    RESULTS+=("PASS ${name}")
    PASS=$((PASS + 1))
  else
    echo "FAIL  ${name} (exit ${rc})"
    RESULTS+=("FAIL ${name}")
    FAIL=$((FAIL + 1))
  fi
  return 0
}

run_check validate_narrative python3 tools/validate_narrative.py --repo "$ROOT" --json
run_check simulate_strategies python3 tools/simulate_strategies.py --repo "$ROOT" --json
run_check save_roundtrip python3 tools/save_roundtrip.py --repo "$ROOT" --json
run_check godot_project_load bash scripts/ci/godot_headless_load.sh

# GDScript unit tests if Core provided a runner
if [[ -f tests/run_tests.gd ]] || [[ -f tests/validation/run_validation.gd ]]; then
  run_check godot_gdscript_tests bash scripts/ci/godot_run_tests.sh
fi

MATRIX="${OUT_DIR}/pass_fail_matrix.md"
{
  echo "# QA Pass/Fail Matrix"
  echo
  echo "Generated: ${STAMP} (UTC)"
  echo
  echo "| Check | Result |"
  echo "|-------|--------|"
  for line in "${RESULTS[@]}"; do
    status="${line%% *}"
    name="${line#* }"
    echo "| \`${name}\` | **${status}** |"
  done
  echo
  echo "Totals: ${PASS} passed, ${FAIL} failed"
} >"${MATRIX}"

echo
echo "Matrix written to ${MATRIX}"
echo "Totals: ${PASS} passed, ${FAIL} failed"

# Always exit 0 from suite aggregator when content not ready? No — surface failures.
if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
exit 0
