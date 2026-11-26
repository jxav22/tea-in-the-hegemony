# Narrative Design — The Reception

## Scope

One dense chapter: briefing → foyer → salon (Maris) → impress/politics → study/cover → moral fork → ending → debrief. Cast and faculties per sprint contract.

## Voice rules

- **Cassian**: overanalytical, fallible, human — not a joke-only goof.
- **Maris**: dry, ambitious, observational. Not an affection meter; dimensions (`trust`, `respect`, `comfort`, `perceived_authenticity`, etc.) move independently.
- **Wren**: clinical romantic advice as comedy; intel > Cassian's dignity.
- **Taly**: clocks awkwardness; protective of Maris.
- **Sera**: charming rival; competes for the same fragment.
- **Pim**: useful disaster; loud loyalty.
- **Moth**: procedural zealot; badge math as horror-comedy.
- **Voss**: soft voice, hard power; porcelain metaphor.

Faculties disagree in panels; player may ignore them. Tone: melancholy cool + awkward comedy.

## Beat spine

| Beat | Pack | Purpose |
|------|------|---------|
| Briefing | `briefing.json` | Absurd clinical romance protocol + objectives |
| Foyer | `foyer.json` | Moth badge check; optional Pim escort |
| Awkward intro | `salon_intro.json` | Meet Maris/Taly; protocol vs human vs agenda |
| Genuine talk | `salon_genuine.json` | Ninety seconds unsupervised; Maris as person |
| Impress | `impress_backfire.json` | Show-off paths backfire (Sera/Voss); restraint pays |
| Political | `political.json` | Overhear or Pim-distract → Friday dock window + cipher hint |
| Study / cover | `study_cover.json` | Extract fragment; Sera inconsistency; Moth confrontation |
| Sacrifice | `sacrifice.json` | Help Taly / abandon / split with Maris |
| Race | `fragment_race.json` | Delay can cost physical fragment; soft extract survives |
| Finale | `finale.json` | Ending by flags |
| Debrief | `debrief.json` | Professional vs interpersonal rubrics |

## Ending variants

| ID | Rough trigger | Feel |
|----|---------------|------|
| `cover_burned` | `cover_compromised` | Hot extract; Moth ink |
| `sera_wins` | Delay + physical fragment lost | Rival postcard energy |
| `balanced` | Fragment held + helped Taly | Both ledgers breathe |
| `professional_win` | Fragment + abandoned Taly + cover ok | Cold success |
| `human_cost` | Helped Taly, no fragment | Maris keeps the data |
| `connection` | Genuine + skipped impress | Hypothesis, not promise |
| `mixed` | Fallback | Median spy weather |

Priority (first match): burned → sera_wins → balanced → professional_win → human_cost → connection → mixed.

## Content schema (assumptions)

Matches sprint dialogue/character contracts. Core had not shipped loader APIs when this landed; narrative assumes:

- Merge all `dialogue_files` nodes by `id`.
- Resolve `choices[].next` / `node.next`; evaluate `conditions` on choices (hide failing).
- Effects: `set_flag`, `set_location`, `rel`, `add_memory`.
- `faculty_interjections` are optional panels; not blocking.
- System choices (race/finale routers) may be auto-selected by engine.

If Core renames keys, map 1:1; do not rewrite prose for renames without a migration note in `HANDOFF.md`.

## Playtest paths (manual)

1. **Cold pro**: protocol smile → funding opener recover → impress intel → listen Voss → hard extract → Moth memo bluff → abandon Taly → `professional_win`.
2. **Human**: fluster intro → genuine honesty → skip impress → Pim distract → soft extract → Sera bargain → help Taly → `balanced` or `sera_wins` if hard extract.
3. **Connection**: human intro → genuine → skip impress → … any mid path … land `connection` if flags match (or `mixed`).
4. **Burned**: joke at Moth early → hard extract → aggression at Moth → `cover_burned`.
5. **Debrief**: always contrast `debrief_prof_grade` vs `debrief_inter_grade`.

Validate JSON with QA tools when available; until then: every `next` id exists across packs; every `speaker` has a character file (or `narrator`).

## Engine wiring (post-Core merge)

- Preferred paths: `content/dialogue/reception/<graph_id>.json`
- Start: New Game → `briefing` → navigate hub rooms → Talk (`reception_<loc>`) → Debrief
- Effects allowlist: `set_flag`, `rel`, `memory`, `heat`, `objective`, `item`, `location`, `beat`
- Chapter: `content/chapters/the_reception.json` (alias `reception.json`)
