extends Node
## Central runtime state: chapter, cover, relationships, memories, inventory, objectives.
## Other agents call typed APIs here — do not poke FlagStore for relationship data.

signal relationship_changed(char_id: StringName, dimension: StringName, value: int)
signal memory_added(memory: Dictionary)
signal cover_changed(state: Dictionary)
signal objective_changed(objective_id: StringName, status: String)
signal chapter_changed(chapter_id: StringName)

const REL_DIMENSIONS: PackedStringArray = [
	"trust", "familiarity", "suspicion", "respect", "affection", "comfort", "perceived_authenticity"
]

const FACULTIES: PackedStringArray = [
	"Analysis", "Tradecraft", "Composure", "Empathy", "Improvisation", "Idealism", "Insecurity"
]

var save_version: int = SaveService.SAVE_VERSION
var chapter_id: StringName = &"reception"
var current_location: StringName = &"foyer"
var cover_state: Dictionary = {
	"name": "Cassian Orth",
	"true_name": "Cassian Vale",
	"role": "Ministry Trade Liaison",
	"heat": 0,
	"blown": false,
}
var inventory: Array = []
var objectives: Dictionary = {} ## id -> {id, status, label}
var memories: Array = [] ## Memory dicts
var relationships: Dictionary = {} ## char_id -> dimension dict
var beat_index: int = 0


func _ready() -> void:
	_seed_defaults()


func reset_to_new_game() -> void:
	FlagStore.clear()
	chapter_id = &"reception"
	current_location = &"foyer"
	cover_state = {
		"name": "Cassian Orth",
		"true_name": "Cassian Vale",
		"role": "Ministry Trade Liaison",
		"heat": 0,
		"blown": false,
	}
	inventory.clear()
	objectives.clear()
	memories.clear()
	relationships.clear()
	beat_index = 0
	_seed_defaults()
	# Prefer Agent B chapter manifests when present.
	if FileAccess.file_exists("res://content/chapters/the_reception.json"):
		ContentIndex.bootstrap_chapter(&"the_reception")
	elif FileAccess.file_exists("res://content/chapters/reception.json"):
		ContentIndex.bootstrap_chapter(&"reception")
	chapter_changed.emit(chapter_id)


func set_chapter(id: StringName) -> void:
	chapter_id = id
	chapter_changed.emit(id)


func set_location(loc: StringName) -> void:
	current_location = loc


func ensure_relationship(char_id: StringName) -> Dictionary:
	if not relationships.has(char_id):
		var blank: Dictionary = {}
		for dim: String in REL_DIMENSIONS:
			blank[dim] = 0
		relationships[char_id] = blank
	return relationships[char_id] as Dictionary


func get_rel(char_id: StringName, dimension: StringName) -> int:
	var rel: Dictionary = ensure_relationship(char_id)
	return int(rel.get(dimension, 0))


func adjust_rel(char_id: StringName, dimension: StringName, delta: int) -> int:
	var rel: Dictionary = ensure_relationship(char_id)
	var next: int = clampi(int(rel.get(dimension, 0)) + delta, -100, 100)
	rel[dimension] = next
	relationship_changed.emit(char_id, dimension, next)
	return next


func set_rel(char_id: StringName, dimension: StringName, value: int) -> void:
	var rel: Dictionary = ensure_relationship(char_id)
	rel[dimension] = clampi(value, -100, 100)
	relationship_changed.emit(char_id, dimension, int(rel[dimension]))


func apply_rel_effects(char_id: StringName, deltas: Dictionary) -> void:
	for key: Variant in deltas.keys():
		var dim: StringName = StringName(str(key))
		if str(dim) in REL_DIMENSIONS:
			adjust_rel(char_id, dim, int(deltas[key]))


func add_memory(memory: Dictionary) -> void:
	if not memory.has("id"):
		memory["id"] = "mem_%d" % memories.size()
	if not memory.has("created_at_beat"):
		memory["created_at_beat"] = beat_index
	if not memory.has("salience"):
		memory["salience"] = 1
	if not memory.has("tags"):
		memory["tags"] = []
	memories.append(memory)
	memory_added.emit(memory)


func has_memory(memory_id: StringName) -> bool:
	for m: Variant in memories:
		if typeof(m) == TYPE_DICTIONARY and StringName(str((m as Dictionary).get("id", ""))) == memory_id:
			return true
	return false


func add_inventory_item(item_id: StringName, meta: Dictionary = {}) -> void:
	for entry: Variant in inventory:
		if typeof(entry) == TYPE_DICTIONARY and StringName(str((entry as Dictionary).get("id", ""))) == item_id:
			return
	var payload: Dictionary = meta.duplicate(true)
	payload["id"] = String(item_id)
	inventory.append(payload)


func has_item(item_id: StringName) -> bool:
	for entry: Variant in inventory:
		if typeof(entry) == TYPE_DICTIONARY and StringName(str((entry as Dictionary).get("id", ""))) == item_id:
			return true
	return false


func set_objective(objective_id: StringName, status: String, label: String = "") -> void:
	var existing: Dictionary = objectives.get(objective_id, {}) as Dictionary
	if label.is_empty():
		label = str(existing.get("label", objective_id))
	objectives[objective_id] = {"id": String(objective_id), "status": status, "label": label}
	objective_changed.emit(objective_id, status)


func get_objective_status(objective_id: StringName) -> String:
	var existing: Dictionary = objectives.get(objective_id, {}) as Dictionary
	return str(existing.get("status", "unknown"))


func adjust_heat(delta: int) -> int:
	cover_state["heat"] = clampi(int(cover_state.get("heat", 0)) + delta, 0, 100)
	if int(cover_state["heat"]) >= 80:
		cover_state["blown"] = true
	cover_changed.emit(cover_state)
	return int(cover_state["heat"])


func advance_beat() -> void:
	beat_index += 1


func to_save_dict() -> Dictionary:
	return {
		"save_version": SaveService.SAVE_VERSION,
		"chapter_id": String(chapter_id),
		"current_location": String(current_location),
		"flags": FlagStore.to_dict(),
		"rels": relationships.duplicate(true),
		"memories": memories.duplicate(true),
		"inventory": inventory.duplicate(true),
		"cover_state": cover_state.duplicate(true),
		"objectives": objectives.duplicate(true),
		"beat_index": beat_index,
	}


func load_from_save_dict(data: Dictionary) -> void:
	chapter_id = StringName(str(data.get("chapter_id", "reception")))
	current_location = StringName(str(data.get("current_location", "foyer")))
	FlagStore.from_dict(data.get("flags", {}) as Dictionary)
	relationships = (data.get("rels", {}) as Dictionary).duplicate(true)
	memories = (data.get("memories", []) as Array).duplicate(true)
	inventory = (data.get("inventory", []) as Array).duplicate(true)
	cover_state = (data.get("cover_state", cover_state) as Dictionary).duplicate(true)
	objectives = (data.get("objectives", {}) as Dictionary).duplicate(true)
	beat_index = int(data.get("beat_index", 0))
	chapter_changed.emit(chapter_id)
	cover_changed.emit(cover_state)


func _seed_defaults() -> void:
	ensure_relationship(&"maris_quell")
	ensure_relationship(&"wren_halden")
	ensure_relationship(&"edrin_voss")
	ensure_relationship(&"taly_renn")
	ensure_relationship(&"sera_kade")
	ensure_relationship(&"pim_orel")
	ensure_relationship(&"clerk_moth")
	# Ids align with Agent B chapter manifest (obj_*).
	set_objective(&"obj_contact_maris", "active", "Contact Maris Quell")
	set_objective(&"obj_identify_voss", "active", "Identify Voss's east-dock interest")
	set_objective(&"obj_cipher_fragment", "active", "Obtain guest-list cipher fragment")
	set_objective(&"obj_maintain_cover", "active", "Maintain cover as Cassian Orth")
