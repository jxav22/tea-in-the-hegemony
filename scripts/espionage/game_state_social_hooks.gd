class_name GameStateSocialHooks
extends RefCounted
## Typed interface Core can copy into GameState / DialogueRunner.
## Agent C does not own autoload/; this file documents the wiring contract.
##
## Expected GameState fields (save_version bundle):
##   flags: Dictionary
##   rels: Dictionary          ## via systems.to_save()["rels"]
##   memories: embedded in rels
##   cover_state: Dictionary
##   objectives: Dictionary
##   inventory: Dictionary    ## Core-owned; evidence ids may mirror inventory
##
## DialogueRunner should dispatch effects with ops in EFFECT_OPS.

const EFFECT_OPS: Array[String] = [
	"rel",
	"memory",
	"evidence",
	"cover",
	"objective",
	"knowledge",
	"set_flag",
]

const CONDITION_KINDS: Array[String] = [
	"flag",
	"rel",
	"memory",
	"cover",
	"evidence",
	"objective",
]


## Pseudocode Core can implement:
##   var systems: SystemsBridge
##   func apply_dialogue_effect(effect: Dictionary) -> Dictionary:
##       if str(effect.get("op","")) in EFFECT_OPS:
##           return systems.apply_effect(effect)
##       return {}
##   func check_dialogue_condition(cond: Dictionary) -> bool:
##       return systems.check_condition(cond)


static func describe_contract() -> Dictionary:
	return {
		"effect_ops": EFFECT_OPS.duplicate(),
		"condition_kinds": CONDITION_KINDS.duplicate(),
		"bootstrap": "SystemsBootstrap.create_with_reception_content()",
		"save_keys": ["rels", "cover_state", "evidence", "objectives"],
		"presentation": [
			"systems.present_character(id)",
			"systems.present_cover()",
			"systems.present_evidence()",
			"systems.present_mission()",
			"systems.present_debrief()",
		],
		"owned_paths": [
			"res://scripts/social/",
			"res://scripts/espionage/",
			"res://content/missions/",
			"res://content/evidence/",
		],
	}
