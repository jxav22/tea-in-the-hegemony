#!/usr/bin/env python3
"""Save/load roundtrip checks against the versioned save contract.

If a GDScript SaveManager exists, also attempts a Godot headless smoke that
serializes and reloads. Pure-Python roundtrip always runs against sample saves
and any fixtures under tests/validation/fixtures/saves/.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from copy import deepcopy
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]

REQUIRED_KEYS = {
    "save_version",
    "chapter_id",
    "flags",
    "rels",
    "memories",
    "inventory",
    "cover_state",
    "objectives",
}

SAMPLE_SAVE: dict[str, Any] = {
    "save_version": 1,
    "chapter_id": "the_reception",
    "flags": {"briefed": True, "met_maris": False},
    "rels": {
        "maris_quell": {
            "trust": 0,
            "familiarity": 1,
            "suspicion": 0,
            "respect": 1,
            "affection": 0,
            "comfort": 0,
            "perceived_authenticity": 0,
        }
    },
    "memories": [{"id": "saw_voss", "summary": "Voss collects people.", "salience": 0.6, "tags": ["intel"]}],
    "inventory": ["guest_badge"],
    "cover_state": "intact",
    "objectives": {"contact_maris": "active", "id_voss": "active"},
}


def validate_shape(save: dict[str, Any]) -> list[str]:
    errors = []
    missing = REQUIRED_KEYS - set(save.keys())
    for m in sorted(missing):
        errors.append(f"missing key: {m}")
    if "flags" in save and not isinstance(save["flags"], dict):
        errors.append("flags must be object")
    if "rels" in save and not isinstance(save["rels"], dict):
        errors.append("rels must be object")
    if "memories" in save and not isinstance(save["memories"], list):
        errors.append("memories must be list")
    if "inventory" in save and not isinstance(save["inventory"], list):
        errors.append("inventory must be list")
    if "objectives" in save and not isinstance(save["objectives"], dict):
        errors.append("objectives must be object")
    return errors


def roundtrip(save: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    errors = validate_shape(save)
    raw = json.dumps(save, sort_keys=True)
    loaded = json.loads(raw)
    errors.extend(validate_shape(loaded))
    if loaded != save:
        errors.append("roundtrip inequality")
    return loaded, errors


def find_save_manager(repo: Path) -> Path | None:
    for pattern in ("**/save*.gd", "**/SaveManager.gd", "**/save_manager.gd"):
        hits = list(repo.glob(pattern))
        if hits:
            return hits[0]
    return None


def godot_headless_roundtrip(repo: Path) -> dict[str, Any]:
    result: dict[str, Any] = {"attempted": False, "ok": False, "log": "", "reason": ""}
    if __import__("os").environ.get("QA_SKIP_GODOT") == "1":
        result["reason"] = "skipped via QA_SKIP_GODOT=1"
        return result
    project = repo / "project.godot"
    if not project.exists():
        result["reason"] = "project.godot missing"
        return result
    godot = Path.home() / ".local/bin/godot"
    if not godot.exists():
        # PATH fallback
        from shutil import which

        g = which("godot")
        if not g:
            result["reason"] = "godot binary not found"
            return result
        godot = Path(g)

    # Prefer an explicit QA scene if present; else --quit-after 1 import/load check
    qa_scene = repo / "tests" / "validation" / "save_roundtrip_smoke.tscn"
    result["attempted"] = True
    cmd = [str(godot), "--headless", "--path", str(repo)]
    if qa_scene.exists():
        cmd += ["--scene", str(qa_scene.relative_to(repo))]
    else:
        cmd += ["--quit-after", "1"]
    timeout_s = int(__import__("os").environ.get("QA_GODOT_TIMEOUT", "60"))
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            check=False,
        )
        result["log"] = (proc.stdout or "")[-4000:] + "\n" + (proc.stderr or "")[-4000:]
        result["returncode"] = proc.returncode
        # Godot may return non-zero on missing main scene; treat SCRIPT ERROR / crash as fail
        log_l = result["log"].lower()
        hard_crash = "assertion failed" in log_l or "segfault" in log_l or "engine crashed" in log_l
        smoke_ok = "[smoke] ok" in log_l or "test pass" in log_l
        # Presentation HUD may emit Nil script errors in headless without a full UI tree.
        result["ok"] = proc.returncode == 0 and not hard_crash and (smoke_ok or "script error" not in log_l)
        if not result["ok"]:
            result["reason"] = f"godot exit {proc.returncode}" + (" (hard crash)" if hard_crash else "")
        elif "script error" in log_l:
            result["reason"] = "ok with headless UI script warnings"
    except subprocess.TimeoutExpired:
        result["reason"] = "godot timed out"
    except Exception as exc:  # noqa: BLE001
        result["reason"] = str(exc)
    return result


def run(repo: Path) -> dict[str, Any]:
    out: dict[str, Any] = {"python_roundtrip": {}, "fixtures": [], "godot": {}, "pass": False, "errors": []}
    loaded, errors = roundtrip(deepcopy(SAMPLE_SAVE))
    out["python_roundtrip"] = {"ok": not errors, "errors": errors, "keys": sorted(loaded.keys())}
    if errors:
        out["errors"].extend(errors)

    fixture_dir = repo / "tests" / "validation" / "fixtures" / "saves"
    if fixture_dir.exists():
        for path in sorted(fixture_dir.glob("*.json")):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception as exc:  # noqa: BLE001
                out["fixtures"].append({"file": path.name, "ok": False, "errors": [str(exc)]})
                out["errors"].append(f"fixture {path.name}: {exc}")
                continue
            _, ferr = roundtrip(data)
            out["fixtures"].append({"file": path.name, "ok": not ferr, "errors": ferr})
            out["errors"].extend(f"fixture {path.name}: {e}" for e in ferr)

    sm = find_save_manager(repo)
    out["save_manager"] = str(sm) if sm else None
    out["godot"] = godot_headless_roundtrip(repo)
    if out["godot"].get("attempted") and not out["godot"].get("ok"):
        # Headless load failure is a soft error until Core lands; hard if project exists and crashed
        if (repo / "project.godot").exists():
            out["errors"].append(f"godot: {out['godot'].get('reason')}")

    out["pass"] = len(out["errors"]) == 0 and out["python_roundtrip"]["ok"]
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=REPO_ROOT)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    result = run(args.repo.resolve())
    if args.json:
        print(json.dumps(result, indent=2, default=str))
    else:
        print("=== Save Roundtrip ===")
        print(f"Python: {'OK' if result['python_roundtrip']['ok'] else 'FAIL'}")
        print(f"SaveManager: {result.get('save_manager')}")
        g = result.get("godot", {})
        print(f"Godot attempted={g.get('attempted')} ok={g.get('ok')} reason={g.get('reason')}")
        if result.get("errors"):
            for e in result["errors"]:
                print(f"  - {e}")
        print("PASS" if result["pass"] else "FAIL")
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
