#!/usr/bin/env python3
"""Mirror PathFlagSync ending_id derivation + debrief twin-flag pairs."""

from __future__ import annotations

import sys

COVER_BURNED = "cover_burned"
SERA_WINS = "sera_wins"
BALANCED = "balanced"
PROFESSIONAL = "professional_win"
HUMAN = "human_cost"
CONNECTION = "connection"
MIXED = "mixed"

OUTCOME_MAP = {
    "blown": COVER_BURNED,
    "balanced": BALANCED,
    "clean_professional": PROFESSIONAL,
    "professional_costly": PROFESSIONAL,
    "human_first": HUMAN,
}


def derive(flags: dict, outcome: str | None = None) -> str:
    if flags.get("cover_blown"):
        return COVER_BURNED
    if outcome == "blown":
        return COVER_BURNED
    if flags.get("sera_has_fragment") and not flags.get("got_fragment"):
        return SERA_WINS
    if outcome in OUTCOME_MAP and outcome != "blown":
        return OUTCOME_MAP[outcome]
    if flags.get("got_fragment") and flags.get("helped_taly"):
        return BALANCED
    if flags.get("got_fragment") and flags.get("abandoned_taly"):
        return PROFESSIONAL
    if flags.get("helped_taly") and not flags.get("got_fragment"):
        return HUMAN
    if flags.get("genuine_with_maris"):
        return CONNECTION
    return MIXED


def should_overwrite(existing: str, derived: str, force: bool) -> bool:
    return force or existing in ("", MIXED) or derived == COVER_BURNED


def main() -> int:
    cases = [
        ({"cover_blown": True}, None, COVER_BURNED),
        ({"sera_has_fragment": True, "got_fragment": False}, None, SERA_WINS),
        ({"got_fragment": True, "helped_taly": True}, None, BALANCED),
        ({"got_fragment": True, "abandoned_taly": True}, None, PROFESSIONAL),
        ({"helped_taly": True, "got_fragment": False}, None, HUMAN),
        ({"genuine_with_maris": True, "skipped_impress": True}, None, CONNECTION),
        ({}, "clean_professional", PROFESSIONAL),
        ({}, "human_first", HUMAN),
        ({}, "balanced", BALANCED),
        ({}, None, MIXED),
    ]
    for flags, outcome, expected in cases:
        got = derive(flags, outcome)
        assert got == expected, (flags, outcome, got, expected)

    # Soft sync preserves Narrative ending unless empty/mixed/cover burned.
    assert not should_overwrite("professional_win", BALANCED, force=False)
    assert should_overwrite("", BALANCED, force=False)
    assert should_overwrite(MIXED, BALANCED, force=False)
    assert should_overwrite("professional_win", COVER_BURNED, force=False)
    assert should_overwrite("professional_win", BALANCED, force=True)

    # Debrief router twin fallbacks (same pairs as debrief.json).
    twin_routes = [
        ({"sera_has_fragment": True, "got_fragment": False}, SERA_WINS),
        ({"got_fragment": True, "helped_taly": True}, BALANCED),
        ({"got_fragment": True, "abandoned_taly": True}, PROFESSIONAL),
        ({"helped_taly": True, "got_fragment": False}, HUMAN),
        ({"genuine_with_maris": True, "skipped_impress": True}, CONNECTION),
    ]
    for flags, expected in twin_routes:
        assert derive(flags) == expected, (flags, expected)

    print("Path flag derivation tests OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
