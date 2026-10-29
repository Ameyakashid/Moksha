extends "res://combat_pc/tests/soft_slope_regression.gd"
## Ordinary-air checkpoint: independent, same-initial-state excluded-owner parity.
## Production physics_tick is called once by the inherited actual physics driver.
const BASELINE_PATH = "res://combat_pc/resources/ground_response_agile.tres"
const CANDIDATE_PATH = "res://combat_pc/resources/air_response_agile.tres"
const OWNERS = ["roll", "wall_kick", "climb", "ledge", "drop", "dive", "hurt", "weapon", "charge", "shield", "driver_true", "driver_false", "permissions_lock", "input_disabled", "action_inputs_denied", "zero_scale", "crouch"]
const STATE_FIELDS = ["position", "velocity", "grounded", "main_action", "action_phase", "facing", "body_height", "air_jumps_left", "air_roll_available", "dive_available", "weapon_phase", "shield_phase", "wall_phase", "climb_phase", "roll_phase", "dive_phase", "crouched", "drop_exception_active", "custom_driver", "allow_input", "uses_inputs", "weapon_permissions", "phase_progress", "roll_elapsed", "weapon_elapsed", "shield_elapsed", "wall_kick_elapsed", "hurt_elapsed", "charge_elapsed"]
var variant := "baseline"
var active_owner := ""
var parity_start := 0
var initial_state := {}
var reference_cases := {}
var owner_rows: Array[Dictionary] = []
var protected_hashes := {}

func _run() -> void:
	for path in ["res://combat_pc/player.gd", "res://combat_pc/player.tscn", "res://combat_pc/resources/movement_profile.gd", BASELINE_PATH, CANDIDATE_PATH, "res://combat_pc/resources/air_response_profile.gd", "res://combat_pc/resources/ground_response_profile.gd", "res://combat_pc/resources/combat_profile.gd", "res://combat_pc/resources/shield_profile.gd", "res://combat_pc/resources/held_charge.tres", "res://combat_pc/tests/soft_slope_regression.gd", "res://combat_pc/tests/air_response_owners.gd"]:
		protected_hashes[path] = FileAccess.get_sha256(path)
	for mode in ["baseline", "candidate"]:
		variant = mode
		for direction in [-1, 1]:
			for owner in OWNERS: await _owner_case(owner, direction)
			await _scaled_case(direction)
	name_ = "source stability"
	var stable := true
	for path in protected_hashes: stable = stable and protected_hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "production resources and unchanged inherited helpers remained stable during run")
	var report := {"suite":"air response excluded owners", "physics_hz":hz, "engine":Engine.get_version_info().string, "checks":checks, "failures":failures, "scenario_count":scenarios.size(), "scenarios":scenarios, "owner_rows":owner_rows, "source_hashes":protected_hashes, "production_hash_stable_during_run":stable,
		"baseline_resource":BASELINE_PATH, "candidate_resource":CANDIDATE_PATH,
		"method":"Identical baseline physical fixture setup in both variants, then actual profile selection at a recorded identical checkpoint. Compare position, velocity and owner state only through the excluded interval. Measure subsequent ordinary steering independently, without claiming that post-release arcs stay identical. One production call per actual physics callback.",
		"limits":["Headless deterministic physical acceptance; visual judgment belongs to separate review.", "Ledge parity includes catch, hang and partial pull, followed by input release; no claim of full-mantle coverage.", "Dive parity includes startup and descent, followed by public host retirement; impact is covered by retained historical suites.", "Host movement lock is compared while locked. Restoring host permissions intentionally admits the optional ordinary steering response."]}
	FileAccess.open("res://combat_pc/tests/air_response_owners_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  ") + "\n")
	print("AIR_RESPONSE_OWNERS %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for row in owner_rows: print(JSON.stringify(row))
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _sample() -> Dictionary:
	var result := super._sample()
	result.merge({"shield_phase":String(actor.shield_phase), "wall_phase":String(actor.wall_phase), "climb_phase":String(actor._climb_phase), "roll_phase":String(actor.roll_phase), "dive_phase":String(actor.dive_phase), "crouched":actor.crouched,
		"custom_driver":actor._action_driver.is_valid(), "allow_input":actor.allow_input, "uses_inputs":actor._uses_inputs(), "selected_air_acceleration":actor._air_acceleration(), "weapon_permissions":actor._weapon_permissions.duplicate(true), "phase_progress":actor.phase_progress,
		"roll_elapsed":actor._roll_elapsed, "weapon_elapsed":actor._weapon_elapsed, "shield_elapsed":actor._shield_elapsed, "wall_kick_elapsed":actor._wall_kick_elapsed, "hurt_elapsed":actor._hurt_elapsed, "charge_elapsed":actor._charge_elapsed})
	return result

func _state(sample: Dictionary) -> Dictionary:
	var result := {}
	for key in STATE_FIELDS: result[key] = sample[key]
	return _safe(result)

func _activate(owner: String) -> void:
	active_owner = owner
	actor.profile = load(CANDIDATE_PATH if variant == "candidate" else BASELINE_PATH).duplicate(true)
	parity_start = frames.size()
	initial_state = _state(_sample())
	params = {"variant":variant, "owner":owner, "same_initial_state_checkpoint":initial_state, "profile":CANDIDATE_PATH if variant == "candidate" else BASELINE_PATH}

func _owned(sample: Dictionary) -> bool:
	match active_owner:
		"wall_kick": return sample.main_action == "wall" and sample.wall_phase == "kick"
		"weapon": return sample.weapon_phase != "idle"
		"charge": return sample.weapon_phase != "idle"
		"shield": return sample.shield_phase != "idle"
		"drop": return sample.main_action == "drop" or sample.drop_exception_active or sample.crouched
		"driver_true", "driver_false": return sample.custom_driver
		"permissions_lock": return not sample.weapon_permissions.can_move
		"input_disabled": return not sample.allow_input
		"action_inputs_denied": return not sample.uses_inputs
		"zero_scale": return sample.weapon_permissions.move_scale == 0
		"crouch": return sample.crouched
	return sample.main_action == active_owner

func _ordinary() -> bool:
	return not actor.grounded and actor.main_action in [&"locomotion", &"jump", &"air_jump"] and not actor.crouched and not is_instance_valid(actor._drop_body) and not actor._action_driver.is_valid() and actor.weapon_phase == &"idle" and actor.shield_phase == &"idle"

func _resume(direction: int) -> void:
	_check(_ordinary(), "owner has retired into actual ordinary airborne control before resumption sample")
	if not _ordinary(): return
	var before: Vector2 = actor.velocity
	var at: Vector2 = actor.position
	var acceleration := 2300.0 if variant == "candidate" else 1450.0
	var scale: float = actor._weapon_permissions.move_scale
	var target: float = direction * actor.profile.run_speed * scale
	var expected := move_toward(before.x, target, acceleration * dt)
	await _step(_direction(direction))
	_near(actor.velocity.x, expected, .0001, "next ordinary callback uses the selected air acceleration after retirement")
	_near(actor.position.x - at.x, expected * dt, .0001, "resumed ordinary velocity is applied by the real sweep")
	_check(absf(before.x - target) > acceleration * dt, "resumption input exposes acceleration before target saturation")
	measurements.resumption = {"initial_velocity":before, "final_velocity":actor.velocity, "direction":direction, "expected_acceleration":acceleration, "measured_acceleration":absf(actor.velocity.x - before.x) / dt}

func _compare_owner(direction: int, required_phases: Dictionary = {}) -> void:
	var sequence: Array[Dictionary] = []
	var phases := {}
	var airborne_samples := 0
	var drop_after_action := 0
	var selected_baseline_acceleration := true
	for index in range(parity_start, frames.size()):
		var sample: Dictionary = frames[index].after
		if not _owned(sample): continue
		sequence.append(_state(sample))
		selected_baseline_acceleration = selected_baseline_acceleration and absf(float(sample.selected_air_acceleration) - 1450.0) < .00001
		if not sample.grounded: airborne_samples += 1
		if sample.drop_exception_active and sample.main_action != "drop": drop_after_action += 1
		for field in ["action_phase", "weapon_phase", "shield_phase", "wall_phase", "climb_phase", "roll_phase", "dive_phase"]:
			if not phases.has(field): phases[field] = []
			if not phases[field].has(sample[field]): phases[field].append(sample[field])
	_check(sequence.size() >= 2 and airborne_samples >= 2, "real action reaches a nonempty multi-callback airborne excluded interval")
	_check(selected_baseline_acceleration, "all excluded-owner samples select the unchanged 1450 air coefficient, including permissions that suppress motion")
	for field in required_phases:
		for phase in required_phases[field]: _check(phases.get(field, []).has(phase), "real excluded interval covers %s %s" % [field, phase])
	if active_owner == "drop": _check(drop_after_action > 0, "drop collision exception remains protected after drop main action retires")
	var key := active_owner + str(direction)
	var row := {"variant":variant, "owner":active_owner, "direction":direction, "owned_samples":sequence.size(), "airborne_owned_samples":airborne_samples, "observed_phases":phases, "post_action_drop_exception_samples":drop_after_action}
	if variant == "baseline": reference_cases[key] = {"initial":initial_state.duplicate(true), "sequence":sequence.duplicate(true)}
	else:
		var reference: Dictionary = reference_cases[key]
		_check(initial_state == reference.initial, "candidate and baseline begin at exactly the same physical and owner state")
		var same_state: bool = sequence.size() == reference.sequence.size()
		var position_error := 0.0
		var velocity_error := 0.0
		for index in mini(sequence.size(), reference.sequence.size()):
			var wanted: Dictionary = reference.sequence[index]
			var actual: Dictionary = sequence[index]
			position_error = maxf(position_error, Vector2(actual.position[0], actual.position[1]).distance_to(Vector2(wanted.position[0], wanted.position[1])))
			velocity_error = maxf(velocity_error, Vector2(actual.velocity[0], actual.velocity[1]).distance_to(Vector2(wanted.velocity[0], wanted.velocity[1])))
			for field in STATE_FIELDS:
				if field not in ["position", "velocity"]: same_state = same_state and actual[field] == wanted[field]
		_check(same_state and position_error < .00001 and velocity_error < .00001, "candidate preserves baseline position velocity and owner state throughout the excluded interval")
		row.maximum_position_error = position_error
		row.maximum_velocity_error = velocity_error
		row.same_owner_state = same_state
	measurements.parity = row
	owner_rows.append(row)

func _owner_case(owner: String, direction: int) -> void:
	await _begin("%s %s direction%d" % [variant, owner, direction], Vector2(0, -1000))
	actor.profile = load(BASELINE_PATH).duplicate(true)
	actor.initial_facing = direction
	var requirements := {}
	if owner == "wall_kick":
		actor.position = Vector2(0, 280)
		actor.allow_wall_run = true
		_box(Vector2(direction * 62, 0), Vector2(100, 2000))
		await _start()
		_check(await _until(func(): return actor.main_action == &"wall", _direction(direction), .5), "physical contact admits wall owner before kick")
	elif owner == "ledge":
		actor.position = Vector2(-direction * 14, 29)
		_box(Vector2(direction * 60, 100), Vector2(120, 200))
		await _start()
		_check(await _until(func(): return actor.main_action == &"ledge", _direction(direction), .4), "actual rays and body sweep acquire real ledge before checkpoint")
	elif owner == "climb":
		actor.position = Vector2(direction * 7, 140)
		var sensor = CLIMBABLE.instantiate()
		sensor.position = Vector2(0, 500); sensor.height = 600
		world.add_child(sensor)
		await _start()
	elif owner == "drop":
		actor.position = Vector2(0, -2)
		_box(Vector2(0, 4), Vector2(1000, 8), true)
		await _start()
		_check(await _until(func(): return actor.grounded), "real one-way support exists before drop request")
	else:
		await _start(Vector2(direction * 120, -60))
	actor.facing = direction
	_activate(owner)
	match owner:
		"roll":
			await _step(_direction(direction, {"roll":true}))
			await _until(func(): return actor.main_action != &"roll", _direction(-direction), .7)
			requirements = {"roll_phase":["start", "travel", "recovery"]}
		"wall_kick":
			await _step(_direction(direction, {"jump":true}))
			await _until(func(): return actor.main_action != &"wall", _direction(direction, {"jump":true}), .4)
			_check(_count("wall_kick") == 1, "one real jump edge starts exactly one outward kick")
			requirements = {"wall_phase":["kick"]}
		"climb":
			await _seconds({"up":1.0, "right" if direction > 0 else "left":.4}, .18)
			await _seconds({}, .15)
			await _seconds({"down":1.0}, .15)
			await _step(_direction(direction))
			requirements = {"climb_phase":["align", "ascend", "idle", "descend"]}
		"ledge":
			await _seconds({}, .2)
			await _seconds({"up":1.0}, .07)
			await _step(_direction(-direction))
			requirements = {"action_phase":["catch", "hang", "pull"]}
		"drop":
			await _step(_direction(-direction, {"down":1.0, "jump":true}))
			await _until(func(): return actor.main_action != &"drop" and not is_instance_valid(actor._drop_body), _direction(-direction), .7)
			await _until(_ordinary, {}, .4)
			requirements = {"action_phase":["release"]}
		"dive":
			await _step(_direction(-direction, {"down":1.0, "jump":true}))
			await _seconds(_direction(direction), .2)
			actor.finish_main_action()
			requirements = {"dive_phase":["startup", "descent"]}
		"hurt":
			_check(actor.receive_hit({"impulse":Vector2(direction * 120, -60), "hitpause":0.0, "stun_seconds":.25}), "public hit API admits actual hurt owner")
			await _until(func(): return actor.main_action != &"hurt", _direction(-direction), .6)
		"weapon":
			await _step(_direction(-direction, {"attack":true}))
			await _until(func(): return actor.weapon_phase == &"idle", _direction(direction), .7)
			requirements = {"weapon_phase":["windup", "active", "recovery"]}
		"charge":
			actor.melee_input_profile = load("res://combat_pc/resources/held_charge.tres").duplicate(true)
			await _step(_direction(-direction, {"attack":true}))
			_check(await _until(func(): return actor.weapon_phase == &"charge", _direction(direction, {"attack":true}), .7), "held authored charge resource reaches real charge phase")
			await _seconds(_direction(-direction, {"attack":true}), .12)
			await _step(_direction(direction))
			requirements = {"weapon_phase":["windup", "active", "recovery", "charge"]}
		"shield":
			await _step(_direction(-direction, {"shield":true}))
			await _seconds(_direction(direction, {"shield":true}), .24)
			await _step(_direction(-direction))
			await _until(func(): return actor.shield_phase == &"idle", _direction(direction), .5)
			requirements = {"shield_phase":["raise", "parry", "hold", "release_recovery"]}
		"driver_true", "driver_false":
			var owns := owner == "driver_true"
			var custom := func(body: Node, delta: float, _input: Dictionary) -> bool:
				if owns:
					body.velocity.x = move_toward(body.velocity.x, -direction * 170, 700 * delta)
					body.velocity.y += 400 * delta
				return owns
			_check(actor.begin_main_action(&"jump", {}, custom), "public host API installs live custom driver with eligible jump name")
			await _seconds(_direction(-direction), .12)
			_check(actor.main_action == &"jump" and actor._action_driver.is_valid(), "custom driver remains attached under eligible main action name")
			actor.finish_main_action()
		"permissions_lock":
			actor.set_weapon_permissions({"can_move":false, "can_turn":false})
			await _seconds(_direction(-direction), .18)
			_check(actor.facing == direction, "external turn denial remains authoritative")
			actor.set_weapon_permissions()
		"input_disabled":
			actor.allow_input = false
			await _seconds(_direction(-direction), .18)
			_check(actor.move_x == 0 and actor.facing == direction, "global disabled input blocks horizontal and turn intent")
			actor.allow_input = true
		"action_inputs_denied":
			_check(actor.begin_main_action(&"jump", {"uses_inputs":false}), "public host API denies input under eligible jump action name")
			await _seconds(_direction(-direction), .18)
			_check(actor.move_x == 0 and actor.facing == direction, "action input denial blocks horizontal and turn intent")
			actor.finish_main_action()
		"zero_scale":
			actor.set_weapon_permissions({"move_scale":0.0})
			await _seconds(_direction(-direction), .12)
			_check(actor.velocity.x == 0, "zero external movement scale settles at exact zero")
			actor.set_weapon_permissions()
		"crouch":
			_check(actor.begin_main_action(&"jump", {"small_hitbox":true}), "public host API requests crouched shape under eligible jump name")
			await _seconds(_direction(-direction), .12)
			_check(actor.crouched and actor.main_action == &"jump", "eligible jump name with crouched body stays excluded")
			actor.finish_main_action()
			await _step()
	_compare_owner(direction, requirements)
	# Choose opposing steering so even high launch speeds expose one full step.
	var resume_direction := -int(signf(actor.velocity.x)) if absf(actor.velocity.x) > 1 else direction
	if owner == "ledge": resume_direction = -direction
	if owner == "wall_kick": resume_direction = direction
	await _resume(resume_direction)
	_check(engine_gaps.all(func(gap): return gap == 1) and deltas.all(func(value): return absf(value - dt) < .0000001), "exactly one production call per consecutive real callback at requested delta")
	await _finish()

func _scaled_case(direction: int) -> void:
	await _begin("%s host scaled analog ordinary steering direction%d" % [variant, direction], Vector2(0, -1000))
	actor.profile = load(BASELINE_PATH).duplicate(true)
	await _start(Vector2(-direction * 120, -60))
	actor.facing = -direction
	actor.set_weapon_permissions({"move_scale":.4, "can_turn":false})
	_activate("scaled_analog")
	var key := "scaled_analog" + str(direction)
	if variant == "baseline": reference_cases[key] = initial_state.duplicate(true)
	else: _check(initial_state == reference_cases[key], "host scaled analog steering starts from identical baseline state")
	var before: Vector2 = actor.velocity
	var acceleration := 2300.0 if variant == "candidate" else 1450.0
	var target: float = direction * actor.profile.run_speed * .4 * .6
	var frame := {"right" if direction > 0 else "left":.6}
	await _step(frame)
	_near(actor.velocity.x, move_toward(before.x, target, acceleration * dt), .0001, "nonzero external scale and analog input keep the selected ordinary acceleration")
	_check(actor.facing == -direction, "external facing lock survives nonzero ordinary air steering")
	await _seconds(frame, .25)
	_near(actor.velocity.x, target, .0001, "external scale multiplies analog speed target exactly without bypass")
	measurements = {"external_move_scale":.4, "input_strength":.6, "speed_target":target, "expected_acceleration":acceleration}
	_check(engine_gaps.all(func(gap): return gap == 1) and deltas.all(func(value): return absf(value - dt) < .0000001), "exactly one production call per consecutive real callback at requested delta")
	await _finish()
