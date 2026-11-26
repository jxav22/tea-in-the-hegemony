extends RefCounted
class_name CharacterRegistry
## Loads and caches character defs for UI / social systems.


var _by_id: Dictionary = {}


func reload() -> void:
	_by_id.clear()
	for cid: String in ContentIndex.list_characters():
		var data: Dictionary = ContentIndex.load_character(cid)
		if not data.is_empty():
			_by_id[cid] = data


func get_character(char_id: StringName) -> Dictionary:
	if _by_id.is_empty():
		reload()
	return (_by_id.get(String(char_id), {}) as Dictionary).duplicate(true)


func display_name(char_id: StringName) -> String:
	var d: Dictionary = get_character(char_id)
	if d.has("display_name"):
		return str(d["display_name"])
	return String(char_id)


func all_ids() -> PackedStringArray:
	if _by_id.is_empty():
		reload()
	var out: PackedStringArray = []
	for k: Variant in _by_id.keys():
		out.append(str(k))
	return out
