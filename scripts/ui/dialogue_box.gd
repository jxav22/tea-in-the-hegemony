extends Control
class_name DialogueBox
## Bottom dialogue panel: speaker, typewriter text, continue cue, portrait.

signal advance_requested
signal typing_finished

@onready var panel: PanelContainer = %Panel
@onready var speaker_label: Label = %Speaker
@onready var body_label: RichTextLabel = %Body
@onready var continue_cue: Label = %ContinueCue
@onready var portrait: TextureRect = %Portrait
@onready var accent: ColorRect = %Accent

var settings: UISettings
var history: DialogueHistoryModel
var _typewriter := Typewriter.new()
var _speaker_id: String = ""
var _speaker_name: String = ""
var _awaiting_advance: bool = false


func _ready() -> void:
	visible = false
	continue_cue.visible = false
	_typewriter.finished.connect(_on_typing_finished)
	gui_input.connect(_on_gui_input)
	if body_label:
		body_label.bbcode_enabled = true
		body_label.fit_content = false
		body_label.scroll_active = true


func bind(settings_ref: UISettings, history_ref: DialogueHistoryModel) -> void:
	settings = settings_ref
	history = history_ref


func show_line(speaker_id: String, speaker_display: String, text: String, expression: String = "neutral") -> void:
	_speaker_id = speaker_id
	_speaker_name = speaker_display
	visible = true
	_awaiting_advance = false
	continue_cue.visible = false
	speaker_label.text = speaker_display
	accent.color = HegemonyPalette.JADE if speaker_id != "cassian_vale" else HegemonyPalette.BRASS
	var tex := PortraitBank.load_texture(PortraitBank.portrait_path(speaker_id, expression))
	portrait.texture = tex
	portrait.visible = tex != null
	var cps := settings.text_chars_per_second if settings else 42.0
	var instant := settings.instant_text if settings else false
	_typewriter.start(text, cps, instant)
	body_label.text = _typewriter.visible_text()
	if history:
		history.add_line(speaker_display, text)


func show_faculty(faculty: String, text: String) -> void:
	show_line("faculty_%s" % faculty.to_lower(), faculty, text, "neutral")
	speaker_label.add_theme_color_override("font_color", HegemonyPalette.AMBER)
	if history:
		# history already got speaker line; retag last as faculty
		if not history.entries.is_empty():
			history.entries[-1]["tags"] = ["faculty"]


func hide_box() -> void:
	visible = false
	_awaiting_advance = false


func is_typing() -> bool:
	return _typewriter.is_running()


func _process(delta: float) -> void:
	if not visible:
		return
	if _typewriter.is_running():
		_typewriter.tick(delta)
		body_label.text = _typewriter.visible_text()


func _on_typing_finished() -> void:
	body_label.text = _typewriter.full_text()
	_awaiting_advance = true
	continue_cue.visible = true
	typing_finished.emit()


func request_advance() -> void:
	if _typewriter.is_running():
		_typewriter.skip()
		return
	if _awaiting_advance:
		_awaiting_advance = false
		continue_cue.visible = false
		advance_requested.emit()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		request_advance()
		accept_event()
