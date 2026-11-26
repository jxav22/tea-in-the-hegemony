extends RefCounted
class_name DialogueLoader
## Loads dialogue graphs from content/dialogue/*.json
## Schema: { "id", "start", "nodes": [ DialogueNode, ... ] } OR flat node array with start.

const CONTENT_ROOT: String = "res://content/dialogue"


static func load_graph(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueLoader: missing %s" % path)
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY and typeof(parsed) != TYPE_ARRAY:
		push_error("DialogueLoader: invalid JSON root in %s" % path)
		return {}
	return normalize_graph(parsed, path)


static func load_by_id(graph_id: String) -> Dictionary:
	## Resolution order (Agent B nests under reception/):
	## 1) content/dialogue/reception/<id>.json
	## 2) content/dialogue/<id>.json
	## 3) recursive basename search
	var candidates: PackedStringArray = PackedStringArray([
		"%s/reception/%s.json" % [CONTENT_ROOT, graph_id],
		"%s/%s.json" % [CONTENT_ROOT, graph_id],
	])
	for path: String in candidates:
		if FileAccess.file_exists(path):
			return load_graph(path)
	var found: String = _find_by_id(graph_id)
	if found.is_empty():
		push_error("DialogueLoader: graph id not found: %s" % graph_id)
		return {}
	return load_graph(found)


static func load_chapter_index(chapter_folder: String = "reception") -> Dictionary:
	var path: String = "%s/%s/index.json" % [CONTENT_ROOT, chapter_folder]
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data as Dictionary if typeof(data) == TYPE_DICTIONARY else {}


static func normalize_graph(parsed: Variant, source: String = "") -> Dictionary:
	var graph: Dictionary = {
		"id": "",
		"start": "",
		"nodes": {},
		"source": source,
	}
	var nodes_array: Array = []
	if typeof(parsed) == TYPE_ARRAY:
		nodes_array = parsed as Array
		if not nodes_array.is_empty() and typeof(nodes_array[0]) == TYPE_DICTIONARY:
			graph["start"] = str((nodes_array[0] as Dictionary).get("id", ""))
	elif typeof(parsed) == TYPE_DICTIONARY:
		var root: Dictionary = parsed as Dictionary
		graph["id"] = str(root.get("id", ""))
		graph["start"] = str(root.get("start", ""))
		if root.has("nodes"):
			if typeof(root["nodes"]) == TYPE_ARRAY:
				nodes_array = root["nodes"] as Array
			elif typeof(root["nodes"]) == TYPE_DICTIONARY:
				for key: Variant in (root["nodes"] as Dictionary).keys():
					var node_raw: Variant = (root["nodes"] as Dictionary)[key]
					if typeof(node_raw) == TYPE_DICTIONARY:
						var nd: Dictionary = (node_raw as Dictionary).duplicate(true)
						if not nd.has("id"):
							nd["id"] = str(key)
						nodes_array.append(nd)
		elif root.has("id") and root.has("text"):
			nodes_array = [root]
			graph["start"] = str(root.get("id", ""))
	var by_id: Dictionary = {}
	for item: Variant in nodes_array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = DialogueTypes.normalize_node(item as Dictionary)
		if str(node["id"]).is_empty():
			continue
		var choices_norm: Array = []
		for ch: Variant in node["choices"]:
			if typeof(ch) == TYPE_DICTIONARY:
				choices_norm.append(DialogueTypes.normalize_choice(ch as Dictionary))
		node["choices"] = choices_norm
		by_id[str(node["id"])] = node
	graph["nodes"] = by_id
	if str(graph["start"]).is_empty() and not by_id.is_empty():
		graph["start"] = str(by_id.keys()[0])
	if str(graph["id"]).is_empty():
		graph["id"] = str(graph["start"])
	return graph


static func list_graphs() -> PackedStringArray:
	var out: PackedStringArray = []
	_collect_json(CONTENT_ROOT, out)
	return out


static func _collect_json(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_collect_json(full, out)
		elif name.ends_with(".json"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


static func _find_by_id(graph_id: String) -> String:
	var all: PackedStringArray = list_graphs()
	for path: String in all:
		if path.ends_with("/%s.json" % graph_id) or path.get_file().get_basename() == graph_id:
			return path
	return ""
