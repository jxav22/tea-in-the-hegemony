extends Node
## Headless test runner scene — uses autoloads normally.
## Run: godot --headless --path . res://tests/core/test_runner.tscn


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	failures.append_array(_test_loader())
	failures.append_array(_test_flags())
	failures.append_array(_test_dialogue_flow())
	failures.append_array(_test_save())
	if failures.is_empty():
		print("TEST PASS (4 suites)")
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
	if not (graph.get("nodes", {}) as Dictionary).has("briefing.intro"):
		fails.append("missing briefing.intro")
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


func _test_dialogue_flow() -> PackedStringArray:
	var fails: PackedStringArray = []
	GameState.reset_to_new_game()
	ContentIndex.bootstrap_chapter(&"reception")
	if not DialogueRunner.start("briefing"):
		fails.append("start briefing")
		return fails
	# Prefer first visible choice — works for Core stubs (c_understood) and
	# Narrative reception/briefing.json (briefing.intro.ready / .dread).
	if not _drive_until_flag(&"briefed", 24):
		# Core stub path sets briefed via later nodes; Narrative sets at briefing.exit.
		fails.append("briefed flag not set after briefing drive")
	# Core-only flag may be absent when Narrative pack shadows briefing.json — soft check.
	var has_priority: bool = FlagStore.get_flag(&"priority_mission", false) == true
	var used_narrative_briefing: bool = DialogueLoader.load_by_id("briefing").get("source", "").find("reception/") >= 0
	if not used_narrative_briefing and not has_priority:
		fails.append("priority_mission not set")
	# Location graph still uses Core stub ids at content/dialogue/reception_salon.json
	if not DialogueRunner.start("reception_salon"):
		fails.append("start salon")
	else:
		_drive_choices(["c_approach", "c_honest"], 8)
		if FlagStore.get_flag(&"met_maris", false) != true:
			fails.append("met_maris not set")
	if fails.is_empty():
		print("[test] dialogue flow ok")
	else:
		print("[test] dialogue flow had failures")
	return fails


func _drive_choices(preferred_ids: Array, max_steps: int) -> void:
	var guard: int = 0
	while DialogueRunner.is_active and guard < max_steps:
		var chose: bool = false
		for cid: Variant in preferred_ids:
			if DialogueRunner.choose(str(cid)):
				chose = true
				break
		if not chose:
			var choices: Array = DialogueRunner.get_visible_choices()
			if choices.is_empty():
				DialogueRunner.advance()
			else:
				DialogueRunner.choose_index(0)
		guard += 1


func _drive_until_flag(flag: StringName, max_steps: int) -> bool:
	var guard: int = 0
	while DialogueRunner.is_active and guard < max_steps:
		if FlagStore.get_flag(flag, false) == true:
			return true
		var choices: Array = DialogueRunner.get_visible_choices()
		if choices.is_empty():
			DialogueRunner.advance()
		else:
			DialogueRunner.choose_index(0)
		guard += 1
	# Drain remaining linear nodes
	var extra: int = 0
	while DialogueRunner.is_active and extra < 8:
		DialogueRunner.advance()
		extra += 1
	return FlagStore.get_flag(flag, false) == true


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
