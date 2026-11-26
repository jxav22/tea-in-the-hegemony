extends Control
## Local presentation demo — exercises UI without Core dialogue engine.
## Open scenes/ui/ui_showcase.tscn (or set as main) to smoke-test visuals.

@onready var hud: GameHUD = %GameHUD

var _step: int = 0
var _demo_choices := [
	{"id": "c_pro", "text": "Keep the cover tight. Trade figures only.", "intent": "professional"},
	{"id": "c_warm", "text": "Offer her a real smile — dangerous, but human.", "intent": "warm"},
	{"id": "c_probe", "text": "Ask who else is watching the terrace tonight.", "intent": "probe"},
	{"id": "c_risk", "text": "Joke about badges. Clerk Moth would combust.", "intent": "risk"},
]


func _ready() -> void:
	hud.set_background("briefing")
	hud.set_objectives([
		{"id": "contact_maris", "text": "Make contact with Maris Quell", "status": "active"},
		{"id": "id_voss", "text": "Identify Lord Edrin Voss", "status": "active"},
		{"id": "fragment", "text": "Obtain shipping schedule discrepancy", "status": "active"},
		{"id": "cover", "text": "Maintain cover as Cassian Orth", "status": "active"},
	])
	hud.choice_made.connect(_on_choice)
	hud.advance_line.connect(_advance)
	hud.save_slot.connect(func (s): _toast("Saved slot %d (demo)" % (s + 1)))
	hud.load_slot.connect(func (s): _toast("Load slot %d (demo)" % (s + 1)))
	hud.restart_chapter.connect(func (): _step = 0; _advance())
	hud.set_save_summaries([
		{"exists": true, "chapter_id": "the_reception", "label": "After briefing"},
		{"empty": true},
		{"empty": true},
		{"empty": true},
		{"empty": true},
	])
	_advance()


func _advance() -> void:
	match _step:
		0:
			hud.set_background("briefing", false)
			hud.present_faculty("Insecurity", "She will notice your shoes.")
			hud.present_faculty("Analysis", "Shoes are irrelevant. Posture is a tell.")
			hud.present_line("wren_halden", "Wren Halden", "Smile with your eyes, Cassian. Not your teeth. Teeth are for people who sleep.", "cold")
		1:
			hud.hide_faculty()
			hud.set_background("foyer", true)
			hud.present_line("wren_halden", "Wren Halden", "Maris Quill—Quell—is Observatory Circle. She collects awkward men like paperweights. Be collectible. Be useful.", "amused")
		2:
			hud.set_background("salon", true)
			hud.present_faculty("Tradecraft", "Do not invent logistics trivia you cannot defend.")
			hud.present_faculty("Empathy", "She already clocked you. Soften.")
			hud.present_line("maris_quell", "Maris Quell", "You're the new liaison. Orth. You look like someone who alphabetises his anxieties.", "amused")
		3:
			hud.hide_faculty()
			hud.present_choices(_demo_choices)
			return
		4:
			hud.present_line("cassian_vale", "Cassian Vale", "I… keep accurate ledgers. Of everything. Including this conversation, apparently.", "flustered")
		5:
			hud.open_notebook([
				{
					"id": "guest_cipher",
					"title": "Guest-list annotation",
					"summary": "A brass-ink mark beside three names on the cloakroom copy.",
					"claims": ["Marks correlate with terrace access", "Not in the public seating chart"],
					"contradicts": ["Voss's secretary denied annex keys"],
					"verified": false,
				},
				{
					"id": "shipping_gap",
					"title": "Schedule discrepancy",
					"summary": "Manifest times disagree with harbour chatter by forty minutes.",
					"claims": ["Gap covers a quiet berth"],
					"contradicts": [],
					"verified": true,
				},
			])
			hud.open_profile({
				"id": "maris_quell",
				"display_name": "Maris Quell",
				"role": "Policy advisor, Observatory Circle",
				"expression": "amused",
				"rels": {"trust": 1, "familiarity": 0, "suspicion": 1, "respect": 2, "affection": 0, "comfort": -1, "perceived_authenticity": 1},
				"knowledge_flags": ["Works Observatory Circle policy", "Dry humour; watches shoes"],
				"memories": [{"summary": "Called out your alphabetised anxieties"}],
			})
			hud.present_line("taly_renn", "Taly Renn", "Oh good. Another man performing competence. Maris, blink twice if you need extraction.", "suspicious")
		_:
			hud.present_line("sera_kade", "Sera Kade", "Charming party. Try not to bleed on the porcelain.", "cold")
			hud.set_objectives([
				{"id": "contact_maris", "text": "Make contact with Maris Quell", "status": "done"},
				{"id": "id_voss", "text": "Identify Lord Edrin Voss", "status": "active"},
				{"id": "fragment", "text": "Obtain shipping schedule discrepancy", "status": "active"},
				{"id": "cover", "text": "Maintain cover as Cassian Orth", "status": "active"},
			])
	_step += 1


func _on_choice(choice_id: String) -> void:
	hud.log_player_choice(_label_for(choice_id), _intent_for(choice_id))
	_step = 4
	_advance()


func _label_for(choice_id: String) -> String:
	for c in _demo_choices:
		if c["id"] == choice_id:
			return c["text"]
	return choice_id


func _intent_for(choice_id: String) -> String:
	for c in _demo_choices:
		if c["id"] == choice_id:
			return c["intent"]
	return ""


func _toast(msg: String) -> void:
	hud.present_faculty("Analysis", msg)
