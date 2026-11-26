class_name EvidenceFragment
extends RefCounted
## Intel fragment with claims, contradictions, and verification state.

var id: String = ""
var title: String = ""
var summary: String = ""
var source: String = "" ## character id, document id, overheard, etc.
var location: String = ""
var claims: Array[Dictionary] = [] ## [{id, text, about, confidence}]
var contradicts: Array[String] = [] ## other fragment ids or claim ids
var supports: Array[String] = []
var tags: Array[String] = []
var verified: bool = false
var verification_notes: String = ""
var obtained: bool = false
var obtained_at_beat: String = ""
var classified: bool = true
var mission_id: String = ""


func _init(data: Dictionary = {}) -> void:
	if not data.is_empty():
		from_dict(data)


func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	title = str(data.get("title", title))
	summary = str(data.get("summary", summary))
	source = str(data.get("source", source))
	location = str(data.get("location", location))
	verified = bool(data.get("verified", verified))
	verification_notes = str(data.get("verification_notes", verification_notes))
	obtained = bool(data.get("obtained", obtained))
	obtained_at_beat = str(data.get("obtained_at_beat", obtained_at_beat))
	classified = bool(data.get("classified", classified))
	mission_id = str(data.get("mission_id", mission_id))
	claims.clear()
	for c in data.get("claims", []):
		if typeof(c) == TYPE_DICTIONARY:
			claims.append(c)
		else:
			claims.append({"id": str(c), "text": str(c)})
	contradicts.clear()
	for c in data.get("contradicts", []):
		contradicts.append(str(c))
	supports.clear()
	for s in data.get("supports", []):
		supports.append(str(s))
	tags.clear()
	for t in data.get("tags", []):
		tags.append(str(t))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"summary": summary,
		"source": source,
		"location": location,
		"claims": claims.duplicate(true),
		"contradicts": contradicts.duplicate(),
		"supports": supports.duplicate(),
		"tags": tags.duplicate(),
		"verified": verified,
		"verification_notes": verification_notes,
		"obtained": obtained,
		"obtained_at_beat": obtained_at_beat,
		"classified": classified,
		"mission_id": mission_id,
	}


func claim_ids() -> Array[String]:
	var ids: Array[String] = []
	for c in claims:
		ids.append(str(c.get("id", "")))
	return ids
