#!/usr/bin/env bash
# Run GDScript validation tests headlessly when present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

GODOT="$(command -v godot || true)"
if [[ -z "${GODOT}" ]]; then
  echo '{"ok": false, "reason": "godot binary not found"}'
  exit 1
fi

SCRIPT=""
if [[ -f "${ROOT}/tests/validation/run_validation.gd" ]]; then
  SCRIPT="res://tests/validation/run_validation.gd"
elif [[ -f "${ROOT}/tests/run_tests.gd" ]]; then
  SCRIPT="res://tests/run_tests.gd"
else
  echo '{"ok": false, "reason": "no gdscript test runner"}'
  exit 1
fi

LOG="$(mktemp)"
set +e
"${GODOT}" --headless --path "${ROOT}" -s "${SCRIPT}" >"${LOG}" 2>&1
RC=$?
set -e

python3 - "${LOG}" "${RC}" "${SCRIPT}" <<'PY'
import json, sys, pathlib
log_path, rc, script = sys.argv[1], int(sys.argv[2]), sys.argv[3]
log_text = pathlib.Path(log_path).read_text(encoding="utf-8", errors="replace")
print(json.dumps({
    "ok": rc == 0,
    "returncode": rc,
    "script": script,
    "log_tail": log_text[-4000:],
}, indent=2))
sys.exit(0 if rc == 0 else 1)
PY
RC2=$?
rm -f "${LOG}"
exit ${RC2}
