extends Button
class_name ChoiceIntentButton
## Choice row with intent preview chip (tone hint, not full spoiler).

signal choice_activated(choice_id: String)

var choice_id: String = ""
var intent: String = ""
var _intent_label: Label
var _gloss_label: Label
var _accent: ColorRect
var _index_badge: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	_ensure_chrome()


func setup(id: String, label: String, intent_key: String, show_intent: bool, index: int = 0) -> void:
	choice_id = id
	intent = intent_key
	text = "     " + label
	_ensure_chrome()
	_index_badge.text = str(index + 1)
	var col := HegemonyPalette.intent_color(intent_key)
	_accent.color = col
	if show_intent and not intent_key.is_empty():
		_intent_label.visible = true
		_gloss_label.visible = true
		_intent_label.text = HegemonyPalette.intent_label(intent_key).to_upper()
		_intent_label.add_theme_color_override("font_color", col)
		_gloss_label.text = HegemonyPalette.intent_gloss(intent_key)
		_gloss_label.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
		tooltip_text = "%s — %s" % [HegemonyPalette.intent_label(intent_key), HegemonyPalette.intent_gloss(intent_key)]
	else:
		_intent_label.visible = false
		_gloss_label.visible = false
		tooltip_text = label
	# Left pad so accent strip + index remain readable
	add_theme_constant_override("h_separation", 8)


func _ensure_chrome() -> void:
	if _accent:
		return
	_accent = ColorRect.new()
	_accent.name = "IntentAccent"
	_accent.custom_minimum_size = Vector2(5, 0)
	_accent.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_accent.offset_right = 5
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accent.color = HegemonyPalette.JADE
	add_child(_accent)

	_index_badge = Label.new()
	_index_badge.name = "IndexBadge"
	_index_badge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_index_badge.offset_left = 10
	_index_badge.offset_right = 28
	_index_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_index_badge.add_theme_font_size_override("font_size", 12)
	_index_badge.add_theme_color_override("font_color", HegemonyPalette.BRASS)
	_index_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_index_badge)

	_intent_label = Label.new()
	_intent_label.name = "IntentChip"
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_intent_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_intent_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_intent_label.offset_left = -200
	_intent_label.offset_right = -12
	_intent_label.offset_top = 6
	_intent_label.offset_bottom = 22
	_intent_label.add_theme_font_size_override("font_size", 11)
	_intent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intent_label)

	_gloss_label = Label.new()
	_gloss_label.name = "IntentGloss"
	_gloss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gloss_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_gloss_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_gloss_label.offset_left = -260
	_gloss_label.offset_right = -12
	_gloss_label.offset_top = -22
	_gloss_label.offset_bottom = -6
	_gloss_label.add_theme_font_size_override("font_size", 10)
	_gloss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gloss_label)


func _on_pressed() -> void:
	choice_activated.emit(choice_id)
