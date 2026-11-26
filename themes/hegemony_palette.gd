class_name HegemonyPalette
extends RefCounted
## Tea in the Hegemony — visual tokens.
## Retro anime espionage / upper-class salon. Not purple sludge, not cream+terracotta.

const INK_DEEP := Color("0b1220")
const SALON_PANEL := Color("1a2332")
const BRASS := Color("c4a574")
const JADE := Color("5b8a7a")
const IVORY := Color("e8e0d4")
const VERMILLION := Color("c45c48")
const PANEL_PAPER := Color("d4cfc4")
const SLATE := Color("253040")
const AMBER := Color("d2aa50")
const WINE := Color("5a2830")
const TEAL_MIST := Color("3c5a64")
const MONOLOGUE := Color("c8b896")
const DIM_TEXT := Color("9a9286")
const CHOICE_HOVER := Color("2a3a4a")
const INTENT_PROFESSIONAL := Color("5b8a7a")
const INTENT_WARM := Color("c4a574")
const INTENT_PROBE := Color("d2aa50")
const INTENT_DEFLECT := Color("3c5a64")
const INTENT_RISK := Color("c45c48")
const INTENT_DEFAULT := Color("9a9286")

static func intent_color(intent: String) -> Color:
	match intent.to_lower():
		"professional", "formal", "cover":
			return INTENT_PROFESSIONAL
		"warm", "charm", "affection", "kind":
			return INTENT_WARM
		"probe", "investigate", "intel", "curious":
			return INTENT_PROBE
		"deflect", "evade", "joke", "humour", "humor":
			return INTENT_DEFLECT
		"risk", "aggressive", "confront", "lie":
			return INTENT_RISK
		_:
			return INTENT_DEFAULT


static func intent_label(intent: String) -> String:
	var i := intent.strip_edges()
	if i.is_empty():
		return "unclear"
	return i.to_lower()
