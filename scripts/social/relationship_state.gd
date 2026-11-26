class_name RelationshipState
extends RefCounted
## Per-character multi-dimension relationship + knowledge flags + motivations.

var character_id: String = ""
var dimensions: Dictionary = {} ## String -> int
var knowledge_flags: Dictionary = {} ## String -> Variant
var motivations: Array[String] = []
var memories: Array[MemoryEntry] = []


func _init(char_id: String = "", defaults: Dictionary = {}) -> void:
	character_id = char_id
	dimensions = RelationshipDimensions.default_map()
	if not defaults.is_empty():
		apply_defaults(defaults)


func apply_defaults(defaults: Dictionary) -> void:
	for dim in RelationshipDimensions.ALL:
		if defaults.has(dim):
			dimensions[dim] = RelationshipDimensions.clamp_value(int(defaults[dim]))
	for flag in defaults.get("knowledge_flags", {}):
		knowledge_flags[str(flag)] = defaults["knowledge_flags"][flag]
	motivations.clear()
	for m in defaults.get("motivations", []):
		motivations.append(str(m))


func get_dim(dimension: String) -> int:
	if not RelationshipDimensions.is_valid(dimension):
		push_warning("Unknown relationship dimension: %s" % dimension)
		return 0
	return int(dimensions.get(dimension, RelationshipDimensions.DEFAULT_VALUE))


func set_dim(dimension: String, value: int) -> void:
	if not RelationshipDimensions.is_valid(dimension):
		push_warning("Unknown relationship dimension: %s" % dimension)
		return
	dimensions[dimension] = RelationshipDimensions.clamp_value(value)


func adjust_dim(dimension: String, delta: int) -> int:
	var next := get_dim(dimension) + delta
	set_dim(dimension, next)
	return get_dim(dimension)


func apply_rel_effect(effect: Dictionary) -> Dictionary:
	## Apply DialogueRunner effect op "rel". Returns changed dims {dim: new_value}.
	var changed := {}
	for dim in RelationshipDimensions.ALL:
		if effect.has(dim):
			changed[dim] = adjust_dim(dim, int(effect[dim]))
	return changed


func set_knowledge(flag: String, value: Variant = true) -> void:
	knowledge_flags[flag] = value


func has_knowledge(flag: String) -> bool:
	return knowledge_flags.has(flag) and bool(knowledge_flags[flag])


func get_knowledge(flag: String, default: Variant = null) -> Variant:
	return knowledge_flags.get(flag, default)


func add_memory(entry: MemoryEntry) -> void:
	if entry == null or entry.id == "":
		return
	for existing in memories:
		if existing.id == entry.id:
			existing.from_dict(entry.to_dict())
			return
	entry.about_character = character_id
	memories.append(entry)


func forget_memory(memory_id: String) -> bool:
	for m in memories:
		if m.id == memory_id:
			m.forgotten = true
			return true
	return false


func has_memory(memory_id: String) -> bool:
	for m in memories:
		if m.id == memory_id and m.is_active():
			return true
	return false


func memories_with_tag(tag: String) -> Array[MemoryEntry]:
	var out: Array[MemoryEntry] = []
	for m in memories:
		if m.is_active() and m.matches_tag(tag):
			out.append(m)
	return out


func active_memories() -> Array[MemoryEntry]:
	var out: Array[MemoryEntry] = []
	for m in memories:
		if m.is_active():
			out.append(m)
	return out


func to_dict() -> Dictionary:
	var mems: Array = []
	for m in memories:
		mems.append(m.to_dict())
	return {
		"character_id": character_id,
		"dimensions": dimensions.duplicate(),
		"knowledge_flags": knowledge_flags.duplicate(true),
		"motivations": motivations.duplicate(),
		"memories": mems,
	}


func from_dict(data: Dictionary) -> void:
	character_id = str(data.get("character_id", character_id))
	dimensions = RelationshipDimensions.default_map()
	var dims: Dictionary = data.get("dimensions", {})
	for dim in RelationshipDimensions.ALL:
		if dims.has(dim):
			dimensions[dim] = RelationshipDimensions.clamp_value(int(dims[dim]))
	knowledge_flags = data.get("knowledge_flags", {}).duplicate(true)
	motivations.clear()
	for m in data.get("motivations", []):
		motivations.append(str(m))
	memories.clear()
	for raw in data.get("memories", []):
		memories.append(MemoryEntry.new(raw))
