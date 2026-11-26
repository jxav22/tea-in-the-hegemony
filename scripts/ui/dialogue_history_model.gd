class_name DialogueHistoryModel
extends RefCounted
## Rolling dialogue history for the presentation layer.

signal entry_added(entry: Dictionary)

var entries: Array[Dictionary] = []
var max_entries: int = 200


func clear() -> void:
	entries.clear()


func add_line(speaker: String, text: String, tags: Array = []) -> void:
	var entry := {
		"speaker": speaker,
		"text": text,
		"tags": tags.duplicate(),
		"ts": Time.get_ticks_msec(),
	}
	entries.append(entry)
	while entries.size() > max_entries:
		entries.pop_front()
	entry_added.emit(entry)


func add_choice(choice_text: String, intent: String = "") -> void:
	add_line("You", choice_text, ["choice", intent])


func as_richtext() -> String:
	var parts: PackedStringArray = []
	for e in entries:
		var speaker := str(e.get("speaker", "?"))
		var text := str(e.get("text", ""))
		var tags: Array = e.get("tags", [])
		if "choice" in tags:
			parts.append("[color=#c4a574]› %s[/color] [i][color=#9a9286]%s[/color][/i]" % [text, speaker])
		elif "faculty" in tags:
			parts.append("[color=#d2aa50][%s][/color] [i]%s[/i]" % [speaker, text])
		else:
			parts.append("[b][color=#5b8a7a]%s[/color][/b]\n%s" % [speaker, text])
	return "\n\n".join(parts)
