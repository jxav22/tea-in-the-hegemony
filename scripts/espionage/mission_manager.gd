class_name MissionManager
extends RefCounted
## Mission / objective orchestration. DialogueRunner effect op: "objective".
##
## Effects:
##   {"op":"objective","action":"activate","id":"obj.contact_maris"}
##   {"op":"objective","action":"complete","id":"obj.contact_maris","beat":"..."}
##   {"op":"objective","action":"fail","id":"obj.maintain_cover","beat":"..."}
##   {"op":"objective","action":"reveal","id":"obj.optional_help_maris"}
##   {"op":"objective","action":"evaluate"}  ## re-check complete_when / fail_when

signal objective_revealed(objective_id: String)
signal objective_activated(objective_id: String)
signal objective_completed(objective_id: String)
signal objective_failed(objective_id: String)
signal mission_status_changed(mission_id: String, status: String)

var mission_id: String = ""
var mission_title: String = ""
var chapter_id: String = ""
var status: String = "inactive" ## inactive | active | debrief | closed
var objectives: Dictionary = {} ## id -> IntelObjective
var flags_ref: Callable ## optional () -> Dictionary for flag checks
var relationships: RelationshipManager
var cover: CoverManager
var evidence: EvidenceManager
var _presentation: EspionagePresentation
var meta: Dictionary = {} ## trade-off tags, ending hints, etc.


func _init() -> void:
	_presentation = EspionagePresentation.new()


func bind(
	rel: RelationshipManager = null,
	cover_mgr: CoverManager = null,
	evidence_mgr: EvidenceManager = null,
	flags_callable: Callable = Callable()
) -> void:
	relationships = rel
	cover = cover_mgr
	evidence = evidence_mgr
	flags_ref = flags_callable


func load_mission(data: Dictionary) -> void:
	mission_id = str(data.get("id", data.get("mission_id", "")))
	mission_title = str(data.get("title", ""))
	chapter_id = str(data.get("chapter_id", ""))
	status = str(data.get("status", "inactive"))
	meta = data.get("meta", {}).duplicate(true)
	objectives.clear()
	for raw in data.get("objectives", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var obj := IntelObjective.new(raw)
		if obj.mission_id == "":
			obj.mission_id = mission_id
		objectives[obj.id] = obj


func load_from_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ERR_CANT_OPEN
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	load_mission(parsed)
	return OK


func get_objective(objective_id: String) -> IntelObjective:
	return objectives.get(objective_id) as IntelObjective


func apply_effect(effect: Dictionary) -> Dictionary:
	var action := str(effect.get("action", "activate"))
	var oid := str(effect.get("id", effect.get("objective", "")))
	var beat := str(effect.get("beat", ""))
	match action:
		"activate":
			return activate(oid, beat)
		"complete":
			return complete(oid, beat)
		"fail":
			return fail(oid, beat)
		"reveal":
			return reveal(oid)
		"abandon":
			return abandon(oid, beat)
		"evaluate":
			return {"updated": evaluate_all(beat)}
		"start_mission":
			return start_mission()
		"close_mission":
			return close_mission(str(effect.get("status", "closed")))
		_:
			push_warning("Unknown objective action: %s" % action)
			return {}


func start_mission() -> Dictionary:
	status = "active"
	mission_status_changed.emit(mission_id, status)
	# Auto-activate objectives that start visible.
	for oid in objectives.keys():
		var obj: IntelObjective = objectives[oid]
		if obj.status == IntelObjective.STATUS_ACTIVE:
			objective_activated.emit(oid)
		elif obj.status == IntelObjective.STATUS_HIDDEN and obj.reveals_when.is_empty():
			# Keep hidden until revealed.
			pass
	return {"mission_id": mission_id, "status": status}


func close_mission(new_status: String = "closed") -> Dictionary:
	status = new_status
	mission_status_changed.emit(mission_id, status)
	return {"mission_id": mission_id, "status": status}


func reveal(objective_id: String) -> Dictionary:
	var obj := get_objective(objective_id)
	if obj == null:
		return {"ok": false}
	if obj.status == IntelObjective.STATUS_HIDDEN:
		obj.status = IntelObjective.STATUS_OPTIONAL if not obj.required else IntelObjective.STATUS_ACTIVE
		objective_revealed.emit(objective_id)
		objective_activated.emit(objective_id)
	return {"ok": true, "id": objective_id, "status": obj.status}


func activate(objective_id: String, _beat: String = "") -> Dictionary:
	var obj := get_objective(objective_id)
	if obj == null:
		return {"ok": false}
	if obj.is_terminal():
		return {"ok": true, "id": objective_id, "status": obj.status, "already_terminal": true}
	obj.status = IntelObjective.STATUS_ACTIVE if obj.required else IntelObjective.STATUS_OPTIONAL
	objective_activated.emit(objective_id)
	return {"ok": true, "id": objective_id, "status": obj.status}


func complete(objective_id: String, beat: String = "") -> Dictionary:
	var obj := get_objective(objective_id)
	if obj == null:
		return {"ok": false}
	obj.status = IntelObjective.STATUS_COMPLETE
	obj.completed_at_beat = beat
	objective_completed.emit(objective_id)
	return {"ok": true, "id": objective_id, "status": obj.status}


func fail(objective_id: String, beat: String = "") -> Dictionary:
	var obj := get_objective(objective_id)
	if obj == null:
		return {"ok": false}
	obj.status = IntelObjective.STATUS_FAILED
	obj.failed_at_beat = beat
	objective_failed.emit(objective_id)
	return {"ok": true, "id": objective_id, "status": obj.status}


func abandon(objective_id: String, beat: String = "") -> Dictionary:
	var obj := get_objective(objective_id)
	if obj == null:
		return {"ok": false}
	obj.status = IntelObjective.STATUS_ABANDONED
	obj.failed_at_beat = beat
	return {"ok": true, "id": objective_id, "status": obj.status}


func evaluate_all(beat: String = "") -> Array[Dictionary]:
	var updates: Array[Dictionary] = []
	for oid in objectives.keys():
		var obj: IntelObjective = objectives[oid]
		if obj.status == IntelObjective.STATUS_HIDDEN:
			if _rules_match(obj.reveals_when):
				updates.append(reveal(oid))
		if obj.is_trackable():
			if _rules_match(obj.fail_when):
				updates.append(fail(oid, beat))
			elif _rules_match(obj.complete_when):
				updates.append(complete(oid, beat))
	return updates


func _rules_match(rules: Array[Dictionary]) -> bool:
	if rules.is_empty():
		return false
	# All rules must match (AND). Nested any/all supported via "any"/"all" keys.
	for rule in rules:
		if not _rule_match(rule):
			return false
	return true


func _rule_match(rule: Dictionary) -> bool:
	if rule.has("any"):
		for sub in rule["any"]:
			if typeof(sub) == TYPE_DICTIONARY and _rule_match(sub):
				return true
		return false
	if rule.has("all"):
		for sub in rule["all"]:
			if typeof(sub) != TYPE_DICTIONARY or not _rule_match(sub):
				return false
		return true

	var kind := str(rule.get("kind", rule.get("type", "")))
	match kind:
		"flag":
			return _check_flag(rule)
		"rel", "relationship":
			return relationships != null and relationships.check_condition(rule)
		"memory":
			return relationships != null and relationships.check_condition(rule)
		"cover":
			return cover != null and cover.check_condition(rule)
		"evidence":
			return evidence != null and evidence.check_condition(rule)
		"objective":
			var other := get_objective(str(rule.get("id", "")))
			if other == null:
				return false
			var want := str(rule.get("status", IntelObjective.STATUS_COMPLETE))
			return other.status == want
		"heat_band":
			return cover != null and cover.check_condition(rule)
		_:
			# Infer from fields.
			if rule.has("flag"):
				return _check_flag(rule)
			if rule.has("dim") or rule.has("memory") or rule.has("knowledge"):
				return relationships != null and relationships.check_condition(rule)
			if rule.has("fragment") or rule.has("contradiction_count"):
				return evidence != null and evidence.check_condition(rule)
			if rule.has("heat") or rule.has("heat_band") or rule.has("blown") or rule.has("fact"):
				return cover != null and cover.check_condition(rule)
			if rule.has("objective") or (rule.has("id") and objectives.has(str(rule.get("id", "")))):
				var oid := str(rule.get("objective", rule.get("id", "")))
				var other2 := get_objective(oid)
				return other2 != null and other2.status == str(rule.get("status", IntelObjective.STATUS_COMPLETE))
	return false


func _check_flag(rule: Dictionary) -> bool:
	if not flags_ref.is_valid():
		return false
	var flags: Variant = flags_ref.call()
	if typeof(flags) != TYPE_DICTIONARY:
		return false
	var flag := str(rule.get("flag", ""))
	var op := str(rule.get("op", "eq"))
	var actual = flags.get(flag, null)
	var expected = rule.get("value", true)
	match op:
		"neq", "not":
			return actual != expected
		"truthy":
			return bool(actual)
		_:
			return actual == expected


func required_complete() -> bool:
	for oid in objectives.keys():
		var obj: IntelObjective = objectives[oid]
		if obj.required and obj.status != IntelObjective.STATUS_COMPLETE:
			return false
	return true


func required_failed() -> bool:
	for oid in objectives.keys():
		var obj: IntelObjective = objectives[oid]
		if obj.required and obj.status == IntelObjective.STATUS_FAILED:
			return true
	return false


func trackable_objectives() -> Array[IntelObjective]:
	var out: Array[IntelObjective] = []
	for oid in objectives.keys():
		var obj: IntelObjective = objectives[oid]
		if obj.is_trackable() or obj.status == IntelObjective.STATUS_COMPLETE:
			out.append(obj)
	out.sort_custom(func(a: IntelObjective, b: IntelObjective) -> bool:
		return a.priority < b.priority
	)
	return out


func check_condition(cond: Dictionary) -> bool:
	var oid := str(cond.get("id", cond.get("objective", "")))
	if oid == "":
		return false
	var obj := get_objective(oid)
	if obj == null:
		return false
	var op := str(cond.get("op", "eq"))
	var status_want := str(cond.get("status", obj.status))
	if cond.has("status"):
		return obj.status == status_want if op != "neq" else obj.status != status_want
	return true


func present(reveal_raw: bool = false) -> Dictionary:
	return _presentation.present_mission(self, reveal_raw)


func build_report(beat: String = "debrief") -> MissionReport:
	var report := MissionReport.new()
	report.mission_id = mission_id
	report.chapter_id = chapter_id
	report.generated_at_beat = beat
	report.collect_from(self, relationships, cover, evidence)
	return report


func to_save() -> Dictionary:
	var objs := {}
	for oid in objectives.keys():
		objs[str(oid)] = (objectives[oid] as IntelObjective).to_dict()
	return {
		"mission_id": mission_id,
		"mission_title": mission_title,
		"chapter_id": chapter_id,
		"status": status,
		"meta": meta.duplicate(true),
		"objectives": objs,
	}


func load_save(data: Dictionary) -> void:
	mission_id = str(data.get("mission_id", mission_id))
	mission_title = str(data.get("mission_title", mission_title))
	chapter_id = str(data.get("chapter_id", chapter_id))
	status = str(data.get("status", status))
	meta = data.get("meta", {}).duplicate(true)
	var objs: Dictionary = data.get("objectives", {})
	for oid in objs.keys():
		if objectives.has(str(oid)):
			(objectives[oid] as IntelObjective).from_dict(objs[oid])
		else:
			objectives[str(oid)] = IntelObjective.new(objs[oid])
