class_name MemoryEntry
extends RefCounted
## A character-facing memory that can gate later dialogue conditions.

var id: String = ""
var summary: String = ""
var salience: int = 1
var tags: Array[String] = []
var created_at_beat: String = ""
var about_character: String = ""
var subject: String = "player" ## who the memory is "of" — usually the player
var source: String = "" ## dialogue node id, event id, etc.
var forgotten: bool = false


func _init(data: Dictionary = {}) -> void:
	if data.is_empty():
		return
	from_dict(data)


func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	summary = str(data.get("summary", summary))
	salience = int(data.get("salience", salience))
	created_at_beat = str(data.get("created_at_beat", created_at_beat))
	about_character = str(data.get("about_character", about_character))
	subject = str(data.get("subject", subject))
	source = str(data.get("source", source))
	forgotten = bool(data.get("forgotten", forgotten))
	tags.clear()
	for t in data.get("tags", []):
		tags.append(str(t))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"summary": summary,
		"salience": salience,
		"tags": tags.duplicate(),
		"created_at_beat": created_at_beat,
		"about_character": about_character,
		"subject": subject,
		"source": source,
		"forgotten": forgotten,
	}


func matches_tag(tag: String) -> bool:
	return tag in tags


func is_active() -> bool:
	return not forgotten and id != ""
