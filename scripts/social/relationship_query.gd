extends RefCounted
class_name RelationshipQuery
## Read helpers for UI / dialogue. Mutate via GameState / SystemsBridge effects only.


static func snapshot(char_id: StringName) -> Dictionary:
	return GameState.ensure_relationship(char_id).duplicate(true)


static func present(char_id: StringName, reveal_raw: bool = false) -> Dictionary:
	## Qualitative bands — preferred for player-facing UI.
	if GameState.systems != null:
		return GameState.systems.present_character(str(char_id), reveal_raw)
	return {
		"character_id": str(char_id),
		"dimensions": {},
		"mood_line": "Relationship systems offline.",
		"notable_memories": [],
	}


static func score_affinity(char_id: StringName) -> float:
	## Soft composite for UI hints — not a single romance bar.
	var r: Dictionary = GameState.ensure_relationship(char_id)
	return (
		float(r.get("trust", 0)) * 0.25
		+ float(r.get("affection", 0)) * 0.25
		+ float(r.get("comfort", 0)) * 0.2
		+ float(r.get("respect", 0)) * 0.15
		+ float(r.get("perceived_authenticity", 0)) * 0.15
		- float(r.get("suspicion", 0)) * 0.3
	)


static func is_hostile(char_id: StringName) -> bool:
	return GameState.get_rel(char_id, &"suspicion") >= 5 or score_affinity(char_id) < -3.0


static func has_memory(char_id: StringName, memory_id: StringName) -> bool:
	if GameState.systems != null and GameState.systems.relationships.has_memory(str(char_id), str(memory_id)):
		return true
	return GameState.has_memory(memory_id)


static func memories_tagged(tag: String) -> Array:
	var out: Array = []
	for m: Variant in GameState.memories:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var tags: Array = (m as Dictionary).get("tags", []) as Array
		if tag in tags:
			out.append(m)
	return out


static func band(char_id: StringName, dimension: StringName) -> String:
	var value := GameState.get_rel(char_id, dimension)
	return RelationshipDimensions.band_for(value)
