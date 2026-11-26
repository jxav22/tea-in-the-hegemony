extends Control
class_name FacultyStack
## Stack of comic-panel faculty interjections — they disagree in frames.

const MAX_PANELS := 3
const FacultyPanelScene := preload("res://scenes/ui/faculty_panel.tscn")

var reduce_motion: bool = false
var _panels: Array[FacultyPanel] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear_all(animate: bool = true) -> void:
	for p in _panels:
		if is_instance_valid(p):
			if animate and p.has_method("hide_panel"):
				p.hide_panel(reduce_motion)
			else:
				p.queue_free()
	_panels.clear()


func show_interjection(faculty: String, text: String) -> void:
	# Cap stack — drop oldest quietly
	while _panels.size() >= MAX_PANELS:
		var old: FacultyPanel = _panels.pop_front()
		if is_instance_valid(old):
			old.hide_panel(true)
	var panel: FacultyPanel = FacultyPanelScene.instantiate() as FacultyPanel
	panel.name = "Faculty_%d" % _panels.size()
	var i := _panels.size()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_top = 72.0 + float(i) * 118.0
	panel.offset_bottom = panel.offset_top + 120.0
	panel.offset_left = -360.0 - float(i) * 6.0
	panel.offset_right = -24.0 - float(i) * 6.0
	add_child(panel)
	_panels.append(panel)
	panel.call_deferred("show_interjection_styled", faculty, text, reduce_motion, i)
