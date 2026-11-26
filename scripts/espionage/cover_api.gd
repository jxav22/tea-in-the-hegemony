extends RefCounted
class_name CoverAPI
## Thin cover/heat helpers for Agent C. Storage remains on GameState.


static func heat() -> int:
	return int(GameState.cover_state.get("heat", 0))


static func is_blown() -> bool:
	return bool(GameState.cover_state.get("blown", false))


static func cover_name() -> String:
	return str(GameState.cover_state.get("name", ""))


static func raise_heat(amount: int, reason: String = "") -> int:
	var next: int = GameState.adjust_heat(amount)
	if not reason.is_empty():
		GameState.add_memory({
			"id": "heat_%d_%d" % [GameState.beat_index, next],
			"summary": "Heat %+d: %s" % [amount, reason],
			"salience": 1,
			"tags": ["heat", "cover"],
		})
	return next


static func has_evidence(fragment_id: StringName) -> bool:
	return GameState.has_item(fragment_id)


static func mission_complete_enough() -> bool:
	return (
		FlagStore.get_flag(&"got_fragment", false) == true
		or (
			FlagStore.get_flag(&"met_maris", false) == true
			and FlagStore.get_flag(&"spotted_voss", false) == true
		)
	)
