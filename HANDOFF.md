# HANDOFF — Tea in the Hegemony

**Godot 4.3** · Compatibility renderer (`gl_compatibility`) · typed GDScript · browser-friendly  
**Repo:** https://github.com/jxav22/tea-in-the-hegemony  
**Sprint start:** 2026-11-26T15:38:54Z  
**Main tip:** `a9ed495` (#23 SystemFont web text) on top of #22/#21 publish stack (+ #20 HANDOFF, through #19 content)

Playable chapter: **The Reception** — social-espionage under cover as Cassian Orth.

---

## Play in browser (publish)

**Public URL:** https://jxav22.github.io/tea-in-the-hegemony/

| Item | Status |
|------|--------|
| Web preset | `export_presets.cfg` → `builds/web/index.html` |
| Threads | **Single-threaded** (`variant/thread_support=false`) — works on GitHub Pages without COOP/COEP |
| Renderer | Compatibility (`gl_compatibility`) |
| CI | `.github/workflows/web-pages.yml` — installs Godot 4.3 + export templates, exports Web, deploys Pages, uploads itch ZIP artifact |
| Local export | `./tools/export_web.sh` (needs templates in `~/.local/share/godot/export_templates/4.3.stable/`) |
| itch ZIP | `builds/itch/tea-in-the-hegemony-web.zip` (CI artifact `tea-in-the-hegemony-web-itch`) |

### Enable GitHub Pages (manual if API lacks admin)

1. Repo **Settings → Pages**.
2. **Build and deployment → Source:** GitHub Actions.
3. Ensure Actions can write Pages: **Settings → Actions → General → Workflow permissions** → Read and write (or allow `pages: write` via the workflow `permissions:` block).
4. Push/merge to `main` (or run **Web export + GitHub Pages** → *Run workflow*).
5. Wait for the `deploy-pages` job; then open https://jxav22.github.io/tea-in-the-hegemony/

Do **not** change repo visibility. Do not commit secrets. `builds/` stays gitignored — CI produces artifacts.

### Known publish defects

- First visit downloads ~37MB wasm; cold load can take several seconds.
- Headless Tweener warnings in smoke tests are non-blocking.
- Pages 404 / `deploy-pages` fails with 404 until source is set to Actions (runs after #21/#22/#23: export-web PASS, deploy-pages “Ensure GitHub Pages has been enabled”).
- Web text: use `SystemFont` primary when `OS.has_feature("web")` (#23). Bundled FontFile/`load_dynamic_font` still tofu on HTML5; local verify after #23 shows readable TitleScreen + briefing.

---

## How to run

```bash
# Play (editor / export)
godot --path .                    # or ./.bin/godot --path .
# UI chrome only (no full chapter loop)
godot --path . res://scenes/ui/ui_showcase.tscn
# Browser build (after export)
python3 -m http.server 8080 --directory builds/web
```

- **Main scene:** `res://scenes/main/boot.tscn`  
- **Renderer:** Project uses Compatibility only — do not switch to Forward+/Mobile.  
- **Export:** `export_presets.cfg` (Web single-threaded + Linux).  
- First editor open regenerates `.godot/` class cache; if you see missing `class_name` errors, run once with `--editor --quit-after 2`.

---

## How to play The Reception

1. Launch → **TitleScreen** → **New Game**.
2. **Briefing** with Wren Halden (clinical “romance protocol”).
3. After dialogue ends, use the **nav bar**:
   - Move: foyer · salon · terrace · study · cloakroom  
   - **Talk** — room graph (`reception_<location>`)  
   - **Debrief** — dual-rubric wrap when ready  
   - Dossier / Notebook / Menu (Esc)
4. Mission pressure: contact **Maris**, identify **Voss**, obtain the **cipher/shipping fragment**, keep cover heat down; **Sera** / **Taly** sacrifice forks matter.
5. **Save/Load** via Esc (UI slots 0–4 → `SaveService` slots 1–5).

**Hotkeys:** `Space` advance · `1–9` choices · `H` history · `N` notebook.

### Endings (finale routers)

`cover_burned` · `sera_wins` · `balanced` · `professional_win` · `human_cost` · `connection` · `mixed`

Bracket choices (`[If …]`) auto-resolve via conditions + chapter `ending_priority`.

### Design notes

- Narrative: `docs/narrative-design.md`  
- Creative direction (store): sprint contracts / creative docs under project Context  
- Faculties: Analysis, Tradecraft, Composure, Empathy, Improvisation, Idealism, Insecurity  

---

## Verification (keep tip green)

```bash
./tools/run_tests.sh
./.bin/godot --headless --path . res://tests/core/test_runner.tscn
./.bin/godot --headless --path . res://scenes/main/boot.tscn
# Expect: briefing ok → foyer ok → debrief ok + save/load

QA_SKIP_GODOT=1 python3 -m unittest tests.validation.test_validators -v
python3 tools/validate_narrative.py --json
python3 tools/simulate_strategies.py --json
python3 scripts/espionage/simulate_reception_paths.py
python3 tools/save_roundtrip.py --json   # if present
bash tools/run_qa_suite.sh
```

### Evidence stamp (tip `add00b3` / post-#19)

| Check | Result | When (UTC) |
|-------|--------|------------|
| Core test_runner (4 suites) | **PASS** | 2026-11-26T16:13Z |
| Boot smoke briefing→foyer→debrief | **PASS** | 2026-11-26T16:13Z |
| validate_narrative | **PASS** | 2026-11-26T16:13Z |
| simulate_reception_paths | Distinct outcomes incl. pro-without-romance + human-without-full-intel | 2026-11-26T16:13Z |

Pacific/Auckland: Fri 27 Nov 2026, **05:13 NZDT**.

---

## Architecture (short)

```
autoload: FlagStore → SaveService → GameState → FacultyBus → SceneRouter → DialogueRunner
scripts/dialogue   DialogueLoader, EffectExecutor
scripts/core       ContentIndex, CharacterRegistry
scripts/social     relationships / memories (Systems)
scripts/espionage  SystemsBridge, CoverAPI, missions/evidence
scenes/main/boot   TitleScreen + GameHUD host
scenes/ui          GameHUD, faculty stack, notebook, dossiers, transitions
content/dialogue/reception/   chapter packs (preferred)
content/characters|chapters|missions|evidence|schemas
```

**Signals for UI:** `DialogueRunner.*` · `FacultyBus.*` · `SceneRouter.location_changed` · `SaveService.save/load_completed`

**Save:** `user://saves/slot_N.json` — `save_version`, `chapter_id`, `current_location`, `flags`, `rels`, `memories`, `inventory`, `cover_state`, `objectives`, `beat_index`, `timestamp` (+ optional `evidence`).

---

## How to add dialogue

1. Author a graph JSON under `content/dialogue/reception/` (preferred) or `content/dialogue/`.
2. Shape:

```json
{
  "id": "reception_salon",
  "start": "salon.enter",
  "nodes": [
    {
      "id": "salon.enter",
      "speaker": "maris_quell",
      "text": "…",
      "tags": [],
      "conditions": [],
      "effects": [{"op": "set_flag", "flag": "met_maris", "value": true}],
      "choices": [
        {
          "id": "c1",
          "text": "…",
          "intent": "awkward_charm",
          "next": "salon.next",
          "effects": [{"op": "rel", "char": "maris_quell", "trust": 1}]
        }
      ],
      "next": null,
      "faculty_interjections": [
        {"faculty": "Insecurity", "text": "…", "weight": 1}
      ]
    }
  ]
}
```

3. Register in `content/dialogue/reception/index.json` and `content/chapters/the_reception.json` `dialogue_files`.
4. Hub **Talk** loads `reception_<location>` — keep location ids aligned with `SceneRouter` (`foyer`, `salon`, `terrace`, `study`, `cloakroom`).
5. Validate: `python3 tools/validate_narrative.py --json`.

**Load order:** `reception/<id>.json` → flat `content/dialogue/<id>.json` → recursive basename search.

**Effects:** `set_flag`, `add_flag`, `toggle_flag`, `rel`, `memory`, `heat`, `objective`, `item`, `beat`, `location` (soft), plus Systems `cover` / `evidence` / `knowledge`.  
Aliases: `add_memory`→`memory`, `set_location`→`location`.

**Router nodes:** if every choice text starts with `[`, engine auto-picks (conditions + `ending_priority`).

---

## How to add characters

1. Add `content/characters/<id>.json`:

```json
{
  "id": "maris_quell",
  "display_name": "Maris Quell",
  "role": "contact",
  "silhouette_notes": "…",
  "default_rel": {
    "trust": 0, "familiarity": 0, "suspicion": 0, "respect": 0,
    "affection": 0, "comfort": 0, "perceived_authenticity": 0
  },
  "motivations": ["…"],
  "portrait_key": "maris_quell"
}
```

2. Portraits/silhouettes: `assets/portraits/{id}_{expression}.png`, `assets/silhouettes/{id}_sil.png` — see `assets/ASSETS.md`. Regenerate placeholders: `python3 tools/generate_placeholders.py`.
3. Reference `id` in dialogue `speaker` / `rel.char` / Systems content.
4. `CharacterRegistry` + `RelationshipQuery` / `GameState.systems.present_character` feed dossiers.

---

## How to extend systems / UI

| Goal | Where |
|------|--------|
| Relationships / memories | `scripts/social/` — mutate via `GameState` / `GameState.systems`, don’t fork save keys |
| Cover / evidence / missions | `scripts/espionage/`, `content/missions/`, `content/evidence/` |
| UI chrome | `scenes/ui/`, `themes/`, `assets/` — prefer `CoverAPI.present()`, `RelationshipQuery.present()`, `systems.present_*` |
| Thin location shells | `scenes/locations/` |
| QA | `tests/validation/`, `tools/validate_*`, `tools/run_qa_suite.sh` |

---

## Playable graph map

| Graph id | Start | Role |
|----------|-------|------|
| `briefing` | `briefing.intro` | Wren safehouse |
| `reception_foyer` | `foyer.arrival` | Clerk Moth / Pim |
| `reception_salon` | `salon.enter` | Maris / Taly / impress |
| `reception_terrace` | `terrace.enter` | Voss / Sera / sacrifice / race / finale |
| `reception_study` | `study.enter` | Fragment extract / cover slip |
| `reception_cloakroom` | `cloak.enter` | Moth / Maris corridor |
| `debrief` | `debrief.intro` | Professional + interpersonal rubrics |

---

## Roadmap (post-sprint)

1. **Content depth** — more location beats, optional side conversations, clearer sacrifice foreshadowing.  
2. **Systems UX** — surface heat/cover bands and mission trade-offs more explicitly in GameHUD during play (not only notebook/debrief).  
3. **Browser export** — Compatibility Web build CI + smoke on itch/static host.  
4. **Art pipeline** — replace procedural placeholders with CSP assets per `assets/ASSETS.md`.  
5. **QA hardening** — expand ending probes + save migration tests on every PR; keep `cover_manager` / typed-assign audits in CI.  
6. **Chapter 2 scaffold** — new `content/chapters/` + dialogue folder; keep Reception as regression suite.  
7. **Accessibility** — text speed / reduce-motion already seeded; audit keyboard-only + contrast.

---

## Ownership (paths)

| Owner | Paths |
|-------|--------|
| Core | `project.godot`, `autoload/`, `scripts/core/`, `scripts/dialogue/`, `scenes/main/`, `tests/core/`, `export_presets.cfg`, this `HANDOFF.md` |
| Narrative | `content/characters/`, `content/dialogue/`, `content/chapters/`, `docs/narrative-design.md` |
| Systems | `scripts/social/`, `scripts/espionage/`, `content/missions/`, `content/evidence/` |
| Presentation | `scenes/ui/`, `assets/`, `themes/`, `shaders/`, `scripts/ui/` |
| QA | `tests/validation/`, `tools/validate_*`, `tools/run_qa_suite.sh`, `scripts/ci/`, store `internal/qa/` |

Prefer additive commits; never force-push `main`.

### Merged sprint stack (high level)

Core #3/#12 · Presentation #4/#6/#9/#15 · Narrative #2/#7/#10/#14/#16 · Systems #5/#8/#13/#17/#19 · QA #1/#11/#18

---

## Agent appendices

Earlier agent-specific sections (effect cookbooks, faculty polish notes, QA store paths) remain valid; prefer this document’s **Run / Play / Add content / Roadmap / Evidence** as the canonical entry. Detailed Systems effect tables and Presentation hotkeys live in agent commits / `docs/narrative-design.md` / `assets/ASSETS.md`.
