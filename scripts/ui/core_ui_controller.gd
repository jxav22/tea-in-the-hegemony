class_name CoreUIController
extends RefCounted
## Binds GameHUD to shipped Core APIs (DialogueRunner, GameState, CharacterRegistry,
## RelationshipQuery, CoverAPI) without rewriting the dialogue engine.

var hud: GameHUD
var registry := CharacterRegistry.new()
var _pending_choices: Array = []
var _awaiting_advance: bool = false


func bind(hud_ref: GameHUD) -> void:
	hud = hud_ref
	registry.reload()
	hud.choice_made.connect(_on_choice_made)
	hud.advance_line.connect(_on_advance)
	hud.save_slot.connect(_on_save)
	hud.load_slot.connect(_on_load)
	hud.delete_slot.connect(_on_delete)
	hud.restart_chapter.connect(_on_restart)
	_connect_core()
	refresh_objectives()
	refresh_cover()
	refresh_save_summaries()
	sync_background(String(GameState.current_location))


func _connect_core() -> void:
	if not DialogueRunner.node_presented.is_connected(_on_node_presented):
		DialogueRunner.node_presented.connect(_on_node_presented)
	if not DialogueRunner.choices_available.is_connected(_on_choices_available):
		DialogueRunner.choices_available.connect(_on_choices_available)
	if not DialogueRunner.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueRunner.dialogue_ended.connect(_on_dialogue_ended)
	if not FacultyBus.faculty_spoke.is_connected(_on_faculty):
		FacultyBus.faculty_spoke.connect(_on_faculty)
	if not FacultyBus.faculty_cleared.is_connected(_on_faculty_cleared):
		FacultyBus.faculty_cleared.connect(_on_faculty_cleared)
	if not SceneRouter.location_changed.is_connected(_on_location_changed):
		SceneRouter.location_changed.connect(_on_location_changed)
	if not GameState.objective_changed.is_connected(_on_objective_changed):
		GameState.objective_changed.connect(_on_objective_changed)
	if not GameState.cover_changed.is_connected(_on_cover_changed):
		GameState.cover_changed.connect(_on_cover_changed)


func _on_node_presented(node: Dictionary) -> void:
	_awaiting_advance = false
	_pending_choices.clear()
	var speaker_id := str(node.get("speaker", ""))
	var display := display_speaker(speaker_id)
	var text := str(node.get("text", ""))
	var expression := str(node.get("expression", "neutral"))
	if expression.is_empty():
		expression = "neutral"
	var portrait_id := _portrait_id_for(speaker_id)
	hud.present_line(portrait_id, display if not display.is_empty() else "—", text, expression)
	refresh_objectives()
	refresh_cover()


func _on_choices_available(choices: Array) -> void:
	_pending_choices = choices.duplicate(true)
	if choices.is_empty():
		_awaiting_advance = true
		return
	_awaiting_advance = false
	hud.present_choices(choices)


func _on_dialogue_ended(_graph_id: StringName, _reason: String) -> void:
	hud.choice_list.hide_choices()
	hud.hide_faculty()
	refresh_objectives()
	refresh_cover()


func _on_faculty(faculty: StringName, text: String, _weight: float, _node_id: StringName) -> void:
	hud.present_faculty(String(faculty), text)
	if hud.history:
		hud.history.add_line(String(faculty), text, ["faculty"])


func _on_faculty_cleared() -> void:
	hud.hide_faculty()


func _on_location_changed(location_id: StringName, _previous: StringName) -> void:
	sync_background(String(location_id))
	refresh_objectives()
	refresh_cover()


func _on_objective_changed(_objective_id: StringName, _status: String) -> void:
	refresh_objectives()


func _on_cover_changed(_state: Dictionary) -> void:
	refresh_cover()


func _on_choice_made(choice_id: String) -> void:
	var label := choice_id
	var intent := ""
	for ch in _pending_choices:
		if typeof(ch) == TYPE_DICTIONARY and str(ch.get("id", "")) == choice_id:
			label = str(ch.get("text", choice_id))
			intent = str(ch.get("intent", ""))
			break
	hud.log_player_choice(label, intent)
	DialogueRunner.choose(choice_id)


func _on_advance() -> void:
	if DialogueRunner.is_active:
		if not DialogueRunner.get_visible_choices().is_empty():
			return
		DialogueRunner.advance()


func _on_save(slot: int) -> void:
	SaveService.save_game(slot + 1)
	refresh_save_summaries()


func _on_load(slot: int) -> void:
	if SaveService.load_game(slot + 1):
		registry.reload()
		refresh_objectives()
		refresh_cover()
		refresh_save_summaries()
		sync_background(String(GameState.current_location))
		var loc := String(GameState.current_location)
		var graph := "reception_%s" % loc
		if not DialogueRunner.start(graph):
			DialogueRunner.start("briefing")


func _on_delete(slot: int) -> void:
	var path := SaveService.get_slot_path(slot + 1)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	refresh_save_summaries()


func _on_restart() -> void:
	GameState.reset_to_new_game()
	registry.reload()
	refresh_objectives()
	refresh_cover()
	sync_background("briefing")
	DialogueRunner.start("briefing")


func refresh_objectives() -> void:
	var items: Array = []
	if GameState.systems != null:
		var mission: Dictionary = GameState.systems.present_mission(false)
		for o in mission.get("objectives", []):
			if typeof(o) != TYPE_DICTIONARY:
				continue
			var od: Dictionary = o
			items.append({
				"id": str(od.get("id", "")),
				"text": str(od.get("title", od.get("description", od.get("id", "")))),
				"status": str(od.get("status", "active")),
			})
	if items.is_empty():
		for key in GameState.objectives.keys():
			var o: Dictionary = GameState.objectives[key]
			items.append({
				"id": str(o.get("id", key)),
				"text": str(o.get("label", o.get("id", key))),
				"status": str(o.get("status", "active")),
			})
	hud.set_objectives(items)


func refresh_cover() -> void:
	if hud == null or hud.mission_panel == null:
		return
	var presented := CoverAPI.present(false)
	hud.mission_panel.set_cover_present(presented)


func refresh_save_summaries() -> void:
	var summaries: Array = []
	for i in range(1, SaveService.MAX_SLOTS + 1):
		if SaveService.slot_exists(i):
			var meta := SaveService.peek_slot(i)
			summaries.append({
				"exists": true,
				"chapter_id": str(meta.get("chapter_id", "")),
				"label": "%s · %s" % [str(meta.get("current_location", "")), str(meta.get("timestamp", ""))],
			})
		else:
			summaries.append({"empty": true})
	hud.set_save_summaries(summaries)


func open_notebook_from_state() -> void:
	var fragments: Array = []
	if GameState.systems != null:
		for e in GameState.systems.present_evidence(false):
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var ed: Dictionary = e
			fragments.append({
				"id": str(ed.get("id", "")),
				"title": str(ed.get("title", ed.get("id", ""))),
				"summary": str(ed.get("summary", "")),
				"claims": ed.get("claims", []),
				"contradicts": [],
				"verified": bool(ed.get("verified", false)),
				"source": str(ed.get("source", "")),
				"verification_label": str(ed.get("verification_label", "")),
			})
	if fragments.is_empty():
		for entry in GameState.inventory:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = entry
			var fid := str(e.get("id", ""))
			fragments.append({
				"id": fid,
				"title": str(e.get("title", e.get("id", "fragment"))),
				"summary": str(e.get("summary", e.get("label", ""))),
				"claims": e.get("claims", []),
				"contradicts": e.get("contradicts", []),
				"verified": CoverAPI.has_evidence(StringName(fid)) or bool(e.get("verified", false)),
			})
	# Cover attention as soft intel note
	var cover := CoverAPI.present(false)
	var attention := str(cover.get("attention_line", ""))
	if not attention.is_empty():
		fragments.append({
			"id": "cover_attention",
			"title": "Room temperature",
			"summary": attention,
			"claims": [str(cover.get("heat_label", ""))],
			"contradicts": [],
			"verified": false,
		})
	hud.open_notebook(fragments)


func open_profile(char_id: String) -> void:
	var sid := StringName(char_id)
	var def := registry.get_character(sid)
	var presented := RelationshipQuery.present(sid, false)
	var rel := RelationshipQuery.snapshot(sid)
	var affinity := RelationshipQuery.score_affinity(sid)
	var hostile := RelationshipQuery.is_hostile(sid)
	var flags: Array = []
	var mood := str(presented.get("mood_line", ""))
	if not mood.is_empty():
		flags.append(mood)
	for hint in presented.get("knowledge_hints", []):
		flags.append(str(hint).replace("_", " "))
	if FlagStore.get_flag(StringName("met_%s" % char_id), false):
		flags.append("Met in person")
	if hostile:
		flags.append("Reading: wary of you")
	# Prefer qualitative bands for the dimension rows when Systems is live
	var band_rels: Dictionary = {}
	var dims: Dictionary = presented.get("dimensions", {})
	if not dims.is_empty():
		for dim_key in dims.keys():
			var entry: Dictionary = dims[dim_key]
			# Encode band as a small int for the existing bar UI fallback
			var band := str(entry.get("band", "neutral"))
			band_rels[str(dim_key)] = _band_to_tick(band)
			flags.append("%s: %s" % [str(entry.get("label", dim_key)), str(entry.get("band_label", band))])
	var mems: Array = presented.get("notable_memories", [])
	if mems.is_empty():
		mems = RelationshipQuery.memories_tagged(char_id)
	var portrait_key := str(def.get("portrait_key", char_id))
	hud.open_profile({
		"id": portrait_key,
		"display_name": registry.display_name(sid),
		"role": str(def.get("role", "")),
		"expression": "suspicious" if hostile else "neutral",
		"rels": band_rels if not band_rels.is_empty() else rel,
		"knowledge_flags": flags,
		"memories": mems,
		"affinity": affinity,
		"mood_line": mood,
		"qualitative": not dims.is_empty(),
	})


func _band_to_tick(band: String) -> int:
	match band:
		"hostile":
			return -5
		"cold":
			return -2
		"neutral":
			return 0
		"warm":
			return 2
		"close":
			return 4
		"intimate":
			return 5
		_:
			return 0


func sync_background(location_id: String, animate: bool = true) -> void:
	var loc := location_id
	if loc == "study":
		loc = "study_annex"
	if loc.is_empty():
		loc = "foyer"
	hud.set_background(loc, animate)


func display_speaker(id: String) -> String:
	if id.is_empty() or id == "narrator":
		return ""
	var name := registry.display_name(StringName(id))
	if name != id:
		return name
	match id:
		"cassian_vale", "cassian_orth":
			return "Cassian Vale"
		_:
			return id.replace("_", " ").capitalize()


func _portrait_id_for(speaker_id: String) -> String:
	if speaker_id.is_empty() or speaker_id == "narrator":
		return "cassian_vale"
	var def := registry.get_character(StringName(speaker_id))
	var key := str(def.get("portrait_key", speaker_id))
	return key if not key.is_empty() else speaker_id


func list_dossier_ids() -> PackedStringArray:
	return registry.all_ids()
