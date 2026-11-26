extends Button
class_name ChoiceIntentButton
## Choice row with intent preview chip (tone hint, not full spoiler).

signal choice_activated(choice_id: String)

var choice_id: String = ""
var intent: String = ""
var _intent_label: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	if _intent_label == null:
		_ensure_chip()


func setup(id: String, label: String, intent_key: String, show_intent: bool) -> void:
	choice_id = id
	intent = intent_key
	text = "  " + label
	_ensure_chip()
	if show_intent and not intent_key.is_empty():
		_intent_label.visible = true
		_intent_label.text = HegemonyPalette.intent_label(intent_key)
		_intent_label.add_theme_color_override("font_color", HegemonyPalette.intent_color(intent_key))
		tooltip_text = "Intent: %s" % HegemonyPalette.intent_label(intent_key)
	else:
		_intent_label.visible = false
		tooltip_text = label


func _ensure_chip() -> void:
	if _intent_label:
		return
	_intent_label = Label.new()
	_intent_label.name = "IntentChip"
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_intent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intent_label.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_intent_label.offset_left = -140
	_intent_label.offset_right = -12
	_intent_label.add_theme_font_size_override("font_size", 12)
	_intent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intent_label)


func _on_pressed() -> void:
	choice_activated.emit(choice_id)
