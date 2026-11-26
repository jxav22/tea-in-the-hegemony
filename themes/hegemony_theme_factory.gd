class_name HegemonyThemeFactory
extends RefCounted
## Builds the runtime Theme for Compatibility renderer (no editor dependency).


static func build() -> Theme:
	var theme := Theme.new()
	var display := _load_font("res://assets/fonts/Tinos-Regular.ttf", 28)
	var display_bold := _load_font("res://assets/fonts/Tinos-Bold.ttf", 32)
	var display_italic := _load_font("res://assets/fonts/Tinos-Italic.ttf", 26)
	var ui := _load_font("res://assets/fonts/PublicSans-Regular.ttf", 16)
	var ui_bold := _load_font("res://assets/fonts/PublicSans-Bold.ttf", 16)
	var ui_italic := _load_font("res://assets/fonts/PublicSans-Italic.ttf", 15)
	var body := _load_font("res://assets/fonts/SourceSans3-Regular.ttf", 18)

	if display:
		theme.set_font("font", "Label", display)
		theme.set_font("title_font", "Hegemony", display_bold if display_bold else display)
		theme.set_font("serif", "Hegemony", display)
		theme.set_font("serif_italic", "Hegemony", display_italic if display_italic else display)
	if ui:
		theme.set_font("font", "Button", ui_bold if ui_bold else ui)
		theme.set_font("font", "CheckBox", ui)
		theme.set_font("font", "OptionButton", ui)
		theme.set_font("font", "LineEdit", ui)
		theme.set_font("ui", "Hegemony", ui)
		theme.set_font("ui_bold", "Hegemony", ui_bold if ui_bold else ui)
		theme.set_font("ui_italic", "Hegemony", ui_italic if ui_italic else ui)
	if body:
		theme.set_font("body", "Hegemony", body)
		theme.set_font("font", "RichTextLabel", body)
		theme.set_font("normal_font", "RichTextLabel", body)
		if display_italic:
			theme.set_font("italics_font", "RichTextLabel", display_italic)
		if ui_bold:
			theme.set_font("bold_font", "RichTextLabel", ui_bold)

	theme.set_color("font_color", "Label", HegemonyPalette.IVORY)
	theme.set_color("font_color", "Button", HegemonyPalette.IVORY)
	theme.set_color("font_hover_color", "Button", HegemonyPalette.BRASS)
	theme.set_color("font_pressed_color", "Button", HegemonyPalette.JADE)
	theme.set_color("font_disabled_color", "Button", HegemonyPalette.DIM_TEXT)
	theme.set_color("font_focus_color", "Button", HegemonyPalette.BRASS)
	theme.set_color("default_color", "RichTextLabel", HegemonyPalette.IVORY)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))

	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_constant("h_separation", "Button", 8)
	theme.set_constant("outline_size", "Label", 0)

	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 16)
	theme.set_font_size("font_size", "RichTextLabel", 18)
	theme.set_font_size("title_size", "Hegemony", 36)
	theme.set_font_size("speaker_size", "Hegemony", 22)
	theme.set_font_size("choice_size", "Hegemony", 17)
	theme.set_font_size("caption_size", "Hegemony", 13)

	var panel := _flat(HegemonyPalette.SALON_PANEL, HegemonyPalette.BRASS, 2, 8)
	var panel_dark := _flat(HegemonyPalette.INK_DEEP, HegemonyPalette.JADE, 2, 6)
	var btn_normal := _flat(HegemonyPalette.SLATE, HegemonyPalette.BRASS, 1, 2)
	var btn_hover := _flat(HegemonyPalette.CHOICE_HOVER, HegemonyPalette.BRASS, 2, 2)
	var btn_pressed := _flat(HegemonyPalette.WINE, HegemonyPalette.VERMILLION, 1, 2)
	var btn_disabled := _flat(Color(HegemonyPalette.SLATE, 0.5), HegemonyPalette.DIM_TEXT, 1, 2)

	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupPanel", panel_dark)
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), HegemonyPalette.AMBER, 2, 2))
	theme.set_stylebox("grabber", "HSlider", _flat(HegemonyPalette.BRASS, HegemonyPalette.BRASS, 0, 4))
	theme.set_stylebox("slider", "HSlider", _flat(HegemonyPalette.SLATE, HegemonyPalette.JADE, 1, 4))

	return theme


static func _load_font(path: String, _size: int) -> Font:
	# Exported/web builds remap .ttf → imported FontFile (.fontdata). Prefer ResourceLoader
	# over load_dynamic_font(), which needs raw TTF bytes and yields tofu glyphs in PCK exports.
	if not ResourceLoader.exists(path):
		push_warning("Missing font: %s" % path)
		return null
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if loaded is Font:
		return loaded as Font
	var font := FontFile.new()
	var err := font.load_dynamic_font(path)
	if err != OK:
		push_warning("Failed loading font %s (%s)" % [path, err])
		return null
	font.fixed_size = 0
	return font


static func _flat(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb
