#!/usr/bin/env python3
"""Lightweight cover slip→repair→blown chain checks (mirrors CoverManager rules)."""

from __future__ import annotations

import sys

BLOW = 80
HIGH = 55


class Cover:
    def __init__(self):
        self.heat = 0
        self.blown = False
        self.facts = {}
        self.incs = []

    def assert_fact(self, key, value):
        if self.blown:
            return {"ok": False, "error": "cover_blown"}
        if key in self.facts and self.facts[key] != value and value:
            self.incs.append((key, self.facts[key], value))
            self.adjust(12)
            return {"ok": True, "consistent": False}
        self.facts[key] = value
        return {"ok": True, "consistent": True}

    def slip(self, key, value, heat=15):
        if self.blown:
            return {"ok": False, "error": "cover_blown"}
        kind = "slip"
        if key in self.facts and self.facts[key] and value and self.facts[key] != value:
            kind = "slip_contradiction"
            heat = max(heat, heat + 5)
        self.incs.append((key, self.facts.get(key), value, kind))
        if value:
            self.facts[key] = value
        self.adjust(heat)
        return {"ok": True, "kind": kind, "heat": self.heat, "blown": self.blown}

    def adjust(self, delta, repair=False):
        if self.blown and delta < 0 and not repair:
            return {"ignored": True, "heat": self.heat}
        self.heat = max(0, min(100, self.heat + delta))
        if self.heat >= BLOW and not self.blown:
            self.blow()
        return {"heat": self.heat, "blown": self.blown}

    def repair(self, delta=-8, force_unblow=False):
        if delta > 0:
            delta = -delta
        out = self.adjust(delta, repair=True)
        if force_unblow and self.blown and self.heat < BLOW:
            self.blown = False
            out["unblown"] = True
        out["blown"] = self.blown
        return out

    def blow(self):
        self.blown = True
        self.heat = max(self.heat, BLOW)


def main() -> int:
    c = Cover()
    c.assert_fact("employer", "Ministry Trade Liaison Office")
    r = c.slip("employer", "private consultancy", heat=18)
    assert r["kind"] == "slip_contradiction", r
    assert c.heat >= 23
    # Repair before blow
    c.repair(-20)
    assert not c.blown
    assert c.heat < HIGH
    # Escalate to blow
    c.adjust(BLOW)
    assert c.blown and c.heat >= BLOW
    # Repair without force_unblow keeps blown
    c.repair(-50)
    assert c.blown
    # force unblow
    c.repair(-1, force_unblow=True)
    assert not c.blown
    # Slip while blown refused
    c.blow()
    refused = c.slip("name", "Cassian Vale")
    assert refused.get("error") == "cover_blown"
    print("Cover chain tests OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
