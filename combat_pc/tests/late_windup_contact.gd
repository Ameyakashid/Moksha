extends "res://combat_pc/tests/combat_regression.gd"
func _run() -> void:
	var first_hits: Array = []
	for use_lease in [false, true]:
		await _begin("admitted contact" if use_lease else "neutral contact")
		actor.melee_chain = load("res://demo/resources/sentinel_melee.tres").duplicate(true)
		if use_lease:
			actor.movement_event.connect(func(kind: StringName, _packet: Dictionary):
				if kind == &"attack_started": _check(actor.request_late_windup(actor.late_windup_admission_snapshot(), 0.18, 0.5), "fixture admits exact committed strike"))
		var target = _target(Vector2(131, 185))
		await _step({"attack":true})
		var start_tick: int = driver.ticks
		_check(await _until(func(): return target.hits > 0, {}, 1.2), "real target receives committed contact")
		first_hits.append(driver.ticks - start_tick)
		_check(target.hits == 1 and actor.weapon_phase == &"active", "first contact only in active phase")
		_check(await _until(func(): return actor.weapon_phase == &"idle", {}, 1.5), "normal recovery completes")
		_check(target.hits == 1, "one target receives one hit per serial")
		await _finish()
	_check(absf(float(first_hits[1] - first_hits[0]) / hz - 0.18) <= 1.0 / hz + 0.000001, "actual first contact delayed by bounded tail within one physics tick")
	print(JSON.stringify({"suite":"opt-in real contact", "physics_hz":hz,"checks":checks,"failures":failures,"first_hit_ticks":first_hits}))
	quit(0 if failures.is_empty() else 1)
