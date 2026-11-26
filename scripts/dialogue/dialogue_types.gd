extends RefCounted
class_name DialogueTypes
## Shared dialogue schema helpers (Agent B authors JSON matching these shapes).


static func empty_node() -> Dictionary:
	return {
		"id": "",
		"speaker": "",
		"text": "",
		"tags": [],
		"conditions": [],
		"effects": [],
		"choices": [],
		"next": null,
		"faculty_interjections": [],
	}


static func normalize_node(raw: Dictionary) -> Dictionary:
	var n: Dictionary = empty_node()
	for key: Variant in n.keys():
		if raw.has(key):
			n[key] = raw[key]
	if typeof(n["choices"]) != TYPE_ARRAY:
		n["choices"] = []
	if typeof(n["conditions"]) != TYPE_ARRAY:
		n["conditions"] = []
	if typeof(n["effects"]) != TYPE_ARRAY:
		n["effects"] = []
	if typeof(n["tags"]) != TYPE_ARRAY:
		n["tags"] = []
	if typeof(n["faculty_interjections"]) != TYPE_ARRAY:
		n["faculty_interjections"] = []
	n["id"] = str(n["id"])
	n["speaker"] = str(n.get("speaker", ""))
	n["text"] = str(n.get("text", ""))
	return n


static func normalize_choice(raw: Dictionary) -> Dictionary:
	return {
		"id": str(raw.get("id", "")),
		"text": str(raw.get("text", "")),
		"intent": str(raw.get("intent", "")),
		"next": raw.get("next", null),
		"conditions": raw.get("conditions", []),
		"effects": raw.get("effects", []),
	}
