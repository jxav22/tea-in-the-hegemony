extends Control
class_name LocationBase
## Thin location scene — Agent D can restyle; Core keeps talk/nav API.

@export var location_id: StringName = &"foyer"

@onready var _title: Label = %TitleLabel
@onready var _desc: Label = %DescLabel


func _ready() -> void:
	GameState.set_location(location_id)
	SceneRouter.current_location = location_id
	var info: Dictionary = SceneRouter.get_location(location_id)
	if _title:
		_title.text = str(info.get("display_name", location_id))
	if _desc:
		_desc.text = str(info.get("description", ""))


func _on_talk_pressed() -> void:
	SceneRouter.goto_boot()
	await get_tree().process_frame
	await get_tree().process_frame
	DialogueRunner.start("reception_%s" % String(location_id))


func _on_hub_pressed() -> void:
	SceneRouter.goto_reception_hub()
