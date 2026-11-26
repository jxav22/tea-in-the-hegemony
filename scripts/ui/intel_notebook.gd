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
	detail.bbcode_enabled = true
	close_btn.pressed.connect(close)
	list.item_selected.connect(_on_select)
	list.allow_reselect = true


func open_with(fragments: Array) -> void:
	_fragments = fragments.duplicate(true)
	visible = true
	list.clear()
	for f in _fragments:
		var id := str(f.get("id", "fragment"))
		var label := str(f.get("title", f.get("summary", id)))
		var verified := bool(f.get("verified", false))
		var mark := "◆" if verified else "◇"
		list.add_item("%s  %s" % [mark, label])
	if _fragments.is_empty():
		detail.text = "[i]No fragments yet. Listen harder.[/i]"
	else:
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
	lines.append("[b]%s[/b]" % str(f.get("title", f.get("id", ""))))
	if f.has("summary"):
		lines.append(str(f["summary"]))
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
		lines.append("\n[color=#c4a574]Verified[/color]")
	detail.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_N):
		close()
		get_viewport().set_input_as_handled()
