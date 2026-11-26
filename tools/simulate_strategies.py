#!/usr/bin/env python3
"""Simulate six player strategies + probe all seven Reception endings.

Strategies:
  - professional_detached
  - sincere_awkward
  - charming_deceptive
  - suspicious_investigative
  - professionally_unsuccessful_personally_successful
  - opportunistic_improvisational

Ending IDs (Narrative contract):
  cover_burned, sera_wins, balanced, professional_win, human_cost, connection, mixed
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]

EXPECTED_ENDINGS = [
    "cover_burned",
    "sera_wins",
    "balanced",
    "professional_win",
    "human_cost",
    "connection",
    "mixed",
]

# Seed flags that make finale.branch resolve to each ending (priority order aware).
ENDING_SEEDS: dict[str, dict[str, Any]] = {
    "cover_burned": {"cover_compromised": True},
    "sera_wins": {
        "cover_compromised": False,
        "sera_gained_time": True,
        "fragment_risk": True,
        "has_cipher_fragment": True,
        "helped_taly": True,
    },
    "balanced": {
        "cover_compromised": False,
        "has_cipher_fragment": True,
        "helped_taly": True,
        "sera_gained_time": False,
        "fragment_risk": False,
    },
    "professional_win": {
        "cover_compromised": False,
        "has_cipher_fragment": True,
        "abandoned_taly": True,
        "helped_taly": False,
        "sera_gained_time": False,
        "fragment_risk": False,
    },
    "human_cost": {
        "cover_compromised": False,
        "helped_taly": True,
        "has_cipher_fragment": False,
        "sera_gained_time": False,
        "fragment_risk": False,
        "abandoned_taly": False,
    },
    "connection": {
        "cover_compromised": False,
        "genuine_with_maris": True,
        "skipped_impress": True,
        "has_cipher_fragment": False,
        "helped_taly": False,
        "abandoned_taly": False,
        "sera_gained_time": False,
        "fragment_risk": False,
    },
    "mixed": {
        "cover_compromised": False,
        "has_cipher_fragment": False,
        "helped_taly": False,
        "abandoned_taly": False,
        "genuine_with_maris": False,
        "skipped_impress": False,
        "sera_gained_time": False,
        "fragment_risk": False,
    },
}

STRATEGY_WEIGHTS: dict[str, dict[str, float]] = {
    "professional_detached": {
        "professional": 3.0,
        "detached": 2.5,
        "formal": 2.0,
        "cover": 2.0,
        "mission": 2.5,
        "intel": 1.5,
        "comply": 1.5,
        "romance": -2.0,
        "sincere": -1.0,
        "charm": -0.5,
        "investigate": 0.5,
        "awkward": -1.5,
        "improv": -1.0,
        "help": -1.0,
        "personal": -1.5,
        "proceed": 1.0,
    },
    "sincere_awkward": {
        "sincere": 3.0,
        "awkward": 2.5,
        "honest": 2.5,
        "empathy": 2.0,
        "romance": 1.5,
        "personal": 2.0,
        "help": 2.0,
        "professional": -0.5,
        "deceptive": -3.0,
        "lie": -3.0,
        "charm": 0.5,
        "improv": 0.5,
        "confess": 2.0,
        "dread": 1.0,
    },
    "charming_deceptive": {
        "charm": 3.0,
        "deceptive": 3.0,
        "lie": 2.5,
        "flirt": 2.5,
        "cover": 1.5,
        "smooth": 2.0,
        "sincere": -2.0,
        "awkward": -2.0,
        "investigate": 0.5,
        "improv": 1.0,
        "romance": 1.5,
        "bluff": 2.0,
    },
    "suspicious_investigative": {
        "investigate": 3.0,
        "suspicious": 3.0,
        "probe": 2.5,
        "intel": 2.5,
        "evidence": 2.5,
        "question": 2.0,
        "tradecraft": 2.0,
        "romance": -1.5,
        "charm": 0.5,
        "professional": 1.0,
        "search": 2.0,
        "study": 2.0,
        "listen": 1.5,
    },
    "professionally_unsuccessful_personally_successful": {
        "romance": 3.0,
        "personal": 3.0,
        "sincere": 2.5,
        "empathy": 2.5,
        "help": 3.0,
        "mission": -2.0,
        "intel": -1.5,
        "cover": -1.0,
        "awkward": 1.5,
        "professional": -2.0,
        "connection": 3.0,
        "affection": 2.5,
        "honesty": 2.0,
        "genuine": 2.5,
    },
    "opportunistic_improvisational": {
        "improv": 3.0,
        "opportunistic": 3.0,
        "adapt": 2.5,
        "risk": 2.0,
        "charm": 1.5,
        "investigate": 1.0,
        "lie": 1.0,
        "sincere": 0.5,
        "professional": 0.0,
        "wildcard": 2.5,
        "pivot": 2.5,
        "seize": 2.0,
        "pim": 1.5,
    },
}

# After a pack ends, strategy picks next location start node.
LOCATION_ORDER = [
    ("foyer.arrival", {"professional": 1, "investigate": 1, "improv": 1}),
    ("salon.enter", {"personal": 2, "sincere": 2, "charm": 2, "romance": 2}),
    ("study.enter", {"investigate": 3, "professional": 2, "intel": 2}),
    ("terrace.enter", {"intel": 2, "investigate": 1, "personal": 1, "help": 1}),
    ("cloak.enter", {"improv": 1, "awkward": 1}),
]


@dataclass
class GameState:
    flags: dict[str, Any] = field(default_factory=dict)
    rels: dict[str, dict[str, float]] = field(default_factory=lambda: defaultdict(lambda: defaultdict(float)))
    memories: list[dict[str, Any]] = field(default_factory=list)
    objectives: dict[str, str] = field(default_factory=dict)
    inventory: list[str] = field(default_factory=list)
    cover_state: str = "intact"
    heat: float = 0.0
    ending: str | None = None
    path: list[str] = field(default_factory=list)
    choice_intents: list[str] = field(default_factory=list)

    def snapshot(self) -> dict[str, Any]:
        return {
            "flags": dict(self.flags),
            "rels": {c: dict(dims) for c, dims in self.rels.items()},
            "memories": list(self.memories),
            "objectives": dict(self.objectives),
            "inventory": list(self.inventory),
            "cover_state": self.cover_state,
            "heat": self.heat,
            "ending": self.ending,
            "ending_id": self.flags.get("ending_id"),
            "path": list(self.path),
            "choice_intents": list(self.choice_intents),
        }


def load_nodes(content: Path) -> dict[str, dict[str, Any]]:
    """Load dialogue nodes, preferring content/dialogue/reception/* over flat mirrors."""
    nodes: dict[str, dict[str, Any]] = {}
    dialogue = content / "dialogue"
    if not dialogue.exists():
        return nodes
    nested = sorted((dialogue / "reception").rglob("*.json")) if (dialogue / "reception").exists() else []
    flat = sorted(p for p in dialogue.glob("*.json"))
    for path in nested + flat:
        if path.name == "index.json":
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001
            continue
        items: list[dict[str, Any]] = []
        if isinstance(data, list):
            items = [x for x in data if isinstance(x, dict)]
        elif isinstance(data, dict):
            if "nodes" in data and isinstance(data["nodes"], list):
                items = [x for x in data["nodes"] if isinstance(x, dict)]
            elif "id" in data and ("text" in data or "choices" in data):
                items = [data]
        is_flat = path.parent == dialogue
        for item in items:
            nid = str(item.get("id", "")).strip()
            if not nid:
                continue
            if nid in nodes and is_flat:
                continue
            nodes[nid] = item
    return nodes


def eval_condition(cond: dict[str, Any], state: GameState) -> bool:
    if "all" in cond and isinstance(cond["all"], list):
        return all(eval_condition(c, state) for c in cond["all"] if isinstance(c, dict))
    if "any" in cond and isinstance(cond["any"], list):
        return any(eval_condition(c, state) for c in cond["any"] if isinstance(c, dict))
    op = cond.get("op", "eq")
    flag = cond.get("flag") or cond.get("key")
    if flag is None:
        return True
    val = state.flags.get(str(flag))
    expected = cond.get("value", True)
    if op in {"eq", "true", "false"}:
        if op == "true":
            return bool(val)
        if op == "false":
            return not bool(val)
        return val == expected
    if op == "neq":
        return val != expected
    if op == "has":
        return flag in state.flags and bool(state.flags[flag])
    if op == "missing":
        return flag not in state.flags or not state.flags[flag]
    try:
        fv = float(val) if val is not None else 0.0
        ev = float(expected)
    except (TypeError, ValueError):
        return False
    return {
        "gt": fv > ev,
        "gte": fv >= ev,
        "lt": fv < ev,
        "lte": fv <= ev,
    }.get(op, True)


def apply_effect(effect: dict[str, Any], state: GameState) -> None:
    op = effect.get("op") or effect.get("type")
    if op is None and "flag" in effect:
        state.flags[str(effect["flag"])] = effect.get("value", True)
        return
    aliases = {
        "add_memory": "memory",
        "add_heat": "heat",
        "set_location": "location",
        "set_cover": "cover",
    }
    op = aliases.get(op, op)
    if op in {"set_flag", "add_flag"}:
        state.flags[str(effect.get("flag"))] = effect.get("value", True)
        if effect.get("flag") == "ending_id":
            state.ending = str(effect.get("value"))
    elif op == "unset_flag":
        state.flags[str(effect.get("flag"))] = False
    elif op == "toggle_flag":
        f = str(effect.get("flag"))
        state.flags[f] = not bool(state.flags.get(f))
    elif op == "rel":
        cid = str(effect.get("char") or effect.get("character") or "unknown")
        for dim, delta in effect.items():
            if dim in {"op", "type", "char", "character", "deltas"}:
                continue
            try:
                state.rels[cid][dim] += float(delta)
            except (TypeError, ValueError):
                pass
    elif op == "memory":
        state.memories.append({"id": effect.get("id"), "summary": effect.get("summary", "")})
    elif op in {"set_objective", "objective"}:
        oid = str(effect.get("objective") or effect.get("id"))
        state.objectives[oid] = str(effect.get("status", "active"))
    elif op == "complete_objective":
        state.objectives[str(effect.get("objective") or effect.get("id"))] = "complete"
    elif op == "fail_objective":
        state.objectives[str(effect.get("objective") or effect.get("id"))] = "failed"
    elif op in {"add_evidence", "item", "evidence"}:
        eid = str(effect.get("id") or effect.get("evidence") or "")
        if eid and eid not in state.inventory:
            state.inventory.append(eid)
    elif op == "cover":
        action = str(effect.get("action", ""))
        if action == "adjust_heat" or "delta" in effect or "amount" in effect or "value" in effect:
            try:
                state.heat += float(effect.get("delta", effect.get("amount", effect.get("value", 1))))
            except (TypeError, ValueError):
                state.heat += 1
        if effect.get("state") or effect.get("value") and action != "adjust_heat":
            if action != "adjust_heat":
                state.cover_state = str(effect.get("state") or effect.get("value") or state.cover_state)
    elif op == "heat":
        try:
            state.heat += float(effect.get("amount", effect.get("value", 1)))
        except (TypeError, ValueError):
            state.heat += 1
    elif op == "location":
        state.flags["current_location"] = effect.get("id") or effect.get("location")
    elif op == "end":
        state.ending = str(effect.get("ending") or effect.get("id") or "ending")
        state.flags["ending_id"] = state.ending


def conditions_pass(obj: dict[str, Any], state: GameState) -> bool:
    conds = obj.get("conditions") or []
    if not isinstance(conds, list):
        return True
    return all(eval_condition(c, state) for c in conds if isinstance(c, dict))


def score_choice(choice: dict[str, Any], strategy: str) -> float:
    weights = STRATEGY_WEIGHTS[strategy]
    score = 0.0
    intent = str(choice.get("intent", "")).lower()
    text = str(choice.get("text", "")).lower()
    tags = [str(t).lower() for t in (choice.get("tags") or [])]
    blob = " ".join([intent, text, *tags])
    for key, w in weights.items():
        if key in blob or key in intent:
            score += w
    if intent and intent in weights:
        score += weights[intent] * 0.5
    return score


def pick_choice(choices: list[dict[str, Any]], strategy: str, state: GameState) -> dict[str, Any] | None:
    available = [c for c in choices if isinstance(c, dict) and conditions_pass(c, state)]
    if not available:
        return None
    # System / ending routers: first matching condition in author order
    if all(str(c.get("intent", "")).lower() in {"system", "ending"} for c in available):
        return available[0]
    ranked = sorted(available, key=lambda c: score_choice(c, strategy), reverse=True)
    return ranked[0]


def simulate_from(
    nodes: dict[str, dict[str, Any]],
    strategy: str,
    start: str,
    state: GameState | None = None,
    max_steps: int = 250,
) -> GameState:
    state = state or GameState()
    current: str | None = start
    steps = 0
    while current and steps < max_steps:
        steps += 1
        if current not in nodes:
            state.ending = state.ending or f"broken_ref:{current}"
            break
        node = nodes[current]
        state.path.append(current)
        if not conditions_pass(node, state):
            state.ending = state.ending or f"gated:{current}"
            break
        for effect in node.get("effects") or []:
            if isinstance(effect, dict):
                apply_effect(effect, state)
        if state.flags.get("ending_id"):
            state.ending = str(state.flags["ending_id"])
            break
        tags = {str(t).lower() for t in (node.get("tags") or [])}
        if "ending" in tags and node.get("effects"):
            # continue to apply then stop if ending_id set
            if state.flags.get("ending_id"):
                state.ending = str(state.flags["ending_id"])
                break
        choices = [c for c in (node.get("choices") or []) if isinstance(c, dict)]
        nxt: str | None = None
        if choices:
            # finale.branch uses chapter ending_priority, not raw choice order
            if current == "finale.branch":
                got = resolve_finale_ending(nodes, state)
                if got:
                    state.ending = got
                break
            # Router nodes with system/ending intents: first match, else linear next
            if any(str(c.get("intent", "")).lower() in {"system", "ending"} for c in choices):
                chosen = None
                for c in choices:
                    if conditions_pass(c, state):
                        chosen = c
                        break
                if chosen is None:
                    nxt = str(node["next"]) if node.get("next") else None
                else:
                    state.choice_intents.append(str(chosen.get("intent") or "system"))
                    for effect in chosen.get("effects") or []:
                        if isinstance(effect, dict):
                            apply_effect(effect, state)
                    nxt = str(chosen["next"]) if chosen.get("next") else None
            else:
                chosen = pick_choice(choices, strategy, state)
                if chosen is None:
                    # all gated — try linear next
                    nxt = str(node["next"]) if node.get("next") else None
                    if nxt is None:
                        break
                else:
                    state.choice_intents.append(str(chosen.get("intent") or "unspecified"))
                    for effect in chosen.get("effects") or []:
                        if isinstance(effect, dict):
                            apply_effect(effect, state)
                    nxt = str(chosen["next"]) if chosen.get("next") else None
        else:
            nxt = str(node["next"]) if node.get("next") else None
        if nxt in {"END", "end", "DEBRIEF", "debrief"}:
            state.ending = state.ending or nxt
            break
        if nxt is None:
            break
        current = nxt
    if state.flags.get("ending_id"):
        state.ending = str(state.flags["ending_id"])
    return state


def pick_next_location(strategy: str, visited: set[str], nodes: dict[str, dict[str, Any]]) -> str | None:
    weights = STRATEGY_WEIGHTS[strategy]
    scored: list[tuple[float, str]] = []
    for start, hints in LOCATION_ORDER:
        if start in visited or start not in nodes:
            continue
        score = 0.0
        for key, w in hints.items():
            score += weights.get(key, 0.0) * w
        scored.append((score, start))
    if not scored:
        return None
    scored.sort(reverse=True)
    return scored[0][1]


def simulate_chapter(nodes: dict[str, dict[str, Any]], strategy: str) -> GameState:
    state = GameState()
    start = "briefing.intro" if "briefing.intro" in nodes else (sorted(nodes)[0] if nodes else "")
    if not start:
        state.ending = "empty"
        return state
    visited_starts = {start}
    state = simulate_from(nodes, strategy, start, state)
    # Room hub walk until ending or locations exhausted
    guard = 0
    while not state.flags.get("ending_id") and guard < 8:
        guard += 1
        nxt = pick_next_location(strategy, visited_starts, nodes)
        if not nxt:
            break
        visited_starts.add(nxt)
        state = simulate_from(nodes, strategy, nxt, state)
        # If we reached finale.router via terrace path, ending should be set
        if state.flags.get("ending_id"):
            break
    # Force finale resolution via priority router if no ending yet
    if not state.flags.get("ending_id") and "finale.branch" in nodes:
        got = resolve_finale_ending(nodes, state)
        if got:
            state.ending = got
    if state.flags.get("ending_id"):
        state.ending = str(state.flags["ending_id"])
    elif not state.ending:
        state.ending = "incomplete"
    return state


def resolve_finale_ending(nodes: dict[str, dict[str, Any]], state: GameState) -> str | None:
    """Apply chapter ending_priority over finale.branch gated choices."""
    branch = nodes.get("finale.branch")
    if not branch:
        return None
    # Map ending id -> choice next target
    choice_by_ending: dict[str, dict[str, Any]] = {}
    for c in branch.get("choices") or []:
        if not isinstance(c, dict):
            continue
        nxt = str(c.get("next") or "")
        if nxt.startswith("ending."):
            # ending.professional_win / ending.default_mixed / ending.cover_burned
            eid = nxt.replace("ending.", "", 1)
            if eid == "default_mixed":
                eid = "mixed"
            choice_by_ending[eid] = c
    for eid in EXPECTED_ENDINGS:
        choice = choice_by_ending.get(eid)
        if choice is None:
            continue
        if conditions_pass(choice, state):
            nxt = str(choice.get("next"))
            # Apply ending node effects
            if nxt in nodes:
                for effect in nodes[nxt].get("effects") or []:
                    if isinstance(effect, dict):
                        apply_effect(effect, state)
                state.path.append(nxt)
            return str(state.flags.get("ending_id") or eid)
    # Fallback linear next
    fallback = str(branch.get("next") or "ending.default_mixed")
    if fallback in nodes:
        for effect in nodes[fallback].get("effects") or []:
            if isinstance(effect, dict):
                apply_effect(effect, state)
        state.path.append(fallback)
    return str(state.flags.get("ending_id") or "mixed")


def probe_endings(nodes: dict[str, dict[str, Any]]) -> dict[str, Any]:
    results = {}
    ok = True
    if "finale.branch" not in nodes:
        return {
            "pass": True,
            "skipped": True,
            "reason": "finale.branch not present (fixture or partial content)",
            "endings": {},
            "expected": EXPECTED_ENDINGS,
        }
    for ending, seeds in ENDING_SEEDS.items():
        state = GameState()
        state.flags.update(seeds)
        state.path.append("finale.branch")
        got = resolve_finale_ending(nodes, state)
        results[ending] = {
            "expected": ending,
            "got": got,
            "pass": got == ending,
            "path": state.path,
            "seeds": seeds,
        }
        if got != ending:
            ok = False
    return {"pass": ok, "endings": results, "expected": EXPECTED_ENDINGS}


def outcome_signature(state: GameState) -> tuple:
    maris = dict(state.rels.get("maris_quell", {}))
    return (
        state.flags.get("ending_id") or state.ending,
        state.cover_state,
        round(state.heat, 2),
        tuple(sorted((k, str(v)) for k, v in state.flags.items() if k in {
            "briefed", "met_maris", "has_cipher_fragment", "cover_compromised",
            "helped_taly", "abandoned_taly", "genuine_with_maris", "skipped_impress",
            "ending_id", "sera_gained_time", "fragment_risk",
        })),
        round(float(maris.get("affection", 0)), 2),
        round(float(maris.get("trust", 0)), 2),
        round(float(maris.get("suspicion", 0)), 2),
    )


def run(repo: Path) -> dict[str, Any]:
    content = repo / "content"
    nodes = load_nodes(content) if content.exists() else {}
    result: dict[str, Any] = {
        "node_count": len(nodes),
        "strategies": {},
        "ending_probes": {},
        "divergent": False,
        "pass": False,
        "errors": [],
    }
    if not nodes:
        result["errors"].append("No dialogue nodes to simulate")
        return result

    result["start"] = "briefing.intro" if "briefing.intro" in nodes else None
    signatures = {}
    for name in STRATEGY_WEIGHTS:
        state = simulate_chapter(nodes, name)
        snap = state.snapshot()
        sig = outcome_signature(state)
        signatures[name] = sig
        result["strategies"][name] = {
            "ending": snap.get("ending_id") or state.ending,
            "path_len": len(state.path),
            "path_head": state.path[:10],
            "path_tail": state.path[-8:],
            "cover_state": state.cover_state,
            "heat": state.heat,
            "flags_key": {k: snap["flags"].get(k) for k in (
                "briefed", "met_maris", "has_cipher_fragment", "cover_compromised",
                "helped_taly", "abandoned_taly", "genuine_with_maris", "skipped_impress",
                "ending_id",
            )},
            "rels_maris": snap["rels"].get("maris_quell", {}),
            "choice_intents": snap["choice_intents"][:20],
        }

    unique = {json.dumps(signatures[s], default=str) for s in signatures}
    result["unique_outcomes"] = len(unique)
    result["divergent"] = len(unique) >= 3
    if len(unique) < 3:
        result["errors"].append(
            f"Only {len(unique)} unique outcome signature(s) across 6 strategies — expect meaningful divergence"
        )

    probes = probe_endings(nodes)
    result["ending_probes"] = probes
    if not probes["pass"]:
        for eid, data in probes["endings"].items():
            if not data["pass"]:
                result["errors"].append(f"ending probe {eid}: got {data['got']}")

    for name, data in result["strategies"].items():
        ending = str(data.get("ending") or "")
        if ending.startswith("softlock:") or ending.startswith("broken_ref:"):
            result["errors"].append(f"{name}: {ending}")

    # Fixtures without finale.branch still pass on divergence alone
    probes_ok = probes.get("pass", False)
    result["pass"] = len(result["errors"]) == 0 and result["divergent"] and probes_ok
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=REPO_ROOT)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    result = run(args.repo.resolve())
    if args.json:
        print(json.dumps(result, indent=2, default=str))
    else:
        print("=== Strategy Simulation ===")
        print(f"Nodes: {result.get('node_count')}  Start: {result.get('start')}")
        print(f"Unique outcomes: {result.get('unique_outcomes')}  Divergent: {result.get('divergent')}")
        for name, data in result.get("strategies", {}).items():
            print(
                f"  [{name}] ending={data.get('ending')} path_len={data.get('path_len')} "
                f"maris={data.get('rels_maris')}"
            )
        print("Ending probes:")
        for eid, data in result.get("ending_probes", {}).get("endings", {}).items():
            print(f"  {eid}: {'PASS' if data.get('pass') else 'FAIL'} (got {data.get('got')})")
        if result.get("errors"):
            print("Errors:")
            for e in result["errors"]:
                print(f"  - {e}")
        print("PASS" if result.get("pass") else "FAIL")
    return 0 if result.get("pass") else 1


if __name__ == "__main__":
    sys.exit(main())
