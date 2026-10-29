extends RefCounted
const Profile = preload("res://simulation/resources/terrain_probe_profile.gd")
const DEFAULT_PROFILE = preload("res://simulation/resources/terrain_probe_default.tres")
## Read-only terrain observations. No actor-role branches, motion or world writes.
## A ray is prospective evidence, never an authoritative grounded flag: actual
## support/collision is owned by CharacterBody2D.move_and_slide().

static func ray(body: CollisionObject2D, from: Vector2, to: Vector2, mask: int) -> Dictionary:
	if not is_instance_valid(body) or not body.is_inside_tree(): return {}
	if not from.is_finite() or not to.is_finite(): return {}
	var query := PhysicsRayQueryParameters2D.create(from, to, mask, [body.get_rid()])
	query.collide_with_areas = false
	query.hit_from_inside = true
	return body.get_world_2d().direct_space_state.intersect_ray(query)

static func stopping_lookahead(speed: float, braking: float, dt: float, margin: float = 14.0, minimum: float = 24.0) -> float:
	for value in [speed, braking, dt, margin, minimum]:
		if not is_finite(value): return NAN
	if braking <= 0 or dt < 0 or margin < 0 or minimum < 0: return NAN
	var result := maxf(minimum, margin + speed * speed / (2.0 * braking) + absf(speed) * dt)
	return result if is_finite(result) else NAN

static func obstacle(body: CollisionObject2D, direction: float, ahead: float, max_slope_radians: float, mask: int = 1, profile: Profile = DEFAULT_PROFILE) -> String:
	if not is_instance_valid(body) or not body.is_inside_tree() or profile == null: return "Invalid probe"
	if not is_finite(direction) or not is_finite(ahead) or ahead < 0 or not is_finite(max_slope_radians): return "Invalid probe"
	for extent in [profile.floor_probe_above, profile.floor_probe_below]:
		if not is_finite(extent) or extent < 0: return "Invalid probe"
	for height in profile.wall_sample_heights:
		if not is_finite(height): return "Invalid probe"
	var origin := body.global_position
	for height in profile.wall_sample_heights:
		var wall := ray(body, origin + Vector2(0, height), origin + Vector2(signf(direction) * ahead, height), mask)
		if not wall.is_empty():
			var normal: Vector2 = wall.normal
			if normal.y > -0.65 and absf(normal.x) > 0.65: return "Wall"
	var toe := origin + Vector2(signf(direction) * ahead, 0)
	var floor_hit := ray(body, toe + Vector2(0, -profile.floor_probe_above), toe + Vector2(0, profile.floor_probe_below), mask)
	if floor_hit.is_empty(): return "Edge"
	var normal: Vector2 = floor_hit.normal
	if normal.dot(Vector2.UP) < cos(max_slope_radians): return "Steep floor"
	return ""
