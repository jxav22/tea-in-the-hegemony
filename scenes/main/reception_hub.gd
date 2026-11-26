extends Control
## Reception location hub — pick rooms, talk, save.
## Dedicated location scenes can replace this later; IDs stay stable.

@onready var _title: Label = %TitleLabel
@onready var _desc: Label = %DescLabel
@onready var _rooms: VBoxContainer = %RoomsBox
@onready var _actions: VBoxContainer = %ActionsBox
@onready var _hud: Label = %HudLabel
@onready var _log: RichTextLabel = %LogLabel


func _ready() -> void:
	_title.text = "The Reception"
	_rebuild()
	SceneRouter.location_changed.connect(func(_a: StringName, _b: StringName) -> void: _rebuild())


func _rebuild() -> void:
	var loc: Dictionary = SceneRouter.get_location(GameState.current_location)
	_desc.text = "%s — %s" % [
		str(loc.get("display_name", GameState.current_location)),
		str(loc.get("description", "")),
	]
	_hud.text = "Heat %d | Fragment %s | Met Maris %s" % [
		int(GameState.cover_state.get("heat", 0)),
		str(FlagStore.get_flag(&"got_fragment", false)),
		str(FlagStore.get_flag(&"met_maris", false)),
	]
	for c: Node in _rooms.get_children():
		c.queue_free()
	for id: String in SceneRouter.get_location_ids():
		var info: Dictionary = SceneRouter.get_location(StringName(id))
		var b: Button = Button.new()
		var here: bool = id == String(GameState.current_location)
		b.text = "%s%s" % [str(info.get("display_name", id)), " (here)" if here else ""]
		b.disabled = here
		var target: String = id
		b.pressed.connect(func() -> void:
			GameState.set_location(StringName(target))
			SceneRouter.current_location = StringName(target)
			_log.append_text("Moved to %s\n" % target)
			_rebuild()
		)
		_rooms.add_child(b)
	for c: Node in _actions.get_children():
		c.queue_free()
	_add_action("Talk here", _talk_here)
	_add_action("Save", func() -> void: SaveService.quick_save(); _log.append_text("Saved.\n"))
	_add_action("Load", func() -> void:
		if SaveService.quick_load():
			_log.append_text("Loaded.\n")
			_rebuild()
		else:
			_log.append_text("No save.\n")
	)
	_add_action("Debrief", func() -> void: SceneRouter.goto_boot(); call_deferred("_start_debrief"))
	_add_action("Title", func() -> void: SceneRouter.goto_boot())


func _add_action(label: String, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = label
	b.pressed.connect(cb)
	_actions.add_child(b)


func _talk_here() -> void:
	# Return to boot UI which hosts dialogue presentation.
	var loc: String = String(GameState.current_location)
	SceneRouter.goto_boot()
	# Boot will show menu; start dialogue after scene loads via meta flag.
	call_deferred("_deferred_talk", loc)


func _deferred_talk(loc: String) -> void:
	# Boot scene owns DialogueRunner UI; start after tree settles.
	await get_tree().process_frame
	await get_tree().process_frame
	var boot: Node = get_tree().current_scene
	if boot != null and boot.has_method("_start_location_dialogue"):
		GameState.set_location(StringName(loc))
		boot.call("_start_location_dialogue")
	else:
		DialogueRunner.start("reception_%s" % loc)


func _start_debrief() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	DialogueRunner.start("debrief")
