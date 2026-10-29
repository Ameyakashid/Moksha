extends "res://combat_pc/tests/noise_regression.gd"
## M19: all unchanged noise cases, with the actual candidate profile on every actor.
func _run() -> void:
	var candidate_paths = ["res://combat_pc/resources/air_response_agile.tres", "res://combat_pc/resources/air_response_profile.gd", "res://combat_pc/resources/movement_profile.gd"]
	for path in candidate_paths: hashes[path] = FileAccess.get_sha256(path)
	for path in NOISE_SOURCES: hashes[path] = FileAccess.get_sha256(path)
	await _physical_origins()
	await _snapshot_teleport()
	await _movement_callback_resets()
	await _legacy_and_receipt_resets()
	await _nested_noise()
	await _binding_lifetime()
	await _bus_callback_retirement()
	await _filter_and_pause()
	await _attached_motor_parity()
	await _health_defeat_integration()
	var stable := true
	for path in candidate_paths: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	for path in NOISE_SOURCES: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "production sources stayed unchanged during run")
	var report := {"candidate_resource":"res://combat_pc/resources/air_response_agile.tres","milestone":14,"suite":"focused noise relay","physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"engine":Engine.get_version_info().string,"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Real reusable actor and local unchanged NoiseBus; one driver call per engine physics callback. Contract and retirement cases explicitly invoke committed-noise admission or retained relay callables.","limitations":["Focused headless integration; parent owns native visual review","Noise provenance only, with no audio playback or sensory behavior"]}
	FileAccess.open("res://combat_pc/tests/air_response_noise_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("AIR_RESPONSE_NOISE_COMPAT_M14 %dHz: %d checks, %d scenarios, %d failures" % [hz,checks.size(),scenarios.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _new_actor(at := Vector2(100,200)) -> Node:
	var result = super._new_actor(at)
	result.profile = load("res://combat_pc/resources/air_response_agile.tres").duplicate(true)
	return result
