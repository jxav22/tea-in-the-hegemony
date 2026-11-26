# Espionage systems (Agent C)

Core hooks:

- `GameState.adjust_heat` / `cover_state`
- `GameState.add_inventory_item` / `has_item`
- `GameState.set_objective` / objectives dict
- Evidence schemas under `content/schemas/evidence.schema.json`
- Mission stubs under `content/missions/` (yours)

Dialogue effects already support `heat`, `item`, `objective`, `memory`.
