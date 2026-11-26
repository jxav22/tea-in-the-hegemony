extends Control
class_name CharacterProfile
## Profile card from discovered info only — no omniscient spoilers.

signal closed

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %Name
@onready var role_label: Label = %Role
@onready var rel_box: VBoxContainer = %RelBox
@onready var knowledge: RichTextLabel = %Knowledge
@onready var memories: RichTextLabel = %Memories
@onready var close_btn: Button = %CloseBtn
@onready var title: Label = %Title


func _ready() -> void:
	visible = false
	title.text = "Dossier"
	title.add_theme_color_override("font_color", HegemonyPalette.BRASS)
	knowledge.bbcode_enabled = true
	memories.bbcode_enabled = true
	close_btn.pressed.connect(close)


func open_profile(data: Dictionary) -> void:
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	var id := str(data.get("id", data.get("character_id", "")))
	var display := str(data.get("display_name", id))
	name_label.text = display
	name_label.add_theme_color_override("font_color", HegemonyPalette.IVORY)
	var role := str(data.get("role", "Unknown"))
	if data.has("affinity"):
		var aff := float(data.get("affinity", 0.0))
		var aff_col := HegemonyPalette.JADE if aff >= 0.0 else HegemonyPalette.VERMILLION
		role_label.add_theme_color_override("font_color", aff_col)
		role = "%s\naffinity %+0.1f  ·  not a romance bar" % [role, aff]
	else:
		role_label.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
	role_label.text = role
	var expr := str(data.get("expression", "neutral"))
	portrait.texture = PortraitBank.load_texture(PortraitBank.portrait_path(id, expr))

	for child in rel_box.get_children():
		child.queue_free()
	var rel: Dictionary = data.get("rels", data.get("relationship", {}))
	var dims := ["trust", "familiarity", "suspicion", "respect", "affection", "comfort", "perceived_authenticity"]
	for dim in dims:
		if not rel.has(dim):
			continue
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = dim.replace("_", " ")
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
		lab.add_theme_font_size_override("font_size", 13)
		var val := Label.new()
		var v := int(rel[dim])
		val.text = _bar(v)
		val.add_theme_color_override("font_color", HegemonyPalette.VERMILLION if dim == "suspicion" and v > 0 else HegemonyPalette.BRASS)
		val.add_theme_font_size_override("font_size", 13)
		row.add_child(lab)
		row.add_child(val)
		rel_box.add_child(row)

	var flags: Array = data.get("knowledge_flags", data.get("discovered", []))
	if flags.is_empty():
		knowledge.text = "[color=#9a9286][i]Nothing confirmed. Watch longer.[/i][/color]"
	else:
		var parts: PackedStringArray = []
		for fl in flags:
			parts.append("• %s" % str(fl))
		knowledge.text = "\n".join(parts)

	var mems: Array = data.get("memories", [])
	if mems.is_empty():
		memories.text = "[color=#9a9286][i]No shared moments logged.[/i][/color]"
	else:
		var mparts: PackedStringArray = []
		for m in mems:
			if typeof(m) == TYPE_DICTIONARY:
				mparts.append("• %s" % str(m.get("summary", m.get("id", ""))))
			else:
				mparts.append("• %s" % str(m))
		memories.text = "\n".join(mparts)

	close_btn.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _bar(v: int) -> String:
	var clamped := clampi(v, -5, 5)
	var fill := clamped + 5
	var s := ""
	for i in 11:
		s += "●" if i == fill else "·"
	return "%s (%+d)" % [s, clamped]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
