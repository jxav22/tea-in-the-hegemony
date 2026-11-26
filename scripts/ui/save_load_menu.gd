extends Control
class_name SaveLoadMenu
## Slot-based save/load UI. Speaks to Core via signals (no engine rewrite).

signal closed
signal save_requested(slot: int)
signal load_requested(slot: int)
signal delete_requested(slot: int)

const SLOT_COUNT := 5

@onready var title: Label = %Title
@onready var slots: VBoxContainer = %Slots
@onready var close_btn: Button = %CloseBtn
@onready var mode_label: Label = %ModeLabel

var _mode: String = "save" # save | load
var _slot_meta: Array = []


func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close)


func open_save(slot_summaries: Array = []) -> void:
	_mode = "save"
	title.text = "Preserve Cover"
	mode_label.text = "Write a checkpoint. Versioned saves are Core-owned."
	_rebuild(slot_summaries)
	visible = true
	close_btn.grab_focus()


func open_load(slot_summaries: Array = []) -> void:
	_mode = "load"
	title.text = "Resume Operation"
	mode_label.text = "Load a checkpoint. Empty slots stay quiet."
	_rebuild(slot_summaries)
	visible = true
	close_btn.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _rebuild(summaries: Array) -> void:
	_slot_meta = summaries.duplicate(true)
	for child in slots.get_children():
		child.queue_free()
	for i in SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = _summary_text(i)
		var action := Button.new()
		action.text = "Save" if _mode == "save" else "Load"
		action.custom_minimum_size = Vector2(96, 40)
		var slot_i := i
		action.pressed.connect(func ():
			if _mode == "save":
				save_requested.emit(slot_i)
			else:
				load_requested.emit(slot_i)
		)
		row.add_child(info)
		row.add_child(action)
		if _mode == "save":
			var wipe := Button.new()
			wipe.text = "Clear"
			wipe.custom_minimum_size = Vector2(72, 40)
			wipe.pressed.connect(func (): delete_requested.emit(slot_i))
			row.add_child(wipe)
		slots.add_child(row)


func _summary_text(slot: int) -> String:
	if slot < _slot_meta.size() and typeof(_slot_meta[slot]) == TYPE_DICTIONARY:
		var s: Dictionary = _slot_meta[slot]
		if s.get("empty", false) or not s.get("exists", true):
			return "Slot %d — empty" % (slot + 1)
		return "Slot %d — %s · %s" % [
			slot + 1,
			str(s.get("chapter_id", "chapter")),
			str(s.get("label", s.get("timestamp", "saved"))),
		]
	return "Slot %d — empty" % (slot + 1)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
