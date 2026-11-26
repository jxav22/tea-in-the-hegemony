class_name SocialPresentation
extends RefCounted
## Selective player-facing social info. Never dump raw relationship numbers in UI.
## Presentation layer (Agent D) should call these APIs, not read RelationshipState.dimensions.

const DIMENSION_LABELS := {
	RelationshipDimensions.TRUST: "Trust",
	RelationshipDimensions.FAMILIARITY: "Familiarity",
	RelationshipDimensions.SUSPICION: "Suspicion",
	RelationshipDimensions.RESPECT: "Respect",
	RelationshipDimensions.AFFECTION: "Affection",
	RelationshipDimensions.COMFORT: "Comfort",
	RelationshipDimensions.PERCEIVED_AUTHENTICITY: "How real you seem",
}

const BAND_LABELS := {
	"hostile": "Hostile",
	"cold": "Distant",
	"neutral": "Uncertain",
	"warm": "Open",
	"close": "Close",
	"intimate": "Intimate",
}

## Suspicion uses inverted emotional reading for copy.
const SUSPICION_BAND_LABELS := {
	"hostile": "Alarming",
	"cold": "Wary",
	"neutral": "Uncertain",
	"warm": "Curious",
	"close": "Guarded",
	"intimate": "Convinced you're false",
}


func present_relationship(state: RelationshipState, reveal_raw: bool = false) -> Dictionary:
	var dims_out := {}
	for dim in RelationshipDimensions.ALL:
		var value := state.get_dim(dim)
		var band := RelationshipDimensions.band_for(value)
		# Suspicion is "bad when high" — remap band labels.
		var label := str(BAND_LABELS.get(band, band))
		if dim == RelationshipDimensions.SUSPICION:
			# High suspicion should read as alarming; invert band for display text.
			var suspicion_band := _suspicion_display_band(value)
			label = str(SUSPICION_BAND_LABELS.get(suspicion_band, suspicion_band))
			band = suspicion_band
		var entry := {
			"id": dim,
			"label": str(DIMENSION_LABELS.get(dim, dim)),
			"band": band,
			"band_label": label,
			"trend_hint": _trend_hint(dim, value),
		}
		if reveal_raw:
			entry["raw"] = value
		dims_out[dim] = entry

	var mem_summaries: Array[Dictionary] = present_memories(state)
	return {
		"character_id": state.character_id,
		"dimensions": dims_out,
		"notable_memories": mem_summaries,
		"knowledge_hints": _knowledge_hints(state),
		"mood_line": compose_mood_line(state),
	}


func present_memories(state: RelationshipState) -> Array[Dictionary]:
	var active := state.active_memories()
	active.sort_custom(func(a: MemoryEntry, b: MemoryEntry) -> bool:
		return a.salience > b.salience
	)
	var out: Array[Dictionary] = []
	for m in active:
		out.append({
			"id": m.id,
			"summary": m.summary,
			"salience": m.salience,
			"tags": m.tags.duplicate(),
			"beat": m.created_at_beat,
		})
	return out


func compose_mood_line(state: RelationshipState) -> String:
	var trust := state.get_dim(RelationshipDimensions.TRUST)
	var suspicion := state.get_dim(RelationshipDimensions.SUSPICION)
	var affection := state.get_dim(RelationshipDimensions.AFFECTION)
	var authenticity := state.get_dim(RelationshipDimensions.PERCEIVED_AUTHENTICITY)
	var comfort := state.get_dim(RelationshipDimensions.COMFORT)

	if suspicion >= 40:
		return "They are watching you too carefully."
	if authenticity <= -30:
		return "Something about you doesn't add up to them."
	if affection >= 35 and trust >= 20:
		return "There's a real warmth here — dangerous, or precious."
	if trust >= 30 and suspicion <= 10:
		return "They seem to take you at your word."
	if comfort <= -20:
		return "The air between you is stiff."
	if affection >= 15 and suspicion >= 20:
		return "Drawn in, and still not sure why."
	if state.active_memories().size() > 0 and trust < 10:
		return "They remember something you did."
	return "The relationship is still taking shape."


func _suspicion_display_band(value: int) -> String:
	# For suspicion, higher = worse. Map absolute value into alarming bands.
	if value >= 70:
		return "intimate" # Convinced you're false
	if value >= 40:
		return "close" # Guarded
	if value >= 15:
		return "warm" # Curious / alert
	if value >= -15:
		return "neutral"
	if value >= -40:
		return "cold" # Wary but low
	return "hostile" # Odd edge case: negative suspicion = they dismiss threat


func _trend_hint(dim: String, value: int) -> String:
	if dim == RelationshipDimensions.SUSPICION:
		if value >= 40:
			return "rising_heat"
		if value <= 5:
			return "quiet"
		return "watched"
	if value >= 40:
		return "strong"
	if value <= -20:
		return "frayed"
	return "forming"


func _knowledge_hints(state: RelationshipState) -> Array[String]:
	var hints: Array[String] = []
	# Only surface curated flags meant for player-facing copy.
	const PLAYER_FACING := [
		"knows_cover_name",
		"suspects_tradecraft",
		"shared_personal",
		"saw_inconsistency",
		"owes_favor",
		"identified_voss",
	]
	for flag in PLAYER_FACING:
		if state.has_knowledge(flag):
			hints.append(flag)
	return hints
