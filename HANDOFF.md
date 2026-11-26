# HANDOFF — Tea in the Hegemony (Core Engine)

**Owner:** Agent A (Core)  
**Godot:** 4.3.stable | renderer: `gl_compatibility` | typed GDScript  
**Repo:** https://github.com/jxav22/tea-in-the-hegemony  
**Sprint start:** 2026-11-26T15:38:54Z

## How to run

```bash
# Editor / play
godot --path .          # or ./.bin/godot --path .

# Headless verification
./tools/run_tests.sh
# equivalent:
./.bin/godot --headless -s res://tests/core/test_dialogue_runner.gd
./.bin/godot --headless --path . res://scenes/main/boot.tscn
```

Main scene: `res://scenes/main/boot.tscn`

**Playable now:** New Game → Wren briefing (choices) → soft-arrive foyer → navigate Reception rooms (foyer / salon / terrace / study / cloakroom) via nav buttons → talk graphs → debrief endings → quick save/load slot 1.

## Architecture

```
autoload/
  flag_store.gd      # conditions: eq/neq/gt/… + all/any
  save_service.gd    # versioned JSON slots user://saves/slot_N.json (SAVE_VERSION=1)
  game_state.gd      # chapter, cover/heat, rels, memories, inventory, objectives
  faculty_bus.gd     # internal monologue panels (signals for UI)
  scene_router.gd    # Reception locations + scene changes
  dialogue_runner.gd # load → present → choices → effects → branch
scripts/dialogue/    # DialogueLoader, EffectExecutor, DialogueTypes
scripts/core/        # ContentIndex (characters/chapters bootstrap)
scenes/main/         # boot.tscn (dialogue UI), reception_hub.tscn
scenes/locations/    # foyer/salon/terrace/study/cloakroom
content/dialogue/    # stub Reception graphs (Agent B replaces/extends)
content/characters/  # character JSON stubs
content/schemas/     # JSON Schema stubs for contracts
```

### Autoload order

`FlagStore` → `SaveService` → `GameState` → `FacultyBus` → `SceneRouter` → `DialogueRunner`

### Dialogue JSON contract

See `content/schemas/dialogue_node.schema.json` and sprint contracts. Graph file shape:

```json
{ "id": "briefing", "start": "briefing.intro", "nodes": [ /* DialogueNode */ ] }
```

**Load order for `DialogueRunner.start(id)`:**  
`content/dialogue/reception/<id>.json` → `content/dialogue/<id>.json` → recursive basename search.  
Chapter manifests: `content/chapters/the_reception.json` preferred, else `reception.json`.

**Effects:** `set_flag`, `add_flag`, `toggle_flag`, `rel`, `memory`, `heat`, `objective`, `item`, `beat`, `location` (soft — updates `GameState.current_location` without tearing down UI).

**Conditions:** `{flag, op, value}` plus `{all:[…]}` / `{any:[…]}`.

**Extra APIs:** `CharacterRegistry`, `RelationshipQuery`, `CoverAPI`, `DialogueOverlay` (`scenes/main/dialogue_overlay.tscn`) for Agent D.

### Save payload

`save_version`, `chapter_id`, `current_location`, `flags`, `rels`, `memories`, `inventory`, `cover_state`, `objectives`, `beat_index`, `timestamp`

## Open interfaces (other agents)

| Agent | Call / extend |
|-------|----------------|
| **B Narrative** | Drop/replace JSON under `content/dialogue/`, `content/characters/`, `content/chapters/`. Keep node schema. Wire new graphs by id (`DialogueRunner.start("id")`). |
| **C Systems** | Own `scripts/social/`, `scripts/espionage/`, `content/missions/`, `content/evidence/`. Use `GameState` rel/heat/item/objective APIs — do not fork stores. |
| **D Presentation** | Own `scenes/ui/`, `assets/`, `themes/`. Listen to `DialogueRunner` + `FacultyBus` signals; may restyle `boot.tscn` but keep runner API. Location scenes already exist as thin shells. |
| **E QA** | Extend `tests/`; `tools/run_tests.sh` entrypoint. Schemas in `content/schemas/`. |

### Key signals

- `DialogueRunner.dialogue_started(graph_id)`
- `DialogueRunner.node_presented(node)`
- `DialogueRunner.choices_available(choices)`
- `DialogueRunner.dialogue_ended(graph_id, reason)`
- `FacultyBus.faculty_spoke(faculty, text, weight, node_id)`
- `SceneRouter.location_changed(location_id, previous)`
- `SaveService.save_completed` / `load_completed`

### SceneRouter locations

`foyer`, `salon`, `terrace`, `study`, `cloakroom` — adjacency helpers + `set_location(id, change_scene_file=false|true)`.

## Stub content shipped (until B/C land)

- `content/dialogue/briefing.json`
- `content/dialogue/reception_{foyer,salon,terrace,study,cloakroom}.json`
- `content/dialogue/debrief.json` (multiple ending flags)
- Character JSON for cast in contracts
- Chapter manifest `content/chapters/reception.json`

## Evidence / verification

```
$ ./.bin/godot --headless --path . res://tests/core/test_runner.tscn
[test] loader graphs=19
[test] flags ok
[test] chapter merge nodes=77
[test] dialogue flow ok steps=4
[test] save/load ok
TEST PASS (5 suites)

$ ./.bin/godot --headless --path . res://scenes/main/boot.tscn
[smoke] headless start
[smoke] OK — reception chapter steps=12 + save/load
```

Godot binary: 4.3.stable.official (`.bin/godot`, gitignored).  
Verified UTC: 2026-11-26T15:53Z (Pacific/Auckland: Fri 27 Nov 2026, 04:53 NZDT).

## Notes for concurrent agents

1. Rebase/pull `main` (or this branch) before pushing.
2. Prefer additive commits; never force-push `main`.
3. Append your section under `## Agent B/C/D/E` below — do not rewrite Core sections without coordinating.

## Agent A — Content integration (follow-up)

- Merged Agent B packs via `ChapterGraph.load_reception()` / `DialogueRunner.start_reception()`.
- Effect aliases: `add_memory`→`memory`, `set_location`→`location`; location alias `study_annex`→`study`.
- Router nodes (choices whose text starts with `[`) auto-pick using visible conditions + `ending_priority`.
- Pulled `content/dialogue/reception/*`, `content/chapters/the_reception.json`, characters, `docs/narrative-design.md`.
- Flat stub graphs under `content/dialogue/*.json` remain as fallback.
- **C/D branches:** none on remote yet at integration time — APIs ready (`CoverAPI`, `RelationshipQuery`, `DialogueOverlay`).
- **E:** open PR #1 (QA suite) — do not block Core; rebase onto main.

## Agent B — Narrative

Content lives under `content/dialogue/reception/` + `docs/narrative-design.md` (integrated onto Core follow-up branch). Prefer merging narrative PR #2 into main after rebase onto current main.

## Agent C — Systems

_(append)_

## Agent D — Presentation

_(append)_

## Agent E — QA

_(append)_
