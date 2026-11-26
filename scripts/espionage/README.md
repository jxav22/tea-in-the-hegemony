# Espionage systems (Agent C)

Cover identity, evidence fragments, intel objectives, mission reports.

## Core hooks

- `GameState.systems` (`SystemsBridge`) — bootstrap via `SystemsBootstrap.create_with_reception_content()`
- `GameStateBinder` mirrors into `cover_state` / `objectives` / `inventory` / `memories` / `relationships`
- Thin helpers: `CoverAPI` (heat, evidence checks, present)
- Content: `content/missions/reception.json`, `content/evidence/reception_evidence.json`

## Effects

```json
{"op":"cover","action":"assert|slip|adjust_heat|repair|blow", "...": "..."}
{"op":"heat","amount":10}
{"op":"evidence","action":"obtain|verify|dispute","id":"frag.shipping_delta"}
{"op":"objective","action":"activate|complete|fail|reveal|evaluate|start_mission","id":"obj.contact_maris"}
```

## Presentation

`CoverAPI.present()`, `GameState.systems.present_evidence()`, `present_mission()`, `present_debrief()`

## Offline check

`python3 scripts/espionage/simulate_reception_paths.py`
