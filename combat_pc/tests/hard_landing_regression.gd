extends "res://combat_pc/tests/wall_regression.gd"
## M6 actual-physics hard-landing acceptance for authored MOKSHA policy.
## No Dead Cells threshold, recovery timing or fall-history algorithm is recovered.

func _run() -> void:
	production_paths.append_array([
		"res://combat_pc/tests/combat_regression.gd", "res://combat_pc/tests/traversal_regression.gd",
		"res://combat_pc/tests/climb_regression.gd", "res://combat_pc/tests/wall_regression.gd",
		"res://combat_pc/tests/hard_landing_regression.gd",
		"res://combat_pc/components/climbable.gd", "res://combat_pc/components/climbable.tscn"
	])
	for path in production_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _hard_landing_cases()
	_release_native_input()
	var hashes := {}
	for path in production_paths: hashes[path] = FileAccess.get_sha256(path)
	var stable := true
	for path in starting_hashes: stable = stable and starting_hashes[path] == hashes[path]
	if not stable: failures.append("Source changed during hard-landing run; final rerun required")
	var report := {
		"milestone": 6, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(),
		"generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "Actual Godot physics, per-physics post-actor samples, production sweeps, native key edges and independent shape/relative-motion observations",
		"numeric_source": "Authored MOKSHA hard-landing tuning. Source evidence supports the high-fall/stun distinction and live-stomp-to-roll exception only.",
		"movement_profile": _resource_values(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _resource_values(load("res://combat_pc/resources/combat_profile.tres"))
	}
	FileAccess.open("res://combat_pc/tests/hard_landing_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  "))
	print("MOKSHA HARD LANDING %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _hard_landing_cases() -> void:
	await _hard_basics_and_thresholds()
	await _hard_contexts_and_excursions()
	await _hard_native_queues()
	await _hard_dive_roll_protection()
	await _hard_phase_permissions_and_lifecycle()
	await _hard_moving_floor_and_pause()
	await _hard_boundary_input_and_geometry()
	await _hard_carrier_review_probes()
	await _hard_slopes_and_connected_reuse()
	await _hard_final_context_edges()
	await _hard_release_excursion_edges()
	await _hard_synchronous_host_callbacks()
	await _hard_old_owner_signal_handoff()

func _begin(label: String, at := Vector2(100, 200), floor_present := true) -> void:
	await super._begin(label, at, floor_present)
	actor.noise_requested.connect(func(at_: Vector2, kind: StringName, loudness: float, _source: Node):
		events.append({"event": "noise:" + String(kind), "tick": driver.ticks + (1 if Engine.is_in_physics_frame() else 0), "data": {"position": _safe(at_), "loudness": loudness}}))

func _landing_floor(top: float, left := -1000.0, width := 3000.0, one_way := false) -> Node2D:
	var floor = _surface(Vector2(left, top), Vector2(width, 30), one_way)
	tracked_bodies.append(floor)
	return floor

func _fall_fixture(label: String, distance := -1.0, initial_speed := 0.0, tuning: Dictionary = {}) -> Node2D:
	await _begin(label, Vector2(100, 256), false)
	actor.enable_hard_landing = true
	for key in tuning: actor.profile.set(key, tuning[key])
	if distance < 0: distance = actor.profile.hard_land_min_distance + 100.0
	var floor = _landing_floor(256 + distance + actor.profile.collision_margin)
	actor.reset_actor(Vector2(100, 256), 1)
	actor.velocity.y = initial_speed
	measurements["initial_foot_y"] = 256.0
	measurements["floor_plane_y"] = floor.position.y
	measurements["nominal_drop_distance"] = distance
	return floor

func _await_landing(frame: Variant = {}, timeout := 3.0) -> bool:
	return await _until(func(): return _count("landed") > 0, frame, timeout)

func _hard_phase() -> String:
	return String(actor.telemetry().get("hard_land_phase", ""))

func _last_event(label: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		if events[index].event == label: return events[index]
	return {}

func _hard_basics_and_thresholds() -> void:
	var default_profile = load("res://combat_pc/resources/movement_profile.tres")
	var distance_limit: float = default_profile.hard_land_min_distance
	var speed_limit: float = default_profile.hard_land_min_relative_speed
	await _begin("hard landing stays optional by default", Vector2(100, 256), false)
	_landing_floor(656)
	_check(not actor.enable_hard_landing, "reusable actor defaults to the prior landing behavior")
	await _await_landing()
	_check(_count("landed") == 1 and _count("hard_land_started") == 0, "disabled hard landing preserves one ordinary physical touchdown")
	await _finish()
	await _fall_fixture("ordinary high fall impact recovery and restored control")
	await _await_landing()
	_check(actor.main_action == &"hard_land" and _hard_phase() == "impact" and actor.crouched, "qualifying actual floor contact starts the short impact with its small collision body")
	_check(_count("landed") == 1 and _count("hard_land_started") == 1 and _count("dive_impact") == 0, "ordinary hard fall dispatches one landing and one hard recovery without a dive impact")
	_check(_count("noise:hard_land") == 1 and _count("noise:land") == 0 and _count("noise:dive_impact") == 0, "ordinary hard impact emits one dominant landing noise")
	var landed_tick: int = driver.ticks
	var seen: Array = [_hard_phase()]
	while actor.main_action == &"hard_land" and driver.ticks - landed_tick < hz:
		await _step({"right": 1.0})
		if not seen.has(_hard_phase()): seen.append(_hard_phase())
	measurements["hard_land_seconds"] = (driver.ticks - landed_tick) * dt
	_check(seen.has("recovery") and actor.main_action != &"hard_land", "bounded impact then recovery releases control without an animation-owned lock")
	_check(_count("landed") == 1 and _count("hard_land_started") == 1 and _count("hard_land_finished") == 1, "persistent floor contact cannot restart landing or recovery")
	await _step({"right": 1.0, "jump": true})
	_check(actor.velocity.y < 0 and _count("ground_jump") == 1, "fresh input uses genuine ground support after recovery")
	_check(not _trace_has_solid_overlap(), "complete high-fall and recovery path remains outside the floor")
	await _finish()
	for offset in [-.25, 0.0, .25]:
		await _fall_fixture("hard landing distance boundary %.2f" % offset, distance_limit + offset, speed_limit + 100)
		await _await_landing()
		var observed: float = actor.global_position.y - float(measurements.initial_foot_y)
		var expected: bool = observed + .000000001 >= actor.profile.hard_land_min_distance
		measurements["observed_contact_travel"] = observed
		_check(absf(observed - (distance_limit + offset)) < .03, "actual floor/margin fixture realizes the requested distance boundary")
		_check((_count("hard_land_started") == 1) == expected, "height threshold is applied to actual swept root excursion at contact")
		if expected: _near(float(actor.telemetry().hard_land_fall_distance), observed, .03, "hard impact records final swept distance before resetting fall history")
		await _finish()
	for speed in [speed_limit - 1.0, speed_limit, speed_limit + 1.0]:
		await _fall_fixture("hard landing speed boundary %.0f" % speed, distance_limit + 100, speed, {"terminal_fall_speed": speed})
		await _await_landing()
		_check((_count("hard_land_started") == 1) == (speed >= actor.profile.hard_land_min_relative_speed), "relative downward speed threshold is inclusive and independent of sufficient fall distance")
		if speed >= actor.profile.hard_land_min_relative_speed: _near(float(actor.telemetry().hard_land_relative_impact_speed), speed, .01, "recorded static-floor impact speed equals the controlled live velocity cap")
		await _finish()
	await _fall_fixture("short fast impact does not meet both thresholds", distance_limit * .25, speed_limit * 1.6)
	await _await_landing()
	_check(_count("hard_land_started") == 0 and actor.grounded, "high speed without sufficient excursion remains a soft landing")
	await _finish()
	await _fall_fixture("long slow fall does not meet both thresholds", distance_limit + 100, 0, {"terminal_fall_speed": speed_limit * .6})
	await _await_landing()
	_check(_count("hard_land_started") == 0 and actor.grounded, "sufficient height without sufficient relative speed remains a soft landing")
	await _finish()

func _hard_contexts_and_excursions() -> void:
	for context in ["ordinary_roll", "weapon_windup", "weapon_active", "weapon_recovery", "hurt"]:
		await _fall_fixture("qualifying contact during " + context, 420, 600, {"terminal_fall_speed": 600.0})
		var time_left := .08
		if context == "weapon_windup": time_left = actor.combat_profile.attack_windup_seconds * .5
		elif context == "weapon_active": time_left = actor.combat_profile.attack_windup_seconds + actor.combat_profile.attack_active_seconds * .5
		elif context == "weapon_recovery": time_left = actor.combat_profile.attack_windup_seconds + actor.combat_profile.attack_active_seconds + actor.combat_profile.attack_recovery_seconds * .5
		await _until(func(): return float(measurements.floor_plane_y) - actor.global_position.y < 600 * time_left, {}, 2)
		if context == "ordinary_roll": await _step({"roll": true})
		elif context.begins_with("weapon_"): await _step({"attack": true})
		else: actor.receive_hit({"rollable": false, "impulse": Vector2(100, 600), "hitpause": 0.0, "stun_seconds": 1.0})
		var serial: int = actor.attack_serial
		await _await_landing()
		var landing_tick: int = driver.ticks
		_check(actor.main_action == &"hard_land" and _count("hard_land_started") == 1, "qualifying physical impact owns recovery over the previous movement or weapon owner")
		if context.begins_with("weapon_"):
			var prior_phase = context.trim_prefix("weapon_")
			var observed_phase: String = String(_last_event("attack_cancelled").get("data", {}).get("phase", ""))
			_check(observed_phase == prior_phase, "fixture reaches actual floor from the requested live weapon phase")
			_check(actor.weapon_phase == &"idle" and not actor.confirm_strike(serial, 99001, actor.global_position), "hard impact retires the live swing and rejects stale contact confirmation")
			_check(not strikes.any(func(sample): return int(sample.tick) >= landing_tick), "cancelled weapon emits no strike sample after qualifying landing dispatch")
		elif context == "ordinary_roll": _check(not bool(actor.telemetry().roll_fall_protected), "ordinary air roll has no active-dive fall protection")
		_check(float(actor.telemetry().hard_land_fall_distance) >= actor.profile.hard_land_min_distance, "roll weapon and hurt ownership cannot erase the current fall excursion")
		await _finish()
	for accepted in [true, false]:
		await _fall_fixture("late air jump resets fall only when " + ("accepted" if accepted else "denied"), 420)
		await _until(func(): return actor.global_position.y > 256 + 340, {}, 2)
		if not accepted: actor.air_jumps_left = 0
		await _step({"jump": true})
		await _await_landing({"jump": true})
		_check((_count("air_jump") == 1) == accepted, "fixture distinguishes a genuine accepted air jump from a buffered request")
		_check((_count("hard_land_started") == 0) == accepted, "only a genuine new jump resets the previous excursion; a denied request retains its high fall")
		await _finish()
	for grip in ["ladder", "wall", "ledge"]:
		await _fall_fixture("accepted " + grip + " grip resets fall excursion", 620, 450, {"terminal_fall_speed": 450.0})
		await _until(func(): return actor.global_position.y > 256 + 230, {}, 2)
		_check(float(actor.telemetry().fall_distance) > actor.profile.hard_land_min_distance, "fixture builds genuine qualifying descent before any grip")
		if grip == "ladder":
			_sensor(Vector2(actor.global_position.x, actor.global_position.y + 130), 260)
			await _step({}, 2); await _step({"up": 1.0})
			await _until(func(): return actor.main_action == &"climb", {"up": 1.0}, .4)
		elif grip == "wall":
			actor.allow_wall_run = true
			_wall_body(1, actor.global_position.x + 10, actor.global_position.y - 600, actor.global_position.y + 600)
			await _step({}, 2); await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .4)
		else:
			_wall_body(1, actor.global_position.x + 10, actor.global_position.y - 18, actor.global_position.y + 300, 100)
			await _step({}, 2); await _until(func(): return actor.main_action == &"ledge", {"right": 1.0}, .4)
		_check(actor.main_action == StringName("climb" if grip == "ladder" else grip), "actual supported grip is acquired through normal input and geometry")
		_check(not bool(actor.telemetry().fall_history_active) and float(actor.telemetry().fall_distance) == 0, "established grip clears fall history without masquerading as ground contact")
		_check(_count("landed") == 0, "grip history reset does not emit a false floor landing")
		await _finish()
	await _fall_fixture("mere solid wall contact does not erase fall", 420, 500, {"terminal_fall_speed": 500.0})
	_wall_body(1, 108.1, -500, 1200)
	await _await_landing({"right": 1.0})
	_check(not actor.allow_wall_run and _count("hard_land_started") == 1, "ungripped side collision preserves the actual falling excursion")
	await _finish()

func _hard_native_queues() -> void:
	for action in ["jump", "roll", "attack", "down"]:
		var floor = await _fall_fixture("native early recovery tap " + action)
		if action == "down": floor.one_way = true
		await _await_landing()
		actor.automatic_physics = true
		var key: Key = KEY_SPACE if action in ["jump", "down"] else (KEY_SHIFT if action == "roll" else KEY_J)
		if action == "down": _key(KEY_S, true)
		_key(key, true); await _step(null)
		_key(key, false)
		if action == "down": _key(KEY_S, false)
		await _step(null)
		var buffered = actor.telemetry()
		var event_name := "ground_jump" if action == "jump" else ("roll_started" if action == "roll" else ("attack_started" if action == "attack" else "drop_started"))
		_check(actor.main_action == &"hard_land" and _count(event_name) == 0, "early native press and release cannot bypass committed hard recovery")
		await _until(func(): return actor.main_action != &"hard_land", null, .6)
		var released_tick: int = driver.ticks
		_check(_count(event_name) == 1, "recovery completion consumes the retained native tap exactly once")
		if action == "jump": _check(actor.velocity.y < 0 and absf(actor.velocity.y) <= actor.profile.jump_release_rise_cap + .01, "released recovery tap retains its variable-height cut on the eventual jump")
		elif action == "down": _check(_count("air_jump") == 0 and _count("ground_jump") == 0 and _count("dive_started") == 0, "queued grounded Down+Jump keeps drop context and cannot become another action")
		await _seconds(null, .08)
		_check(_count(event_name) == 1 and driver.ticks > released_tick, "accepted action remains single-consumed on subsequent actual physics ticks")
		measurements["buffer_snapshot_during_recovery"] = buffered
		await _finish()

func _hard_dive_roll_protection() -> void:
	for boundary in ["before", "at", "after", "outside_iframes"]:
		var floor = await _fall_fixture("descent roll protection contact " + boundary, 2400, 500)
		await _until(func(): return float(actor.telemetry().fall_distance) > actor.profile.hard_land_min_distance + 30, {}, 2)
		await _step({"down": 1.0, "jump": true})
		await _until(func(): return actor.dive_phase == &"descent" and actor.velocity.y >= actor.combat_profile.dive_max_speed - .01, {}, 1)
		_check(actor.main_action == &"dive" and actor.dive_phase == &"descent", "roll starts from actual live dive descent after a qualifying free fall")
		actor.profile.gravity = 0
		var speed: float = actor.velocity.y
		var roll_steps := ceili((_roll_duration() - .000000001) / dt)
		var target_step: int = roll_steps - 1 if boundary == "before" else (roll_steps if boundary == "at" else roll_steps + 1)
		if boundary == "outside_iframes": target_step = ceili((actor.combat_profile.roll_invulnerable_until + actor.combat_profile.roll_recovery_seconds * .5) / dt)
		floor.position.y = actor.global_position.y + speed * dt * (target_step + 1) + actor.profile.collision_margin
		await _step({"roll": true})
		var started_tick: int = driver.ticks
		var serial: int = int(actor.telemetry().roll_serial)
		_check(actor.main_action == &"roll" and bool(actor.telemetry().roll_fall_protected), "accepted descent-to-roll transition scopes fall protection to that live roll")
		await _await_landing({}, 2)
		measurements["contact_roll_seconds"] = (driver.ticks - started_tick) * dt
		measurements["intended_contact_step"] = target_step
		measurements["observed_contact_step"] = driver.ticks - started_tick
		_check(driver.ticks == started_tick + target_step, "real floor collision occurs on the intended roll lifetime boundary tick")
		var protected: bool = boundary in ["before", "outside_iframes"]
		_check((_count("hard_land_started") == 0) == protected, "high-fall protection exists only before the originating roll's exclusive lifetime end")
		_check(int(actor.telemetry().roll_serial) == serial and _count("roll_started") == 1, "protection cannot refer to a later or repeated roll")
		if protected:
			_check(not actor.is_roll_invulnerable() and bool(actor.telemetry().roll_fall_protected), "fall protection continues after roll i-frames end while the same roll is still active")
		else: _check(not bool(actor.telemetry().roll_fall_protected), "ended roll cannot retain protection during hard landing")
		_check(_count("dive_impact") == 0 and _count("landed") == 1, "cancelled dive cannot emit a later false impact on rolled touchdown")
		await _finish()
	for source in ["startup", "expired", "cancelled_attack", "cancelled_damage", "cancelled_forced"]:
		var floor = await _fall_fixture("roll has no leaked protection from " + source, 2400, 500)
		await _until(func(): return float(actor.telemetry().fall_distance) > actor.profile.hard_land_min_distance + 30, {}, 2)
		await _step({"down": 1.0, "jump": true})
		if source != "startup":
			await _until(func(): return actor.dive_phase == &"descent" and actor.velocity.y >= actor.combat_profile.dive_max_speed - .01, {}, 1)
		if source == "expired": await _until(func(): return actor.main_action != &"dive", {}, actor.combat_profile.dive_max_descent_seconds + .2)
		actor.profile.gravity = 0
		var speed: float = actor.velocity.y
		var contact_seconds := .24 if source.begins_with("cancelled_") else .12
		floor.position.y = actor.global_position.y + speed * contact_seconds + actor.profile.collision_margin
		await _step({"roll": true})
		if source.begins_with("cancelled_"):
			_check(bool(actor.telemetry().roll_fall_protected), "cancellation fixture first establishes the real descent-origin protection")
			if source == "cancelled_attack":
				await _seconds({}, actor.combat_profile.roll_attack_cancel_after + dt); await _step({"attack": true})
			elif source == "cancelled_damage": actor.receive_hit({"rollable": false, "impulse": Vector2(0, speed), "hitpause": 0.0})
			else: _check(actor.begin_main_action(&"forced", {}), "forced interruption is accepted by the live roll")
		_check(not bool(actor.telemetry().roll_fall_protected), "startup expired or cancelled dive-roll history grants no active protection")
		await _await_landing({}, 2)
		_check(_count("hard_land_started") == 1 and actor.main_action == &"hard_land", "qualifying contact after an ineligible or cancelled roll still starts hard recovery")
		_check(_count("dive_impact") == 0 and _count("landed") == 1, "historical dive ownership cannot create a duplicate impact")
		await _finish()
	for distance_scale in [.5, 1.8]:
		var p = load("res://combat_pc/resources/movement_profile.tres")
		await _fall_fixture("dive impact recovery height scale %.1f" % distance_scale, p.hard_land_min_distance * distance_scale)
		await _step({"down": 1.0, "jump": true})
		await _await_landing()
		var high: bool = distance_scale > 1
		_check(_count("dive_impact") == 1 and _count("landed") == 1, "actual dive touchdown emits its own impact exactly once")
		_check((_count("hard_land_started") == 1) == high, "only qualifying high dive transfers recovery into hard landing")
		_check(actor.main_action == (&"hard_land" if high else &"dive"), "low dive retains its original recovery owner while high dive uses hard recovery")
		if high: _check(String(actor.telemetry().hard_land_kind) == "dive", "hard recovery retains the semantic dive impact kind")
		_check(_count("noise:hard_land") == (1 if high else 0) and _count("noise:dive_impact") == (0 if high else 1) and _count("noise:land") == 0, "low and high dive contacts each emit only their dominant landing cue")
		await _seconds({}, .5)
		_check(_count("dive_impact") == 1 and _count("landed") == 1, "remaining on the floor cannot duplicate dive or hard-impact dispatch")
		await _finish()

func _hard_phase_permissions_and_lifecycle() -> void:
	await _fall_fixture("hard impact skid facing and recovery permissions")
	actor.velocity.x = actor.profile.run_speed
	await _await_landing({"right": 1.0})
	var horizontal_before: float = actor.velocity.x
	await _step({"left": 1.0, "up": 1.0})
	_near(actor.velocity.x, maxf(0, horizontal_before - actor.profile.hard_land_braking * dt), .02, "hard-impact horizontal skid uses configured braking without accepting opposite locomotion")
	_check(actor.facing == 1 and _hard_phase() == "impact", "impact locks facing despite deliberate opposite input")
	await _until(func(): return _hard_phase() == "recovery", {"left": 1.0}, .2)
	_check(actor.facing == -1 and actor.main_action == &"hard_land", "recovery restores turning while retaining motion ownership")
	actor.set_weapon_permissions({"can_turn": false})
	await _step({"right": 1.0})
	_check(actor.facing == -1, "recovery cannot reopen externally forbidden turning")
	await _until(func(): return absf(actor.velocity.x) < .02, {"right": 1.0}, horizontal_before / actor.profile.hard_land_braking + dt)
	_check(absf(actor.velocity.x) < .02 and not _trace_has_solid_overlap(), "finite skid stops physically without body overlap")
	_check(_count("noise:hard_land") == 1 and _count("noise:footstep") == 0, "committed hard skid cannot emit travel footsteps alongside its impact cue")
	await _finish()
	await _fall_fixture("hard recovery retains tapped jump across host denial")
	await _await_landing(); actor.automatic_physics = true
	_key(KEY_SPACE, true); await _step(null); _key(KEY_SPACE, false); await _step(null)
	actor.set_weapon_permissions({"can_jump": false})
	await _until(func(): return actor.main_action != &"hard_land", null, .5)
	_check(_count("ground_jump") == 0 and float(actor.telemetry().jump_buffer) > 0, "host denial survives recovery while the retained input remains finite")
	await _seconds(null, actor.profile.jump_buffer_seconds * .25)
	actor.set_weapon_permissions(); await _step(null)
	_check(_count("ground_jump") == 1 and actor.velocity.y < 0 and absf(actor.velocity.y) <= actor.profile.jump_release_rise_cap + .01, "restored jump permission preserves the queued tap's release history")
	await _seconds(null, .04)
	_check(_count("ground_jump") == 1 and _count("air_jump") == 0 and actor.velocity.y < 0, "accepted recovery jump survives multiple ticks without hidden repeat or ascent cancellation")
	await _finish()
	await _fall_fixture("hard recovery disable input clears native held request")
	await _await_landing(); actor.automatic_physics = true
	_key(KEY_SPACE, true); await _step(null)
	actor.allow_input = false
	await _until(func(): return actor.main_action != &"hard_land", null, .5)
	actor.allow_input = true; await _step(null, 2)
	_check(_count("ground_jump") == 0 and float(actor.telemetry().jump_buffer) == 0, "input disable clears queues and reenable cannot synthesize an edge from held Jump")
	_key(KEY_SPACE, false); await _step(null); _key(KEY_SPACE, true); await _step(null)
	_check(_count("ground_jump") == 1, "a genuinely fresh native press works after disabled recovery")
	await _finish()
	await _fall_fixture("hard ability disable affects only future contact")
	await _await_landing(); actor.enable_hard_landing = false
	await _step({"jump": true})
	_check(actor.main_action == &"hard_land" and _count("ground_jump") == 0, "turning off the optional trigger does not cancel an existing committed recovery")
	await _until(func(): return actor.main_action != &"hard_land", {}, .5)
	_check(_count("hard_land_finished") == 1, "already-started recovery still completes finitely")
	await _finish()
	for phase in ["impact", "recovery"]:
		for reason in ["floor_removed", "damage", "forced", "reset"]:
			var floor = await _fall_fixture("hard %s cancellation %s" % [phase, reason])
			await _await_landing()
			if phase == "recovery": await _until(func(): return _hard_phase() == "recovery", {}, .2)
			if reason == "floor_removed": floor.queue_free()
			elif reason == "damage": actor.receive_hit({"rollable": false, "impulse": Vector2(-80, -70), "hitpause": .1})
			elif reason == "forced": _check(actor.begin_main_action(&"forced", {}), "forced replacement is accepted during hard recovery")
			else: actor.reset_actor(Vector2(100, 256))
			await _step()
			_check(actor.main_action != &"hard_land" and not bool(actor.telemetry().hard_land_active), "support loss forced action hurt or reset retires hard recovery immediately")
			if reason == "damage": _check(actor.main_action == &"hurt" and actor.hitpause_remaining > 0, "new incoming hurt overrides landing ownership and owns its own pause")
			elif reason == "floor_removed":
				await _step({}, 2)
				_check(not actor.grounded and actor.velocity.y > 0 and _count("landed") == 1, "removed floor releases into gravity without repeated land dispatch or a frozen hover")
			elif reason == "reset": _check(not bool(actor.telemetry().roll_fall_protected) and float(actor.telemetry().hard_land_progress) == 0, "reset clears hard progress and unrelated roll protection")
			await _finish()
	var floor = await _fall_fixture("hard recovery exit preserves low ceiling clearance")
	await _await_landing()
	var roof = _surface(Vector2(40, floor.position.y - 32), Vector2(140, 10))
	await _step({"jump": true}); await _step()
	await _until(func(): return actor.main_action != &"hard_land", {}, .5)
	_check(actor.crouched and _count("ground_jump") == 0 and not _has_solid_overlap(), "bounded recovery cannot expand the small body or jump through newly blocked headroom")
	roof.queue_free(); await _step({}, 2)
	_check(_count("ground_jump") == 1 and actor.velocity.y < 0 and not _has_solid_overlap(), "a still-live queued jump resumes only once genuine standing space opens")
	await _finish()

func _hard_moving_floor_and_pause() -> void:
	for pair in [Vector2(500, 150), Vector2(350, -100)]:
		var floor = await _fall_fixture("moving floor relative impact %.0f %.0f" % [pair.x, pair.y], 420, pair.x, {"terminal_fall_speed": pair.x})
		_motion(floor, Vector2(0, pair.y))
		await _await_landing({}, 3)
		measurements["relative_impact_speed"] = float(_last_event("landed").get("data", {}).get("relative_impact_speed", -1))
		var expected: bool = pair.x - pair.y >= actor.profile.hard_land_min_relative_speed
		_check((_count("hard_land_started") == 1) == expected, "hard landing uses downward relative Y speed rather than actor world speed alone")
		if expected: _near(float(actor.telemetry().hard_land_relative_impact_speed), pair.x - pair.y, .2, "recorded relative impact subtracts the actual translating floor velocity")
		_check(not _trace_has_solid_overlap(), "new moving-floor contact leaves the body outside its current rectangle")
		await _finish()
	for pause in [false, true]:
		var floor = await _fall_fixture("hard floor transport " + ("paused" if pause else "live"))
		await _await_landing()
		var relative_before: Vector2 = actor.global_position - floor.global_position
		var progress: float = actor.telemetry().hard_land_progress
		_motion(floor, Vector2(30, -35))
		if pause: actor.apply_hitpause(.2)
		await _seconds({}, .1)
		var relative_after: Vector2 = actor.global_position - floor.global_position
		_check(relative_after.distance_to(relative_before) < .25 and not _trace_has_solid_overlap(), "hard recovery follows valid moving support using safe swept transport")
		_check(not bool(actor.telemetry().fall_history_active) and float(actor.telemetry().fall_distance) == 0 and _count("landed") == 1, "supported carrier motion cannot manufacture a new fall or duplicate touchdown")
		if pause: _near(float(actor.telemetry().hard_land_progress), progress, .000001, "actor-local hitpause freezes hard recovery while support transport remains safe")
		await _finish()
	await _begin("long supported carrier descent is excluded from next fall", Vector2(100, 200), false)
	actor.enable_hard_landing = true
	var carrier = _landing_floor(200)
	await _until(func(): return actor.grounded)
	var motion = _motion(carrier, Vector2(0, 350))
	await _seconds({}, 1.0); motion.enabled = false
	_check(actor.global_position.y > 500 and float(actor.telemetry().fall_distance) == 0 and not bool(actor.telemetry().fall_history_active), "large grounded carrier descent remains support motion rather than free-fall history")
	var release_y: float = actor.global_position.y
	carrier.queue_free(); _landing_floor(release_y + 80)
	await _step()
	var landings: int = _count("landed")
	await _until(func(): return _count("landed") > landings, {}, 1)
	_check(_count("hard_land_started") == 0 and actor.grounded, "short fall after support removal does not inherit the carrier's long travel")
	await _finish()

func _hard_boundary_input_and_geometry() -> void:
	for action in ["jump", "roll", "attack", "down"]:
		for offset in [-1, 0, 1]:
			var label := "before" if offset < 0 else ("at" if offset == 0 else "after")
			var floor = await _fall_fixture("native hard recovery boundary %s %s" % [action, label])
			if action == "down": floor.one_way = true
			await _await_landing(); actor.automatic_physics = true
			var contact_tick: int = driver.ticks
			var eligible := ceili((actor.profile.hard_land_impact_seconds + actor.profile.hard_land_recovery_seconds - .000000001) / dt)
			await _step(null, eligible + offset - 1)
			var key: Key = KEY_SPACE if action in ["jump", "down"] else (KEY_SHIFT if action == "roll" else KEY_J)
			var event_name := "ground_jump" if action == "jump" else ("roll_started" if action == "roll" else ("attack_started" if action == "attack" else "drop_started"))
			if action == "down": _key(KEY_S, true)
			_key(key, true); await _step(null)
			measurements["press_after_contact_seconds"] = (driver.ticks - contact_tick) * dt
			_check(driver.ticks == contact_tick + eligible + offset, "boundary press arrives on the intended exact physics tick")
			if offset < 0:
				_check(actor.main_action == &"hard_land" and _count(event_name) == 0, "the last committed recovery tick queues input without early execution")
				await _step(null)
			_check(_count(event_name) == 1 and actor.main_action != &"hard_land", "first eligible boundary executes the requested action exactly once")
			measurements["action_after_contact_seconds"] = (driver.ticks - contact_tick) * dt
			_key(key, false)
			if action == "down": _key(KEY_S, false)
			await _seconds(null, .04)
			_check(_count(event_name) == 1 and _count("landed") == 1, "subsequent ticks retain the accepted action without a repeat or duplicate landing reset")
			if action == "jump": _check(actor.velocity.y < 0 and _count("air_jump") == 0, "ground jump preserves its upward impulse across the recovery boundary")
			await _finish()
	await _fall_fixture("recovery simultaneous queued action priority")
	await _await_landing(); await _step({"jump": true, "roll": true, "attack": true}); await _step()
	await _until(func(): return actor.main_action != &"hard_land", {}, .5)
	_check(actor.main_action == &"roll" and _count("roll_started") == 1 and _count("ground_jump") == 0 and _count("attack_started") == 0, "recovery release preserves explicit roll priority over queued jump and melee")
	await _seconds({}, .4)
	_check(_count("roll_started") == 1 and _count("ground_jump") == 0 and _count("attack_started") == 0, "lower-priority queues resume finite expiry rather than leaking into later actions")
	await _finish()
	await _begin("hard landing high speed thin wall and floor", Vector2(100, 256), false)
	actor.enable_hard_landing = true
	actor.profile.terminal_fall_speed *= 4
	actor.velocity = Vector2(actor.profile.run_speed * 4, actor.profile.terminal_fall_speed)
	var floor = _surface(Vector2(-100, 680), Vector2(500, 2)); tracked_bodies.append(floor)
	_wall_body(1, 112, 0, 682, 2)
	await _await_landing({"right": 1.0})
	_check(_count("hard_land_started") == 1 and actor.grounded and actor.global_position.x <= 112 - actor.profile.body_width * .5 + .1, "fast diagonal fall cannot skip two-pixel wall or floor before hard contact dispatch")
	_check(not _trace_has_solid_overlap(), "high-speed hard impact retains continuous solid clearance")
	_near(float(actor.telemetry().hard_land_entry_horizontal_speed), 0, .02, "real wall collision still removes blocked horizontal momentum before hard recovery")
	await _finish()
	await _begin("sloped impact uses relative downward component", Vector2(100, 256), false)
	actor.enable_hard_landing = true
	actor.profile.terminal_fall_speed = actor.profile.hard_land_min_relative_speed + 20
	actor.velocity.y = actor.profile.terminal_fall_speed
	var slope = StaticBody2D.new(); slope.position = Vector2(100, 650); slope.collision_layer = 1; slope.collision_mask = 0
	var polygon = CollisionPolygon2D.new(); polygon.polygon = PackedVector2Array([Vector2(-180, 180), Vector2(180, -180), Vector2(180, 220), Vector2(-180, 220)])
	slope.add_child(polygon); world.add_child(slope)
	await _await_landing()
	_check(actor.main_action == &"hard_land" and absf(actor.telemetry().floor_normal.x) > .6, "qualifying real slope contact uses downward Y rather than normal-projected speed")
	_near(float(actor.telemetry().hard_land_relative_impact_speed), actor.profile.terminal_fall_speed, .01, "slope impact records the declared relative Y-speed threshold input")
	_check(not _has_solid_overlap(), "small recovery body remains collision-safe on the slope")
	await _finish()

func _hard_carrier_review_probes() -> void:
	for pair in [Vector2(500, 150), Vector2(350, -100)]:
		var floor = await _fall_fixture("late callback floor relative impact %.0f %.0f" % [pair.x, pair.y], 420, pair.x, {"terminal_fall_speed": pair.x})
		var motion = _motion(floor, Vector2(0, pair.y)); motion.process_physics_priority = 40
		await _await_landing({}, 3); motion.enabled = false
		measurements["relative_impact_speed"] = float(_last_event("landed").get("data", {}).get("relative_impact_speed", -1))
		var expected: bool = pair.x - pair.y >= actor.profile.hard_land_min_relative_speed
		_check((_count("hard_land_started") == 1) == expected, "a moving floor's engine velocity remains authoritative when its pending translation is zero at actor sampling")
		if expected: _near(float(actor.telemetry().hard_land_relative_impact_speed), pair.x - pair.y, .2, "relative impact remains correct for a post-actor mover callback")
		await _finish()
	await _begin("partly blocked hurt carrier excludes actual swept motion only", Vector2(100, 200), false)
	actor.enable_hard_landing = true
	var carrier = _landing_floor(200)
	await _until(func(): return actor.grounded)
	var roof_bottom: float = actor.global_position.y - actor.body_height - 1
	var roof = _surface(Vector2(40, roof_bottom - 12), Vector2(120, 12))
	await _step()
	actor.receive_hit({"rollable": false, "impulse": Vector2(0, -70), "hitpause": .2})
	var before: Vector2 = actor.global_position
	var motion = _motion(carrier, Vector2(0, -350))
	await _step(); motion.enabled = false
	var actual_shift: float = actor.global_position.y - before.y
	_check(actual_shift < 0 and absf(actual_shift) < 350 * dt - .1, "roof fixture genuinely blocks part of the requested upward hurt-carrier sweep")
	_near(float(actor.telemetry().fall_distance), 0, .03, "blocked carrier travel cannot invent free-fall distance from the unachieved requested displacement")
	_near(float(actor.telemetry().support_displacement.y), actual_shift, .03, "transport telemetry records actual swept carrier motion")
	# Remove the opposing geometry after the one bounded blocked step; an
	# indefinitely advancing crusher is not an escape-policy assertion.
	carrier.queue_free(); roof.queue_free(); await _step({}, 2)
	_check(actor.main_action == &"hurt" and _count("hard_land_started") == 0, "paused hurt remains owned without a fabricated landing after carrier removal")
	await _finish()

func _hard_slopes_and_connected_reuse() -> void:
	for direction in [-1, 1]:
		for kind in ["downhill", "uphill", "uphill_ceiling"]:
			await _begin("hard skid %d %s" % [direction, kind], Vector2(100, 256), false)
			actor.enable_hard_landing = true
			var gradient: int = direction if kind == "downhill" else -direction
			var slope = StaticBody2D.new(); slope.position = Vector2(100, 1000); slope.collision_layer = 1; slope.collision_mask = 0
			var polygon = CollisionPolygon2D.new()
			polygon.polygon = PackedVector2Array([Vector2(-1200, -1200 * gradient), Vector2(1200, 1200 * gradient), Vector2(1200, 1300), Vector2(-1200, 1300)])
			slope.add_child(polygon); world.add_child(slope)
			var incoming = Vector2(actor.profile.run_speed * 2 * direction, actor.profile.terminal_fall_speed) if kind == "downhill" else Vector2(actor.profile.terminal_fall_speed * direction, actor.profile.hard_land_min_relative_speed * 1.5)
			actor.begin_main_action(&"incoming_probe", {"can_wall_grab": false}, func(player, _delta, _frame): player.velocity = incoming; return true)
			await _await_landing({}, 3)
			_check(actor.main_action == &"hard_land" and actor.grounded, "controlled incoming motion reaches real sloped hard contact")
			measurements["incoming_hard_horizontal_speed"] = actor.velocity.x
			_near(float(actor.telemetry().hard_land_entry_horizontal_speed), incoming.x, .02, "hard recovery preserves controlled incoming horizontal momentum rather than creating speed from downward collision")
			_near(actor.velocity.x, incoming.x, .02, "first recovery sample retains the same horizontal momentum at either physics rate")
			if kind == "uphill_ceiling": _surface(Vector2(actor.global_position.x - 70, actor.global_position.y - actor.body_height - 12.25), Vector2(140, 12))
			var remained_supported := true
			var clear := true
			var start_tick: int = driver.ticks
			while actor.main_action == &"hard_land" and driver.ticks - start_tick < hz:
				await _step()
				remained_supported = remained_supported and actor.grounded
				clear = clear and not _has_solid_overlap()
			measurements["slope_recovery_seconds"] = (driver.ticks - start_tick) * dt
			_check(remained_supported and _count("hard_land_finished") == 1 and _count("hard_land_cancelled") == 0, "hard skid follows its confirmed floor through complete recovery instead of outrunning the floor probe")
			_check(clear and _count("landed") == 1, "mirrored slope and ceiling constraints remain swept with one floor dispatch")
			await _finish()
	await _fall_fixture("actual spent air budgets refill on hard contact", 720)
	await _step({"jump": true})
	await _until(func(): return float(actor.telemetry().fall_distance) > actor.profile.hard_land_min_distance + 30, {"jump": true}, 2)
	await _step(); await _step({"down": 1.0, "jump": true})
	await _until(func(): return actor.dive_phase == &"descent", {}, .3)
	await _step({"roll": true})
	await _seconds({}, actor.combat_profile.roll_attack_cancel_after + dt); await _step({"attack": true})
	_check(actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available and not bool(actor.telemetry().roll_fall_protected), "actual air jump dive and interrupted roll spend independent budgets before impact")
	await _await_landing()
	_check(actor.main_action == &"hard_land" and actor.air_jumps_left == actor.profile.air_jump_count and actor.air_roll_available and actor.dive_available, "one genuine hard floor contact replenishes the three independent airborne budgets")
	await _step({"jump": true}); await _step()
	await _until(func(): return actor.main_action != &"hard_land", {}, .5)
	await _step({"jump": true})
	_check(_count("ground_jump") == 1 and _count("air_jump") == 2 and actor.air_jumps_left == 0, "retained ground jump and one fresh air jump consume only their respective resources after recovery")
	await _seconds({"jump": true}, .08)
	_check(_count("air_jump") == 2 and actor.air_jumps_left == 0, "held airborne input cannot receive repeated floor refills or repeat a consumed jump")
	await _finish()
	var floor = await _fall_fixture("same actor repeated hard falls and reset")
	var identity: int = actor.get_instance_id()
	for cycle in range(3):
		var contacts: int = _count("landed")
		var starts: int = _count("hard_land_started")
		if cycle > 0: actor.reset_actor(Vector2(100, 256), 1)
		await _until(func(): return _count("landed") > contacts, {}, 2)
		_check(actor.get_instance_id() == identity and _count("hard_land_started") == starts + 1, "same actor reuses clean excursion history for each genuine high fall")
		actor.apply_hitpause(.1); await _step({"jump": true, "attack": true})
		actor.reset_actor(Vector2(100, 256), 1)
		_check(not bool(actor.telemetry().hard_land_active) and float(actor.telemetry().hard_land_progress) == 0 and not bool(actor.telemetry().roll_fall_protected) and actor.hitpause_remaining == 0 and float(actor.telemetry().jump_buffer) == 0, "reset clears recovery pause protection and retained input on the same instance")
		await _step()
	_check(is_instance_valid(floor) and not _trace_has_solid_overlap(), "repeated lifecycle use leaves the original physical floor valid and collision-safe")
	await _finish()
	floor = await _fall_fixture("one-way hard recovery queued drop reaches next hard contact")
	floor.one_way = true
	var lower = _landing_floor(floor.position.y + 320, -1000, 3000, true)
	await _await_landing()
	await _step({"down": 1.0, "jump": true}); await _step()
	await _until(func(): return _count("drop_started") == 1, {}, .6)
	_check(actor.get_collision_exceptions() == [floor], "recovery's retained grounded chord ignores only its actual upper one-way support")
	await _until(func(): return _count("landed") == 2, {}, 2)
	_check(actor.main_action == &"hard_land" and actor.telemetry().support_id == lower.get_instance_id() and _count("hard_land_started") == 2 and actor.get_collision_exceptions().is_empty(), "separate lower platform remains collidable and classifies the new fall independently")
	_check(_count("dive_started") == 0 and _count("air_jump") == 0, "one queued grounded chord never becomes a dive or air jump during the next descent")
	await _finish()
	floor = await _fall_fixture("floor loss during paused hard recovery")
	await _await_landing(); actor.apply_hitpause(.2); floor.queue_free(); await _step()
	_check(actor.main_action != &"hard_land" and _count("hard_land_cancelled") == 1 and not actor.grounded, "removed support revokes committed landing authority even during local hitpause")
	await _finish()

func _hard_final_context_edges() -> void:
	for context in ["low_impact", "low_recovery", "high_recovery"]:
		var default_profile = load("res://combat_pc/resources/movement_profile.tres")
		var high: bool = context == "high_recovery"
		var floor = await _fall_fixture("post-impact dive roll is ordinary " + context, default_profile.hard_land_min_distance * (1.8 if high else .5))
		floor.position.x = 80; floor.size = Vector2(42, 10)
		_landing_floor(floor.position.y + default_profile.hard_land_min_distance + 100)
		await _step({"down": 1.0, "jump": true}); await _await_landing()
		if context == "low_recovery": await _until(func(): return actor.dive_phase == &"recovery", {}, .2)
		await _step({"right": 1.0, "roll": true}); await _step({"right": 1.0})
		await _until(func(): return actor.main_action == &"roll", {"right": 1.0}, .6)
		_check(actor.main_action == &"roll" and not bool(actor.telemetry().roll_fall_protected), "roll requested after actual dive impact cannot inherit historical descent protection")
		_check(_count("dive_impact") == 1 and _count("roll_started") == 1, "post-impact queued roll starts once after the relevant committed phase")
		await _until(func(): return _count("landed") == 2, {"right": 1.0}, 2)
		_check(actor.main_action == &"hard_land" and _count("hard_land_started") == (2 if high else 1), "later high fall from the ledge remains independently eligible for hard recovery")
		await _finish()
	await _fall_fixture("buffered pre-contact jump cannot bypass hard impact")
	actor.automatic_physics = true
	_key(KEY_SPACE, true); await _step(null)
	await _until(func(): return actor.velocity.y > 0 and float(measurements.floor_plane_y) - actor.global_position.y < actor.velocity.y * actor.profile.jump_buffer_seconds * .5, null, 2)
	_key(KEY_SPACE, false); await _step(null); _key(KEY_SPACE, true); await _step(null)
	await _await_landing(null)
	_check(_count("air_jump") == 1 and actor.main_action == &"hard_land" and _count("ground_jump") == 0, "qualifying contact owns recovery before consuming a still-live landing jump buffer")
	await _until(func(): return _count("ground_jump") == 1, null, .5)
	_check(_count("ground_jump") == 1 and _count("hard_land_finished") == 1 and actor.velocity.y < 0, "pre-contact request survives bounded recovery then launches once from the real floor")
	await _seconds(null, .05)
	_check(_count("air_jump") == 1 and actor.velocity.y < 0, "held landing input cannot spend another air jump after the accepted launch")
	await _finish()
	for repress in [false, true]:
		await _fall_fixture("native hard-recovery paused latest input " + ("held repress" if repress else "tap"))
		await _await_landing(); actor.automatic_physics = true; actor.apply_hitpause(.2)
		_key(KEY_SPACE, true); await _step(null); _key(KEY_SPACE, false); await _step(null)
		if repress: _key(KEY_SPACE, true); await _step(null)
		_check(actor.main_action == &"hard_land" and _count("ground_jump") == 0, "local pause captures intent without advancing the committed landing owner")
		await _until(func(): return actor.hitpause_remaining <= 0, null)
		await _until(func(): return _count("ground_jump") == 1, null, .5)
		_check(_count("ground_jump") == 1 and actor.velocity.y < 0, "latest buffered input executes once after pause and hard recovery both finish")
		if repress: _check(absf(actor.velocity.y) > actor.profile.jump_release_rise_cap + 20, "a later held repress owns its new release history and keeps the full jump")
		else: _check(absf(actor.velocity.y) <= actor.profile.jump_release_rise_cap + .01, "a released tap retains its cut through both frozen intervals")
		await _finish()

func _hard_release_excursion_edges() -> void:
	await _begin("ladder bottom release excludes final supported segment", Vector2(100, 350), false)
	actor.enable_hard_landing = true
	_sensor(Vector2(100, 360), 180)
	await _step({}, 2); await _step({"down": 1.0})
	await _until(func(): return actor.main_action == &"climb", {"down": 1.0}, .3)
	_check(actor.main_action == &"climb", "actual near-bottom grip begins before its supported descent")
	await _until(func(): return _count("climb_detached") == 1, {"down": 1.0}, .6)
	var detached: Dictionary = _last_event("climb_detached")
	var release_y: float = float(detached.get("data", {}).get("position", [0, actor.global_position.y])[1])
	_check(String(detached.get("data", {}).get("reason", "")) == "bottom_exit", "fixture reaches a real unsupported bottom exit after a climb sweep")
	_near(float(actor.telemetry().fall_apex_y), release_y, .03, "new excursion begins at actual grip release rather than including the final supported travel")
	_landing_floor(release_y + actor.profile.hard_land_min_distance - .25 + actor.profile.collision_margin)
	await _await_landing()
	_check(_count("hard_land_started") == 0 and actor.grounded, "a just-below-threshold fall after bottom exit cannot inherit a phantom supported segment")
	await _finish()
	await _setup_wall("ceiling-interrupted wall kick preserves its excursion after commitment")
	actor.enable_hard_landing = true
	var initial_y: float = actor.global_position.y
	_surface(Vector2(-50, initial_y - actor.body_height - 20), Vector2(250, 12))
	_landing_floor(initial_y + actor.profile.hard_land_min_distance + 100)
	await _step({"right": 1.0, "jump": true})
	var kick_tick: int = driver.ticks
	await _until(func(): return actor.main_action != &"wall", {"jump": true}, .4)
	var apex: float = initial_y
	for frame in frames:
		if int(frame.tick) >= kick_tick: apex = minf(apex, float(frame.position[1]))
	_check(_count("ceiling_contact") > 0 and actor.velocity.y > 0, "kick hits the real ceiling and begins falling before its commitment ends")
	_near(float(actor.telemetry().fall_apex_y), apex, .03, "kick completion retains its already-observed apex rather than starting another excursion")
	await _await_landing()
	_check(actor.main_action == &"hard_land", "subsequent qualifying fall remains eligible after wall-kick completion")
	_near(float(actor.telemetry().hard_land_fall_distance), actor.global_position.y - apex, .03, "hard contact measures the complete kick excursion from its physical apex")
	await _finish()

func _hard_synchronous_host_callbacks() -> void:
	for hook in ["action_changed", "hard_started", "recovery_phase", "finished"]:
		for replacement in ["hurt", "forced"]:
			await _fall_fixture("synchronous %s callback preserves %s owner" % [hook, replacement])
			var state := {"fired": false, "accepted": false}
			var overwrite = func():
				if state.fired: return
				state.fired = true
				if replacement == "hurt":
					state.accepted = actor.receive_hit({"rollable": false, "impulse": Vector2(-71, -47), "hitpause": .1})
				else:
					state.accepted = actor.begin_main_action(&"forced", {"uses_inputs": false, "small_hitbox": false}, func(player, _delta, _frame): player.velocity = Vector2(-71, -47); return true)
					actor.action_phase = &"external_phase"
					actor.phase_progress = .37
					actor.velocity = Vector2(-71, -47)
			if hook == "action_changed":
				actor.action_changed.connect(func(_previous: StringName, current: StringName):
					if current == &"hard_land": overwrite.call())
			else:
				actor.movement_event.connect(func(name: StringName, data: Dictionary):
					if (hook == "hard_started" and name == &"hard_land_started") or (hook == "recovery_phase" and name == &"hard_land_phase_changed" and data.get("phase") == &"recovery") or (hook == "finished" and name == &"hard_land_finished"):
						overwrite.call())
			await _until(func(): return state.fired, {}, 3)
			_check(state.fired and state.accepted and actor.main_action == StringName(replacement), "synchronous landing callback accepts and retains the host's replacement owner")
			var expected_velocity := Vector2(-71, -47)
			if replacement == "hurt" and hook in ["recovery_phase", "finished"]:
				expected_velocity.x = move_toward(expected_velocity.x, 0, actor.combat_profile.hurt_drag * dt)
				expected_velocity.y += actor.profile.gravity * actor.profile.released_jump_gravity_multiplier * dt
			_check(actor.action_phase == (&"recoil" if replacement == "hurt" else &"external_phase") and actor.velocity.distance_to(expected_velocity) < .01, "new owner phase wins immediately and only its intended remaining motion step may integrate")
			if replacement == "forced": _near(actor.phase_progress, .37, .000001, "late landing phase work cannot overwrite externally owned phase progress")
			if hook == "action_changed":
				_check(_count("hard_land_started") == 0 and _count("hard_land_phase_changed") == 0 and not actor.crouched, "replaced ownership before start delivery cannot reapply the hard body or emit late hard-only start events")
			elif hook == "hard_started": _check(_count("hard_land_started") == 1 and _count("hard_land_phase_changed") == 0, "a valid delivered start may be interrupted without a later stale impact-phase event")
			var starts: int = _count("hard_land_started")
			var phases: int = _count("hard_land_phase_changed")
			var paused_position: Vector2 = actor.global_position
			var paused_velocity: Vector2 = actor.velocity
			await _step({}, 2)
			if replacement == "hurt": _check(actor.global_position == paused_position and actor.velocity == paused_velocity, "mid-tick hurt pause freezes subsequent callbacks after the admitted step completes")
			_check(actor.main_action == StringName(replacement) and _count("hard_land_started") == starts and _count("hard_land_phase_changed") == phases, "subsequent physics ticks preserve replacement ownership without resurrecting hard recovery")
			await _finish()

func _hard_old_owner_signal_handoff() -> void:
	for source in ["weapon_retirement", "dive_impact"]:
		var floor = await _fall_fixture("incoming hurt from " + source + " wins hard handoff", 420, 600, {"terminal_fall_speed": 600.0})
		var state := {"fired": false}
		actor.movement_event.connect(func(name: StringName, data: Dictionary):
			if state.fired: return
			if (source == "weapon_retirement" and name == &"attack_cancelled" and data.get("reason") == &"hard_landing") or (source == "dive_impact" and name == &"dive_impact"):
				state.fired = true
				actor.receive_hit({"rollable": false, "impulse": Vector2(-71, -47), "hitpause": .1}))
		if source == "weapon_retirement":
			await _until(func(): return float(measurements.floor_plane_y) - actor.global_position.y < 600 * (actor.combat_profile.attack_windup_seconds + actor.combat_profile.attack_active_seconds * .5), {}, 2)
			await _step({"attack": true})
		else: await _step({"down": 1.0, "jump": true})
		await _until(func(): return state.fired, {}, 3)
		_check(state.fired and actor.main_action == &"hurt" and actor.action_phase == &"recoil", "new incoming hurt from the actual contact callback outranks the pending hard-recovery handoff")
		_check(_count("hard_land_started") == 0 and actor.velocity == Vector2(-71, -47), "the older contact transaction cannot recreate hard ownership or overwrite callback recoil")
		if source == "dive_impact": _check(_count("dive_impact") == 1, "the already-delivered actual dive impact remains exactly once after host interruption")
		_check(_count("landed") == 1 and int(_last_event("landed").get("data", {}).get("surface_id", 0)) == floor.get_instance_id(), "physical contact metadata keeps its original surface even when a callback clears live support")
		await _finish()
