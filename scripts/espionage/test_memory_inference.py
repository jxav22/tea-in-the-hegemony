#!/usr/bin/env python3
"""Mirror RelationshipManager.infer_memory_character for dialogue coverage."""

from __future__ import annotations

import json
import sys
from pathlib import Path

TAG_MAP = {
    "maris": "maris_quell",
    "moth": "clerk_moth",
    "wren": "wren_halden",
    "taly": "taly_renn",
    "sera": "sera_kade",
    "pim": "pim_orel",
    "voss": "edrin_voss",
    "cassian": "cassian_vale",
    "orth": "cassian_vale",
}
PLAYER_LOG = {
    "intel", "cipher", "advice", "comedy", "cloakroom", "ending", "loss", "heat",
    "fragment", "mission", "cover", "tradecraft", "protocol", "briefing",
}
NAME_HINTS = {
    "maris": "maris_quell",
    "moth": "clerk_moth",
    "wren": "wren_halden",
    "taly": "taly_renn",
    "sera": "sera_kade",
    "pim": "pim_orel",
    "voss": "edrin_voss",
}


def infer(effect: dict) -> str:
    tags = effect.get("tags", []) or []
    mid = str(effect.get("id", "")).lower()
    for t in tags:
        ts = str(t).lower()
        if ts in TAG_MAP:
            return TAG_MAP[ts]
        for key in TAG_MAP:
            if key in ts:
                return TAG_MAP[key]
    for key in TAG_MAP:
        if key in mid:
            return TAG_MAP[key]
    summary = str(effect.get("summary", "")).lower()
    for key, char in NAME_HINTS.items():
        if key in summary:
            return char
    for t in tags:
        if str(t).lower() in PLAYER_LOG:
            return "cassian_vale"
    if any(x in mid for x in ("cipher", "intel", "got_", "fragment", "cover")):
        return "cassian_vale"
    if "wren" in mid or "tariff" in mid:
        return "wren_halden"
    return "cassian_vale"


def walk(obj):
    if isinstance(obj, dict):
        if obj.get("op") == "memory":
            yield obj
        for v in obj.values():
            yield from walk(v)
    elif isinstance(obj, list):
        for i in obj:
            yield from walk(i)


def main() -> int:
    root = Path(__file__).resolve().parents[2] / "content" / "dialogue"
    count = 0
    by_char: dict[str, int] = {}
    for path in root.rglob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        for eff in walk(data):
            if eff.get("char") or eff.get("character"):
                continue
            char = infer(eff)
            by_char[char] = by_char.get(char, 0) + 1
            count += 1
            assert char, (path, eff.get("id"))
    assert count >= 30, count
    assert "maris_quell" in by_char, by_char
    assert "cassian_vale" in by_char, by_char
    print(f"Memory inference OK ({count} char-less → {by_char})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
