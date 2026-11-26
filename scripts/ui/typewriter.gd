class_name Typewriter
extends RefCounted
## Character reveal helper for dialogue. Supports instant dump, skip, live speed.

signal finished
signal character_shown

var _full_text: String = ""
var _visible: int = 0
var _cps: float = 42.0
var _accum: float = 0.0
var _running: bool = false
var _instant: bool = false
var _pause_left: float = 0.0


func start(text: String, chars_per_second: float, instant: bool) -> void:
	_full_text = text
	_cps = maxf(1.0, chars_per_second)
	_instant = instant
	_visible = 0
	_accum = 0.0
	_pause_left = 0.0
	_running = true
	if _instant or text.is_empty():
		_visible = _full_text.length()
		_running = false
		finished.emit()


func set_speed(chars_per_second: float, instant: bool = false) -> void:
	## Live-update mid-line when preferences change.
	_cps = maxf(1.0, chars_per_second)
	_instant = instant
	if _instant and _running:
		skip()


func skip() -> void:
	if not _running:
		return
	_visible = _full_text.length()
	_running = false
	_pause_left = 0.0
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
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	_accum += delta * _cps
	var step := int(_accum)
	if step <= 0:
		return
	_accum -= float(step)
	for _i in step:
		if _visible >= _full_text.length():
			break
		_visible += 1
		character_shown.emit()
		var ch := _full_text[_visible - 1]
		# Soft comic beat on punctuation — feels deliberate, not sluggish
		if ch == "." or ch == "?" or ch == "!":
			_pause_left = 0.12
			break
		if ch == "," or ch == ";" or ch == "—":
			_pause_left = 0.05
			break
	if _visible >= _full_text.length():
		_running = false
		finished.emit()
