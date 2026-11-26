class_name ResponsiveLayout
extends RefCounted
## Breakpoints for keyboard/mouse narrative UI (browser-friendly 16:9).

enum SizeClass { COMPACT, REGULAR, WIDE }

static func size_class(viewport_size: Vector2) -> SizeClass:
	if viewport_size.x < 900 or viewport_size.y < 520:
		return SizeClass.COMPACT
	if viewport_size.x >= 1400:
		return SizeClass.WIDE
	return SizeClass.REGULAR


static func dialogue_height(viewport_size: Vector2) -> float:
	match size_class(viewport_size):
		SizeClass.COMPACT:
			return minf(220.0, viewport_size.y * 0.42)
		SizeClass.WIDE:
			return 260.0
		_:
			return 240.0


static func mission_width(viewport_size: Vector2) -> float:
	match size_class(viewport_size):
		SizeClass.COMPACT:
			return minf(280.0, viewport_size.x * 0.7)
		SizeClass.WIDE:
			return 380.0
		_:
			return 336.0
