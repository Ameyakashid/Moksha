extends "res://combat_pc/player.gd"
## Observations only; paired stock runs must retain identical physical results.
var probe_operations: Array[Dictionary] = []
func _probe_state() -> Dictionary:
	return {"position": global_position, "velocity": velocity, "grounded": grounded, "normal": _floor_contact_normal, "wall_normal": _wall_normal, "follow_segments": _ground_follow_segments}
func _sweep_motion(motion: Vector2) -> void:
	var before = _probe_state()
	super._sweep_motion(motion)
	probe_operations.append({"operation": "sweep", "request": motion, "before": before, "after": _probe_state()})
func _refresh_ground() -> void:
	var before = _probe_state()
	super._refresh_ground()
	probe_operations.append({"operation": "probe", "before": before, "after": _probe_state()})

func _sweep_segment(motion: Vector2, following_floor: bool) -> Vector2:
	var before = _probe_state()
	var unresolved = super._sweep_segment(motion, following_floor)
	probe_operations.append({"operation": "segment", "request": motion, "following": following_floor, "unresolved": unresolved, "before": before, "after": _probe_state()})
	return unresolved
