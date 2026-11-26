class_name EvidenceManager
extends RefCounted
## Evidence fragments, contradictory accounts, verification.
## DialogueRunner effect op: "evidence".
##
## Effects:
##   {"op":"evidence","action":"obtain","id":"frag.shipping_delta","beat":"study.inspect"}
##   {"op":"evidence","action":"verify","id":"frag.shipping_delta","notes":"Cross-checked guest cipher"}
##   {"op":"evidence","action":"dispute","id":"frag.pim_rumour","against":"frag.shipping_delta"}
##   {"op":"evidence","action":"add_claim","id":"frag.x","claim":{"id":"c1","text":"..."}}

signal fragment_obtained(fragment_id: String)
signal fragment_verified(fragment_id: String)
signal contradiction_flagged(fragment_id: String, against_id: String)

var fragments: Dictionary = {} ## id -> EvidenceFragment
var _presentation: EspionagePresentation


func _init() -> void:
	_presentation = EspionagePresentation.new()


func register_fragment(data: Dictionary) -> EvidenceFragment:
	var frag := EvidenceFragment.new(data)
	fragments[frag.id] = frag
	return frag


func load_catalog(catalog: Array) -> void:
	for item in catalog:
		if typeof(item) == TYPE_DICTIONARY:
			register_fragment(item)


func load_from_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ERR_CANT_OPEN
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("fragments"):
		load_catalog(parsed["fragments"])
		return OK
	if typeof(parsed) == TYPE_ARRAY:
		load_catalog(parsed)
		return OK
	return ERR_INVALID_DATA


func get_fragment(fragment_id: String) -> EvidenceFragment:
	return fragments.get(fragment_id) as EvidenceFragment


func has_fragment(fragment_id: String) -> bool:
	return fragments.has(fragment_id)


func is_obtained(fragment_id: String) -> bool:
	var frag := get_fragment(fragment_id)
	return frag != null and frag.obtained


func is_verified(fragment_id: String) -> bool:
	var frag := get_fragment(fragment_id)
	return frag != null and frag.verified


func apply_effect(effect: Dictionary) -> Dictionary:
	var action := str(effect.get("action", "obtain"))
	var fid := str(effect.get("id", effect.get("fragment", "")))
	match action:
		"obtain":
			return obtain(fid, str(effect.get("beat", "")))
		"verify":
			return verify(fid, str(effect.get("notes", "")))
		"unverify":
			return unverify(fid)
		"dispute":
			return dispute(fid, str(effect.get("against", "")))
		"add_claim":
			return add_claim(fid, effect.get("claim", {}))
		"register":
			var frag := register_fragment(effect.get("data", effect))
			return {"id": frag.id, "registered": true}
		_:
			push_warning("Unknown evidence action: %s" % action)
			return {}


func obtain(fragment_id: String, beat: String = "") -> Dictionary:
	var frag := get_fragment(fragment_id)
	if frag == null:
		push_warning("Unknown evidence fragment: %s" % fragment_id)
		return {"ok": false, "id": fragment_id}
	if frag.obtained:
		return {"ok": true, "id": fragment_id, "already": true}
	frag.obtained = true
	frag.obtained_at_beat = beat
	fragment_obtained.emit(fragment_id)
	return {"ok": true, "id": fragment_id, "obtained": true, "beat": beat}


func verify(fragment_id: String, notes: String = "") -> Dictionary:
	var frag := get_fragment(fragment_id)
	if frag == null:
		return {"ok": false, "id": fragment_id}
	if not frag.obtained:
		# Allow verify-on-obtain for tightly scripted beats.
		frag.obtained = true
	frag.verified = true
	if notes != "":
		frag.verification_notes = notes
	fragment_verified.emit(fragment_id)
	return {"ok": true, "id": fragment_id, "verified": true}


func unverify(fragment_id: String) -> Dictionary:
	var frag := get_fragment(fragment_id)
	if frag == null:
		return {"ok": false}
	frag.verified = false
	return {"ok": true, "id": fragment_id, "verified": false}


func dispute(fragment_id: String, against_id: String) -> Dictionary:
	var frag := get_fragment(fragment_id)
	if frag == null:
		return {"ok": false}
	if against_id != "" and against_id not in frag.contradicts:
		frag.contradicts.append(against_id)
	contradiction_flagged.emit(fragment_id, against_id)
	# Disputed fragments lose verification until resolved.
	if frag.verified:
		frag.verified = false
		frag.verification_notes = "Disputed against %s" % against_id
	return {"ok": true, "id": fragment_id, "against": against_id}


func add_claim(fragment_id: String, claim: Variant) -> Dictionary:
	var frag := get_fragment(fragment_id)
	if frag == null:
		return {"ok": false}
	var claim_dict: Dictionary
	if typeof(claim) == TYPE_DICTIONARY:
		claim_dict = claim
	else:
		claim_dict = {"id": str(claim), "text": str(claim)}
	frag.claims.append(claim_dict)
	return {"ok": true, "id": fragment_id, "claim": claim_dict}


## Open contradictions among obtained fragments.
func open_contradictions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fid in fragments.keys():
		var frag: EvidenceFragment = fragments[fid]
		if not frag.obtained:
			continue
		for against in frag.contradicts:
			var other := get_fragment(against)
			if other != null and other.obtained:
				out.append({
					"fragment": frag.id,
					"against": against,
					"either_verified": frag.verified or other.verified,
				})
			elif against.begins_with("claim:") or against.contains("."):
				# Claim-level or cross-ref still surfaces.
				out.append({
					"fragment": frag.id,
					"against": against,
					"either_verified": frag.verified,
				})
	return out


func obtained_ids() -> Array[String]:
	var ids: Array[String] = []
	for fid in fragments.keys():
		if (fragments[fid] as EvidenceFragment).obtained:
			ids.append(str(fid))
	return ids


func verified_ids() -> Array[String]:
	var ids: Array[String] = []
	for fid in fragments.keys():
		var frag: EvidenceFragment = fragments[fid]
		if frag.obtained and frag.verified:
			ids.append(str(fid))
	return ids


func check_condition(cond: Dictionary) -> bool:
	var op := str(cond.get("op", "eq"))
	if cond.has("fragment") or cond.has("id"):
		var fid := str(cond.get("fragment", cond.get("id", "")))
		var want_verified := bool(cond.get("verified", false)) if cond.has("verified") else null
		var obtained := is_obtained(fid)
		if typeof(want_verified) == TYPE_BOOL:
			var ok := obtained and (is_verified(fid) == want_verified)
			return ok if op != "neq" and op != "not" else not ok
		if cond.get("status", "") == "verified":
			var v := is_verified(fid)
			return v if op != "neq" and op != "not" else not v
		return obtained if op != "neq" and op != "not" else not obtained
	if cond.has("contradiction_count"):
		var count := open_contradictions().size()
		var expected := int(cond["contradiction_count"])
		match op:
			"gte", "ge":
				return count >= expected
			"lte", "le":
				return count <= expected
			_:
				return count == expected
	return false


func present(reveal_raw: bool = false) -> Array[Dictionary]:
	return _presentation.present_evidence(self, reveal_raw)


func to_save() -> Dictionary:
	var out := {}
	for fid in fragments.keys():
		out[str(fid)] = (fragments[fid] as EvidenceFragment).to_dict()
	return out


func load_save(data: Dictionary) -> void:
	for fid in data.keys():
		if fragments.has(str(fid)):
			(fragments[fid] as EvidenceFragment).from_dict(data[fid])
		else:
			register_fragment(data[fid])
