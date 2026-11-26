extends Control
class_name DialogueOverlay
## Presentation hook for Agent D. Core boot embeds a simpler copy;
## swap this scene in when UI polish lands. Binds DialogueRunner signals.

signal choice_picked(choice_id: String)
signal continue_pressed()

@onready var speaker_label: Label = %SpeakerLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var faculty_label: RichTextLabel = %FacultyLabel
@onready var choices_box: VBoxContainer = %ChoicesBox


func _ready() -> void:
	visible = false
	DialogueRunner.node_presented.connect(_on_node)
	DialogueRunner.choices_available.connect(_on_choices)
	DialogueRunner.dialogue_started.connect(func(_g: StringName) -> void: visible = true)
	DialogueRunner.dialogue_ended.connect(func(_g: StringName, _r: String) -> void: visible = false)
	FacultyBus.faculty_spoke.connect(_on_faculty)
	FacultyBus.faculty_cleared.connect(func() -> void: faculty_label.text = "")


func _on_node(node: Dictionary) -> void:
	speaker_label.text = str(node.get("speaker", ""))
	body_label.text = str(node.get("text", ""))


func _on_choices(choices: Array) -> void:
	for c: Node in choices_box.get_children():
		c.queue_free()
	if choices.is_empty():
		var b: Button = Button.new()
		b.text = "Continue"
		b.pressed.connect(func() -> void:
			continue_pressed.emit()
			DialogueRunner.advance()
		)
		choices_box.add_child(b)
		return
	for ch: Variant in choices:
		var choice: Dictionary = ch as Dictionary
		var b: Button = Button.new()
		b.text = str(choice.get("text", ""))
		var cid: String = str(choice.get("id", ""))
		b.pressed.connect(func() -> void:
			choice_picked.emit(cid)
			DialogueRunner.choose(cid)
		)
		choices_box.add_child(b)


func _on_faculty(faculty: StringName, text: String, _w: float, _n: StringName) -> void:
	faculty_label.text += "[b]%s[/b]: %s\n" % [String(faculty), text]
