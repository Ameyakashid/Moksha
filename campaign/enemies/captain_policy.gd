extends "res://demo/components/sentinel_policy.gd"
## Decisions only: existing shared controller owns all travel, timing and damage.
@export_enum("lancer", "keeper") var pattern := "lancer"
var spacing_elapsed := 0.0

func reset_intent() -> void:
	super.reset_intent()
	spacing_elapsed = 0.0

func charge_lane_clear(actor: Node2D, direction: int) -> bool:
	# Admission inspects the entire committed travel plus braking margin, not
	# merely the next footstep. Collision remains authoritative if doors move.
	var travel := 220.0 * 0.38 + 30.0
	if actor.global_position.x + direction * travel < actor.room_left + 8 or actor.global_position.x + direction * travel > actor.room_right - 8: return false
	for distance in [20.0, 40.0, 60.0, 80.0, 100.0, 114.0]:
		if not Probe.obstacle(actor, direction, distance, deg_to_rad(actor.profile.maximum_floor_angle_degrees), actor.terrain_mask, actor.terrain_probe_profile).is_empty(): return false
	return true

func sample_intent(actor: Node2D, dt: float) -> Dictionary:
	var was_requested := _requested_last_sample
	var base := super.sample_intent(actor, dt)
	if actor.dead or not actor.enabled or not actor.ai_enabled or actor.hitpause_remaining > 0 or actor.main_action == &"hurt": return base
	if actor.weapon_phase != &"idle":
		spacing_elapsed = 0.0
		return base
	if not actor.grounded or not target_available(actor): return base
	var offset: Vector2 = actor._player.global_position - actor.global_position
	if absf(offset.y) >= 27 or absf(offset.x) > actor.detection_range or not terrain_visible(actor, actor._player.global_position + Vector2(0,-20)): return base
	var direction := -1 if offset.x < 0 else 1
	if pattern == "keeper":
		# One bounded backstep invites pursuit, then a committed long thrust.
		# Never retreat forever; obstruction also immediately ends spacing.
		if absf(offset.x) < 58 and spacing_elapsed < 0.32:
			spacing_elapsed += dt
			var retreat := _walk(actor, -direction, 0.85, dt)
			if not retreat.is_empty():
				_requested_last_sample = false
				state = &"spacing"
				reason = "Bounded backstep before locked long thrust"
				return retreat
			spacing_elapsed = 0.32
		return base
	if absf(offset.x) > 130: return base
	if not charge_lane_clear(actor, direction):
		_requested_last_sample = false
		# Do not dash off an edge; walk only through shared terrain admission.
		return _walk(actor, direction, 0.55, dt) if absf(offset.x) > 44 else {}
	if actor.facing != direction: return {"move": Vector2(direction * 0.1,0)}
	if decision_cooldown <= 0 and not was_requested:
		_requested_last_sample = true
		state = &"charge_ready"
		reason = "Clear supported lane; locked charge request"
		return {"attack": true}
	return {}
