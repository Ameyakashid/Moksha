extends Node
## Small gym policy: observe LOS/range, submit ordinary attack intention.
@export_node_path("Node2D") var target_path: NodePath
@export var range_pixels := 450.0
func sample_intent(actor: Node2D, _dt: float) -> Dictionary:
	var target := get_node_or_null(target_path) as Node2D
	if not is_instance_valid(target) or actor.weapon_phase != &"idle" or actor.main_action != &"locomotion" or actor.is_defeated() or target.is_defeated(): return {}
	var origin := actor.global_position + Vector2(0,-22)
	var point := target.global_position + Vector2(0,-22)
	if origin.distance_to(point) > range_pixels or (point.x-origin.x)*actor.facing <= 0: return {}
	var query := PhysicsRayQueryParameters2D.create(origin,point,9,[actor.get_rid(),target.get_rid()])
	query.hit_from_inside = true
	return {"attack":true} if actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty() else {}
func reset_intent() -> void: pass
