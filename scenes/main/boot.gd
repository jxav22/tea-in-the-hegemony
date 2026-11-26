extends Control
## Presentation-wired boot: title → briefing → reception via GameHUD.
## Keeps DialogueRunner / SaveService / headless smoke; restyles Core stub UI.

const GameHUDScene := preload("res://scenes/ui/game_hud.tscn")
const TitleScene := preload("res://scenes/ui/title_screen.tscn")

var _hud: GameHUD
var _title: TitleScreen
var _ui := CoreUIController.new()
var _nav_bar: HBoxContainer
var _status: Label
var _legacy: Control


func _ready() -> void:
	theme = HegemonyThemeFactory.build()
	_hide_legacy_chrome()
	_build_presentation()
	_ui.bind(_hud)
	_show_title()
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		call_deferred("_headless_smoke")


func _hide_legacy_chrome() -> void:
	# Keep unique-name nodes alive for any external refs; hide Core stub layout.
	for n in ["TitleLabel", "SubtitleLabel", "HudLabel", "StatusLabel", "SpeakerLabel",
			"BodyLabel", "FacultyLabel", "MenuBox", "ChoicesBox", "NavBox"]:
		var node := get_node_or_null("%" + n)
		if node:
			node.visible = false
	var bg := get_node_or_null("Background")
	if bg:
		bg.visible = false
	var margin := get_node_or_null("Margin")
	if margin:
		margin.visible = false
	_legacy = margin


func _build_presentation() -> void:
	_hud = GameHUDScene.instantiate() as GameHUD
	add_child(_hud)

	# Title above GameHUD CanvasLayer (layer 20) so it isn't buried
	var title_layer := CanvasLayer.new()
	title_layer.name = "TitleLayer"
	title_layer.layer = 30
	add_child(title_layer)
	_title = TitleScene.instantiate() as TitleScreen
	title_layer.add_child(_title)
	_title.start_requested.connect(_start_new)
	_title.continue_requested.connect(_continue_game)
	_title.preferences_requested.connect(func (): _hud.settings_menu.open())

	# Nav/status above room art but under modal overlays
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "PresOverlayLayer"
	overlay_layer.layer = 22
	add_child(overlay_layer)
	var overlay := Control.new()
	overlay.name = "PresentationOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(overlay)

	_status = Label.new()
	_status.name = "PresStatus"
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_left = 380
	_status.offset_top = 28
	_status.offset_right = -40
	_status.offset_bottom = 52
	_status.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
	_status.add_theme_font_size_override("font_size", 13)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_status)

	_nav_bar = HBoxContainer.new()
	_nav_bar.name = "PresNav"
	_nav_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_nav_bar.offset_left = -420
	_nav_bar.offset_top = -300
	_nav_bar.offset_right = 420
	_nav_bar.offset_bottom = -252
	_nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav_bar.add_theme_constant_override("separation", 8)
	overlay.add_child(_nav_bar)

	# Prefer live inventory/memories over empty notebook stub
	for c in _hud.notebook_requested.get_connections():
		_hud.notebook_requested.disconnect(c["callable"])
	_hud.notebook_requested.connect(func (): _ui.open_notebook_from_state())

	if not DialogueRunner.dialogue_started.is_connected(_on_dialogue_started):
		DialogueRunner.dialogue_started.connect(_on_dialogue_started)
	if not DialogueRunner.dialogue_ended.is_connected(_on_dialogue_ended_nav):
		DialogueRunner.dialogue_ended.connect(_on_dialogue_ended_nav)
	if not SceneRouter.location_changed.is_connected(_on_location_nav):
		SceneRouter.location_changed.connect(_on_location_nav)


func _show_title() -> void:
	_title.visible = true
	_nav_bar.visible = false
	_status.text = "Ready"
	_ui.refresh_objectives()
	_ui.sync_background("salon", false)


func _start_new() -> void:
	_title.visible = false
	GameState.reset_to_new_game()
	_status.text = "Briefing"
	_ui.sync_background("briefing", false)
	_ui.refresh_objectives()
	DialogueRunner.start("briefing")


func _continue_game() -> void:
	_title.visible = false
	if SaveService.slot_exists(1) and SaveService.load_game(1):
		_status.text = "Loaded slot 1"
		_ui.refresh_objectives()
		_ui.refresh_save_summaries()
		_ui.sync_background(String(GameState.current_location))
		_start_location_dialogue()
	else:
		_status.text = "No save — starting briefing"
		_start_new()


func _start_location_dialogue() -> void:
	var loc: String = String(GameState.current_location)
	var graph: String = "reception_%s" % loc
	if not DialogueRunner.start(graph):
		_status.text = "No dialogue for %s" % loc
		_build_nav()


func _on_dialogue_started(graph_id: StringName) -> void:
	_title.visible = false
	_status.text = "Dialogue: %s" % String(graph_id)
	_nav_bar.visible = false


func _on_dialogue_ended_nav(_graph_id: StringName, reason: String) -> void:
	_status.text = "Ended (%s)" % reason
	_build_nav()
	_ui.refresh_objectives()


func _on_location_nav(location_id: StringName, _previous: StringName) -> void:
	_status.text = "Location → %s" % String(location_id)
	if not DialogueRunner.is_active:
		call_deferred("_after_location", String(location_id))


func _after_location(loc: String) -> void:
	if DialogueRunner.is_active:
		return
	_build_nav()
	_status.text = "Arrived: %s" % loc


func _build_nav() -> void:
	for c: Node in _nav_bar.get_children():
		c.queue_free()
	_nav_bar.visible = true
	var loc: StringName = GameState.current_location
	for adj: String in SceneRouter.adjacent_for(loc):
		var b := Button.new()
		var info: Dictionary = SceneRouter.get_location(StringName(adj))
		b.text = str(info.get("display_name", adj))
		NavChrome.style_button(b, "nav")
		var target := adj
		b.pressed.connect(func () -> void:
			GameState.set_location(StringName(target))
			SceneRouter.current_location = StringName(target)
			_ui.sync_background(target)
			DialogueRunner.start("reception_%s" % target)
		)
		_nav_bar.add_child(b)
	var talk := Button.new()
	talk.text = "Talk"
	NavChrome.style_button(talk, "quiet")
	talk.pressed.connect(_start_location_dialogue)
	_nav_bar.add_child(talk)
	var dossier := Button.new()
	dossier.text = "Dossier"
	NavChrome.style_button(dossier, "nav")
	dossier.pressed.connect(_open_next_dossier)
	_nav_bar.add_child(dossier)
	var note := Button.new()
	note.text = "Notebook"
	NavChrome.style_button(note, "nav")
	note.pressed.connect(func (): _ui.open_notebook_from_state())
	_nav_bar.add_child(note)
	var deb := Button.new()
	deb.text = "Debrief"
	NavChrome.style_button(deb, "danger")
	deb.pressed.connect(func (): DialogueRunner.start("debrief"))
	_nav_bar.add_child(deb)
	var menu := Button.new()
	menu.text = "Menu"
	NavChrome.style_button(menu, "quiet")
	menu.pressed.connect(_show_title)
	_nav_bar.add_child(menu)


var _dossier_index: int = 0


func _open_next_dossier() -> void:
	var ids := _ui.list_dossier_ids()
	if ids.is_empty():
		_ui.open_profile("maris_quell")
		return
	_dossier_index = _dossier_index % ids.size()
	_ui.open_profile(ids[_dossier_index])
	_dossier_index += 1


func _headless_smoke() -> void:
	print("[smoke] headless start")
	GameState.reset_to_new_game()
	assert(DialogueRunner.start("briefing"))
	await _smoke_drive(24)
	assert(FlagStore.get_flag(&"briefed", false) == true)
	print("[smoke] briefing ok")
	GameState.set_location(&"foyer")
	SceneRouter.current_location = &"foyer"
	assert(DialogueRunner.start("reception_foyer"))
	await _smoke_drive(20)
	print("[smoke] foyer ok")
	assert(DialogueRunner.start("debrief"))
	await _smoke_drive(24)
	print("[smoke] debrief ok")
	assert(SaveService.save_game(1))
	assert(SaveService.load_game(1))
	assert(FlagStore.get_flag(&"briefed", false) == true)
	print("[smoke] OK — boot→Reception→debrief + save/load")
	get_tree().quit(0)


func _smoke_drive(max_steps: int) -> void:
	var guard: int = 0
	while DialogueRunner.is_active and guard < max_steps:
		await get_tree().process_frame
		if not DialogueRunner.is_active:
			break
		var choices: Array = DialogueRunner.get_visible_choices()
		if choices.is_empty():
			if not DialogueRunner.advance():
				break
		else:
			DialogueRunner.choose_index(0)
		guard += 1
