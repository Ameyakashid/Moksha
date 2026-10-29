extends "res://combat_pc/fixtures/knockback_target.gd"
## Optional health composition. Reset fences the adapter before the existing
## motor and contact instrument reset. Removing StrikeHealth remains valid.

func reset_at(at: Vector2) -> void:
	var strike_health := get_node_or_null("StrikeHealth")
	if is_instance_valid(strike_health):
		strike_health.reset_to_full()
	super.reset_at(at)
