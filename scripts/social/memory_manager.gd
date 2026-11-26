class_name MemoryManager
extends RefCounted
## Thin façade over RelationshipManager memory APIs for DialogueRunner / GameState.
## Prefer wiring GameState.memories → this, or call RelationshipManager directly.

signal memory_recorded(character_id: String, memory_id: String)

var relationships: RelationshipManager


func _init(rel_manager: RelationshipManager = null) -> void:
	relationships = rel_manager if rel_manager != null else RelationshipManager.new()


func record(character_id: String, memory_data: Dictionary) -> MemoryEntry:
	var entry := relationships.add_memory(character_id, memory_data)
	if entry != null:
		memory_recorded.emit(character_id, entry.id)
	return entry


func apply_effect(effect: Dictionary) -> MemoryEntry:
	var entry := relationships.apply_memory_effect(effect)
	if entry != null:
		var char_id := str(effect.get("char", effect.get("character", "")))
		if char_id == "":
			char_id = RelationshipManager.infer_memory_character(effect)
		memory_recorded.emit(char_id, entry.id)
	return entry


func has(character_id: String, memory_id: String) -> bool:
	return relationships.has_memory(character_id, memory_id)


func with_tag(character_id: String, tag: String) -> Array[MemoryEntry]:
	return relationships.memories_with_tag(character_id, tag)


## Condition: {"op":"has_memory","char":"maris_quell","memory":"noticed_hesitation"}
func check_condition(cond: Dictionary) -> bool:
	return relationships.check_condition(cond)


func present(character_id: String) -> Array[Dictionary]:
	return relationships.present_memories(character_id)
