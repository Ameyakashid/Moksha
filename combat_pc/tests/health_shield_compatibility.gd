extends "res://combat_pc/tests/shield_regression.gd"
## Run original M8 assertions unchanged against M12. Only reporting differs.
## Keep historical shield artifacts untouched and omit large per-tick arrays.
const GROUPS := ["outcomes", "history", "callbacks", "effects"]

func _run() -> void:
	source_paths.append_array([
		"res://combat_pc/resources/shield_profile.gd", "res://combat_pc/resources/shield_profile.tres",
		"res://combat_pc/tests/shield_regression.gd", "res://combat_pc/components/shield_contact_adapter.gd",
		"res://combat_pc/fixtures/guard_melee_fixture.gd", "res://combat_pc/fixtures/guard_projectile.gd",
		"res://combat_pc/components/health_component.gd", "res://combat_pc/components/health_component.tscn"
	])
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _outcome_and_identity_cases()
	await _history_cases()
	await _callback_cases()
	await _physical_effect_cases()
	_release_input()
	var stable := true
	var hashes := {}
	for path in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Production/test source changed during compatibility run; rerun required")
	var bounded: Array[Dictionary] = []
	for scenario in scenarios:
		bounded.append({"name": scenario.get("name", ""), "assertions": scenario.get("assertions", []), "checks": scenario.get("checks", 0), "failures": scenario.get("failures", 0), "measurements": scenario.get("measurements", {}), "recorded_physics_frames": scenario.get("frames", []).size(), "incoming_contacts": scenario.get("incoming", []).size(), "effect_reports": scenario.get("effect_reports", [])})
	var report := {"milestone": 12, "suite": "existing shield compatibility", "groups": GROUPS, "physics_hz": hz, "checks": checks, "failures": failures, "scenarios": bounded, "source_hashes": hashes, "production_hash_stable_during_run": stable, "generated_utc": Time.get_datetime_string_from_system(true), "execution": "Original shield regression cases and assertions, one production sample per real physics callback; compact report only"}
	FileAccess.open("res://combat_pc/tests/health_shield_compatibility_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  ") + "\n")
	print("HEALTH_SHIELD_COMPATIBILITY %dHz: groups %s, %d scenarios, %d checks, %d failures" % [hz, str(GROUPS), scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
