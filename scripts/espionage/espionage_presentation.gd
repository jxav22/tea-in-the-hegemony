class_name EspionagePresentation
extends RefCounted
## Selective player-facing espionage info. UI must not dump raw heat/scores by default.


func present_cover(cover: CoverIdentity, reveal_raw: bool = false) -> Dictionary:
	var out := {
		"cover_name": cover.cover_name,
		"cover_role": cover.cover_role,
		"employer": cover.employer,
		"heat_band": cover.heat_band(),
		"heat_label": _heat_label(cover),
		"blown": cover.blown,
		"inconsistency_count": cover.inconsistencies.size(),
		"attention_line": _attention_line(cover),
	}
	if reveal_raw:
		out["heat"] = cover.heat
		out["stated_facts"] = cover.stated_facts.duplicate(true)
		out["inconsistencies"] = cover.inconsistencies.duplicate(true)
	return out


func present_evidence(manager: EvidenceManager, reveal_raw: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fid in manager.obtained_ids():
		var frag := manager.get_fragment(fid)
		if frag == null:
			continue
		var entry := {
			"id": frag.id,
			"title": frag.title,
			"summary": frag.summary,
			"source": frag.source,
			"verified": frag.verified,
			"verification_label": "Verified" if frag.verified else "Unconfirmed",
			"contradiction_count": frag.contradicts.size(),
			"tags": frag.tags.duplicate(),
		}
		if reveal_raw:
			entry["claims"] = frag.claims.duplicate(true)
			entry["contradicts"] = frag.contradicts.duplicate()
		out.append(entry)
	return out


func present_mission(mission: MissionManager, reveal_raw: bool = false) -> Dictionary:
	var objs: Array[Dictionary] = []
	for obj in mission.trackable_objectives():
		var entry := {
			"id": obj.id,
			"title": obj.title,
			"description": obj.notes_player if obj.notes_player != "" else obj.description,
			"status": obj.status,
			"status_label": _objective_status_label(obj.status),
			"category": obj.category,
			"required": obj.required,
		}
		if reveal_raw:
			entry["complete_when"] = obj.complete_when.duplicate(true)
		objs.append(entry)
	var out := {
		"mission_id": mission.mission_id,
		"title": mission.mission_title,
		"status": mission.status,
		"objectives": objs,
	}
	if reveal_raw:
		out["meta"] = mission.meta.duplicate(true)
	return out


func _heat_label(cover: CoverIdentity) -> String:
	match cover.heat_band():
		"blown":
			return "Cover blown"
		"critical":
			return "Eyes everywhere"
		"high":
			return "Too much attention"
		"elevated":
			return "Someone is noticing"
		"low":
			return "A little heat"
		_:
			return "Under the radar"


func _attention_line(cover: CoverIdentity) -> String:
	if cover.blown:
		return "Cassian Orth is finished. Move."
	if cover.inconsistencies.size() >= 3:
		return "Your story has holes others can see."
	if cover.heat >= 55:
		return "The room's attention is sticking to you."
	if cover.heat >= 30:
		return "A few glances linger a beat too long."
	return "Your cover is holding."


func _objective_status_label(status: String) -> String:
	match status:
		IntelObjective.STATUS_COMPLETE:
			return "Done"
		IntelObjective.STATUS_FAILED:
			return "Failed"
		IntelObjective.STATUS_ABANDONED:
			return "Abandoned"
		IntelObjective.STATUS_OPTIONAL:
			return "Optional"
		IntelObjective.STATUS_ACTIVE:
			return "Active"
		_:
			return "Hidden"
