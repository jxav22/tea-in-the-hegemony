class_name GameStateBinder
extends RefCounted
## Mirrors SystemsBridge ↔ GameState fields so saves stay on Core keys (no forked stores).

const OBJECTIVE_ALIASES := {
	"obj.contact_maris": "contact_maris",
	"obj.identify_voss": "identify_voss",
	"obj.obtain_fragment": "obtain_fragment",
	"obj.maintain_cover": "maintain_cover",
	"obj.avoid_attention": "avoid_attention",
	"obj.optional_real_talk": "optional_real_talk",
	"obj.optional_verify": "optional_verify",
}


static func core_objective_id(systems_id: String) -> String:
	if OBJECTIVE_ALIASES.has(systems_id):
		return str(OBJECTIVE_ALIASES[systems_id])
	if systems_id.begins_with("obj."):
		return systems_id.substr(4)
	return systems_id


static func systems_objective_id(core_id: String) -> String:
	for sys_id in OBJECTIVE_ALIASES.keys():
		if str(OBJECTIVE_ALIASES[sys_id]) == core_id:
			return str(sys_id)
	if core_id.begins_with("obj."):
		return core_id
	return "obj." + core_id


## Push rich systems state into GameState dictionaries/arrays.
static func push_to_game_state(systems: SystemsBridge, gs: Node) -> void:
	if systems == null or gs == null:
		return
	_push_relationships(systems, gs)
	_push_cover(systems, gs)
	_push_objectives(systems, gs)
	_push_memories(systems, gs)
	_push_evidence_inventory(systems, gs)


static func pull_into_systems(systems: SystemsBridge, gs: Node, save_data: Dictionary = {}) -> void:
	if systems == null or gs == null:
		return
	_pull_relationships(systems, gs)
	_pull_cover(systems, gs)
	_pull_objectives(systems, gs)
	_pull_memories(systems, gs)
	if save_data.has("evidence") and typeof(save_data["evidence"]) == TYPE_DICTIONARY:
		systems.evidence.load_save(save_data["evidence"])
	elif save_data.is_empty():
		# Re-mark obtained from inventory.
		for entry in gs.inventory:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var iid := str(entry.get("id", ""))
			if iid.begins_with("frag.") and systems.evidence.has_fragment(iid):
				systems.evidence.obtain(iid, str(entry.get("beat", "")))
				if bool(entry.get("verified", false)):
					systems.evidence.verify(iid, str(entry.get("verification_notes", "")))


static func _push_relationships(systems: SystemsBridge, gs: Node) -> void:
	for char_id in systems.relationships.all_character_ids():
		var state: RelationshipState = systems.relationships.get_state(char_id)
		var blank: Dictionary = gs.ensure_relationship(StringName(char_id))
		for dim in RelationshipDimensions.ALL:
			blank[dim] = state.get_dim(dim)


static func _pull_relationships(systems: SystemsBridge, gs: Node) -> void:
	for char_id in gs.relationships.keys():
		var dims: Dictionary = gs.relationships[char_id]
		var state := systems.relationships.ensure(str(char_id))
		for dim in RelationshipDimensions.ALL:
			if dims.has(dim):
				state.set_dim(dim, int(dims[dim]))


static func _push_cover(systems: SystemsBridge, gs: Node) -> void:
	var c: CoverIdentity = systems.cover.cover
	gs.cover_state["name"] = c.cover_name
	gs.cover_state["true_name"] = c.legal_name
	gs.cover_state["role"] = c.cover_role
	gs.cover_state["heat"] = c.heat
	gs.cover_state["blown"] = c.blown
	gs.cover_state["employer"] = c.employer
	gs.cover_state["cover_id"] = c.cover_id
	gs.cover_state["inconsistency_count"] = c.inconsistencies.size()
	gs.cover_changed.emit(gs.cover_state)


static func _pull_cover(systems: SystemsBridge, gs: Node) -> void:
	var cs: Dictionary = gs.cover_state
	systems.cover.cover.cover_name = str(cs.get("name", systems.cover.cover.cover_name))
	systems.cover.cover.legal_name = str(cs.get("true_name", systems.cover.cover.legal_name))
	systems.cover.cover.cover_role = str(cs.get("role", systems.cover.cover.cover_role))
	systems.cover.cover.heat = clampi(int(cs.get("heat", 0)), 0, 100)
	systems.cover.cover.blown = bool(cs.get("blown", false))
	if cs.has("employer"):
		systems.cover.cover.employer = str(cs["employer"])
	if cs.has("cover_id"):
		systems.cover.cover.cover_id = str(cs["cover_id"])


static func _push_objectives(systems: SystemsBridge, gs: Node) -> void:
	for oid in systems.mission.objectives.keys():
		var obj: IntelObjective = systems.mission.objectives[oid]
		var core_id := core_objective_id(str(oid))
		var label := obj.title if obj.title != "" else core_id
		gs.set_objective(StringName(core_id), obj.status, label)
		# Keep systems id visible too for mission-aware UI.
		if core_id != str(oid):
			gs.objectives[str(oid)] = {
				"id": str(oid),
				"status": obj.status,
				"label": label,
			}


static func _pull_objectives(systems: SystemsBridge, gs: Node) -> void:
	for oid in gs.objectives.keys():
		var entry: Dictionary = gs.objectives[oid]
		var status := str(entry.get("status", "active"))
		var sys_id := systems_objective_id(str(oid))
		var obj := systems.mission.get_objective(sys_id)
		if obj == null:
			obj = systems.mission.get_objective(str(oid))
		if obj == null:
			continue
		obj.status = status
		if entry.has("label") and str(entry["label"]) != "":
			obj.title = str(entry["label"])


static func _push_memories(systems: SystemsBridge, gs: Node) -> void:
	## Rebuild flat GameState.memories from per-character systems memories (dedupe by id).
	var seen: Dictionary = {}
	var flat: Array = []
	for char_id in systems.relationships.all_character_ids():
		for mem in systems.relationships.get_state(char_id).active_memories():
			if seen.has(mem.id):
				continue
			seen[mem.id] = true
			var d := mem.to_dict()
			d["char"] = char_id
			# Core schema prefers int beat index when possible.
			if str(d.get("created_at_beat", "")).is_valid_int():
				d["created_at_beat"] = int(d["created_at_beat"])
			else:
				d["created_at_beat"] = gs.beat_index
			flat.append(d)
	# Preserve any GameState memories that systems doesn't know (legacy / non-character).
	for m in gs.memories:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var mid := str(m.get("id", ""))
		if mid != "" and not seen.has(mid):
			flat.append(m)
			seen[mid] = true
	gs.memories = flat


static func _pull_memories(systems: SystemsBridge, gs: Node) -> void:
	for m in gs.memories:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var char_id := str(m.get("char", m.get("about_character", "")))
		if char_id == "":
			# Global memory — attach to wren as mission log default, still listed flat.
			char_id = "wren_halden"
		systems.relationships.add_memory(char_id, m)


static func _push_evidence_inventory(systems: SystemsBridge, gs: Node) -> void:
	for fid in systems.evidence.obtained_ids():
		var frag := systems.evidence.get_fragment(fid)
		if frag == null:
			continue
		gs.add_inventory_item(StringName(fid), {
			"kind": "evidence",
			"title": frag.title,
			"verified": frag.verified,
			"beat": frag.obtained_at_beat,
			"verification_notes": frag.verification_notes,
		})
