# Social systems (Agent C)

Core exposes relationship APIs on `GameState`:

- `ensure_relationship(char_id)`
- `get_rel` / `adjust_rel` / `set_rel` / `apply_rel_effects`
- Dimensions: trust, familiarity, suspicion, respect, affection, comfort, perceived_authenticity
- Memories via `GameState.add_memory` / `has_memory`

Put social-sim logic here. Do not fork relationship storage.
