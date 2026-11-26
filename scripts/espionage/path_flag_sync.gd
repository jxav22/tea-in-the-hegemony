class_name PathFlagSync
extends RefCounted
## Maps SystemsBridge mission report / inventory state → Narrative debrief path flags.
## Debrief router (content/dialogue/debrief.json) reads these FlagStore keys.

## Narrative ending_id values (debrief choice conditions).
const ENDING_COVER_BURNED := "cover_burned"
const ENDING_SERA_WINS := "sera_wins"
const ENDING_BALANCED := "balanced"
const ENDING_PROFESSIONAL := "professional_win"
const ENDING_HUMAN := "human_cost"
const ENDING_CONNECTION := "connection"
const ENDING_MIXED := "mixed"


static func sync_from_systems(systems: SystemsBridge, force_ending: bool = false) -> Dictionary:
	if systems == null:
		return {}
	var report: MissionReport = systems.mission.build_report("debrief")
	return sync_from_report(report, systems, force_ending)


static func sync_from_report(
	report: MissionReport,
	systems: SystemsBridge = null,
	force_ending: bool = false
) -> Dictionary:
	var flags := {}
	# Evidence / fragment
	var got_fragment := false
	if systems != null:
		got_fragment = (
			systems.evidence.is_obtained("frag.shipping_delta")
			or GameState.has_item(&"shipping_discrepancy")
			or GameState.has_item(&"frag.shipping_delta")
		)
	flags["got_fragment"] = got_fragment

	# Cover
	CoverFlagSync.sync_from_manager(systems.cover if systems != null else null)
	flags["cover_blown"] = bool(FlagStore.get_flag(&"cover_blown", false))
	flags["heat_high"] = bool(FlagStore.get_flag(&"heat_high", false))

	# Social / path memories → narrative flags
	var helped_taly := _mem("mem_helped_taly", systems) or bool(FlagStore.get_flag(&"helped_taly", false))
	var abandoned_taly := _mem("mem_abandoned_taly", systems) or bool(FlagStore.get_flag(&"abandoned_taly", false))
	var genuine := false
	if report != null:
		genuine = report.genuine_connection
	if systems != null and systems.relationships != null:
		genuine = genuine or systems.relationships.has_memory_with_tag_anywhere("genuine")
		for mid in MissionReport.GENUINE_MEMORY_IDS:
			if systems.relationships.has_memory_anywhere(mid):
				genuine = true
				break
	var skipped := _mem("mem_skipped_impress", systems) or bool(FlagStore.get_flag(&"skipped_impress", false))
	var sera_has := _mem("mem_sera_stole", systems) or bool(FlagStore.get_flag(&"sera_has_fragment", false))

	flags["helped_taly"] = helped_taly
	flags["abandoned_taly"] = abandoned_taly
	flags["genuine_with_maris"] = genuine
	flags["skipped_impress"] = skipped
	flags["sera_has_fragment"] = sera_has

	for k in flags.keys():
		FlagStore.set_flag(StringName(str(k)), flags[k])

	# ending_id — only overwrite empty/mixed unless forced or cover burned.
	var ending := _derive_ending_id(report, flags)
	var existing := str(FlagStore.get_flag(&"ending_id", ""))
	if force_ending or existing == "" or existing == ENDING_MIXED or ending == ENDING_COVER_BURNED:
		FlagStore.set_flag(&"ending_id", ending)
		flags["ending_id"] = ending
	else:
		flags["ending_id"] = existing

	FlagStore.set_flag(&"reception_ending", true)
	flags["reception_ending"] = true
	return flags


static func _mem(memory_id: String, systems: SystemsBridge) -> bool:
	if systems == null or systems.relationships == null:
		return GameState.has_memory(StringName(memory_id))
	return systems.relationships.has_memory_anywhere(memory_id)


static func _derive_ending_id(report: MissionReport, flags: Dictionary) -> String:
	if bool(flags.get("cover_blown", false)):
		return ENDING_COVER_BURNED
	if report != null and report.outcome_id == MissionReport.OUTCOME_BLOWN:
		return ENDING_COVER_BURNED
	if bool(flags.get("sera_has_fragment", false)) and not bool(flags.get("got_fragment", false)):
		return ENDING_SERA_WINS
	if report != null:
		match report.outcome_id:
			MissionReport.OUTCOME_BALANCED:
				return ENDING_BALANCED
			MissionReport.OUTCOME_CLEAN_PROFESSIONAL, MissionReport.OUTCOME_PROFESSIONAL_COSTLY:
				return ENDING_PROFESSIONAL
			MissionReport.OUTCOME_HUMAN_FIRST:
				return ENDING_HUMAN
			_:
				pass
	# Narrative-style heuristics when report is partial.
	if bool(flags.get("got_fragment", false)) and bool(flags.get("helped_taly", false)):
		return ENDING_BALANCED
	if bool(flags.get("got_fragment", false)) and bool(flags.get("abandoned_taly", false)):
		return ENDING_PROFESSIONAL
	if bool(flags.get("helped_taly", false)) and not bool(flags.get("got_fragment", false)):
		return ENDING_HUMAN
	if bool(flags.get("genuine_with_maris", false)) and bool(flags.get("skipped_impress", false)):
		return ENDING_CONNECTION
	if bool(flags.get("genuine_with_maris", false)):
		return ENDING_CONNECTION
	return ENDING_MIXED
