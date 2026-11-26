# Asset Replacement Guide — Tea in the Hegemony

Procedural/vector placeholders ship with the project. Clip Studio (or any pipeline) can replace them by **exact path + filename**. Keep dimensions unless you also update UI stretch settings.

Godot will create sibling `*.import` files on first open — leave those alone; replace only the source PNG/TTF.

## Naming convention

| Kind | Pattern | Example |
|------|---------|---------|
| Portrait | `assets/portraits/{character_id}_{expression}.png` | `maris_quell_amused.png` |
| Silhouette | `assets/silhouettes/{character_id}_sil.png` | `cassian_vale_sil.png` |
| Background | `assets/backgrounds/{location_id}_bg.png` | `salon_bg.png` |
| UI chrome | `assets/ui/{element_id}.png` | `dialogue_panel.png` |
| Font | `assets/fonts/{Family}-{Weight}.ttf` | `Tinos-Bold.ttf` |
| Shader | `shaders/{name}_compat.gdshader` | `vignette_compat.gdshader` |

`character_id` matches content IDs (`cassian_vale`, `maris_quell`, `wren_halden`, `edrin_voss`, `taly_renn`, `sera_kade`, `pim_orel`, `clerk_moth`).

Portrait lookup also honors `portrait_key` from character JSON when present.

### Expressions (portraits) — 5 × 8 = 40 files

`neutral`, `amused`, `suspicious`, `flustered`, `cold`

### Locations (backgrounds)

| File stem | Used for |
|-----------|----------|
| `foyer` | Reception foyer |
| `salon` | Salon |
| `terrace` | Terrace |
| `study_annex` | Study (UI maps SceneRouter `study` → this) |
| `study` | Alias copy of study annex (optional direct use) |
| `cloakroom` | Cloakroom |
| `briefing` | Wren briefing / title wash |

### UI chrome keys

`dialogue_panel`, `choice_button`, `intent_chip`, `notebook_page`, `faculty_panel`, `mission_stamp`, `logo_mark`, `focus_corners`

### Inventory checklist (placeholders shipped)

- Portraits: **40** PNG (`8` characters × `5` expressions)
- Silhouettes: **8** PNG
- Backgrounds: **7** PNG (incl. `study` + `study_annex`)
- UI chrome: **8** PNG
- Fonts: Tinos (R/B/I), Public Sans (R/B/I), Source Sans 3 (R) + `LICENSES.txt`
- Shaders: `vignette_compat.gdshader`, `panel_grain_compat.gdshader` (Compatibility / canvas_item only)

## Recommended final sizes

| Asset | Size | Notes |
|-------|------|-------|
| Portrait | 512×512 | Square comic panel; transparent OK |
| Silhouette | 256×410 | Full-body expressive pose |
| Background | 1280×720 | 16:9; Compatibility renderer |
| Dialogue panel | 960×220 | Nine-patch friendly |
| Choice button | 640×56 | Horizontal |
| Intent chip | 160×28 | Optional; UI also draws chips procedurally |
| Faculty panel | 320×120 | Optional texture under comic stack |
| Logo mark | 256×256 | Title / pause accents |

## Scene → asset map (presentation)

| UI surface | Primary assets |
|------------|----------------|
| `scenes/ui/game_hud.tscn` | backgrounds via `RoomTransition`, portraits in `DialogueBox` |
| `scenes/ui/title_screen.tscn` | `salon_bg`, `logo_mark` |
| `scenes/ui/intel_notebook.tscn` | `notebook_page` |
| `scenes/ui/faculty_stack.tscn` | `faculty_panel` (optional) |
| `themes/hegemony_theme_factory.gd` | fonts under `assets/fonts/` |

## Regenerate placeholders

```bash
python3 tools/generate_placeholders.py
```

Requires Pillow (`pip install Pillow`). Re-run after adding characters/locations to the generator script.

## Fonts (OFL / Apache)

- **Tinos** (serif display) — Apache License 2.0 (Croscore)
- **Public Sans** (UI) — SIL OFL
- **Source Sans 3** (body fallback) — SIL OFL

License texts: `assets/fonts/LICENSES.txt`

## Palette tokens

See `themes/hegemony_palette.gd` — ink navy, brass, jade, ivory, vermillion. Do not drift into generic purple gradients or cream+terracotta cliché.

Intent gloss + faculty accent helpers live on the same palette script.

## Import tips for Clip Studio replacements

1. Export PNG (sRGB), same filename.
2. Overwrite the file in-place; Godot reimports on focus (updates sibling `.import`).
3. Keep subject framed for dramatic close-ups; leave margin for vignette.
4. Portraits should read as exaggerated comic silhouettes, not photoreal.
5. Prefer Compatibility-safe art (no HDR-only tricks); shaders are `canvas_item` only.
