extends Node
## Versioned save/load. Slot files under user://saves/slot_N.json

signal save_completed(slot: int, path: String)
signal load_completed(slot: int, path: String)
signal save_failed(slot: int, reason: String)
signal load_failed(slot: int, reason: String)

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves"
const MAX_SLOTS: int = 5


func _ready() -> void:
	_ensure_dir()


func get_slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func list_slots() -> Array:
	var result: Array = []
	for i: int in range(1, MAX_SLOTS + 1):
		var path: String = get_slot_path(i)
		if FileAccess.file_exists(path):
			var meta: Dictionary = peek_slot(i)
			result.append({"slot": i, "path": path, "meta": meta})
	return result


func peek_slot(slot: int) -> Dictionary:
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = data as Dictionary
	return {
		"save_version": d.get("save_version", 0),
		"chapter_id": d.get("chapter_id", ""),
		"current_location": d.get("current_location", ""),
		"timestamp": d.get("timestamp", ""),
	}


func save_game(slot: int = 1) -> bool:
	_ensure_dir()
	if slot < 1 or slot > MAX_SLOTS:
		save_failed.emit(slot, "invalid slot")
		return false
	var payload: Dictionary = GameState.to_save_dict()
	payload["timestamp"] = Time.get_datetime_string_from_system(true)
	payload["save_version"] = SAVE_VERSION
	var path: String = get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		save_failed.emit(slot, "cannot open %s" % path)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	save_completed.emit(slot, path)
	return true


func load_game(slot: int = 1) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		load_failed.emit(slot, "invalid slot")
		return false
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		load_failed.emit(slot, "missing file")
		return false
	var raw: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		load_failed.emit(slot, "invalid JSON")
		return false
	var d: Dictionary = data as Dictionary
	var version: int = int(d.get("save_version", 0))
	if version > SAVE_VERSION:
		load_failed.emit(slot, "save newer than game (%d > %d)" % [version, SAVE_VERSION])
		return false
	d = _migrate(d, version)
	GameState.load_from_save_dict(d)
	load_completed.emit(slot, path)
	return true


func delete_slot(slot: int) -> bool:
	var path: String = get_slot_path(slot)
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	return false


func quick_save() -> bool:
	return save_game(1)


func quick_load() -> bool:
	return load_game(1)


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	## Additive migrations only. Keep older saves loadable.
	var out: Dictionary = data.duplicate(true)
	if from_version < 1:
		out["save_version"] = 1
		if not out.has("flags"):
			out["flags"] = {}
		if not out.has("rels"):
			out["rels"] = {}
		if not out.has("memories"):
			out["memories"] = []
		if not out.has("inventory"):
			out["inventory"] = []
		if not out.has("cover_state"):
			out["cover_state"] = {}
		if not out.has("objectives"):
			out["objectives"] = {}
	out["save_version"] = SAVE_VERSION
	return out


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
