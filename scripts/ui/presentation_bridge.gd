class_name PresentationBridge
extends Node
## Thin adapter so Core can drive UI without Presentation owning dialogue state.
## Attach beside GameHUD or call from an Autoload once Core lands.

@export var hud_path: NodePath
var hud: GameHUD


func _ready() -> void:
	if hud == null and hud_path != NodePath(""):
		hud = get_node_or_null(hud_path) as GameHUD


func bind_hud(h: GameHUD) -> void:
	hud = h


func line(speaker_id: String, display: String, text: String, expression: String = "neutral") -> void:
	if hud:
		hud.present_line(speaker_id, display, text, expression)


func choices(items: Array) -> void:
	if hud:
		hud.present_choices(items)


func faculty(name: String, text: String) -> void:
	if hud:
		hud.present_faculty(name, text)


func objectives(items: Array) -> void:
	if hud:
		hud.set_objectives(items)


func background(location_id: String) -> void:
	if hud:
		hud.set_background(location_id)


func notebook(fragments: Array) -> void:
	if hud:
		hud.open_notebook(fragments)


func profile(data: Dictionary) -> void:
	if hud:
		hud.open_profile(data)
