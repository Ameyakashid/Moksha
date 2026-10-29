extends "res://simulation/tests/sentinel_regression.gd"
## Reuses actual physics fixture helpers, never replaces combat with mocks.
var variant := "lancer"
func new_npc() -> Node2D:
	return load("res://campaign/enemies/" + variant + ".tscn").instantiate()
func _run() -> void:
	root.get_node("NoiseBus").noise_emitted.connect(bus_noise)
	for name in ["lancer", "keeper"]:
		variant = name
		for blind in [false, true]:
			for mode in ["hurt", "guard", "parry", "roll"]:
				await begin(name + " blind=" + str(blind) + " " + mode, 3, 300, 336)
				npc.set_blind_mode(blind)
				if mode == "guard": driver.frame = {"shield": true}; await frames(ceili(hz * 0.25))
				attack()
				check(await until(func(): return npc.weapon_phase == &"windup"), "AI requests shared committed windup")
				var warnings := events.filter(func(e): return e.kind == &"enemy_windup" and e.source_id == npc.get_instance_id())
				check(warnings.size() == 1 and warnings[0].origin.is_equal_approx(warnings[0].source_position + Vector2(0,-26)), "one physical-origin warning in either sight state")
				if mode == "parry":
					await until(func(): return npc._phase_elapsed >= npc._windup - 0.09)
					driver.frame = {"shield": true}
				elif mode == "roll":
					driver.frame = {"right": 1.0, "roll": true}
				if mode == "roll":
					await frames(ceili(hz * 1.3))
					check(receipts.is_empty() and pc.get_node("Health").current_health == 60, "ordinary roll escapes locked attack")
				else:
					check(await until(func(): return not receipts.is_empty()), "physical sweep reaches actual player receiver")
					var expected: StringName = &"parried" if mode == "parry" else (&"guarded" if mode == "guard" else &"hurt")
					check(not receipts.is_empty() and receipts[0].outcome == expected, "stock defense adjudicates " + mode)
					if mode == "parry":
						check(npc.dead and npc.health == 0 and defeats == 1, "real counter kills once")
						await frames(3)
						check(npc.collision_layer == 0 and npc.get_node("BodyShape").disabled, "dead body removed")
						var serial: int = npc.attack_serial
						npc.reset_at(Vector2(336,200)); npc.ai_enabled = false; await frames(3)
						check(npc.health == 3 and not npc.dead and npc.attack_serial == serial and npc.collision_layer == 32, "reset restores life without reusing attack ID")
					npc.ai_enabled = false
					await frames(ceili(hz * 0.5))
					check(receipts.size() == 1, "bounded swing cannot repeat damage")
				await finish()
		await begin(name + " player sword and interruption", 3, 300, 336)
		attack(); await until(func(): return npc.weapon_phase == &"windup")
		# Keeper has physically backed out of sword reach: close using real input.
		if name == "keeper":
			driver.frame = {"right": 1.0}
			await until(func(): return npc.position.x - pc.position.x < 35, 0.4)
		driver.frame = {"attack": true}; await frames(1); driver.frame = {}
		check(await until(func(): return npc.health < 3), "real player J sweep damages captain")
		check(npc.main_action == &"hurt" and npc.weapon_phase == &"idle", "normal hit interrupts commitment")
		await finish()
		await begin(name + " solid terrain occludes sight", 3, 300,336)
		surface(Vector2(318,165),Vector2(8,70)); await frames(3); attack(); await frames(hz)
		check(npc.attack_serial == 0 and receipts.is_empty(), "wall blocks AI and damage")
		await finish()
		await begin(name + " pause freezes action", 3,300,336)
		attack(); await until(func(): return npc.weapon_phase == &"windup")
		var elapsed: float = npc._phase_elapsed
		var at: Vector2 = npc.position
		paused = true; await frames(20)
		check(npc._phase_elapsed == elapsed and npc.position == at and receipts.is_empty(), "paused shared controller neither travels nor attacks")
		paused = false
		check(await until(func(): return not receipts.is_empty()), "resume completes real commitment")
		await finish()
	variant = "lancer"
	await begin("lancer full supported travel", 3, 300, 410)
	attack(); check(await until(func(): return npc.weapon_phase == &"windup"), "charge begins outside ordinary melee range")
	var start: Vector2 = npc.position
	check(await until(func(): return not receipts.is_empty()), "traveling strike reaches target physically")
	check(start.x - npc.position.x > 45 and start.x - npc.position.x < 115, "charge is actual bounded travel not enlarged damage rectangle")
	await finish()
	await begin("lancer moving door stops committed charge",3,300,410)
	attack(); await until(func(): return npc.weapon_phase == &"windup")
	surface(Vector2(375,165),Vector2(10,70)); await frames(ceili(hz * 1.5)); npc.ai_enabled = false
	check(npc.position.x > 388 and receipts.is_empty(), "new wall stops body and occludes attack")
	await finish()
	await begin("lancer edge admission",3,180,140,200)
	attack(); await frames(hz * 2)
	check(npc.attack_serial == 0 and npc.position.y < 201, "unsafe entire dash lane is refused rather than falling")
	await finish()
	var report := {"hz": hz,"checks": checks,"failures": failures,"scenarios": scenarios,"scope":"Actual shared controller physics; no visual verification"}
	FileAccess.open("res://campaign/enemy_tests/results_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("CAPTAINS %d Hz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
