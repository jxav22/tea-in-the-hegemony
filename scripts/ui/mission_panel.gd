extends Control
class_name MissionPanel
## Compact mission objectives — narrative HUD, not a task tracker app.

@onready var title: Label = %Title
@onready var list: VBoxContainer = %List
@onready var stamp: TextureRect = %Stamp
@onready var cover_label: Label = %CoverLabel

var _collapsed: bool = false
var _objectives_cache: Array = []


func _ready() -> void:
	title.text = "Brief"
	if stamp:
		stamp.texture = PortraitBank.load_texture("res://assets/ui/mission_stamp.png")
	if cover_label:
		cover_label.text = "Cover: —"


func set_cover_status(cover_name: String, heat: int, blown: bool, mission_ok: bool) -> void:
	if cover_label == null:
		return
	var heat_col := HegemonyPalette.JADE
	if heat >= 50:
		heat_col = HegemonyPalette.AMBER
	if heat >= 80 or blown:
		heat_col = HegemonyPalette.VERMILLION
	cover_label.add_theme_color_override("font_color", heat_col)
	var flag := "BLOWN" if blown else ("brief met" if mission_ok else "active")
	cover_label.text = "%s · heat %d · %s" % [cover_name, heat, flag]


func set_objectives(objectives: Array) -> void:
	_objectives_cache = objectives.duplicate(true)
	for child in list.get_children():
		child.queue_free()
	var shown := 0
	for o in objectives:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var status := str(o.get("status", "active")).to_lower()
		if status == "hidden":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var mark := Label.new()
		match status:
			"done", "complete", "completed":
				mark.text = "▣"
				mark.add_theme_color_override("font_color", HegemonyPalette.JADE)
			"failed", "blown":
				mark.text = "✕"
				mark.add_theme_color_override("font_color", HegemonyPalette.VERMILLION)
			_:
				mark.text = "□"
				mark.add_theme_color_override("font_color", HegemonyPalette.BRASS)
		var lab := Label.new()
		lab.text = str(o.get("text", o.get("title", o.get("id", ""))))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_color", HegemonyPalette.IVORY)
		if status in ["done", "complete", "completed"]:
			lab.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
		row.add_child(mark)
		row.add_child(lab)
		list.add_child(row)
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "No active brief — wait for handlers."
		empty.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(empty)
	title.text = "Brief · %d" % shown


func toggle_collapse() -> void:
	_collapsed = not _collapsed
	list.visible = not _collapsed
