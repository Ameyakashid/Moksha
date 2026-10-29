extends "res://combat_pc/tests/combo_regression.gd"
## M10 independent held-input acceptance. Real Godot callbacks and contacts;
## original MOKSHA policy, never reference-game timing equivalence.

var input_profile_at_start: Dictionary = {}
var native_edges: Array[Dictionary] = []

func _run() -> void:
	source_paths.append_array([
		"res://project.godot", "res://scripts/sensory/noise_bus.gd",
		"res://combat_pc/tests/combo_regression.gd", "res://combat_pc/tests/shield_regression.gd",
		"res://combat_pc/tests/held_regression.gd", "res://combat_pc/resources/melee_input_profile.gd",
		"res://combat_pc/resources/held_repeat.tres", "res://combat_pc/resources/held_charge.tres",
		"res://combat_pc/resources/melee_chain.gd", "res://combat_pc/resources/melee_step.gd",
		"res://combat_pc/resources/light_chain.tres", "res://combat_pc/resources/shield_profile.gd",
		"res://combat_pc/resources/shield_profile.tres", "res://combat_pc/components/shield_contact_adapter.gd",
		"res://combat_pc/fixtures/contact_target.gd", "res://combat_pc/fixtures/contact_target.tscn",
		"res://prop.gd", "res://scenes/props/crate.tscn", "res://resources/tuning/prop_tuning.gd", "res://resources/tuning/crate_default.tres"])
	for filename in DirAccess.get_files_at("res://combat_pc/visuals"):
		if filename.ends_with(".gd"): source_paths.append("res://combat_pc/visuals/" + filename)
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	if only_group in ["", "repeat"]: await _held_repeat_cases()
	if only_group in ["", "charge"]: await _held_charge_cases()
	if only_group in ["", "boundaries"]: await _held_boundary_cases()
	if only_group in ["", "gates"]: await _held_gate_cases()
	if only_group in ["", "pause"]: await _held_pause_cases()
	if only_group in ["", "callbacks"]: await _held_callback_cases()
	if only_group in ["", "motion"]: await _held_motion_cases()
	if only_group in ["", "resources"]: await _held_resource_cases()
	if only_group in ["", "native"]: await _held_native_cases()
	if only_group in ["", "props"]: await _held_prop_cases()
	if only_group in ["", "locks"]: await _held_lock_cases()
	if only_group in ["", "integration"]: await _held_integration_cases()
	if only_group in ["", "contacts"]: await _held_contact_cases()
	if only_group in ["", "limits"]: await _held_limit_cases()
	_release_input()
	var hashes := {}; var stable := true
	for path in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Source changed during held-input run; final rerun required")
	var output := {"milestone": 10, "selected_group": only_group, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(), "generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "One production call per actual Godot physics callback. Inputs, observations, admitted contacts, target effects and adapter receipts are separate records.",
		"numeric_source": "Original MOKSHA held-repeat and starter-to-auto-charge policy; reference release/charge scheduler is not recovered.",
		"repeat_profile": _definition(load("res://combat_pc/resources/held_repeat.tres")),
		"charge_profile": _definition(load("res://combat_pc/resources/held_charge.tres"))}
	FileAccess.open("res://combat_pc/tests/held_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("MOKSHA HELD %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _held_begin(label: String, mode := "charge", at := Vector2(100, 200), floor_present := true, chained := true) -> void:
	await _combo_begin(label, at, floor_present, false, chained)
	native_edges = []
	actor.melee_input_profile = load("res://combat_pc/resources/held_%s.tres" % mode).duplicate(true) if mode in ["repeat", "charge"] else null
	if mode == "fresh":
		actor.melee_input_profile = load("res://combat_pc/resources/held_repeat.tres").duplicate(true)
		actor.melee_input_profile.mode = 0
	input_profile_at_start = _definition(actor.melee_input_profile) if actor.melee_input_profile != null else {}
	params["input_mode"] = mode

func _sample() -> Dictionary:
	var result: Dictionary = super._sample()
	for key in actor.telemetry():
		if String(key).begins_with("charge") or String(key).begins_with("repeat") or key in ["input_mode", "attack_hold_id", "attack_hold_armed", "attack_hold_released", "attack_rearm_required", "attack_request_kind", "pending_attack_request_id", "pending_attack_request_kind"]:
			result[key] = actor.telemetry()[key]
	return result

func _finish() -> void:
	var saved_profile := input_profile_at_start.duplicate(true)
	var current_profile = _definition(actor.melee_input_profile)
	var saved_edges := native_edges.duplicate(true)
	await super._finish()
	scenarios.back()["input_profile_at_start"] = saved_profile
	scenarios.back()["input_profile_at_finish"] = current_profile
	scenarios.back()["parsed_input_edges"] = saved_edges

func _enter_charge(frame: Dictionary = {}) -> bool:
	await _step(frame.merged({"attack": true}, true))
	return await _until(func(): return actor.weapon_phase == &"charge", frame.merged({"attack": true}, true), 1.0)

func _charged_starts() -> Array:
	return _event_rows("attack_started").filter(func(row): return String(row.data.get("attack_pose_id", "")) == "charged_thrust")

func _strike_hold_origins_match() -> bool:
	var origins := {}; var mismatches := []
	for row in _event_rows("attack_started"):
		origins[int(row.data.serial)] = int(row.data.hold_id)
	for row in events:
		if row.event not in ["attack_phase_changed", "attack_finished", "attack_cancelled", "strike_confirmed"]: continue
		var serial: int = row.data.get("serial", 0)
		if origins.has(serial) and int(row.data.get("hold_id", -1)) != int(origins[serial]): mismatches.append({"tick": row.tick, "event": row.event, "serial": serial, "expected": origins[serial], "actual": row.data.get("hold_id", -1)})
	for row in strike_samples:
		var serial: int = row.snapshot.serial
		if origins.has(serial) and int(row.snapshot.get("hold_id", -1)) != int(origins[serial]): mismatches.append({"tick": row.tick, "event": "strike_sample", "serial": serial, "expected": origins[serial], "actual": row.snapshot.get("hold_id", -1)})
	measurements["strike_hold_origin_mismatches"] = mismatches
	return mismatches.is_empty()

func _held_repeat_cases() -> void:
	for mode in ["null", "fresh"]:
		for chained in [false, true]:
			await _held_begin("baseline %s %s remains fresh only" % [mode, "chain" if chained else "fallback"], mode, Vector2(100, 200), true, chained)
			await _seconds({"attack": true}, 1.3)
			_check(_count("attack_started") == 1 and _count("charge_started") == 0, "one held edge remains one ordinary stroke with optional modes absent or fresh-only")
			await _step(); await _step({"attack": true})
			_check(_count("attack_started") == 2, "release and a new physical edge still admit a fresh stroke")
			await _finish()
	for chained in [false, true]:
		for direction in [-1, 1]:
			await _held_begin("held repeat %s direction%d" % ["chain" if chained else "fallback", direction], "repeat", Vector2(100, 200), true, chained)
			actor.reset_actor(actor.position, direction); await _step()
			var target := _target(Vector2(100 + direction * 45, 200)); target.size = Vector2(160, 30)
			await _sync_geometry(); await _step({"attack": true})
			var physical_id: int = _state().attack_input_id
			_check(await _until(func(): return _count("attack_started") >= 4, {"attack": true}, 2.2), "a single sustained hold connects successive ordinary strokes and a natural restart")
			await _attack_phase("active", {"attack": true}); await _step({"attack": true})
			var starts := _event_rows("attack_started"); var serials := []; var indices := []
			for row in starts: serials.append(int(row.data.serial)); indices.append(int(row.data.step_index))
			_check(int(_state().attack_input_id) == physical_id, "generated repeat requests never manufacture physical press identities")
			_check(serials.size() == 4 and serials[0] < serials[1] and serials[1] < serials[2] and serials[2] < serials[3], "each repeated stroke owns a separate increasing strike serial")
			_check(indices == ([0, 1, 2, 0] if chained else [-1, -1, -1, -1]), "repeat follows the actual chain graph or the independent fallback")
			_check(target.hits == 4, "the production target receives one actual hit from each repeated stroke")
			await _step(); await _seconds({}, .7)
			_check(_count("attack_started") == 4 and actor.weapon_phase == &"idle", "release withdraws synthetic pending work without replay after the current stroke")
			measurements["strike_serials"] = serials; measurements["step_indices"] = indices
			await _finish()
	for explicit in [false, true]:
		await _held_begin("repeat release preserves %s request" % ("explicit fresh" if explicit else "no synthetic"), "repeat")
		await _step({"attack": true})
		if explicit:
			await _step(); await _at_step_age(actor.melee_chain.steps[0].followup_open_seconds)
			await _step({"attack": true})
		else: await _until(func(): return int(_state().chain_pending_input_id) > 0, {"attack": true}, .3)
		await _step(); await _seconds({}, .8)
		_check(_count("attack_started") == (2 if explicit else 1), "release discards only held-derived intent while a captured fresh tap retains its finite request")
		if explicit: _check(_strike_hold_origins_match(), "queuing a new physical hold never rewrites the admitted hold origin of the previous strike")
		await _finish()

func _held_charge_cases() -> void:
	for direction in [-1, 1]:
		for contact in ["whiff", "target", "occluded"]:
			await _held_begin("starter charge thrust %s direction%d" % [contact, direction])
			actor.reset_actor(actor.position, direction); await _step()
			var target: Node = null
			if contact != "whiff": target = _target(Vector2(100 + direction * 34, 200))
			if contact == "occluded": _box(Vector2(100 + direction * 18, 175), Vector2(2, 100))
			await _sync_geometry()
			_check(await _enter_charge(), "the same accepted continuous hold branches from the actual starter recovery")
			_near(float(_state().charge_elapsed), 0.0, .00000001, "charge time begins at the branch instead of accumulating during the slash")
			var physical_id: int = _state().attack_input_id
			_check(await _until(func(): return _charged_starts().size() == 1, {"attack": true}, .8), "full authored charging automatically commits one separate thrust")
			await _attack_phase("idle", {"attack": true}); await _seconds({"attack": true}, .7)
			_check(_count("attack_started") == 2 and _count("charge_committed") == 1 and int(_state().attack_input_id) == physical_id, "continuous holding cannot repeat the completed charge or create another press")
			if target != null: _check(target.hits == (0 if contact == "occluded" else 2), "actual target effects require each starter and thrust contact with terrain occlusion")
			else: _check(contact_receipts.is_empty(), "a charged whiff has no fabricated physical confirmation")
			await _step(); await _step({"attack": true})
			_check(_count("attack_started") == 3, "physical release and a fresh edge rearm a distinct starter")
			measurements.merge(_trace_bounds()); await _finish()

func _held_boundary_cases() -> void:
	for edge in ["before_branch", "branch_tick", "after_branch"]:
		await _held_begin("charge release " + edge)
		await _step({"attack": true}); await _attack_phase("recovery", {"attack": true})
		var branch: float = actor.melee_input_profile.charge_branch_recovery_seconds
		var lead := 2 if edge == "before_branch" else (1 if edge == "branch_tick" else 0)
		await _until(func(): return float(_state().weapon_elapsed) + lead * dt + .000000001 >= branch, {"attack": true}, .3)
		params["pre_release_age"] = _state().weapon_elapsed; params["pre_release_phase"] = String(actor.weapon_phase)
		await _step(); await _seconds({}, .9)
		_check(_charged_starts().is_empty() and _count("attack_started") == 1, "release around branch admission never creates an extra charged strike")
		_check(actor.weapon_phase == &"idle", "early release settles in finite time")
		await _finish()
	for edge in ["before_ready", "ready_tick", "after_ready"]:
		await _held_begin("charge release " + edge)
		await _enter_charge()
		var duration: float = actor.melee_input_profile.charge_seconds
		var lead := 2 if edge == "before_ready" else (1 if edge == "ready_tick" else 0)
		await _until(func(): return float(_state().charge_elapsed) + lead * dt + .000000001 >= duration or _charged_starts().size() > 0, {"attack": true}, .8)
		params["pre_release_age"] = _state().charge_elapsed; params["pre_release_phase"] = String(actor.weapon_phase)
		await _step(); await _seconds({}, .6)
		_check(_charged_starts().size() == (1 if edge == "after_ready" else 0), "release is captured before clock advancement and wins on the readiness callback")
		_check(actor.weapon_phase == &"idle", "readiness or cancellation leaves no indefinitely live charge")
		await _finish()

func _held_gate_cases() -> void:
	for mode in ["repeat", "charge"]:
		for interruption in ["can_attack", "disable", "roll", "jump", "shield", "hurt", "forced", "reset"]:
			await _held_begin("%s hold retires on %s" % [mode, interruption], mode)
			if mode == "charge": await _enter_charge()
			else:
				await _step({"attack": true}); await _attack_phase("recovery", {"attack": true})
			var starts := _count("attack_started")
			match interruption:
				"can_attack": actor.set_weapon_permissions({"can_attack": false})
				"disable": actor.allow_input = false
				"hurt": actor.receive_hit({"amount": 1.0, "impulse": Vector2.ZERO, "hitpause": 0.0})
				"forced": actor.finish_main_action()
				"reset": actor.reset_actor(Vector2(100, 200))
				_: await _step({"attack": true, interruption: true})
			await _seconds({"attack": true}, .35)
			actor.allow_input = true; actor.set_weapon_permissions()
			await _seconds({"attack": true}, .9)
			_check(_count("attack_started") == starts and _charged_starts().is_empty(), "restoring admission cannot restart an interrupted held episode without release")
			_check(actor.weapon_phase != &"charge", "retirement leaves no hidden loading owner")
			await _step(); await _step({"attack": true})
			_check(_count("attack_started") == starts + 1, "release and a new edge restore normal admission after interruption")
			await _finish()
	for action in ["roll", "jump", "shield"]:
		await _held_begin("full charge yields to simultaneous " + action)
		await _enter_charge()
		await _until(func(): return float(_state().charge_elapsed) + dt + .000000001 >= actor.melee_input_profile.charge_seconds, {"attack": true}, .8)
		await _step({"attack": true, action: true})
		_check(_charged_starts().is_empty() and actor.weapon_phase != &"charge", "higher-priority accepted input retires readiness before a thrust can commit")
		await _seconds({"attack": true}, .6)
		_check(_charged_starts().is_empty(), "a canceled ready charge cannot escape later after the replacement ends")
		await _finish()

func _held_pause_cases() -> void:
	for release in [false, true]:
		await _held_begin("charge hitpause %s" % ("release tap" if release else "continued hold"))
		await _enter_charge(); await _seconds({"attack": true}, .1)
		var elapsed: float = _state().charge_elapsed
		var old_charge: int = _state().charge_serial
		actor.apply_hitpause(.1)
		await _step({"attack": not release}, 2)
		if not release: _near(float(_state().charge_elapsed), elapsed, .00000001, "actor-local pause advances no charge clock")
		else: await _step({"attack": true})
		await _until(func(): return actor.hitpause_remaining <= 0, {"attack": true}, .3)
		await _seconds({"attack": true}, .9)
		var old_commits := _event_rows("charge_committed").filter(func(row): return int(row.data.charge_serial) == old_charge)
		_check(old_commits.size() == (0 if release else 1), "a release captured during pause permanently invalidates only the old charge hold")
		if release: _check(_charged_starts().size() == 1 and int(_charged_starts()[0].data.charge_serial) > old_charge, "a separate fresh paused press may start its own new finite charge episode")
		await _finish()

func _held_callback_cases() -> void:
	for boundary in ["charge_started", "charge_committed"]:
		for replacement in ["reset", "hurt", "forced", "configuration"]:
			await _held_begin("%s callback replaces %s" % [boundary, replacement])
			var changed := {"done": false}
			actor.movement_event.connect(func(label, _data):
				if String(label) != boundary or changed.done: return
				changed.done = true
				if replacement == "reset": actor.reset_actor(Vector2(400, 200))
				elif replacement == "hurt": actor.receive_hit({"impulse": Vector2(-50, -80), "hitpause": .04})
				elif replacement == "forced": actor.finish_main_action()
				else:
					var previous = actor.melee_input_profile
					actor.melee_input_profile = null; actor.melee_input_profile = previous)
			await _seconds({"attack": true}, 1.4)
			_check(changed.done, "the real charge lifecycle reaches the requested callback boundary")
			var active_thrusts := strike_samples.filter(func(row): return bool(row.snapshot.eligible) and String(row.snapshot.get("attack_pose_id", "")) == "charged_thrust")
			_check(active_thrusts.is_empty(), "a superseding callback prevents any stale eligible thrust contact")
			_check(actor.weapon_phase != &"charge", "retired charge cannot resume behind its replacement")
			await _finish()

func _held_motion_cases() -> void:
	for entry in ["rising", "falling"]:
		await _held_begin("air charge preserves fall and budgets " + entry, "charge", Vector2(100, -700), false)
		await _step({"jump": true})
		if entry == "falling": await _until(func(): return actor.velocity.y > 100, {"jump": true}, .8)
		var budget: int = actor.air_jumps_left
		await _enter_charge(); var begin_tick := ticks
		await _until(func(): return _charged_starts().size() == 1, {"attack": true}, .8)
		await _attack_phase("idle", {"attack": true})
		var loading := frames.filter(func(row): return row.tick >= begin_tick and row.before.weapon_phase == "charge" and float(row.before.velocity[1]) >= 0)
		var error := 0.0
		for row in loading:
			var expected: float = minf(float(row.before.velocity[1]) + actor.profile.gravity * actor.profile.falling_gravity_multiplier * dt, actor.profile.terminal_fall_speed)
			error = maxf(error, absf(float(row.after.velocity[1]) - expected))
		_check(loading.size() > 2 and error < .002, "loading retains ordinary falling acceleration without hover or lift")
		_check(actor.air_jumps_left == budget and actor.air_roll_available and actor.dive_available and _count("landed") == 0, "charge never refills independent air resources or manufactures support")
		_check(bool(_state().fall_history_active) and float(_state().fall_distance) > 100, "starter charge and thrust retain the same free-fall excursion")
		measurements["maximum_gravity_error"] = error; await _finish()
	for direction in [-1, 1]:
		await _held_begin("charge reversal and thin wall direction%d" % direction)
		actor.reset_actor(actor.position, -direction); await _step()
		_check(await _enter_charge(), "charge begins on the original facing")
		await _step(_direction(direction, {"attack": true}))
		_check(actor.facing == direction, "permitted loading turns immediately with physical direction")
		_box(Vector2(100 + direction * 26, 170), Vector2(2, 100)); await _sync_geometry()
		await _until(func(): return _charged_starts().size() == 1, _direction(direction, {"attack": true}), .8)
		await _attack_phase("active", {"attack": true})
		await _step(_direction(-direction, {"attack": true}), 3)
		_check(actor.attack_facing == direction, "committed thrust keeps its captured direction after attempted reversal")
		var bounds := _trace_bounds(); _check(float(bounds.maximum_rectangle_depth) < .03, "the high-speed thrust remains swept against a two-pixel wall")
		measurements.merge(bounds); await _finish()

func _held_resource_cases() -> void:
	for phase in ["pending", "loading", "active"]:
		await _held_begin("input configuration round trip retires " + phase)
		if phase == "pending":
			actor.set_weapon_permissions({"can_attack": false}); await _step({"attack": true})
		else:
			await _enter_charge()
			if phase == "active": await _until(func(): return _charged_starts().size() == 1, {"attack": true}, .8); await _attack_phase("active", {"attack": true})
		var old_profile = actor.melee_input_profile
		var old_serial: int = actor.attack_serial
		actor.melee_input_profile = null; actor.melee_input_profile = old_profile
		_check(not actor.is_strike_current(old_serial), "changed-and-restored input configuration invalidates old contact authority immediately")
		var starts := _count("attack_started")
		actor.set_weapon_permissions(); await _seconds({"attack": true}, 1.0)
		_check(_count("attack_started") == starts and actor.weapon_phase == &"idle", "configuration replacement cannot resurrect the prior held or buffered episode")
		await _finish()
	for stage in ["too_early", "queue_full"]:
		await _held_begin("live repeat snapshot survives rejected edge " + stage, "repeat")
		await _step({"attack": true})
		if stage == "queue_full": await _until(func(): return int(_state().chain_pending_input_id) > 0, {"attack": true}, .3)
		actor.melee_input_profile.mode = 2
		actor.melee_input_profile.charge_seconds = .001
		await _step({"attack": true, "attack_pressed": true})
		_check(String(_state().input_mode) == "held_repeat" and _count("charge_started") == 0, "a rejected physical edge cannot replace the live episode policy with an in-place edit")
		await _seconds({"attack": true}, .5)
		_check(_count("charge_started") == 0 and _charged_starts().is_empty(), "the old repeat episode never changes into charging behind its accepted stroke")
		await _finish()
	for mutate in [false, true]:
		await _held_begin("charge resource snapshot %s" % ("in-place edit" if mutate else "same-value assignment"))
		await _enter_charge()
		var old_duration: float = _state().charge_duration
		if mutate:
			actor.melee_input_profile.charge_seconds = .001
			actor.melee_input_profile.charge_strike.damage = 99.0
		else: actor.melee_input_profile = actor.melee_input_profile
		await _seconds({"attack": true}, old_duration * .5)
		_check(actor.weapon_phase == &"charge" and _charged_starts().is_empty(), "live charging retains its accepted configuration and does not restart or shorten")
		await _until(func(): return _charged_starts().size() > 0, {"attack": true}, .5)
		await _attack_phase("active", {"attack": true})
		_near(float(actor.strike_snapshot().damage), float(input_profile_at_start.charge_strike.damage), .000001, "committed thrust uses its episode snapshot rather than edited shared values")
		await _finish()
	await _held_begin("two actors share input configuration without runtime cross-talk")
	var shared = actor.melee_input_profile
	var baseline = _definition(shared)
	var second = PLAYER.instantiate()
	second.automatic_physics = false; second.position = Vector2(600, 200)
	second.melee_input_profile = shared; second.melee_chain = actor.melee_chain
	world.add_child(second); await _sync_geometry(); second.reset_actor(Vector2(600, 200))
	var second_samples := []; var second_input := {"attack": false}
	before_tick = func(delta):
		var before = second.telemetry()
		second.physics_tick(delta, second_input)
		second_samples.append({"engine_tick": Engine.get_physics_frames(), "before": _safe(before), "after": _safe(second.telemetry())})
	await _enter_charge()
	_check(second.weapon_phase == &"idle" and second.attack_serial == 0, "charging one actor cannot admit a shared-resource peer")
	second_input.attack = true
	await _seconds({"attack": true}, .9)
	_check(_charged_starts().size() == 1 and second.attack_serial == 2, "both real actors independently complete their own starter and thrust")
	_check(_definition(shared) == baseline, "runtime holds charge clocks and identities never write into a shared Resource")
	measurements["second_actor_samples"] = second_samples
	before_tick = Callable(); await _finish()
	await _held_begin("finished held melee configuration change preserves independent shield", "repeat")
	await _step({"attack": true}); await _seconds({}, .8)
	await _seconds({"shield": true}, .35)
	_check(actor.shield_phase == &"hold" and actor.weapon_phase == &"idle", "the fixture reaches a real held shield after melee and its retention have finished")
	var shield_id: int = actor.shield_serial
	actor.melee_input_profile = load("res://combat_pc/resources/held_charge.tres")
	await _step({"shield": true}, 2)
	_check(actor.shield_phase == &"hold" and actor.shield_serial == shield_id, "an unused stale melee snapshot cannot retire independent shield ownership")
	await _finish()
	await _held_begin("fresh-only strike has no inherited held origin", "repeat")
	await _step({"attack": true}); await _seconds({}, .8)
	var old_hold: int = _state().attack_hold_id
	actor.melee_input_profile = null; await _step(); await _step({"attack": true})
	await _attack_phase("active")
	_check(old_hold > 0 and int(_event_rows("attack_started").back().data.hold_id) == 0, "fresh-only admission does not borrow a remembered optional-mode hold identity")
	_check(int(actor.strike_snapshot().hold_id) == 0, "the fresh-only contact snapshot retains the explicit no-held-origin identity")
	await _finish()

func _native_attack(down: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = KEY_J; event.pressed = down
	native_edges.append({"before_engine_tick": Engine.get_physics_frames(), "next_case_tick": ticks + 1, "key": "J", "pressed": down})
	Input.parse_input_event(event)

func _held_native_cases() -> void:
	for mode in ["repeat", "charge"]:
		await _held_begin("parsed held input release during pause " + mode, mode)
		_native_attack(true); await _step(null)
		if mode == "charge": await _until(func(): return actor.weapon_phase == &"charge", null, 1)
		else: await _until(func(): return int(_state().chain_pending_input_id) > 0, null, .3)
		actor.apply_hitpause(.10); var count_before := _count("attack_started")
		var old_charge: int = _state().charge_serial
		_native_attack(false); await _step(null)
		_native_attack(true); await _step(null)
		await _seconds(null, 1.0)
		var old_commits := _event_rows("charge_committed").filter(func(row): return int(row.data.charge_serial) == old_charge)
		_check(old_commits.is_empty(), "a parsed release invalidates the old charge even when a new press occurs during pause")
		if mode == "charge": _check(_count("attack_started") == count_before + 2 and _charged_starts().size() == 1 and int(_charged_starts()[0].data.charge_serial) > old_charge, "the fresh paused press creates one new starter and thrust with a distinct charge identity")
		_check(native_edges.size() == 3, "the trace retains actual parsed event order separately from the sampled held state")
		if mode == "repeat": _check(_strike_hold_origins_match(), "a parsed new hold during pause cannot relabel the old strike events or contact samples")
		_native_attack(false); await _step(null); await _finish()
	await _held_begin("same-callback release repress cannot preserve charge hold")
	_native_attack(true); await _step(null)
	await _until(func(): return actor.weapon_phase == &"charge", null, 1)
	actor.apply_hitpause(.05)
	_native_attack(false); _native_attack(true); await _step(null)
	await _seconds(null, 1.0)
	_check(_count("charge_cancelled") >= 1 and _charged_starts().is_empty(), "release edge wins even when the final sampled state is held again in the same callback")
	_native_attack(false); await _step(null); await _finish()

func _held_prop_cases() -> void:
	for direction in [-1, 1]:
		await _held_begin("real charged thrust crate and noise direction%d" % direction)
		actor.reset_actor(actor.position, direction); await _step(); await _enter_charge()
		var crate = load("res://scenes/props/crate.tscn").instantiate()
		crate.tuning = crate.tuning.duplicate(true); crate.tuning.launch_spin_range = Vector2.ZERO
		crate.position = actor.position + Vector2(direction * 31, -14); world.add_child(crate)
		var launch := {"count": 0, "position": Vector2.ZERO}
		crate.launched.connect(func(prop): launch.count += 1; launch.position = prop.global_position)
		var bus = root.get_node("NoiseBus"); bus.clear_history()
		await _sync_geometry(); await _until(func(): return launch.count > 0, {"attack": true}, 1.0)
		_check(launch.count == 1 and crate.hit_count == 1 and crate.charge > 0, "the real RigidBody crate receives exactly one confirmed charged launch")
		await _step({"attack": true}, 2)
		var expected_speed: float = crate.tuning.launch_speed * actor.melee_input_profile.charge_strike.prop_launch_scale
		_check(crate.linear_velocity.x * direction > expected_speed * .5 and (crate.position.x - Vector2(launch.position).x) * direction > 0, "the charged profile produces actual outward rigid-body momentum")
		var found := false
		for event in bus.event_history:
			if event.kind == &"prop_launch" and Vector2(event.origin).distance_to(Vector2(launch.position)) < .01: found = true
		_check(found, "launch noise originates at the actual physical crate")
		measurements["launch_position"] = launch.position; measurements["body_velocity"] = crate.linear_velocity; measurements["expected_launch_speed"] = expected_speed
		measurements["prop_launch_events"] = _safe(bus.event_history.filter(func(event): return event.kind == &"prop_launch"))
		measurements["body_position"] = crate.global_position; measurements["launch_count"] = launch.count
		measurements["hit_count"] = crate.hit_count; measurements["charge"] = crate.charge
		measurements["tuning_launch_speed"] = crate.tuning.launch_speed
		await _finish()

func _held_lock_cases() -> void:
	for mode in ["repeat", "charge"]:
		for overlap in ["simultaneous", "nonholdable_shield"]:
			await _held_begin("%s input versus %s" % [mode, overlap], mode)
			if overlap == "nonholdable_shield":
				actor.shield_profile.can_be_held = false
				await _step({"shield": true}); await _step({"shield": true, "attack": true})
			else: await _step({"shield": true, "attack": true})
			_check(actor.shield_phase != &"idle" and actor.weapon_phase == &"idle", "shield owns admission when the new held mode competes with an eligible shield")
			await _seconds({"shield": true, "attack": true}, .9)
			_check(_count("attack_started") == 0 and _count("charge_started") == 0, "an admitted shield prevents parallel loading and no stale held attack escapes its recovery")
			await _finish()
	for mode in ["repeat", "charge"]:
		for unlock in ["before_deadline", "after_deadline"]:
			await _held_begin("initial denied %s press %s" % [mode, unlock], mode)
			actor.set_weapon_permissions({"can_attack": false}); await _step({"attack": true})
			await _seconds({"attack": true}, actor.combat_profile.attack_buffer_seconds * (.5 if unlock == "before_deadline" else 1.5))
			actor.set_weapon_permissions(); await _seconds({"attack": true}, 1.0)
			_check((_count("attack_started") > 0) == (unlock == "before_deadline"), "an initially denied fresh edge uses its finite ordinary deadline without held retries")
			if unlock == "after_deadline":
				await _step(); await _step({"attack": true})
				_check(_count("attack_started") == 1, "an expired hold is usable only after neutral and a new press")
			await _finish()
	await _held_begin("repeat pending expiry cannot retry after longer reuse lock", "repeat")
	actor.melee_chain.steps[0].reuse_lock_seconds = .8
	await _seconds({"attack": true}, 1.3)
	_check(_count("attack_started") == 1 and not bool(_state().attack_hold_armed), "an expired repeat request disarms the episode rather than retrying when the independent lock expires")
	_check(_count("chain_input_expired") == 1, "the single synthetic request expires once without a refreshed backlog")
	await _finish()
	await _held_begin("starter reuse lock closes charge branch without backlog")
	actor.melee_input_profile.charge_starter.reuse_lock_seconds = .8
	await _seconds({"attack": true}, 1.3)
	_check(_count("attack_started") == 1 and _count("charge_started") == 0, "a missed finite starter branch cannot start charging after its reuse lock opens")
	_check(actor.weapon_phase == &"idle", "a denied branch cannot keep the starter alive indefinitely")
	await _finish()
	await _held_begin("shield lock rejects held starter without parallel loading")
	actor.shield_profile.use_lock_seconds = .6
	await _seconds({"shield": true}, .2)
	await _step({"attack": true, "shield": true}); await _seconds({"attack": true}, .9)
	_check(_count("attack_started") == 0 and _count("charge_started") == 0, "held attack cannot erase shield ownership or survive its longer use lock")
	await _step(); await _step({"attack": true})
	_check(_count("attack_started") == 1, "the independent shield lock eventually expires without poisoning later fresh input")
	await _finish()
	await _held_begin("charge live movement and turning permissions intersect")
	await _enter_charge()
	actor.set_weapon_permissions({"can_move": false, "can_turn": true, "move_scale": .5})
	var at: Vector2 = actor.position
	await _step({"attack": true, "left": 1.0}, 3)
	_check(actor.facing == -1 and actor.position.distance_to(at) < .03, "charge permits independent turning while denied movement remains stationary")
	_near(float(actor.weapon_permissions.move_scale), .5 * actor.melee_input_profile.charge_move_scale, .000001, "charge movement scale composes with the external scale")
	actor.set_weapon_permissions({"can_turn": false}); await _step({"attack": true, "right": 1.0})
	_check(actor.facing == -1 and actor.weapon_phase == &"charge", "turn denial preserves loading and its previously permitted facing")
	await _finish()

func _held_integration_cases() -> void:
	for gradient in [-1.0, 1.0]:
		await _held_begin("charge and thrust stay supported on slope %.1f" % gradient, "charge", Vector2(100, 50), false)
		_terrain([Vector2(-400, 200 - gradient * 500), Vector2(1000, 200 + gradient * 900)])
		await _sync_geometry(); await _until(func(): return actor.grounded, {}, 1.0)
		_check(actor.grounded, "the physical slope supplies the initial support")
		var start_tick := ticks
		await _enter_charge(); await _until(func(): return _charged_starts().size() == 1, {"attack": true}, .8)
		await _attack_phase("idle", {"attack": true})
		var supported := frames.filter(func(row): return row.tick > start_tick)
		_check(supported.all(func(row): return row.after.grounded), "starter loading and thrust follow a continuous slope without fabricated landing or support loss")
		_check(supported.all(func(row): return row.after.terrain_clearance_normal == null or float(row.after.terrain_clearance_normal) >= -.03), "the collision rectangle stays outside the actual sloped plane")
		measurements.merge(_trace_bounds()); await _finish()
	await _held_begin("complete charge remains crouched under real low roof")
	await _step({"down": 1.0}); _box(actor.position + Vector2(0, -26.3), Vector2(300, 12)); await _sync_geometry()
	await _enter_charge(); await _until(func(): return _charged_starts().size() == 1, {"attack": true}, .8)
	await _attack_phase("idle", {"attack": true})
	_check(actor.crouched and actor.body_height == actor.profile.crouching_height, "charging and execution never expand through blocked headroom")
	var bounds := _trace_bounds(); _check(float(bounds.maximum_rectangle_depth) <= .03, "the swept small body remains outside the low ceiling")
	measurements.merge(bounds); await _finish()
	for hard in [false, true]:
		await _held_begin("charge landing %s retires or preserves owner" % ("hard" if hard else "soft"), "charge", Vector2(100, 0), false)
		_box(Vector2(0, 420), Vector2(2400, 40)); await _sync_geometry()
		actor.reset_actor(Vector2(100, 0)); actor.velocity.y = 300; actor.enable_hard_landing = hard
		await _enter_charge(); var serial: int = _state().charge_serial
		await _until(func(): return actor.grounded, {"attack": true}, 1.2)
		_check(_count("landed") == 1, "the airborne episode reaches one actual floor contact")
		if hard: _check(actor.main_action == &"hard_land" and actor.weapon_phase == &"idle", "qualifying hard landing immediately retires charge and held authority")
		else: _check(actor.weapon_phase == &"charge" and int(_state().charge_serial) == serial, "ordinary soft landing preserves the separate charge owner")
		await _seconds({"attack": true}, .9)
		_check(_charged_starts().size() == (0 if hard else 1), "landing cancellation cannot leak a later thrust while permitted soft landing can complete")
		await _finish()
	for removed in [false, true]:
		await _held_begin("paused charging carrier %s" % ("removed" if removed else "moving"), "charge", Vector2(100, 200), false)
		var carrier := _box(Vector2(100, 220), Vector2(400, 40), false, true)
		await _sync_geometry(); await _until(func(): return actor.grounded)
		await _enter_charge(); actor.apply_hitpause(.10)
		var age: float = _state().charge_elapsed; var at: Vector2 = actor.position
		if removed: carrier.queue_free()
		else: before_tick = func(delta): carrier.position += Vector2(50, -20) * delta
		await _step({"attack": true}, 4)
		_near(float(_state().charge_elapsed), age, .00000001, "carrier lifecycle during pause never advances the charge clock")
		if not removed: _check(actor.position.x > at.x and actor.position.y < at.y, "paused charge follows actual moving support through swept transport")
		await _until(func(): return actor.hitpause_remaining <= 0, {"attack": true}, .3); await _step({"attack": true}, 3)
		if removed: _check(not actor.grounded and actor.velocity.y > 0, "removed support resumes ordinary gravity without phantom grounding")
		else: _check(actor.grounded, "moving support remains genuine after pause")
		before_tick = Callable(); measurements.merge(_trace_bounds()); await _finish()
	for action in ["air_jump", "dive", "climb", "wall"]:
		await _held_begin("loading charge yields to physical " + action, "charge", Vector2(100, 200), action == "climb")
		if action == "climb":
			var sensor = CLIMBABLE.instantiate(); sensor.position = Vector2(100, 450); sensor.height = 600; sensor.width = 100; world.add_child(sensor)
		if action == "wall":
			actor.allow_wall_run = true; _box(Vector2(118, 500), Vector2(20, 3000))
		await _sync_geometry(); await _enter_charge()
		var frame := {"attack": true}
		if action == "air_jump": frame.jump = true
		elif action == "dive": frame.down = 1.0; frame.jump = true
		elif action == "climb": frame.up = 1.0
		else: frame.right = 1.0
		await _step(frame)
		_check(String(actor.main_action) == action and actor.weapon_phase == &"idle", "the admitted traversal replacement retires loading through its actual geometry and budget gates")
		await _seconds(frame, .6)
		_check(_charged_starts().is_empty(), "held attack cannot resume the replaced charge during later traversal callbacks")
		await _finish()

func _held_contact_cases() -> void:
	for trigger in ["strike_confirmed", "hitpause_started", "receiver", "contact_confirmed"]:
		await _held_begin("charged physical callback reset at " + trigger)
		await _enter_charge()
		var first := _target(actor.position + Vector2(28, 0), "First")
		var second := _target(actor.position + Vector2(36, 0), "Second")
		await _sync_geometry()
		var seen := {"count": 0, "serial": 0}
		var replace := func():
			if seen.count > 0: return
			seen.count = 1; seen.serial = actor.attack_serial
			actor.reset_actor(Vector2(400, 200))
		if trigger == "receiver":
			first.struck.connect(func(_payload): replace.call()); second.struck.connect(func(_payload): replace.call())
		elif trigger == "contact_confirmed": actor.get_node("ContactAdapter").contact_confirmed.connect(func(_a, _b, _p, _s, _k): replace.call())
		else: actor.movement_event.connect(func(label, _data):
			if String(label) == trigger: replace.call())
		await _until(func(): return seen.count > 0, {"attack": true}, 1.0); await _step({"attack": true}, 4)
		_check(seen.count == 1, "the actual charged contact reaches its intended callback")
		_check(first.hits + second.hits == (1 if trigger in ["receiver", "contact_confirmed"] else 0), "already applied contact survives its callback but stale remaining target effects stop")
		_check(actor.weapon_phase == &"idle" and not actor.confirm_strike(int(seen.serial), 333333, actor.position), "reset withdraws old charged strike authority and holding cannot replay it")
		await _finish()
	await _held_begin("charged strike confirms two actual targets once each")
	await _enter_charge()
	var first := _target(actor.position + Vector2(28, 0), "First")
	var second := _target(actor.position + Vector2(36, 0), "Second")
	await _sync_geometry(); await _until(func(): return first.hits + second.hits == 2, {"attack": true}, 1.0)
	await _attack_phase("idle", {"attack": true})
	_check(first.hits == 1 and second.hits == 1 and contact_receipts.size() == 2, "the charged active interval applies one effect per real target")
	_check(_count("hitpause_started") == 1 and int(contact_receipts[0].engine_tick) == int(contact_receipts[1].engine_tick), "two targets share one admitted sample and one charged contact-pause budget")
	await _finish()

func _held_limit_cases() -> void:
	for short in ["starter", "thrust", "both_with_pause"]:
		await _held_begin("minimum valid phase retains charge opportunity " + short)
		var profile_ = actor.melee_input_profile
		if short != "thrust":
			profile_.charge_starter.windup_seconds = .001; profile_.charge_starter.active_seconds = .001; profile_.charge_starter.recovery_seconds = .001
			profile_.charge_branch_recovery_seconds = .0005
		if short != "starter":
			profile_.charge_strike.windup_seconds = .001; profile_.charge_strike.active_seconds = .001; profile_.charge_strike.recovery_seconds = .001
			profile_.charge_strike.recovery_cancel_after = 0.0
		profile_.charge_seconds = .001
		input_profile_at_start = _definition(profile_)
		var target := _target(Vector2(130, 200)); await _sync_geometry()
		var pause_once := {"done": false}
		if short == "both_with_pause": actor.movement_event.connect(func(label, _data):
			if label == &"charge_started" and not pause_once.done:
				pause_once.done = true; actor.apply_hitpause(.04))
		await _seconds({"attack": true}, .8)
		_check(_count("charge_started") == 1 and _charged_starts().size() == 1, "accepted minimum timings retain one finite branch and one charged execution across a larger callback delta")
		_check(target.hits == 2, "starter and thrust each receive a separate real active contact opportunity")
		_check(actor.weapon_phase == &"idle" and _count("attack_started") == 2, "minimum phases finish without skipping contacts or looping the held episode")
		await _finish()
	for invalid in ["zero_charge", "nonfinite_charge", "branch_after_completion", "missing_strike", "zero_repeat_restart"]:
		await _held_begin("invalid held configuration refuses " + invalid, "repeat" if invalid == "zero_repeat_restart" else "charge")
		match invalid:
			"zero_charge": actor.melee_input_profile.charge_seconds = 0.0
			"nonfinite_charge": actor.melee_input_profile.charge_seconds = INF
			"branch_after_completion": actor.melee_input_profile.charge_branch_recovery_seconds = actor.melee_input_profile.charge_starter.recovery_seconds
			"missing_strike": actor.melee_input_profile.charge_strike = null
			"zero_repeat_restart": actor.melee_input_profile.repeat_restart_seconds = 0.0
		await _seconds({"attack": true}, .8)
		_check(_count("attack_started") == 0 and _count("charge_started") == 0 and actor.weapon_phase == &"idle", "invalid configuration refuses entry without a partial owner or silent fallback")
		await _finish()
	for phase in ["starter", "loading", "thrust"]:
		await _held_begin("fresh presses during busy charge episode " + phase)
		await _step({"attack": true})
		if phase != "starter": await _until(func(): return actor.weapon_phase == &"charge", {"attack": true}, 1.0)
		if phase == "thrust": await _until(func(): return _charged_starts().size() == 1, {"attack": true}, .8)
		var old_hold: int = _state().attack_hold_id
		await _step({"attack": true, "attack_pressed": true})
		_check(int(_state().attack_hold_id) == old_hold, "a rejected busy press cannot replace the original held identity")
		await _seconds({"attack": true}, 1.2)
		_check(_count("attack_started") == 2 and _count("charge_committed") == 1, "busy fresh presses create no hidden next-charge backlog")
		await _finish()
	for action in ["roll", "jump", "shield"]:
		await _held_begin("denied readiness replacement preserves charge " + action)
		await _enter_charge()
		actor.set_weapon_permissions({"can_" + action: false})
		await _until(func(): return float(_state().charge_elapsed) + dt + .000000001 >= actor.melee_input_profile.charge_seconds, {"attack": true}, .8)
		await _step({"attack": true, action: true})
		_check(_charged_starts().size() == 1 and actor.weapon_phase == &"windup", "a denied higher-priority request does not erase an otherwise eligible charged commit")
		await _finish()
	await _held_begin("charging one-way support yields to targeted drop", "charge", Vector2(100, 200), false)
	_box(Vector2(100, 204), Vector2(500, 8), true); await _sync_geometry(); await _until(func(): return actor.grounded)
	await _enter_charge(); await _step({"attack": true, "down": 1.0, "jump": true})
	_check(actor.main_action == &"drop" and bool(_state().drop_exception_active) and actor.weapon_phase == &"idle", "actual one-way drop interrupts loading while retaining target-only cleanup")
	await _seconds({"attack": true}, .8)
	_check(_charged_starts().is_empty() and not bool(_state().drop_exception_active), "cleanup clears physically and held attack cannot revive the interrupted charge")
	await _finish()
	await _held_begin("same actor alternates held modes through reset without stale authority")
	var serials := []; var holds := []
	for cycle in range(4):
		actor.melee_input_profile = load("res://combat_pc/resources/held_%s.tres" % ("charge" if cycle % 2 == 0 else "repeat")).duplicate(true)
		actor.reset_actor(Vector2(100, 200), 1 if cycle % 2 == 0 else -1)
		await _step(); await _step({"attack": true})
		serials.append(actor.attack_serial); holds.append(int(_state().attack_hold_id))
		await _seconds({"attack": true}, .1)
		var starts := _count("attack_started")
		actor.reset_actor(Vector2(100, 200)); await _seconds({"attack": true}, .5)
		_check(_count("attack_started") == starts and actor.weapon_phase == &"idle", "reset refuses the previous physical hold over subsequent callbacks")
	var monotonic := true
	for i in range(1, serials.size()): monotonic = monotonic and serials[i] > serials[i - 1] and holds[i] > holds[i - 1]
	_check(monotonic, "same-instance mode reuse never recycles accepted strike or hold identities")
	measurements["cycle_serials"] = serials; measurements["cycle_hold_ids"] = holds
	await _finish()
