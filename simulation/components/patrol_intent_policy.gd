extends Node
## Local, evidence-driven policy. It returns intention only and never moves,
## rotates, damages, grants footing to, or cancels momentum on an actor.
const Probe = preload("res://simulation/components/terrain_probe.gd")
const ProbeProfile = preload("res://simulation/resources/terrain_probe_profile.gd")
@export_node_path("Node2D") var target_path := NodePath("")
@export var patrol_radius := 120.0
@export_range(0.0, 1.0) var move_strength := 0.45
@export var sight_range := 260.0
@export var same_lane_height := 48.0
@export var stop_distance := 48.0
@export var terrain_profile: ProbeProfile
var state: StringName = &"settling"
var reason := "Waiting for real support"
var sees_target := false
var _home := Vector2.ZERO
var _has_home := false
var _direction := 1
func _ready() -> void:
	terrain_profile = terrain_profile.duplicate(true) if terrain_profile != null else ProbeProfile.new()
func reset_intent() -> void:
	_has_home = false
	_direction = 1
	sees_target = false
	state = &"settling"
func sample_intent(actor: Node2D, dt: float) -> Dictionary:
	if not _has_home:
		_home = actor.global_position
		_has_home = true
	sees_target = false
	if actor.is_defeated(): return _neutral(&"defeated", "No new intention")
	if not actor.grounded: return _neutral(&"falling", "Waiting for real support")
	var target := get_node_or_null(target_path) as Node2D if not target_path.is_empty() else null
	if is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.can_process() and target.get_world_2d() == actor.get_world_2d() and not (target.has_method("is_defeated") and target.is_defeated()):
		var offset := target.global_position - actor.global_position
		sees_target = offset.length() <= sight_range and absf(offset.y) <= same_lane_height and Probe.ray(actor, actor.global_position + Vector2(0, -22), target.global_position + Vector2(0, -22), actor.terrain_mask).is_empty()
		if sees_target:
			if absf(offset.x) <= stop_distance: return _neutral(&"holding", "Visible target within stopping distance")
			var direction := -1 if offset.x < 0 else 1
			var obstacle := _obstacle(actor, direction, dt)
			if not obstacle.is_empty(): return _neutral(&"blocked", obstacle + " on path to visible target")
			state = &"chasing"
			reason = "Target observed by range and clear terrain ray"
			return {"move": Vector2(direction * move_strength, 0)}
	var ahead := _lookahead(actor, _direction, dt)
	var predicted: float = actor.global_position.x + _direction * ahead
	# A real impulse may put the actor beyond its patrol interval. Only reject
	# outward travel; inward intention must remain available for recovery.
	var at_limit := (_direction > 0 and predicted >= _home.x + patrol_radius) or (_direction < 0 and predicted <= _home.x - patrol_radius)
	var obstacle := _obstacle(actor, _direction, dt)
	if at_limit or not obstacle.is_empty():
		_direction *= -1
		return _neutral(&"turning", "Patrol boundary" if at_limit else obstacle)
	state = &"patrolling"
	reason = "Local terrain rays clear"
	return {"move": Vector2(_direction * move_strength, 0)}
func _lookahead(actor: Node2D, direction: int, dt: float) -> float:
	return Probe.stopping_lookahead(maxf(0, actor.velocity.x * direction), actor.profile.ground_braking, dt, terrain_profile.body_margin, terrain_profile.minimum_lookahead)
func _obstacle(actor: Node2D, direction: int, dt: float) -> String:
	return Probe.obstacle(actor, direction, _lookahead(actor, direction, dt), deg_to_rad(actor.profile.maximum_floor_angle_degrees), actor.terrain_mask, terrain_profile)
func _neutral(next: StringName, why: String) -> Dictionary:
	state = next
	reason = why
	return {}
