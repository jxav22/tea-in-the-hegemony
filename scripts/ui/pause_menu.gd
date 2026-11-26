extends Control
class_name PauseMenu
## Narrative pause — continues the fiction tone, not a settings dump.

signal resume_requested
signal open_settings
signal open_save
signal open_load
signal open_notebook
signal open_history
signal restart_requested

@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var resume_btn: Button = %ResumeBtn
@onready var history_btn: Button = %HistoryBtn
@onready var notebook_btn: Button = %NotebookBtn
@onready var save_btn: Button = %SaveBtn
@onready var load_btn: Button = %LoadBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var restart_btn: Button = %RestartBtn


func _ready() -> void:
	visible = false
	title.text = "Hold"
	subtitle.text = "The reception continues without you — briefly."
	resume_btn.pressed.connect(func (): resume_requested.emit())
	history_btn.pressed.connect(func (): open_history.emit())
	notebook_btn.pressed.connect(func (): open_notebook.emit())
	save_btn.pressed.connect(func (): open_save.emit())
	load_btn.pressed.connect(func (): open_load.emit())
	settings_btn.pressed.connect(func (): open_settings.emit())
	restart_btn.pressed.connect(func (): restart_requested.emit())


func open() -> void:
	visible = true
	resume_btn.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
