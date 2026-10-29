extends "res://combat_pc/visuals/lithe_wireframe.gd"
## View-only echo of the actual body pose above blackout. No extra actor,
## physics tick, world geometry, enemy information or sonar source is created.
var host: Node
func _process(_dt: float) -> void:
	visible = is_instance_valid(host) and host.blind and is_instance_valid(host.player) and host.state not in ["title","complete"]
	if not visible: return
	var source = host.player.get_node_or_null("Visual")
	if not is_instance_valid(source):
		visible = false
		return
	_pose = source.get_pose()
	transform = get_viewport().get_canvas_transform()*source.global_transform
	modulate = Color(0.84,0.94,1,0.9)
	queue_redraw()
