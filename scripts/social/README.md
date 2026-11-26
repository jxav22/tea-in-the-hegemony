# Social systems (Agent C)

Multi-dimension relationships + character memories. **No single progress bar.**

## Core storage

Mutations flow through `GameState` / `EffectExecutor` and mirror via `SystemsBridge` — do not fork relationship storage.

- Dimensions: `trust`, `familiarity`, `suspicion`, `respect`, `affection`, `comfort`, `perceived_authenticity`
- `GameState.systems` → `RelationshipManager` / `MemoryManager`
- UI: `RelationshipQuery.present(char_id)` (qualitative) or `GameState.systems.present_character`

## Effects

```json
{"op":"rel","char":"maris_quell","trust":1,"suspicion":-1}
{"op":"memory","char":"maris_quell","id":"noticed_hesitation","summary":"...","salience":2,"tags":["awkward"],"beat":"foyer.meet"}
{"op":"knowledge","char":"maris_quell","flag":"identified_voss","value":true}
```

## Scripts

`relationship_dimensions.gd`, `relationship_state.gd`, `relationship_manager.gd`, `memory_entry.gd`, `memory_manager.gd`, `social_presentation.gd`, `knowledge_flags.gd`, `relationship_query.gd`
