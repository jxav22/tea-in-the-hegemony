extends Control
class_name LocationBanner
## Brief location title card during room transitions.

@onready var label: Label = %Label
@onready var rule: ColorRect = %Rule

var _tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func announce(location_id: String, display_name: String = "", reduce_motion: bool = false) -> void:
	var text := display_name if not display_name.is_empty() else location_id.replace("_", " ").capitalize()
	if label:
		label.text = text.to_upper()
	visible = true
	if _tween:
		_tween.kill()
	if reduce_motion:
		modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		visible = false
		modulate.a = 0.0
		return
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(0.55)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func (): visible = false)
