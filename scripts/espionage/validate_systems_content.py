#!/usr/bin/env python3
"""Validate Agent C mission/evidence JSON against required fields (no Godot)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIMS = {
    "trust",
    "familiarity",
    "suspicion",
    "respect",
    "affection",
    "comfort",
    "perceived_authenticity",
}


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def main() -> int:
    mission = json.loads((ROOT / "content/missions/reception.json").read_text())
    evidence = json.loads((ROOT / "content/evidence/reception_evidence.json").read_text())
    cookbook = json.loads((ROOT / "content/missions/reception_effect_cookbook.json").read_text())

    if not mission.get("id"):
        fail("mission missing id")
    objs = mission.get("objectives", [])
    if len(objs) < 4:
        fail("expected >=4 objectives")
    required_ids = {"obj.contact_maris", "obj.identify_voss", "obj.obtain_fragment", "obj.maintain_cover"}
    have = {o["id"] for o in objs}
    if not required_ids.issubset(have):
        fail(f"missing required objectives: {required_ids - have}")

    paths = mission.get("meta", {}).get("trade_off_design", {}).get("example_paths", [])
    if len(paths) < 5:
        fail("expected >=5 trade-off example paths")
    for p in paths:
        if "effects_sketch" not in p or "expected_outcome" not in p:
            fail(f"path {p.get('id')} incomplete")

    frags = evidence.get("fragments", [])
    ids = {f["id"] for f in frags}
    for need in ("frag.shipping_delta", "frag.guest_cipher", "frag.pim_rumour", "frag.voss_confirm"):
        if need not in ids:
            fail(f"missing evidence {need}")
    for f in frags:
        if "claims" not in f or "contradicts" not in f:
            fail(f"fragment {f.get('id')} missing claims/contradicts")
        if "verified" not in f:
            fail(f"fragment {f.get('id')} missing verified")

    # Cookbook ops must be known.
    known = {"rel", "memory", "cover", "evidence", "objective", "knowledge", "set_flag", "heat"}
    for beat, body in cookbook.get("beats", {}).items():
        for eff in body.get("effects", []):
            op = eff.get("op")
            if op not in known:
                fail(f"cookbook beat {beat} unknown op {op}")
            if op == "rel":
                for k in eff:
                    if k in DIMS:
                        continue

    print("Systems content validation OK")
    print(f"  objectives={len(objs)} fragments={len(frags)} paths={len(paths)} cookbook_beats={len(cookbook.get('beats', {}))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
