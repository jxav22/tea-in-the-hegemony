extends RefCounted
class_name EffectExecutor
## Applies dialogue effect ops to GameState / FlagStore.
## Supported ops: set_flag, add_flag, toggle_flag, rel, memory, heat, objective, item, beat


static func apply_all(effects: Array) -> void:
	for e: Variant in effects:
		if typeof(e) == TYPE_DICTIONARY:
			apply(e as Dictionary)


static func apply(effect: Dictionary) -> void:
	var op: String = str(effect.get("op", ""))
	match op:
		"set_flag":
			FlagStore.set_flag(StringName(str(effect.get("flag", ""))), effect.get("value", true))
		"add_flag":
			FlagStore.add_flag(StringName(str(effect.get("flag", ""))), int(effect.get("amount", effect.get("value", 1))))
		"toggle_flag":
			FlagStore.toggle_flag(StringName(str(effect.get("flag", ""))))
		"rel":
			var char_id: StringName = StringName(str(effect.get("char", effect.get("character", ""))))
			var deltas: Dictionary = {}
			for key: Variant in effect.keys():
				var k: String = str(key)
				if k in GameState.REL_DIMENSIONS:
					deltas[k] = int(effect[key])
			if effect.has("deltas") and typeof(effect["deltas"]) == TYPE_DICTIONARY:
				for dk: Variant in (effect["deltas"] as Dictionary).keys():
					deltas[str(dk)] = int((effect["deltas"] as Dictionary)[dk])
			GameState.apply_rel_effects(char_id, deltas)
		"memory":
			var mem: Dictionary = {
				"id": str(effect.get("id", "")),
				"summary": str(effect.get("summary", "")),
				"salience": int(effect.get("salience", 1)),
				"tags": effect.get("tags", []),
			}
			if mem["id"] == "":
				mem["id"] = "mem_auto_%d" % GameState.memories.size()
			GameState.add_memory(mem)
		"heat":
			GameState.adjust_heat(int(effect.get("amount", effect.get("value", 0))))
		"objective":
			GameState.set_objective(
				StringName(str(effect.get("id", ""))),
				str(effect.get("status", "active")),
				str(effect.get("label", ""))
			)
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
			push_warning("EffectExecutor: unknown op '%s'" % op)
