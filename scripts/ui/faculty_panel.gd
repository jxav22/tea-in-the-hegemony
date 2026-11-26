extends Control
class_name FacultyPanel
## Comic-panel internal monologue from a faculty (non-blocking advice).

@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var body: Label = %Body

var _tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func show_interjection(faculty: String, text: String, reduce_motion: bool = false) -> void:
	title.text = faculty.to_upper()
	body.text = text
	visible = true
	if _tween:
		_tween.kill()
	if reduce_motion:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)


func hide_panel(reduce_motion: bool = false) -> void:
	if not visible:
		return
	if _tween:
		_tween.kill()
	if reduce_motion:
		visible = false
		modulate.a = 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(func (): visible = false)
