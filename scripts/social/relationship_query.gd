extends RefCounted
class_name RelationshipQuery
## Read-only helpers for Agent C / UI. Mutate via GameState only.


static func snapshot(char_id: StringName) -> Dictionary:
	return GameState.ensure_relationship(char_id).duplicate(true)


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


static func memories_tagged(tag: String) -> Array:
	var out: Array = []
	for m: Variant in GameState.memories:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var tags: Array = (m as Dictionary).get("tags", []) as Array
		if tag in tags:
			out.append(m)
	return out
