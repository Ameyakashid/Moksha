extends Node2D
var host: Node
func _process(_dt: float) -> void: queue_redraw()
func _draw() -> void:
	if is_instance_valid(host): host.render_hud(self)
