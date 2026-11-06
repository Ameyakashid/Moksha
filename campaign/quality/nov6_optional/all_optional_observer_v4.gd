extends "res://campaign/quality/nov6_optional/all_optional_observer_v3.gd"
## Read-only optional-route planner uses the authored baffles above live strips.
var baffle_step := 0
var baffle_points: Array[Vector2] = [Vector2(510,80),Vector2(1420,80),Vector2(1900,135),Vector2(2240,80),Vector2(2360,80),Vector2(1900,135),Vector2(1420,80),Vector2(1240,80),Vector2(1900,135),Vector2(2360,80),Vector2(2800,25),Vector2(2930,25),Vector2(3540,80),Vector2(3730,300)]
func decide() -> Dictionary:
	if district_id == "works_baffle_hall" and baffle_step < baffle_points.size():
		var required: String = {4:"baffle_key",7:"quiet_bus",11:"echo_notes",13:"quiet_lock"}.get(baffle_step,"")
		if reached_supported_waypoint(baffle_points[baffle_step],28) and (required.is_empty() or host.goal_done(required)):
			events.append({"event":"actual_safe_baffle_waypoint", "index":baffle_step, "frame":frame, "position":str(host.player.position)})
			baffle_step += 1
	return super.decide()
func navigate(target: Vector2, d: Dictionary) -> Dictionary:
	if district_id == "works_baffle_hall" and baffle_step < baffle_points.size():
		var fighting: bool = host.enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and host.player.position.distance_to(enemy.position)<115)
		if not fighting:
			goal_target = baffle_points[baffle_step]
			have_goal = true
	return super.navigate(target,d)
func capture_sources(directory: String) -> void:
	super.capture_sources(directory)
	if directory == "res://":
		var path := "res://campaign/quality/nov6_optional/all_optional_observer_v3.gd"
		checkpoint_hashes[path] = FileAccess.get_sha256(path)
