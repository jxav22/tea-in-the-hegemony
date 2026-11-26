extends Control
class_name IntelNotebook
## Intelligence notebook — evidence fragments, claims, contradictions.

signal closed

@onready var page: PanelContainer = %Page
@onready var title: Label = %Title
@onready var list: ItemList = %EvidenceList
@onready var detail: RichTextLabel = %Detail
@onready var close_btn: Button = %CloseBtn

var _fragments: Array = []


func _ready() -> void:
	visible = false
	title.text = "Field Notebook"
	title.add_theme_color_override("font_color", HegemonyPalette.IVORY)
	detail.bbcode_enabled = true
	close_btn.pressed.connect(close)
	list.item_selected.connect(_on_select)
	list.allow_reselect = true


func open_with(fragments: Array) -> void:
	_fragments = fragments.duplicate(true)
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	list.clear()
	var verified_n := 0
	for f in _fragments:
		var id := str(f.get("id", "fragment"))
		var label := str(f.get("title", f.get("summary", id)))
		var verified := bool(f.get("verified", false))
		if verified:
			verified_n += 1
		var mark := "◆" if verified else "◇"
		list.add_item("%s  %s" % [mark, label])
	title.text = "Field Notebook · %d entries" % _fragments.size()
	if _fragments.is_empty():
		detail.text = "[color=#9a9286][i]Pages still blank.[/i][/color]\n\nListen in the salon. Mark contradictions. Trust nothing that arrives too neatly."
	else:
		detail.text = "[color=#5b8a7a]%d verified[/color] · [color=#c4a574]%d provisional[/color]\n\nSelect a fragment." % [
			verified_n, _fragments.size() - verified_n
		]
		list.select(0)
		_on_select(0)
	close_btn.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _on_select(index: int) -> void:
	if index < 0 or index >= _fragments.size():
		return
	var f: Dictionary = _fragments[index]
	var lines: PackedStringArray = []
	lines.append("[b][color=#e8e0d4]%s[/color][/b]" % str(f.get("title", f.get("id", ""))))
	if f.has("summary") and str(f["summary"]).strip_edges() != "":
		lines.append("\n%s" % str(f["summary"]))
	var claims: Array = f.get("claims", [])
	if claims:
		lines.append("\n[color=#5b8a7a]Claims[/color]")
		for c in claims:
			lines.append("• %s" % str(c))
	var contradicts: Array = f.get("contradicts", [])
	if contradicts:
		lines.append("\n[color=#c45c48]Contradicts[/color]")
		for c in contradicts:
			lines.append("• %s" % str(c))
	if f.get("verified", false):
		lines.append("\n[color=#c4a574]◆ Verified[/color]")
	else:
		lines.append("\n[color=#9a9286]◇ Unverified — treat as rumour[/color]")
	detail.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_N):
		close()
		get_viewport().set_input_as_handled()
