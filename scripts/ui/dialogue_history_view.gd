extends Control
class_name DialogueHistoryView
## Overlay log of spoken lines / choices / faculty asides.

@onready var rich: RichTextLabel = %HistoryText
@onready var title: Label = %Title

var history: DialogueHistoryModel


func _ready() -> void:
	visible = false
	title.text = "Conversation Log"
	if rich:
		rich.bbcode_enabled = true
		rich.scroll_following = true


func bind(history_ref: DialogueHistoryModel) -> void:
	history = history_ref
	if history and not history.entry_added.is_connected(_on_entry):
		history.entry_added.connect(_on_entry)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	_refresh()
	rich.grab_focus()


func close() -> void:
	visible = false


func _on_entry(_entry: Dictionary) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if history:
		rich.text = history.as_richtext()
	else:
		rich.text = "[i]No lines recorded.[/i]"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_H):
		close()
		get_viewport().set_input_as_handled()
