extends "res://combat_pc/tests/npc_footstep_regression.gd"
## Narrow diagnostic runner; final acceptance also includes this exact case.
func _run() -> void:
	SOURCE = load("res://combat_pc/components/character_footsteps.tscn")
	COMPOSED = load("res://combat_pc/fixtures/footstep_npc.tscn")
	autoload_initial = root.get_node("NoiseBus").event_count
	await _late_air_pause()
	var report := {"physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"source_sha256":FileAccess.get_sha256("res://combat_pc/components/character_footsteps.gd"),"bridge_sha256":FileAccess.get_sha256("res://combat_pc/fixtures/footstep_npc_motor.gd")}
	FileAccess.open("res://combat_pc/tests/npc_footstep_late_air_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("NPC_FOOTSTEP_LATE_AIR %dHz: %d checks, %d failures"%[hz,checks.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
