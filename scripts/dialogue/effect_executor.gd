extends RefCounted
class_name EffectExecutor
## Applies dialogue effect ops to GameState / FlagStore / SystemsBridge.
## Core ops: set_flag, add_flag, toggle_flag, rel, memory, heat, objective, item, beat, location
## Systems ops: cover, evidence, knowledge (+ rich objective actions)


static func apply_all(effects: Array) -> void:
	for e: Variant in effects:
		if typeof(e) == TYPE_DICTIONARY:
			apply(e as Dictionary)


static func apply(effect: Dictionary) -> void:
	var op: String = str(effect.get("op", ""))
	match op:
		"set_flag":
			FlagStore.set_flag(StringName(str(effect.get("flag", ""))), effect.get("value", true))
			if GameState.systems != null:
				GameState.systems.mission.evaluate_all(str(effect.get("beat", "")))
				GameStateBinder.push_to_game_state(GameState.systems, GameState)
		"add_flag":
			FlagStore.add_flag(StringName(str(effect.get("flag", ""))), int(effect.get("amount", effect.get("value", 1))))
		"toggle_flag":
			FlagStore.toggle_flag(StringName(str(effect.get("flag", ""))))
		"rel", "memory", "cover", "evidence", "knowledge":
			GameState.apply_systems_effect(effect)
		"heat":
			# Core shorthand → systems cover heat when available.
			var amount := int(effect.get("amount", effect.get("value", effect.get("delta", 0))))
			if GameState.systems != null:
				GameState.apply_systems_effect({
					"op": "cover",
					"action": "adjust_heat",
					"delta": amount,
					"reason": str(effect.get("reason", "heat_effect")),
					"beat": str(effect.get("beat", "")),
				})
			else:
				GameState.adjust_heat(amount)
		"objective":
			_apply_objective(effect)
		"item":
			_apply_item(effect)
		"beat":
			GameState.advance_beat()
		"location":
			# Soft set — keeps dialogue UI on boot; UI may change scenes later.
			SceneRouter.set_location(StringName(str(effect.get("id", effect.get("location", "foyer")))), false)
		"":
			pass
		_:
			# Forward unknown ops to systems if it recognizes them.
			if GameState.systems != null:
				var result: Dictionary = GameState.apply_systems_effect(effect)
				if result.get("error", "") == "unknown_op":
					push_warning("EffectExecutor: unknown op '%s'" % op)
			else:
				push_warning("EffectExecutor: unknown op '%s'" % op)


## Narrative item ids → evidence fragment ids.
const ITEM_EVIDENCE_MAP := {
	"shipping_discrepancy": "frag.shipping_delta",
	"frag.shipping_delta": "frag.shipping_delta",
	"guest_cipher": "frag.guest_cipher",
	"frag.guest_cipher": "frag.guest_cipher",
	"voss_confirm": "frag.voss_confirm",
	"frag.voss_confirm": "frag.voss_confirm",
}


static func _apply_item(effect: Dictionary) -> void:
	var item_id := str(effect.get("id", ""))
	var meta: Dictionary = effect.get("meta", {}) as Dictionary
	if meta.is_empty():
		meta = {}
	else:
		meta = meta.duplicate(true)
	GameState.add_inventory_item(StringName(item_id), meta)
	# Bridge inventory pickups into Systems evidence when mapped.
	if GameState.systems == null:
		return
	var frag_id := str(ITEM_EVIDENCE_MAP.get(item_id, ""))
	if frag_id == "" and item_id.begins_with("frag."):
		frag_id = item_id
	if frag_id == "":
		return
	if not GameState.systems.evidence.has_fragment(frag_id):
		# Register a minimal fragment so obtain still works.
		GameState.systems.evidence.register_fragment({
			"id": frag_id,
			"title": str(meta.get("label", meta.get("title", frag_id))),
			"summary": str(meta.get("summary", meta.get("label", ""))),
			"claims": meta.get("claims", []),
			"contradicts": meta.get("contradicts", []),
			"mission_id": "mission.reception",
		})
	GameState.apply_systems_effect({
		"op": "evidence",
		"action": "obtain",
		"id": frag_id,
		"beat": str(effect.get("beat", "")),
	})
	if bool(meta.get("verified", false)):
		GameState.apply_systems_effect({
			"op": "evidence",
			"action": "verify",
			"id": frag_id,
			"notes": str(meta.get("verification_notes", "item_meta")),
		})


static func _apply_objective(effect: Dictionary) -> void:
	## Support Core {id,status,label} and Systems {action,id}.
	if effect.has("action") and GameState.systems != null:
		GameState.apply_systems_effect(effect)
		# Also mirror Core-style status when action maps cleanly.
		var action := str(effect.get("action", ""))
		var oid := str(effect.get("id", effect.get("objective", "")))
		var core_id := GameStateBinder.core_objective_id(oid)
		match action:
			"complete":
				GameState.set_objective(StringName(core_id), "complete", str(effect.get("label", "")))
			"fail", "abandon":
				GameState.set_objective(StringName(core_id), "failed", str(effect.get("label", "")))
			"activate", "reveal":
				GameState.set_objective(StringName(core_id), "active", str(effect.get("label", "")))
			_:
				pass
		return
	GameState.set_objective(
		StringName(str(effect.get("id", ""))),
		str(effect.get("status", "active")),
		str(effect.get("label", ""))
	)
	if GameState.systems != null:
		var status := str(effect.get("status", "active"))
		var sys_id := GameStateBinder.systems_objective_id(str(effect.get("id", "")))
		var mapped_action := "activate"
		match status:
			"complete", "completed":
				mapped_action = "complete"
			"failed", "fail":
				mapped_action = "fail"
			"hidden":
				mapped_action = "reveal"
			_:
				mapped_action = "activate"
		GameState.systems.mission.apply_effect({
			"op": "objective",
			"action": mapped_action,
			"id": sys_id,
			"beat": str(effect.get("beat", "")),
		})
		GameStateBinder.push_to_game_state(GameState.systems, GameState)
