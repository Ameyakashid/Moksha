extends Node2D
## Screen-space canvas. The renderer projects world contours through the active Camera2D.
var sonar: Node

func _draw() -> void:
	if is_instance_valid(sonar):
		sonar.render_on(self)
