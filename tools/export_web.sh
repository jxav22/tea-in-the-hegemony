#!/usr/bin/env bash
# Export Compatibility Web build (single-threaded) + itch.io ZIP.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
  if [[ -x "$ROOT/.bin/godot" ]]; then
    GODOT="$ROOT/.bin/godot"
  elif command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  else
    echo "Godot binary not found (set GODOT= or place .bin/godot)" >&2
    exit 1
  fi
fi

OUT_DIR="${OUT_DIR:-$ROOT/builds/web}"
ITCH_DIR="${ITCH_DIR:-$ROOT/builds/itch}"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$ITCH_DIR"

echo "== Exporting Web (single-threaded / Compatibility) =="
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT_DIR/index.html"
# Ensure Pages serves without Jekyll interference
touch "$OUT_DIR/.nojekyll"
# Drop any accidental .import sidecars if the editor touched the export dir
find "$OUT_DIR" -name '*.import' -delete

ZIP="$ITCH_DIR/tea-in-the-hegemony-web.zip"
rm -f "$ZIP"
(
  cd "$OUT_DIR"
  zip -9 -r "$ZIP" . -x "*.zip"
)
echo "Web build: $OUT_DIR"
echo "itch ZIP:  $ZIP"
ls -lah "$OUT_DIR" | head -20
ls -lah "$ZIP"
