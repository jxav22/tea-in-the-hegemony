class_name SystemsBridge
extends RefCounted
## Thin bridge for Core GameState / DialogueRunner.
## Wire: GameState.systems = SystemsBootstrap.create_default()
## Then DialogueRunner calls systems.apply_effect(effect) / systems.check_condition(cond).
##
## Supported effect ops: rel, memory, evidence, cover, objective, knowledge
## (plus aliases relationship, intel_objective)

signal effect_applied(op: String, result: Dictionary)

var relationships: RelationshipManager
var memories: MemoryManager
var cover: CoverManager
var evidence: EvidenceManager
var mission: MissionManager
var flags: Dictionary = {} ## optional local flag bag if Core has not bound yet
var _flag_provider: Callable = Callable()


func _init() -> void:
	relationships = RelationshipManager.new()
	memories = MemoryManager.new(relationships)
	cover = CoverManager.new()
	cover.bind_relationships(relationships)
	evidence = EvidenceManager.new()
	mission = MissionManager.new()
	mission.bind(relationships, cover, evidence, Callable(self, "get_flags"))


func get_flags() -> Dictionary:
	if _flag_provider.is_valid():
		var provided: Variant = _flag_provider.call()
		if typeof(provided) == TYPE_DICTIONARY:
			return provided as Dictionary
	return flags


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	## When bound to Core, also write FlagStore (live condition source).
	if _flag_provider.is_valid():
		FlagStore.set_flag(StringName(flag), value)


## Core may replace the flag bag with its own GameState.flags reference.
func bind_flags(flag_dict: Dictionary) -> void:
	flags = flag_dict
	mission.bind(relationships, cover, evidence, Callable(self, "get_flags"))


## Preferred Core wiring: live FlagStore via Callable returning Dictionary.
func bind_flag_provider(provider: Callable) -> void:
	_flag_provider = provider
	mission.bind(relationships, cover, evidence, Callable(self, "get_flags"))


func apply_effect(effect: Dictionary) -> Dictionary:
	var op := str(effect.get("op", ""))
	var result := {}
	match op:
		"rel", "relationship":
			result = relationships.apply_effect(effect)
		"memory":
			var entry: MemoryEntry = memories.apply_effect(effect)
			result = entry.to_dict() if entry != null else {}
		"evidence":
			result = evidence.apply_effect(effect)
		"cover":
			result = cover.apply_effect(effect)
		"objective", "intel_objective":
			result = mission.apply_effect(effect)
		"knowledge":
			var kid := str(effect.get("char", effect.get("character", "")))
			var kflag := str(effect.get("flag", effect.get("knowledge", "")))
			var kval: Variant = effect.get("value", true)
			if kid == "" or kflag == "":
				result = {"ok": false, "error": "knowledge_missing_fields"}
			else:
				relationships.set_knowledge(kid, kflag, kval)
				result = {"ok": true, "char": kid, "flag": kflag, "value": kval}
		"set_flag":
			set_flag(str(effect.get("flag", "")), effect.get("value", true))
			result = {"flag": effect.get("flag"), "value": effect.get("value", true)}
		_:
			return {"ok": false, "error": "unknown_op", "op": op}
	effect_applied.emit(op, result)
	# Re-evaluate mission rules after any mutating op.
	if mission != null and op in ["rel", "relationship", "memory", "evidence", "cover", "set_flag", "knowledge"]:
		mission.evaluate_all(str(effect.get("beat", "")))
	return result


func apply_effects(effects: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in effects:
		if typeof(e) == TYPE_DICTIONARY:
			out.append(apply_effect(e))
	return out


func check_condition(cond: Dictionary) -> bool:
	## Route by explicit kind or by field presence.
	var kind := str(cond.get("kind", cond.get("type", "")))
	match kind:
		"rel", "relationship":
			return relationships.check_condition(cond)
		"memory":
			return memories.check_condition(cond)
		"cover":
			return cover.check_condition(cond)
		"evidence":
			return evidence.check_condition(cond)
		"objective":
			return mission.check_condition(cond)
		"flag":
			var flag := str(cond.get("flag", ""))
			var op := str(cond.get("op", "eq"))
			var actual = flags.get(flag, null)
			var expected = cond.get("value", true)
			return actual != expected if op in ["neq", "not"] else actual == expected

	if cond.has("memory") or cond.has("memory_tag") or cond.has("dim") or cond.has("dimension") or cond.has("knowledge"):
		return relationships.check_condition(cond)
	if cond.has("heat") or cond.has("heat_band") or cond.has("blown") or cond.has("fact") or cond.has("inconsistency_count"):
		return cover.check_condition(cond)
	if cond.has("fragment") or cond.has("contradiction_count"):
		return evidence.check_condition(cond)
	if cond.has("objective") or (cond.has("id") and mission.get_objective(str(cond.get("id", ""))) != null):
		return mission.check_condition(cond)
	if cond.has("flag"):
		var f := str(cond["flag"])
		var opf := str(cond.get("op", "eq"))
		var act = flags.get(f, null)
		var exp = cond.get("value", true)
		return act != exp if opf in ["neq", "not"] else act == exp
	return false


func check_conditions(conds: Array) -> bool:
	## AND across list.
	for c in conds:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if not check_condition(c):
			return false
	return true


## Presentation façade for Agent D UI.
func present_character(character_id: String, reveal_raw: bool = false) -> Dictionary:
	return relationships.present(character_id, reveal_raw)


func present_cover(reveal_raw: bool = false) -> Dictionary:
	return cover.present(reveal_raw)


func present_evidence(reveal_raw: bool = false) -> Array[Dictionary]:
	return evidence.present(reveal_raw)


func present_mission(reveal_raw: bool = false) -> Dictionary:
	return mission.present(reveal_raw)


func present_debrief(beat: String = "debrief", reveal_raw: bool = false) -> Dictionary:
	var report := mission.build_report(beat)
	var flags := PathFlagSync.sync_from_report(report, self, true)
	var out := report.present(reveal_raw)
	out["path_flags"] = flags
	return out


## Push Systems state into Narrative debrief FlagStore keys (got_fragment, ending_id, …).
func sync_path_flags(force_ending: bool = false) -> Dictionary:
	return PathFlagSync.sync_from_systems(self, force_ending)


func to_save() -> Dictionary:
	return {
		"rels": relationships.to_save(),
		"cover_state": cover.to_save(),
		"evidence": evidence.to_save(),
		"objectives": mission.to_save(),
		"flags": flags.duplicate(true),
	}


func load_save(data: Dictionary) -> void:
	if data.has("rels"):
		relationships.load_save(data["rels"])
	if data.has("cover_state"):
		cover.load_save(data["cover_state"])
	if data.has("evidence"):
		evidence.load_save(data["evidence"])
	if data.has("objectives"):
		mission.load_save(data["objectives"])
	if data.has("flags"):
		flags = data["flags"].duplicate(true)
	# Restore Narrative cover/path flags after load (FlagStore may be empty).
	CoverFlagSync.sync_from_manager(cover)


## Load Reception (or other) content packs.
func load_reception_content(
	mission_path: String = "res://content/missions/reception.json",
	evidence_path: String = "res://content/evidence/reception_evidence.json"
) -> Dictionary:
	var mission_err := mission.load_from_file(mission_path)
	var evidence_err := evidence.load_from_file(evidence_path)
	return {
		"mission_ok": mission_err == OK,
		"evidence_ok": evidence_err == OK,
		"mission_error": mission_err,
		"evidence_error": evidence_err,
	}
