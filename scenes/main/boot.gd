extends Control
## Minimal boot / title → briefing → reception loop.
## Agent D may restyle; keep node names and signal wiring stable if possible.

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _status: Label = %StatusLabel
@onready var _speaker: Label = %SpeakerLabel
@onready var _body: RichTextLabel = %BodyLabel
@onready var _faculty: RichTextLabel = %FacultyLabel
@onready var _choices: VBoxContainer = %ChoicesBox
@onready var _nav: HBoxContainer = %NavBox
@onready var _hud: Label = %HudLabel
@onready var _menu: VBoxContainer = %MenuBox


func _ready() -> void:
	_title.text = "Tea in the Hegemony"
	_subtitle.text = "The Reception"
	_connect_runner()
	_show_menu()
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		# Auto-smoke in headless: run briefing choice path then quit.
		call_deferred("_headless_smoke")


func _connect_runner() -> void:
	if not DialogueRunner.dialogue_started.is_connected(_on_dialogue_started):
		DialogueRunner.dialogue_started.connect(_on_dialogue_started)
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


func _show_menu() -> void:
	_menu.visible = true
	_speaker.text = ""
	_body.text = "A narrative social-espionage RPG.\nCassian Vale under cover as Cassian Orth."
	_faculty.text = ""
	_clear_choices()
	_status.text = "Ready"
	_refresh_hud()
	_build_menu_buttons()


func _build_menu_buttons() -> void:
	for c: Node in _menu.get_children():
		c.queue_free()
	_add_menu_btn("New Game — Briefing", _start_new)
	_add_menu_btn("Continue to Reception Hub", _goto_hub)
	_add_menu_btn("Quick Save", func() -> void: SaveService.quick_save(); _status.text = "Saved slot 1")
	_add_menu_btn("Quick Load", func() -> void:
		if SaveService.quick_load():
			_status.text = "Loaded slot 1"
			_refresh_hud()
			_start_location_dialogue()
		else:
			_status.text = "No save in slot 1"
	)
	_add_menu_btn("Debrief", func() -> void: _menu.visible = false; DialogueRunner.start("debrief"))


func _add_menu_btn(label: String, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = label
	b.pressed.connect(cb)
	_menu.add_child(b)


func _start_new() -> void:
	GameState.reset_to_new_game()
	_menu.visible = false
	_status.text = "The Reception"
	# Prefer merged Agent B chapter; fall back to stub briefing pack.
	if not DialogueRunner.start_reception():
		DialogueRunner.start("briefing")
	_refresh_hud()


func _goto_hub() -> void:
	_menu.visible = false
	SceneRouter.goto_reception_hub()


func _start_location_dialogue() -> void:
	_menu.visible = false
	var loc: StringName = GameState.current_location
	var mapping: Dictionary = SceneRouter.dialogue_for(loc)
	var start_node: String = str(mapping.get("start_node", ""))
	# Prefer jumping into the merged chapter at the room's start node.
	if DialogueRunner.start_reception(start_node if not start_node.is_empty() else ""):
		return
	var graph: String = str(mapping.get("graph_id", "foyer"))
	if not DialogueRunner.start(graph, start_node):
		if not DialogueRunner.start("reception_%s" % String(loc)):
			_status.text = "No dialogue for %s" % String(loc)
			_show_menu()


func _on_dialogue_started(graph_id: StringName) -> void:
	_status.text = "Dialogue: %s" % String(graph_id)
	_menu.visible = false


func _on_node_presented(node: Dictionary) -> void:
	var speaker: String = str(node.get("speaker", ""))
	_speaker.text = _display_speaker(speaker)
	_body.text = str(node.get("text", ""))
	_refresh_hud()


func _on_choices_available(choices: Array) -> void:
	_clear_choices()
	if choices.is_empty():
		var cont: Button = Button.new()
		cont.text = "Continue"
		cont.pressed.connect(func() -> void: DialogueRunner.advance())
		_choices.add_child(cont)
		return
	for ch: Variant in choices:
		var choice: Dictionary = ch as Dictionary
		var b: Button = Button.new()
		var intent: String = str(choice.get("intent", ""))
		var label: String = str(choice.get("text", ""))
		if not intent.is_empty():
			b.text = "%s  [%s]" % [label, intent]
		else:
			b.text = label
		var cid: String = str(choice.get("id", ""))
		b.pressed.connect(_make_choose(cid))
		_choices.add_child(b)


func _make_choose(choice_id: String) -> Callable:
	return func() -> void: DialogueRunner.choose(choice_id)


func _on_dialogue_ended(_graph_id: StringName, reason: String) -> void:
	_status.text = "Ended (%s)" % reason
	_clear_choices()
	_build_nav()
	_refresh_hud()


func _on_faculty(faculty: StringName, text: String, _weight: float, _node_id: StringName) -> void:
	_faculty.text += "[b]%s[/b]: %s\n" % [String(faculty), text]


func _on_faculty_cleared() -> void:
	_faculty.text = ""


func _on_location_changed(location_id: StringName, _previous: StringName) -> void:
	_status.text = "Location → %s" % String(location_id)
	_refresh_hud()
	# If dialogue just soft-set location, wait for it to end before starting room graph.
	if not DialogueRunner.is_active:
		call_deferred("_after_location", String(location_id))


func _after_location(loc: String) -> void:
	if DialogueRunner.is_active:
		return
	_build_nav()
	_status.text = "Arrived: %s — pick a destination or Talk" % loc


func _build_nav() -> void:
	for c: Node in _nav.get_children():
		c.queue_free()
	var loc: StringName = GameState.current_location
	var talk: Button = Button.new()
	talk.text = "Talk here"
	talk.pressed.connect(_start_location_dialogue)
	_nav.add_child(talk)
	for adj: String in SceneRouter.adjacent_for(loc):
		var b: Button = Button.new()
		var info: Dictionary = SceneRouter.get_location(StringName(adj))
		b.text = "Go: %s" % str(info.get("display_name", adj))
		var target: String = adj
		b.pressed.connect(func() -> void:
			SceneRouter.set_location(StringName(target), false)
			_start_location_dialogue()
		)
		_nav.add_child(b)
	var hub: Button = Button.new()
	hub.text = "Hub / Menu"
	hub.pressed.connect(_show_menu)
	_nav.add_child(hub)
	var deb: Button = Button.new()
	deb.text = "Debrief"
	deb.pressed.connect(func() -> void: DialogueRunner.start("debrief"))
	_nav.add_child(deb)
	var save_b: Button = Button.new()
	save_b.text = "Save"
	save_b.pressed.connect(func() -> void: SaveService.quick_save(); _status.text = "Saved")
	_nav.add_child(save_b)


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		c.queue_free()


func _refresh_hud() -> void:
	var heat: int = int(GameState.cover_state.get("heat", 0))
	_hud.text = "Loc: %s | Heat: %d | Beat: %d | Cover: %s" % [
		String(GameState.current_location),
		heat,
		GameState.beat_index,
		str(GameState.cover_state.get("name", "")),
	]


func _display_speaker(id: String) -> String:
	match id:
		"wren_halden":
			return "Wren Halden"
		"maris_quell":
			return "Maris Quell"
		"edrin_voss":
			return "Lord Edrin Voss"
		"taly_renn":
			return "Taly Renn"
		"sera_kade":
			return "Sera Kade"
		"pim_orel":
			return "Pim Orel"
		"clerk_moth":
			return "Clerk Moth"
		"narrator", "":
			return ""
		_:
			return id


func _headless_smoke() -> void:
	print("[smoke] headless start")
	GameState.reset_to_new_game()
	var started: bool = DialogueRunner.start_reception()
	if not started:
		started = DialogueRunner.start("briefing")
	assert(started)
	# Drive a few choices generically (works for stub or Agent B ids).
	var steps: int = 0
	while DialogueRunner.is_active and steps < 12:
		var choices: Array = DialogueRunner.get_visible_choices()
		if choices.is_empty():
			if not DialogueRunner.advance():
				break
		else:
			DialogueRunner.choose_index(0)
		steps += 1
	assert(SaveService.save_game(1))
	assert(SaveService.load_game(1))
	print("[smoke] OK — reception chapter steps=%d + save/load" % steps)
	get_tree().quit(0)
