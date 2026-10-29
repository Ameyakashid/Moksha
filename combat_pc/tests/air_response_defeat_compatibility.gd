extends "res://combat_pc/tests/defeat_regression.gd"
## M19: all unchanged defeat cases, with the actual candidate profile on every actor.
func _run() -> void:
	var candidate_paths = ["res://combat_pc/resources/air_response_agile.tres", "res://combat_pc/resources/air_response_profile.gd", "res://combat_pc/resources/movement_profile.gd"]
	for path in candidate_paths: hashes[path] = FileAccess.get_sha256(path)
	for path in defeat_paths: hashes[path] = FileAccess.get_sha256(path)
	await _defense_cases()
	await _physical_lethal_cases()
	await _cancellation_cases()
	await _fall_and_carrier_cases()
	await _reset_and_lifetime_cases()
	await _acquisition_callback_cases()
	await _parity_case()
	_pose_cases()
	var stable := true
	for path in candidate_paths: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	for path in defeat_paths: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "production sources stayed unchanged during run")
	var report := {"candidate_resource":"res://combat_pc/resources/air_response_agile.tres","milestone":13,"physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"engine":Engine.get_version_info().string,"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Real reusable player and optional Health/DefeatResponse, one driver call per engine physics callback; bounded assertions and measurements","limitations":["Headless integration and numeric pose checks; native visual review belongs to parent","Authored collapse policy and timing; no source-game death-animation parity claim"]}
	FileAccess.open("res://combat_pc/tests/air_response_defeat_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("AIR_RESPONSE_DEFEAT_COMPAT_M13 %dHz: %d checks, %d scenarios, %d failures" % [hz,checks.size(),scenarios.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _new_actor(at := Vector2(100,200)) -> Node:
	var result = super._new_actor(at)
	result.profile = load("res://combat_pc/resources/air_response_agile.tres").duplicate(true)
	return result
