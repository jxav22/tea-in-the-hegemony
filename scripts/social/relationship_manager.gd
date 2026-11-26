class_name RelationshipManager
extends RefCounted
## Multi-dimension relationships. DialogueRunner effect op: "rel".
##
## Effect shape:
##   {"op":"rel","char":"maris_quell","trust":1,"suspicion":-1}
## Condition helpers expose qualitative bands + thresholds without dumping raw UI.

signal relationship_changed(character_id: String, dimension: String, new_value: int, delta: int)
signal knowledge_changed(character_id: String, flag: String, value: Variant)
signal memory_added(character_id: String, memory_id: String)

var _rels: Dictionary = {} ## character_id -> RelationshipState
var _presentation: SocialPresentation


func _init() -> void:
	_presentation = SocialPresentation.new()


func ensure(character_id: String, defaults: Dictionary = {}) -> RelationshipState:
	if not _rels.has(character_id):
		_rels[character_id] = RelationshipState.new(character_id, defaults)
	elif not defaults.is_empty():
		# Only fill missing dims / flags on first ensure with defaults.
		pass
	return _rels[character_id] as RelationshipState


func get_state(character_id: String) -> RelationshipState:
	return ensure(character_id)


func has_character(character_id: String) -> bool:
	return _rels.has(character_id)


func get_dim(character_id: String, dimension: String) -> int:
	return ensure(character_id).get_dim(dimension)


func set_dim(character_id: String, dimension: String, value: int) -> void:
	var state := ensure(character_id)
	var before := state.get_dim(dimension)
	state.set_dim(dimension, value)
	var after := state.get_dim(dimension)
	if after != before:
		relationship_changed.emit(character_id, dimension, after, after - before)


func adjust(character_id: String, dimension: String, delta: int) -> int:
	var state := ensure(character_id)
	var before := state.get_dim(dimension)
	var after := state.adjust_dim(dimension, delta)
	if after != before:
		relationship_changed.emit(character_id, dimension, after, after - before)
	return after


## Apply DialogueRunner effect op "rel".
## Optional knowledge: "knowledge":"identified_voss" or "set_knowledge":{"flag":"...","value":true}
func apply_effect(effect: Dictionary) -> Dictionary:
	var char_id := str(effect.get("char", effect.get("character", "")))
	if char_id == "":
		push_warning("rel effect missing char")
		return {}
	var state := ensure(char_id)
	var before := state.dimensions.duplicate()
	var changed := state.apply_rel_effect(effect)
	for dim in changed.keys():
		var delta := int(changed[dim]) - int(before.get(dim, 0))
		relationship_changed.emit(char_id, str(dim), int(changed[dim]), delta)
	if effect.has("knowledge") and effect["knowledge"] != null:
		var flag := str(effect["knowledge"])
		var val: Variant = effect.get("knowledge_value", true)
		set_knowledge(char_id, flag, val)
		changed["_knowledge"] = {flag: val}
	if effect.has("set_knowledge") and typeof(effect["set_knowledge"]) == TYPE_DICTIONARY:
		var sk: Dictionary = effect["set_knowledge"]
		var flag2 := str(sk.get("flag", ""))
		if flag2 != "":
			var val2: Variant = sk.get("value", true)
			set_knowledge(char_id, flag2, val2)
			changed["_knowledge"] = {flag2: val2}
	return changed


func set_knowledge(character_id: String, flag: String, value: Variant = true) -> void:
	ensure(character_id).set_knowledge(flag, value)
	knowledge_changed.emit(character_id, flag, value)


func has_knowledge(character_id: String, flag: String) -> bool:
	return ensure(character_id).has_knowledge(flag)


func add_memory(character_id: String, memory_data: Dictionary) -> MemoryEntry:
	var entry := MemoryEntry.new(memory_data)
	ensure(character_id).add_memory(entry)
	memory_added.emit(character_id, entry.id)
	return entry


## DialogueRunner effect op "memory".
## {"op":"memory","char":"maris_quell","id":"noticed_shoes","summary":"...","salience":2,"tags":["awkward"],"beat":"foyer.meet"}
func apply_memory_effect(effect: Dictionary) -> MemoryEntry:
	var char_id := str(effect.get("char", effect.get("character", "")))
	if char_id == "":
		push_warning("memory effect missing char")
		return null
	var data := {
		"id": str(effect.get("id", "")),
		"summary": str(effect.get("summary", "")),
		"salience": int(effect.get("salience", 1)),
		"tags": effect.get("tags", []),
		"created_at_beat": str(effect.get("beat", effect.get("created_at_beat", ""))),
		"source": str(effect.get("source", effect.get("node", ""))),
		"subject": str(effect.get("subject", "player")),
	}
	return add_memory(char_id, data)


func has_memory(character_id: String, memory_id: String) -> bool:
	return ensure(character_id).has_memory(memory_id)


func memories_with_tag(character_id: String, tag: String) -> Array[MemoryEntry]:
	return ensure(character_id).memories_with_tag(tag)


## Condition helpers for DialogueRunner.
func check_condition(cond: Dictionary) -> bool:
	var op := str(cond.get("op", "eq"))
	var char_id := str(cond.get("char", cond.get("character", "")))
	if char_id == "":
		return false

	if cond.has("memory"):
		var has := has_memory(char_id, str(cond["memory"]))
		return has if op != "neq" and op != "not" else not has

	if cond.has("memory_tag"):
		var tagged := memories_with_tag(char_id, str(cond["memory_tag"]))
		var has_tag := tagged.size() > 0
		return has_tag if op != "neq" and op != "not" else not has_tag

	if cond.has("knowledge"):
		var has_k := has_knowledge(char_id, str(cond["knowledge"]))
		return has_k if op != "neq" and op != "not" else not has_k

	if cond.has("dim") or cond.has("dimension"):
		var dim := str(cond.get("dim", cond.get("dimension", "")))
		var actual := get_dim(char_id, dim)
		var expected := int(cond.get("value", 0))
		match op:
			"eq":
				return actual == expected
			"neq":
				return actual != expected
			"gte", "ge":
				return actual >= expected
			"lte", "le":
				return actual <= expected
			"gt":
				return actual > expected
			"lt":
				return actual < expected
			"band":
				return RelationshipDimensions.band_for(actual) == str(cond.get("value", "neutral"))
			_:
				return actual == expected

	return false


## Player-facing snapshot — qualitative only by default.
func present(character_id: String, reveal_raw: bool = false) -> Dictionary:
	return _presentation.present_relationship(ensure(character_id), reveal_raw)


func present_memories(character_id: String) -> Array[Dictionary]:
	return _presentation.present_memories(ensure(character_id))


func all_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _rels.keys():
		ids.append(str(k))
	return ids


func to_save() -> Dictionary:
	var out := {}
	for char_id in _rels.keys():
		out[str(char_id)] = (_rels[char_id] as RelationshipState).to_dict()
	return out


func load_save(data: Dictionary) -> void:
	_rels.clear()
	for char_id in data.keys():
		var state := RelationshipState.new(str(char_id))
		state.from_dict(data[char_id])
		_rels[str(char_id)] = state


## Seed from character def default_rel blobs.
func seed_from_character_defs(defs: Array) -> void:
	for d in defs:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := str(d.get("id", ""))
		if id == "":
			continue
		var defaults: Dictionary = d.get("default_rel", {})
		if d.has("motivations"):
			defaults = defaults.duplicate()
			defaults["motivations"] = d["motivations"]
		ensure(id, defaults)
