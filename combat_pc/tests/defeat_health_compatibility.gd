extends "res://combat_pc/tests/health_regression.gd"
## All original M12 assertions; only output destination and milestone differ.
func _run() -> void:
	var paths: Array[String]=[]
	paths.assign(SOURCES)
	paths.append_array(["res://combat_pc/components/defeat_response.gd","res://combat_pc/tests/health_regression.gd"])
	for path in paths: hashes[path]=FileAccess.get_sha256(path)
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
	var stable:=true
	for path in paths: stable=stable and hashes[path]==FileAccess.get_sha256(path)
	_check(stable,"production sources stayed unchanged during run")
	var report: Dictionary={"milestone":13,"suite":"unchanged M12 health cases","physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Original M12 assertions and real physics helpers; separate output preserves accepted prior artifacts"}
	FileAccess.open("res://combat_pc/tests/defeat_health_compatibility_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("DEFEAT_HEALTH_COMPATIBILITY %dHz: %d checks, %d scenarios, %d failures" % [hz,checks.size(),scenarios.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
