extends Node
## Scene / location router for Reception areas and dialogue overlays.
## Agent D may replace location scenes; keep IDs stable.

signal location_changed(location_id: StringName, previous: StringName)
signal scene_change_requested(path: String)
signal scene_changed(path: String)

const LOCATIONS: Dictionary = {
	"foyer": {
		"id": "foyer",
		"display_name": "Foyer",
		"scene": "res://scenes/locations/foyer.tscn",
		"description": "Marble, coats, and first impressions.",
		"dialogue": "foyer",
		"start_node": "foyer.arrival",
	},
	"salon": {
		"id": "salon",
		"display_name": "Salon",
		"scene": "res://scenes/locations/salon.tscn",
		"description": "Conversation as bloodsport, served with champagne.",
		"dialogue": "salon_intro",
		"start_node": "salon.enter",
	},
	"terrace": {
		"id": "terrace",
		"display_name": "Terrace",
		"scene": "res://scenes/locations/terrace.tscn",
		"description": "Night air and overheard policy.",
		"dialogue": "political",
		"start_node": "political.hook",
	},
	"study": {
		"id": "study",
		"display_name": "Study Annex",
		"scene": "res://scenes/locations/study.tscn",
		"description": "Books, ledgers, and unlocked drawers that shouldn't be.",
		"dialogue": "study_cover",
		"start_node": "study.approach",
	},
	"cloakroom": {
		"id": "cloakroom",
		"display_name": "Cloakroom",
		"scene": "res://scenes/locations/cloakroom.tscn",
		"description": "Pockets, badges, and Clerk Moth's jurisdiction.",
		"dialogue": "reception_cloakroom",
		"start_node": "",
	},
}

## Narrative aliases from Agent B chapter manifest.
const LOCATION_ALIASES: Dictionary = {
	"study_annex": "study",
	"safehouse_briefing": "foyer",
	"safehouse_debrief": "foyer",
	"voss_house_foyer": "foyer",
}

const BOOT_SCENE: String = "res://scenes/main/boot.tscn"
const RECEPTION_HUB: String = "res://scenes/main/reception_hub.tscn"
const DIALOGUE_OVERLAY: String = "res://scenes/main/dialogue_overlay.tscn"

var current_location: StringName = &"foyer"
var current_scene_path: String = ""


func get_location_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for key: Variant in LOCATIONS.keys():
		ids.append(str(key))
	return ids


func normalize_location_id(location_id: StringName) -> StringName:
	var raw: String = String(location_id)
	if LOCATION_ALIASES.has(raw):
		return StringName(str(LOCATION_ALIASES[raw]))
	return location_id


func get_location(location_id: StringName) -> Dictionary:
	var normalized: StringName = normalize_location_id(location_id)
	return LOCATIONS.get(String(normalized), {}) as Dictionary


func dialogue_for(location_id: StringName) -> Dictionary:
	## Returns {graph_id, start_node} for location talk buttons.
	var info: Dictionary = get_location(location_id)
	return {
		"graph_id": str(info.get("dialogue", "foyer")),
		"start_node": str(info.get("start_node", "")),
	}


func set_location(location_id: StringName, change_scene_file: bool = false) -> bool:
	## Soft location update (dialogue effects). Optionally swap scenes.
	location_id = normalize_location_id(location_id)
	var info: Dictionary = get_location(location_id)
	if info.is_empty():
		push_warning("SceneRouter: unknown location %s" % location_id)
		return false
	var previous: StringName = current_location
	current_location = location_id
	GameState.set_location(location_id)
	location_changed.emit(location_id, previous)
	if not change_scene_file:
		return true
	var path: String = str(info.get("scene", RECEPTION_HUB))
	if not ResourceLoader.exists(path):
		path = RECEPTION_HUB
	return change_scene(path)


func goto_location(location_id: StringName) -> bool:
	return set_location(location_id, true)


func goto_reception_hub() -> bool:
	return change_scene(RECEPTION_HUB)


func goto_boot() -> bool:
	return change_scene(BOOT_SCENE)


func change_scene(path: String) -> bool:
	if path.is_empty():
		return false
	scene_change_requested.emit(path)
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: failed to load %s (err %d)" % [path, err])
		return false
	current_scene_path = path
	scene_changed.emit(path)
	return true


func adjacent_for(location_id: StringName) -> PackedStringArray:
	## Soft graph for Reception — all rooms reachable; cloakroom gated by flag later.
	match String(location_id):
		"foyer":
			return PackedStringArray(["salon", "cloakroom", "terrace"])
		"salon":
			return PackedStringArray(["foyer", "terrace", "study"])
		"terrace":
			return PackedStringArray(["foyer", "salon"])
		"study":
			return PackedStringArray(["salon"])
		"cloakroom":
			return PackedStringArray(["foyer"])
		_:
			return PackedStringArray(["foyer"])
