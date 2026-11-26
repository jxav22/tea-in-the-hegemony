class_name UISettings
extends RefCounted
## Presentation-side player preferences (text speed, instant text, etc.).

signal changed

const SAVE_PATH := "user://ui_settings.cfg"

var text_chars_per_second: float = 42.0
var instant_text: bool = false
var show_intent_previews: bool = true
var show_faculty_panels: bool = true
var ui_scale: float = 1.0
var reduce_motion: bool = false


func apply_defaults() -> void:
	text_chars_per_second = 42.0
	instant_text = false
	show_intent_previews = true
	show_faculty_panels = true
	ui_scale = 1.0
	reduce_motion = false
	changed.emit()


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	text_chars_per_second = float(cfg.get_value("text", "cps", text_chars_per_second))
	instant_text = bool(cfg.get_value("text", "instant", instant_text))
	show_intent_previews = bool(cfg.get_value("ui", "intent_previews", show_intent_previews))
	show_faculty_panels = bool(cfg.get_value("ui", "faculty_panels", show_faculty_panels))
	ui_scale = float(cfg.get_value("ui", "scale", ui_scale))
	reduce_motion = bool(cfg.get_value("ui", "reduce_motion", reduce_motion))
	changed.emit()


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("text", "cps", text_chars_per_second)
	cfg.set_value("text", "instant", instant_text)
	cfg.set_value("ui", "intent_previews", show_intent_previews)
	cfg.set_value("ui", "faculty_panels", show_faculty_panels)
	cfg.set_value("ui", "scale", ui_scale)
	cfg.set_value("ui", "reduce_motion", reduce_motion)
	cfg.save(SAVE_PATH)
	changed.emit()
