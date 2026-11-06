extends "res://campaign/quality/nov6_optional/all_optional_route.gd"
## Observer-only recovery for optional return trips across low solid plinths.
## This changes button planning, never production movement/physics or level data.
func navigate(target: Vector2, d: Dictionary) -> Dictionary:
	var p = host.player
	var fighting: bool = host.enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and p.position.distance_to(enemy.position)<115)
	if have_goal and not fighting and p.grounded and goal_target.y > p.position.y+35:
		for rect in d.platforms:
			if rect.size.y <= 18 or absf(p.position.y-rect.position.y)>3 or p.position.x < rect.position.x or p.position.x > rect.end.x: continue
			# Select the departure lip from the support's fixed center, not the
			# player's jittering position beside a moving crate below the lip.
			var side: float = signf(goal_target.x-rect.get_center().x)
			if side == 0: side = -1
			var lip_x: float = rect.end.x+45 if side > 0 else rect.position.x-45
			nav_trace = {"observer_recovery":"solid_return_departure", "support":str(rect), "optional_target":str(goal_target), "lip":lip_x}
			return {"target":Vector2(lip_x,goal_target.y), "jump":false, "up":false, "drop":false}
	return super.navigate(target,d)
