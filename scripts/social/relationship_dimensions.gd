class_name RelationshipDimensions
extends RefCounted
## Canonical multi-dimension relationship axes. No single progress bar.

const TRUST := "trust"
const FAMILIARITY := "familiarity"
const SUSPICION := "suspicion"
const RESPECT := "respect"
const AFFECTION := "affection"
const COMFORT := "comfort"
const PERCEIVED_AUTHENTICITY := "perceived_authenticity"

const ALL: Array[String] = [
	TRUST,
	FAMILIARITY,
	SUSPICION,
	RESPECT,
	AFFECTION,
	COMFORT,
	PERCEIVED_AUTHENTICITY,
]

## Soft clamps for gameplay readability. Core may override via GameState config.
const MIN_VALUE := -100
const MAX_VALUE := 100
const DEFAULT_VALUE := 0

## Qualitative bands for presentation (never expose raw ints in UI by default).
const BAND_THRESHOLDS := {
	"hostile": -40,
	"cold": -15,
	"neutral": 15,
	"warm": 40,
	"close": 70,
}


static func is_valid(dimension: String) -> bool:
	return dimension in ALL


static func clamp_value(value: int) -> int:
	return clampi(value, MIN_VALUE, MAX_VALUE)


static func band_for(value: int) -> String:
	if value <= int(BAND_THRESHOLDS["hostile"]):
		return "hostile"
	if value <= int(BAND_THRESHOLDS["cold"]):
		return "cold"
	if value < int(BAND_THRESHOLDS["neutral"]):
		return "neutral"
	if value < int(BAND_THRESHOLDS["warm"]):
		return "warm"
	if value < int(BAND_THRESHOLDS["close"]):
		return "close"
	return "intimate"


static func default_map() -> Dictionary:
	var out := {}
	for dim in ALL:
		out[dim] = DEFAULT_VALUE
	return out
