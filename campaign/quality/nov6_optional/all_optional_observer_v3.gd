extends "res://campaign/quality/nov6_optional/all_optional_observer_v2.gd"
## Collect an optional crate pocket before running its loose cargo down the hall.
## Source receipts deliberately exclude unrelated concurrent QA harness edits.
var active_optional_plate: Node

func decide() -> Dictionary:
	if not is_instance_valid(active_optional_plate) or active_optional_plate.completed:
		active_optional_plate = null
		for goal in host.goals:
			if goal.kind != "plate" or goal.completed or not goal.available: continue
			if host.player.position.distance_to(goal.position)<380:
				active_optional_plate = goal
				break
	if is_instance_valid(active_optional_plate):
		have_goal = true
		goal_target = active_optional_plate.position
		var plan := guide_plate(active_optional_plate)
		if plan.has("raw"): return plan.raw
		goal_target = plan.get("target",goal_target)
		return production_decide()
	return super.decide()

func navigate(target: Vector2, d: Dictionary) -> Dictionary:
	var p = host.player
	var fighting: bool = host.enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and p.position.distance_to(enemy.position)<115)
	if have_goal and not fighting and p.grounded and goal_target.y > p.position.y+35:
		for rect in d.platforms:
			var margin: float = p.profile.body_width * 0.5 + 2
			if rect.size.y<=18 or absf(p.position.y-rect.position.y)>3 or p.position.x<rect.position.x-margin or p.position.x>rect.end.x+margin: continue
			var side: float = signf(goal_target.x-rect.get_center().x)
			if side == 0: side = -1
			var lip_x: float = rect.end.x+45 if side > 0 else rect.position.x-45
			nav_trace = {"observer_recovery":"solid_return_departure", "support":str(rect), "optional_target":str(goal_target), "lip":lip_x}
			return {"target":Vector2(lip_x,goal_target.y), "jump":false, "up":false, "drop":false}
	return super.navigate(target,d)

func capture_sources(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension() in ["gd","tscn","tres","gdshader","godot"]:
			var path := directory.path_join(filename)
			checkpoint_hashes[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory):
		if child.begins_with(".") or "test" in child or child in ["quality","qa_audit","evidence","docs"]: continue
		capture_sources(directory.path_join(child))
	if directory == "res://":
		for path in ["res://campaign/quality/nov6_optional/all_optional_route.gd","res://campaign/quality/nov6_optional/all_optional_recovery_route.gd","res://campaign/quality/nov6_optional/all_optional_observer_v2.gd",get_script().resource_path,"res://campaign/route_tests/l23_route.gd","res://demo/tests/expanded_mission_route_bot.gd"]:
			checkpoint_hashes[path] = FileAccess.get_sha256(path)
