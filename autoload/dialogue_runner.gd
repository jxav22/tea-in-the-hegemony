extends Node
## Dialogue runtime: load graph → present node → evaluate conditions → apply effects → branch.
## Agent D listens to signals for UI; Agent B authors JSON under content/dialogue/.

signal dialogue_started(graph_id: StringName)
signal node_presented(node: Dictionary)
signal choices_available(choices: Array)
signal dialogue_ended(graph_id: StringName, reason: String)
signal effect_applied(effect: Dictionary)

var current_graph: Dictionary = {}
var current_node_id: StringName = &""
var is_active: bool = false
var history: PackedStringArray = []


func start(graph_id: String, start_override: String = "") -> bool:
	var graph: Dictionary = DialogueLoader.load_by_id(graph_id)
	return start_graph(graph, start_override)


func start_path(path: String, start_override: String = "") -> bool:
	var graph: Dictionary = DialogueLoader.load_graph(path)
	return start_graph(graph, start_override)


func start_graph(graph: Dictionary, start_override: String = "") -> bool:
	if graph.is_empty() or not graph.has("nodes"):
		push_error("DialogueRunner: empty graph")
		return false
	current_graph = graph
	history.clear()
	is_active = true
	var start_id: String = start_override if not start_override.is_empty() else str(graph.get("start", ""))
	dialogue_started.emit(StringName(str(graph.get("id", start_id))))
	return goto_node(start_id)


func goto_node(node_id: String) -> bool:
	if not is_active:
		return false
	var nodes: Dictionary = current_graph.get("nodes", {}) as Dictionary
	if not nodes.has(node_id):
		end_dialogue("missing_node:%s" % node_id)
		return false
	var node: Dictionary = (nodes[node_id] as Dictionary).duplicate(true)
	# Skip nodes whose conditions fail (linear next-chain).
	var guard: int = 0
	while not FlagStore.evaluate_conditions(node.get("conditions", []) as Array):
		guard += 1
		if guard > 64:
			end_dialogue("condition_loop")
			return false
		var skip_next: Variant = node.get("next", null)
		if skip_next == null or str(skip_next).is_empty():
			end_dialogue("blocked")
			return false
		node_id = str(skip_next)
		if not nodes.has(node_id):
			end_dialogue("missing_node:%s" % node_id)
			return false
		node = (nodes[node_id] as Dictionary).duplicate(true)
	current_node_id = StringName(node_id)
	history.append(node_id)
	GameState.advance_beat()
	EffectExecutor.apply_all(node.get("effects", []) as Array)
	for e: Variant in node.get("effects", []) as Array:
		if typeof(e) == TYPE_DICTIONARY:
			effect_applied.emit(e as Dictionary)
	FacultyBus.emit_interjections(node.get("faculty_interjections", []) as Array, current_node_id)
	node_presented.emit(node)
	var visible_choices: Array = _visible_choices(node)
	# Agent B router nodes: all authored choice texts start with "[" — auto-pick.
	if _is_router_node(node):
		var picked: Dictionary = _pick_router_choice(visible_choices)
		if picked.is_empty():
			var nodes_map: Dictionary = current_graph.get("nodes", {}) as Dictionary
			if nodes_map.has("ending.default_mixed"):
				call_deferred("goto_node", "ending.default_mixed")
				choices_available.emit([])
				return true
		else:
			call_deferred("_auto_choose", str(picked.get("id", "")))
			choices_available.emit([])
			return true
	if not visible_choices.is_empty():
		choices_available.emit(visible_choices)
	else:
		choices_available.emit([])
	return true


func _auto_choose(choice_id: String) -> void:
	if is_active and not choice_id.is_empty():
		choose(choice_id)


func _is_router_node(node: Dictionary) -> bool:
	var raw: Array = node.get("choices", []) as Array
	if raw.is_empty():
		return false
	for ch: Variant in raw:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var text: String = str((ch as Dictionary).get("text", "")).strip_edges()
		if not text.begins_with("["):
			return false
	return true


func _pick_router_choice(choices: Array) -> Dictionary:
	if choices.is_empty():
		return {}
	var chapter: Dictionary = ContentIndex.load_chapter("the_reception")
	var priority: Array = chapter.get("ending_priority", []) as Array
	if not priority.is_empty():
		for end_id: Variant in priority:
			var want: String = str(end_id)
			for ch: Variant in choices:
				var choice: Dictionary = ch as Dictionary
				var next_id: String = str(choice.get("next", ""))
				if want in next_id:
					return choice
	return choices[0] as Dictionary


func advance() -> bool:
	## Continue along node.next when there are no choices (or after auto lines).
	if not is_active:
		return false
	var node: Dictionary = get_current_node()
	if node.is_empty():
		end_dialogue("no_node")
		return false
	var choices: Array = _visible_choices(node)
	if not choices.is_empty():
		return false
	var next_id: Variant = node.get("next", null)
	if next_id == null or str(next_id).is_empty():
		end_dialogue("completed")
		return false
	return goto_node(str(next_id))


func choose(choice_id: String) -> bool:
	if not is_active:
		return false
	var node: Dictionary = get_current_node()
	for ch: Variant in _visible_choices(node):
		var choice: Dictionary = ch as Dictionary
		if str(choice.get("id", "")) == choice_id:
			EffectExecutor.apply_all(choice.get("effects", []) as Array)
			for e: Variant in choice.get("effects", []) as Array:
				if typeof(e) == TYPE_DICTIONARY:
					effect_applied.emit(e as Dictionary)
			var next_id: Variant = choice.get("next", null)
			if next_id == null or str(next_id).is_empty():
				end_dialogue("completed")
				return true
			return goto_node(str(next_id))
	push_warning("DialogueRunner: choice not found or locked: %s" % choice_id)
	return false


func choose_index(index: int) -> bool:
	var node: Dictionary = get_current_node()
	var choices: Array = _visible_choices(node)
	if index < 0 or index >= choices.size():
		return false
	return choose(str((choices[index] as Dictionary).get("id", "")))


func get_current_node() -> Dictionary:
	if not is_active:
		return {}
	var nodes: Dictionary = current_graph.get("nodes", {}) as Dictionary
	return (nodes.get(String(current_node_id), {}) as Dictionary).duplicate(true)


func get_visible_choices() -> Array:
	return _visible_choices(get_current_node())


func end_dialogue(reason: String = "ended") -> void:
	var gid: StringName = StringName(str(current_graph.get("id", "")))
	is_active = false
	current_node_id = &""
	FacultyBus.clear()
	dialogue_ended.emit(gid, reason)


func _visible_choices(node: Dictionary) -> Array:
	var out: Array = []
	for ch: Variant in node.get("choices", []) as Array:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = ch as Dictionary
		var conds: Array = choice.get("conditions", []) as Array
		if FlagStore.evaluate_conditions(conds):
			out.append(choice)
	return out
