extends Control
class_name SettingsMenu
## Text speed, instant text, intent previews, faculty panels, UI scale.

signal closed
signal restart_requested

@onready var title: Label = %Title
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_value: Label = %SpeedValue
@onready var instant_check: CheckBox = %InstantCheck
@onready var intent_check: CheckBox = %IntentCheck
@onready var faculty_check: CheckBox = %FacultyCheck
@onready var scale_slider: HSlider = %ScaleSlider
@onready var scale_value: Label = %ScaleValue
@onready var motion_check: CheckBox = %MotionCheck
@onready var apply_btn: Button = %ApplyBtn
@onready var close_btn: Button = %CloseBtn
@onready var restart_btn: Button = %RestartBtn
@onready var preset_row: HBoxContainer = %PresetRow
@onready var hint: Label = %SpeedHint

var settings: UISettings


func _ready() -> void:
	visible = false
	title.text = "Preferences"
	speed_slider.min_value = 12
	speed_slider.max_value = 120
	speed_slider.step = 1
	scale_slider.min_value = 0.85
	scale_slider.max_value = 1.25
	scale_slider.step = 0.05
	speed_slider.value_changed.connect(_on_speed)
	scale_slider.value_changed.connect(_on_scale)
	instant_check.toggled.connect(func (_v): _live_apply())
	speed_slider.drag_ended.connect(func (_c): _live_apply())
	apply_btn.pressed.connect(_apply)
	close_btn.pressed.connect(close)
	restart_btn.pressed.connect(func (): restart_requested.emit())
	_ensure_presets()


func _ensure_presets() -> void:
	if preset_row == null:
		return
	for c in preset_row.get_children():
		c.queue_free()
	_add_preset("Leisurely", 22, false)
	_add_preset("Brisk", 42, false)
	_add_preset("Rapid", 78, false)
	_add_preset("Instant", 120, true)


func _add_preset(label: String, cps: int, instant: bool) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(func ():
		speed_slider.value = cps
		instant_check.button_pressed = instant
		_on_speed(cps)
		_live_apply()
	)
	preset_row.add_child(b)


func bind(settings_ref: UISettings) -> void:
	settings = settings_ref


func open() -> void:
	visible = true
	_sync_from_settings()
	close_btn.grab_focus()


func close() -> void:
	_apply()
	visible = false
	closed.emit()


func _sync_from_settings() -> void:
	if settings == null:
		return
	speed_slider.value = settings.text_chars_per_second
	instant_check.button_pressed = settings.instant_text
	intent_check.button_pressed = settings.show_intent_previews
	faculty_check.button_pressed = settings.show_faculty_panels
	scale_slider.value = settings.ui_scale
	motion_check.button_pressed = settings.reduce_motion
	_on_speed(speed_slider.value)
	_on_scale(scale_slider.value)


func _on_speed(v: float) -> void:
	var label := "brisk"
	if instant_check.button_pressed:
		label = "instant"
	elif v < 28:
		label = "leisurely"
	elif v > 70:
		label = "rapid"
	speed_value.text = "%d · %s" % [int(v), label]
	if hint:
		hint.text = "Hold Ctrl while advancing to dump a line instantly. Space skips typing."


func _on_scale(v: float) -> void:
	scale_value.text = "%.0f%%" % (v * 100.0)


func _live_apply() -> void:
	if settings == null:
		return
	settings.text_chars_per_second = float(speed_slider.value)
	settings.instant_text = instant_check.button_pressed
	settings.changed.emit()


func _apply() -> void:
	if settings == null:
		return
	settings.text_chars_per_second = float(speed_slider.value)
	settings.instant_text = instant_check.button_pressed
	settings.show_intent_previews = intent_check.button_pressed
	settings.show_faculty_panels = faculty_check.button_pressed
	settings.ui_scale = float(scale_slider.value)
	settings.reduce_motion = motion_check.button_pressed
	settings.save_to_disk()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
