extends Node
## Observation only, equally usable by device-input and NPC-driven actors.
@export_node_path("Node2D") var target_path: NodePath
@export var target_offset := Vector2(0,-22)
@export var fallback_distance := 400.0
func sample_aim(actor: Node2D, muzzle: Vector2) -> Vector2:
	var target := get_node_or_null(target_path) as Node2D
	if is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.get_world_2d() == actor.get_world_2d():
		return target.global_position + target_offset
	return muzzle + Vector2(actor.facing * fallback_distance, 0)
