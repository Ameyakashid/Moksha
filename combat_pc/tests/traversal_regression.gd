extends "res://combat_pc/tests/combat_regression.gd"
## Reuses immutable M2 physics harness helpers; scenarios and outputs are separate.
## Drop/dive policy and every numeric value are original MOKSHA design.

var one_way_bodies: Array[Node] = []

func _run() -> void:
	production_paths.append("res://combat_pc/tests/combat_regression.gd")
	production_paths.append("res://combat_pc/tests/traversal_regression.gd")
	for path in production_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _traversal_cases()
	var hashes := {}
	for path in production_paths: hashes[path] = FileAccess.get_sha256(path)
	var stable := true
	for path in starting_hashes: stable = stable and starting_hashes[path] == hashes[path]
	if not stable: failures.append("Source files changed during traversal run; final rerun required")
	var report := {
		"milestone": 3, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(),
		"generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "Actual Godot physics callbacks, production player scene, collision sweeps and independent space queries",
		"numeric_source": "Original MOKSHA profile values; no recovered Dead Cells timings or executable parity",
		"movement_profile": _resource_values(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _resource_values(load("res://combat_pc/resources/combat_profile.tres"))
	}
	FileAccess.open("res://combat_pc/tests/traversal_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  "))
	print("MOKSHA TRAVERSAL %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _traversal_cases() -> void:
	await _drop_basics()
	await _drop_validation()
	await _drop_interruption()
	await _context_and_gates()
	await _dive_phases()
	await _dive_interruptions()
	await _dive_geometry_and_lifecycle()
	await _native_down_input()
	await _tight_stacks_and_host_edges()

func _begin(label: String, at := Vector2(100, 200), floor_present := true) -> void:
	one_way_bodies = []
	await super._begin(label, at, floor_present)

func _oneway(at: Vector2, size := Vector2(160, 8)) -> Node:
	var body = _surface(at, size, true)
	one_way_bodies.append(body)
	return body

func _shaped_body(at: Vector2, shapes: Array, flags: Array) -> StaticBody2D:
	var body = StaticBody2D.new(); body.position = at; body.collision_layer = 1; body.collision_mask = 0
	for index in shapes.size():
		var rect: Rect2 = shapes[index]
		var node = CollisionShape2D.new(); var shape = RectangleShape2D.new()
		shape.size = rect.size; node.shape = shape; node.position = rect.get_center()
		node.one_way_collision = flags[index]; node.one_way_collision_margin = 1
		body.add_child(node)
	world.add_child(body)
	if flags.all(func(value): return value): one_way_bodies.append(body)
	return body

func _setup_oneway(label: String, top := 140.0, lower_floor := true) -> Node:
	await _begin(label, Vector2(100, top - 6), false)
	var support = _oneway(Vector2(20, top))
	if lower_floor: _surface(Vector2(-500, top + 160), Vector2(1500, 40))
	await _until(func(): return actor.grounded, {}, .5)
	_check(actor.grounded and absf(actor.global_position.y - top) < .2, "fixture establishes genuine one-way support before contextual input")
	return support

func _ordinary_solid_overlap() -> bool:
	var query = PhysicsShapeQueryParameters2D.new(); var shape = RectangleShape2D.new()
	shape.size = Vector2(actor.profile.body_width - .12, actor.body_height - .12)
	query.shape = shape; query.transform = Transform2D(0, actor.global_position + Vector2(0, -actor.body_height * .5))
	query.collision_mask = 1
	var excluded: Array[RID] = [actor.get_rid()]
	for body in one_way_bodies:
		if is_instance_valid(body): excluded.append(body.get_rid())
	query.exclude = excluded
	var overlaps = actor.get_world_2d().direct_space_state.intersect_shape(query, 8)
	if not overlaps.is_empty():
		if not measurements.has("solid_overlap_samples"): measurements.solid_overlap_samples = []
		for overlap in overlaps:
			var collider = overlap.collider
			measurements.solid_overlap_samples.append({"tick": driver.ticks, "position": actor.global_position, "height": actor.body_height, "collider_position": collider.global_position, "collider_name": String(collider.name)})
	return not overlaps.is_empty()

func _exceptions() -> Array:
	return actor.get_collision_exceptions()

func _drop_basics() -> void:
	var upper = await _setup_oneway("drop reaches next distinct platform")
	var lower = _oneway(Vector2(20, 180)); await _step({}, 2)
	await _step({"down": 1.0, "jump": true})
	_check(actor.main_action == &"drop" and _count("drop_started") == 1 and _exceptions().has(upper) and not _exceptions().has(lower), "drop ignores only the validated supporting body")
	await _until(func(): return actor.grounded and actor.global_position.y > 160, {"down": 1.0, "jump": true})
	_check(actor.grounded and absf(actor.global_position.y - 180) < .2, "next independent one-way catches the drop")
	_check(_exceptions().is_empty() and not actor.telemetry().drop_exception_active, "target exception is removed after safe plane clearance")
	_check(_count("air_jump") == 0 and _count("ground_jump") == 0 and _count("dive_started") == 0 and _count("drop_started") == 1, "one held chord cannot become another drop, jump or dive")
	await _finish()
	await _begin("coplanar multi-shape support accepts drop", Vector2(100, 134), false)
	var body = _shaped_body(Vector2(20, 140), [Rect2(0, 0, 80, 8), Rect2(80, 0, 80, 8)], [true, true])
	_surface(Vector2(-200, 250), Vector2(800, 30)); await _until(func(): return actor.grounded)
	await _step({"down": 1.0, "jump": true})
	_check(_count("drop_started") == 1 and _exceptions().has(body), "dedicated upright coplanar rectangles are a valid target")
	await _until(func(): return actor.grounded and actor.global_position.y > 200)
	_check(_exceptions().is_empty() and absf(actor.global_position.y - 250) < .2, "multi-shape drop restores collision before lower solid landing")
	await _finish()
	for direction in [-1, 1]:
		await _setup_oneway("drop interrupted by roll against thin wall %d" % direction)
		_surface(Vector2(133 if direction > 0 else 63, 100), Vector2(4, 240)); await _step()
		await _step({"down": 1.0, "jump": true}); await _step(_direction(direction, {"roll": true}))
		_check(actor.main_action == &"roll" and _count("drop_started") == 1, "roll can interrupt accepted drop without replacing motor")
		var safe := true
		for _i in range(ceili(.6 / dt)):
			await _step(_direction(direction)); safe = safe and not _ordinary_solid_overlap()
		_check(actor.global_position.x <= 133 - actor.profile.body_width * .5 + .15 if direction > 0 else actor.global_position.x >= 67 + actor.profile.body_width * .5 - .15, "drop plus roll never bypasses an independent thin solid wall")
		_check(safe and _exceptions().is_empty(), "wall collision and targeted exception cleanup remain safe through roll")
		await _finish()

func _drop_validation() -> void:
	for mode in ["mixed", "stacked_same_body", "rotated", "nonrectangle", "ambiguous"]:
		await _begin("unsupported drop layout " + mode, Vector2(100, 130), false)
		var body: Node
		if mode == "mixed": body = _shaped_body(Vector2(20, 140), [Rect2(0, 0, 160, 8), Rect2(145, -80, 12, 88)], [true, false])
		elif mode == "stacked_same_body": body = _shaped_body(Vector2(20, 140), [Rect2(0, 0, 160, 8), Rect2(0, 45, 160, 8)], [true, true])
		elif mode == "rotated":
			body = _oneway(Vector2(20, 140)); body.rotation = .04
		elif mode == "nonrectangle":
			body = StaticBody2D.new(); body.collision_layer = 1; body.position = Vector2(100, 150)
			var shape = CollisionShape2D.new(); var capsule = CapsuleShape2D.new(); capsule.radius = 10; capsule.height = 120
			shape.shape = capsule; shape.rotation = PI * .5; shape.one_way_collision = true; body.add_child(shape); world.add_child(body); one_way_bodies.append(body)
		else:
			body = _oneway(Vector2(20, 140)); _oneway(Vector2(20, 140))
		_surface(Vector2(-200, 260), Vector2(800, 30)); await _until(func(): return actor.grounded, {}, .6)
		_check(actor.grounded, "unsupported geometry fixture still gives actual floor contact")
		var before: Vector2 = actor.global_position
		await _step({"down": 1.0, "jump": true}); await _seconds({"down": 1.0, "jump": true}, .2)
		_check(_count("drop_denied") == 1 and _count("drop_started") == 0 and _exceptions().is_empty(), "unsupported or ambiguous support is explicitly refused without leaking collision exception")
		_check(_count("ground_jump") == 0 and _count("air_jump") == 0 and _count("dive_started") == 0 and actor.global_position.distance_to(before) < 1, "denied chord has no fallback jump or dive")
		await _finish()

func _drop_interruption() -> void:
	for mode in ["attack", "damage", "removed", "disabled", "moving", "reset"]:
		var support = await _setup_oneway("drop exception lifetime " + mode)
		await _step({"down": 1.0, "jump": true})
		_check(_exceptions().has(support), "accepted drop creates target exception before interruption")
		if mode == "attack": await _step({"attack": true})
		elif mode == "damage": actor.receive_hit({"rollable": false, "impulse": Vector2(0, -100), "hitpause": .1})
		elif mode == "removed": support.queue_free()
		elif mode == "disabled": support.get_node("Shape").set_deferred("disabled", true)
		elif mode == "moving": support.moving = true; support.travel = Vector2(80, -30); support.travel_speed = 120
		else:
			actor.reset_actor(Vector2(230, 140)); _check(_exceptions().is_empty(), "reset synchronously removes targeted exception")
		if mode in ["attack", "damage"]:
			_check(actor.main_action != &"drop" and _exceptions().has(support), "action interruption does not prematurely restore crossing support")
		await _seconds({}, actor.profile.drop_max_ignore_seconds + .25)
		_check(_exceptions().is_empty() and not actor.telemetry().drop_exception_active, "targeted ignore eventually clears despite interruption or target change")
		_check(not _ordinary_solid_overlap(), "continued motion does not penetrate independent solids")
		await _finish()
	var held_support = await _setup_oneway("blocked drop cleanup stays explicit and target scoped")
	# A deliberately frozen velocity/gravity profile isolates the documented
	# impossible-clearance watchdog without replacing the real body or queries.
	await _step({"down": 1.0, "jump": true})
	actor.velocity = Vector2.ZERO
	actor.profile.gravity = 0
	await _seconds({}, actor.profile.drop_max_ignore_seconds + 2 * dt)
	_check(actor.main_action != &"drop" and _count("drop_cleanup_blocked") == 1 and _exceptions().size() == 1 and _exceptions().has(held_support), "finite action ends while unresolved overlap is reported once and keeps only target exception")
	await _seconds({}, actor.profile.drop_max_ignore_seconds)
	_check(_count("drop_cleanup_blocked") == 1, "blocked cleanup does not flood repeated events")
	held_support.queue_free(); await _step({}, 2)
	_check(_exceptions().is_empty() and not actor.telemetry().drop_exception_active, "removing obstructing target clears blocked cleanup")
	await _finish()

func _dive_interruptions() -> void:
	for phase in ["startup", "descent", "impact", "recovery"]:
		for action in ["roll", "jump", "attack"]:
			await _start_test_dive("dive " + phase + " interruption " + action)
			var reached = await _until(func(): return String(actor.dive_phase) == phase, {}, 2)
			_check(reached, "fixture reaches requested physical dive phase before interruption")
			var impacts_before = _count("dive_impact")
			if phase == "startup" and action == "jump": await _step()
			await _step({action: true})
			var allowed: bool = phase in ["startup", "recovery"] or (phase == "descent" and action == "roll")
			_check(actor.main_action != &"dive" if allowed else actor.main_action == &"dive", "ordinary interruption obeys authored phase matrix")
			if allowed:
				_check(actor.main_action == &"roll" if action == "roll" else (actor.weapon_phase == &"windup" if action == "attack" else _count("air_jump") + _count("ground_jump") == 1), "accepted interruption starts the requested owner once")
				await _seconds({}, .8)
				_check(_count("dive_impact") == impacts_before, "canceled dive cannot produce a later stale impact on ordinary landing")
			else:
				_check(actor.weapon_phase == &"idle" and _count("air_jump") + _count("ground_jump") == 0 and _count("roll_started") == 0, "denied phase request cannot take partial ownership")
			await _finish()
	for phase in ["startup", "descent", "impact", "recovery"]:
		for action in ["damage", "reset"]:
			await _start_test_dive("dive " + phase + " forced " + action)
			await _until(func(): return String(actor.dive_phase) == phase, {}, 2)
			var old_impact_count = _count("dive_impact")
			if action == "damage": actor.receive_hit({"rollable": false, "impulse": Vector2(30, -80), "hitpause": .06})
			else: actor.reset_actor(Vector2(100, 180))
			_check(actor.main_action == (&"hurt" if action == "damage" else &"locomotion") and actor.dive_phase == &"", "forced interruption clears dive phase immediately")
			await _seconds({}, .8)
			_check(_count("dive_impact") == old_impact_count and _exceptions().is_empty(), "forced cancellation leaves no delayed dive impact or drop exception")
			await _finish()

func _dive_geometry_and_lifecycle() -> void:
	await _start_test_dive("dive descent watchdog without floor", Vector2(100, -200), false)
	var begin_tick: int = driver.ticks
	await _until(func(): return actor.main_action != &"dive", {}, 3)
	var cancelled = events.filter(func(e): return e.event == "dive_cancelled")
	_check(not cancelled.is_empty() and cancelled.back().data.reason == "descent_timeout" and _count("dive_impact") == 0, "missing floor ends finite descent without inventing impact")
	measurements["timeout_seconds"] = (driver.ticks - begin_tick) * dt
	_near(measurements.timeout_seconds, actor.combat_profile.dive_startup_seconds + actor.combat_profile.dive_max_descent_seconds, 2 * dt + .000001, "watchdog duration follows authored phase seconds")
	await _finish()
	await _begin("dive startup upward momentum hits real ceiling", Vector2(100, -30), true)
	_surface(Vector2(60, -80), Vector2(100, 10)); await _step()
	actor.velocity = Vector2(0, -500)
	await _step({"down": 1.0, "jump": true})
	var ceiling_seen := bool(actor.telemetry().ceiling_contact); var safe := not _ordinary_solid_overlap()
	for _i in range(ceili(1.5 / dt)):
		await _step(); ceiling_seen = ceiling_seen or actor.telemetry().ceiling_contact; safe = safe and not _ordinary_solid_overlap()
	_check(ceiling_seen and safe and _count("dive_impact") == 1, "braced upward momentum collides with ceiling then produces one genuine floor impact")
	await _finish()
	await _begin("dive lands on real slope", Vector2(135, -60), true)
	var ramp = StaticBody2D.new(); ramp.set_script(load("res://combat_pc/fixtures/ramp.gd")); ramp.position = Vector2(80, 200); ramp.width = 120; ramp.rise = 40
	var shape = CollisionPolygon2D.new(); shape.name = "Shape"; ramp.add_child(shape); world.add_child(ramp); await _step()
	await _step({"down": 1.0, "jump": true}); await _until(func(): return _count("dive_impact") == 1)
	var impacts = events.filter(func(e): return e.event == "dive_impact")
	_check(impacts.size() == 1 and absf(float(impacts[0].data.normal[0])) > .1 and actor.grounded and actor.global_position.y < 199, "impact records actual slope normal and stable supported foot")
	_check(not _ordinary_solid_overlap(), "slope impact leaves no solid overlap")
	await _finish()
	await _start_test_dive("dive phase freezes through actor hitpause")
	await _until(func(): return actor.dive_phase == &"descent")
	var position_before: Vector2 = actor.global_position; var progress: float = actor.telemetry().dive_phase_progress
	actor.apply_hitpause(.2); await _step({"jump": true})
	await _until(func(): return actor.hitpause_remaining <= 0)
	_check(actor.global_position == position_before and actor.telemetry().dive_phase_progress == progress and _count("dive_impact") == 0, "local pause suspends descent and cannot generate contact impact")
	await _step()
	_check(actor.main_action == &"dive" and _count("air_jump") == 0, "queued plain jump remains denied in descent after pause")
	await _finish()
	await _begin("near floor dive refusal consumes contextual chord", Vector2(100, 194), true)
	await _step({"down": 1.0, "jump": true})
	_check(_count("dive_denied") == 1 and _count("dive_started") == 0 and _count("air_jump") == 0, "insufficient height refuses dive without fallback jump")
	await _finish()
	await _start_test_dive("live dive survives ability toggle")
	actor.allow_dive = false
	await _until(func(): return actor.main_action != &"dive", {}, 2)
	_check(_count("dive_impact") == 1 and _count("dive_finished") == 1, "ability toggle gates new starts while existing dive completes safely")
	await _finish()

func _native_down_input() -> void:
	await _setup_oneway("native parsed Down Jump drops once")
	actor.automatic_physics = true
	_key(KEY_S, true); _key(KEY_C, true); await _step(null)
	_check(_count("drop_started") == 1, "InputMap down and fresh jump choose supported drop")
	await _seconds(null, .7)
	_check(_count("drop_started") == 1 and _count("dive_started") == 0 and _count("air_jump") == 0, "native held chord stays consumed through falling and landing")
	_key(KEY_C, false); _key(KEY_S, false); await _step(null)
	await _finish()

func _context_and_gates() -> void:
	for kind in ["drop", "dive"]:
		for gate in ["ability", "host", "main"]:
			if kind == "drop": await _setup_oneway(kind + " gate " + gate)
			else: await _begin(kind + " gate " + gate, Vector2(100, -80), true)
			if gate == "ability": actor.set("allow_drop_through" if kind == "drop" else "allow_dive", false)
			elif gate == "host": actor.set_weapon_permissions({"can_drop_through" if kind == "drop" else "can_dive": false})
			else: actor.begin_main_action(&"gated", {"can_drop_through" if kind == "drop" else "can_dive": false})
			await _step({"down": 1.0, "jump": true}); await _seconds({"down": 1.0, "jump": true}, .15)
			_check(_count(kind + "_denied") == 1 and _count(kind + "_started") == 0, "explicit ability or capability refusal consumes exactly one contextual chord")
			_check(_count("ground_jump") == 0 and _count("air_jump") == 0 and _exceptions().is_empty(), "gate denial does not become normal jump or collision ignore")
			await _finish()
	await _setup_oneway("context stays drop while frozen support disappears")
	actor.apply_hitpause(.15); await _step({"down": 1.0, "jump": true})
	for body in one_way_bodies: body.queue_free()
	await _until(func(): return actor.hitpause_remaining <= 0, {"down": 1.0, "jump": true})
	await _seconds({"down": 1.0, "jump": true}, .3)
	_check(_count("drop_started") == 0 and _count("drop_denied") == 1 and _count("dive_started") == 0 and _count("air_jump") == 0, "ground-classified frozen chord is denied when support disappears and cannot turn into dive")
	await _finish()

func _start_test_dive(label: String, at := Vector2(100, -80), floor_present := true) -> void:
	await _begin(label, at, floor_present)
	await _step({"down": 1.0, "jump": true})
	_check(actor.main_action == &"dive" and actor.dive_phase == &"startup", "airborne fresh down-jump enters authored dive startup")

func _dive_phases() -> void:
	await _start_test_dive("connected dive startup descent impact recovery")
	var passive = _target(Vector2(100, 200))
	var begin_tick: int = driver.ticks; var phases := {}; var max_speed := 0.0; var safe := true
	while actor.main_action == &"dive" and driver.ticks - begin_tick < hz * 4:
		var phase := String(actor.dive_phase)
		if not phases.has(phase): phases[phase] = driver.ticks
		await _step({"down": 1.0, "jump": true})
		max_speed = maxf(max_speed, actor.velocity.y); safe = safe and not _ordinary_solid_overlap()
	_check(phases.has("startup") and phases.has("descent") and phases.has("impact") and phases.has("recovery"), "real geometry drives all four finite dive phases")
	_check(_count("dive_impact") == 1 and _count("dive_finished") == 1 and actor.grounded and safe, "one real floor impact completes safely and held chord never restarts")
	_check(max_speed <= actor.combat_profile.dive_max_speed + .01 and _count("air_jump") == 0, "descent respects authored cap without consuming an air jump")
	_check(passive.hits == 0 and strikes.is_empty(), "dive impact remains a semantic hook and does not invent melee damage")
	measurements = {"total_seconds": (driver.ticks - begin_tick) * dt, "max_fall_speed": max_speed}
	if phases.has("descent"):
		measurements.startup_seconds = (phases.descent - phases.startup) * dt
		_near(measurements.startup_seconds, actor.combat_profile.dive_startup_seconds, dt + .000001, "startup timing quantizes by at most one physics tick")
	if phases.has("recovery"):
		measurements.impact_seconds = (phases.recovery - phases.impact) * dt
		measurements.recovery_seconds = (driver.ticks - phases.recovery) * dt
		_near(measurements.impact_seconds, actor.combat_profile.dive_impact_seconds, dt + .000001, "impact timing follows profile seconds")
		_near(measurements.recovery_seconds, actor.combat_profile.dive_recovery_seconds, dt + .000001, "recovery timing follows profile seconds")
	await _finish()

func _tight_stacks_and_host_edges() -> void:
	var dive_support = await _setup_oneway("drop expiry into dive retains safe cleanup")
	await _step({"down": 1.0, "jump": true})
	await _until(func(): return actor.main_action != &"drop", {}, .2)
	await _step({"down": 1.0, "jump": true})
	_check(actor.main_action == &"dive" and actor.crouched and _exceptions().has(dive_support), "dive after finite drop release preserves required small body and original target exception")
	var safe_small := true
	while actor.main_action == &"dive":
		await _step()
		if actor.telemetry().drop_exception_active: safe_small = safe_small and actor.crouched
	_check(safe_small and _exceptions().is_empty() and _count("dive_impact") == 1 and not _ordinary_solid_overlap(), "downward dive completes safe separation before restoring shape and impact")
	await _finish()
	for interruption in ["action_expired", "melee"]:
		await _setup_oneway("jump waits for outstanding drop cleanup " + interruption)
		await _step({"down": 1.0, "jump": true})
		if interruption == "melee": await _step({"attack": true})
		else: await _until(func(): return actor.main_action != &"drop", {}, .2)
		_check(actor.telemetry().drop_exception_active, "fixture still crosses ignored platform after its action owner changes")
		await _step({"jump": true})
		_check(_count("air_jump") == 0 and actor.crouched, "jump cannot expand the body into an ignored platform while cleanup remains live")
		await _finish()
	for gap in [40, 44]:
		for interrupt in [false, true]:
			await _begin("stack spacing %d repeated drop " % gap + ("melee interrupt" if interrupt else "ordinary"), Vector2(100, 146), false)
			var upper = _oneway(Vector2(20, 152), Vector2(160, 6))
			var lower = _oneway(Vector2(20, 152 + gap), Vector2(160, 6))
			_surface(Vector2(-200, 300), Vector2(800, 30)); await _until(func(): return actor.grounded)
			await _step({"down": 1.0, "jump": true})
			if interrupt: await _step({"attack": true})
			await _until(func(): return actor.grounded and actor.global_position.y > 170)
			await _until(func(): return actor.weapon_phase == &"idle", {}, .6)
			await _step()
			_check(absf(actor.global_position.y - (152 + gap)) < .2 and _exceptions().is_empty(), "lower support clears old targeted exception")
			_check((actor.crouched and not actor.can_stand()) if gap == 40 else (not actor.crouched and actor.can_stand()), "forty-pixel gap stays safely crouched; forty-four-pixel gap permits standing with margin")
			await _step({"down": 1.0, "jump": true})
			_check(_count("drop_started") == 2 and _exceptions().has(lower) and not _exceptions().has(upper), "first fresh chord on lower platform starts second drop without hidden extra press")
			await _until(func(): return actor.grounded and actor.global_position.y > 250)
			_check(_exceptions().is_empty() and _count("dive_started") == 0, "repeated stack traversal clears both target lifetimes")
			await _finish()
	var support = await _setup_oneway("live drop survives ability toggle and downward carrier")
	await _step({"down": 1.0, "jump": true}); actor.allow_drop_through = false
	support.moving = true; support.travel = Vector2(40, 40); support.travel_speed = 120
	await _seconds({}, .6)
	_check(_exceptions().is_empty() and actor.main_action != &"drop" and _count("drop_started") == 1, "ability toggle cannot abandon live cleanup on a moving one-way target")
	await _finish()
	for resolution in ["remove", "reset"]:
		var mutated = await _setup_oneway("overlapping drop target changes to solid " + resolution)
		await _step({"down": 1.0, "jump": true}); mutated.one_way = false
		await _step({}, 2)
		var stopped: Vector2 = actor.global_position
		_check(actor.telemetry().drop_geometry_blocked and _exceptions().is_empty() and _count("drop_geometry_blocked") == 1, "invalidated overlapping target loses exception and enters explicit blocked geometry state")
		await _step({"right": 1.0, "roll": true, "attack": true}, 3)
		_check(actor.global_position == stopped and actor.velocity == Vector2.ZERO, "unsupported changed geometry cannot be crossed by queued combat actions")
		if resolution == "remove": mutated.queue_free()
		else: actor.reset_actor(Vector2(230, 140))
		await _step({}, 2)
		_check(not actor.telemetry().drop_geometry_blocked and _exceptions().is_empty(), "removal or reset releases explicit geometry block without stale collision exception")
		await _finish()
	await _start_test_dive("canceled dive cannot repeatedly reset airborne motion")
	var air_jumps: int = actor.air_jumps_left
	await _step({"attack": true}); await _step({"down": 1.0, "jump": true})
	_check(_count("dive_started") == 1 and _count("dive_denied") == 1 and not actor.dive_available and actor.air_jumps_left == air_jumps, "startup cancellation does not replenish dive allowance or change air-jump budget")
	await _until(func(): return actor.grounded, {}, 2)
	_check(actor.dive_available, "only actual floor contact replenishes canceled dive allowance")
	await _finish()
	await _start_test_dive("dive impact loses supporting body")
	await _until(func(): return actor.dive_phase == &"impact")
	world.get_child(0).queue_free(); await _step({}, 2)
	_check(actor.main_action != &"dive" and not actor.grounded and _count("dive_impact") == 1, "removed impact surface cancels remaining grounded phases without replaying impact")
	await _finish()
	await _setup_oneway("fresh reset chord probes actual support")
	actor.reset_actor(Vector2(100, 140))
	await _step({"down": 1.0, "jump": true})
	_check(_count("drop_started") == 1 and _count("dive_started") == 0 and _count("air_jump") == 0, "fresh reset classifies existing support geometrically before cached ground tick")
	await _finish()
