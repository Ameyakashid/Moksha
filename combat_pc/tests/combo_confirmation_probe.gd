extends "res://combat_pc/tests/shield_regression.gd"
## M9 pre-implementation physical continuation probe; explicit contact callback reset.
func _run() -> void:
	var source_hash := FileAccess.get_sha256("res://combat_pc/player.gd")
	await _shield_begin("reset inside strike confirmation retires unapplied target effect")
	var target = load("res://combat_pc/fixtures/contact_target.tscn").instantiate()
	target.position = Vector2(130, 200)
	world.add_child(target)
	await _sync_geometry()
	var callback = {"count": 0}
	actor.movement_event.connect(func(label, _data):
		if label == &"strike_confirmed" and callback.count == 0:
			callback.count += 1
			actor.reset_actor(Vector2(300, 200), -1))
	await _step({"attack": true})
	await _until(func(): return callback.count > 0, {"attack": true}, .4)
	await _step({"attack": true}, 3)
	_check(callback.count == 1, "real physical overlap reaches exactly one confirmation callback")
	_check(target.hits == 0, "reset during confirmation prevents the old target effect from applying afterward")
	_check(actor.weapon_phase == &"idle" and actor.position.x == 300, "reset remains authoritative after the interrupted physics callback")
	measurements["target_hits"] = target.hits
	measurements["confirmation_callbacks"] = callback.count
	await _finish()
	var output = {"milestone": 9, "physics_hz": hz, "controller_sha256": source_hash, "checks": checks, "failures": failures, "scenarios": scenarios}
	FileAccess.open("res://combat_pc/tests/combo_confirmation_before_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("COMBO CONFIRMATION PROBE %dHz: %d checks, %d failures" % [hz, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
