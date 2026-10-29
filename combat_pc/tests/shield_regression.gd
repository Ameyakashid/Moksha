extends "res://combat_pc/tests/soft_slope_regression.gd"
## M8 independent authored shield acceptance. No recovered timing or stamina model.
## The inherited recorder runs exactly once per real physics callback.

var incoming_records: Array[Dictionary] = []
var incoming_queue: Array[Dictionary] = []
var noises: Array[Dictionary] = []
var after_actor: Callable = Callable()
var latest_result := {}
var attack_identity := 1000
var passive_nodes: Array[Node] = []
var physical_before := {}
var effect_reports: Array[Dictionary] = []
var effect_requests: Array[Dictionary] = []

func _run() -> void:
	source_paths.append_array([
		"res://combat_pc/resources/shield_profile.gd", "res://combat_pc/resources/shield_profile.tres",
		"res://combat_pc/tests/shield_regression.gd", "res://combat_pc/components/shield_contact_adapter.gd",
		"res://combat_pc/fixtures/guard_melee_fixture.gd", "res://combat_pc/fixtures/guard_melee_fixture.tscn",
		"res://combat_pc/fixtures/guard_projectile.gd", "res://combat_pc/fixtures/guard_projectile_fixture.gd", "res://combat_pc/fixtures/guard_projectile_fixture.tscn",
		"res://combat_pc/components/guard_prop_adapter.gd", "res://combat_pc/fixtures/guard_prop_fixture.gd", "res://combat_pc/fixtures/guard_prop_fixture.tscn",
		"res://prop.gd", "res://scenes/props/crate.tscn", "res://resources/tuning/prop_tuning.gd", "res://resources/tuning/crate_default.tres"
	])
	for filename in DirAccess.get_files_at("res://combat_pc/visuals"):
		if filename.ends_with(".gd"): source_paths.append("res://combat_pc/visuals/" + filename)
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _shield_cases()
	_release_input()
	var hashes := {}; var stable := true
	for path in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Source changed during shield run; final rerun required")
	var output := {"milestone": 8, "selected_group": only_group, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(), "generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "One production call per actual physics callback with immediate before/after observations; explicit incoming-resolver API probes are recorded separately from physical collision-adapter contacts; real actor geometry and parsed native input",
		"numeric_source": "Original MOKSHA shield policy; no recovered Dead Cells timings, directional predicate, resource cost or executable equivalence",
		"movement_profile": _resource_values(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _resource_values(load("res://combat_pc/resources/combat_profile.tres")),
		"shield_profile": _resource_values(load("res://combat_pc/resources/shield_profile.tres"))}
	FileAccess.open("res://combat_pc/tests/shield_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("MOKSHA SHIELD %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _shield_cases() -> void:
	if only_group in ["", "timing"]: await _timing_cases()
	if only_group in ["", "physical_timing"]: await _physical_timing_cases()
	if only_group in ["", "outcomes"]: await _outcome_and_identity_cases()
	if only_group in ["", "geometry"]: await _geometry_and_category_cases()
	if only_group in ["", "cancels"]: await _phase_cancel_cases()
	if only_group in ["", "locks"]: await _lock_and_host_cases()
	if only_group in ["", "effects"]: await _physical_effect_cases()
	if only_group in ["", "props"]: await _physical_prop_cases()
	if only_group in ["", "admission"]: await _admission_cases()
	if only_group in ["", "history"]: await _history_cases()
	if only_group in ["", "native"]: await _native_buffer_cases()
	if only_group in ["", "callbacks"]: await _callback_cases()
	if only_group in ["", "air"]:
		await _air_and_clearance_cases()
		await _jump_owner_landings()
	if only_group in ["", "intersections"]: await _final_intersections()
	if only_group in ["", "priorities"]: await _priority_and_kick_cases()

func _shield_begin(label: String, at := Vector2(100, 200), floor_present := true, one_way_floor := false) -> void:
	incoming_records = []; incoming_queue = []; noises = []; after_actor = Callable(); latest_result = {}; passive_nodes = []; physical_before = {}; effect_reports = []; effect_requests = []
	await super._begin(label, at, false)
	if floor_present: _box(Vector2(0, 204 if one_way_floor else 220), Vector2(3000, 8 if one_way_floor else 40), one_way_floor)
	if actor.get("shield_profile") != null: actor.shield_profile = actor.shield_profile.duplicate(true)
	actor.noise_requested.connect(func(at_, kind, loudness, source):
		noises.append({"tick": ticks, "position": _safe(at_), "kind": String(kind), "loudness": loudness, "source": _safe(source)}))
	var defense_adapter := _attach_defense_adapter()
	defense_adapter.effect_resolved.connect(func(report): effect_reports.append({"tick": ticks, "report": _safe(report)}))
	actor.shield_effect_requested.connect(func(_owner, request): effect_requests.append({"tick": ticks, "request": _safe(request)}))
	await _start()
	if floor_present: await _until(func(): return actor.grounded)

func physics_sample(delta: float) -> void:
	if not is_instance_valid(actor): return
	ticks += 1
	var engine_tick := Engine.get_physics_frames()
	if last_engine_tick >= 0: engine_gaps.append(engine_tick - last_engine_tick)
	last_engine_tick = engine_tick; deltas.append(delta)
	if before_tick.is_valid(): before_tick.call(delta)
	var before := _sample()
	var physical_input: Variant = _sample_native_input() if input_frame == null else null
	actor.physics_tick(delta, input_frame)
	if after_actor.is_valid(): after_actor.call(delta)
	for passive in passive_nodes.duplicate():
		if is_instance_valid(passive) and not passive.is_queued_for_deletion():
			physical_before = _safe(_sample())
			passive.call("_physics_process", delta)
	var pending := incoming_queue.duplicate(); incoming_queue.clear()
	for payload in pending: _deliver_now(payload)
	frames.append(_safe({"tick": ticks, "engine_tick": engine_tick, "delta": delta,
		"input": input_frame, "native_input": physical_input, "before": before, "after": _sample()}))

func _deliver_now(payload: Dictionary) -> Dictionary:
	var before: Dictionary = _sample()
	var result: Dictionary = actor.receive_attack(payload)
	latest_result = result.duplicate(true)
	incoming_records.append({"tick": ticks, "engine_tick": Engine.get_physics_frames(), "payload": _safe(payload),
		"before": _safe(before), "result": _safe(result), "after": _safe(_sample())})
	return result

func _incoming(payload: Dictionary, frame: Variant = {}) -> Dictionary:
	incoming_queue.append(payload)
	await _step(frame)
	return latest_result

func _sample() -> Dictionary:
	var snapshot: Dictionary = super._sample()
	var state: Dictionary = actor.telemetry()
	for key in state:
		if String(key).begins_with("shield") or String(key).begins_with("incoming_history") or key in ["hitpause_remaining", "weapon_permissions", "capabilities", "jump_buffer", "roll_buffer", "attack_buffer", "down_action_buffer", "roll_elapsed", "weapon_elapsed", "climb_active", "wall_active", "ledge_phase", "fall_history_active", "roll_fall_protected"]:
			snapshot[key] = state[key]
	snapshot["weapon_permissions"] = actor.weapon_permissions
	snapshot["main_capabilities"] = actor.main_capabilities
	return snapshot

func _sample_native_input() -> Dictionary:
	var result: Dictionary = super._sample_native_input()
	if InputMap.has_action("cp_shield"):
		result.shield = Input.is_action_pressed("cp_shield")
		result.shield_pressed = Input.is_action_just_pressed("cp_shield")
		result.shield_released = Input.is_action_just_released("cp_shield")
	return result

func _release_input() -> void:
	super._release_input()
	var event := InputEventKey.new(); event.physical_keycode = KEY_K; event.pressed = false; Input.parse_input_event(event)
	if InputMap.has_action("cp_shield"): Input.action_release("cp_shield")

func _safe(value: Variant) -> Variant:
	if value is Object:
		if not is_instance_valid(value): return {"freed_object": true}
		return {"object_id": value.get_instance_id(), "class": value.get_class(), "name": String(value.name) if value is Node else ""}
	return super._safe(value)

func _finish() -> void:
	var incoming_copy := incoming_records.duplicate(true); var noise_copy := noises.duplicate(true)
	var reports_copy := effect_reports.duplicate(true); var requests_copy := effect_requests.duplicate(true)
	var effective_shield_profile := _resource_values(actor.shield_profile)
	await super._finish()
	scenarios.back()["incoming"] = incoming_copy
	scenarios.back()["noises"] = noise_copy
	scenarios.back()["effect_reports"] = reports_copy
	scenarios.back()["effect_requests"] = requests_copy
	scenarios.back()["shield_profile"] = effective_shield_profile

func _source(at: Vector2, label := "AttackSource") -> Node2D:
	var node := Node2D.new(); node.name = label; node.position = at; world.add_child(node)
	return node

func _attack(source: Node, extra: Dictionary = {}) -> Dictionary:
	attack_identity += 1
	var state: Dictionary = actor.telemetry()
	var point: Vector2 = state.shield_center
	var body_front: float = actor.profile.body_width * .5
	var band_inner: float = body_front + actor.shield_profile.contact_forward_offset - actor.shield_profile.contact_width * .5
	point.x = actor.position.x + actor.facing * (maxf(0, band_inner) + body_front) * .5
	return {"attack_id": attack_identity, "source": source, "kind": "melee", "origin": source.global_position,
		"contact_position": point, "incoming_velocity": Vector2(-actor.facing * 200, 0), "amount": 8.0,
		"impulse": Vector2(-actor.facing * 120, -50), "stun_seconds": .18, "hitpause": 0.0,
		"blockable": true, "parryable": true, "reflectable": false, "counterable": false, "rollable": true}.merged(extra, true)

func _phase(phase: String, held := true, maximum_seconds := 1.0) -> bool:
	return await _until(func(): return String(actor.shield_phase) == phase, {"shield": held}, maximum_seconds)

func _open_shield(held := true) -> void:
	await _step({"shield": true})
	if not held: await _step()
	await _until(func(): return actor.is_shield_parry_open(), {"shield": held}, .3)

func _shield_noise_count(kind: String) -> int:
	return noises.filter(func(item): return item.kind == kind).size()

func _timing_cases() -> void:
	for aligned in [false, true]:
		for direction in [-1, 1]:
			for edge in ["before_open", "first_open", "last_open", "first_closed"]:
				await _shield_begin("shield window %s direction%d%s" % [edge, direction, " aligned" if aligned else ""])
				actor.reset_actor(actor.position, direction)
				if aligned:
					actor.shield_profile.parry_window_from = .05
					actor.shield_profile.parry_window_until = .15
				var p = actor.shield_profile
				var source := _source(actor.position + Vector2(direction * 35, -17))
				var target_tick := 0
				match edge:
					"before_open": target_tick = floori((p.parry_window_from - .000000001) / dt)
					"first_open": target_tick = ceili((p.parry_window_from - .000000001) / dt)
					"last_open": target_tick = ceili((p.parry_window_until - .000000001) / dt) - 1
					"first_closed": target_tick = ceili((p.parry_window_until - .000000001) / dt)
				await _step({"shield": true})
				var serial: int = actor.shield_serial
				if target_tick > 1: await _step({"shield": true}, target_tick - 1)
				var result := await _incoming(_attack(source), {"shield": true})
				var expected := "parried" if edge in ["first_open", "last_open"] else ("guarded" if edge == "first_closed" else "hurt")
				_check(result.get("outcome") == expected, "contact on the selected actual phase boundary has the declared distinct defense result")
				_check(actor.shield_serial == serial, "one held press does not create a second attempt at a timing edge")
				measurements["contact_attempt_seconds"] = incoming_records.back().before.shield_elapsed
				measurements["requested_boundary_seconds"] = target_tick * dt
				_near(float(incoming_records.back().before.shield_elapsed), target_tick * dt, .00000001, "incoming dispatch observes exactly the requested engine-tick attempt time")
				measurements.merge(_trace_bounds()); await _finish()
	await _shield_begin("tap keeps one finite window and miss recovery")
	await _step({"shield": true}); var serial: int = actor.shield_serial
	await _step(); await _phase("miss_recovery", false)
	_check(actor.shield_phase == &"miss_recovery" and actor.shield_serial == serial, "released tap completes its original finite attempt then visibly misses")
	await _phase("idle", false)
	_check(actor.shield_phase == &"idle" and actor.shield_serial == serial, "miss recovery completes without a held-input repeat")
	await _seconds({}, .2)
	_check(actor.shield_serial == serial and not actor.is_shield_parry_open(), "expired tap cannot silently rearm after ordinary idle ticks")
	await _finish()
	await _shield_begin("held guard release and fresh next attempt")
	await _step({"shield": true}); serial = actor.shield_serial
	await _seconds({"shield": true}, actor.shield_profile.parry_window_until * 4)
	_check(actor.shield_phase == &"hold" and actor.shield_serial == serial and not actor.is_shield_parry_open(), "held input remains guard across multiple expired parry-window lengths")
	await _step()
	_check(actor.shield_phase == &"release_recovery" and not actor.is_shield_parry_open(), "releasing established guard starts release recovery without another parry")
	await _phase("idle", false); await _step({"shield": true})
	_check(actor.shield_serial != serial and actor.shield_phase == &"raise", "fresh post-recovery press admits exactly one new attempt")
	await _finish()

func _outcome_and_identity_cases() -> void:
	for mode in ["idle", "guard", "parry", "roll"]:
		await _shield_begin("incoming outcome and same ID duplicate " + mode)
		var source := _source(actor.position + Vector2(35, -17))
		if mode == "guard": await _step({"shield": true}); await _phase("hold")
		elif mode == "parry": await _open_shield()
		elif mode == "roll":
			await _step({"roll": true})
			await _until(func(): return actor.is_roll_invulnerable(), {}, .2)
		var payload := _attack(source)
		var result := _deliver_now(payload)
		var expected: String = {"idle": "hurt", "guard": "guarded", "parry": "parried", "roll": "evaded"}[mode]
		_check(result.get("outcome") == expected and result.get("consumed", false), "same eligible front contact yields the phase-specific incoming result")
		var residual: float = 8.0 if mode == "idle" else (8.0 * (1 - actor.shield_profile.guard_absorption) if mode == "guard" else 0.0)
		_near(float(result.get("residual_damage", -1)), residual, .000001, "residual damage metadata follows ordinary guard and full-negation policy exactly once")
		var event_count := events.size(); var noise_count := noises.size()
		var repeat := _deliver_now(payload)
		_check(repeat.get("outcome") == "duplicate" and events.size() == event_count and noises.size() == noise_count, "duplicate stable identity has no second hurt defense or feedback effect")
		if mode == "guard": _check(actor.shield_phase == &"hold" and actor.main_action != &"hurt", "guard residual metadata does not also run the ordinary full-hurt path")
		if mode == "parry": _check(actor.shield_phase == &"success_recovery" and not result.get("counter_confirmed", false), "incoming parry success closes the attempt even without a confirmed counter")
		await _finish()
	await _shield_begin("same local ID from distinct live sources")
	var first_source := _source(actor.position + Vector2(35, -17), "FirstSource")
	var second_source := _source(actor.position + Vector2(35, -17), "SecondSource")
	await _open_shield()
	var first := _attack(first_source); var second := _attack(second_source, {"attack_id": first.attack_id})
	var first_result := _deliver_now(first); var second_result := _deliver_now(second)
	_check(first_result.get("outcome") == "parried" and second_result.get("outcome") != "duplicate", "authenticator identity distinguishes simultaneous attacks that share a local sequence")
	_check(second_result.get("outcome") == "hurt" and actor.shield_phase == &"idle", "first success enters committed recovery and does not grant blanket immunity to a distinct attack")
	await _finish()

func _geometry_and_category_cases() -> void:
	for direction in [-1, 1]:
		for geometry in ["front", "back", "above", "below", "equal_x", "diagonal_inside", "diagonal_outside", "velocity_inside", "velocity_outside", "zero_melee", "zero_projectile", "remote_owner", "contact_outside_body", "contact_outside_band", "occluded"]:
			await _shield_begin("defense geometry %s direction%d" % [geometry, direction], Vector2(100, 200), geometry != "below")
			actor.reset_actor(actor.position, direction)
			var source := _source(actor.position + Vector2(direction * 35, -17))
			var carrier := _source(source.position, "ActualCarrier")
			await _open_shield()
			var payload := _attack(source)
			var point: Vector2 = payload.contact_position
			var kind := "melee"
			var expected := "parried"
			match geometry:
				"back": payload.origin = point - Vector2(direction * 35, 0); expected = "hurt"
				"above": payload.origin = point + Vector2(0, -35); expected = "hurt"
				"below": payload.origin = point + Vector2(0, 35); expected = "hurt"
				"equal_x": payload.origin = point; expected = "hurt"
				"diagonal_inside": payload.origin = point + Vector2(direction * cos(deg_to_rad(actor.shield_profile.frontal_half_angle_degrees - 1)), -sin(deg_to_rad(actor.shield_profile.frontal_half_angle_degrees - 1))) * 35
				"diagonal_outside": payload.origin = point + Vector2(direction * cos(deg_to_rad(actor.shield_profile.frontal_half_angle_degrees + 1)), -sin(deg_to_rad(actor.shield_profile.frontal_half_angle_degrees + 1))) * 35; expected = "hurt"
				"velocity_inside": payload.incoming_velocity = Vector2(-direction * .26, -sqrt(1 - .26 * .26)) * 200
				"velocity_outside": payload.incoming_velocity = Vector2(-direction * .24, -sqrt(1 - .24 * .24)) * 200; expected = "hurt"
				"zero_melee": payload.incoming_velocity = Vector2.ZERO
				"zero_projectile": payload.incoming_velocity = Vector2.ZERO; kind = "projectile"; expected = "hurt"
				"remote_owner": source.position = point - Vector2(direction * 150, 0); kind = "projectile"
				"contact_outside_body": payload.contact_position = actor.position + Vector2(direction * 3, -actor.body_height - 4); expected = "rejected"
				"contact_outside_band": payload.contact_position = Vector2(point.x, actor.position.y - .5); expected = "hurt"
				"occluded":
					_box((Vector2(payload.origin) + point) * .5, Vector2(4, 60))
					await _sync_geometry()
					expected = "rejected"
			payload.kind = kind
			if geometry != "remote_owner": source.position = payload.origin
			if kind == "projectile":
				payload.carrier = carrier
				carrier.position = payload.origin
			var noise_before := noises.size(); var hurt_before := _count("hurt_started")
			var result := _deliver_now(payload)
			_check(result.get("outcome") == expected, "actual body contact band, incoming direction and terrain occlusion determine the declared defense result")
			if expected == "rejected": _check(noises.size() == noise_before and _count("hurt_started") == hurt_before and not result.get("consumed", true), "invalid or occluded contact produces no hurt defense noise or consumed identity")
			if expected == "parried":
				var impact_noises := noises.filter(func(item): return item.kind == "parry")
				_check(impact_noises.size() == 1, "accepted incoming defense emits one original parry noise")
				if not impact_noises.is_empty(): _near(Vector2(impact_noises[0].position[0], impact_noises[0].position[1]).distance_to(payload.contact_position), 0, .00001, "noise uses the actual incoming contact coordinate")
			params = {"geometry": geometry, "direction": direction, "expected": expected, "contact_route": "explicit resolver descriptor validation"}
			measurements.merge(_trace_bounds()); await _finish()
	for phase in ["parry", "hold"]:
		for category in ["block_only", "parry_only", "neither", "area", "projectile_no_reflect"]:
			await _shield_begin("eligibility %s during %s" % [category, phase])
			var source := _source(actor.position + Vector2(35, -17))
			var carrier := _source(source.position, "Carrier")
			await _open_shield()
			if phase == "hold": await _phase("hold")
			var payload := _attack(source)
			if category == "block_only": payload.parryable = false
			elif category == "parry_only": payload.blockable = false
			elif category == "neither": payload.parryable = false; payload.blockable = false
			elif category == "area": payload.kind = "area"; payload.counterable = true
			else: payload.kind = "projectile"; payload.carrier = carrier; payload.reflectable = false
			var expected := "hurt"
			if phase == "parry" and payload.parryable: expected = "parried"
			if phase == "hold" and payload.blockable: expected = "guarded"
			var result := _deliver_now(payload)
			_check(result.get("outcome") == expected, "explicit attack-category eligibility is preserved even with otherwise correct timing and geometry")
			_check(not result.get("counter_confirmed", false) and not result.get("reflection_confirmed", false), "defense flags alone do not fabricate an unimplemented or ineligible outgoing effect")
			await _finish()

func _physical_result(carrier: Node, result: Dictionary) -> void:
	latest_result = result.duplicate(true)
	incoming_records.append({"route": "production swept projectile", "tick": ticks, "engine_tick": Engine.get_physics_frames(),
		"carrier": _safe(carrier), "before": physical_before.duplicate(true), "result": _safe(result), "after": _safe(_sample())})

func _carrier(at: Vector2, source: Node, velocity_: Vector2, reflected_eligible := true) -> Node:
	var carrier = load("res://combat_pc/fixtures/guard_projectile.gd").new()
	carrier.position = at; carrier.reflectable = reflected_eligible
	world.add_child(carrier); carrier.set_physics_process(false)
	attack_identity += 1; carrier.configure(source, velocity_, attack_identity)
	carrier.resolved.connect(_physical_result)
	return carrier

func _attach_defense_adapter() -> Node:
	var adapter := actor.get_node_or_null("ShieldContactAdapter")
	if adapter == null:
		adapter = load("res://combat_pc/components/shield_contact_adapter.gd").new()
		adapter.name = "ShieldContactAdapter"; actor.add_child(adapter)
	return adapter

func _physical_timing_cases() -> void:
	for direction in [-1, 1]:
		for edge in ["before_open", "first_open", "last_open", "first_closed"]:
			await _shield_begin("physical projectile window %s direction%d" % [edge, direction])
			actor.reset_actor(actor.position, direction)
			var p = actor.shield_profile
			var target_tick := 0
			match edge:
				"before_open": target_tick = floori((p.parry_window_from - .000000001) / dt)
				"first_open": target_tick = ceili((p.parry_window_from - .000000001) / dt)
				"last_open": target_tick = ceili((p.parry_window_until - .000000001) / dt) - 1
				"first_closed": target_tick = ceili((p.parry_window_until - .000000001) / dt)
			var source := _source(actor.position + Vector2(direction * 150, -17), "RemoteSource")
			var speed := 200.0
			var distance: float = actor.profile.body_width * .5 + 3 + speed * (target_tick + .5) * dt
			var start: Vector2 = Vector2(actor.position.x + direction * distance, actor.telemetry().shield_center.y)
			var carrier := _carrier(start, source, Vector2(-direction * speed, 0), false)
			await _sync_geometry(); passive_nodes.append(carrier)
			await _until(func(): return not latest_result.is_empty(), {"shield": true}, .5)
			var expected := "parried" if edge in ["first_open", "last_open"] else ("guarded" if edge == "first_closed" else "hurt")
			_check(latest_result.get("outcome") == expected and incoming_records.size() == 1, "production swept sphere makes one real body contact on the chosen shield boundary")
			if not incoming_records.is_empty():
				measurements["contact_attempt_seconds"] = incoming_records[0].before.shield_elapsed
				_near(float(incoming_records[0].before.shield_elapsed), target_tick * dt, .00000001, "physical carrier reaches the intended first/last open or adjacent closed engine sample")
				var point = latest_result.contact_position
				_near(absf(float(point.x) - actor.position.x), actor.profile.body_width * .5, .05, "reported contact is the real actor side from the sphere sweep")
			await _seconds({"shield": true}, .08)
			_check(incoming_records.size() == 1, "retired non-reflecting discrete carrier cannot deal a second contact during local pause or recovery")
			params = {"contact_route": "production swept projectile", "direction": direction, "edge": edge, "intended_attempt_seconds": target_tick * dt}
			measurements.merge(_trace_bounds()); await _finish()

func _enter_phase(phase: String) -> void:
	await _step({"shield": true})
	if phase == "raise": return
	if phase == "miss_recovery": await _step(); await _phase(phase, false); return
	if phase == "release_recovery": await _phase("hold"); await _step(); return
	await _phase("parry")
	if phase == "parry": return
	if phase == "hold": await _phase("hold"); return
	var source := _source(actor.position + Vector2(actor.facing * 35, -17))
	_deliver_now(_attack(source))
	await _until(func(): return actor.hitpause_remaining <= 0, {"shield": true}, .2)

func _phase_cancel_cases() -> void:
	for phase in ["raise", "parry", "hold", "miss_recovery", "success_recovery", "release_recovery"]:
		for action in ["jump", "roll", "attack", "drop", "dive", "climb", "wall"]:
			await _shield_begin("shield %s requests %s" % [phase, action], Vector2(100, 200), action not in ["dive", "wall"], action == "drop")
			if action == "climb":
				var sensor = CLIMBABLE.instantiate(); sensor.position = Vector2(100, 450); sensor.height = 400; world.add_child(sensor)
				await _sync_geometry()
			if action == "wall" and phase != "success_recovery":
				actor.allow_wall_run = true; _box(Vector2(118, 200), Vector2(20, 1400)); await _sync_geometry()
			await _enter_phase(phase)
			if action == "wall" and phase == "success_recovery":
				actor.allow_wall_run = true; _box(Vector2(118, 200), Vector2(20, 1400)); await _sync_geometry()
			if phase == "hold" and action == "attack": await _until(func(): return float(actor.telemetry().shield_lock_remaining) <= 0, {"shield": true}, .2)
			_check(String(actor.shield_phase) == phase, "requested cancellation starts from the intended real shield phase")
			var frame := {"shield": phase not in ["miss_recovery", "release_recovery"]}
			match action:
				"jump": frame.jump = true
				"roll": frame.roll = true
				"attack": frame.attack = true
				"drop", "dive": frame.down = 1.0; frame.jump = true
				"climb": frame.up = 1.0
				"wall": frame.right = 1.0
			var expected: bool = phase == "hold"
			await _step(frame)
			var accepted: bool = actor.weapon_phase == &"windup" if action == "attack" else (actor.main_action in [&"jump", &"air_jump"] if action == "jump" else String(actor.main_action) == action)
			_check(accepted == expected, "phase commitment and actual action eligibility agree with the authored cancellation matrix")
			_check((actor.shield_phase == &"idle") == expected, "denied request preserves shield ownership; accepted replacement retires it transactionally")
			if expected:
				var serial: int = actor.shield_serial
				await _seconds(frame, .03)
				_check(actor.shield_phase == &"idle" and actor.shield_serial == serial, "held shield input cannot restart after an accepted replacement over subsequent callbacks")
			measurements.merge(_trace_bounds()); await _finish()

func _lock_and_host_cases() -> void:
	for replacement in ["roll", "jump", "forced"]:
		await _shield_begin("independent use lock survives " + replacement)
		actor.shield_profile.use_lock_seconds = .6
		await _enter_phase("hold")
		var before: float = actor.telemetry().shield_lock_remaining
		if replacement == "roll": await _step({"roll": true, "shield": true})
		elif replacement == "jump": await _step({"jump": true, "shield": true})
		else: actor.begin_main_action(&"forced", {})
		_check(actor.shield_phase == &"idle" and float(actor.telemetry().shield_lock_remaining) > 0, "accepted replacement retires shield defense while preserving its separate incurred use lock")
		var remaining: float = actor.telemetry().shield_lock_remaining
		_check(remaining <= before and before - remaining <= dt + .00000001, "ordinary cancellation cannot erase or restart the remaining actor-time lock")
		actor.apply_hitpause(.08); var paused_remaining: float = actor.telemetry().shield_lock_remaining
		await _seconds({"attack": true, "shield": true}, .04)
		_near(float(actor.telemetry().shield_lock_remaining), paused_remaining, .00000001, "independent use lock freezes with actor-local pause")
		await _until(func(): return actor.hitpause_remaining <= 0, {}, .15)
		await _seconds({}, .15)
		_check(actor.weapon_phase == &"idle" and actor.shield_phase == &"idle", "short queued attacks and shields cannot bypass the still-live use lock after cancellation")
		await _until(func(): return float(actor.telemetry().shield_lock_remaining) <= 0, {}, 1)
		var previous_serial: int = actor.shield_serial
		await _step({"shield": true})
		_check(actor.shield_serial == previous_serial + 1, "fresh press after independent lock expiry reuses the same actor exactly once")
		await _finish()
	for gate in ["ability", "main", "host", "inputs"]:
		await _shield_begin("shield admission gate " + gate)
		if gate == "ability": actor.allow_shield = false
		elif gate == "main": actor.begin_main_action(&"host_gate", {"can_shield": false})
		elif gate == "host": actor.set_weapon_permissions({"can_shield": false})
		else: actor.allow_input = false
		var previous: String = actor.main_action
		await _seconds({"shield": true}, .04)
		_check(actor.shield_phase == &"idle" and actor.shield_serial == 0 and String(actor.main_action) == previous, "denied shield admission leaves existing ownership intact")
		await _seconds({"shield": true}, actor.shield_profile.input_buffer_seconds + .05)
		if gate == "ability": actor.allow_shield = true
		elif gate == "main": actor.finish_main_action()
		elif gate == "host": actor.set_weapon_permissions()
		else: actor.allow_input = true
		await _seconds({"shield": true}, .04)
		_check(actor.shield_phase == &"idle", "expired or disabled held intent cannot synthesize a new press when a gate opens")
		await _step(); await _step({"shield": true})
		_check(actor.shield_phase == &"raise", "fresh allowed release/press enters shield after the gate opens")
		await _finish()
	for phase in ["raise", "parry", "hold", "miss_recovery", "success_recovery", "release_recovery"]:
		await _shield_begin("responsive shield facing " + phase)
		await _enter_phase(phase)
		var frame := {"left": 1.0, "shield": phase not in ["miss_recovery", "release_recovery"]}
		actor.set_weapon_permissions({"can_move": false, "can_turn": true})
		await _step(frame)
		_check(actor.facing == -1, "host-approved facing follows permitted direction even when movement or replacement is committed")
		actor.set_weapon_permissions({"can_turn": false})
		frame.erase("left"); frame.right = 1.0
		await _step(frame)
		_check(actor.facing == -1, "shield phase turning never overrides an external turn denial")
		await _finish()
	await _shield_begin("shield ground move scale and braking")
	await _enter_phase("hold"); await _seconds({"shield": true, "right": 1.0}, .25)
	_near(actor.velocity.x, actor.profile.run_speed * actor.shield_profile.ground_move_scale, .02, "held guard reaches the authored scaled ground speed")
	await _step({"shield": true, "left": 1.0})
	_check(actor.facing == -1 and actor.velocity.x > 0, "shield turning is immediate while real horizontal momentum still reverses")
	await _seconds({"shield": true}, .2)
	_near(actor.velocity.x, 0, .02, "held guard neutral input retains finite ground braking")
	await _finish()
	await _shield_begin("nonholdable profile cannot cancel committed attempt")
	actor.shield_profile.can_be_held = false
	await _step({"shield": true}); await _seconds({"shield": true}, actor.shield_profile.parry_window_until + dt)
	_check(actor.shield_phase == &"miss_recovery", "nonholdable profile cannot enter sustained guard")
	await _step({"shield": true, "roll": true})
	_check(actor.main_action != &"roll" and actor.shield_phase == &"miss_recovery", "nonholdable outer cancellation gate preserves recovery commitment")
	await _phase("idle", false); await _finish()

func _passive_fixture(path: String, at: Vector2, direction: int) -> Node:
	var fixture = load(path).instantiate()
	fixture.position = at; fixture.direction = direction; fixture.auto_attack = false
	world.add_child(fixture); fixture.set_physics_process(false)
	fixture.attack_resolved.connect(func(result):
		latest_result = result.duplicate(true)
		incoming_records.append({"route": "production passive fixture contact", "tick": ticks, "engine_tick": Engine.get_physics_frames(),
			"before": physical_before.duplicate(true), "result": _safe(result), "after": _safe(_sample())}))
	return fixture

func _physical_effect_cases() -> void:
	for direction in [-1, 1]:
		for outcome in ["accepted", "receiver_rejects", "out_of_counter_range", "turn_after_defense", "reset_after_counter"]:
			await _shield_begin("physical melee counter %s direction%d" % [outcome, direction])
			actor.reset_actor(actor.position, direction)
			var fixture := _passive_fixture("res://combat_pc/fixtures/guard_melee_fixture.tscn", actor.position + Vector2(direction * (75 if outcome == "out_of_counter_range" else 36), 0), -direction)
			fixture.telegraph_seconds = 0.0
			if outcome == "out_of_counter_range": fixture.reach = 100.0
			if outcome == "receiver_rejects": fixture.accepts_counter = false
			if outcome == "turn_after_defense":
				actor.movement_event.connect(func(label, payload):
					if label == &"defense_resolved" and payload.get("outcome") == &"parried": actor.facing = -direction)
			if outcome == "reset_after_counter": fixture.counter_received.connect(func(_payload): actor.reset_actor(Vector2(100, 200), direction))
			await _sync_geometry(); passive_nodes.append(fixture); fixture.request_attack()
			await _until(func(): return not latest_result.is_empty(), {"shield": true}, .5)
			_check(latest_result.get("outcome") == &"parried" and fixture.contacts == 1, "real telescoping blade reaches the actor and resolves one full incoming parry")
			var should_apply: bool = outcome not in ["receiver_rejects", "out_of_counter_range"]
			var should_confirm: bool = should_apply and outcome != "reset_after_counter"
			_check((fixture.counters == 1) == should_apply and bool(latest_result.get("counter_confirmed", false)) == should_confirm, "physical receiver application and current-scope confirmation remain distinct from incoming defense")
			if should_apply: _near(fixture.damage_received, actor.shield_profile.counter_damage, .000001, "reachable passive receiver accepts the authored counter damage once")
			if outcome == "turn_after_defense":
				_check(actor.facing == -direction and latest_result.get("shield_facing") == direction and latest_result.get("counter_confirmed"), "post-defense turn cannot redirect the already-frozen counter geometry")
			if outcome == "reset_after_counter":
				_check(not effect_reports.is_empty() and effect_reports.back().report.applied and not effect_reports.back().report.confirmed, "physical effect already applied before reset is retained honestly without stale confirmation")
			await _seconds({}, .2)
			_check(fixture.contacts == 1 and fixture.counters <= 1, "completed physical blade cannot duplicate incoming or outgoing effects")
			measurements.merge(_trace_bounds()); await _finish()
		for behavior in ["reflected", "remote_source_freed", "carrier_disabled", "carrier_removed", "wall_before_actor"]:
			await _shield_begin("physical projectile effect %s direction%d" % [behavior, direction])
			actor.reset_actor(actor.position, direction)
			var source := _source(actor.position - Vector2(direction * 160, 0), "OppositeRemoteOwner")
			var carrier := _carrier(actor.position + Vector2(direction * 28, -17), source, Vector2(-direction * 200, 0), true)
			if behavior == "wall_before_actor": _box(actor.position + Vector2(direction * 18, -20), Vector2(2, 40))
			if behavior in ["carrier_disabled", "carrier_removed"]:
				var target_state := {"carrier": carrier}
				actor.movement_event.connect(func(label, payload):
					if label == &"defense_resolved" and payload.get("outcome") == &"parried" and is_instance_valid(target_state.carrier):
						if behavior == "carrier_disabled": target_state.carrier.simulation_enabled = false
						else: target_state.carrier.queue_free())
			await _sync_geometry()
			if behavior == "remote_source_freed": source.queue_free(); await _step()
			passive_nodes.append(carrier)
			var carrier_ref: WeakRef = weakref(carrier)
			await _until(func(): return not latest_result.is_empty() or carrier_ref.get_ref() == null, {"shield": true}, .4)
			if behavior == "wall_before_actor":
				_check(latest_result.is_empty() and effect_reports.is_empty() and _count("hurt_started") == 0, "real terrain sweep retires the projectile before any actor defense or hurt")
			else:
				_check(latest_result.get("outcome") == &"parried", "live swept carrier can be defended independently from its remote owner")
				var reflected: bool = behavior in ["reflected", "remote_source_freed"]
				_check(bool(latest_result.get("reflection_confirmed", false)) == reflected and not latest_result.get("counter_confirmed", false), "projectile defense does not fabricate a remote-source melee counter or denied redirect")
				if reflected:
					_check(is_instance_valid(carrier) and carrier.reflected and carrier.reflection_count == 1 and carrier.attack_owner.get_ref() == actor, "actual carrier switches ownership once")
					_near(carrier.velocity.x, direction * actor.shield_profile.reflected_projectile_speed, .001, "actual redirected carrier uses the independent authored outgoing speed")
			await _seconds({}, .08)
			_check(incoming_records.size() <= 1, "old projectile identity cannot also damage the defender after resolution")
			measurements.merge(_trace_bounds()); await _finish()

func _physical_prop_cases() -> void:
	for direction in [-1, 1]:
		await _shield_begin("real rigid prop reflection and noise direction%d" % direction)
		actor.reset_actor(actor.position, direction)
		var fixture := _passive_fixture("res://combat_pc/fixtures/guard_prop_fixture.tscn", actor.position + Vector2(direction * 75, 0), -direction)
		await _sync_geometry()
		var bus = root.get_node("NoiseBus"); bus.clear_history()
		var prop: RigidBody2D = fixture.throw_prop()
		var launch_origin: Vector2 = prop.global_position
		var bridge: Node = prop.get_node("GuardPropAdapter"); bridge.set_physics_process(false); passive_nodes.append(bridge)
		await _until(func(): return not latest_result.is_empty(), {"shield": true}, .5)
		_check(latest_result.get("outcome") == &"parried" and fixture.contacts == 1, "original rigid crate produces a real solver contact accepted by the shield")
		_check(is_instance_valid(prop) and bridge.reflected and bridge.reflection_count == 1 and prop.linear_velocity.x * direction > 0, "reflection changes actual RigidBody velocity and ownership once")
		var launch_noise := false
		for event in bus.event_history:
			if event.kind == &"prop_launch" and Vector2(event.origin).distance_to(launch_origin) < .01: launch_noise = true
		_check(launch_noise, "original physical prop launch noise retains its true world origin")
		await _until(func(): return fixture.returned == 1, {}, 1)
		_check(fixture.returned == 1, "reflected rigid body reaches a real return receiver through continued physics")
		fixture.set_fixture_paused(true)
		if is_instance_valid(prop):
			var stopped: Vector2 = prop.global_position
			await _seconds({}, .08)
			_near(prop.global_position.distance_to(stopped), 0, .001, "global fixture pause freezes committed rigid motion")
		fixture.reset_fixture(); await _step()
		_check(fixture.get_node("Props").get_child_count() == 0, "fixture reset removes transient rigid bodies and their defense carriers")
		measurements.merge(_trace_bounds()); await _finish()

func _admission_cases() -> void:
	for context in ["melee_windup", "melee_active", "melee_recovery", "early_roll", "late_roll", "climb", "wall", "ledge", "dive_startup", "dive_descent", "dive_impact", "dive_recovery", "hurt", "hard_land"]:
		var airborne: bool = context in ["climb", "wall", "ledge", "dive_startup", "dive_descent", "dive_impact", "dive_recovery", "hard_land"]
		await _shield_begin("shield enters from " + context, Vector2(100, 200), not airborne)
		if context.begins_with("melee"):
			await _step({"attack": true})
			var phase: String = context.trim_prefix("melee_")
			await _until(func(): return String(actor.weapon_phase) == phase, {}, .5)
		elif context.ends_with("roll"):
			await _step({"roll": true})
			await _seconds({}, actor.combat_profile.roll_attack_cancel_after + dt if context == "late_roll" else .04)
		elif context == "climb":
			var sensor = CLIMBABLE.instantiate(); sensor.position = Vector2(100, 450); sensor.height = 400; world.add_child(sensor); await _sync_geometry()
			await _until(func(): return actor.main_action == &"climb", {"up": 1.0}, .3)
		elif context == "wall":
			actor.allow_wall_run = true; _box(Vector2(118, 200), Vector2(20, 1400)); await _sync_geometry()
			await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .3)
		elif context == "ledge":
			_box(Vector2(148, 210), Vector2(80, 80)); await _sync_geometry()
			await _until(func(): return actor.main_action == &"ledge", {"right": 1.0}, .3)
		elif context.begins_with("dive_"):
			_box(Vector2(100, 620), Vector2(1000, 40)); await _sync_geometry()
			await _step({"down": 1.0, "jump": true})
			var phase: String = context.trim_prefix("dive_")
			await _until(func(): return String(actor.dive_phase) == phase, {}, 2)
		elif context == "hurt": actor.receive_hit({"impulse": Vector2.ZERO, "hitpause": 0.0, "stun_seconds": .18})
		else:
			_box(Vector2(100, 570), Vector2(1000, 40)); await _sync_geometry()
			actor.enable_hard_landing = true; actor.reset_actor(Vector2(100, 200), 1)
			await _until(func(): return actor.main_action == &"hard_land", {}, 2)
		var previous_owner: String = actor.main_action
		var previous_weapon: String = actor.weapon_phase
		var previous_attack: int = actor.attack_serial
		var accepted: bool = context in ["melee_windup", "melee_recovery", "late_roll", "climb", "wall", "dive_startup", "dive_recovery"]
		await _step({"shield": true})
		_check((actor.shield_phase != &"idle") == accepted, "actual prior phase admits or refuses shield according to the declared intersection")
		if accepted:
			_check(actor.weapon_phase == &"idle" and actor.main_action not in [&"climb", &"wall", &"roll", &"dive"], "accepted shield transaction retires the previous weapon or traversal contact")
			_check(not actor.confirm_strike(previous_attack, 123456, actor.position), "prior strike confirmation cannot outlive a shield replacement")
		else:
			_check(String(actor.main_action) == previous_owner and String(actor.weapon_phase) == previous_weapon, "denied admission does not partially retire its committed previous owner")
		if context in ["melee_active", "hard_land"]:
			await _until(func(): return actor.shield_phase != &"idle", {"shield": true}, .6)
			_check(actor.shield_serial == 1, "still-valid or hard-recovery-retained buffered press starts once when the real gate opens")
			if context == "hard_land":
				_check(frames.all(func(record): return not bool(record.after.hard_land_active) or record.after.shield_phase == "idle"), "both hard-landing phases retain shield denial until actual recovery completion")
			await _seconds({"shield": true}, .05)
			_check(actor.shield_serial == 1, "held input cannot turn gate-opening admission into repeated attempts")
		measurements.merge(_trace_bounds()); await _finish()

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed; Input.parse_input_event(event)

func _history_cases() -> void:
	await _shield_begin("bounded history reordered IDs duplicates and stale contact")
	var source := _source(actor.position + Vector2(35, -17))
	await _enter_phase("hold")
	var base := _attack(source, {"attack_id": 10, "amount": 0.0})
	var first := _deliver_now(base)
	_check(first.get("outcome") == &"guarded", "one live emitter's first physical descriptor is consumed normally")
	var before_pause: float = actor.hitpause_remaining
	var higher := _deliver_now(base.merged({"attack_id": 12}, true))
	var reordered := _deliver_now(base.merged({"attack_id": 11}, true))
	_check(higher.get("outcome") == &"guarded" and reordered.get("outcome") == &"guarded", "nearby previously unseen lower IDs remain eligible after a newer arrival")
	_near(actor.hitpause_remaining, before_pause, .00000001, "distinct guard contacts share one feedback-pause budget instead of extending the attempt indefinitely")
	var window: int = actor.shield_profile.incoming_history_window
	for identifier in range(13, window + 40): _deliver_now(base.merged({"attack_id": identifier}, true))
	_check(int(actor.telemetry().incoming_history_entries) <= window, "live emitter history has a bounded authored retention window")
	var noises_before := noises.size(); var events_before := events.size()
	var stale := _deliver_now(base)
	_check(stale.get("outcome") == &"rejected" and stale.get("reason") == &"stale_attack_id" and not stale.get("consumed", true), "evicted old identity remains permanently ineligible within this emitter lifetime")
	_check(noises.size() == noises_before and events.size() == events_before, "stale attack has no renewed guard recoil noise or feedback")
	var recent := base.merged({"attack_id": window + 39}, true)
	_check(_deliver_now(recent).get("outcome") == &"duplicate", "recent consumed identity remains a duplicate")
	await _step(); await _phase("idle", false)
	await _open_shield()
	_check(_deliver_now(recent).get("outcome") == &"duplicate", "fresh shield attempt cannot re-parry a prior accepted identity")
	actor.receive_hit({"impulse": Vector2.ZERO, "hitpause": 0.0})
	_check(_deliver_now(recent).get("outcome") == &"duplicate", "ordinary hurt does not reset contact identity history")
	await _finish()
	await _shield_begin("invalid far ID cannot advance history window")
	source = _source(actor.position + Vector2(35, -17)); await _enter_phase("hold")
	base = _attack(source, {"attack_id": 3})
	_deliver_now(base)
	var invalid := base.merged({"attack_id": 100000, "contact_position": actor.position + Vector2(200, 0)}, true)
	_check(_deliver_now(invalid).get("outcome") == &"rejected", "invalid contact with far-future ID is rejected before retention advances")
	_check(_deliver_now(base.merged({"attack_id": 4}, true)).get("outcome") == &"guarded", "valid nearby contact remains usable after invalid far ID")
	var old_serial: int = actor.shield_serial
	actor.reset_actor(actor.position, 1); await _step()
	_check(actor.shield_serial >= old_serial and int(actor.telemetry().incoming_history_entries) == 0, "reset clears contact history while preserving non-reused attempt identity")
	await _finish()
	for invalidity in ["missing_source", "removed_source", "queued_source", "fractional_id", "negative_id"]:
		await _shield_begin("identified descriptor rejection " + invalidity)
		source = _source(actor.position + Vector2(35, -17)); await _open_shield()
		base = _attack(source)
		if invalidity == "missing_source": base.erase("source")
		elif invalidity == "removed_source": world.remove_child(source)
		elif invalidity == "queued_source": source.queue_free()
		elif invalidity == "fractional_id": base.attack_id = 1.5
		else: base.attack_id = -1
		var result := _deliver_now(base)
		_check(result.get("outcome") == &"rejected" and not result.get("consumed", true), "malformed or unavailable required authenticator cannot gain defense or ordinary hurt")
		_check(noises.is_empty() and _count("hurt_started") == 0, "rejected identity is silent and leaves the actor untouched")
		if invalidity == "removed_source": source.queue_free()
		await _finish()

func _native_buffer_cases() -> void:
	await _shield_begin("native press and release before one physics callback")
	_key(KEY_K, true); _key(KEY_K, false); await _step(null)
	_check(actor.shield_serial == 1 and actor.shield_phase == &"raise", "parsed sub-callback tap is captured once despite its final released level")
	await _until(func(): return actor.shield_phase == &"miss_recovery", null, .4)
	_check(actor.shield_phase == &"miss_recovery" and actor.shield_serial == 1, "same-callback release cannot become a sustained guard or a repeated attempt")
	await _finish()
	await _shield_begin("native shield tap captured wholly during local pause")
	actor.apply_hitpause(.12); var origin: Vector2 = actor.position
	_key(KEY_K, true); await _step(null)
	_key(KEY_K, false); await _seconds(null, .04)
	_check(actor.shield_phase == &"idle" and float(actor.telemetry().shield_buffer) > 0, "parsed paused press is captured without advancing shield ownership")
	_near(actor.position.distance_to(origin), 0, .0001, "stationary actor pause keeps physical motion frozen")
	await _until(func(): return actor.shield_phase != &"idle", null, .3)
	var serial: int = actor.shield_serial
	await _until(func(): return actor.shield_phase == &"miss_recovery", null, .4)
	_check(actor.shield_phase == &"miss_recovery" and actor.shield_serial == serial, "release captured during pause keeps the resumed attempt a tap")
	await _phase("idle", false); await _seconds(null, .2)
	_check(actor.shield_serial == serial, "paused tap is consumed once without held or stale rearm")
	await _finish()
	await _shield_begin("native tap then repress preserves old attempt latch")
	_key(KEY_K, true); await _step(null); var first_serial: int = actor.shield_serial
	_key(KEY_K, false); await _step(null)
	await _seconds(null, .06); _key(KEY_K, true); await _step(null)
	await _until(func(): return actor.shield_phase == &"miss_recovery", null, .3)
	_check(actor.shield_phase == &"miss_recovery" and actor.shield_serial == first_serial, "later held repress cannot convert the earlier released attempt into guard")
	await _until(func(): return actor.shield_phase == &"idle", null, .3)
	_check(actor.shield_serial == first_serial, "ordinary shield-phase buffer lifetime expires a too-early re-press")
	_key(KEY_K, false); await _step(null); _key(KEY_K, true); await _step(null)
	_check(actor.shield_serial == first_serial + 1, "fresh post-expiry edge still starts a new attempt")
	await _finish()
	for boundary in ["before", "at", "after"]:
		await _shield_begin("native shield rearm gate " + boundary)
		await _open_shield(false)
		var source := _source(actor.position + Vector2(35, -17)); _deliver_now(_attack(source))
		await _until(func(): return actor.hitpause_remaining <= 0, {}, .2)
		await _until(func(): return actor.shield_phase == &"idle", {}, .2)
		var old_serial: int = actor.shield_serial
		var lead := 1 if boundary == "before" else (0 if boundary == "at" else -1)
		while float(actor.telemetry().shield_lock_remaining) > maxf(0, lead + 1) * dt + .000000001: await _step(null)
		if boundary == "after": await _step(null)
		_key(KEY_K, true); await _step(null); _key(KEY_K, false); await _step(null)
		await _until(func(): return actor.shield_serial > old_serial, null, .2)
		_check(actor.shield_serial == old_serial + 1, "fresh parsed edge immediately before at or after lock eligibility is consumed exactly once")
		await _seconds(null, .2)
		_check(actor.shield_serial == old_serial + 1 and actor.shield_phase != &"hold", "accepted queued tap retains its release edge over later callbacks")
		await _finish()

func _callback_cases() -> void:
	for stage in ["shield_started", "parry_phase", "defense_resolved", "parry_noise", "hitpause_started"]:
		for replacement in ["reset", "hurt"]:
			await _shield_begin("shield callback %s replaces with %s" % [stage, replacement])
			var callback_state := {"called": false}
			var replace := func():
				if callback_state.called: return
				callback_state.called = true
				if replacement == "reset": actor.reset_actor(actor.position, 1)
				else: actor.receive_hit({"impulse": Vector2(17, -111), "hitpause": 0.0})
			actor.movement_event.connect(func(label, payload):
				if (stage == "shield_started" and label == &"shield_started") or (stage == "parry_phase" and label == &"shield_phase_changed" and payload.phase == &"parry") or (stage == "defense_resolved" and label == &"defense_resolved" and payload.get("outcome") == &"parried") or (stage == "hitpause_started" and label == &"hitpause_started"): replace.call())
			actor.noise_requested.connect(func(_at, kind, _loudness, _source):
				if stage == "parry_noise" and kind == &"parry": replace.call())
			await _step({"shield": true})
			if not callback_state.called: await _until(func(): return callback_state.called or actor.is_shield_parry_open(), {"shield": true}, .3)
			if not callback_state.called:
				var source := _source(actor.position + Vector2(35, -17)); _deliver_now(_attack(source, {"counterable": true}))
			_check(callback_state.called and actor.shield_phase == &"idle", "synchronous replacement retires the old shield owner at the selected callback boundary")
			_check(effect_requests.is_empty() and effect_reports.is_empty(), "stale shield continuation cannot request or confirm an outgoing effect after replacement")
			if replacement == "hurt": _check(actor.main_action == &"hurt" and actor.action_phase == &"recoil", "new forced hurt ownership and phase survive shield callback return")
			var expected_pause: float = actor.shield_profile.parry_hitpause_seconds if stage == "hitpause_started" and replacement == "hurt" else 0.0
			_near(actor.hitpause_remaining, expected_pause, .000000001, "replacement preserves already-applied pause but prevents later stale shield feedback")
			await _seconds({}, .03)
			_check(actor.shield_phase == &"idle", "retired attempt remains absent over subsequent callbacks")
			await _finish()
	for stage in ["action_changed", "hurt_started", "hurt_noise"]:
		await _shield_begin("structured hurt callback preserves newer owner " + stage)
		var callback_state := {"called": false}
		var replace := func():
			if callback_state.called: return
			callback_state.called = true
			actor.begin_main_action(&"forced", {}, func(player, _delta, _frame): player.velocity = Vector2(17, -111); return true)
			actor.action_phase = &"host_owned"; actor.velocity = Vector2(17, -111)
		actor.action_changed.connect(func(_old, next):
			if stage == "action_changed" and next == &"hurt": replace.call())
		actor.movement_event.connect(func(label, _payload):
			if stage == "hurt_started" and label == &"hurt_started": replace.call())
		actor.noise_requested.connect(func(_at, kind, _loudness, _source):
			if stage == "hurt_noise" and kind == &"hurt": replace.call())
		var source := _source(actor.position + Vector2(35, -17))
		_deliver_now(_attack(source, {"hitpause": .1}))
		_check(callback_state.called and actor.main_action == &"forced" and actor.action_phase == &"host_owned", "new main-action generation keeps its custom phase after structured incoming hurt returns")
		_near(actor.velocity.distance_to(Vector2(17, -111)), 0, .000001, "old hurt setup cannot overwrite the accepted replacement impulse")
		_near(actor.hitpause_remaining, 0, .000001, "old hurt feedback cannot impose a later pause on the replacement")
		await _seconds({}, .03)
		_check(actor.main_action == &"forced" and actor.action_phase == &"host_owned" and actor.velocity.y < 0, "new owner survives several real callbacks beyond the synchronous replacement")
		await _finish()
	await _shield_begin("effect confirmation scope rejects delayed wrong and repeated callbacks")
	var adapter := _attach_defense_adapter(); adapter.bind_actor(null)
	var source := _source(actor.position + Vector2(35, -17))
	var captured := {}
	var confirmations := []
	actor.shield_effect_requested.connect(func(_owner, request):
		captured.merge(request, true)
		confirmations.append(actor.confirm_shield_effect(request.shield_serial, request.attack_key, request.effect, request.target_id + 1, true))
		confirmations.append(actor.confirm_shield_effect(request.shield_serial, request.attack_key, request.effect, request.target_id, false))
		confirmations.append(actor.confirm_shield_effect(request.shield_serial, request.attack_key, request.effect, request.target_id, true)))
	await _open_shield(); var result := _deliver_now(_attack(source, {"counterable": true}))
	_check(result.get("outcome") == &"parried" and not result.get("counter_confirmed", false) and confirmations == [false, false, false], "wrong target rejected response and duplicate confirmation cannot fabricate an outgoing success")
	_check(not actor.confirm_shield_effect(captured.shield_serial, captured.attack_key, captured.effect, captured.target_id, true), "effect authority closes when synchronous request emission returns")
	actor.reset_actor(actor.position, 1)
	_check(not actor.confirm_shield_effect(captured.shield_serial, captured.attack_key, captured.effect, captured.target_id, true), "reset cannot revive a retained old effect callback")
	await _finish()

func _air_and_clearance_cases() -> void:
	for hard in [false, true]:
		await _shield_begin("shield preserves spent airborne resources then %s landing" % ("hard" if hard else "soft"), Vector2(100, -250), false)
		_box(Vector2(100, 620), Vector2(4000, 40)); await _sync_geometry()
		actor.enable_hard_landing = hard; actor.reset_actor(Vector2(100, -250), 1)
		await _step({"jump": true}); await _step()
		await _until(func(): return float(actor.telemetry().fall_distance) > 130, {}, 2)
		await _step({"roll": true}); await _seconds({}, actor.combat_profile.roll_jump_cancel_after + dt)
		await _step({"down": 1.0, "jump": true})
		var before_distance: float = actor.telemetry().fall_distance
		_check(actor.main_action == &"dive" and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "real air jump roll and dive spend independent resources before shield admission")
		await _step({"shield": true})
		_check(actor.shield_phase == &"raise" and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "shield replacement cannot refill any spent airborne budget")
		_check(float(actor.telemetry().fall_distance) >= before_distance - .03 and actor.velocity.y > 0, "shield preserves the existing fall excursion and continued gravity")
		await _until(func(): return actor.grounded, {"shield": true}, 2)
		_check(actor.grounded and actor.air_jumps_left == actor.profile.air_jump_count and actor.air_roll_available and actor.dive_available and _count("landed") == 1, "one genuine floor contact refills airborne budgets independently of shield use")
		_check((actor.main_action == &"hard_land") == hard and (actor.shield_phase == &"idle") == hard, "qualifying hard landing preempts shield while ordinary soft landing preserves guard")
		measurements.merge(_trace_bounds()); await _finish()
	await _shield_begin("small body shield contact under low ceiling")
	await _step({"down": 1.0})
	_box(actor.position + Vector2(0, -26.3), Vector2(80, 12)); await _sync_geometry()
	await _open_shield()
	_check(actor.crouched and actor.body_height == actor.profile.crouching_height, "real low ceiling retains the small physical body during shield use")
	var source := _source(actor.position + Vector2(35, -11))
	var result := _deliver_now(_attack(source))
	_check(result.get("outcome") == &"parried", "shield band follows the actual small collider rather than an assumed standing silhouette")
	await _until(func(): return actor.position.x > 170, {"right": 1.0}, 1.5)
	_check(not actor.crouched and actor.grounded, "ordinary standing clearance returns after leaving the actual roof")
	measurements.merge(_trace_bounds()); await _finish()

func _jump_owner_landings() -> void:
	for direction in [-1, 1]:
		for mode in ["ground_jump_soft", "air_jump_soft", "air_jump_hard"]:
			var air: bool = mode.begins_with("air")
			var hard: bool = mode.ends_with("hard")
			await _shield_begin("held shield survives %s completion direction%d" % [mode, direction], Vector2(100, 0 if air else 200), not air)
			if air: _box(Vector2(0, 220), Vector2(2000, 40)); await _sync_geometry()
			actor.enable_hard_landing = hard; actor.reset_actor(Vector2(100, 0 if air else 200), direction)
			await _step({"jump": true})
			await _step({"shield": true, "jump": true})
			_check(actor.shield_phase == &"raise" and actor.main_action == (&"air_jump" if air else &"jump"), "independent shield enters while the accepted jump main owner remains live")
			await _until(func(): return actor.grounded, {"shield": true, "jump": true}, 2)
			_check(actor.grounded and _count("landed") == 1, "jump with held shield reaches one actual floor contact")
			if hard:
				_check(actor.main_action == &"hard_land" and actor.shield_phase == &"idle", "qualifying hard floor preempts the independent shield owner")
			else:
				_check(actor.main_action == &"locomotion" and actor.shield_phase == &"hold" and _count("shield_cancelled") == 0, "ordinary automatic jump completion preserves the independently held shield")
			measurements.merge(_trace_bounds()); await _finish()

func _final_intersections() -> void:
	for identified in [false, true]:
		for phase in ["idle", "parry", "hold", "roll"]:
			await _shield_begin("receive_hit Boolean %s %s" % ["identified" if identified else "legacy", phase])
			if phase in ["parry", "hold"]: await _enter_phase(phase)
			elif phase == "roll":
				await _step({"roll": true}); await _until(func(): return actor.is_roll_invulnerable(), {}, .2)
			var source := _source(actor.position + Vector2(35, -17))
			var payload := _attack(source) if identified else {"amount": 8, "impulse": Vector2.ZERO, "hitpause": 0.0, "rollable": true}
			var applied: bool = actor.receive_hit(payload)
			var expected: bool = phase == "idle" or (not identified and phase != "roll")
			_check(applied == expected, "legacy Boolean remains true only for an actually applied ordinary hurt response")
			_check((_count("hurt_started") > 0) == expected, "guard parry and evasion are never misreported as the old hurt Boolean")
			await _finish()
	await _shield_begin("shield admission during targeted drop preserves cleanup", Vector2(100, 200), true, true)
	var upper: PhysicsBody2D = boxes[0].body
	var lower := _box(Vector2(0, 248), Vector2(3000, 8), true)
	await _sync_geometry(); await _step({"down": 1.0, "jump": true})
	_check(actor.main_action == &"drop" and actor.get_collision_exceptions() == [upper], "fresh grounded chord begins the real targeted one-way drop")
	await _step({"shield": true})
	_check(actor.shield_phase == &"raise" and actor.main_action != &"drop" and actor.body_height == actor.profile.crouching_height and actor.get_collision_exceptions() == [upper], "shield retirement of drop owner keeps its independently required small body and exact target exception")
	await _until(func(): return actor.grounded and actor.telemetry().support_id == lower.get_instance_id(), {"shield": true}, 1)
	_check(actor.grounded and actor.telemetry().support_id == lower.get_instance_id() and actor.get_collision_exceptions().is_empty(), "shield continues through full-body clearance onto the separate lower support")
	_check(_count("dive_started") == 0 and _count("air_jump") == 0, "consumed drop chord cannot be reused by shield admission as dive or air jump")
	measurements.merge(_trace_bounds()); await _finish()
	await _shield_begin("moving shield support and local pause", Vector2(100, 200), false)
	var carrier := _box(Vector2(100, 220), Vector2(1000, 40), false, true)
	await _sync_geometry(); actor.reset_actor(Vector2(100, 200), 1); await _enter_phase("hold")
	var relative: Vector2 = actor.position - carrier.position
	var landings := _count("landed")
	before_tick = func(delta): carrier.position += Vector2(30, -20) * delta
	actor.apply_hitpause(.12)
	await _seconds({"shield": true}, .08)
	_near((actor.position - carrier.position).distance_to(relative), 0, .05, "shield-local pause retains swept moving-floor transport without locomotion drift")
	var source := _source(actor.position + Vector2(35, -17)); var result := _deliver_now(_attack(source))
	_check(result.get("outcome") == &"guarded" and actor.shield_phase == &"hold", "valid guard contact resolves against the transported actor body during pause")
	await _seconds({"shield": true}, .2)
	_check(actor.grounded and _count("landed") == landings and actor.shield_phase == &"hold", "paused guard and recoil resume on the moving support without false landings or stale weapon state")
	before_tick = Callable(); carrier.queue_free(); await _seconds({"shield": true}, .12)
	_check(not actor.grounded and actor.velocity.y > 0 and actor.shield_phase == &"hold", "removed support releases gravity while leaving the permitted independent held shield")
	measurements.merge(_trace_bounds()); await _finish()
	for gate in ["ability", "host"]:
		await _shield_begin("live shield gate withdrawal during pause " + gate)
		await _open_shield(); actor.apply_hitpause(.1)
		if gate == "ability": actor.allow_shield = false
		else: actor.set_weapon_permissions({"can_shield": false})
		_check(not actor.is_shield_parry_open(), "incoming defense authority sees a withdrawn gate immediately during local pause")
		await _seconds({"shield": true}, .12)
		_check(actor.shield_phase == &"idle" and float(actor.telemetry().shield_lock_remaining) > 0, "active simulation safely retires the withdrawn shield without erasing its independent lock")
		await _finish()

func _priority_and_kick_cases() -> void:
	await _shield_begin("committed wall kick refuses shield admission", Vector2(100, 200), false)
	actor.allow_wall_run = true; _box(Vector2(118, 200), Vector2(20, 1400)); await _sync_geometry()
	await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .3)
	await _step({"right": 1.0, "jump": true})
	_check(actor.main_action == &"wall" and actor.wall_phase == &"kick", "real supported wall input starts its outward committed kick")
	await _step({"shield": true, "jump": true})
	_check(actor.shield_phase == &"idle" and actor.wall_phase == &"kick" and actor.velocity.x < 0 and actor.velocity.y < 0, "shield cannot cancel or swallow the committed outward kick")
	await _until(func(): return actor.shield_phase != &"idle", {"shield": true, "jump": true}, .3)
	_check(actor.shield_serial == 1 and actor.position.x < 100, "still-valid shield buffer waits for commitment to end while outward motion survives")
	await _finish()
	await _shield_begin("simultaneous roll jump shield attack priority")
	await _step({"roll": true, "jump": true, "shield": true, "attack": true})
	_check(actor.main_action == &"roll" and actor.shield_phase == &"idle" and actor.weapon_phase == &"idle", "eligible roll owns the simultaneous input callback before lower-priority new actions")
	await _seconds({}, .4)
	_check(_count("roll_started") == 1 and _count("shield_started") == 0 and _count("attack_started") == 0 and _count("ground_jump") == 0, "lower-priority finite queues cannot outlive their cancellation gates and become phantom actions")
	await _finish()
	await _shield_begin("simultaneous shield attack priority")
	await _step({"shield": true, "attack": true})
	_check(actor.shield_phase == &"raise" and actor.weapon_phase == &"idle", "shield wins same-callback admission before melee")
	await _seconds({"shield": true}, .35)
	_check(_count("shield_started") == 1 and _count("attack_started") == 0 and actor.shield_phase == &"hold", "expired lower-priority melee press cannot bypass the live shield or incurred use lock")
	await _finish()
