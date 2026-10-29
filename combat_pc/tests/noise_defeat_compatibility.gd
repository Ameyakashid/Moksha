extends "res://combat_pc/tests/defeat_regression.gd"
## Rerun every unchanged M13 case; M14-only output preserves earlier reports.
func _run() -> void:
	var paths: Array[String] = defeat_paths.duplicate()
	paths.append_array(["res://combat_pc/components/noise_relay.gd","res://combat_pc/tests/defeat_regression.gd"])
	for path in paths: hashes[path] = FileAccess.get_sha256(path)
	await _defense_cases()
	await _physical_lethal_cases()
	await _cancellation_cases()
	await _fall_and_carrier_cases()
	await _reset_and_lifetime_cases()
	await _acquisition_callback_cases()
	await _parity_case()
	_pose_cases()
	var stable := true
	for path in paths: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable,"production sources stayed unchanged during run")
	var report := {"milestone":14,"suite":"unchanged M13 defeat cases","physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Original M13 assertions and real physics helpers; separate M14 output preserves accepted prior artifacts","limitations":["Headless integration and numeric pose checks; native visual review belongs to parent"]}
	FileAccess.open("res://combat_pc/tests/noise_defeat_compatibility_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("NOISE_DEFEAT_COMPATIBILITY %dHz: %d checks, %d scenarios, %d failures" % [hz,checks.size(),scenarios.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
