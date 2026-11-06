extends "res://campaign/quality/nov6_optional/all_optional_observer_v6.gd"
## A real cargo-top landing is recoverable by walking off the push side.
## Do not let the generic crate jump policy bounce forever over a plate crate.
func guide_plate(goal: Node) -> Dictionary:
	var plan := super.guide_plate(goal)
	var p = host.player
	if is_instance_valid(plate_cargo) and p.grounded and p._support == plate_cargo:
		var direction: float = signf(goal.position.x-plate_cargo.position.x)
		return {"raw":{"left":1.0} if direction >= 0 else {"right":1.0}}
	return plan
func capture_sources(directory: String) -> void:
	super.capture_sources(directory)
	if directory == "res://":
		var path := "res://campaign/quality/nov6_optional/all_optional_observer_v6.gd"
		checkpoint_hashes[path] = FileAccess.get_sha256(path)
