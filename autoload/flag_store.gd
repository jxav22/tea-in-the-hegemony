extends Node
## Typed flag store for narrative/state conditions.
## Keys are StringName; values are Variant (bool, int, float, String).

signal flag_changed(flag: StringName, value: Variant)

var _flags: Dictionary = {}


func clear() -> void:
	_flags.clear()


func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return _flags.get(flag, default)


func set_flag(flag: StringName, value: Variant) -> void:
	var prev: Variant = _flags.get(flag, null)
	_flags[flag] = value
	if prev != value:
		flag_changed.emit(flag, value)


func toggle_flag(flag: StringName) -> bool:
	var next: bool = not bool(get_flag(flag, false))
	set_flag(flag, next)
	return next


func add_flag(flag: StringName, amount: int = 1) -> int:
	var current: int = int(get_flag(flag, 0))
	var next: int = current + amount
	set_flag(flag, next)
	return next


func evaluate_condition(condition: Dictionary) -> bool:
	## Supports: {flag, op, value} and AND/OR groups via "all" / "any" arrays.
	if condition.has("all"):
		for sub: Variant in condition["all"]:
			if not evaluate_condition(sub as Dictionary):
				return false
		return true
	if condition.has("any"):
		for sub: Variant in condition["any"]:
			if evaluate_condition(sub as Dictionary):
				return true
		return false
	if not condition.has("flag"):
		## Delegate Systems condition kinds (rel/memory/cover/evidence/objective) to GameState.
		if _looks_like_systems_condition(condition):
			if Engine.get_main_loop() != null and GameState != null and GameState.systems != null:
				return GameState.check_systems_condition(condition)
		return true
	var flag: StringName = StringName(str(condition["flag"]))
	var op: String = str(condition.get("op", "eq"))
	var expected: Variant = condition.get("value", true)
	var actual: Variant = get_flag(flag, _default_for(expected))
	match op:
		"eq", "==":
			return actual == expected
		"neq", "!=":
			return actual != expected
		"gt", ">":
			return float(actual) > float(expected)
		"gte", ">=":
			return float(actual) >= float(expected)
		"lt", "<":
			return float(actual) < float(expected)
		"lte", "<=":
			return float(actual) <= float(expected)
		"truthy":
			return bool(actual)
		"falsy":
			return not bool(actual)
		_:
			push_warning("FlagStore: unknown op '%s'" % op)
			return false


func evaluate_conditions(conditions: Array) -> bool:
	if conditions.is_empty():
		return true
	for c: Variant in conditions:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if not evaluate_condition(c as Dictionary):
			return false
	return true


func to_dict() -> Dictionary:
	return _flags.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_flags = data.duplicate(true)


func _default_for(expected: Variant) -> Variant:
	match typeof(expected):
		TYPE_BOOL:
			return false
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
		TYPE_STRING:
			return ""
		_:
			return null


func _looks_like_systems_condition(condition: Dictionary) -> bool:
	if condition.has("kind") or condition.has("type"):
		return true
	for key in [
		"dim", "dimension", "memory", "memory_tag", "knowledge",
		"heat", "heat_band", "blown", "fact", "inconsistency_count",
		"fragment", "contradiction_count", "objective", "char", "character",
	]:
		if condition.has(key):
			return true
	return false
