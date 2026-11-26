#!/usr/bin/env python3
"""Tea in the Hegemony — narrative content validator.

Checks dialogue graphs, characters, missions/objectives, conditions/effects,
softlock heuristics, contradictory flags, and ending reachability.

Exit codes:
  0 = pass (warnings allowed)
  1 = failures found
  2 = no content / setup error
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]

EXPECTED_CHARS = {
    "cassian_vale",
    "cassian_orth",  # cover alias may appear as speaker in some content
    "maris_quell",
    "wren_halden",
    "edrin_voss",
    "taly_renn",
    "sera_kade",
    "pim_orel",
    "clerk_moth",
}

FACULTIES = {
    "Analysis",
    "Tradecraft",
    "Composure",
    "Empathy",
    "Improvisation",
    "Idealism",
    "Insecurity",
}

REL_DIMS = {
    "trust",
    "familiarity",
    "suspicion",
    "respect",
    "affection",
    "comfort",
    "perceived_authenticity",
}

CONDITION_OPS = {"eq", "neq", "gt", "gte", "lt", "lte", "has", "missing", "true", "false"}
EFFECT_OPS = {
    # Core EffectExecutor ops
    "set_flag",
    "add_flag",
    "toggle_flag",
    "rel",
    "memory",
    "heat",
    "objective",
    "item",
    "beat",
    "location",
    "set_location",
    "knowledge",
    "evidence",
    "cover",
    # Narrative / sprint-contract aliases (executor maps these)
    "unset_flag",
    "add_memory",
    "set_objective",
    "complete_objective",
    "fail_objective",
    "add_evidence",
    "set_cover",
    "add_heat",
    "goto",
    "end",
}


@dataclass
class Finding:
    severity: str  # error | warning | info
    check: str
    message: str
    path: str = ""

    def as_dict(self) -> dict[str, str]:
        return {
            "severity": self.severity,
            "check": self.check,
            "message": self.message,
            "path": self.path,
        }


@dataclass
class Report:
    findings: list[Finding] = field(default_factory=list)
    stats: dict[str, Any] = field(default_factory=dict)

    def add(self, severity: str, check: str, message: str, path: str = "") -> None:
        self.findings.append(Finding(severity, check, message, path))

    @property
    def errors(self) -> list[Finding]:
        return [f for f in self.findings if f.severity == "error"]

    @property
    def warnings(self) -> list[Finding]:
        return [f for f in self.findings if f.severity == "warning"]


def load_json(path: Path) -> Any | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        return {"__load_error__": str(exc)}


def collect_json_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return sorted(p for p in root.rglob("*.json") if p.is_file())


def normalize_dialogue_nodes(data: Any, source: str) -> list[tuple[str, dict[str, Any]]]:
    """Accept list of nodes, {nodes:[]}, or {id: node} maps."""
    nodes: list[tuple[str, dict[str, Any]]] = []
    if isinstance(data, list):
        for i, item in enumerate(data):
            if isinstance(item, dict) and "id" in item:
                nodes.append((f"{source}[{i}]", item))
            elif isinstance(item, dict):
                nodes.append((f"{source}[{i}]", item))
        return nodes
    if isinstance(data, dict):
        if "__load_error__" in data:
            return []
        if "nodes" in data and isinstance(data["nodes"], list):
            return normalize_dialogue_nodes(data["nodes"], source)
        if "id" in data and ("text" in data or "choices" in data or "speaker" in data):
            return [(source, data)]
        # map of id -> node
        for key, val in data.items():
            if key.startswith("_") or key in {"schema", "meta", "chapter", "title"}:
                continue
            if isinstance(val, dict) and ("text" in val or "choices" in val or "speaker" in val or "id" in val):
                node = dict(val)
                node.setdefault("id", key)
                nodes.append((f"{source}:{key}", node))
    return nodes


def index_characters(content_root: Path, report: Report) -> dict[str, dict[str, Any]]:
    chars: dict[str, dict[str, Any]] = {}
    char_dir = content_root / "characters"
    for path in collect_json_files(char_dir):
        data = load_json(path)
        if isinstance(data, dict) and "__load_error__" in data:
            report.add("error", "json_parse", data["__load_error__"], str(path))
            continue
        items: list[dict[str, Any]] = []
        if isinstance(data, list):
            items = [x for x in data if isinstance(x, dict)]
        elif isinstance(data, dict):
            if "id" in data:
                items = [data]
            elif "characters" in data and isinstance(data["characters"], list):
                items = [x for x in data["characters"] if isinstance(x, dict)]
            else:
                for key, val in data.items():
                    if isinstance(val, dict):
                        v = dict(val)
                        v.setdefault("id", key)
                        items.append(v)
        for item in items:
            cid = str(item.get("id", "")).strip()
            if not cid:
                report.add("error", "character_id", "Character missing id", str(path))
                continue
            if cid in chars:
                report.add("error", "character_dup", f"Duplicate character id '{cid}'", str(path))
            chars[cid] = item
            for req in ("display_name", "role"):
                if req not in item:
                    report.add("warning", "character_schema", f"Character '{cid}' missing '{req}'", str(path))
            if "default_rel" in item and isinstance(item["default_rel"], dict):
                for dim in item["default_rel"]:
                    if dim not in REL_DIMS:
                        report.add(
                            "warning",
                            "rel_dim",
                            f"Unknown rel dim '{dim}' on '{cid}'",
                            str(path),
                        )
    report.stats["characters"] = len(chars)
    return chars


def index_missions(content_root: Path, report: Report) -> dict[str, dict[str, Any]]:
    missions: dict[str, dict[str, Any]] = {}
    objectives: dict[str, dict[str, Any]] = {}
    for folder in ("missions", "evidence"):
        for path in collect_json_files(content_root / folder):
            data = load_json(path)
            if isinstance(data, dict) and "__load_error__" in data:
                report.add("error", "json_parse", data["__load_error__"], str(path))
                continue
            items: list[dict[str, Any]] = []
            if isinstance(data, list):
                items = [x for x in data if isinstance(x, dict)]
            elif isinstance(data, dict):
                if "id" in data:
                    items = [data]
                else:
                    for key in ("missions", "objectives", "evidence", "fragments"):
                        if key in data and isinstance(data[key], list):
                            items.extend(x for x in data[key] if isinstance(x, dict))
                    if not items:
                        for key, val in data.items():
                            if isinstance(val, dict):
                                v = dict(val)
                                v.setdefault("id", key)
                                items.append(v)
            for item in items:
                iid = str(item.get("id", "")).strip()
                if not iid:
                    report.add("error", "mission_id", "Mission/evidence missing id", str(path))
                    continue
                missions[iid] = item
                for obj in item.get("objectives", []) if isinstance(item.get("objectives"), list) else []:
                    if isinstance(obj, dict) and obj.get("id"):
                        objectives[str(obj["id"])] = obj
                if "status" in item or item.get("type") == "objective":
                    objectives[iid] = item
    # also scan chapters for objective defs
    for path in collect_json_files(content_root / "chapters"):
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        for obj in data.get("objectives", []) if isinstance(data.get("objectives"), list) else []:
            if isinstance(obj, dict) and obj.get("id"):
                objectives[str(obj["id"])] = obj
    report.stats["missions"] = len(missions)
    report.stats["objectives"] = len(objectives)
    report.stats["_objectives_map"] = objectives
    return missions


def validate_condition(cond: Any, path: str, report: Report, known_flags: set[str]) -> None:
    if not isinstance(cond, dict):
        report.add("error", "condition", f"Condition must be object, got {type(cond).__name__}", path)
        return
    op = cond.get("op")
    if op is not None and op not in CONDITION_OPS:
        report.add("error", "condition_op", f"Invalid condition op '{op}'", path)
    flag = cond.get("flag") or cond.get("key") or cond.get("id")
    if flag:
        known_flags.add(str(flag))
    # faculty / rel conditions
    if "faculty" in cond and cond["faculty"] not in FACULTIES:
        report.add("warning", "faculty", f"Unknown faculty '{cond['faculty']}' in condition", path)
    if "char" in cond or "character" in cond:
        pass  # checked later against char index via effects path


def validate_effect(
    effect: Any,
    path: str,
    report: Report,
    known_flags: set[str],
    chars: set[str],
    objectives: set[str],
    node_ids: set[str],
) -> None:
    if not isinstance(effect, dict):
        report.add("error", "effect", f"Effect must be object, got {type(effect).__name__}", path)
        return
    op = effect.get("op") or effect.get("type")
    if op is None:
        # allow shorthand {flag: x, value: y}
        if "flag" in effect:
            known_flags.add(str(effect["flag"]))
            return
        if any(k in effect for k in REL_DIMS) and ("char" in effect or "character" in effect):
            op = "rel"
        else:
            report.add("error", "effect_op", "Effect missing op/type", path)
            return
    if op not in EFFECT_OPS:
        report.add("error", "effect_op", f"Invalid effect op '{op}'", path)
        return
    if op in {"set_flag", "unset_flag", "add_flag"} and effect.get("flag"):
        known_flags.add(str(effect["flag"]))
    if op == "rel":
        cid = effect.get("char") or effect.get("character")
        if cid and str(cid) not in chars:
            report.add("error", "missing_character", f"Effect rel targets unknown char '{cid}'", path)
        for dim, val in effect.items():
            if dim in {"op", "type", "char", "character"}:
                continue
            if dim not in REL_DIMS:
                report.add("warning", "rel_dim", f"Unknown rel dim '{dim}' in effect", path)
    if op in {"set_objective", "complete_objective", "fail_objective"}:
        oid = effect.get("objective") or effect.get("id") or effect.get("flag")
        if oid and objectives and str(oid) not in objectives:
            report.add("error", "unresolvable_objective", f"Effect references unknown objective '{oid}'", path)
    if op == "goto":
        nxt = effect.get("next") or effect.get("node") or effect.get("id")
        if nxt and node_ids and str(nxt) not in node_ids:
            report.add("error", "broken_ref", f"Effect goto unknown node '{nxt}'", path)
    if op == "end":
        ending = effect.get("ending") or effect.get("id")
        if ending:
            report.stats.setdefault("endings_referenced", set()).add(str(ending))


def build_dialogue_index(
    content_root: Path, report: Report
) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    nodes: dict[str, dict[str, Any]] = {}
    sources: dict[str, str] = {}
    paths: list[Path] = []
    # Prefer nested reception/ packs; flat mirrors are fallbacks (same basenames).
    nested = collect_json_files(content_root / "dialogue" / "reception")
    flat = [p for p in collect_json_files(content_root / "dialogue") if "reception" not in p.parts]
    chapter_files = collect_json_files(content_root / "chapters")
    # Process nested first, then flat only for ids not already seen
    paths = nested + flat + chapter_files
    for path in paths:
        data = load_json(path)
        if isinstance(data, dict) and "__load_error__" in data:
            report.add("error", "json_parse", data["__load_error__"], str(path))
            continue
        rel = str(path.relative_to(content_root))
        is_flat_mirror = "dialogue" in path.parts and "reception" not in path.parts and path.parent.name == "dialogue"
        for src, node in normalize_dialogue_nodes(data, rel):
            nid = str(node.get("id", "")).strip()
            if not nid:
                report.add("error", "node_id", "Dialogue node missing id", src)
                continue
            if nid in nodes:
                if is_flat_mirror:
                    continue  # expected Core/Narrative flat mirror of nested pack
                report.add("error", "node_dup", f"Duplicate node id '{nid}'", src)
                continue
            nodes[nid] = node
            sources[nid] = src
    report.stats["dialogue_nodes"] = len(nodes)
    return nodes, sources


def validate_dialogue(
    nodes: dict[str, dict[str, Any]],
    sources: dict[str, str],
    chars: dict[str, dict[str, Any]],
    objectives: dict[str, dict[str, Any]],
    report: Report,
) -> None:
    char_ids = set(chars.keys())
    # Allow protagonist aliases and generic narrators
    char_ids |= {"narrator", "system", "cassian", "player", "internal"}
    obj_ids = set(objectives.keys())
    node_ids = set(nodes.keys())
    known_flags: set[str] = set()
    graph: dict[str, set[str]] = defaultdict(set)
    entry_candidates: set[str] = set()
    ending_nodes: set[str] = set()

    for nid, node in nodes.items():
        src = sources.get(nid, nid)
        speaker = node.get("speaker")
        if speaker and str(speaker) not in char_ids and str(speaker) not in EXPECTED_CHARS:
            # soft if characters not yet authored
            sev = "error" if chars else "warning"
            report.add(sev, "missing_character", f"Speaker '{speaker}' not in characters", src)

        for cond in node.get("conditions", []) if isinstance(node.get("conditions"), list) else []:
            validate_condition(cond, src, report, known_flags)

        for effect in node.get("effects", []) if isinstance(node.get("effects"), list) else []:
            validate_effect(effect, src, report, known_flags, char_ids, obj_ids, node_ids)

        for fi in node.get("faculty_interjections", []) if isinstance(node.get("faculty_interjections"), list) else []:
            if isinstance(fi, dict):
                fac = fi.get("faculty")
                if fac and fac not in FACULTIES:
                    report.add("warning", "faculty", f"Unknown faculty '{fac}'", src)
                if not fi.get("text"):
                    report.add("warning", "faculty_text", "Faculty interjection missing text", src)

        choices = node.get("choices")
        if choices is None:
            choices = []
        if not isinstance(choices, list):
            report.add("error", "choices", "choices must be a list", src)
            choices = []

        nexts: set[str] = set()
        for i, choice in enumerate(choices):
            if not isinstance(choice, dict):
                report.add("error", "choice", f"Choice {i} not an object", src)
                continue
            if not choice.get("text"):
                report.add("warning", "choice_text", f"Choice {i} missing text", src)
            for cond in choice.get("conditions", []) if isinstance(choice.get("conditions"), list) else []:
                validate_condition(cond, f"{src}#choice{i}", report, known_flags)
            for effect in choice.get("effects", []) if isinstance(choice.get("effects"), list) else []:
                validate_effect(
                    effect, f"{src}#choice{i}", report, known_flags, char_ids, obj_ids, node_ids
                )
            nxt = choice.get("next")
            if nxt:
                nxt_s = str(nxt)
                nexts.add(nxt_s)
                if nxt_s not in node_ids and nxt_s not in {"END", "end", "DEBRIEF", "debrief"}:
                    report.add("error", "broken_ref", f"Choice next '{nxt_s}' not found", src)

        linear_next = node.get("next")
        if linear_next:
            nxt_s = str(linear_next)
            nexts.add(nxt_s)
            if nxt_s not in node_ids and nxt_s not in {"END", "end", "DEBRIEF", "debrief"}:
                report.add("error", "broken_ref", f"Node next '{nxt_s}' not found", src)

        tags = {str(t).lower() for t in (node.get("tags") or [])}
        if "entry" in tags or "start" in tags or nid.endswith(".intro") or nid.endswith(".start"):
            entry_candidates.add(nid)
        if "ending" in tags or "end" in tags or node.get("ending") or any(
            isinstance(e, dict) and (e.get("op") == "end" or e.get("type") == "end")
            for e in (node.get("effects") or [])
            if isinstance(e, dict) or True
        ):
            ending_nodes.add(nid)
        if not nexts and not choices:
            ending_nodes.add(nid)

        for n in nexts:
            if n in node_ids:
                graph[nid].add(n)

    # Reachability
    if not entry_candidates and nodes:
        # heuristic: nodes never referenced as next
        referenced = {n for outs in graph.values() for n in outs}
        entry_candidates = {n for n in nodes if n not in referenced}
        if len(entry_candidates) > 12:
            # too many — pick briefing-ish
            preferred = {n for n in entry_candidates if "brief" in n or "intro" in n or "start" in n}
            if preferred:
                entry_candidates = preferred

    reachable: set[str] = set()
    q: deque[str] = deque(sorted(entry_candidates))
    while q:
        cur = q.popleft()
        if cur in reachable:
            continue
        reachable.add(cur)
        for nxt in graph.get(cur, ()):
            if nxt not in reachable:
                q.append(nxt)

    unreachable = set(nodes) - reachable if entry_candidates else set()
    for nid in sorted(unreachable):
        report.add("warning", "unreachable", f"Node '{nid}' unreachable from entries", sources.get(nid, nid))

    # Softlock heuristic: non-ending node with choices all gated and no linear next,
    # or node with zero outgoing and not tagged ending while mid-graph
    for nid, node in nodes.items():
        if nid not in reachable:
            continue
        outs = graph.get(nid, set())
        choices = node.get("choices") or []
        if outs:
            continue
        tags = {str(t).lower() for t in (node.get("tags") or [])}
        is_end = nid in ending_nodes or "ending" in tags or "end" in tags or node.get("ending")
        if not is_end and choices:
            # all choices missing next?
            missing_next = all(not (isinstance(c, dict) and c.get("next")) for c in choices)
            if missing_next:
                report.add(
                    "error",
                    "softlock",
                    f"Node '{nid}' has choices without next and is not an ending",
                    sources.get(nid, nid),
                )
        elif not is_end and not choices and node.get("next") is None:
            # dead end mid content
            report.add(
                "warning",
                "softlock",
                f"Node '{nid}' is a dead end without ending tag",
                sources.get(nid, nid),
            )

        # contradictory choice gates: mutually exclusive conditions that leave no choice
        if isinstance(choices, list) and choices:
            gated = [c for c in choices if isinstance(c, dict) and c.get("conditions")]
            if gated and len(gated) == len(choices):
                # flag as potential softlock if every choice requires a flag
                report.add(
                    "info",
                    "softlock_heuristic",
                    f"Node '{nid}': all choices are conditioned — verify a path always remains",
                    sources.get(nid, nid),
                )

    # Contradictory flags: set_flag true and false on same node effects without branch
    for nid, node in nodes.items():
        effects = [e for e in (node.get("effects") or []) if isinstance(e, dict)]
        sets: dict[str, set[Any]] = defaultdict(set)
        for e in effects:
            op = e.get("op") or e.get("type")
            if op in {"set_flag", "add_flag"} and "flag" in e:
                sets[str(e["flag"])].add(e.get("value", True))
            if op == "unset_flag" and "flag" in e:
                sets[str(e["flag"])].add(False)
        for flag, values in sets.items():
            if len(values) > 1:
                report.add(
                    "error",
                    "contradictory_flags",
                    f"Node '{nid}' sets flag '{flag}' to contradictory values {sorted(values, key=str)}",
                    sources.get(nid, nid),
                )

    report.stats["entry_nodes"] = sorted(entry_candidates)
    report.stats["reachable_nodes"] = len(reachable)
    report.stats["unreachable_nodes"] = len(unreachable)
    report.stats["ending_nodes"] = sorted(ending_nodes)
    report.stats["known_flags"] = sorted(known_flags)
    report.stats["_graph"] = {k: sorted(v) for k, v in graph.items()}
    report.stats["_reachable"] = sorted(reachable)

    if nodes and not ending_nodes:
        report.add("warning", "endings", "No ending nodes detected")
    if ending_nodes and len(ending_nodes) < 2:
        report.add(
            "warning",
            "endings",
            f"Only {len(ending_nodes)} ending node(s) — expect multiple divergent endings",
        )


def validate_save_schema(content_root: Path, report: Report) -> None:
    schema_paths = list((content_root / "schemas").glob("*save*")) if (content_root / "schemas").exists() else []
    schema_paths += list((REPO_ROOT / "content" / "schemas").glob("*save*"))
    required_keys = {
        "save_version",
        "chapter_id",
        "flags",
        "rels",
        "memories",
        "inventory",
        "cover_state",
        "objectives",
    }
    found = False
    for path in schema_paths:
        found = True
        data = load_json(path)
        if not isinstance(data, dict):
            report.add("warning", "save_schema", f"Could not parse save schema {path.name}", str(path))
            continue
        props = set()
        if "properties" in data and isinstance(data["properties"], dict):
            props = set(data["properties"].keys())
        elif "required" in data and isinstance(data["required"], list):
            props = set(data["required"])
        else:
            props = set(data.keys())
        missing = required_keys - props
        for m in sorted(missing):
            report.add("warning", "save_schema", f"Save schema missing key '{m}'", str(path))
    if not found:
        report.add("info", "save_schema", "No save schema file found yet")


def validate_project(repo: Path, report: Report) -> None:
    godot = repo / "project.godot"
    if not godot.exists():
        report.add("error", "project", "project.godot missing — Core has not landed skeleton")
        return
    text = godot.read_text(encoding="utf-8", errors="replace")
    if "config_version" not in text and "config_version=" not in text.replace(" ", ""):
        report.add("warning", "project", "project.godot may be incomplete")
    if "gl_compatibility" not in text and "Compatibility" not in text:
        report.add(
            "warning",
            "renderer",
            "Compatibility renderer not clearly set (browser-friendly requirement)",
        )


def run_validation(repo: Path) -> Report:
    report = Report()
    content = repo / "content"
    if not content.exists():
        report.add("error", "content_root", "content/ directory missing")
        validate_project(repo, report)
        return report

    chars = index_characters(content, report)
    missions = index_missions(content, report)
    objectives = report.stats.pop("_objectives_map", {})
    nodes, sources = build_dialogue_index(content, report)

    if not nodes:
        report.add("error", "dialogue", "No dialogue nodes found under content/dialogue or content/chapters")
    if not chars:
        report.add("warning", "characters", "No character defs found under content/characters")
        # still expect creative-lock cast eventually
        for cid in sorted(EXPECTED_CHARS - {"cassian_orth"}):
            report.add("info", "expected_cast", f"Expected character '{cid}' not yet present")

    validate_dialogue(nodes, sources, chars, objectives, report)
    validate_save_schema(content, report)
    validate_project(repo, report)

    # Evidence contradiction sanity
    for mid, mission in missions.items():
        frags = mission.get("fragments") or mission.get("claims") or []
        if not isinstance(frags, list):
            continue
        claim_ids = {}
        for frag in frags:
            if not isinstance(frag, dict):
                continue
            fid = frag.get("id")
            if fid:
                claim_ids[str(fid)] = frag
        for frag in frags:
            if not isinstance(frag, dict):
                continue
            for c in frag.get("contradicts", []) if isinstance(frag.get("contradicts"), list) else []:
                if str(c) not in claim_ids and str(c) not in missions:
                    report.add(
                        "warning",
                        "evidence_ref",
                        f"Fragment '{frag.get('id')}' contradicts unknown '{c}'",
                        mid,
                    )

    return report


def print_report(report: Report, as_json: bool = False) -> None:
    if as_json:
        payload = {
            "stats": {
                k: (sorted(v) if isinstance(v, set) else v)
                for k, v in report.stats.items()
                if not str(k).startswith("_")
            },
            "errors": [f.as_dict() for f in report.errors],
            "warnings": [f.as_dict() for f in report.warnings],
            "findings": [f.as_dict() for f in report.findings],
            "pass": len(report.errors) == 0,
        }
        print(json.dumps(payload, indent=2, default=str))
        return
    print("=== Narrative Validation ===")
    for k, v in report.stats.items():
        if str(k).startswith("_"):
            continue
        print(f"  {k}: {v if not isinstance(v, list) else len(v) if k.endswith('nodes') or k == 'known_flags' else v}")
    print(f"\nErrors: {len(report.errors)}  Warnings: {len(report.warnings)}")
    for f in report.findings:
        if f.severity == "info":
            continue
        loc = f" @ {f.path}" if f.path else ""
        print(f"  [{f.severity.upper()}] {f.check}: {f.message}{loc}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=REPO_ROOT)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as failures")
    args = parser.parse_args(argv)

    report = run_validation(args.repo.resolve())
    print_report(report, as_json=args.json)

    if report.errors:
        return 1
    if args.strict and report.warnings:
        return 1
    if not (args.repo / "content").exists():
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
