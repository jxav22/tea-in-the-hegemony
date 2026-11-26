class_name CoreUIController
extends RefCounted
## Binds GameHUD to Core autoloads without rewriting DialogueRunner.

var hud: GameHUD
var _pending_choices: Array = []
var _awaiting_advance: bool = false


func bind(hud_ref: GameHUD) -> void:
	hud = hud_ref
	hud.choice_made.connect(_on_choice_made)
	hud.advance_line.connect(_on_advance)
	hud.save_slot.connect(_on_save)
	hud.load_slot.connect(_on_load)
	hud.delete_slot.connect(_on_delete)
	hud.restart_chapter.connect(_on_restart)
	_connect_core()
	refresh_objectives()
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


func _on_node_presented(node: Dictionary) -> void:
	_awaiting_advance = false
	_pending_choices.clear()
	var speaker_id := str(node.get("speaker", ""))
	var display := display_speaker(speaker_id)
	var text := str(node.get("text", ""))
	var expression := str(node.get("expression", "neutral"))
	if expression.is_empty():
		expression = "neutral"
	hud.present_line(speaker_id, display if not display.is_empty() else "—", text, expression)
	refresh_objectives()


func _on_choices_available(choices: Array) -> void:
	_pending_choices = choices.duplicate(true)
	if choices.is_empty():
		_awaiting_advance = true
		# Continue cue lives on DialogueBox; advance_line → DialogueRunner.advance()
		return
	_awaiting_advance = false
	hud.present_choices(choices)


func _on_dialogue_ended(_graph_id: StringName, _reason: String) -> void:
	hud.choice_list.hide_choices()
	hud.hide_faculty()
	refresh_objectives()


func _on_faculty(faculty: StringName, text: String, _weight: float, _node_id: StringName) -> void:
	hud.present_faculty(String(faculty), text)
	if hud.history:
		hud.history.add_line(String(faculty), text, ["faculty"])


func _on_faculty_cleared() -> void:
	hud.hide_faculty()


func _on_location_changed(location_id: StringName, _previous: StringName) -> void:
	sync_background(String(location_id))
	refresh_objectives()


func _on_objective_changed(_objective_id: StringName, _status: String) -> void:
	refresh_objectives()


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
	# UI uses 0-based; SaveService uses 1-based
	SaveService.save_game(slot + 1)
	refresh_save_summaries()


func _on_load(slot: int) -> void:
	if SaveService.load_game(slot + 1):
		refresh_objectives()
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
	refresh_objectives()
	sync_background("briefing")
	DialogueRunner.start("briefing")


func refresh_objectives() -> void:
	var items: Array = []
	for key in GameState.objectives.keys():
		var o: Dictionary = GameState.objectives[key]
		items.append({
			"id": str(o.get("id", key)),
			"text": str(o.get("label", o.get("id", key))),
			"status": str(o.get("status", "active")),
		})
	hud.set_objectives(items)


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
	for entry in GameState.inventory:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		fragments.append({
			"id": str(e.get("id", "")),
			"title": str(e.get("title", e.get("id", "fragment"))),
			"summary": str(e.get("summary", e.get("label", ""))),
			"claims": e.get("claims", []),
			"contradicts": e.get("contradicts", []),
			"verified": bool(e.get("verified", false)),
		})
	# Memories as soft intel
	for m in GameState.memories:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var mem: Dictionary = m
		fragments.append({
			"id": str(mem.get("id", "")),
			"title": "Memory",
			"summary": str(mem.get("summary", "")),
			"claims": [],
			"contradicts": [],
			"verified": true,
		})
	hud.open_notebook(fragments)


func open_profile(char_id: String) -> void:
	var def := ContentIndex.load_character(char_id)
	var rel := GameState.ensure_relationship(StringName(char_id))
	var flags: Array = []
	if FlagStore.get_flag(StringName("met_%s" % char_id), false):
		flags.append("Met in person")
	for key in FlagStore.to_dict().keys():
		var ks := str(key)
		if ks.begins_with(char_id) or ks.find(char_id) >= 0:
			flags.append(ks)
	var mems: Array = []
	for m in GameState.memories:
		if typeof(m) == TYPE_DICTIONARY:
			var tags: Array = m.get("tags", [])
			if char_id in tags or tags.is_empty():
				mems.append(m)
	hud.open_profile({
		"id": char_id,
		"display_name": str(def.get("display_name", display_speaker(char_id))),
		"role": str(def.get("role", "")),
		"expression": "neutral",
		"rels": rel,
		"knowledge_flags": flags,
		"memories": mems,
	})


func sync_background(location_id: String) -> void:
	var loc := location_id
	if loc == "study":
		loc = "study_annex"
	if loc.is_empty():
		loc = "foyer"
	hud.set_background(loc)


static func display_speaker(id: String) -> String:
	var def := ContentIndex.load_character(id)
	if not def.is_empty():
		return str(def.get("display_name", id))
	match id:
		"narrator", "":
			return ""
		"cassian_vale", "cassian_orth":
			return "Cassian Vale"
		_:
			return id.replace("_", " ").capitalize()
