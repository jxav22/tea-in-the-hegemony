extends RefCounted
class_name ContentIndex
## Discovers characters / chapters / dialogue graphs under res://content/


static func load_character(char_id: String) -> Dictionary:
	var path: String = "res://content/characters/%s.json" % char_id
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data as Dictionary if typeof(data) == TYPE_DICTIONARY else {}


static func list_characters() -> PackedStringArray:
	return _list_json_basenames("res://content/characters")


static func load_chapter(chapter_id: String) -> Dictionary:
	var path: String = "res://content/chapters/%s.json" % chapter_id
	if not FileAccess.file_exists(path):
		# Alias: "reception" ↔ "the_reception"
		if chapter_id == "reception":
			path = "res://content/chapters/the_reception.json"
		elif chapter_id == "the_reception":
			path = "res://content/chapters/reception.json"
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data as Dictionary if typeof(data) == TYPE_DICTIONARY else {}


static func apply_character_defaults(char_id: StringName) -> void:
	var def: Dictionary = load_character(String(char_id))
	if def.is_empty():
		GameState.ensure_relationship(char_id)
		return
	var rel: Dictionary = GameState.ensure_relationship(char_id)
	var defaults: Dictionary = def.get("default_rel", {}) as Dictionary
	for key: Variant in defaults.keys():
		rel[str(key)] = int(defaults[key])


static func bootstrap_chapter(chapter_id: StringName = &"reception") -> void:
	var chapter: Dictionary = load_chapter(String(chapter_id))
	GameState.set_chapter(StringName(str(chapter.get("id", chapter_id))))
	var cast: Array = chapter.get("characters", chapter.get("characters_present", [])) as Array
	for cid: Variant in cast:
		apply_character_defaults(StringName(str(cid)))
	var flags_init: Dictionary = chapter.get("flags_initialized", {}) as Dictionary
	for fk: Variant in flags_init.keys():
		FlagStore.set_flag(StringName(str(fk)), flags_init[fk])
	for obj: Variant in chapter.get("objectives", []) as Array:
		if typeof(obj) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = obj as Dictionary
		var oid: StringName = StringName(str(d.get("id", "")))
		var label: String = str(d.get("label", oid))
		var status: String = "active"
		# Agent B uses flag_done / flag_fail markers.
		if d.has("flag_done") and bool(FlagStore.get_flag(StringName(str(d["flag_done"])), false)):
			status = "complete"
		if d.has("flag_fail") and bool(FlagStore.get_flag(StringName(str(d["flag_fail"])), false)):
			status = "failed"
		GameState.set_objective(oid, status, label)


static func _list_json_basenames(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			out.append(name.get_basename())
		name = dir.get_next()
	dir.list_dir_end()
	return out
