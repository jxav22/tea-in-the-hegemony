class_name KnowledgeFlags
extends RefCounted
## Curated knowledge flag ids for dialogue conditions + presentation hints.
## Narrative may introduce more; player-facing subset is listed in SocialPresentation.

const KNOWS_COVER_NAME := "knows_cover_name"
const SUSPECTS_TRADECRAFT := "suspects_tradecraft"
const SHARED_PERSONAL := "shared_personal"
const SAW_INCONSISTENCY := "saw_inconsistency"
const OWES_FAVOR := "owes_favor"
const IDENTIFIED_VOSS := "identified_voss"
const KNOW_STUDY_ANNEX := "knows_study_annex"
const KNOW_SERA_RIVAL := "knows_sera_rival"
const TRUSTED_WITH_POLICY := "trusted_with_policy"
const OFFERED_EXIT := "offered_exit"


static func all_known() -> Array[String]:
	return [
		KNOWS_COVER_NAME,
		SUSPECTS_TRADECRAFT,
		SHARED_PERSONAL,
		SAW_INCONSISTENCY,
		OWES_FAVOR,
		IDENTIFIED_VOSS,
		KNOW_STUDY_ANNEX,
		KNOW_SERA_RIVAL,
		TRUSTED_WITH_POLICY,
		OFFERED_EXIT,
	]
