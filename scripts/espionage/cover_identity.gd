class_name CoverIdentity
extends RefCounted
## Cover identity state + inconsistency tracking for Cassian Orth (and swaps).

var cover_id: String = "cassian_orth"
var legal_name: String = "Cassian Vale"
var cover_name: String = "Cassian Orth"
var cover_role: String = "logistics analyst, Ministry Trade Liaison"
var employer: String = "Ministry Trade Liaison Office"
var backstory_beats: Array[String] = []
## Claims the player has made aloud; contradictions raise heat.
var stated_facts: Dictionary = {} ## key -> {value, beat, witnesses:[]}
var inconsistencies: Array[Dictionary] = []
var heat: int = 0 ## attention / cover stress 0..100
var blown: bool = false
var active: bool = true


func _init(data: Dictionary = {}) -> void:
	if not data.is_empty():
		from_dict(data)


func from_dict(data: Dictionary) -> void:
	cover_id = str(data.get("cover_id", cover_id))
	legal_name = str(data.get("legal_name", legal_name))
	cover_name = str(data.get("cover_name", cover_name))
	cover_role = str(data.get("cover_role", cover_role))
	employer = str(data.get("employer", employer))
	heat = clampi(int(data.get("heat", heat)), 0, 100)
	blown = bool(data.get("blown", blown))
	active = bool(data.get("active", active))
	backstory_beats.clear()
	for b in data.get("backstory_beats", []):
		backstory_beats.append(str(b))
	stated_facts = data.get("stated_facts", {}).duplicate(true)
	inconsistencies.clear()
	for inc in data.get("inconsistencies", []):
		inconsistencies.append(inc)


func to_dict() -> Dictionary:
	return {
		"cover_id": cover_id,
		"legal_name": legal_name,
		"cover_name": cover_name,
		"cover_role": cover_role,
		"employer": employer,
		"backstory_beats": backstory_beats.duplicate(),
		"stated_facts": stated_facts.duplicate(true),
		"inconsistencies": inconsistencies.duplicate(true),
		"heat": heat,
		"blown": blown,
		"active": active,
	}


func heat_band() -> String:
	if blown:
		return "blown"
	if heat >= 80:
		return "critical"
	if heat >= 55:
		return "high"
	if heat >= 30:
		return "elevated"
	if heat >= 10:
		return "low"
	return "clear"


static func default_cassian_orth() -> CoverIdentity:
	return CoverIdentity.new({
		"cover_id": "cassian_orth",
		"legal_name": "Cassian Vale",
		"cover_name": "Cassian Orth",
		"cover_role": "logistics analyst, Ministry Trade Liaison",
		"employer": "Ministry Trade Liaison Office",
		"backstory_beats": [
			"Transferred from eastern corridor logistics last quarter",
			"Here to observe shipping courtesy protocols",
			"Does not drink on duty — claims medical",
		],
		"heat": 0,
		"blown": false,
		"active": true,
	})
