extends "res://combat_pc/tests/combo_regression.gd"
func _run() -> void:
	var source_hash := FileAccess.get_sha256("res://combat_pc/player.gd")
	await _combo_begin("fallback pending edge cannot survive a configuration round trip", Vector2(100, 200), true, false, false)
	var target := _target(Vector2(131, 200), "UnexpectedFallback")
	await _sync_geometry()
	actor.set_weapon_permissions({"can_attack": false})
	await _step({"attack": true})
	actor.melee_chain = load("res://combat_pc/resources/light_chain.tres").duplicate(true)
	await _step()
	actor.melee_chain = null
	actor.set_weapon_permissions({"can_attack": true})
	await _seconds({}, .4)
	_check(_count("attack_started") == 0, "the old configuration-bound press cannot restart after an intervening chain assignment")
	_check(target.hits == 0, "no retired fallback edge creates an unexpected physical target effect")
	measurements["target_hits"] = target.hits
	await _finish()
	var output := {"milestone": 9, "physics_hz": hz, "controller_sha256": source_hash, "checks": checks, "failures": failures, "scenarios": scenarios}
	FileAccess.open("res://combat_pc/tests/combo_fallback_switch_before_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("COMBO FALLBACK SWITCH %dHz: %d checks, %d failures" % [hz, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
