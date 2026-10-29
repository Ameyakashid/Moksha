extends Node2D
## Explicit view source only; host decides when the echo is enabled.
var source_visual: Node2D
@export var enabled := false
func _process(_dt: float) -> void:
	var view := get_node_or_null("View")
	if view == null: return
	view.visible = enabled and is_instance_valid(source_visual) and source_visual.has_method("get_pose")
	if not view.visible: return
	view.set_pose(source_visual.get_pose())
	# Screen-space projection; this node's transform remains an optional placement offset.
	view.transform = get_viewport().get_canvas_transform()*source_visual.global_transform
