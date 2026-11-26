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
	# Narrative aliases → Core ops (Agent E integration)
	match op:
		"add_memory":
			op = "memory"
		"add_heat":
			op = "heat"
		"set_location":
			op = "location"
		"unset_flag":
			FlagStore.set_flag(StringName(str(effect.get("flag", ""))), false)
			return
		"complete_objective", "fail_objective", "set_objective":
			var status: String = "complete" if op == "complete_objective" else ("failed" if op == "fail_objective" else str(effect.get("status", "active")))
			GameState.set_objective(
				StringName(str(effect.get("id", effect.get("objective", "")))),
				status,
				str(effect.get("label", ""))
			)
			return
		"add_evidence":
			GameState.add_inventory_item(StringName(str(effect.get("id", effect.get("evidence", "")))), effect.get("meta", {}) as Dictionary)
			return
		"end":
			FlagStore.set_flag(&"chapter_complete", true)
			if effect.has("ending") or effect.has("id"):
				FlagStore.set_flag(&"ending_id", str(effect.get("ending", effect.get("id", ""))))
			return
		"goto":
			return
	match op:
		"set_flag":
			FlagStore.set_flag(StringName(str(effect.get("flag", ""))), effect.get("value", true))
			if GameState.systems != null and GameState.systems.mission != null:
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
			GameState.add_inventory_item(StringName(str(effect.get("id", ""))), effect.get("meta", {}) as Dictionary)
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
