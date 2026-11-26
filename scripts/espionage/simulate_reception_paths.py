#!/usr/bin/env python3
"""Offline simulator for Reception trade-off paths (no Godot / no LLM).

Mirrors MissionReport outcome logic enough to prove professional-without-romance
and human-without-full-intel endings are both reachable.
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

GENUINE_IDS = {
    "shared_something_real",
    "mem_maris_freight_joke",
    "mem_cloak_hypothesis",
    "mem_ending_connection",
    "mem_ending_human",
    "mem_maris_page_four",
    "mem_split_help",
}

TAG_CHAR = {
    "maris": "maris_quell",
    "moth": "clerk_moth",
    "wren": "wren_halden",
    "taly": "taly_renn",
    "sera": "sera_kade",
    "pim": "pim_orel",
    "voss": "edrin_voss",
}


def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def infer_char(effect: dict) -> str:
    if effect.get("char") or effect.get("character"):
        return str(effect.get("char") or effect.get("character"))
    tags = [str(t).lower() for t in effect.get("tags", [])]
    mid = str(effect.get("id", "")).lower()
    for t in tags:
        if t in TAG_CHAR:
            return TAG_CHAR[t]
        for key, cid in TAG_CHAR.items():
            if key in t:
                return cid
    for key, cid in TAG_CHAR.items():
        if key in mid:
            return cid
    return "cassian_vale"


class Sim:
    def __init__(self, mission: dict, evidence_catalog: dict):
        self.flags: dict = {}
        self.rels: dict[str, dict] = {}
        self.memories: dict[str, set[str]] = {}
        self.memory_tags: dict[str, set[str]] = {}
        self.heat = 0
        self.blown = False
        self.inconsistencies = 0
        self.stated_facts: dict = {}
        self.evidence = {
            frag["id"]: {
                "obtained": False,
                "verified": False,
                "contradicts": list(frag.get("contradicts", [])),
            }
            for frag in evidence_catalog.get("fragments", [])
        }
        self.objectives = {
            o["id"]: {
                "status": o.get("status", "hidden"),
                "required": o.get("required", True),
                "category": o.get("category", "intel"),
            }
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
            char = infer_char(effect)
            mid = effect["id"]
            self.memories.setdefault(char, set()).add(mid)
            for t in effect.get("tags", []):
                self.memory_tags.setdefault(char, set()).add(str(t))
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
                self.heat = max(self.heat, 80)
            elif action == "slip":
                key = effect.get("key", "slip")
                val = effect.get("value", "")
                if key in self.stated_facts and self.stated_facts[key] != val:
                    self.inconsistencies += 1
                self.stated_facts[key] = val
                self.heat = min(100, self.heat + int(effect.get("heat", 15)))
                self.inconsistencies += 1
            elif action == "assert":
                key = effect.get("key", "")
                val = effect.get("value", "")
                if key and key in self.stated_facts and self.stated_facts[key] != val and val != "":
                    self.inconsistencies += 1
                    self.heat = min(100, self.heat + int(effect.get("heat", 12)))
                elif key and val != "":
                    self.stated_facts[key] = val
            elif action == "adjust_heat":
                self.heat = max(0, min(100, self.heat + int(effect.get("delta", 0))))
            elif action == "repair":
                delta = int(effect.get("delta", -5))
                if delta > 0:
                    delta = -delta
                if not self.blown:
                    self.heat = max(0, min(100, self.heat + delta))
            if self.heat >= 80:
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
        if self.evidence.get("frag.shipping_delta", {}).get("obtained") or (
            self.evidence.get("frag.guest_cipher", {}).get("obtained")
            and self.evidence.get("frag.pim_rumour", {}).get("obtained")
        ):
            self.objectives["obj.obtain_fragment"]["status"] = "complete"

    def apply_path_flags(self, path_id: str) -> None:
        if path_id in (
            "path.human_first",
            "path.balanced",
            "path.pro_extract",
            "path.pro_cold",
            "path.costly_success",
        ):
            self.flags["met_maris"] = True
            self.objectives["obj.contact_maris"]["status"] = "complete"
        if path_id in ("path.pro_extract", "path.pro_cold", "path.balanced", "path.costly_success"):
            self.flags["identified_voss"] = True
            self.objectives["obj.identify_voss"]["status"] = "complete"
            self.evidence.setdefault(
                "frag.voss_confirm", {"obtained": False, "verified": False, "contradicts": []}
            )
            self.evidence["frag.voss_confirm"]["obtained"] = True
        if path_id == "path.human_first":
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

    def genuine(self) -> bool:
        for mems in self.memories.values():
            if mems & GENUINE_IDS:
                return True
            if "genuine" in self.memory_tags.get(
                next((c for c, m in self.memories.items() if m is mems), ""), set()
            ):
                return True
        for char, tags in self.memory_tags.items():
            if "genuine" in tags:
                return True
        m = self.ensure_rel("maris_quell")
        return m["affection"] >= 18

    def score(self) -> dict:
        cover_score = 0 if self.blown else 100 - self.heat
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

        human = 40
        m = self.ensure_rel("maris_quell")
        human += max(-20, min(25, m["trust"]))
        human += max(-15, min(30, m["affection"]))
        human += max(-10, min(15, m["comfort"] // 2))
        human -= max(0, min(35, m["suspicion"]))
        human += max(-15, min(15, m["perceived_authenticity"] // 2))
        genuine = self.genuine()
        if genuine:
            human += 12
        all_mems = set()
        for s in self.memories.values():
            all_mems |= s
        if "felt_used" in all_mems:
            human -= 18
        if "mem_skipped_impress" in all_mems:
            human += 4
        if "mem_helped_taly" in all_mems:
            human += 6
        if "mem_abandoned_taly" in all_mems:
            human -= 6
        human = max(0, min(100, human))

        outcome = self.derive_outcome(pro, human, genuine)
        return {
            "professional_score": pro,
            "human_score": human,
            "cover_score": cover_score,
            "heat": self.heat,
            "blown": self.blown,
            "genuine": genuine,
            "outcome_id": outcome,
            "objectives": {k: v["status"] for k, v in self.objectives.items()},
            "evidence_obtained": [k for k, v in self.evidence.items() if v.get("obtained")],
            "evidence_verified": [k for k, v in self.evidence.items() if v.get("verified")],
            "memories": {k: sorted(v) for k, v in self.memories.items()},
        }

    def derive_outcome(self, pro: int, human: int, genuine: bool) -> str:
        if self.blown:
            return "blown"
        fragment_got = self.evidence.get("frag.shipping_delta", {}).get("obtained") or self.objectives[
            "obj.obtain_fragment"
        ]["status"] == "complete"
        pro_high = pro >= 55
        pro_low = pro < 40
        human_connection = genuine or human >= 60
        if pro_high and human_connection and self.heat < 40 and fragment_got:
            return "balanced"
        if pro_high and not human_connection:
            return "clean_professional" if self.heat < 35 else "professional_costly"
        if human_connection and (pro_low or not fragment_got):
            return "human_first"
        req_failed = sum(
            1 for o in self.objectives.values() if o["required"] and o["status"] == "failed"
        )
        if req_failed or (pro_low and not human_connection and human < 40):
            return "compromised"
        return "partial"


def run_path(mission: dict, evidence: dict, path: dict) -> dict:
    sim = Sim(deepcopy(mission), deepcopy(evidence))
    for effect in path.get("effects_sketch", []):
        sim.apply(effect)
    sim.apply_path_flags(path["id"])
    all_mems = set()
    for s in sim.memories.values():
        all_mems |= s
    if all_mems & GENUINE_IDS or any("genuine" in tags for tags in sim.memory_tags.values()):
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
            f"cover={result['cover_score']} heat={result['heat']} genuine={result['genuine']} blown={result['blown']}"
        )
        print(f"  objectives={result['objectives']}")
        print(f"  evidence={result['evidence_obtained']} verified={result['evidence_verified']}")
        print(f"  memories={result['memories']}")

    print("\n" + "=" * 60)
    print(f"Distinct outcomes reached: {sorted(outcomes)}")
    pro_ok = "clean_professional" in outcomes or "professional_costly" in outcomes
    human_ok = "human_first" in outcomes
    print(f"Professional-without-romance reachable: {pro_ok}")
    print(f"Human-without-full-intel reachable: {human_ok}")
    print(f"Balanced reachable: {'balanced' in outcomes}")
    if not (pro_ok and human_ok):
        all_ok = False
        print("FAIL: both professional and human outcomes must be reachable", file=sys.stderr)
    return 0 if all_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
