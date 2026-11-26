extends SceneTree
## Deprecated entry — use test_runner.tscn so autoloads resolve.
## Kept as a pointer for older docs.


func _init() -> void:
	printerr("Use: godot --headless --path . res://tests/core/test_runner.tscn")
	quit(2)
