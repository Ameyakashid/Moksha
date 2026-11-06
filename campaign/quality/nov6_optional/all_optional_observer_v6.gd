extends "res://campaign/quality/nov6_optional/all_optional_observer_v5.gd"
## The eastern Stamping rescue has a fixed ladder boardable from its solid
## plinth. Prefer that recovery route over repeatedly attempting a long jump.
var stamping_climb_stage := 0
func decide() -> Dictionary:
	if district_id == "l2_stamping_galleries" and host.goal_done("certify") and not host.goal_done("release"):
		var target := Vector2(3730,245) if stamping_climb_stage == 0 else Vector2(3730,100)
		if stamping_climb_stage < 2 and reached_supported_waypoint(target,25):
			events.append({"event":"actual_stamping_recovery_waypoint", "stage":stamping_climb_stage, "frame":frame, "position":str(host.player.position)})
			stamping_climb_stage += 1
	return super.decide()
func navigate(target: Vector2, d: Dictionary) -> Dictionary:
	if district_id == "l2_stamping_galleries" and host.goal_done("certify") and not host.goal_done("release") and stamping_climb_stage < 2 and (not is_instance_valid(active_optional_plate) or active_optional_plate.completed):
		var fighting: bool = host.enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and host.player.position.distance_to(enemy.position)<115)
		if not fighting:
			goal_target = Vector2(3730,245) if stamping_climb_stage == 0 else Vector2(3730,100)
			have_goal = true
	return super.navigate(target,d)
func capture_sources(directory: String) -> void:
	super.capture_sources(directory)
	if directory == "res://":
		var path := "res://campaign/quality/nov6_optional/all_optional_observer_v5.gd"
		checkpoint_hashes[path] = FileAccess.get_sha256(path)
