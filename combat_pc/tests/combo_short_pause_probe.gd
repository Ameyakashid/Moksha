extends "res://combat_pc/tests/combo_regression.gd"
func _run() -> void:
	var source_hash := FileAccess.get_sha256("res://combat_pc/player.gd")
	await _combo_begin("short active phase still receives contact after entry-noise hitpause")
	actor.melee_chain.steps.resize(1)
	var definition = actor.melee_chain.steps[0]
	definition.next_step = -1; definition.windup_seconds = .001; definition.active_seconds = .001; definition.recovery_seconds = .001
	var target := _target(Vector2(131, 200), "PausedShortPhase")
	await _sync_geometry()
	var pause := [0]
	actor.noise_requested.connect(func(_at, kind, _loud, _source):
		if kind == &"strike" and pause[0] == 0: pause[0] = 1; actor.apply_hitpause(.08))
	await _step({"attack": true}); await _seconds({}, .3)
	_check(pause[0] == 1 and _count("attack_started") == 1, "one admitted short attack reaches its actual entry feedback callback")
	_check(target.hits == 1, "the paused short active phase receives its one physical contact opportunity after resume")
	measurements["target_hits"] = target.hits; measurements["strike_sample_count"] = strike_samples.size()
	await _finish()
	var output := {"milestone": 9, "physics_hz": hz, "controller_sha256": source_hash, "checks": checks, "failures": failures, "scenarios": scenarios}
	FileAccess.open("res://combat_pc/tests/combo_short_pause_before_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("COMBO SHORT PAUSE %dHz: %d checks, %d failures" % [hz, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
