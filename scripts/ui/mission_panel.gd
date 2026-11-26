extends Control
class_name MissionPanel
## Compact mission objectives — narrative HUD, not a task tracker app.

@onready var title: Label = %Title
@onready var list: VBoxContainer = %List
@onready var stamp: TextureRect = %Stamp

var _collapsed: bool = false


func _ready() -> void:
	title.text = "Brief"
	if stamp:
		stamp.texture = PortraitBank.load_texture("res://assets/ui/mission_stamp.png")


func set_objectives(objectives: Array) -> void:
	for child in list.get_children():
		child.queue_free()
	for o in objectives:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var mark := Label.new()
		var status := str(o.get("status", "active")).to_lower()
		match status:
			"done", "complete", "completed":
				mark.text = "▣"
				mark.add_theme_color_override("font_color", HegemonyPalette.JADE)
			"failed", "blown":
				mark.text = "✕"
				mark.add_theme_color_override("font_color", HegemonyPalette.VERMILLION)
			"hidden":
				continue
			_:
				mark.text = "□"
				mark.add_theme_color_override("font_color", HegemonyPalette.BRASS)
		var lab := Label.new()
		lab.text = str(o.get("text", o.get("title", o.get("id", ""))))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 14)
		if status in ["done", "complete", "completed"]:
			lab.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
		row.add_child(mark)
		row.add_child(lab)
		list.add_child(row)


func toggle_collapse() -> void:
	_collapsed = not _collapsed
	list.visible = not _collapsed
