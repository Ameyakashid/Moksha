extends "res://combat_pc/tests/health_regression.gd"
## M19: all unchanged health cases, with the actual candidate profile on every actor.
func _run() -> void:
	var candidate_paths = ["res://combat_pc/resources/air_response_agile.tres", "res://combat_pc/resources/air_response_profile.gd", "res://combat_pc/resources/movement_profile.gd"]
	for path in candidate_paths: hashes[path] = FileAccess.get_sha256(path)
	for path in SOURCES: hashes[path] = FileAccess.get_sha256(path)
	await _outcomes()
	await _identity()
	await _legacy_and_invalid()
	await _reset_during_resolution()
	await _commit_and_actor_lifetime()
	await _reset_before_observer()
	await _nested_receipts()
	await _health_callback_reset()
	await _queued_component_lifetime()
	await _processed_callback_reset()
	await _detach_and_rebind()
	await _depletion_and_capacity()
	await _fixture_contact()
	await _motor_parity()
	var stable := true
	for path in candidate_paths: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	for path in SOURCES: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "production sources stayed unchanged during run")
	var report := {"candidate_resource":"res://combat_pc/resources/air_response_agile.tres","milestone": 12, "physics_hz": hz, "execution": "Real Godot physics callbacks and real player scene, optional component, swept melee/projectile fixtures", "generated_utc": Time.get_datetime_string_from_system(true), "engine": Engine.get_version_info().string, "checks": checks.size(), "failures": failures, "scenarios": scenarios, "total_physics_ticks": total_ticks, "production_hash_stable_during_run": stable, "source_hashes": hashes, "limitations": ["Headless integration checks; parent owns native visual review", "No death, healing, persistence, combat AI, or exact Dead Cells numerical parity claim"]}
	FileAccess.open("res://combat_pc/tests/air_response_health_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("AIR_RESPONSE_HEALTH_COMPAT_M12 %dHz: %d checks, %d scenarios, %d failures" % [hz, checks.size(), scenarios.size(), failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _new_actor(at := Vector2(100,200)) -> Node:
	var result = super._new_actor(at)
	result.profile = load("res://combat_pc/resources/air_response_agile.tres").duplicate(true)
	return result
