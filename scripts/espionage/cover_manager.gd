class_name CoverManager
extends RefCounted
## Cover identity ops for DialogueRunner effect op "cover".
##
## Effects:
##   {"op":"cover","action":"assert","key":"employer","value":"Ministry Trade Liaison Office","beat":"...","witness":"maris_quell"}
##   {"op":"cover","action":"slip","key":"real_name","value":"Cassian Vale","beat":"...","witness":"taly_renn","heat":15}
##   {"op":"cover","action":"adjust_heat","delta":10}
##   {"op":"cover","action":"repair","delta":-8,"beat":"..."}
##   {"op":"cover","action":"blow"}

signal heat_changed(new_heat: int, band: String, reason: String)
signal inconsistency_recorded(key: String, detail: Dictionary)
signal cover_blown(reason: String)
signal cover_repaired(new_heat: int, still_blown: bool)

## Aligned with Core GameState.adjust_heat blow threshold.
const HEAT_BLOW_THRESHOLD := 80
const HEAT_HIGH_THRESHOLD := 55
const HEAT_STRAINED_THRESHOLD := 30

var cover: CoverIdentity
## Optional hook: RelationshipManager for witness suspicion bumps.
var relationships: RelationshipManager
var _presentation: EspionagePresentation
var _sync_flags: bool = true


func _init(initial: CoverIdentity = null) -> void:
	cover = initial if initial != null else CoverIdentity.default_cassian_orth()
	_presentation = EspionagePresentation.new()


func bind_relationships(rel: RelationshipManager) -> void:
	relationships = rel


func apply_effect(effect: Dictionary) -> Dictionary:
	var action := str(effect.get("action", "assert"))
	match action:
		"assert":
			return _assert_fact(effect)
		"slip":
			return _slip(effect)
		"adjust_heat":
			return adjust_heat(int(effect.get("delta", 0)), str(effect.get("reason", "adjust")))
		"repair":
			return repair(effect)
		"blow":
			return blow(str(effect.get("reason", "explicit")))
		"escalate":
			## Chain helper: slip-or-heat then auto-evaluate blow.
			return _escalate(effect)
		"set_fact":
			return _assert_fact(effect)
		_:
			push_warning("Unknown cover action: %s" % action)
			return {}


func repair(effect: Dictionary = {}) -> Dictionary:
	## Explicit repair cools heat. Never silently un-blows; use force_unblow.
	var repair_delta := int(effect.get("delta", -5))
	if repair_delta > 0:
		repair_delta = -repair_delta
	var reason := "repair:%s" % str(effect.get("reason", effect.get("beat", "")))
	var out := adjust_heat(repair_delta, reason)
	if bool(effect.get("force_unblow", false)) and cover.blown and cover.heat < HEAT_BLOW_THRESHOLD:
		cover.blown = false
		out["unblown"] = true
		_emit_flag_sync()
	cover_repaired.emit(cover.heat, cover.blown)
	out["repaired"] = true
	out["blown"] = cover.blown
	return out


func _escalate(effect: Dictionary) -> Dictionary:
	## Typical chain: optional slip, then heat bump, sync flags, maybe blow.
	var results: Array = []
	if effect.has("key") or str(effect.get("slip", "")) != "":
		var slip_effect := effect.duplicate(true)
		slip_effect["action"] = "slip"
		if effect.has("slip") and typeof(effect["slip"]) == TYPE_DICTIONARY:
			for k in effect["slip"].keys():
				slip_effect[k] = effect["slip"][k]
		results.append(_slip(slip_effect))
	var delta := int(effect.get("delta", effect.get("heat", 10)))
	results.append(adjust_heat(delta, str(effect.get("reason", "escalate"))))
	return {
		"ok": true,
		"action": "escalate",
		"heat": cover.heat,
		"band": cover.heat_band(),
		"blown": cover.blown,
		"steps": results,
	}


func _emit_flag_sync() -> void:
	if _sync_flags:
		CoverFlagSync.sync_from_manager(self)


func _assert_fact(effect: Dictionary) -> Dictionary:
	var key := str(effect.get("key", ""))
	var value := str(effect.get("value", ""))
	var beat := str(effect.get("beat", ""))
	var witness := str(effect.get("witness", ""))
	if key == "":
		push_warning("cover assert missing key")
		return {"ok": false, "error": "missing_key"}
	if value == "" and not bool(effect.get("allow_empty", false)):
		push_warning("cover assert empty value for key %s" % key)
		return {"ok": false, "error": "empty_value", "key": key}
	if cover.blown and not bool(effect.get("force", false)):
		return {"ok": false, "error": "cover_blown", "key": key, "value": value}

	var result := {"key": key, "value": value, "consistent": true, "ok": true}
	if cover.stated_facts.has(key):
		var prior: Dictionary = cover.stated_facts[key]
		var prior_value := str(prior.get("value", ""))
		if prior_value != "" and prior_value != value:
			result["consistent"] = false
			var detail := {
				"key": key,
				"prior": prior_value,
				"stated": value,
				"beat": beat,
				"prior_beat": str(prior.get("beat", "")),
				"witness": witness,
			}
			# Dedupe identical inconsistency rows.
			var dup := false
			for existing in cover.inconsistencies:
				if str(existing.get("key", "")) == key \
					and str(existing.get("prior", "")) == prior_value \
					and str(existing.get("stated", "")) == value:
					dup = true
					break
			if not dup:
				cover.inconsistencies.append(detail)
				inconsistency_recorded.emit(key, detail)
			var heat_delta := int(effect.get("heat", 12))
			adjust_heat(heat_delta, "inconsistency:%s" % key)
			_bump_witness_suspicion(witness, int(effect.get("suspicion", 8)))
			result["inconsistency"] = detail
			result["heat"] = cover.heat
			result["blown"] = cover.blown
			return result
		# Same value restated — refresh beat/witnesses only.
		var witnesses_same: Array = prior.get("witnesses", []).duplicate()
		if witness != "" and witness not in witnesses_same:
			witnesses_same.append(witness)
		cover.stated_facts[key] = {
			"value": prior_value if prior_value != "" else value,
			"beat": beat if beat != "" else str(prior.get("beat", "")),
			"witnesses": witnesses_same,
		}
		if bool(effect.get("reinforce", false)):
			adjust_heat(int(effect.get("heat", -2)), "reinforce:%s" % key)
		result["reinforced"] = true
		return result

	var witnesses: Array = []
	if witness != "":
		witnesses.append(witness)
	cover.stated_facts[key] = {
		"value": value,
		"beat": beat,
		"witnesses": witnesses,
	}
	# Consistent reinforcement can slightly cool heat.
	if bool(effect.get("reinforce", false)):
		adjust_heat(int(effect.get("heat", -2)), "reinforce:%s" % key)
	return result


func _slip(effect: Dictionary) -> Dictionary:
	var key := str(effect.get("key", "slip"))
	if key == "":
		key = "slip"
	var value := str(effect.get("value", ""))
	var beat := str(effect.get("beat", ""))
	var witness := str(effect.get("witness", ""))
	if cover.blown and not bool(effect.get("force", false)):
		return {"ok": false, "error": "cover_blown", "key": key}
	var detail := {
		"key": key,
		"stated": value,
		"beat": beat,
		"witness": witness,
		"kind": "slip",
	}
	# If we previously asserted this key, a different slip value is a hard contradiction.
	if cover.stated_facts.has(key):
		var prior_value := str(cover.stated_facts[key].get("value", ""))
		if prior_value != "" and value != "" and prior_value != value:
			detail["prior"] = prior_value
			detail["kind"] = "slip_contradiction"
	cover.inconsistencies.append(detail)
	inconsistency_recorded.emit(key, detail)
	# Record the slip as the new (broken) stated fact so later asserts can catch it.
	if value != "":
		var witnesses: Array = []
		if cover.stated_facts.has(key):
			witnesses = cover.stated_facts[key].get("witnesses", []).duplicate()
		if witness != "" and witness not in witnesses:
			witnesses.append(witness)
		cover.stated_facts[key] = {
			"value": value,
			"beat": beat,
			"witnesses": witnesses,
			"slipped": true,
		}
	var heat_delta := int(effect.get("heat", 15))
	if detail.get("kind", "") == "slip_contradiction":
		heat_delta = maxi(heat_delta, int(effect.get("contradiction_heat", heat_delta + 5)))
	adjust_heat(heat_delta, "slip:%s" % key)
	_bump_witness_suspicion(witness, int(effect.get("suspicion", 12)))
	if relationships != null and witness != "":
		relationships.set_knowledge(witness, "saw_inconsistency", true)
		var slip_id := "cover_slip_%s_%s" % [key, beat if beat != "" else str(cover.inconsistencies.size())]
		relationships.apply_memory_effect({
			"char": witness,
			"id": slip_id,
			"summary": "Something Cassian said did not sit right: %s." % (value if value != "" else key),
			"salience": 3,
			"tags": ["cover", "inconsistency"],
			"beat": beat,
		})
	detail["ok"] = true
	detail["heat"] = cover.heat
	detail["blown"] = cover.blown
	return detail


func adjust_heat(delta: int, reason: String = "") -> Dictionary:
	if cover.blown and delta < 0 and not reason.begins_with("repair"):
		# Cooling while blown is a no-op unless explicit repair.
		return {
			"before": cover.heat,
			"heat": cover.heat,
			"band": cover.heat_band(),
			"delta": 0,
			"reason": reason,
			"blown": true,
			"ignored": true,
		}
	var before := cover.heat
	cover.heat = clampi(cover.heat + delta, 0, 100)
	heat_changed.emit(cover.heat, cover.heat_band(), reason)
	var out := {
		"before": before,
		"heat": cover.heat,
		"band": cover.heat_band(),
		"delta": cover.heat - before,
		"reason": reason,
	}
	if cover.heat >= HEAT_BLOW_THRESHOLD and not cover.blown:
		blow("heat_threshold")
		out["blown"] = true
	else:
		_emit_flag_sync()
	return out


func blow(reason: String = "") -> Dictionary:
	if cover.blown:
		_emit_flag_sync()
		return {"blown": true, "reason": reason, "heat": cover.heat, "already": true}
	cover.blown = true
	cover.heat = maxi(cover.heat, HEAT_BLOW_THRESHOLD)
	cover_blown.emit(reason)
	_emit_flag_sync()
	# Fail maintain_cover objective when systems mission is bound via GameState.
	if Engine.get_main_loop() != null:
		var gs := Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null and gs.get("systems") != null:
			gs.systems.mission.apply_effect({
				"op": "objective",
				"action": "fail",
				"id": "obj.maintain_cover",
				"beat": reason,
			})
			GameStateBinder.push_to_game_state(gs.systems, gs)
	return {"blown": true, "reason": reason, "heat": cover.heat}


func _bump_witness_suspicion(witness: String, amount: int) -> void:
	if relationships == null or witness == "" or amount == 0:
		return
	relationships.adjust(witness, RelationshipDimensions.SUSPICION, amount)
	relationships.adjust(witness, RelationshipDimensions.PERCEIVED_AUTHENTICITY, -maxi(1, amount / 2))


## Condition helpers.
func check_condition(cond: Dictionary) -> bool:
	var op := str(cond.get("op", "eq"))
	if cond.has("heat_band"):
		var actual := cover.heat_band()
		var expected := str(cond["heat_band"])
		return actual == expected if op != "neq" else actual != expected
	if cond.has("heat"):
		var actual_h := cover.heat
		var expected_h := int(cond["heat"])
		match op:
			"gte", "ge":
				return actual_h >= expected_h
			"lte", "le":
				return actual_h <= expected_h
			"gt":
				return actual_h > expected_h
			"lt":
				return actual_h < expected_h
			"neq":
				return actual_h != expected_h
			_:
				return actual_h == expected_h
	if cond.has("blown"):
		return cover.blown == bool(cond["blown"])
	if cond.has("fact"):
		var key := str(cond["fact"])
		var has := cover.stated_facts.has(key)
		if cond.has("value"):
			if not has:
				return false
			return str(cover.stated_facts[key].get("value", "")) == str(cond["value"])
		return has if op != "neq" and op != "not" else not has
	if cond.has("inconsistency_count"):
		var count := cover.inconsistencies.size()
		var expected_c := int(cond["inconsistency_count"])
		match op:
			"gte", "ge":
				return count >= expected_c
			"lte", "le":
				return count <= expected_c
			_:
				return count == expected_c
	return false


func present(reveal_raw: bool = false) -> Dictionary:
	return _presentation.present_cover(cover, reveal_raw)


func to_save() -> Dictionary:
	return cover.to_dict()


func load_save(data: Dictionary) -> void:
	cover.from_dict(data)
	_emit_flag_sync()
