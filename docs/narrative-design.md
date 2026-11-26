# Narrative Design — The Reception

## Scope

One dense chapter: briefing → foyer → salon (Maris) → impress/politics → study/cover → sacrifice → race → ending → debrief.

Boot graphs (preferred): `content/dialogue/reception/<id>.json` — `briefing`, `reception_{foyer,salon,terrace,study,cloakroom}`, `debrief`.

## Voice

| Character | Note |
|-----------|------|
| Cassian | Overanalytical, fallible; cover Orth |
| Maris | Observatory policy; opacity fight vs Voss; **not** an affection meter |
| Wren | Clinical handler; intel over dignity; dual-column debrief |
| Taly | Protective gate; clocks operators |
| Sera | Rival; charming, finished |
| Pim | Loud loyalty; useful disaster |
| Moth | Procedural zealot |
| Voss | Soft power; porcelain |

Faculties disagree in panels; ignorable. Tone: melancholy cool + specific awkward comedy (no listicle gags).

## Maris (independent actor)

Her night is a **dock-opacity fight**: keep Voss from laundering a schedule into policy before Observatory publishes. Underestimation until after the toast is strategy. Ninety seconds with Orth is a test (careful / useful / operator) — not a date audition. Endings treat her as risk assessment, colleague, or publisher — never a romance unlock.

## Beat spine (live files)

| Beat | Graph | Purpose |
|------|-------|---------|
| Briefing | `briefing` | Objectives + clinical manners (no flowchart smell) |
| Foyer | `reception_foyer` | Moth; optional Pim |
| Salon | `reception_salon` | Intro / genuine / impress backfire or restraint |
| Terrace | `reception_terrace` | Overhear, sacrifice, race, endings |
| Study | `reception_study` | Extract; Sera; Moth |
| Cloakroom | `reception_cloakroom` | Moth serial / Maris corridor |
| Debrief | `debrief` | Seven ending-specific dual columns |

## Endings

| ID | Trigger (approx.) | Operational feel | Interpersonal feel |
|----|-------------------|------------------|--------------------|
| `cover_burned` | `cover_compromised` / Moth ink | Badge retired; annex watched | Maris closes risk assessment |
| `sera_wins` | Delay + lost physical fragment | Cipher hers; window late | Decent minute, lost race |
| `balanced` | `got_fragment` + `helped_taly` | Window spoilable | Split problem without dumping person |
| `professional_win` | Fragment + abandoned Taly | Green board | Filed as optimized noise |
| `human_cost` | Helped Taly, no fragment | Empty pocket | Evidence kept, not softness |
| `connection` | Genuine + skipped impress | Uneven ops | Calendar scraps on her terms |
| `mixed` | Fallback | Half-wins | Incomplete assessment |

Priority: burned → sera_wins → balanced → professional_win → human_cost → connection → mixed.  
Debrief stamps `debrief_prof_grade` / `debrief_inter_grade` per path.

## Engine

- Loader: `reception/<id>.json` then flat `dialogue/<id>.json`
- Effects: `set_flag`, `rel`, `memory`, `heat`, `objective`, `item`, `location`, `beat`
- HUD twins: `got_fragment`, `met_maris`
- Chapter: `the_reception.json` (alias `reception.json`)
- Entry: `DialogueRunner.start("briefing")`

## Playtest

1. **Cold pro** — work opener → impress intel → hard extract → abandon Taly → `professional_win` debrief  
2. **Split** — genuine work → skip impress → soft extract → split sacrifice → `balanced`  
3. **Human** — genuine honesty → help Taly after hard extract → `sera_wins` or `human_cost`  
4. **Connection** — genuine + skip impress → `connection` debrief (fallout-meeting ninety seconds)  
5. **Burned** — Moth aggression / ink → `cover_burned`  

Validate: `python3 tools/validate_narrative.py --repo .` (when present); every `next` in-graph; Core effect ops only.

## Pass history

- Polish (#7): distinct debrief rubrics; Maris agency; joke cuts  
- Critical (#10): kill listicle/TEU comedy; cosmetic choices; opacity-fight Maris  
- Final (`cursor/reception-final-prose-c9ed`): debrief operational specificity; residual quip cleanup; docs sync
- Orphan cleanup (`cursor/reception-orphan-lines-c9ed`): removed leftover lower-third / romance-unlock meta after protocol cut
