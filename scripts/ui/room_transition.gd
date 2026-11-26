extends Control
class_name RoomTransition
## Crossfade / brief ink wipe between Reception rooms. Compatibility-safe.

signal transition_finished

@onready var under: TextureRect = %Under
@onready var over: TextureRect = %Over
@onready var wipe: ColorRect = %Wipe

var reduce_motion: bool = false
var _busy: bool = false
var _current_id: String = ""
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wipe:
		wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wipe.modulate.a = 0.0
	if over:
		over.modulate.a = 0.0


func current_location() -> String:
	return _current_id


func set_location_immediate(location_id: String) -> void:
	_current_id = location_id
	var tex := PortraitBank.load_texture(PortraitBank.background_path(_map_loc(location_id)))
	if under:
		under.texture = tex
		under.visible = tex != null
	if over:
		over.texture = null
		over.modulate.a = 0.0
	if wipe:
		wipe.modulate.a = 0.0
	_busy = false


func transition_to(location_id: String) -> void:
	var mapped := _map_loc(location_id)
	if mapped == _map_loc(_current_id) and under and under.texture != null:
		transition_finished.emit()
		return
	var next := PortraitBank.load_texture(PortraitBank.background_path(mapped))
	if next == null:
		_current_id = location_id
		transition_finished.emit()
		return
	if reduce_motion or under == null:
		set_location_immediate(location_id)
		transition_finished.emit()
		return
	if _busy:
		# Interrupt prior transition cleanly
		if _tween:
			_tween.kill()
		set_location_immediate(location_id)
		transition_finished.emit()
		return
	if under.texture == null:
		set_location_immediate(location_id)
		transition_finished.emit()
		return
	_busy = true
	over.texture = next
	over.modulate.a = 0.0
	wipe.color = HegemonyPalette.INK_DEEP
	wipe.modulate.a = 0.0
	_tween = create_tween()
	# Ink dip → reveal new room underneath wipe → soft brass edge fade
	_tween.tween_property(wipe, "modulate:a", 0.72, 0.14).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func ():
		under.texture = next
		over.modulate.a = 0.0
		wipe.color = HegemonyPalette.BRASS
	)
	_tween.tween_property(wipe, "modulate:a", 0.18, 0.08)
	_tween.tween_property(wipe, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func ():
		_current_id = location_id
		_busy = false
		transition_finished.emit()
	)


func _map_loc(location_id: String) -> String:
	if location_id == "study":
		return "study_annex"
	if location_id.is_empty():
		return "foyer"
	return location_id
