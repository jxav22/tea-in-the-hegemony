extends Node
## Headless test runner scene — uses autoloads normally.
## Run: godot --headless --path . res://tests/core/test_runner.tscn


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_loader())
	failures.append_array(_test_flags())
	failures.append_array(_test_chapter_merge())
	failures.append_array(_test_dialogue_flow())
	failures.append_array(_test_save())
	if failures.is_empty():
		print("TEST PASS (5 suites)")
		get_tree().quit(0)
	else:
		for f: String in failures:
			printerr("FAIL: ", f)
		get_tree().quit(1)


func _test_loader() -> PackedStringArray:
	var fails: PackedStringArray = []
	var graph: Dictionary = DialogueLoader.load_by_id("briefing")
	if graph.is_empty():
		fails.append("briefing graph empty")
	var nodes: Dictionary = graph.get("nodes", {}) as Dictionary
	if not (nodes.has("briefing.intro") or nodes.is_empty() == false):
		fails.append("missing briefing nodes")
	var listed: PackedStringArray = DialogueLoader.list_graphs()
	if listed.is_empty():
		fails.append("list_graphs empty")
	print("[test] loader graphs=", listed.size())
	return fails


func _test_flags() -> PackedStringArray:
	var fails: PackedStringArray = []
	FlagStore.clear()
	FlagStore.set_flag(&"met_maris", false)
	if FlagStore.evaluate_condition({"flag": "met_maris", "op": "eq", "value": false}) != true:
		fails.append("eq false failed")
	FlagStore.set_flag(&"met_maris", true)
	if FlagStore.evaluate_conditions([{"flag": "met_maris", "op": "eq", "value": true}]) != true:
		fails.append("conditions true failed")
	if FlagStore.evaluate_condition({"any": [{"flag": "nope", "op": "eq", "value": true}, {"flag": "met_maris", "op": "eq", "value": true}]}) != true:
		fails.append("any failed")
	print("[test] flags ok")
	return fails


func _test_chapter_merge() -> PackedStringArray:
	var fails: PackedStringArray = []
	var merged: Dictionary = ChapterGraph.load_reception()
	var nodes: Dictionary = merged.get("nodes", {}) as Dictionary
	if nodes.size() < 20:
		fails.append("merged chapter too small: %d" % nodes.size())
	if not nodes.has("briefing.intro"):
		fails.append("merged missing briefing.intro")
	if not nodes.has("foyer.arrival"):
		fails.append("merged missing foyer.arrival")
	if str(merged.get("start", "")) != "briefing.intro":
		fails.append("bad start %s" % str(merged.get("start", "")))
	print("[test] chapter merge nodes=", nodes.size())
	return fails


func _test_dialogue_flow() -> PackedStringArray:
	var fails: PackedStringArray = []
	GameState.reset_to_new_game()
	if not DialogueRunner.start_reception():
		fails.append("start_reception")
		return fails
	# Walk Agent B briefing choices by taking index 0 a few times.
	var guard: int = 0
	while DialogueRunner.is_active and guard < 16:
		var node: Dictionary = DialogueRunner.get_current_node()
		var nid: String = str(node.get("id", ""))
		var choices: Array = DialogueRunner.get_visible_choices()
		if choices.is_empty():
			if not DialogueRunner.advance():
				break
		else:
			DialogueRunner.choose_index(0)
		guard += 1
		if nid == "foyer.arrival" or FlagStore.get_flag(&"briefed", false) == true:
			# Reached foyer / briefed — success for this suite.
			break
	if FlagStore.get_flag(&"briefed", false) != true and FlagStore.get_flag(&"briefing_started", false) != true:
		fails.append("briefing flags not set after walk")
	# Effects aliases
	EffectExecutor.apply({"op": "add_memory", "id": "mem_test", "summary": "test", "salience": 1, "tags": ["test"]})
	if not GameState.has_memory(&"mem_test"):
		fails.append("add_memory alias failed")
	EffectExecutor.apply({"op": "set_location", "location": "study_annex"})
	if String(GameState.current_location) != "study":
		fails.append("set_location alias/normalize failed: %s" % String(GameState.current_location))
	print("[test] dialogue flow ok steps=", guard)
	return fails


func _test_save() -> PackedStringArray:
	var fails: PackedStringArray = []
	FlagStore.set_flag(&"save_probe", 42)
	GameState.cover_state["heat"] = 0
	GameState.adjust_heat(7)
	if not SaveService.save_game(2):
		fails.append("save failed")
	FlagStore.set_flag(&"save_probe", 0)
	GameState.cover_state["heat"] = 0
	if not SaveService.load_game(2):
		fails.append("load failed")
	if int(FlagStore.get_flag(&"save_probe", 0)) != 42:
		fails.append("flag not restored")
	if int(GameState.cover_state.get("heat", 0)) != 7:
		fails.append("heat not restored")
	print("[test] save/load ok")
	return fails
