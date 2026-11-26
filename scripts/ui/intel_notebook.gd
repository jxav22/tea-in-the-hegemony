extends Control
class_name IntelNotebook
## Intelligence notebook — evidence fragments, claims, contradictions.

signal closed

@onready var page: PanelContainer = %Page
@onready var title: Label = %Title
@onready var list: ItemList = %EvidenceList
@onready var detail: RichTextLabel = %Detail
@onready var close_btn: Button = %CloseBtn
@onready var filter_row: HBoxContainer = get_node_or_null("%FilterRow") as HBoxContainer
@onready var summary: Label = get_node_or_null("%Summary") as Label

var _fragments: Array = []
var _view: Array = []
var _filter: String = "all" # all | verified | provisional


func _ready() -> void:
	visible = false
	title.text = "Field Notebook"
	title.add_theme_color_override("font_color", HegemonyPalette.IVORY)
	detail.bbcode_enabled = true
	close_btn.pressed.connect(close)
	list.item_selected.connect(_on_select)
	list.allow_reselect = true
	_ensure_filters()


func _ensure_filters() -> void:
	if filter_row == null:
		return
	for c in filter_row.get_children():
		c.queue_free()
	for key in ["all", "verified", "provisional"]:
		var b := Button.new()
		b.text = key.capitalize()
		b.toggle_mode = true
		b.button_pressed = key == _filter
		var k := key
		b.pressed.connect(func ():
			_filter = k
			_rebuild_list()
			for sib in filter_row.get_children():
				if sib is Button:
					(sib as Button).button_pressed = (sib as Button).text.to_lower() == _filter
		)
		filter_row.add_child(b)


func open_with(fragments: Array) -> void:
	_fragments = fragments.duplicate(true)
	# Verified first, then provisional — clearer scan
	_fragments.sort_custom(func(a, b) -> bool:
		var av := bool(a.get("verified", false))
		var bv := bool(b.get("verified", false))
		if av == bv:
			return str(a.get("title", "")) < str(b.get("title", ""))
		return av and not bv
	)
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	_rebuild_list()
	close_btn.grab_focus()


func _rebuild_list() -> void:
	list.clear()
	_view.clear()
	var verified_n := 0
	var prov_n := 0
	for f in _fragments:
		var verified := bool(f.get("verified", false))
		if verified:
			verified_n += 1
		else:
			prov_n += 1
		if _filter == "verified" and not verified:
			continue
		if _filter == "provisional" and verified:
			continue
		_view.append(f)
		var label := str(f.get("title", f.get("summary", f.get("id", "fragment"))))
		var mark := "◆" if verified else "◇"
		var source := str(f.get("source", ""))
		if source.is_empty():
			list.add_item("%s  %s" % [mark, label])
		else:
			list.add_item("%s  %s  ·  %s" % [mark, label, source])
	title.text = "Field Notebook"
	if summary:
		summary.text = "%d verified · %d provisional · showing %d" % [verified_n, prov_n, _view.size()]
		summary.add_theme_color_override("font_color", HegemonyPalette.DIM_TEXT)
	if _view.is_empty():
		if _fragments.is_empty():
			detail.text = "[color=#9a9286][i]Pages still blank.[/i][/color]\n\nListen in the salon. Mark contradictions. Trust nothing that arrives too neatly.\n\n[color=#c4a574]◆[/color] verified · [color=#9a9286]◇[/color] provisional"
		else:
			detail.text = "[color=#9a9286][i]Nothing in this filter.[/i][/color]\n\nTry All / Verified / Provisional."
	else:
		detail.text = "[color=#5b8a7a]Select a fragment.[/color]\n◆ verified holds weight · ◇ provisional is rumour until pressed."
		list.select(0)
		_on_select(0)


func close() -> void:
	visible = false
	closed.emit()


func _on_select(index: int) -> void:
	if index < 0 or index >= _view.size():
		return
	var f: Dictionary = _view[index]
	var lines: PackedStringArray = []
	lines.append("[b][color=#e8e0d4]%s[/color][/b]" % str(f.get("title", f.get("id", ""))))
	var source := str(f.get("source", ""))
	if not source.is_empty():
		lines.append("[color=#9a9286]Source: %s[/color]" % source)
	var vlabel := str(f.get("verification_label", ""))
	if f.get("verified", false):
		lines.append("[color=#c4a574]◆ %s[/color]" % (vlabel if not vlabel.is_empty() else "Verified"))
	else:
		lines.append("[color=#9a9286]◇ %s[/color]" % (vlabel if not vlabel.is_empty() else "Unverified — treat as rumour"))
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
	var ccount := int(f.get("contradiction_count", 0))
	if ccount > 0 and contradicts.is_empty():
		lines.append("\n[color=#c45c48]%d noted contradiction(s)[/color]" % ccount)
	detail.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_N):
		close()
		get_viewport().set_input_as_handled()
