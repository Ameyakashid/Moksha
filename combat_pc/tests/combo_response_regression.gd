extends "res://combat_pc/tests/combo_regression.gd"
## M20 focused admission acceptance. Real shared actor, real shared contact fixtures,
## one production physics call per engine physics callback; no invented frame counts.
const RESPONSIVE = "res://combat_pc/resources/responsive_chain.tres"
const BASELINE = "res://combat_pc/resources/light_chain.tres"
var selected_chain := RESPONSIVE
var response_rows: Array[Dictionary] = []
var movement_references := {}

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--chain="): selected_chain = argument.trim_prefix("--chain=")
	source_paths.append_array([BASELINE, RESPONSIVE, "res://combat_pc/resources/melee_chain.gd", "res://combat_pc/resources/melee_step.gd", "res://combat_pc/tests/combo_regression.gd", "res://combat_pc/tests/shield_regression.gd", "res://combat_pc/tests/combo_response_regression.gd", "res://combat_pc/fixtures/contact_target.gd", "res://combat_pc/fixtures/contact_target.tscn", "res://combat_pc/resources/ground_response_agile.tres", "res://combat_pc/resources/air_response_agile.tres"])
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	if only_group in ["", "resource"]: await _response_resource_cases()
	if only_group in ["", "early"]: await _response_early_cases()
	if only_group in ["", "patterns"]: await _response_pattern_cases()
	if only_group in ["", "pause"]: await _response_pause_cases()
	if selected_chain == RESPONSIVE:
		if only_group in ["", "restart"]: await _response_restart_cases()
		if only_group in ["", "gates"]: await _response_gate_cases()
		if only_group in ["", "cancel"]: await _response_cancel_cases()
		if only_group in ["", "callbacks"]: await _response_callback_cases()
		if only_group in ["", "contacts"]: await _response_contact_cases()
		if only_group in ["", "owners"]: await _response_owner_cases()
	_release_input()
	var hashes := {}; var stable := true
	for path in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Source changed during focused run; final rerun required")
	var result := {"milestone":20, "suite":"fresh combo response", "physics_hz":hz, "selected_group":only_group, "selected_chain":selected_chain, "checks":checks, "failures":failures, "scenarios":scenarios, "behavioral_rows":response_rows, "engine":Engine.get_version_info(), "production_hash_stable_during_run":stable, "starting_hashes":starting_hashes, "hashes":hashes, "execution":"One production physics_tick per actual Godot physics callback. Shared production actor and collision adapters; real passive targets and terrain. Direct lifecycle API and recursive refusal probes are identified separately. Frame samples are evidence, not independent test cases.", "limits":["Headless input-admission and physical-owner acceptance; subjective animation feel and native UI review are separate.", "Original combo/held suites run separately against the preserved baseline controller; these focused cases test the responsive candidate."]}
	var suffix := "candidate" if selected_chain == RESPONSIVE else "baseline"
	FileAccess.open("res://combat_pc/tests/combo_response_%s_results_%dhz.json" % [suffix, hz], FileAccess.WRITE).store_string(JSON.stringify(_safe(result), "  ") + "\n")
	print("COMBO_RESPONSE %s %dHz: %d scenarios, %d assertions, %d failures" % [suffix, hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _response_begin(label: String, floor_present := true) -> void:
	await _combo_begin(label, Vector2(100, 200) if floor_present else Vector2(100, -1000), floor_present)
	actor.melee_chain = load(selected_chain).duplicate(true)
	actor.melee_input_profile = null
	params.chain = selected_chain

func _response_finish() -> void:
	var starts := _event_rows("attack_started")
	var indices := []; var identities := []; var serials := []; var chains := []
	for row in starts:
		indices.append(int(row.data.step_index)); identities.append(int(row.data.input_id)); serials.append(int(row.data.serial)); chains.append(int(row.data.chain_serial))
	response_rows.append({"name":name_, "starts":starts.size(), "indices":indices, "input_ids":identities, "strike_serials":serials, "chain_serials":chains, "physical_contacts":contact_receipts.size(), "rejected":_count("chain_input_rejected"), "expired":_count("chain_input_expired"), "measurements":measurements.duplicate(true)})
	await _finish()

func _indices() -> Array:
	var result := []
	for row in _event_rows("attack_started"): result.append(int(row.data.step_index))
	return result

func _queued_restart() -> Array:
	return _event_rows("chain_input_queued").filter(func(row): return String(row.data.kind) == "restart")

func _native_attack(pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = KEY_J; event.pressed = pressed; Input.parse_input_event(event)

func _finisher_recovery() -> void:
	await _start_step(2)
	await _attack_phase("recovery")
	_check(int(_state().attack_step_index) == 2 and actor.weapon_phase == &"recovery", "setup reaches real finisher recovery")

func _late_age(first := true) -> void:
	var recovery: float = actor.melee_chain.steps[2].recovery_seconds
	var window: float = actor.melee_chain.fresh_restart_window_seconds
	await _until(func(): return actor.weapon_phase != &"recovery" or (float(_state().weapon_elapsed) + .000000001 >= recovery - window if first else float(_state().weapon_elapsed) + dt + .000000001 >= recovery), {}, .6)

func _response_resource_cases() -> void:
	await _response_begin("candidate changes admission only")
	var baseline: Resource = load(BASELINE)
	var candidate: Resource = load(RESPONSIVE)
	var differences := []
	for index in baseline.steps.size():
		for property in baseline.steps[index].get_property_list():
			if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
			if baseline.steps[index].get(property.name) != candidate.steps[index].get(property.name): differences.append(str(index) + ":" + String(property.name))
	_check(differences == ["0:followup_open_seconds", "1:followup_open_seconds"], "every step field except Slash/Backhand opening time is byte-value equivalent")
	_check(candidate.steps[0].followup_open_seconds == 0 and candidate.steps[1].followup_open_seconds == 0, "candidate admits fresh follow-up from first windup callback")
	_check(baseline.fresh_restart_window_seconds == 0 and candidate.fresh_restart_window_seconds == .12, "restart is opt-in and preserved baseline keeps no restart window")
	_check(candidate.followup_buffer_seconds == baseline.followup_buffer_seconds and candidate.idle_retention_seconds == baseline.idle_retention_seconds, "existing follow-up lifetime and idle retention remain unchanged")
	for value in [-.01, INF, NAN]:
		var invalid = candidate.duplicate(true); invalid.fresh_restart_window_seconds = value
		_check(invalid.snapshot() == null, "invalid restart duration is refused by resource snapshot")
	measurements.changed_step_fields = differences
	await _response_finish()

func _response_early_cases() -> void:
	for index in [0, 1]:
		await _response_begin("fresh early windup tap step%d" % index)
		await _start_step(index)
		await _step()
		var age: float = _state().attack_step_elapsed
		await _step({"attack":true})
		var fresh_id: int = _state().attack_input_id
		var pending: int = _state().chain_pending_input_id
		var expected := selected_chain == RESPONSIVE
		_check(age < .035 and actor.weapon_phase == &"windup", "fresh edge falls inside the formerly rejected 35 ms windup interval")
		_check((pending == fresh_id and pending > 0) == expected, "early admission follows the selected resource policy")
		await _seconds({"attack":true}, 1.0)
		var uses := _event_rows("attack_started").filter(func(row): return int(row.data.input_id) == fresh_id)
		_check(uses.size() == (1 if expected else 0), "one early physical identity commits once at most")
		_check(_count("attack_started") == index + 1 + (1 if expected else 0), "continued hold adds no hidden follow-up")
		measurements.early_press_age_seconds = age; measurements.admitted = expected
		await _response_finish()
	await _response_begin("parsed native early tap and release")
	_native_attack(true); await _step(null)
	_native_attack(false); await _step(null)
	var before_age: float = _state().attack_step_elapsed
	_native_attack(true); await _step(null)
	_native_attack(false); await _step(null)
	await _seconds(null, .8)
	_check(before_age < .035, "parsed key events reach the early physical interval")
	_check(_indices() == ([0, 1] if selected_chain == RESPONSIVE else [0]), "native press-release preserves exactly the selected admission result")
	await _response_finish()

func _response_pattern_cases() -> void:
	for pattern in [[0.0, .12, .32], [0.0, .05, .23]]:
		await _response_begin("three deliberate taps " + str(pattern))
		var start_tick := ticks; var tap_index := 0
		for index in ceili(1.2 / dt):
			var press: bool = tap_index < pattern.size() and index * dt + .000000001 >= float(pattern[tap_index])
			if press: tap_index += 1
			await _step({"attack":press})
		var expected: Array = [0, 1] if selected_chain == BASELINE and float(pattern[2]) == .23 else [0, 1, 2]
		_check(_indices() == expected, "three-tap progression matches the selected follow-up opening policy")
		_check(actor.weapon_phase == &"idle" and int(_state().chain_pending_input_id) == 0, "completed three-tap pattern has no deferred work")
		measurements.tap_offsets_seconds = pattern; measurements.begin_tick = start_tick
		await _response_finish()
	for rate in [6, 10, 18, 30]:
		await _response_begin("finite %d taps per second burst" % rate)
		var next_press := 0.0; var was_pressed := false; var press_count := 0
		for index in ceili(1.6 / dt):
			var press := not was_pressed and index * dt + .000000001 >= next_press
			if press: next_press += 1.0 / rate; press_count += 1
			await _step({"attack":press}); was_pressed = press
		var count_at_release := _count("attack_started")
		await _seconds({}, 1.2)
		var count_settled := _count("attack_started")
		await _seconds({}, .5)
		var indices := _indices(); var ordered := true; var distinct := true; var seen := {}
		for index in indices.size():
			ordered = ordered and indices[index] == index % 3
		for row in _event_rows("attack_started"):
			var identity: int = row.data.input_id
			distinct = distinct and not seen.has(identity) and String(row.data.request_kind) == "fresh"
			seen[identity] = true
		_check(indices.size() >= 3 and ordered, "repeated taps preserve the distinct three-strike graph through natural restarts")
		_check(distinct and indices.size() <= press_count, "each admitted strike consumes one unique physical press")
		_check(count_settled - count_at_release <= 1 and _count("attack_started") == count_settled, "a stopped burst drains at most its single pending slot and stays stopped")
		_check(actor.weapon_phase == &"idle" and int(_state().chain_pending_input_id) == 0, "spam leaves no invisible backlog")
		measurements.tap_rate = rate; measurements.press_count = press_count; measurements.starts_at_release = count_at_release
		await _response_finish()
	for explicit_fresh in [false, true]:
		await _response_begin("one held edge Fresh mode " + str(explicit_fresh))
		if explicit_fresh:
			actor.melee_input_profile = load("res://combat_pc/resources/held_repeat.tres").duplicate(true)
			actor.melee_input_profile.mode = 0
		await _seconds({"attack":true}, 1.8)
		_check(_indices() == [0] and _queued_restart().is_empty(), "sustained Fresh hold produces one stroke and no restart request")
		await _response_finish()

func _response_pause_cases() -> void:
	for location in ["windup", "restart"]:
		if location == "restart" and selected_chain != RESPONSIVE: continue
		await _response_begin("tap fully inside hitpause " + location)
		if location == "restart": await _finisher_recovery(); await _late_age()
		else: await _start_step(0); await _step()
		actor.apply_hitpause(.10)
		var elapsed: float = _state().attack_step_elapsed
		await _step({"attack":true}); var pending_id: int = _state().chain_pending_input_id
		var remaining: float = _state().chain_pending_remaining
		await _step({}, 3)
		_near(float(_state().attack_step_elapsed), elapsed, .000000001, "local hitpause freezes the authored strike clock")
		_near(float(_state().chain_pending_remaining), remaining, .000000001, "release and paused callbacks do not drain or refresh captured input")
		await _seconds({}, 1.0)
		var uses := _event_rows("attack_started").filter(func(row): return pending_id > 0 and int(row.data.input_id) == pending_id)
		_check(uses.size() == (1 if selected_chain == RESPONSIVE else 0), "press and release entirely within pause survive once under the selected policy")
		await _response_finish()

func _response_restart_cases() -> void:
	for phase in ["windup", "active", "early_recovery"]:
		await _response_begin("finisher refuses premature restart " + phase)
		await _start_step(2)
		if phase == "windup": await _step()
		else: await _attack_phase("recovery" if phase == "early_recovery" else "active")
		await _step({"attack":true}); await _seconds({}, 1.0)
		_check(_indices() == [0, 1, 2] and _queued_restart().is_empty(), "a fresh finisher edge before late recovery is rejected without idle leakage")
		await _response_finish()
	for boundary in ["before_open", "first_open", "last_live", "after_completion"]:
		await _response_begin("finisher restart boundary " + boundary)
		await _finisher_recovery()
		var recovery: float = actor.melee_chain.steps[2].recovery_seconds
		var window: float = actor.melee_chain.fresh_restart_window_seconds
		if boundary == "before_open":
			await _until(func(): return float(_state().weapon_elapsed) + dt + .000000001 >= recovery - window, {}, .4)
		elif boundary == "first_open": await _late_age()
		elif boundary == "last_live": await _late_age(false)
		else: await _attack_phase("idle")
		var before := _state(); var prior: int = _count("attack_started")
		await _step({"attack":true}); var requested_id: int = _state().attack_input_id
		await _seconds({"attack":true}, .9)
		var expected: bool = boundary != "before_open"
		_check(_count("attack_started") == prior + (1 if expected else 0), "boundary fresh press has exactly the declared acceptance")
		_check(_queued_restart().size() == (1 if boundary in ["first_open", "last_live"] else 0), "live late-recovery and idle-start routes keep distinct request kinds")
		if expected:
			var starts := _event_rows("attack_started"); var last: Dictionary = starts.back()
			_check(int(last.data.step_index) == 0 and int(last.data.input_id) == requested_id and int(last.data.chain_serial) > int(starts[2].data.chain_serial), "accepted restart owns a new chain and preserves its one fresh identity")
			var finished := _event_rows("attack_finished").filter(func(row): return int(row.data.serial) == int(starts[2].data.serial))
			_check(finished.size() == 1 and not bool(finished[0].data.early_chain) and int(last.tick) >= int(finished[0].tick), "restart waits for full finisher completion without early recovery cancellation")
			var finish_frame: Dictionary = frames.filter(func(row): return int(row.tick) == int(finished[0].tick))[0]
			_check(float(finish_frame.before.weapon_elapsed) + dt + .000000001 >= recovery, "finisher retires only on a callback that reaches the unchanged recovery duration")
		measurements.press_before_phase = before.weapon_phase; measurements.press_before_recovery_age = before.weapon_elapsed
		await _response_finish()
	await _response_begin("late restart first slot rejects spam without refresh")
	await _finisher_recovery(); await _late_age()
	await _step({"attack":true})
	var first_id: int = _state().chain_pending_input_id; var remaining: float = _state().chain_pending_remaining
	await _step(); await _step({"attack":true})
	_check(first_id > 0 and int(_state().chain_pending_input_id) == first_id, "first late fresh request keeps the single pending slot")
	_near(float(_state().chain_pending_remaining), remaining - 2 * dt, .000000001, "queue-full rejection does not replenish the fixed deadline")
	_check(_event_rows("chain_input_rejected").any(func(row): return String(row.data.reason) == "queue_full"), "additional spam records a visible full-slot refusal")
	await _seconds({}, 1.0)
	_check(_indices() == [0, 1, 2, 0] and int(_event_rows("attack_started").back().data.input_id) == first_id, "only first queued restart commits and rejected spam cannot become Backhand")
	await _response_finish()
	await _response_begin("held charge never enters fresh restart route")
	actor.melee_input_profile = load("res://combat_pc/resources/held_charge.tres").duplicate(true)
	await _step({"attack":true})
	_check(await _until(func(): return _count("attack_started") == 2, {"attack":true}, 2.0), "candidate resource still permits the existing charged-thrust mode")
	await _attack_phase("recovery", {"attack":true})
	await _step(); await _step({"attack":true})
	await _seconds({"attack":true}, 1.0)
	_check(_count("attack_started") == 2 and _queued_restart().is_empty(), "fresh tap in charged recovery cannot enter the Fresh-only late restart route")
	await _response_finish()
	await _response_begin("held repeat never enters fresh restart route")
	actor.melee_input_profile = load("res://combat_pc/resources/held_repeat.tres").duplicate(true)
	await _step({"attack":true})
	await _until(func(): return _count("attack_started") >= 4, {"attack":true}, 2.0)
	_check(_indices() == [0, 1, 2, 0] and _queued_restart().is_empty(), "optional held repeat retains its own existing restart scheduler")
	_check(int(_state().attack_input_id) == 1, "held-derived requests do not masquerade as fresh physical identities")
	await _step(); await _seconds({}, .5)
	_check(_count("attack_started") == 4, "releasing held mode withdraws its optional synthetic work")
	await _response_finish()

func _response_gate_cases() -> void:
	for edge in ["last_valid_callback", "expiry_callback"]:
		await _response_begin("restart deadline boundary " + edge)
		await _finisher_recovery(); await _late_age(false)
		actor.set_weapon_permissions({"can_attack":false})
		await _step({"attack":true})
		var pending: int = _state().chain_pending_input_id
		var lead := 2.0 if edge == "last_valid_callback" else 1.0
		await _until(func(): return float(_state().chain_pending_remaining) <= lead * dt + .000000001, {}, .3)
		var before_remaining: float = _state().chain_pending_remaining
		actor.set_weapon_permissions()
		await _step(); await _seconds({}, .6)
		var uses := _event_rows("attack_started").filter(func(row): return int(row.data.input_id) == pending)
		_check(pending > 0 and uses.size() == (1 if edge == "last_valid_callback" else 0), "expiration is evaluated before gate reopening can commit a dead request")
		measurements.remaining_before_gate_reopen = before_remaining
		await _response_finish()
	for gate in ["attack_permission", "reuse_lock"]:
		for restore_early in [false, true]:
			await _response_begin("late request respects %s restore%s" % [gate, restore_early])
			if gate == "reuse_lock": actor.melee_chain.steps[2].reuse_lock_seconds = .51 if restore_early else .85
			await _finisher_recovery(); await _late_age(false)
			if gate == "attack_permission": actor.set_weapon_permissions({"can_attack":false})
			await _step({"attack":true}); var request_id: int = _state().attack_input_id
			_check(_count("attack_started") == 3, "late input cannot cross a closed control or reuse gate")
			await _seconds({}, .04 if restore_early else .23)
			if gate == "attack_permission": actor.set_weapon_permissions()
			await _seconds({}, 1.0)
			var uses := _event_rows("attack_started").filter(func(row): return int(row.data.input_id) == request_id)
			_check(uses.size() == (1 if restore_early else 0), "only a still-live request may commit after the independent gate opens")
			if not restore_early: _check(_count("chain_input_expired") == 1 and int(_state().chain_pending_input_id) == 0, "blocked request expires once and cannot leak into later idle")
			await _response_finish()
	await _response_begin("disabled control never captures a fresh late edge")
	await _finisher_recovery(); await _late_age(false)
	var identity: int = _state().attack_input_id
	actor.allow_input = false
	await _step({"attack":true}); await _seconds({"attack":true}, .3)
	actor.allow_input = true
	await _seconds({"attack":true}, .7)
	_check(int(_state().attack_input_id) == identity and _count("attack_started") == 3, "input-disabled press is not captured and does not become fresh when controls return")
	_check(_queued_restart().is_empty() and int(_state().chain_pending_input_id) == 0, "disabled input creates no pending restart authority")
	await _response_finish()

func _response_cancel_cases() -> void:
	for replacement in ["reset", "reconfigure", "roundtrip"]:
		await _response_begin("physical J remains held through late " + replacement)
		await _finisher_recovery(); await _late_age()
		_native_attack(true); await _step(null)
		_check(String(_state().chain_pending_kind) == "restart", "native J edge queues the late fresh identity")
		if replacement == "reset": actor.reset_actor(Vector2(100, 200))
		elif replacement == "reconfigure": actor.melee_chain = actor.melee_chain.duplicate(true)
		else:
			var original = actor.melee_chain; actor.melee_chain = null; actor.melee_chain = original
		await _seconds(null, 1.0)
		_check(_count("attack_started") == 3 and int(_state().chain_pending_input_id) == 0, "held native J cannot resurrect retired restart intent or manufacture a fresh edge")
		_native_attack(false); await _step(null)
		_native_attack(true); await _step(null)
		_check(_count("attack_started") == 4, "a separate physical release and new press still rearm ordinary admission")
		_native_attack(false); await _step(null)
		await _response_finish()
	for action in ["hurt", "shield", "roll", "jump", "reset", "forced", "chain_swap", "input_swap", "clear_buffers", "input_disabled"]:
		await _response_begin("pending late restart retired by " + action)
		await _finisher_recovery(); await _late_age()
		await _step({"attack":true}); var pending: int = _state().chain_pending_input_id
		_check(pending > 0 and String(_state().chain_pending_kind) == "restart", "cancellation probe begins with an admitted late restart")
		match action:
			"hurt": actor.receive_hit({"amount":1.0, "rollable":false, "impulse":Vector2.ZERO, "hitpause":0.0})
			"reset": actor.reset_actor(Vector2(100, 200))
			"forced": actor.finish_main_action()
			"chain_swap": actor.melee_chain = actor.melee_chain.duplicate(true)
			"input_swap": actor.melee_input_profile = load("res://combat_pc/resources/held_repeat.tres").duplicate(true)
			"clear_buffers": actor.clear_input_buffers()
			"input_disabled": actor.allow_input = false
			_: await _step({action:true})
		await _seconds({}, .2)
		actor.allow_input = true
		await _seconds({}, 1.0)
		_check(_count("attack_started") == 3 and int(_state().chain_pending_input_id) == 0, "replacement retires pending fresh identity with no delayed attack")
		_check(not _event_rows("attack_started").any(func(row): return int(row.data.input_id) == pending), "retired restart identity is never reused")
		await _response_finish()

func _response_callback_cases() -> void:
	for trigger in ["chain_input_queued", "attack_finished", "chain_reset"]:
		for replacement in ["reset", "hurt", "reconfigure", "roundtrip", "reenter"]:
			await _response_begin("restart callback %s %s" % [trigger, replacement])
			await _finisher_recovery(); await _late_age(false)
			var reached := {"count":0, "starts":0, "sequence":0}
			actor.movement_event.connect(func(label, data):
				var eligible: bool = String(label) == trigger
				if trigger == "chain_input_queued": eligible = eligible and String(data.get("kind", "")) == "restart"
				elif trigger == "attack_finished": eligible = eligible and int(data.get("step_index", -1)) == 2
				elif trigger == "chain_reset": eligible = eligible and String(data.get("reason", "")) == "completed"
				if not eligible or int(reached.count) > 0: return
				reached.count = 1; reached.starts = _count("attack_started"); reached.sequence = int(_state().attack_input_id)
				match replacement:
					"reset": actor.reset_actor(Vector2(300, 200), -1)
					"hurt": actor.receive_hit({"amount":1.0, "rollable":false, "impulse":Vector2.ZERO, "hitpause":0.0})
					"reconfigure": actor.melee_chain = actor.melee_chain.duplicate(true)
					"roundtrip":
						var original = actor.melee_chain; actor.melee_chain = null; actor.melee_chain = original
					"reenter": actor.physics_tick(dt, {"attack":true})
			)
			await _step({"attack":true}); await _seconds({}, 1.0)
			_check(int(reached.count) == 1, "the intended synchronous lifecycle callback was exercised")
			_check(_count("attack_started") == (4 if replacement == "reenter" else 3), "newer reset/configuration/hurt invalidates restart while recursive API cannot manufacture work")
			_check(int(_state().chain_pending_input_id) == 0, "callback completion leaves no stale pending owner")
			if replacement == "reenter": _check(int(_state().attack_input_id) == int(reached.sequence), "nested physics request is refused without minting an extra physical edge")
			await _response_finish()

func _response_contact_cases() -> void:
	for route in ["miss", "one_target", "two_targets", "wall"]:
		for direction in [-1, 1]:
			await _response_begin("responsive physical %s direction%d" % [route, direction])
			actor.reset_actor(actor.position, direction)
			var targets := []
			if route != "miss": targets.append(_target(actor.position + Vector2(direction * 31, 0), "First"))
			if route == "two_targets": targets.append(_target(actor.position + Vector2(direction * 39, 0), "Second"))
			if route == "wall": _box(actor.position + Vector2(direction * 18, -40), Vector2(2, 120))
			await _sync_geometry()
			await _start_step(0); await _step(); await _step({"attack":true})
			await _until(func(): return int(_state().attack_step_index) == 1, {}, .8)
			await _step(); await _step({"attack":true})
			await _seconds({}, 1.2)
			_check(_indices() == [0, 1, 2], "fresh early taps preserve three distinct strike identities with actual geometry")
			var expected_hits := 0 if route == "wall" else 3
			for target in targets: _check(target.hits == expected_hits, "each physical target takes exactly one admitted effect per step, with wall occlusion")
			_check(contact_receipts.size() == expected_hits * targets.size(), "adapter receipts equal actual applied target effects")
			var serials := {}; var input_ids := {}; var chains := {}
			for row in _event_rows("attack_started"):
				serials[int(row.data.serial)] = true; input_ids[int(row.data.input_id)] = true; chains[int(row.data.chain_serial)] = true
			_check(serials.size() == 3 and input_ids.size() == 3 and chains.size() == 1, "distinct physical presses and strike serials belong to one ordered episode")
			_check(_count("hitpause_started") == (3 if route in ["one_target", "two_targets"] else 0), "one confirmation pause per strike requires real unobstructed contacts")
			await _response_finish()

func _response_owner_cases() -> void:
	for grounded_ in [true, false]:
		for movement in ["movement_profile", "ground_response_agile", "air_response_agile"]:
			for chain in [BASELINE, RESPONSIVE]:
				selected_chain = chain
				await _response_begin("owner preservation %s %s %s" % ["ground" if grounded_ else "air", movement, "baseline" if chain == BASELINE else "candidate"], grounded_)
				actor.profile = load("res://combat_pc/resources/%s.tres" % movement).duplicate(true)
				actor.velocity = Vector2(100, 0 if grounded_ else -60)
				var first_frame := frames.size()
				await _start_step(0); await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
				var sequence := []
				for row in frames.slice(first_frame):
					sequence.append({"position":row.after.position, "velocity":row.after.velocity, "owner":row.after.main_action, "grounded":row.after.grounded, "weapon_phase":row.after.weapon_phase, "step":row.after.attack_step_index, "facing":row.after.facing})
				var key: String = str(grounded_) + movement
				if chain == BASELINE: movement_references[key] = sequence
				else: _check(sequence == movement_references[key], "same timed taps preserve exact real motion and action ownership across every authored phase")
				_check(_indices() == [0, 1, 2], "ground/air response selection retains the whole three-strike combo")
				await _response_finish()
	selected_chain = RESPONSIVE
