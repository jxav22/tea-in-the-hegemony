# Asset Replacement Guide — Tea in the Hegemony

Procedural/vector placeholders ship with the project. Clip Studio (or any pipeline) can replace them by **exact path + filename**. Keep dimensions unless you also update UI stretch settings.

## Naming convention

| Kind | Pattern | Example |
|------|---------|---------|
| Portrait | `assets/portraits/{character_id}_{expression}.png` | `maris_quell_amused.png` |
| Silhouette | `assets/silhouettes/{character_id}_sil.png` | `cassian_vale_sil.png` |
| Background | `assets/backgrounds/{location_id}_bg.png` | `salon_bg.png` |
| UI chrome | `assets/ui/{element_id}.png` | `dialogue_panel.png` |
| Font | `assets/fonts/{Family}-{Weight}.ttf` | `Tinos-Bold.ttf` |

`character_id` matches content IDs (`cassian_vale`, `maris_quell`, `wren_halden`, `edrin_voss`, `taly_renn`, `sera_kade`, `pim_orel`, `clerk_moth`).

### Expressions (portraits)

`neutral`, `amused`, `suspicious`, `flustered`, `cold`

### Locations (backgrounds)

`foyer`, `salon`, `terrace`, `study_annex`, `cloakroom`, `briefing`

### UI chrome keys

`dialogue_panel`, `choice_button`, `intent_chip`, `notebook_page`, `faculty_panel`, `mission_stamp`, `logo_mark`, `focus_corners`

## Recommended final sizes

| Asset | Size | Notes |
|-------|------|-------|
| Portrait | 512×512 | Square comic panel; transparent OK |
| Silhouette | 256×410 | Full-body expressive pose |
| Background | 1280×720 | 16:9; Compatibility renderer |
| Dialogue panel | 960×220 | Nine-patch friendly |
| Choice button | 640×56 | Horizontal |

## Regenerate placeholders

```bash
python3 tools/generate_placeholders.py
```

Requires Pillow (`pip install Pillow`).

## Fonts (OFL / Apache)

- **Tinos** (serif display) — Apache License 2.0 (Croscore)
- **Public Sans** (UI) — SIL OFL
- **Source Sans 3** (body fallback) — SIL OFL

License texts: `assets/fonts/LICENSES.txt`

## Palette tokens

See `themes/hegemony_palette.gd` — ink navy, brass, jade, ivory, vermillion. Do not drift into generic purple gradients or cream+terracotta cliché.

## Import tips for Clip Studio replacements

1. Export PNG (sRGB), same filename.
2. Overwrite the file in-place; Godot reimports on focus.
3. Keep subject framed for dramatic close-ups; leave margin for vignette.
4. Portraits should read as exaggerated comic silhouettes, not photoreal.
