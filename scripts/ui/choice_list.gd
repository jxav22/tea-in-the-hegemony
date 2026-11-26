extends Control
class_name ChoiceList
## Vertical list of choices with keyboard/mouse navigation and intent chips.

signal choice_selected(choice_id: String)

@onready var list: VBoxContainer = %List
@onready var hint: Label = %Hint

var settings: UISettings
var _buttons: Array[ChoiceIntentButton] = []
var _index: int = 0


func _ready() -> void:
	visible = false
	hint.text = "↑↓ / mouse · Enter confirm · Esc open menu"


func bind(settings_ref: UISettings) -> void:
	settings = settings_ref


func present(choices: Array) -> void:
	_clear()
	visible = true
	var show_intent := true if settings == null else settings.show_intent_previews
	for c in choices:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var btn := ChoiceIntentButton.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := str(c.get("id", ""))
		var label := str(c.get("text", c.get("label", "…")))
		var intent := str(c.get("intent", ""))
		btn.setup(id, label, intent, show_intent)
		btn.choice_activated.connect(_on_choice)
		list.add_child(btn)
		_buttons.append(btn)
	if _buttons.is_empty():
		visible = false
		return
	_index = 0
	_focus_index()


func hide_choices() -> void:
	visible = false
	_clear()


func _clear() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()
	for child in list.get_children():
		child.queue_free()


func _on_choice(choice_id: String) -> void:
	choice_selected.emit(choice_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _buttons.is_empty():
		return
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		_index = (_index + 1) % _buttons.size()
		_focus_index()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		_index = (_index - 1 + _buttons.size()) % _buttons.size()
		_focus_index()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_buttons[_index].emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var n := event.keycode - KEY_1
		if n < _buttons.size():
			_buttons[n].emit_signal("pressed")
			get_viewport().set_input_as_handled()


func _focus_index() -> void:
	if _index >= 0 and _index < _buttons.size():
		_buttons[_index].grab_focus()
