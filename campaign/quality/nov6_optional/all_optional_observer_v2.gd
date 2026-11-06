extends "res://campaign/quality/nov6_optional/all_optional_recovery_route.gd"
## A distant ladder must not suppress an ordinary crate-clearance jump.
func decide() -> Dictionary:
	var raw := super.decide()
	var p = host.player
	var direction: float = float(raw.get("right",0.0))-float(raw.get("left",0.0))
	if p.grounded and stagnant > 0.5 and direction != 0 and not raw.get("attack",false) and not raw.get("shield",false) and not p._last_jump_held:
		var contact := KinematicCollision2D.new()
		if p.test_move(p.global_transform,Vector2(signf(direction)*20,0),contact,p.profile.collision_margin) and contact.get_collider() is RigidBody2D:
			# Do not jump out of the deliberate local pressure-plate push.
			if not is_instance_valid(plate_cargo) or p.position.distance_to(plate_cargo.position)>100:
				raw.jump = true
				jump_age = 0
				jump_released = false
				events.append({"event":"ordinary_crate_clearance_jump", "frame":frame, "position":str(p.position), "obstruction":str(contact.get_collider().position)})
	return raw
