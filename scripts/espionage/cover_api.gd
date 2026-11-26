extends RefCounted
class_name CoverAPI
## Thin cover/heat helpers. Storage remains on GameState; rich logic via SystemsBridge.


static func heat() -> int:
	return int(GameState.cover_state.get("heat", 0))


static func is_blown() -> bool:
	return bool(GameState.cover_state.get("blown", false))


static func cover_name() -> String:
	return str(GameState.cover_state.get("name", ""))


static func heat_band() -> String:
	if GameState.systems != null:
		return GameState.systems.cover.cover.heat_band()
	if is_blown():
		return "blown"
	var h := heat()
	if h >= 80:
		return "critical"
	if h >= 55:
		return "high"
	if h >= 30:
		return "elevated"
	if h >= 10:
		return "low"
	return "clear"


static func present(reveal_raw: bool = false) -> Dictionary:
	if GameState.systems != null:
		return GameState.systems.present_cover(reveal_raw)
	return {
		"cover_name": cover_name(),
		"heat_band": heat_band(),
		"blown": is_blown(),
		"attention_line": "Cover state unavailable.",
	}


static func escalate(delta: int = 10, reason: String = "escalate", slip: Dictionary = {}) -> Dictionary:
	if GameState.systems == null:
		raise_heat(delta, reason)
		return {"heat": heat(), "blown": is_blown()}
	var effect := {
		"op": "cover",
		"action": "escalate",
		"delta": delta,
		"reason": reason,
	}
	if not slip.is_empty():
		effect["slip"] = slip
	return GameState.apply_systems_effect(effect)


static func repair(delta: int = -8, reason: String = "repair", force_unblow: bool = false) -> Dictionary:
	if GameState.systems == null:
		return {"heat": GameState.adjust_heat(delta if delta < 0 else -abs(delta))}
	return GameState.apply_systems_effect({
		"op": "cover",
		"action": "repair",
		"delta": delta,
		"reason": reason,
		"force_unblow": force_unblow,
	})


static func raise_heat(amount: int, reason: String = "") -> int:
	var next: int
	if GameState.systems != null:
		GameState.apply_systems_effect({
			"op": "cover",
			"action": "adjust_heat",
			"delta": amount,
			"reason": reason,
		})
		next = heat()
	else:
		next = GameState.adjust_heat(amount)
	if not reason.is_empty():
		GameState.add_memory({
			"id": "heat_%d_%d" % [GameState.beat_index, next],
			"summary": "Heat %+d: %s" % [amount, reason],
			"salience": 1,
			"tags": ["heat", "cover"],
		})
	return next


static func assert_fact(key: String, value: String, beat: String = "", witness: String = "") -> Dictionary:
	if GameState.systems == null:
		return {}
	return GameState.apply_systems_effect({
		"op": "cover",
		"action": "assert",
		"key": key,
		"value": value,
		"beat": beat,
		"witness": witness,
	})


static func slip(key: String, value: String, beat: String = "", witness: String = "", heat_delta: int = 15) -> Dictionary:
	if GameState.systems == null:
		return {}
	return GameState.apply_systems_effect({
		"op": "cover",
		"action": "slip",
		"key": key,
		"value": value,
		"beat": beat,
		"witness": witness,
		"heat": heat_delta,
	})


static func has_evidence(fragment_id: StringName) -> bool:
	if GameState.systems != null and GameState.systems.evidence.is_obtained(str(fragment_id)):
		return true
	return GameState.has_item(fragment_id)


static func evidence_notebook(reveal_raw: bool = false) -> Array:
	## Player-facing evidence list for intel notebook UI.
	if GameState.systems != null:
		var presented: Array[Dictionary] = GameState.systems.present_evidence(reveal_raw)
		var out: Array = []
		for e in presented:
			out.append(e)
		return out
	var fallback: Array = []
	for entry in GameState.inventory:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		if str(e.get("kind", "")) != "evidence" and not str(e.get("id", "")).begins_with("frag."):
			continue
		fallback.append({
			"id": str(e.get("id", "")),
			"title": str(e.get("title", e.get("id", ""))),
			"summary": str(e.get("summary", "")),
			"verified": bool(e.get("verified", false)),
			"verification_label": "Verified" if bool(e.get("verified", false)) else "Unconfirmed",
		})
	return fallback


static func debrief(reveal_raw: bool = false) -> Dictionary:
	if GameState.systems != null:
		return GameState.systems.present_debrief("debrief", reveal_raw)
	return {
		"title": "Debrief unavailable",
		"summary": "Systems bridge offline.",
	}


static func mission_complete_enough() -> bool:
	if GameState.systems != null:
		var obtained: bool = GameState.systems.evidence.is_obtained("frag.shipping_delta")
		var met: bool = bool(FlagStore.get_flag(&"met_maris", false))
		var voss: bool = (
			bool(FlagStore.get_flag(&"identified_voss", false))
			or bool(FlagStore.get_flag(&"spotted_voss", false))
		)
		return obtained or (met and voss)
	return (
		FlagStore.get_flag(&"got_fragment", false) == true
		or (
			FlagStore.get_flag(&"met_maris", false) == true
			and FlagStore.get_flag(&"spotted_voss", false) == true
		)
	)
