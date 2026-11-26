#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$ROOT/.bin/godot}"
if [[ ! -x "$GODOT" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  else
    echo "Godot binary not found. Set GODOT= or place at .bin/godot" >&2
    exit 1
  fi
fi
cd "$ROOT"
echo "== Import project =="
"$GODOT" --headless --editor --quit-after 1 2>/dev/null || "$GODOT" --headless --import --quit 2>/dev/null || true
echo "== Core tests =="
"$GODOT" --headless --path "$ROOT" res://tests/core/test_runner.tscn
echo "== Boot smoke =="
"$GODOT" --headless --path "$ROOT" res://scenes/main/boot.tscn
echo "All verification passed."
