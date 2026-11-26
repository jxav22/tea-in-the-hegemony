extends CanvasLayer
class_name GameHUD
## Root presentation shell. Core drives it via public API; does not own dialogue logic.

signal choice_made(choice_id: String)
signal advance_line
signal save_slot(slot: int)
signal load_slot(slot: int)
signal delete_slot(slot: int)
signal restart_chapter
signal pause_changed(paused: bool)
signal notebook_requested
signal profile_requested(character_id: String)
signal room_transition_done(location_id: String)

@onready var root: Control = %Root
@onready var room_transition: RoomTransition = %RoomTransition
@onready var location_banner: LocationBanner = %LocationBanner
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var choice_list: ChoiceList = %ChoiceList
@onready var faculty_stack: FacultyStack = %FacultyStack
@onready var mission_panel: MissionPanel = %MissionPanel
@onready var history_view: DialogueHistoryView = %HistoryView
@onready var notebook: IntelNotebook = %IntelNotebook
@onready var profile: CharacterProfile = %CharacterProfile
@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var save_load: SaveLoadMenu = %SaveLoadMenu
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var hotkey_bar: Label = %HotkeyBar
@onready var letterbox_top: ColorRect = %LetterboxTop
@onready var letterbox_bottom: ColorRect = %LetterboxBottom

## Back-compat alias for scripts that still expect faculty_panel
var faculty_panel: FacultyStack:
	get:
		return faculty_stack

var settings := UISettings.new()
var history := DialogueHistoryModel.new()
var _paused: bool = false
var _slot_summaries: Array = []
var _bg_seeded: bool = false


func _ready() -> void:
	layer = 20
	settings.load_from_disk()
	root.theme = HegemonyThemeFactory.build()
	_apply_scale()
	dialogue_box.bind(settings, history)
	choice_list.bind(settings)
	history_view.bind(history)
	settings_menu.bind(settings)
	if faculty_stack:
		faculty_stack.reduce_motion = settings.reduce_motion
	if room_transition:
		room_transition.reduce_motion = settings.reduce_motion
		room_transition.transition_finished.connect(_on_room_done)
	hotkey_bar.text = "H history · N notebook · Esc menu · Space advance · 1–9 choices"

	dialogue_box.advance_requested.connect(func (): advance_line.emit())
	choice_list.choice_selected.connect(_on_choice)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.open_settings.connect(func (): settings_menu.open())
	pause_menu.open_save.connect(func (): save_load.open_save(_slot_summaries))
	pause_menu.open_load.connect(func (): save_load.open_load(_slot_summaries))
	pause_menu.open_notebook.connect(func (): notebook_requested.emit())
	pause_menu.open_history.connect(func (): history_view.open())
	pause_menu.restart_requested.connect(func (): restart_chapter.emit())
	notebook_requested.connect(func (): notebook.open_with([]))
	settings_menu.restart_requested.connect(func (): restart_chapter.emit())
	settings.changed.connect(_on_settings_changed)
	save_load.save_requested.connect(func (s): save_slot.emit(s))
	save_load.load_requested.connect(func (s): load_slot.emit(s))
	save_load.delete_requested.connect(func (s): delete_slot.emit(s))

	# Overlays above gameplay chrome
	history_view.z_index = 40
	notebook.z_index = 40
	profile.z_index = 40
	settings_menu.z_index = 50
	save_load.z_index = 50
	pause_menu.z_index = 60

	_set_letterbox(false)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func _on_settings_changed() -> void:
	_apply_scale()
	if faculty_stack:
		faculty_stack.reduce_motion = settings.reduce_motion
	if room_transition:
		room_transition.reduce_motion = settings.reduce_motion


func _on_viewport_resized() -> void:
	var vs := get_viewport().get_visible_rect().size
	if dialogue_box:
		dialogue_box.offset_top = -ResponsiveLayout.dialogue_height(vs)
	if mission_panel:
		mission_panel.offset_right = mission_panel.offset_left + ResponsiveLayout.mission_width(vs)


func set_background(location_id: String, animate: bool = true) -> void:
	if room_transition == null:
		return
	var display := location_id.replace("_", " ")
	var info: Dictionary = SceneRouter.get_location(StringName(location_id))
	if not info.is_empty():
		display = str(info.get("display_name", display))
	if not _bg_seeded or not animate:
		room_transition.set_location_immediate(location_id)
		_bg_seeded = true
		return
	if location_banner:
		location_banner.announce(location_id, display, settings.reduce_motion if settings else false)
	room_transition.transition_to(location_id)


func _on_room_done() -> void:
	room_transition_done.emit(room_transition.current_location())


func present_line(speaker_id: String, speaker_display: String, text: String, expression: String = "neutral") -> void:
	choice_list.hide_choices()
	dialogue_box.show_line(speaker_id, speaker_display, text, expression)


func present_choices(choices: Array) -> void:
	choice_list.present(choices)


func present_faculty(faculty: String, text: String) -> void:
	if settings and not settings.show_faculty_panels:
		return
	if faculty_stack:
		faculty_stack.reduce_motion = settings.reduce_motion if settings else false
		faculty_stack.show_interjection(faculty, text)


func hide_faculty() -> void:
	if faculty_stack:
		faculty_stack.reduce_motion = settings.reduce_motion if settings else false
		faculty_stack.clear_all(true)


func set_objectives(objectives: Array) -> void:
	mission_panel.set_objectives(objectives)


func open_notebook(fragments: Array) -> void:
	notebook.open_with(fragments)


func open_profile(data: Dictionary) -> void:
	profile.open_profile(data)


func set_save_summaries(summaries: Array) -> void:
	_slot_summaries = summaries.duplicate(true)


func set_cinematic(enabled: bool) -> void:
	_set_letterbox(enabled)
	mission_panel.visible = not enabled
	hotkey_bar.visible = not enabled


func _on_choice(choice_id: String) -> void:
	choice_list.hide_choices()
	choice_made.emit(choice_id)


func log_player_choice(text: String, intent: String = "") -> void:
	history.add_choice(text, intent)


func _toggle_pause() -> void:
	if _paused:
		_resume()
	else:
		_pause()


func _pause() -> void:
	_paused = true
	pause_menu.open()
	pause_changed.emit(true)


func _resume() -> void:
	_paused = false
	pause_menu.close()
	settings_menu.close()
	save_load.close()
	pause_changed.emit(false)


func _apply_scale() -> void:
	if root and settings:
		root.scale = Vector2(settings.ui_scale, settings.ui_scale)
		root.pivot_offset = Vector2.ZERO


func _set_letterbox(on: bool) -> void:
	letterbox_top.visible = on
	letterbox_bottom.visible = on


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if notebook.visible or profile.visible or history_view.visible:
					return
				if settings_menu.visible or save_load.visible:
					return
				_toggle_pause()
				get_viewport().set_input_as_handled()
			KEY_H:
				if not _overlay_blocking():
					history_view.toggle()
					get_viewport().set_input_as_handled()
			KEY_N:
				if not _overlay_blocking():
					notebook_requested.emit()
					get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ENTER:
				if not _paused and not choice_list.visible and dialogue_box.visible:
					dialogue_box.request_advance()
					get_viewport().set_input_as_handled()


func _overlay_blocking() -> bool:
	return _paused or settings_menu.visible or save_load.visible or profile.visible
