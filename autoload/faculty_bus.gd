extends Node
## Internal faculty monologue bus. Faculties disagree; player may ignore advice.
## Agent D binds UI panels to faculty_spoke / faculty_cleared.

signal faculty_spoke(faculty: StringName, text: String, weight: float, node_id: StringName)
signal faculty_cleared()
signal faculty_selected(faculty: StringName) ## Optional player acknowledgment

const FACULTY_NAMES: PackedStringArray = [
	"Analysis", "Tradecraft", "Composure", "Empathy", "Improvisation", "Idealism", "Insecurity"
]

var last_interjections: Array = [] ## Array of {faculty, text, weight}
var muted: Dictionary = {} ## faculty -> bool


func is_known(faculty: StringName) -> bool:
	return String(faculty) in FACULTY_NAMES


func set_muted(faculty: StringName, is_muted: bool) -> void:
	muted[faculty] = is_muted


func clear() -> void:
	last_interjections.clear()
	faculty_cleared.emit()


func emit_interjections(interjections: Array, node_id: StringName = &"") -> void:
	clear()
	if interjections.is_empty():
		return
	var sorted: Array = interjections.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float((a as Dictionary).get("weight", 1.0)) > float((b as Dictionary).get("weight", 1.0))
	)
	for entry: Variant in sorted:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry as Dictionary
		var faculty: StringName = StringName(str(d.get("faculty", "")))
		if not is_known(faculty):
			continue
		if bool(muted.get(faculty, false)):
			continue
		var text: String = str(d.get("text", ""))
		var weight: float = float(d.get("weight", 1.0))
		var payload: Dictionary = {"faculty": String(faculty), "text": text, "weight": weight}
		last_interjections.append(payload)
		faculty_spoke.emit(faculty, text, weight, node_id)


func acknowledge(faculty: StringName) -> void:
	faculty_selected.emit(faculty)


## Stub hook for Agent C social systems — return current panel texts.
func get_active_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: Variant in last_interjections:
		out.append(str((entry as Dictionary).get("text", "")))
	return out
