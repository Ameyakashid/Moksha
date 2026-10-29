extends "res://combat_pc/visuals/lithe_wireframe.gd"
## Optional pose-only screen view. No character or mission lookup.
func set_pose(value: Dictionary) -> void:
	_pose = value.duplicate(true)
	queue_redraw()
