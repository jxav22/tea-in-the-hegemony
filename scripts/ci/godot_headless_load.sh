#!/usr/bin/env bash
# Verify Godot project loads headlessly. Emits JSON to stdout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

if [[ ! -f "${ROOT}/project.godot" ]]; then
  echo '{"ok": false, "reason": "project.godot missing", "attempted": false}'
  exit 1
fi

GODOT="$(command -v godot || true)"
if [[ -z "${GODOT}" ]]; then
  echo '{"ok": false, "reason": "godot binary not found", "attempted": false}'
  exit 1
fi

VERSION="$("${GODOT}" --version 2>/dev/null || true)"
LOG="$(mktemp)"
set +e
"${GODOT}" --headless --path "${ROOT}" --quit-after 1 >"${LOG}" 2>&1
RC=$?
set -e

python3 - "${LOG}" "${RC}" "${VERSION}" <<'PY'
import json, sys, pathlib
log_path, rc, version = sys.argv[1], int(sys.argv[2]), sys.argv[3]
log_text = pathlib.Path(log_path).read_text(encoding="utf-8", errors="replace")
crash = any(s in log_text.lower() for s in ("script error", "assertion failed", "segfault", "engine crashed"))
ok = rc == 0 and not crash
print(json.dumps({
    "ok": ok,
    "attempted": True,
    "returncode": rc,
    "godot_version": version,
    "crash_markers": crash,
    "log_tail": log_text[-3000:],
}, indent=2))
sys.exit(0 if ok else 1)
PY
RC2=$?
rm -f "${LOG}"
exit ${RC2}
