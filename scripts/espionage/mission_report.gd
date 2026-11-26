class_name MissionReport
extends RefCounted
## Debrief / mission reporting: professional success vs social/human outcomes.

const OUTCOME_CLEAN_PROFESSIONAL := "clean_professional"
const OUTCOME_PROFESSIONAL_COSTLY := "professional_costly"
const OUTCOME_HUMAN_FIRST := "human_first"
const OUTCOME_BALANCED := "balanced"
const OUTCOME_COMPROMISED := "compromised"
const OUTCOME_BLOWN := "blown"
const OUTCOME_PARTIAL := "partial"

var mission_id: String = ""
var chapter_id: String = ""
var generated_at_beat: String = ""
var outcome_id: String = OUTCOME_PARTIAL
var outcome_title: String = ""
var outcome_summary: String = ""
var professional_score: int = 0 ## internal; presentation uses bands
var human_score: int = 0
var cover_score: int = 0
var objectives_complete: Array[String] = []
var objectives_failed: Array[String] = []
var objectives_optional_complete: Array[String] = []
var evidence_obtained: Array[String] = []
var evidence_verified: Array[String] = []
var contradictions_open: Array[Dictionary] = []
var cover_heat: int = 0
var cover_blown: bool = false
var inconsistency_count: int = 0
var social_highlights: Array[Dictionary] = []
var trade_off_tags: Array[String] = []
var handler_note: String = ""
var personal_note: String = ""


func collect_from(
	mission: MissionManager,
	rels: RelationshipManager = null,
	cover: CoverManager = null,
	evidence: EvidenceManager = null
) -> void:
	mission_id = mission.mission_id
	chapter_id = mission.chapter_id

	for oid in mission.objectives.keys():
		var obj: IntelObjective = mission.objectives[oid]
		match obj.status:
			IntelObjective.STATUS_COMPLETE:
				if obj.required:
					objectives_complete.append(oid)
				else:
					objectives_optional_complete.append(oid)
			IntelObjective.STATUS_FAILED, IntelObjective.STATUS_ABANDONED:
				objectives_failed.append(oid)

	if evidence != null:
		evidence_obtained = evidence.obtained_ids()
		evidence_verified = evidence.verified_ids()
		contradictions_open = evidence.open_contradictions()

	if cover != null:
		cover_heat = cover.cover.heat
		cover_blown = cover.cover.blown
		inconsistency_count = cover.cover.inconsistencies.size()
		cover_score = 100 - cover_heat
		if cover_blown:
			cover_score = 0

	professional_score = _score_professional(mission, evidence)
	human_score = _score_human(rels)
	_derive_outcome(mission)
	_compose_notes(rels, cover)


func _score_professional(mission: MissionManager, evidence: EvidenceManager) -> int:
	var score := 0
	var required_total := 0
	for oid in mission.objectives.keys():
		var obj: IntelObjective = mission.objectives[oid]
		if not obj.required:
			continue
		if obj.category in ["intel", "cover", "survival"]:
			required_total += 1
			if obj.status == IntelObjective.STATUS_COMPLETE:
				score += 25
	if evidence != null:
		score += mini(20, evidence.verified_ids().size() * 10)
		score -= mini(15, evidence.open_contradictions().size() * 5)
	# Cover integrity feeds professional grade.
	score = int(score * (0.5 + 0.5 * (float(cover_score) / 100.0)))
	return clampi(score, 0, 100)


func _score_human(rels: RelationshipManager) -> int:
	if rels == null:
		return 0
	var score := 40
	# Maris is the primary human axis for The Reception.
	if rels.has_character("maris_quell"):
		var trust := rels.get_dim("maris_quell", RelationshipDimensions.TRUST)
		var affection := rels.get_dim("maris_quell", RelationshipDimensions.AFFECTION)
		var comfort := rels.get_dim("maris_quell", RelationshipDimensions.COMFORT)
		var suspicion := rels.get_dim("maris_quell", RelationshipDimensions.SUSPICION)
		var authenticity := rels.get_dim("maris_quell", RelationshipDimensions.PERCEIVED_AUTHENTICITY)
		score += clampi(trust, -20, 25)
		score += clampi(affection, -15, 30)
		score += clampi(comfort / 2, -10, 15)
		score -= clampi(suspicion, 0, 35)
		score += clampi(authenticity / 2, -15, 15)
		if rels.has_memory("maris_quell", "shared_something_real"):
			score += 12
		if rels.has_memory("maris_quell", "felt_used"):
			score -= 18
		social_highlights.append(rels.present("maris_quell"))
	# Secondary: Taly perception, Wren approval (handler is professional, not human win).
	if rels.has_character("taly_renn"):
		var taly_sus := rels.get_dim("taly_renn", RelationshipDimensions.SUSPICION)
		if taly_sus >= 30:
			score -= 8
			trade_off_tags.append("taly_clocked_you")
	return clampi(score, 0, 100)


func _derive_outcome(mission: MissionManager) -> void:
	trade_off_tags.clear()
	if cover_blown:
		outcome_id = OUTCOME_BLOWN
		outcome_title = "Cover Blown"
		outcome_summary = "The reception ends with your name in the wrong mouths."
		trade_off_tags.append("blown")
		return

	var intel_ok := objectives_complete.has("obj.obtain_fragment") \
		or objectives_complete.has("obj.identify_voss")
	# Broader: any required intel-ish complete count.
	var req_done := objectives_complete.size()
	var req_failed := 0
	for oid in objectives_failed:
		var obj := mission.get_objective(oid)
		if obj != null and obj.required:
			req_failed += 1

	var pro_high := professional_score >= 60
	var human_high := human_score >= 60
	var pro_low := professional_score < 35
	var human_low := human_score < 35

	if cover_heat >= 55:
		trade_off_tags.append("high_heat")
	if human_high:
		trade_off_tags.append("human_connection")
	if pro_high:
		trade_off_tags.append("professional_success")
	if contradictions_open.size() > 0:
		trade_off_tags.append("unresolved_intel")

	if pro_high and human_high and cover_heat < 40:
		outcome_id = OUTCOME_BALANCED
		outcome_title = "Both Ledgers"
		outcome_summary = "You leave with the fragment and something harder to file: a real conversation."
	elif pro_high and human_low:
		outcome_id = OUTCOME_CLEAN_PROFESSIONAL if cover_heat < 35 else OUTCOME_PROFESSIONAL_COSTLY
		outcome_title = "Clean Extraction" if outcome_id == OUTCOME_CLEAN_PROFESSIONAL else "Costly Success"
		outcome_summary = (
			"Handler will be pleased. Maris may not return your calls — if she ever had your number."
			if outcome_id == OUTCOME_CLEAN_PROFESSIONAL
			else "The intel is solid. The room remembers your sweat."
		)
		trade_off_tags.append("mission_over_person")
	elif human_high and pro_low:
		outcome_id = OUTCOME_HUMAN_FIRST
		outcome_title = "The Soft Exit"
		outcome_summary = "You protected a person and lost an angle. Wren will not clap."
		trade_off_tags.append("person_over_mission")
	elif req_failed > 0 or (pro_low and human_low):
		outcome_id = OUTCOME_COMPROMISED
		outcome_title = "Compromised Evening"
		outcome_summary = "Little to show Wren. Little warmth left in the room."
	elif intel_ok or req_done > 0:
		outcome_id = OUTCOME_PARTIAL
		outcome_title = "Partial Picture"
		outcome_summary = "Enough to continue. Not enough to feel finished."
	else:
		outcome_id = OUTCOME_PARTIAL
		outcome_title = "Partial Picture"
		outcome_summary = "The reception ends; the ledgers disagree."

	# Meta trade-off paths from mission file.
	for tag in mission.meta.get("trade_off_tags_on_outcome", {}).get(outcome_id, []):
		if tag not in trade_off_tags:
			trade_off_tags.append(str(tag))


func _compose_notes(rels: RelationshipManager, cover: CoverManager) -> void:
	match outcome_id:
		OUTCOME_BALANCED:
			handler_note = "Wren: 'Unexpectedly competent. Don't make a habit of feeling things on the clock.'"
			personal_note = "You remember how Maris laughed — and the shipping discrepancy."
		OUTCOME_CLEAN_PROFESSIONAL:
			handler_note = "Wren: 'Textbook. The woman was a vector. You treated her as one.'"
			personal_note = "Professional pride. A quiet, ugly aftertaste."
		OUTCOME_PROFESSIONAL_COSTLY:
			handler_note = "Wren: 'You got it. You also got noticed. We will manage the notice.'"
			personal_note = "Success with a pulse in your throat."
		OUTCOME_HUMAN_FIRST:
			handler_note = "Wren: 'Charming. Useless. File a better night next time.'"
			personal_note = "Whatever you gave up, it felt like choosing a side of yourself."
		OUTCOME_BLOWN:
			handler_note = "Wren: 'Exfil. Now. Sentiment is for people who still have covers.'"
			personal_note = "Cassian Orth is a short story with a bad ending."
		OUTCOME_COMPROMISED:
			handler_note = "Wren: 'We will discuss this without tea.'"
			personal_note = "The room moved on. You did not."
		_:
			handler_note = "Wren: 'Incomplete. Acceptable. Improve.'"
			personal_note = "Fragments of a night — intel and otherwise."

	if rels != null and rels.has_memory("maris_quell", "shared_something_real"):
		personal_note += " She has a memory of you that isn't a cover."
	if cover != null and cover.cover.inconsistencies.size() > 0:
		handler_note += " Inconsistencies logged: %d." % cover.cover.inconsistencies.size()


func to_dict() -> Dictionary:
	return {
		"mission_id": mission_id,
		"chapter_id": chapter_id,
		"generated_at_beat": generated_at_beat,
		"outcome_id": outcome_id,
		"outcome_title": outcome_title,
		"outcome_summary": outcome_summary,
		"professional_score": professional_score,
		"human_score": human_score,
		"cover_score": cover_score,
		"objectives_complete": objectives_complete.duplicate(),
		"objectives_failed": objectives_failed.duplicate(),
		"objectives_optional_complete": objectives_optional_complete.duplicate(),
		"evidence_obtained": evidence_obtained.duplicate(),
		"evidence_verified": evidence_verified.duplicate(),
		"contradictions_open": contradictions_open.duplicate(true),
		"cover_heat": cover_heat,
		"cover_blown": cover_blown,
		"inconsistency_count": inconsistency_count,
		"trade_off_tags": trade_off_tags.duplicate(),
		"handler_note": handler_note,
		"personal_note": personal_note,
	}


func present(reveal_raw: bool = false) -> Dictionary:
	var out := {
		"outcome_id": outcome_id,
		"title": outcome_title,
		"summary": outcome_summary,
		"professional": _band(professional_score),
		"human": _band(human_score),
		"cover": _cover_band(),
		"objectives_complete": objectives_complete.duplicate(),
		"objectives_failed": objectives_failed.duplicate(),
		"optional_wins": objectives_optional_complete.duplicate(),
		"evidence_count": evidence_obtained.size(),
		"verified_count": evidence_verified.size(),
		"trade_offs": trade_off_tags.duplicate(),
		"handler_note": handler_note,
		"personal_note": personal_note,
	}
	if reveal_raw:
		out["raw"] = {
			"professional_score": professional_score,
			"human_score": human_score,
			"cover_score": cover_score,
			"cover_heat": cover_heat,
		}
	return out


func _band(score: int) -> Dictionary:
	var label := "mixed"
	if score >= 75:
		label = "strong"
	elif score >= 55:
		label = "solid"
	elif score >= 35:
		label = "uneven"
	else:
		label = "weak"
	return {"band": label, "label": label.capitalize()}


func _cover_band() -> Dictionary:
	if cover_blown:
		return {"band": "blown", "label": "Blown"}
	if cover_heat >= 80:
		return {"band": "critical", "label": "Critical"}
	if cover_heat >= 55:
		return {"band": "high", "label": "Fraying"}
	if cover_heat >= 30:
		return {"band": "elevated", "label": "Watched"}
	if cover_heat >= 10:
		return {"band": "low", "label": "Steady"}
	return {"band": "clear", "label": "Clean"}
