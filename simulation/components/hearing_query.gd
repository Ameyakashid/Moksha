extends RefCounted
## Pure admission from real event origin + current listener geometry. The result
## contains evidence only. AI decisions and visual presentation live elsewhere.
const Profile = preload("res://simulation/resources/hearing_profile.gd")
static func sample(listener: Node2D, origin: Vector2, loudness: float, source: Node, profile: Profile) -> Dictionary:
	if not is_instance_valid(listener) or not listener.is_inside_tree() or listener.is_queued_for_deletion(): return {}
	if profile == null or not profile.hearing_enabled: return {}
	if not origin.is_finite() or not is_finite(loudness) or loudness <= 0: return {}
	for value in [profile.range_at_unit_loudness, profile.gain, profile.minimum_loudness_scale, profile.maximum_loudness_scale, profile.blocked_range_multiplier, profile.contact_endpoint_tolerance]:
		if not is_finite(value): return {}
	if is_instance_valid(source):
		if not source.is_inside_tree() or source.is_queued_for_deletion() or source.get_tree() != listener.get_tree(): return {}
		if source.get_viewport().world_2d != listener.get_world_2d(): return {}
	if profile.minimum_loudness_scale < 0 or profile.maximum_loudness_scale < profile.minimum_loudness_scale: return {}
	if profile.ignore_own_source and source == listener: return {}
	var ear := listener.global_position + profile.ear_offset
	if not ear.is_finite(): return {}
	var distance := ear.distance_to(origin)
	var radius := maxf(0, profile.range_at_unit_loudness) * maxf(0, profile.gain) * clampf(loudness, maxf(0, profile.minimum_loudness_scale), maxf(profile.minimum_loudness_scale, profile.maximum_loudness_scale))
	if not is_finite(radius) or radius <= 0 or distance > radius: return {}
	var blocked := false
	if profile.terrain_attenuation_enabled and not ear.is_equal_approx(origin):
		var excluded: Array[RID] = []
		if listener is CollisionObject2D: excluded.append(listener.get_rid())
		if is_instance_valid(source) and source is CollisionObject2D: excluded.append(source.get_rid())
		var query := PhysicsRayQueryParameters2D.create(ear, origin.move_toward(ear, clampf(profile.contact_endpoint_tolerance, 0, 1)), profile.terrain_mask, excluded)
		query.collide_with_areas = false
		query.hit_from_inside = true
		blocked = not listener.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
		if blocked: radius *= clampf(profile.blocked_range_multiplier, 0, 1)
	if not is_finite(radius) or radius <= 0 or distance > radius: return {}
	return {"origin": origin, "listener_position": ear, "source_id": source.get_instance_id() if is_instance_valid(source) else 0,
		"loudness": loudness, "distance": distance, "audible_radius": radius, "terrain_blocked": blocked,
		"strength": clampf(1.0 - distance / radius, 0, 1)}
