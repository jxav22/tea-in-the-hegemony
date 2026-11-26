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
	## Legacy numeric path — prefer set_cover_present().
	var band := "clear"
	if blown:
		band = "blown"
	elif heat >= 80:
		band = "critical"
	elif heat >= 55:
		band = "high"
	elif heat >= 30:
		band = "elevated"
	elif heat >= 10:
		band = "low"
	set_cover_present({
		"cover_name": cover_name,
		"heat_band": band,
		"heat_label": "Cover blown" if blown else ("holding" if mission_ok else "active"),
		"blown": blown,
		"attention_line": "",
	})


func set_cover_present(data: Dictionary) -> void:
	## Qualitative cover chrome — no raw heat dump.
	if cover_label == null:
		return
	var band := str(data.get("heat_band", "clear"))
	var heat_col := HegemonyPalette.JADE
	match band:
		"elevated", "low":
			heat_col = HegemonyPalette.AMBER
		"high", "critical", "blown":
			heat_col = HegemonyPalette.VERMILLION
	cover_label.add_theme_color_override("font_color", heat_col)
	var name := str(data.get("cover_name", "—"))
	var label := str(data.get("heat_label", band))
	var attention := str(data.get("attention_line", ""))
	if attention.is_empty():
		cover_label.text = "%s · %s" % [name, label]
	else:
		cover_label.text = "%s · %s\n%s" % [name, label, attention]
		cover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


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
