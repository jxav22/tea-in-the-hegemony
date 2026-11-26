class_name SystemsBootstrap
extends RefCounted
## Factory helpers so Core can spin up Social + Espionage without owning these scripts.


static func create_default() -> SystemsBridge:
	var bridge := SystemsBridge.new()
	_seed_reception_characters(bridge)
	return bridge


static func create_with_reception_content(
	mission_path: String = "res://content/missions/reception.json",
	evidence_path: String = "res://content/evidence/reception_evidence.json"
) -> SystemsBridge:
	var bridge := create_default()
	bridge.load_reception_content(mission_path, evidence_path)
	return bridge


static func _seed_reception_characters(bridge: SystemsBridge) -> void:
	## Prefer Narrative character defs when present; fall back to embedded defaults.
	var loaded := _try_load_character_dir("res://content/characters")
	if loaded.size() > 0:
		bridge.relationships.seed_from_character_defs(loaded)
		return
	bridge.relationships.seed_from_character_defs(_embedded_reception_defaults())


static func _try_load_character_dir(dir_path: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full := dir_path.rstrip("/") + "/" + file_name
			var f: FileAccess = FileAccess.open(full, FileAccess.READ)
			if f != null:
				var parsed: Variant = JSON.parse_string(f.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("id", "")) != "":
					out.append(parsed)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


static func _embedded_reception_defaults() -> Array:
	## Aligned with Narrative branch character default_rel values (fallback if files absent).
	return [
		{
			"id": "maris_quell",
			"default_rel": {
				"trust": 10,
				"familiarity": 5,
				"suspicion": 15,
				"respect": 20,
				"affection": 0,
				"comfort": 10,
				"perceived_authenticity": 40,
			},
			"motivations": [
				"Advance Observatory Circle policy work without becoming anyone's trophy introduction",
				"Decide whether Cassian Orth is interesting or merely careful",
				"Keep Taly from performing an autopsy of every conversation",
			],
		},
		{
			"id": "wren_halden",
			"default_rel": {
				"trust": 60,
				"familiarity": 70,
				"suspicion": 5,
				"respect": 45,
				"affection": 15,
				"comfort": 30,
				"perceived_authenticity": 80,
			},
			"motivations": [
				"Extract the shipping-schedule discrepancy and guest-list cipher",
				"Keep Cassian's cover intact longer than his self-regard",
				"Deliver romantic advice with the bedside manner of a coroner",
			],
		},
		{
			"id": "edrin_voss",
			"default_rel": {
				"trust": 5,
				"familiarity": 0,
				"suspicion": 10,
				"respect": 0,
				"affection": 0,
				"comfort": 0,
				"perceived_authenticity": 30,
			},
			"motivations": [
				"Host a reception that looks effortless and is anything but",
				"Broker quiet influence via guest adjacency",
				"Keep the study annex's papers boring to everyone but the right people",
			],
		},
		{
			"id": "taly_renn",
			"default_rel": {
				"trust": 5,
				"familiarity": 0,
				"suspicion": 25,
				"respect": 10,
				"affection": 0,
				"comfort": 5,
				"perceived_authenticity": 35,
			},
			"motivations": [
				"Protect Maris from boring operators and interesting disasters",
				"Catalogue social tells for later entertainment",
				"Decide if Orth is a threat, a project, or both",
			],
		},
		{
			"id": "sera_kade",
			"default_rel": {
				"trust": 0,
				"familiarity": 20,
				"suspicion": 40,
				"respect": 35,
				"affection": 5,
				"comfort": 10,
				"perceived_authenticity": 25,
			},
			"motivations": [
				"Secure the discrepancy fragment before Cassian does",
				"Stay charming enough that nobody calls security",
				"Remind Cassian that competence without grace is just noise",
			],
		},
		{
			"id": "pim_orel",
			"default_rel": {
				"trust": 25,
				"familiarity": 40,
				"suspicion": 5,
				"respect": 10,
				"affection": 20,
				"comfort": 45,
				"perceived_authenticity": 70,
			},
			"motivations": [
				"Be useful by accident",
				"Survive the evening without being escorted out again",
				"Introduce people who should never meet",
			],
		},
		{
			"id": "clerk_moth",
			"default_rel": {
				"trust": 0,
				"familiarity": 0,
				"suspicion": 20,
				"respect": 0,
				"affection": 0,
				"comfort": 0,
				"perceived_authenticity": 15,
			},
			"motivations": [
				"Enforce reception protocol to the letter and then some",
				"Catch badge, alias, and seating inconsistencies",
				"Prove that paperwork is the real security apparatus",
			],
		},
	]
