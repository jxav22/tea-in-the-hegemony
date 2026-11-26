class_name NavChrome
extends RefCounted
## Shared styling for reception nav buttons — narrative, not form controls.


static func style_button(btn: Button, kind: String = "nav") -> void:
	btn.custom_minimum_size = Vector2(maxi(72, int(btn.custom_minimum_size.x)), 40)
	btn.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = HegemonyPalette.SLATE
	normal.border_color = HegemonyPalette.BRASS
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = HegemonyPalette.CHOICE_HOVER
	hover.border_color = HegemonyPalette.AMBER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = HegemonyPalette.WINE
	match kind:
		"danger":
			normal.border_color = HegemonyPalette.VERMILLION
		"quiet":
			normal.border_color = HegemonyPalette.JADE
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", HegemonyPalette.IVORY)
	btn.add_theme_color_override("font_hover_color", HegemonyPalette.BRASS)
