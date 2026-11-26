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
**Systems extensions:** `cover`, `evidence`, `knowledge` (Agent C — routed via `GameState.systems` / EffectExecutor).

**Conditions:** `{flag, op, value}` plus `{all:[…]}` / `{any:[…]}`. Systems also accepts rel/memory/cover/evidence/objective condition kinds via `GameState.systems.check_condition`.

**Extra APIs:** `CharacterRegistry`, `RelationshipQuery`, `CoverAPI`, `DialogueOverlay` (`scenes/main/dialogue_overlay.tscn`) for Agent D.

### Save payload

`save_version`, `chapter_id`, `current_location`, `flags`, `rels`, `memories`, `inventory`, `cover_state`, `objectives`, `beat_index`, `timestamp`  
(+ optional `evidence` runtime bag mirrored from SystemsBridge)

## Open interfaces (other agents)

| Agent | Call / extend |
|-------|----------------|
| **B Narrative** | Drop/replace JSON under `content/dialogue/`, `content/characters/`, `content/chapters/`. Keep node schema. Wire new graphs by id (`DialogueRunner.start("id")`). |
| **C Systems** | Own `scripts/social/`, `scripts/espionage/`, `content/missions/`, `content/evidence/`. Use `GameState` rel/heat/item/objective APIs — do not fork stores. |
| **D Presentation** | Own `scenes/ui/`, `assets/`, `themes/`. Listen to `DialogueRunner` + `FacultyBus` signals; may restyle `boot.tscn` but keep runner API. Location scenes already exist as thin shells. Prefer `GameState.systems.present_*` for qualitative UI. |
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
[test] loader graphs=7
[test] flags ok
[test] dialogue flow ok
[test] save/load ok
TEST PASS (4 suites)

$ ./.bin/godot --headless --path . res://scenes/main/boot.tscn
[smoke] headless start
[smoke] OK — briefing + save/load
```

Godot binary: 4.3.stable.official (`.bin/godot`, gitignored).  
Verified UTC: 2026-11-26T15:48Z (Pacific/Auckland: Fri 27 Nov 2026, 04:48 NZDT).

## Notes for concurrent agents

1. Rebase/pull `main` (or this branch) before pushing.
2. Prefer additive commits; never force-push `main`.
3. Append your section under `## Agent B/C/D/E` below — do not rewrite Core sections without coordinating.

## Agent B — Narrative

**Branch:** `cursor/reception-narrative-c9ed` (PR #2)  
**Owns:** `content/characters/`, `content/dialogue/` (esp. `content/dialogue/reception/`), `content/chapters/the_reception.json`, `docs/narrative-design.md`

### Shipped

- Full cast character JSON (richer stubs replacing Core placeholders).
- Nested Reception packs under `content/dialogue/reception/` (preferred load path per Core).
- Location/boot graph ids also provided / aligned: `briefing`, `reception_*`, `debrief`.
- Chapter manifest `content/chapters/the_reception.json` (Core aliases this over `reception.json`).
- Design notes: `docs/narrative-design.md`.

### Beats

Briefing (clinical romance protocol) → foyer/Moth → awkward Maris intro → genuine talk → impress backfire → political overhear → study extract → cover inconsistency → sacrifice fork → fragment race → multi-ending finale → dual-rubric debrief.

### Ending IDs

`cover_burned`, `sera_wins`, `balanced`, `professional_win`, `human_cost`, `connection`, `mixed`

### Engine alignment

- Effects use Core ops: `set_flag`, `rel`, `memory`, `heat`, `objective`, `item`, `location`, `beat`.
- Flags include Core HUD twins: `got_fragment`, `met_maris`.
- Graph shape: `{ "id", "start", "nodes": [...] }` where a file is a boot-startable graph; nested beat packs keep `nodes` arrays and are composed via chapter index / location graphs.
- Play: New Game → briefing → navigate rooms → Talk → Debrief.

### Playtest paths

See `docs/narrative-design.md`. Entry: `DialogueRunner.start("briefing")` → `briefing.intro`.

## Agent C — Systems

**Branch:** `cursor/social-espionage-systems-b2e0`  
**Paths:** `scripts/social/`, `scripts/espionage/`, `content/missions/`, `content/evidence/`

### What landed

Data-driven multi-dimension relationships, per-character memories, cover identity + inconsistency heat, evidence fragments (claims / contradictions / verification), intel objectives, mission reporting with professional vs human trade-offs. **No runtime LLM.** Presentation APIs return qualitative bands — raw numbers only with `reveal_raw=true`.

**Storage rule:** SystemsBridge mirrors into `GameState` fields (`relationships`, `memories`, `cover_state`, `objectives`, `inventory` for obtained fragments). Does not fork save keys.

### Wiring

- `GameState.systems` — `SystemsBootstrap.create_with_reception_content()` on ready / new game
- `EffectExecutor` routes `rel`, `memory`, `heat`, `objective`, `cover`, `evidence`, `knowledge` through `GameState.apply_systems_effect`
- Save/load: `GameState.to_save_dict` / `load_from_save_dict` sync systems bag (`evidence` optional key)

### Effect ops (Systems)

| op | shape |
|----|--------|
| `rel` | `{"op":"rel","char":"maris_quell","trust":1,"suspicion":-1}` (+ optional `knowledge`) |
| `memory` | `{"op":"memory","char":"maris_quell","id":"...","summary":"...","salience":2,"tags":[],"beat":"..."}` |
| `cover` | `{"op":"cover","action":"assert\|slip\|adjust_heat\|repair\|blow",...}` |
| `heat` | Core shorthand → `cover.adjust_heat` |
| `evidence` | `{"op":"evidence","action":"obtain\|verify\|dispute","id":"frag.shipping_delta"}` |
| `objective` | Core `{id,status,label}` **or** Systems `{action,id}` (`activate\|complete\|fail\|reveal\|evaluate\|start_mission`) |
| `knowledge` | `{"op":"knowledge","char":"maris_quell","flag":"identified_voss","value":true}` |

### Presentation (Agent D)

`GameState.systems.present_character(id)` / `present_cover()` / `present_evidence()` / `present_mission()` / `present_debrief()`

### Content

- `content/missions/reception.json` — contact Maris, identify Voss, obtain fragment, maintain cover; trade-off paths in `meta.trade_off_design.example_paths`
- `content/evidence/reception_evidence.json`
- `content/missions/reception_effect_cookbook.json`
- `content/missions/systems_data_schema.json`
- Simulator: `python3 scripts/espionage/simulate_reception_paths.py` (five outcomes OK)

### Objective id mapping

Mission file uses `obj.*` ids; GameState seeds Core ids (`contact_maris`, …). Sync mirrors both: completing `obj.contact_maris` also sets `contact_maris` status on GameState.

## Agent D — Presentation

**Branch:** `cursor/presentation-ui-df75`  
**Owns:** `scenes/ui/`, `assets/`, `themes/`, `shaders/` (compat), `scripts/ui/`, `tools/generate_placeholders.py`

### How to run UI

```bash
godot --path .                    # main = boot.tscn (wired to GameHUD)
# Presentation-only smoke (no Core loop):
godot --path . res://scenes/ui/ui_showcase.tscn
```

Boot flow: TitleScreen → New Game starts `DialogueRunner` briefing → GameHUD presents lines/choices/faculties → nav bar after dialogue ends → notebook/dossier/save-load/settings via Esc menu or hotkeys (`H` history, `N` notebook, `Space` advance, `1–9` choices).

### Wiring (does not rewrite dialogue engine)

- `scripts/ui/core_ui_controller.gd` listens to `DialogueRunner`, `FacultyBus`, `SceneRouter`, `GameState`
- Uses shipped helpers: `CharacterRegistry`, `RelationshipQuery`, `CoverAPI` (heat / blown / evidence / affinity)
- `scenes/main/boot.gd` restyled to host `GameHUD` + title; legacy stub labels hidden; headless smoke preserved
- `scenes/main/dialogue_overlay.tscn` remains as Core stub — **GameHUD supersedes it** for play; overlay kept for thin embeds
- Save/load slots map UI 0–4 → `SaveService` 1–5
- Rebased onto `main` @ `81934cc` (PR #3)

### Asset replacement

See `assets/ASSETS.md` — CSP-replaceable naming:
`portraits/{id}_{expression}.png`, `silhouettes/{id}_sil.png`, `backgrounds/{loc}_bg.png`, `ui/{element}.png`

Regenerate: `python3 tools/generate_placeholders.py` (Pillow).

### Visual tokens

`themes/hegemony_palette.gd` + `hegemony_theme_factory.gd` — ink navy / brass / jade / ivory / vermillion. Fonts: Tinos + Public Sans (+ Source Sans 3). Shaders: `shaders/vignette_compat.gdshader`, `panel_grain_compat.gdshader`.

### Showcase

`scenes/ui/ui_showcase.tscn` demos dialogue, intents, notebook, profile, objectives without Core.

### Polish pass (`cursor/presentation-polish-df75`)

- **Faculty:** `FacultyStack` cascades up to 3 disagreeing comic panels (faculty-colored accents, snap-in + micro-shake).
- **Rooms:** `RoomTransition` ink-pulse crossfade between Reception backgrounds (respects reduce-motion).
- **Intents:** Choice rows show numbered accent + uppercase intent + short gloss (“tone, not outcomes”).
- **Systems UI:** Prefer `CoverAPI.present()`, `RelationshipQuery.present()`, `GameState.systems.present_mission/evidence` — qualitative heat bands / mood lines, no raw dumps.
- **Layering fix:** TitleScreen on CanvasLayer 30 above GameHUD; nav overlay on 22; modals z-ordered.
- **Notebook / dossier / brief:** Stronger empty-states, verified counts, affinity/mood copy.

## Agent E — QA

_(append)_
