extends Control
class_name FacultyPanel
## Comic-panel internal monologue from a faculty (non-blocking advice).

@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var body: Label = %Body

var _tween: Tween
var _base_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_base_pos = position


func show_interjection(faculty: String, text: String, reduce_motion: bool = false) -> void:
	show_interjection_styled(faculty, text, reduce_motion, 0)


func show_interjection_styled(faculty: String, text: String, reduce_motion: bool = false, stack_index: int = 0) -> void:
	if title == null:
		await ready
	title.text = faculty.to_upper()
	body.text = text
	var accent := HegemonyPalette.faculty_color(faculty)
	title.add_theme_color_override("font_color", accent)
	body.add_theme_color_override("font_color", HegemonyPalette.MONOLOGUE)
	if panel:
		var sb := panel.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			flat.border_color = accent
			flat.bg_color = Color(HegemonyPalette.INK_DEEP, 0.92)
			panel.add_theme_stylebox_override("panel", flat)
	visible = true
	if _tween:
		_tween.kill()
	if reduce_motion:
		modulate.a = 1.0
		rotation_degrees = 0.0
		return
	# Comic beat: snap-in with slight tilt + short shake
	modulate.a = 0.0
	rotation_degrees = -2.5 + float(stack_index) * 0.6
	scale = Vector2(0.94, 0.94)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees", float(stack_index % 2) * 0.8 - 0.4, 0.22)
	_tween.chain().tween_callback(_micro_shake)


func _micro_shake() -> void:
	if not visible:
		return
	var origin := position
	var shake := create_tween()
	shake.tween_property(self, "position:x", origin.x + 3.0, 0.04)
	shake.tween_property(self, "position:x", origin.x - 2.0, 0.04)
	shake.tween_property(self, "position:x", origin.x, 0.05)


func hide_panel(reduce_motion: bool = false) -> void:
	if not visible:
		return
	if _tween:
		_tween.kill()
	if reduce_motion:
		visible = false
		modulate.a = 0.0
		queue_free()
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.16)
	_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.16)
	_tween.tween_callback(func ():
		visible = false
		queue_free()
	)
