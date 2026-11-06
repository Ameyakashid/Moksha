extends "res://campaign/quality/nov6_optional/all_optional_observer_v4.gd"
## Use the unobstructed upper return to the Crown weather log rather than
## repeatedly climbing into loose authored cargo at the western ladder lip.
var weather_return_staged := false
func decide() -> Dictionary:
	if district_id == "crown_ascent" and host.goal_done("intake") and not host.goal_done("weather_log") and not weather_return_staged and reached_supported_waypoint(Vector2(2320,-30),28):
		weather_return_staged = true
		events.append({"event":"actual_weather_upper_return", "frame":frame, "position":str(host.player.position)})
	return super.decide()
func navigate(target: Vector2, d: Dictionary) -> Dictionary:
	if district_id == "crown_ascent" and host.goal_done("intake") and not host.goal_done("weather_log") and not weather_return_staged:
		var fighting: bool = host.enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and host.player.position.distance_to(enemy.position)<115)
		if not fighting:
			goal_target = Vector2(2320,-30)
			have_goal = true
	return super.navigate(target,d)
func capture_sources(directory: String) -> void:
	super.capture_sources(directory)
	if directory == "res://":
		var path := "res://campaign/quality/nov6_optional/all_optional_observer_v4.gd"
		checkpoint_hashes[path] = FileAccess.get_sha256(path)
