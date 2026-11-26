class_name Typewriter
extends RefCounted
## Character reveal helper for dialogue. Supports instant dump and skip.

signal finished
signal character_shown

var _full_text: String = ""
var _visible: int = 0
var _cps: float = 42.0
var _accum: float = 0.0
var _running: bool = false
var _instant: bool = false


func start(text: String, chars_per_second: float, instant: bool) -> void:
	_full_text = text
	_cps = maxf(1.0, chars_per_second)
	_instant = instant
	_visible = 0
	_accum = 0.0
	_running = true
	if _instant or text.is_empty():
		_visible = _full_text.length()
		_running = false
		finished.emit()


func skip() -> void:
	if not _running:
		return
	_visible = _full_text.length()
	_running = false
	finished.emit()


func is_running() -> bool:
	return _running


func visible_text() -> String:
	return _full_text.substr(0, _visible)


func full_text() -> String:
	return _full_text


func tick(delta: float) -> void:
	if not _running:
		return
	_accum += delta * _cps
	var step := int(_accum)
	if step <= 0:
		return
	_accum -= float(step)
	_visible = mini(_visible + step, _full_text.length())
	character_shown.emit()
	if _visible >= _full_text.length():
		_running = false
		finished.emit()
