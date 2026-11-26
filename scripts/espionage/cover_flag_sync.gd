class_name CoverFlagSync
extends RefCounted
## Keeps Narrative debrief flags aligned with cover heat / blown state.
## Flags are FlagStore keys consumed by content/dialogue/debrief.json.

const FLAG_HEAT_HIGH := "heat_high"
const FLAG_COVER_STRAINED := "cover_strained"
const FLAG_COVER_COMPROMISED := "cover_compromised"
const FLAG_COVER_BLOWN := "cover_blown"
const FLAG_COVER_HELD := "cover_held"
const FLAG_ENDING_ID := "ending_id"


static func sync_from_cover(cover: CoverIdentity) -> void:
	if cover == null:
		return
	var heat := cover.heat
	var blown := cover.blown
	FlagStore.set_flag(StringName(FLAG_HEAT_HIGH), heat >= 55)
	FlagStore.set_flag(StringName(FLAG_COVER_STRAINED), heat >= 30 and not blown)
	FlagStore.set_flag(StringName(FLAG_COVER_COMPROMISED), blown or heat >= 80)
	FlagStore.set_flag(StringName(FLAG_COVER_BLOWN), blown)
	if blown:
		FlagStore.set_flag(StringName(FLAG_COVER_HELD), false)
		# Prefer cover_burned ending when cover collapses (Narrative debrief router).
		var existing := str(FlagStore.get_flag(StringName(FLAG_ENDING_ID), ""))
		if existing == "" or existing == "mixed":
			FlagStore.set_flag(StringName(FLAG_ENDING_ID), "cover_burned")
	elif heat < 30:
		FlagStore.set_flag(StringName(FLAG_COVER_HELD), true)


static func sync_from_manager(manager: CoverManager) -> void:
	if manager == null:
		return
	sync_from_cover(manager.cover)
