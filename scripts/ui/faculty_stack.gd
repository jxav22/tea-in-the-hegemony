extends Control
class_name FacultyStack
## Stack of comic-panel faculty interjections — they disagree in frames.

const MAX_PANELS := 3
const FacultyPanelScene := preload("res://scenes/ui/faculty_panel.tscn")
const STAGGER_SEC := 0.11

var reduce_motion: bool = false
var _panels: Array[FacultyPanel] = []
var _queue: Array[Dictionary] = []
var _releasing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear_all(animate: bool = true) -> void:
	_queue.clear()
	_releasing = false
	for p in _panels:
		if is_instance_valid(p):
			if animate and p.has_method("hide_panel"):
				p.hide_panel(reduce_motion)
			else:
				p.queue_free()
	_panels.clear()


func show_interjection(faculty: String, text: String) -> void:
	## Queue so disagreeing voices land as a comic beat, not a pile-up.
	_queue.append({"faculty": faculty, "text": text})
	if not _releasing:
		_release_next()


func _release_next() -> void:
	if _queue.is_empty():
		_releasing = false
		return
	_releasing = true
	var entry: Dictionary = _queue.pop_front()
	_spawn_panel(str(entry.get("faculty", "")), str(entry.get("text", "")))
	if reduce_motion:
		_release_next()
		return
	get_tree().create_timer(STAGGER_SEC).timeout.connect(_release_next)


func _spawn_panel(faculty: String, text: String) -> void:
	while _panels.size() >= MAX_PANELS:
		var old: FacultyPanel = _panels.pop_front()
		if is_instance_valid(old):
			old.hide_panel(true)
		_repack()
	var panel: FacultyPanel = FacultyPanelScene.instantiate() as FacultyPanel
	panel.name = "Faculty_%d" % Time.get_ticks_msec()
	_place_panel(panel, _panels.size())
	add_child(panel)
	_panels.append(panel)
	panel.call_deferred("show_interjection_styled", faculty, text, reduce_motion, _panels.size() - 1)
	# Auto-dismiss oldest after a dwell if stack stays full
	if not reduce_motion and _panels.size() >= MAX_PANELS:
		get_tree().create_timer(4.2).timeout.connect(func ():
			if _panels.size() >= MAX_PANELS and is_instance_valid(_panels[0]):
				var drop: FacultyPanel = _panels.pop_front()
				drop.hide_panel(false)
				_repack()
		)


func _place_panel(panel: Control, index: int) -> void:
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_top = 72.0 + float(index) * 118.0
	panel.offset_bottom = panel.offset_top + 120.0
	panel.offset_left = -360.0 - float(index) * 6.0
	panel.offset_right = -24.0 - float(index) * 6.0


func _repack() -> void:
	for i in _panels.size():
		if is_instance_valid(_panels[i]):
			_place_panel(_panels[i], i)
