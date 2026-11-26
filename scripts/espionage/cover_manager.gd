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

const HEAT_BLOW_THRESHOLD := 95

var cover: CoverIdentity
## Optional hook: RelationshipManager for witness suspicion bumps.
var relationships: RelationshipManager
var _presentation: EspionagePresentation


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
			return adjust_heat(int(effect.get("delta", -5)), str(effect.get("reason", effect.get("beat", "repair"))))
		"blow":
			return blow(str(effect.get("reason", "explicit")))
		"set_fact":
			return _assert_fact(effect)
		_:
			push_warning("Unknown cover action: %s" % action)
			return {}


func _assert_fact(effect: Dictionary) -> Dictionary:
	var key := str(effect.get("key", ""))
	var value := str(effect.get("value", ""))
	var beat := str(effect.get("beat", ""))
	var witness := str(effect.get("witness", ""))
	if key == "":
		return {}

	var result := {"key": key, "value": value, "consistent": true}
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
			cover.inconsistencies.append(detail)
			inconsistency_recorded.emit(key, detail)
			var heat_delta := int(effect.get("heat", 12))
			adjust_heat(heat_delta, "inconsistency:%s" % key)
			_bump_witness_suspicion(witness, int(effect.get("suspicion", 8)))
			result["inconsistency"] = detail
			return result

	var witnesses: Array = []
	if cover.stated_facts.has(key):
		witnesses = cover.stated_facts[key].get("witnesses", []).duplicate()
	if witness != "" and witness not in witnesses:
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
	var value := str(effect.get("value", ""))
	var beat := str(effect.get("beat", ""))
	var witness := str(effect.get("witness", ""))
	var detail := {
		"key": key,
		"stated": value,
		"beat": beat,
		"witness": witness,
		"kind": "slip",
	}
	cover.inconsistencies.append(detail)
	inconsistency_recorded.emit(key, detail)
	var heat_delta := int(effect.get("heat", 15))
	adjust_heat(heat_delta, "slip:%s" % key)
	_bump_witness_suspicion(witness, int(effect.get("suspicion", 12)))
	if relationships != null and witness != "":
		relationships.set_knowledge(witness, "saw_inconsistency", true)
		relationships.apply_memory_effect({
			"char": witness,
			"id": "cover_slip_%s_%s" % [key, beat],
			"summary": "Something Cassian said did not sit right: %s." % value,
			"salience": 3,
			"tags": ["cover", "inconsistency"],
			"beat": beat,
		})
	return detail


func adjust_heat(delta: int, reason: String = "") -> Dictionary:
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
	return out


func blow(reason: String = "") -> Dictionary:
	cover.blown = true
	cover.heat = maxi(cover.heat, HEAT_BLOW_THRESHOLD)
	cover_blown.emit(reason)
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
