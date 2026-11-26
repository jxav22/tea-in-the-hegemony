class_name IntelObjective
extends RefCounted
## Single intelligence / social objective with status lifecycle.

const STATUS_HIDDEN := "hidden"
const STATUS_ACTIVE := "active"
const STATUS_OPTIONAL := "optional"
const STATUS_COMPLETE := "complete"
const STATUS_FAILED := "failed"
const STATUS_ABANDONED := "abandoned"

var id: String = ""
var title: String = ""
var description: String = ""
var status: String = STATUS_HIDDEN
var mission_id: String = ""
var category: String = "intel" ## intel | social | cover | survival
var required: bool = true
var priority: int = 1
## Completion rules evaluated by MissionManager.
var complete_when: Array[Dictionary] = []
var fail_when: Array[Dictionary] = []
var reveals_when: Array[Dictionary] = []
var rewards: Dictionary = {}
var related_evidence: Array[String] = []
var related_characters: Array[String] = []
var notes_player: String = "" ## selective player-facing blurb
var completed_at_beat: String = ""
var failed_at_beat: String = ""


func _init(data: Dictionary = {}) -> void:
	if not data.is_empty():
		from_dict(data)


func from_dict(data: Dictionary) -> void:
	id = str(data.get("id", id))
	title = str(data.get("title", title))
	description = str(data.get("description", description))
	status = str(data.get("status", status))
	mission_id = str(data.get("mission_id", mission_id))
	category = str(data.get("category", category))
	required = bool(data.get("required", required))
	priority = int(data.get("priority", priority))
	rewards = data.get("rewards", {}).duplicate(true)
	notes_player = str(data.get("notes_player", notes_player))
	completed_at_beat = str(data.get("completed_at_beat", completed_at_beat))
	failed_at_beat = str(data.get("failed_at_beat", failed_at_beat))
	complete_when.clear()
	for c in data.get("complete_when", []):
		if typeof(c) == TYPE_DICTIONARY:
			complete_when.append(c)
	fail_when.clear()
	for c in data.get("fail_when", []):
		if typeof(c) == TYPE_DICTIONARY:
			fail_when.append(c)
	reveals_when.clear()
	for c in data.get("reveals_when", []):
		if typeof(c) == TYPE_DICTIONARY:
			reveals_when.append(c)
	related_evidence.clear()
	for e in data.get("related_evidence", []):
		related_evidence.append(str(e))
	related_characters.clear()
	for c in data.get("related_characters", []):
		related_characters.append(str(c))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"status": status,
		"mission_id": mission_id,
		"category": category,
		"required": required,
		"priority": priority,
		"complete_when": complete_when.duplicate(true),
		"fail_when": fail_when.duplicate(true),
		"reveals_when": reveals_when.duplicate(true),
		"rewards": rewards.duplicate(true),
		"related_evidence": related_evidence.duplicate(),
		"related_characters": related_characters.duplicate(),
		"notes_player": notes_player,
		"completed_at_beat": completed_at_beat,
		"failed_at_beat": failed_at_beat,
	}


func is_terminal() -> bool:
	return status in [STATUS_COMPLETE, STATUS_FAILED, STATUS_ABANDONED]


func is_trackable() -> bool:
	return status in [STATUS_ACTIVE, STATUS_OPTIONAL]
