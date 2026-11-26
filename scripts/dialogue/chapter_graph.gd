extends RefCounted
class_name ChapterGraph
## Merges Agent B reception packs into one runnable graph so cross-pack
## `next` ids (e.g. briefing.exit → foyer.arrival) resolve.


static func load_reception() -> Dictionary:
	var index: Dictionary = DialogueLoader.load_chapter_index("reception")
	var merged: Dictionary = {
		"id": "the_reception",
		"start": "briefing.intro",
		"nodes": {},
		"source": "res://content/dialogue/reception/",
		"packs": [],
	}
	var packs: Array = index.get("packs", []) as Array
	if packs.is_empty():
		# Fallback: merge every JSON in the folder except index.
		for path: String in DialogueLoader.list_graphs():
			if "/reception/" in path and not path.ends_with("/index.json"):
				_merge_file(merged, path)
		return merged
	var first_start: String = ""
	for pack: Variant in packs:
		if typeof(pack) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = pack as Dictionary
		var file_name: String = str(p.get("file", ""))
		if file_name.is_empty():
			continue
		var path: String = "res://content/dialogue/reception/%s" % file_name
		_merge_file(merged, path)
		(merged["packs"] as Array).append(file_name)
		var pack_start: String = str(p.get("start", ""))
		if first_start.is_empty() and not pack_start.is_empty():
			first_start = pack_start
	if not first_start.is_empty():
		merged["start"] = first_start
	# Chapter manifest may override start.
	var chapter: Dictionary = ContentIndex.load_chapter("the_reception")
	if chapter.has("start_node"):
		merged["start"] = str(chapter["start_node"])
	return merged


static func _merge_file(merged: Dictionary, path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("ChapterGraph: missing pack %s" % path)
		return
	var part: Dictionary = DialogueLoader.load_graph(path)
	var nodes: Dictionary = part.get("nodes", {}) as Dictionary
	var dest: Dictionary = merged["nodes"] as Dictionary
	for nid: Variant in nodes.keys():
		if dest.has(nid):
			push_warning("ChapterGraph: duplicate node id %s from %s" % [nid, path])
		dest[str(nid)] = nodes[nid]
