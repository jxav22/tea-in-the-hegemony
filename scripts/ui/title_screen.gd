extends Control
class_name TitleScreen
## Brand-forward title — product name is the hero signal.

signal start_requested
signal continue_requested
signal preferences_requested

@onready var start_btn: Button = %StartBtn
@onready var continue_btn: Button = %ContinueBtn
@onready var prefs_btn: Button = %PrefsBtn
@onready var title: Label = %Title


func _ready() -> void:
	theme = HegemonyThemeFactory.build()
	title.add_theme_color_override("font_color", HegemonyPalette.IVORY)
	start_btn.pressed.connect(func (): start_requested.emit())
	continue_btn.pressed.connect(func (): continue_requested.emit())
	prefs_btn.pressed.connect(func (): preferences_requested.emit())
	start_btn.grab_focus()
	# Subtle title pulse — presence, not noise
	var tw := create_tween().set_loops()
	tw.tween_property(title, "modulate", Color(1, 1, 1, 0.88), 2.4)
	tw.tween_property(title, "modulate", Color(1, 1, 1, 1.0), 2.4)
