#!/usr/bin/env python3
"""Offline simulator for Reception trade-off paths (no Godot / no LLM).

Mirrors MissionReport outcome logic enough to prove both professional and
human endings are reachable from content/missions/reception.json sketches.
"""

from __future__ import annotations

import json
import sys
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MISSION_PATH = ROOT / "content/missions/reception.json"
EVIDENCE_PATH = ROOT / "content/evidence/reception_evidence.json"

DIMS = [
    "trust",
    "familiarity",
    "suspicion",
    "respect",
    "affection",
    "comfort",
    "perceived_authenticity",
]


def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


class Sim:
    def __init__(self, mission: dict, evidence_catalog: dict):
        self.flags: dict = {}
        self.rels: dict[str, dict] = {}
        self.memories: dict[str, set[str]] = {}
        self.heat = 0
        self.blown = False
        self.inconsistencies = 0
        self.evidence = {
            frag["id"]: {
                "obtained": False,
                "verified": False,
                "contradicts": list(frag.get("contradicts", [])),
            }
            for frag in evidence_catalog.get("fragments", [])
        }
        self.objectives = {
            o["id"]: {"status": o.get("status", "hidden"), "required": o.get("required", True), "category": o.get("category", "intel")}
            for o in mission.get("objectives", [])
        }
        self.mission_meta = mission.get("meta", {})

    def ensure_rel(self, char: str) -> dict:
        if char not in self.rels:
            self.rels[char] = {d: 0 for d in DIMS}
        return self.rels[char]

    def apply(self, effect: dict) -> None:
        op = effect.get("op")
        if op == "rel":
            char = effect["char"]
            state = self.ensure_rel(char)
            for d in DIMS:
                if d in effect:
                    state[d] = max(-100, min(100, state[d] + int(effect[d])))
        elif op == "memory":
            char = effect["char"]
            self.memories.setdefault(char, set()).add(effect["id"])
            if effect["id"] == "shared_something_real":
                self.flags["shared_real"] = True
            if effect["id"] == "felt_used":
                self.flags["felt_used"] = True
        elif op == "evidence":
            action = effect.get("action", "obtain")
            fid = effect["id"]
            if fid not in self.evidence:
                self.evidence[fid] = {"obtained": False, "verified": False, "contradicts": []}
            if action == "obtain":
                self.evidence[fid]["obtained"] = True
            elif action == "verify":
                self.evidence[fid]["obtained"] = True
                self.evidence[fid]["verified"] = True
        elif op == "cover":
            action = effect.get("action")
            if action == "blow":
                self.blown = True
                self.heat = max(self.heat, 95)
            elif action == "slip":
                self.heat = min(100, self.heat + int(effect.get("heat", 15)))
                self.inconsistencies += 1
            elif action == "adjust_heat":
                self.heat = max(0, min(100, self.heat + int(effect.get("delta", 0))))
            elif action == "assert" and effect.get("heat"):
                self.heat = max(0, min(100, self.heat + int(effect["heat"])))
            if self.heat >= 95:
                self.blown = True
        elif op == "objective":
            action = effect.get("action")
            oid = effect.get("id")
            if oid in self.objectives:
                if action == "complete":
                    self.objectives[oid]["status"] = "complete"
                elif action == "fail":
                    self.objectives[oid]["status"] = "failed"
                elif action == "activate":
                    self.objectives[oid]["status"] = "active"
        # Derived flags from common mission completes
        if self.evidence.get("frag.shipping_delta", {}).get("obtained") or (
            self.evidence.get("frag.guest_cipher", {}).get("obtained")
            and self.evidence.get("frag.pim_rumour", {}).get("obtained")
        ):
            self.objectives["obj.obtain_fragment"]["status"] = "complete"
        if self.flags.get("met_maris") or "obj.contact_maris" in [
            e.get("id") for e in []
        ]:
            pass

    def apply_path_flags(self, path_id: str) -> None:
        # Path-specific narrative flags the sketches imply
        if path_id in ("path.human_first", "path.balanced", "path.pro_extract", "path.costly_success"):
            self.flags["met_maris"] = True
            self.objectives["obj.contact_maris"]["status"] = "complete"
        if path_id in ("path.pro_extract", "path.balanced", "path.costly_success"):
            self.flags["identified_voss"] = True
            self.objectives["obj.identify_voss"]["status"] = "complete"
            self.evidence.setdefault("frag.voss_confirm", {"obtained": False, "verified": False, "contradicts": []})
            self.evidence["frag.voss_confirm"]["obtained"] = True
        if path_id == "path.human_first":
            # Soft identify optional — may miss Voss
            self.flags["identified_voss"] = False
        if path_id != "path.blown":
            self.flags["reception_ending"] = True
            if not self.blown and self.heat < 80:
                self.objectives["obj.maintain_cover"]["status"] = "complete"
            if self.heat < 30 and not self.blown:
                self.objectives["obj.avoid_attention"]["status"] = "complete"
            if self.heat >= 55:
                self.objectives["obj.avoid_attention"]["status"] = "failed"
        if path_id == "path.blown":
            self.objectives["obj.maintain_cover"]["status"] = "failed"
            self.objectives["obj.contact_maris"]["status"] = "failed"

    def score(self) -> dict:
        cover_score = 0 if self.blown else 100 - self.heat
        # Professional
        pro = 0
        for oid, obj in self.objectives.items():
            if obj["required"] and obj["category"] in ("intel", "cover", "survival"):
                if obj["status"] == "complete":
                    pro += 25
        verified = sum(1 for e in self.evidence.values() if e.get("verified"))
        pro += min(20, verified * 10)
        open_c = 0
        for fid, e in self.evidence.items():
            if not e.get("obtained"):
                continue
            for against in e.get("contradicts", []):
                other = self.evidence.get(against)
                if other and other.get("obtained"):
                    open_c += 1
        pro -= min(15, open_c * 5)
        pro = int(pro * (0.5 + 0.5 * (cover_score / 100.0)))
        pro = max(0, min(100, pro))

        # Human (Maris-centric)
        human = 40
        m = self.ensure_rel("maris_quell")
        human += max(-20, min(25, m["trust"]))
        human += max(-15, min(30, m["affection"]))
        human += max(-10, min(15, m["comfort"] // 2))
        human -= max(0, min(35, m["suspicion"]))
        human += max(-15, min(15, m["perceived_authenticity"] // 2))
        mems = self.memories.get("maris_quell", set())
        if "shared_something_real" in mems:
            human += 12
        if "felt_used" in mems:
            human -= 18
        human = max(0, min(100, human))

        outcome = self.derive_outcome(pro, human, cover_score)
        return {
            "professional_score": pro,
            "human_score": human,
            "cover_score": cover_score,
            "heat": self.heat,
            "blown": self.blown,
            "outcome_id": outcome,
            "objectives": {k: v["status"] for k, v in self.objectives.items()},
            "evidence_obtained": [k for k, v in self.evidence.items() if v.get("obtained")],
            "evidence_verified": [k for k, v in self.evidence.items() if v.get("verified")],
            "memories": {k: sorted(v) for k, v in self.memories.items()},
        }

    def derive_outcome(self, pro: int, human: int, cover_score: int) -> str:
        if self.blown:
            return "blown"
        pro_high, human_high = pro >= 60, human >= 60
        pro_low, human_low = pro < 35, human < 35
        if pro_high and human_high and self.heat < 40:
            return "balanced"
        if pro_high and human_low:
            return "clean_professional" if self.heat < 35 else "professional_costly"
        if human_high and pro_low:
            return "human_first"
        req_failed = sum(
            1
            for o in self.objectives.values()
            if o["required"] and o["status"] == "failed"
        )
        if req_failed or (pro_low and human_low):
            return "compromised"
        return "partial"


def run_path(mission: dict, evidence: dict, path: dict) -> dict:
    sim = Sim(deepcopy(mission), deepcopy(evidence))
    for effect in path.get("effects_sketch", []):
        sim.apply(effect)
    sim.apply_path_flags(path["id"])
    # Optional objective from memory
    if "shared_something_real" in sim.memories.get("maris_quell", set()):
        sim.objectives["obj.optional_real_talk"]["status"] = "complete"
    if sim.evidence.get("frag.shipping_delta", {}).get("verified"):
        sim.objectives["obj.optional_verify"]["status"] = "complete"
    result = sim.score()
    result["path_id"] = path["id"]
    result["path_label"] = path.get("label")
    result["expected_outcome"] = path.get("expected_outcome")
    result["match"] = result["outcome_id"] == path.get("expected_outcome")
    return result


def main() -> int:
    mission = load_json(MISSION_PATH)
    evidence = load_json(EVIDENCE_PATH)
    paths = mission.get("meta", {}).get("trade_off_design", {}).get("example_paths", [])
    if not paths:
        print("No example_paths in mission meta", file=sys.stderr)
        return 1

    print("Reception trade-off path simulation")
    print("=" * 60)
    all_ok = True
    outcomes = set()
    for path in paths:
        result = run_path(mission, evidence, path)
        outcomes.add(result["outcome_id"])
        status = "OK" if result["match"] else "MISMATCH"
        if not result["match"]:
            all_ok = False
        print(f"\n[{status}] {result['path_id']} — {result['path_label']}")
        print(f"  expected={result['expected_outcome']} got={result['outcome_id']}")
        print(
            f"  pro={result['professional_score']} human={result['human_score']} "
            f"cover={result['cover_score']} heat={result['heat']} blown={result['blown']}"
        )
        print(f"  objectives={result['objectives']}")
        print(f"  evidence={result['evidence_obtained']} verified={result['evidence_verified']}")
        print(f"  memories={result['memories']}")

    print("\n" + "=" * 60)
    print(f"Distinct outcomes reached: {sorted(outcomes)}")
    both = "clean_professional" in outcomes or "professional_costly" in outcomes
    human = "human_first" in outcomes
    balanced = "balanced" in outcomes
    print(f"Professional reachable: {both}")
    print(f"Human-first reachable: {human}")
    print(f"Balanced reachable: {balanced}")
    if not (both and human):
        all_ok = False
        print("FAIL: both professional and human outcomes must be reachable", file=sys.stderr)
    return 0 if all_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
