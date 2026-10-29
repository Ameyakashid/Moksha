extends Node
## Intention only. Shared controller owns every action clock and physical outcome.
const Probe = preload("res://simulation/components/terrain_probe.gd")
const PeerFilter = preload("res://simulation/components/ai_hearing_filter.gd")
var state: StringName = &"patrol"
var reason := "Patrol"
var noise_goal := Vector2.ZERO
var noise_memory := 0.0
var decision_cooldown := 0.6
var _direction := 1
var _requested_last_sample := false
var _was_hurt := false
func reset_intent() -> void:
	state = &"patrol"
	noise_memory = 0.0
	decision_cooldown = 0.6
	_direction = 1
	_requested_last_sample = false
	_was_hurt = false
func admit_hearing(evidence: Dictionary) -> void:
	var actor := get_parent()
	if evidence.is_empty() or actor.dead or not actor.enabled: return
	var source := instance_from_id(int(evidence.get("source_id", 0))) if int(evidence.get("source_id", 0)) != 0 else null
	if PeerFilter.ignores(source, actor.hearing_peer_group): return
	noise_goal = evidence.origin
	noise_memory = actor.archetype_profile.hearing_memory_seconds
func target_available(actor: Node2D) -> bool:
	var target: Node2D = actor._player
	return is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.can_process() and target.get_world_2d() == actor.get_world_2d() and (not target.has_method("is_defeated") or not target.is_defeated())
func terrain_visible(actor: Node2D, point: Vector2) -> bool:
	return Probe.ray(actor, actor.global_position + Vector2(0, -23), point, 1).is_empty()
func _walk(actor: Node2D, direction: float, strength: float, dt: float) -> Dictionary:
	var ahead := Probe.stopping_lookahead(maxf(0, actor.velocity.x * direction), actor.profile.ground_braking, dt, actor.terrain_probe_profile.body_margin, actor.terrain_probe_profile.minimum_lookahead)
	var predicted: float = actor.global_position.x + direction * ahead
	var outward: bool = (direction < 0 and predicted < actor.room_left + 8) or (direction > 0 and predicted > actor.room_right - 8)
	var obstacle := Probe.obstacle(actor, direction, ahead, deg_to_rad(actor.profile.maximum_floor_angle_degrees), actor.terrain_mask, actor.terrain_probe_profile) if actor.grounded else ""
	if outward or not obstacle.is_empty():
		reason = "Observed boundary or " + obstacle
		return {}
	return {"move": Vector2(direction * strength, 0)}
func sample_intent(actor: Node2D, dt: float) -> Dictionary:
	if actor.dead or not actor.enabled: return {}
	if actor.hitpause_remaining > 0: return {}
	decision_cooldown = maxf(0, decision_cooldown - dt)
	noise_memory = maxf(0, noise_memory - dt)
	var was_requested := _requested_last_sample
	_requested_last_sample = false
	if actor.main_action == &"hurt":
		_was_hurt = true
		return {}
	if _was_hurt:
		_was_hurt = false
		decision_cooldown = maxf(decision_cooldown, 0.45)
	if not actor.ai_enabled or actor.weapon_phase != &"idle": return {}
	if not actor.grounded:
		state = &"patrol"
		return {}
	if target_available(actor):
		var offset: Vector2 = actor._player.global_position - actor.global_position
		var sight_limit: float = actor.archetype_profile.sight_range_exclusive
		var in_sight: bool = absf(offset.x) <= actor.detection_range and (sight_limit <= 0 or absf(offset.x) < sight_limit)
		if absf(offset.y) < 58 and in_sight and terrain_visible(actor, actor._player.global_position + Vector2(0, -20)):
			state = &"chase"
			var direction := -1 if offset.x < 0 else 1
			if absf(offset.x) <= actor._reach - 2 and absf(offset.y) < 27:
				if actor.facing != direction:
					reason = "Turn through ordinary movement intention"
					return {"move": Vector2(direction * 0.1, 0)}
				if decision_cooldown <= 0 and not was_requested:
					_requested_last_sample = true
					reason = "Visible target within authored request range"
					return {"attack": true}
				return {}
			reason = "Clear sight to target"
			return _walk(actor, direction, 1.0, dt)
	if noise_memory > 0:
		state = &"investigate"
		var dx: float = noise_goal.x - actor.global_position.x
		return _walk(actor, signf(dx), 1.0, dt) if absf(dx) >= 12 else {}
	state = &"patrol"
	if actor.global_position.x >= minf(actor.room_right - 12, actor._spawn.x + actor.patrol_radius): _direction = -1
	if actor.global_position.x <= maxf(actor.room_left + 12, actor._spawn.x - actor.patrol_radius): _direction = 1
	var result := _walk(actor, _direction, 0.43, dt)
	if result.is_empty(): _direction *= -1
	return result
