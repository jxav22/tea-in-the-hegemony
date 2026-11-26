# HANDOFF — Tea in the Hegemony

**Godot:** 4.3.stable | renderer: `gl_compatibility` | typed GDScript  
**Repo:** https://github.com/jxav22/tea-in-the-hegemony  
**Sprint start:** 2026-11-26T15:38:54Z  
**Main stack:** Core #3 · Presentation #4/#6/#9 · Narrative #2/#7/#10 · Systems #5/#8 · QA #1/#11

## How to run

```bash
godot --path .                                 # or ./.bin/godot --path .
godot --path . res://scenes/ui/ui_showcase.tscn  # UI-only demo
```

Main scene: `res://scenes/main/boot.tscn` (TitleScreen → GameHUD).

### How to play

1. **New Game** → Wren briefing.
2. Nav bar: rooms (foyer / salon / terrace / study / cloakroom) + **Talk** / **Debrief** / dossier / notebook.
3. Goals: contact Maris, identify Voss, extract fragment, keep cover; endings via terrace finale routers.
4. Esc menu save/load (UI slots 0–4 → SaveService 1–5). Hotkeys: `H` history, `N` notebook, `Space` advance, `1–9` choices.

Endings: `cover_burned`, `sera_wins`, `balanced`, `professional_win`, `human_cost`, `connection`, `mixed`.

### Verify

```bash
./tools/run_tests.sh
./.bin/godot --headless --path . res://tests/core/test_runner.tscn
./.bin/godot --headless --path . res://scenes/main/boot.tscn   # briefing → foyer → debrief
QA_SKIP_GODOT=1 python3 -m unittest tests.validation.test_validators -v
python3 tools/validate_narrative.py --json
python3 tools/simulate_strategies.py --json
python3 scripts/espionage/simulate_reception_paths.py
```

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
Chapter: `the_reception.json` (alias `reception`). Hub Talk uses `reception_<location>`.

**Router nodes:** If every authored choice text starts with `[`, engine auto-picks first visible match (prefers chapter `ending_priority`); falls back to `ending.default_mixed` when present.

**Effects:** `set_flag`, `add_flag`, `toggle_flag`, `rel`, `memory`, `heat`, `objective`, `item`, `beat`, `location` (soft).  
**Systems:** `cover`, `evidence`, `knowledge` via `GameState.systems`. Aliases: `add_memory`→`memory`, `set_location`→`location`.

**Conditions:** `{flag, op, value}` plus `{all:[…]}` / `{any:[…]}`.

**APIs:** `CharacterRegistry`, `RelationshipQuery`, `CoverAPI`. GameHUD supersedes `dialogue_overlay.tscn`.

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

## Playable graph map

| id | start | role |
|----|-------|------|
| `briefing` | `briefing.intro` | Wren brief |
| `reception_foyer` | `foyer.arrival` | Moth / Pim |
| `reception_salon` | `salon.enter` | Maris / Taly |
| `reception_terrace` | `terrace.enter` | Voss / Sera / race / finale |
| `reception_study` | `study.enter` | Fragment / cover |
| `reception_cloakroom` | `cloak.enter` | Moth / Maris corridor |
| `debrief` | `debrief.intro` | Dual-rubric wrap |

## Evidence / verification

```
$ ./.bin/godot --headless --path . res://tests/core/test_runner.tscn
$ ./.bin/godot --headless --path . res://scenes/main/boot.tscn
# Expect: briefing ok → foyer ok → debrief ok + save/load
```

Godot: 4.3.stable (`.bin/godot`, gitignored).  
Stabilize: router auto-pick + extended boot smoke + typed filter fix in `intel_notebook.gd`.
Verified UTC: 2026-11-26T16:05Z (Pacific/Auckland: Fri 27 Nov 2026, 05:05 NZDT).


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

Briefing (objectives + clinical manners) → foyer/Moth → salon (Maris opacity fight / genuine test / impress) → terrace politics → study extract / cover → sacrifice → fragment race → endings → dual-column debrief (7 paths).

### Ending IDs

`cover_burned`, `sera_wins`, `balanced`, `professional_win`, `human_cost`, `connection`, `mixed`

### Engine alignment

- Effects use Core ops: `set_flag`, `rel`, `memory`, `heat`, `objective`, `item`, `location`, `beat`.
- Flags include Core HUD twins: `got_fragment`, `met_maris`.
- Graph shape: `{ "id", "start", "nodes": [...] }` where a file is a boot-startable graph; nested beat packs keep `nodes` arrays and are composed via chapter index / location graphs.
- Play: New Game → briefing → navigate rooms → Talk → Debrief.

### Playtest paths

See `docs/narrative-design.md`. Entry: `DialogueRunner.start("briefing")` → `briefing.intro`.

### Follow-up polish (`cursor/reception-prose-polish-c9ed`)

- Rewrote weakest clinical jokes (briefing / salon).
- Deepened Maris as Observatory actor with her own dock fight (not affection meter).
- Debrief: seven distinct ending rubrics (prof + inter columns).
- Cut generic finale/study filler lines.


### Critical pass (`cursor/reception-critical-pass-c9ed`)

- Cut unfunny protocol/list comedy; Maris scenes tied to dock opacity fight.
- Cosmetic quip-choices removed or given stakes; sacrifice/endings tightened.

### Final prose (`cursor/reception-final-prose-c9ed`)

- Debrief: seven endings rewritten with concrete ops + interpersonal stakes (no rubric-label / lower-third / flowers leftover mush).
- Residual salon/Sera/Pim/cloak/ending lines tightened.
- `docs/narrative-design.md` rewritten to match live boot graphs, Maris rules, playtest paths.

### Orphan cleanup (`cursor/reception-orphan-lines-c9ed`)

- Removed leftover lower-third choice/faculty and "romance unlock" meta after protocol cut.

## Agent C — Systems

**Landed on main:** #5 systems, #8 balance, #13 cover/path-flag harden  
**Paths:** `scripts/social/`, `scripts/espionage/`, `content/missions/`, `content/evidence/`

### What landed

Data-driven multi-dimension relationships, per-character memories, cover identity + inconsistency heat, evidence fragments (claims / contradictions / verification), intel objectives, mission reporting with professional vs human trade-offs. **No runtime LLM.** Presentation APIs return qualitative bands — raw numbers only with `reveal_raw=true`.

**Storage rule:** SystemsBridge mirrors into `GameState` fields (`relationships`, `memories`, `cover_state`, `objectives`, `inventory` for obtained fragments). Does not fork save keys.

### Wiring

- `GameState.systems` — `SystemsBootstrap.create_with_reception_content()` on ready / new game
- `EffectExecutor` routes `rel`, `memory`, `heat`, `objective`, `cover`, `evidence`, `knowledge` through `GameState.apply_systems_effect`
- Save/load: `GameState.to_save_dict` / `load_from_save_dict` sync systems bag (`evidence` optional key); reload also re-syncs cover FlagStore keys

### Effect ops (Systems)

| op | shape |
|----|--------|
| `rel` | `{"op":"rel","char":"maris_quell","trust":1,"suspicion":-1}` (+ optional `knowledge`) |
| `memory` | `{"op":"memory","id":"...","summary":"...","tags":["maris"]}` — `char` optional (inferred from tags/id/summary); also Core flat `GameState.memories` |
| `item` | Inventory pickup; mapped ids like `shipping_discrepancy` → `frag.shipping_delta` evidence obtain |
| `cover` | `{"op":"cover","action":"assert\|slip\|adjust_heat\|repair\|blow\|escalate",...}` |
| `heat` | Core shorthand → `cover.adjust_heat` (auto-syncs `heat_high` / `cover_blown` flags) |
| `evidence` | `{"op":"evidence","action":"obtain\|verify\|dispute","id":"frag.shipping_delta"}` |
| `objective` | Core `{id,status,label}` **or** Systems `{action,id}` (`activate\|complete\|fail\|reveal\|evaluate\|start_mission`) |
| `knowledge` | `{"op":"knowledge","char":"maris_quell","flag":"identified_voss","value":true}` |

### Presentation (Agent D)

`GameState.systems.present_character(id)` / `present_cover()` / `present_evidence()` / `present_mission()` / `present_debrief()`  
Helpers: `RelationshipQuery.present(id)`, `CoverAPI.present()`, `CoverAPI.evidence_notebook()`, `CoverAPI.debrief()` — prefer these over raw heat/rel ints in chrome.

### Content

- `content/missions/reception.json` — contact Maris, identify Voss, obtain fragment, maintain cover; trade-off paths in `meta.trade_off_design.example_paths`
- `content/evidence/reception_evidence.json`
- `content/missions/reception_effect_cookbook.json`
- `content/missions/systems_data_schema.json`

### Offline checks (keep green)

```bash
python3 scripts/espionage/simulate_reception_paths.py
python3 scripts/espionage/test_cover_chains.py
python3 scripts/espionage/test_memory_inference.py
python3 scripts/espionage/test_path_flags.py
python3 scripts/espionage/validate_systems_content.py
```

### Objective id mapping

Mission file uses `obj.*` ids; GameState seeds Core ids (`contact_maris`, …). Sync mirrors both: completing `obj.contact_maris` also sets `contact_maris` status on GameState.

### Trade-off balance (follow-up)

- **Professional without romance:** `path.pro_extract` / `path.pro_cold` → `clean_professional` (lukewarm affection OK; genuine memories not required)
- **Human without full intel:** `path.human_first` → `human_first` (genuine connection; fragment can fail)
- Narrative memories without `char` infer speaker via tags/id/summary (`mem_maris_*`, tags `maris`/`moth`/…); topic tags `intel`/`cipher` → `cassian_vale` mission log
- Cover assert/slip hardened (empty key/value, blown no-ops, inconsistency dedupe, repair cools only when not ignoring blown)

### Path flags (Narrative debrief router)

**Consumer:** `content/dialogue/debrief.json` → `debrief.router` (bracket choices auto-picked by Core).  
**Producer:** Narrative `set_flag` mid-Reception **or** Systems `PathFlagSync` / `CoverFlagSync` at debrief entry.

#### Sync API / triggers

| Call | When |
|------|------|
| `GameState.systems.sync_path_flags(force=false)` | soft fill |
| `GameState.systems.sync_path_flags(true)` / `present_debrief()` | derive `ending_id` if empty/`mixed`/cover burned |
| `EffectExecutor` `set_flag debrief_started` | soft sync (live `debrief.json` intro) |
| `EffectExecutor` `set_flag reception_ending` | force sync |
| `EffectExecutor` `set_flag start_debrief` / `debrief_ready` | soft sync |
| `EffectExecutor` `end` without explicit ending | force sync |
| Cover heat/blow/repair | `CoverFlagSync` only (heat bands + `cover_blown`) |

`ending_id` already set by Narrative (terrace/cloakroom) is **kept** on soft sync unless empty/`mixed`, or cover is blown (`cover_burned` wins). Force sync (reception end / present_debrief) may re-derive when empty/`mixed`.

#### Flag catalog

| Flag | Systems source | Narrative twin |
|------|----------------|----------------|
| `ending_id` | mission report + heuristics (`PathFlagSync`) | terrace/cloakroom `set_flag` |
| `got_fragment` | evidence `frag.shipping_delta` **or** inventory `shipping_discrepancy` / `frag.shipping_delta` | terrace/study flags |
| `helped_taly` | memory `mem_helped_taly` | terrace `set_flag` |
| `abandoned_taly` | memory `mem_abandoned_taly` | terrace `set_flag` |
| `genuine_with_maris` | report.genuine_connection / genuine memories/tags | salon/cloakroom flags |
| `skipped_impress` | memory `mem_skipped_impress` | salon flag |
| `sera_has_fragment` | memory `mem_sera_stole` | terrace flag |
| `heat_high` | cover heat ≥ 55 (`CoverFlagSync`) | cloakroom conditions |
| `cover_strained` | heat ≥ 30 ∧ ¬blown | — |
| `cover_compromised` | blown ∨ heat ≥ 80 | cloakroom/terrace conditions |
| `cover_blown` | `cover.blown` | — |
| `cover_held` | heat < 30 ∧ ¬blown | cloakroom |
| `reception_ending` | set true on path sync | cookbook `debrief.close` |

#### `ending_id` derivation (Systems)

Priority: `cover_blown`/`outcome blown` → `cover_burned` → sera stole ∧ ¬fragment → `sera_wins` → report outcomes (`balanced` / `professional_win` / `human_cost`) → twin heuristics (`got_fragment`+`helped_taly` → `balanced`, +`abandoned_taly` → `professional_win`, helped∧¬fragment → `human_cost`, genuine → `connection`) → `mixed`.

Debrief router also accepts twin-flag fallbacks when `ending_id` is unset (same pairs as above); `[Mixed]` is the default catch-all.

### Cover slip → repair → blown chain

```
assert(fact) ──contradict──► inconsistency (+heat) ──≥80──► blow → cover_blown + ending_id=cover_burned
     │                              ▲
     └── slip(same key, new value) ─┘  (slip_contradiction, extra heat)
heat / escalate ──≥80──► blow
repair(delta<0) cools heat; does **not** un-blow unless force_unblow=true
CoverAPI.escalate / CoverAPI.repair helpers available for UI/tests
```

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
- **LocationBanner** during room changes; dialogue continue-cue pulse.

### Feel pass (`cursor/presentation-feel-df75`)

- **Text speed:** Leisurely / Brisk / Rapid / Instant presets; live CPS apply; punctuation micro-pauses; Ctrl dumps current line; Space still skips.
- **Room transitions:** Ink → brass edge wipe, interruptible; location banner scale-in.
- **Faculty timing:** Staggered release queue (0.11s), dwell dismiss when stack full, repack.
- **Notebook clarity:** Verified-first sort, All/Verified/Provisional filters, source + verification labels in detail.

## Agent E — QA

**PR #1:** merged (`f401656`). Follow-up: `cursor/qa-postmerge-fixes-6f2c` (typed GDScript fixes missed merge tip).  
**Reports:** `/cursor/stores/self/internal/qa/` — `final-evidence.md`, `critique.md`, `pass_fail_matrix.md`

### Commands (evidence 2026-11-26T16:03:19Z)

```bash
GODOT=~/.local/bin/godot ./tools/run_tests.sh
QA_SKIP_GODOT=1 python3 -m unittest tests.validation.test_validators -v
python3 tools/validate_narrative.py --json
python3 tools/simulate_strategies.py --json
python3 tools/save_roundtrip.py --json
```

### Latest results

- validate: **PASS** (100 nodes, 0 errors)
- strategy sims: **PASS** (5 unique signatures; organic endings → `mixed`; relationship deltas diverge)
- ending probes: **7/7 PASS**
- Godot headless: **PASS**

### Remaining risks

Organic non-mixed endings rare without terrace sacrifice/race; DialogueRunner should honor `ending_priority` for system choices; triage 72 soft warnings.

