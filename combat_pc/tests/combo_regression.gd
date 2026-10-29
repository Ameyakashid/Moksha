extends "res://combat_pc/tests/shield_regression.gd"
## M9 independent authored chained-melee acceptance.
## Each recorded input invokes the production actor once in a real physics callback.

var strike_samples: Array[Dictionary] = []
var contact_receipts: Array[Dictionary] = []
var target_receipts: Array[Dictionary] = []
var target_nodes: Array[Node] = []

func _run() -> void:
	source_paths.append_array([
		"res://combat_pc/resources/shield_profile.gd", "res://combat_pc/resources/shield_profile.tres",
		"res://combat_pc/resources/melee_chain.gd", "res://combat_pc/resources/melee_step.gd",
		"res://combat_pc/resources/light_chain.tres", "res://combat_pc/tests/combo_regression.gd",
		"res://combat_pc/tests/shield_regression.gd", "res://combat_pc/components/shield_contact_adapter.gd",
		"res://combat_pc/fixtures/contact_target.gd", "res://combat_pc/fixtures/contact_target.tscn",
		"res://prop.gd", "res://scenes/props/crate.tscn", "res://resources/tuning/prop_tuning.gd", "res://resources/tuning/crate_default.tres"
	])
	for filename in DirAccess.get_files_at("res://combat_pc/visuals"):
		if filename.ends_with(".gd"): source_paths.append("res://combat_pc/visuals/" + filename)
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _combo_cases()
	_release_input()
	var hashes := {}; var stable := true
	for path in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Source changed during combo run; final rerun required")
	var output := {"milestone": 9, "selected_group": only_group, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(), "generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "One scheduled production call per actual physics callback with immediate before/after observations. Actual target/prop contacts, direct strike-authority probes and an explicit recursive-API refusal probe are recorded separately.",
		"numeric_source": "Original MOKSHA chain policy and resource values; no recovered Dead Cells queue, timing, damage or executable equivalence",
		"movement_profile": _definition(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _definition(load("res://combat_pc/resources/combat_profile.tres")),
		"shield_profile": _definition(load("res://combat_pc/resources/shield_profile.tres")),
		"melee_chain": _definition(load("res://combat_pc/resources/light_chain.tres"))}
	FileAccess.open("res://combat_pc/tests/combo_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("MOKSHA COMBO %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _combo_cases() -> void:
	if only_group in ["", "identity"]: await _identity_cases()
	if only_group in ["", "queue"]: await _queue_cases()
	if only_group in ["", "retention"]: await _retention_cases()
	if only_group in ["", "cancels"]: await _cancel_cases()
	if only_group in ["", "callbacks"]: await _callback_owner_cases()
	if only_group in ["", "resources"]: await _resource_and_lock_cases()
	if only_group in ["", "native"]: await _native_chain_cases()
	if only_group in ["", "motion"]: await _motion_cases()
	if only_group in ["", "props"]: await _prop_cases()
	if only_group in ["", "facing"]: await _facing_cases()
	if only_group in ["", "contact_lifetime"]: await _contact_lifetime_cases()
	if only_group in ["", "air_carrier"]: await _air_carrier_cases()
	if only_group in ["", "host_lifetime"]: await _host_lifetime_cases()
	if only_group in ["", "profile_limits"]: await _profile_limit_cases()
	if only_group in ["", "intersections"]: await _traversal_intersections()

func _combo_begin(label: String, at := Vector2(100, 200), floor_present := true, one_way_floor := false, chained := true) -> void:
	strike_samples = []; contact_receipts = []; target_receipts = []; target_nodes = []
	await _shield_begin(label, at, floor_present, one_way_floor)
	actor.melee_chain = load("res://combat_pc/resources/light_chain.tres").duplicate(true) if chained else null
	actor.strike_sample.connect(func(_source, snapshot):
		strike_samples.append({"tick": ticks, "engine_tick": Engine.get_physics_frames(), "snapshot": _safe(snapshot), "after_callbacks": _safe(_sample())}))
	actor.get_node("ContactAdapter").contact_confirmed.connect(func(_source, target, point, serial, kind):
		contact_receipts.append({"tick": ticks, "engine_tick": Engine.get_physics_frames(), "target": _safe(target), "position": _safe(point), "serial": serial, "kind": String(kind)}))

func _target(at: Vector2, label := "PassiveContact") -> Node:
	var target = load("res://combat_pc/fixtures/contact_target.tscn").instantiate()
	target.name = label; target.position = at
	world.add_child(target); target_nodes.append(target)
	target.struck.connect(func(payload): target_receipts.append({"tick": ticks, "engine_tick": Engine.get_physics_frames(), "target_name": label, "payload": _safe(payload)}))
	return target

func _sample() -> Dictionary:
	var snapshot: Dictionary = super._sample()
	var state: Dictionary = actor.telemetry()
	for key in state:
		if String(key).begins_with("combo") or String(key).begins_with("chain") or String(key).begins_with("melee") or String(key).begins_with("attack") or String(key).begins_with("weapon") or String(key).begins_with("strike") or String(key).ends_with("generation"):
			snapshot[key] = state[key]
	return snapshot

func _definition(value: Variant) -> Variant:
	if value is Resource:
		var result := {}
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: result[property.name] = _definition(value.get(property.name))
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_definition(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[str(key)] = _definition(value[key])
		return result
	return _safe(value)

func _finish() -> void:
	var saved_strikes := strike_samples.duplicate(true)
	var saved_contacts := contact_receipts.duplicate(true)
	var saved_targets := target_receipts.duplicate(true)
	var definition = _definition(actor.melee_chain)
	await super._finish()
	scenarios.back()["strike_samples"] = saved_strikes
	scenarios.back()["physical_contact_receipts"] = saved_contacts
	scenarios.back()["physical_target_receipts"] = saved_targets
	scenarios.back()["melee_chain"] = definition

func _state() -> Dictionary:
	return actor.telemetry()

func _attack_phase(phase: String, frame: Variant = {}, seconds := 1.0) -> bool:
	return await _until(func(): return String(actor.weapon_phase) == phase, frame, seconds)

func _follow_to(index: int, frame: Dictionary = {}) -> void:
	await _attack_phase("active", frame.merged({"attack": true}, true))
	await _step(frame)
	await _step(frame.merged({"attack": true}, true))
	await _until(func(): return int(_state().attack_step_index) == index and actor.weapon_phase == &"windup", frame.merged({"attack": true}, true), 1)

func _event_rows(label: String) -> Array:
	return events.filter(func(item): return item.event == label)

func _start_step(index: int) -> void:
	await _step({"attack": true})
	for next in range(1, index + 1): await _follow_to(next)

func _at_step_age(seconds: float, frame: Dictionary = {}) -> void:
	await _until(func(): return float(_state().attack_step_elapsed) + .000000001 >= seconds or actor.weapon_phase == &"idle", frame, 1.5)

func _identity_cases() -> void:
	for direction in [-1, 1]:
		for route in ["whiff", "one_target", "two_targets", "occluded"]:
			await _combo_begin("three distinct strikes %s direction%d" % [route, direction])
			actor.reset_actor(actor.position, direction)
			var targets := []
			if route != "whiff": targets.append(_target(actor.position + Vector2(direction * 31, 0), "First"))
			if route == "two_targets": targets.append(_target(actor.position + Vector2(direction * 39, 0), "Second"))
			if route == "occluded": _box(actor.position + Vector2(direction * 18, -40), Vector2(2, 120))
			await _sync_geometry()
			await _step({"attack": true})
			await _follow_to(1)
			await _follow_to(2)
			await _attack_phase("idle", {"attack": true})
			await _seconds({"attack": true}, .4)
			var starts := _event_rows("attack_started")
			_check(starts.size() == 3, "three deliberate presses produce three strikes and held input produces no fourth")
			var indices := []; var serials := []; var identities := []; var chains := []
			for row in starts:
				indices.append(int(row.data.step_index)); serials.append(int(row.data.serial)); identities.append(int(row.data.input_id)); chains.append(int(row.data.chain_serial))
			_check(indices == [0, 1, 2], "follow-ups commit the authored slash backhand finisher order")
			_check(serials.size() == 3 and serials[0] < serials[1] and serials[1] < serials[2], "every step receives a new strictly increasing strike serial")
			_check(identities.size() == 3 and identities[0] < identities[1] and identities[1] < identities[2], "each committed step consumes a distinct fresh input identity")
			_check(chains.size() == 3 and chains[0] > 0 and chains[0] == chains[1] and chains[1] == chains[2], "the connected sequence keeps one chain episode identity")
			var expected_hits := 0 if route == "occluded" else 3
			for target in targets: _check(target.hits == expected_hits, "each actual target receives one effect per eligible step, with terrain occlusion authoritative")
			_check(contact_receipts.size() == expected_hits * targets.size(), "adapter confirmation receipts match actual physical target applications")
			if route == "two_targets":
				var shared_scope := true
				for serial in serials:
					var rows := contact_receipts.filter(func(item): return int(item.serial) == int(serial))
					shared_scope = shared_scope and rows.size() == 2 and int(rows[0].engine_tick) == int(rows[1].engine_tick)
				_check(shared_scope and _count("hitpause_started") == 3, "both real targets share each admitted sample while contact pause is spent once per strike")
			elif route in ["whiff", "occluded"]: _check(_count("hitpause_started") == 0, "whiffs and terrain-blocked contact create no hit-confirmation pause")
			_check(int(_state().chain_pending_input_id) == 0 and int(_state().chain_next_step) < 0, "finisher completion retires the follow-up and retained next-step authority")
			measurements["step_indices"] = indices; measurements["strike_serials"] = serials; measurements["input_ids"] = identities
			measurements.merge(_trace_bounds()); await _finish()
	for chained in [false, true]:
		await _combo_begin("one held edge %s" % ("chain" if chained else "legacy fallback"), Vector2(100, 200), true, false, chained)
		await _seconds({"attack": true}, 1.2)
		_check(_count("attack_started") == 1 and actor.weapon_phase == &"idle", "one held edge finishes exactly one attack without repeat or charge")
		var starts := _event_rows("attack_started")
		if chained: _check(int(starts[0].data.step_index) == 0, "optional chain begins at its configured first step")
		else: _check(int(_state().attack_step_index) == -1, "null chain keeps the documented single-swing fallback identity")
		await _step(); await _step({"attack": true})
		_check(_count("attack_started") == 2, "a later distinct press starts exactly one new idle attack")
		await _finish()

func _queue_cases() -> void:
	for index in [0, 1]:
		for shortened in [false, true]:
			for edge in ["before_open", "first_open", "last_open", "first_closed"]:
				await _combo_begin("queue %s step%d %s" % [edge, index, "short_window" if shortened else "default_window"])
				var step = actor.melee_chain.steps[index]
				if shortened: step.followup_close_seconds = step.windup_seconds + step.active_seconds
				var boundary: float = step.followup_open_seconds if edge.ends_with("open") and edge in ["before_open", "first_open"] else step.followup_close_seconds
				var boundary_tick := ceili((boundary - .000000001) / dt)
				var sample_tick := maxi(0, boundary_tick - 1) if edge in ["before_open", "last_open"] else boundary_tick
				await _start_step(index)
				await _at_step_age(sample_tick * dt)
				var before: Dictionary = _state()
				var first_events := events.size()
				var expected_live: bool = actor.weapon_phase != &"idle"
				var accepts: bool = expected_live and float(before.attack_step_elapsed) + .000000001 >= step.followup_open_seconds and float(before.attack_step_elapsed) + .000000001 < step.followup_close_seconds
				params = {"step": index, "edge": edge, "short_window": shortened, "sample_age": before.attack_step_elapsed, "sample_live": expected_live, "expected_queue_acceptance": accepts}
				await _step({"attack": true})
				var new_events := events.slice(first_events)
				var queued := new_events.filter(func(item): return item.event == "chain_input_queued")
				_check((queued.size() == 1) == (accepts or not expected_live), "fresh edge classification uses the pre-advance live window or the separate idle request policy")
				if not queued.is_empty(): _check(String(queued[0].data.kind) == ("followup" if expected_live else "retained"), "idle retained intent and live follow-up keep distinct queue kinds")
				var identity: int = _state().attack_input_id
				await _seconds({"attack": true}, .65)
				var uses := _event_rows("attack_started").filter(func(item): return int(item.data.input_id) == identity)
				_check(uses.size() == (1 if accepts or not expected_live else 0), "the classified edge executes at most once and a rejected live edge never leaks into idle")
				if uses.size() == 1: _check(int(uses[0].data.step_index) == index + 1, "eligible follow-up or retained idle intent advances to the expected next step")
				_check(int(_state().chain_pending_input_id) == 0, "follow-up identity has no invisible backlog after the observed completion")
				await _finish()
	await _combo_begin("first queued edge owns slot without refresh from rapid presses")
	await _start_step(0); await _at_step_age(actor.melee_chain.steps[0].followup_open_seconds)
	await _step({"attack": true})
	var queued_id: int = _state().chain_pending_input_id
	var remaining: float = _state().chain_pending_remaining
	await _step(); await _step({"attack": true})
	_check(queued_id > 0 and int(_state().chain_pending_input_id) == queued_id, "a second fresh edge cannot replace the first valid pending request")
	_near(float(_state().chain_pending_remaining), remaining - 2 * dt, .00000001, "full-slot rejection does not refresh the pending deadline")
	await _until(func(): return int(_state().attack_step_index) == 1, {"attack": true})
	await _seconds({"attack": true}, .7)
	var starts := _event_rows("attack_started")
	_check(starts.size() == 2 and int(starts[1].data.input_id) == queued_id, "only the first pending identity commits and the rejected extra edge never starts a finisher")
	await _finish()
	for unlock in [true, false]:
		await _combo_begin("queued request temporary host denial %s" % ("unlocks" if unlock else "expires"))
		await _start_step(0); await _at_step_age(actor.melee_chain.steps[0].followup_open_seconds)
		await _step({"attack": true}); queued_id = _state().chain_pending_input_id
		actor.set_weapon_permissions({"can_attack": false})
		if unlock:
			await _seconds({}, .08)
			_check(int(_state().chain_pending_input_id) == queued_id, "temporary host denial preserves the same pending identity while its deadline remains")
			actor.set_weapon_permissions({"can_attack": true})
			await _until(func(): return int(_state().attack_consumed_input_id) == queued_id, {}, .5)
			_check(int(_state().attack_consumed_input_id) == queued_id and _count("attack_started") == 2, "restored host permission commits the still-valid request exactly once")
		else:
			await _seconds({}, actor.melee_chain.followup_buffer_seconds + .08)
			actor.set_weapon_permissions({"can_attack": true}); await _seconds({}, .4)
			_check(_count("attack_started") == 1 and int(_state().chain_pending_input_id) == 0, "expired denied request never becomes a delayed idle attack when the host unlocks")
			_check(_count("chain_input_expired") == 1, "the pending deadline produces one explicit expiration")
		await _finish()
	for phase in ["windup", "active", "recovery"]:
		await _combo_begin("finisher rejects fresh follow-up during " + phase)
		await _start_step(2); await _attack_phase(phase)
		await _step(); var old_count := _count("attack_started")
		await _step({"attack": true}); var rejected_id: int = _state().attack_input_id
		await _seconds({"attack": true}, .8)
		_check(_count("attack_started") == old_count and int(_state().chain_pending_input_id) == 0, "finisher consumes the live extra edge without wrapping or delayed restart")
		_check(_event_rows("attack_started").all(func(item): return int(item.data.input_id) != rejected_id), "rejected finisher identity never appears as a committed strike")
		await _finish()

func _retention_cases() -> void:
	for index in [0, 1]:
		for edge in ["before", "at", "after"]:
			await _combo_begin("natural idle retention %s deadline after step%d" % [edge, index])
			await _start_step(index); await _attack_phase("idle")
			var remaining: float = _state().chain_retention_remaining
			var age_ticks := ceili((remaining - .000000001) / dt)
			if edge == "before": age_ticks = maxi(0, age_ticks - 1)
			elif edge == "after": age_ticks += 1
			if age_ticks > 0: await _step({}, age_ticks)
			var live: bool = float(_state().chain_retention_remaining) > .000000001
			params = {"step": index, "edge": edge, "idle_ticks": age_ticks, "retention_before_press": _state().chain_retention_remaining}
			await _step({"attack": true})
			_check(int(_state().attack_step_index) == (index + 1 if live else actor.melee_chain.start_step), "idle input uses only unexpired natural-completion retention")
			await _seconds({"attack": true}, .7)
			_check(int(_state().chain_pending_input_id) == 0, "a retained idle start does not create a second pending request from the same press")
			await _finish()

func _enter_attack_window(index: int, window: String) -> void:
	await _start_step(index)
	if window == "windup": return
	await _attack_phase("active" if window == "active" else "recovery")
	if window == "recovery_open":
		var definition = actor.melee_chain.steps[index]
		await _until(func(): return float(_state().weapon_elapsed) + .000000001 >= definition.recovery_cancel_after, {}, .5)

func _cancel_cases() -> void:
	for index in [0, 1, 2]:
		for window in ["windup", "active", "recovery_entry", "recovery_open"]:
			if index == 0 and window == "recovery_entry": continue
			for action in ["roll", "jump", "air_jump", "shield", "drop", "dive", "climb", "wall"]:
				await _combo_begin("step%d %s requests %s" % [index, window, action], Vector2(100, 200), action not in ["air_jump", "dive", "wall"], action == "drop")
				if action == "climb":
					var sensor = CLIMBABLE.instantiate(); sensor.position = Vector2(100, 450); sensor.height = 400; sensor.width = 80; world.add_child(sensor)
					await _sync_geometry()
				if action == "wall":
					actor.allow_wall_run = true; _box(Vector2(118, 500), Vector2(20, 3000)); await _sync_geometry()
				await _enter_attack_window(index, window)
				var definition = actor.melee_chain.steps[index]
				var phase: String = actor.weapon_phase
				var phase_age: float = _state().weapon_elapsed
				var expected: bool = definition.windup_cancels.has(action) if phase == "windup" else (definition.active_cancels.has(action) if phase == "active" else definition.recovery_cancels.has(action) and phase_age + dt + .000000001 >= definition.recovery_cancel_after)
				params = {"step": index, "window": window, "action": action, "phase_before": phase, "phase_age_before": phase_age, "expected_cancel": expected}
				_check(phase == (window if window in ["windup", "active"] else "recovery"), "request begins in the intended physically advanced attack phase")
				var old_serial: int = actor.attack_serial
				var frame := {}
				match action:
					"roll": frame.roll = true
					"jump", "air_jump": frame.jump = true
					"shield": frame.shield = true
					"drop", "dive": frame.down = 1.0; frame.jump = true
					"climb": frame.up = 1.0
					"wall": frame.right = 1.0
				await _step(frame)
				var accepted: bool = actor.shield_phase != &"idle" if action == "shield" else String(actor.main_action) == action
				_check(accepted == expected, "per-step phase cancellation intersects actual movement and weapon admission")
				_check((actor.weapon_phase == &"idle") == expected, "accepted replacement retires the strike while denied input preserves it")
				if expected:
					_check(not actor.confirm_strike(old_serial, 987654, actor.position), "retired strike cannot be revived by a delayed confirmation")
					_check(int(_state().chain_pending_input_id) == 0 and int(_state().chain_next_step) < 0, "accepted non-melee action clears queued and retained chain authority")
					await _seconds(frame, .04)
					_check(actor.weapon_phase == &"idle" and actor.attack_serial == old_serial, "old melee cannot restart on subsequent replacement callbacks")
				measurements.merge(_trace_bounds()); await _finish()
	for index in [0, 1, 2]:
		for phase in ["windup", "active", "recovery"]:
			for action in ["hurt", "forced", "reset"]:
				await _combo_begin("step%d %s forced retirement %s" % [index, phase, action])
				await _enter_attack_window(index, phase)
				var serial: int = actor.attack_serial
				if action == "hurt": actor.receive_hit({"rollable": false, "impulse": Vector2(-120, -60), "hitpause": 0.0})
				elif action == "forced": actor.finish_main_action()
				else: actor.reset_actor(Vector2(300, 200), -1)
				_check(actor.weapon_phase == &"idle" and not actor.confirm_strike(serial, 987655, actor.position), "forced owner change retires the live strike in every chain phase")
				_check(int(_state().chain_pending_input_id) == 0 and int(_state().chain_next_step) < 0, "forced retirement clears chain intent and retention")
				await _seconds({}, .5)
				_check(actor.weapon_phase == &"idle" and actor.attack_serial == serial, "forced retirement leaves no latent follow-up over later callbacks")
				await _finish()

func _callback_owner_cases() -> void:
	for chained in [false, true]:
		for trigger in ["attack_started", "active_phase", "strike_noise", "strike_confirmed", "hitpause_started", "receiver", "contact_confirmed"]:
			for replacement in ["reset", "hurt", "forced"]:
				await _combo_begin("%s callback %s replaces %s" % ["chain" if chained else "fallback", trigger, replacement], Vector2(100, 200), true, false, chained)
				var first := _target(Vector2(128, 200), "First")
				var second := _target(Vector2(136, 200), "Second")
				await _sync_geometry()
				var seen := {"count": 0, "event_index": 0, "serial": 0, "tick": 0}
				var replace := func():
					if seen.count > 0: return
					seen.count = 1; seen.event_index = events.size(); seen.serial = actor.attack_serial; seen.tick = ticks
					if replacement == "reset": actor.reset_actor(Vector2(300, 200), -1)
					elif replacement == "hurt": actor.receive_hit({"rollable": false, "impulse": Vector2(-120, -60), "hitpause": 0.0})
					else: actor.begin_main_action(&"forced", {"can_move": false, "can_turn": false, "uses_inputs": false, "interruptible_by": ["*"]})
				if trigger == "receiver":
					first.struck.connect(func(_payload): replace.call()); second.struck.connect(func(_payload): replace.call())
				elif trigger == "contact_confirmed": actor.get_node("ContactAdapter").contact_confirmed.connect(func(_a, _b, _p, _s, _k): replace.call())
				elif trigger == "strike_noise": actor.noise_requested.connect(func(_at, kind, _loud, _source):
					if kind == &"strike": replace.call())
				else: actor.movement_event.connect(func(label, data):
					if String(label) == trigger or (trigger == "active_phase" and label == &"attack_phase_changed" and data.get("phase") == &"active"): replace.call())
				await _step({"attack": true})
				await _until(func(): return seen.count > 0, {}, .5)
				await _step({}, 3)
				_check(seen.count == 1, "the intended production callback was reached exactly once")
				var expected_applied := 1 if trigger in ["receiver", "contact_confirmed"] else 0
				_check(first.hits + second.hits == expected_applied, "effects applied before replacement remain counted and old unapplied effects stop immediately")
				_check(actor.weapon_phase == &"idle" and not actor.confirm_strike(int(seen.serial), 1234567, actor.position), "newer owner invalidates old strike authority inside nested callbacks")
				var desired_owner: String = "locomotion" if replacement == "reset" else replacement
				_check(String(actor.main_action) == desired_owner, "stale admission and phase continuations cannot overwrite the newer main owner")
				var stale_phases := events.slice(int(seen.event_index)).filter(func(row): return row.event == "attack_phase_changed")
				_check(stale_phases.is_empty(), "no old attack phase event is emitted after synchronous replacement")
				measurements["callback_tick"] = seen.tick; measurements["target_hits"] = first.hits + second.hits
				await _finish()

func _resource_and_lock_cases() -> void:
	await _combo_begin("independent reuse lock and pending deadline freeze through local pause")
	actor.melee_chain.steps[0].reuse_lock_seconds = .6
	await _start_step(0); await _step({"roll": true})
	actor.apply_hitpause(.08)
	var lock_before: float = _state().melee_reuse_lock_remaining
	await _step({"attack": true})
	var pending_before: float = _state().chain_pending_remaining
	var pending_id: int = _state().chain_pending_input_id
	await _step({}, 3)
	_near(float(_state().melee_reuse_lock_remaining), lock_before, .00000001, "local pause freezes the independent lock even after its original weapon has retired")
	_near(float(_state().chain_pending_remaining), pending_before, .00000001, "the separate paused pending-input deadline is neither consumed nor refreshed")
	_check(pending_id > 0 and int(_state().chain_pending_input_id) == pending_id, "pause preserves one captured input identity independently from its use lock")
	await _seconds({}, .7)
	_check(_count("attack_started") == 1, "an expired request still cannot execute when the longer use lock eventually opens")
	await _finish()
	await _combo_begin("idle retention freezes during pause before a retained fresh press")
	await _start_step(0); await _attack_phase("idle")
	var retention: float = _state().chain_retention_remaining
	actor.apply_hitpause(.08); await _step({}, 3)
	_near(float(_state().chain_retention_remaining), retention, .00000001, "local pause freezes natural-completion retention as its own clock")
	await _step({"attack": true}); var retained_id: int = _state().chain_pending_input_id
	await _until(func(): return int(_state().attack_step_index) == 1, {}, .5)
	_check(int(_state().attack_consumed_input_id) == retained_id and retained_id > 0, "the fresh retained press commits once after pause resumes")
	await _finish()
	await _combo_begin("episode snapshots all steps and later episode reads edited resource")
	var original_damage: float = actor.melee_chain.steps[0].damage
	var original_next_damage: float = actor.melee_chain.steps[1].damage
	var original_size: Vector2 = actor.melee_chain.steps[0].strike_size
	await _start_step(0); await _attack_phase("active")
	actor.melee_chain.steps[0].damage = original_damage + 7
	actor.melee_chain.steps[0].strike_size = Vector2(80, 30)
	actor.melee_chain.steps[1].damage = original_next_damage + 9
	var live: Dictionary = actor.strike_snapshot()
	_check(live.damage == original_damage and live.size == original_size, "in-place editing cannot change the geometry or power of an admitted strike")
	await _follow_to(1); await _attack_phase("active")
	_check(actor.strike_snapshot().damage == original_next_damage, "later steps in the same episode use the same deep configuration snapshot")
	await _attack_phase("idle"); await _seconds({}, actor.melee_chain.idle_retention_seconds + dt)
	await _step({"attack": true}); await _attack_phase("active")
	_check(int(_state().attack_step_index) == 0 and actor.strike_snapshot().damage == original_damage + 7, "a later new episode observes the resource edit without mixing old step identity")
	await _finish()
	await _combo_begin("replacing chain resource immediately withdraws old strike")
	await _start_step(0); await _attack_phase("active")
	var old_serial: int = actor.attack_serial
	actor.melee_chain = actor.melee_chain.duplicate(true)
	_check(not actor.is_strike_current(old_serial) and not actor.confirm_strike(old_serial, 998811, actor.position), "different resource identity withdraws old strike queries immediately")
	await _step(); await _seconds({}, .4)
	_check(actor.weapon_phase == &"idle" and int(_state().chain_pending_input_id) == 0 and _count("attack_started") == 1, "next validation cancels old resource ownership without restarting from stale input")
	await _finish()
	for replacement in ["roll", "jump", "forced"]:
		await _combo_begin("independent melee reuse lock survives " + replacement)
		actor.melee_chain.steps[0].reuse_lock_seconds = .6
		await _start_step(0)
		var serial: int = actor.attack_serial
		if replacement == "forced": actor.finish_main_action()
		else: await _step({replacement: true})
		_check(actor.weapon_phase == &"idle" and float(_state().melee_reuse_lock_remaining) > 0, "ordinary or forced replacement retires the strike while its independent use lock survives")
		await _step({"attack": true})
		await _seconds({}, actor.combat_profile.attack_buffer_seconds + .03)
		_check(actor.attack_serial == serial, "an early request cannot bypass the retained reuse lock")
		await _until(func(): return float(_state().melee_reuse_lock_remaining) <= .04, {}, .8)
		await _step({"attack": true})
		await _until(func(): return actor.attack_serial != serial, {"attack": true}, .2)
		_check(actor.attack_serial == serial + 1 and int(_state().attack_step_index) == 0, "one still-valid fresh request starts step zero when the actual independent lock opens")
		await _seconds({"attack": true}, .15)
		_check(actor.attack_serial == serial + 1, "held input cannot duplicate the newly admitted post-lock strike")
		await _finish()
	await _combo_begin("M8 shield lock remains authoritative for a queued chain start")
	actor.shield_profile.use_lock_seconds = .6
	await _step({"shield": true}); await _phase("hold")
	await _step({"shield": true, "roll": true})
	_check(actor.main_action == &"roll" and actor.shield_phase == &"idle" and float(_state().shield_lock_remaining) > 0, "physical hold-to-roll cancellation retains the independent shield use lock")
	await _until(func(): return float(_state().shield_lock_remaining) <= .04, {}, .8)
	await _step({"attack": true})
	_check(actor.weapon_phase == &"idle" and float(_state().shield_lock_remaining) > 0, "chain request cannot erase the remaining shield lock")
	await _until(func(): return actor.weapon_phase != &"idle", {"attack": true}, .2)
	_check(_count("attack_started") == 1 and int(_state().attack_step_index) == 0, "buffered melee starts once after the shield lock actually expires")
	await _finish()
	for action in ["hurt", "reset"]:
		await _combo_begin("melee reuse lock explicit clearing by " + action)
		actor.melee_chain.steps[0].reuse_lock_seconds = .6
		await _start_step(0)
		if action == "hurt": actor.receive_hit({"rollable": false, "hitpause": 0.0})
		else: actor.reset_actor(actor.position)
		_check(float(_state().melee_reuse_lock_remaining) == 0 and actor.weapon_phase == &"idle", "damage/reset clear the authored reuse lock and old strike together")
		await _finish()

func _native_chain_cases() -> void:
	for repress in [false, true]:
		await _combo_begin("parsed follow-up tap across local hitpause%s" % (" with rejected second press" if repress else ""))
		_key(KEY_J, true); await _step(null)
		_key(KEY_J, false); await _step(null)
		await _attack_phase("active", null)
		actor.apply_hitpause(.08)
		var age: float = _state().attack_step_elapsed
		_key(KEY_J, true); await _step(null)
		var identity: int = _state().chain_pending_input_id
		var remaining: float = _state().chain_pending_remaining
		_key(KEY_J, false); await _step(null)
		if repress:
			_key(KEY_J, true); await _step(null)
			_key(KEY_J, false); await _step(null)
		_check(identity > 0 and int(_state().chain_pending_input_id) == identity, "paused native edges retain one first-accepted follow-up identity")
		_near(float(_state().chain_pending_remaining), remaining, .00000001, "actor-local pause freezes the existing input deadline")
		_near(float(_state().attack_step_elapsed), age, .00000001, "actor-local pause freezes the step clock independently from input capture")
		await _until(func(): return int(_state().attack_step_index) == 1, null, .6)
		await _seconds(null, .6)
		var starts := _event_rows("attack_started")
		_check(starts.size() == 2 and int(starts[1].data.input_id) == identity, "the queued native tap resumes exactly once and rejected presses cannot become a finisher")
		await _finish()
	await _combo_begin("disabled native held input cannot manufacture a chain edge")
	actor.allow_input = false
	_key(KEY_J, true); await _step(null, 3)
	actor.allow_input = true
	await _step(null, 3)
	_check(_count("attack_started") == 0 and int(_state().chain_pending_input_id) == 0, "reenabling held input does not synthesize an attack request")
	_key(KEY_J, false); await _step(null)
	_key(KEY_J, true); await _step(null)
	_check(_count("attack_started") == 1 and int(_state().attack_step_index) == 0, "a genuine native release and fresh press restores normal chain entry")
	await _finish()
	for simultaneous in ["roll", "jump", "shield"]:
		await _combo_begin("simultaneous fresh " + simultaneous + " and melee")
		await _step({simultaneous: true, "attack": true})
		_check(actor.weapon_phase == &"idle" and _count("attack_started") == 0, "higher-priority accepted action wins the shared input callback")
		await _seconds({simultaneous: true, "attack": true}, .6)
		_check(_count("attack_started") == 0 and int(_state().chain_pending_input_id) == 0, "the losing edge cannot leak into a later unrelated idle attack")
		await _finish()

func _motion_cases() -> void:
	for gradient in [-1.0, -.5, .5, 1.0]:
		for direction in [-1, 1]:
			await _combo_begin("connected chain on slope %.1f direction%d" % [gradient, direction], Vector2(0, -absf(gradient) * 8 - .03), false)
			_terrain([Vector2(-1200, -1200 * gradient), Vector2(1200, 1200 * gradient)])
			await _sync_geometry(); await _until(func(): return actor.grounded)
			actor.reset_actor(actor.position, direction); await _step()
			var start_tick := ticks
			await _step(_direction(direction, {"attack": true}))
			await _follow_to(1, _direction(direction)); await _follow_to(2, _direction(direction))
			await _attack_phase("idle", _direction(direction))
			var supported_frames := frames.filter(func(row): return row.tick > start_tick)
			_check(supported_frames.all(func(row): return row.after.grounded), "the connected chain follows the actual slope without manufactured support loss")
			_check(supported_frames.all(func(row): return row.after.terrain_clearance_normal == null or float(row.after.terrain_clearance_normal) >= -.03), "every swept body remains outside the measured slope plane within unchanged solver skin")
			_check(supported_frames.all(func(row): return absf(float(row.after.velocity[0])) <= actor.profile.run_speed + .02), "slope contact cannot turn downward momentum into excess horizontal chain speed")
			await _seconds({}, .4)
			_near(actor.velocity.x, 0, .02, "neutral input brakes to rest after the chain on either slope direction")
			measurements.merge(_trace_bounds(start_tick, true)); await _finish()
	for direction in [-1, 1]:
		await _combo_begin("high-speed chain meets thin wall direction%d" % direction)
		actor.reset_actor(actor.position, direction)
		for definition in actor.melee_chain.steps: definition.active_ground_speed = 2000.0
		var wall_x: float = actor.position.x + direction * 28
		_box(Vector2(wall_x, 140), Vector2(2, 140))
		var target := _target(Vector2(wall_x + direction * 18, 200), "Occluded")
		await _sync_geometry()
		await _start_step(0); await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
		_check(frames.all(func(row): return (float(row.after.position[0]) - wall_x) * direction <= -actor.profile.body_width * .5 + .03), "actual fast per-step ground travel cannot tunnel through the thin solid wall")
		_check(target.hits == 0, "a target behind the same thin obstruction receives no chain effects")
		measurements.merge(_trace_bounds()); await _finish()
	await _combo_begin("complete chain retains safe small body under a low roof")
	await _step({"down": 1.0})
	_box(actor.position + Vector2(0, -26.3), Vector2(100, 12)); await _sync_geometry()
	await _start_step(0); await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
	_check(actor.crouched and actor.body_height == actor.profile.crouching_height, "every chain step respects actual blocked standing clearance")
	_check(strike_samples.all(func(row): return float(row.snapshot.origin[1]) >= float(row.after_callbacks.position[1]) - float(row.after_callbacks.body_height) + 2.9), "strike origin follows the actual small body rather than an assumed standing pose")
	measurements.merge(_trace_bounds()); _check(float(measurements.maximum_rectangle_depth) <= .03, "chain motion under the roof does not embed its collision body")
	await _finish()
	for hard in [false, true]:
		await _combo_begin("airborne full chain reaches %s floor" % ("hard" if hard else "soft"), Vector2(100, 0), false)
		_box(Vector2(0, 420), Vector2(2400, 40)); await _sync_geometry()
		actor.reset_actor(Vector2(100, 0)); actor.velocity.y = 300; actor.enable_hard_landing = hard
		await _start_step(0); await _follow_to(1); await _follow_to(2)
		var chain: int = _state().chain_serial
		await _until(func(): return actor.grounded, {}, 1.5)
		_check(_count("landed") == 1 and actor.grounded, "the chain reaches exactly one actual floor contact")
		_check(actor.air_jumps_left == actor.profile.air_jump_count and actor.air_roll_available and actor.dive_available, "real floor contact refills independent airborne budgets once")
		if hard:
			_check(actor.main_action == &"hard_land" and actor.weapon_phase == &"idle" and int(_state().chain_pending_input_id) == 0, "qualifying hard impact retires the live chain and pending follow-up")
		else:
			_check(actor.weapon_phase != &"idle" and int(_state().chain_serial) == chain, "ordinary soft landing preserves the live weapon episode")
		measurements.merge(_trace_bounds()); await _finish()
	await _combo_begin("natural jump completion preserves an accepted aerial follow-up")
	await _step({"jump": true}); await _step({"attack": true})
	await _follow_to(1); await _follow_to(2)
	await _until(func(): return actor.grounded, {}, 1.5)
	_check(_count("ground_jump") == 1 and _count("air_jump") == 0 and _count("landed") == 1, "the chain adds no jump or manufactured floor contact to the actual jump arc")
	var starts := _event_rows("attack_started")
	_check(starts.size() == 3 and int(starts[0].data.chain_serial) == int(starts[2].data.chain_serial), "soft main-owner completion cannot discard or replace the queued episode")
	await _finish()

func _prop_cases() -> void:
	for index in [0, 1, 2]:
		for direction in [-1, 1]:
			await _combo_begin("real crate step%d impulse and noise direction%d" % [index, direction])
			actor.reset_actor(actor.position, direction)
			await _start_step(index)
			var crate = load("res://scenes/props/crate.tscn").instantiate()
			crate.tuning = crate.tuning.duplicate(true); crate.tuning.launch_spin_range = Vector2.ZERO
			crate.position = actor.position + Vector2(direction * 31, -14); world.add_child(crate)
			var launch := {"count": 0, "position": Vector2.ZERO}
			crate.launched.connect(func(prop): launch.count += 1; launch.position = prop.global_position)
			var bus = root.get_node("NoiseBus"); bus.clear_history()
			await _sync_geometry(); await _until(func(): return launch.count > 0, {}, .6)
			_check(launch.count == 1 and crate.hit_count == 1 and crate.charge > 0, "the actual production crate receives one physical launch from this step")
			await _step({}, 2)
			var expected_speed: float = crate.tuning.launch_speed * actor.melee_chain.steps[index].prop_launch_scale
			_check(crate.linear_velocity.x * direction > expected_speed * .5 and (crate.position.x - Vector2(launch.position).x) * direction > 0, "step launch strength changes real Rigidbody momentum in the committed strike direction")
			var exact_noise := false
			for event in bus.event_history:
				if event.kind == &"prop_launch" and Vector2(event.origin).distance_to(Vector2(launch.position)) < .01: exact_noise = true
			_check(exact_noise, "prop launch noise uses its actual world contact-time origin")
			measurements["launch_position"] = _safe(launch.position); measurements["prop_velocity"] = _safe(crate.linear_velocity); measurements["expected_launch_speed"] = expected_speed
			await _finish()

func _facing_cases() -> void:
	for index in [0, 1, 2]:
		for direction in [-1, 1]:
			for edge in ["last_windup", "active_entry"]:
				await _combo_begin("direction edge %s step%d direction%d" % [edge, index, direction])
				actor.reset_actor(actor.position, direction)
				await _start_step(index)
				var entry_tick := ceili((float(actor.melee_chain.steps[index].windup_seconds) - .000000001) / dt)
				var pre_tick := maxi(0, entry_tick - (2 if edge == "last_windup" else 1))
				await _at_step_age(pre_tick * dt)
				params = {"step": index, "direction": direction, "edge": edge, "pre_age": _state().attack_step_elapsed}
				await _step(_direction(-direction))
				var expected: int = -direction if edge == "last_windup" else direction
				_check(actor.facing == expected, "direction admission uses the phase reached after this callback advances its clock")
				await _attack_phase("active")
				_check(actor.attack_facing == expected and int(actor.strike_snapshot().facing) == expected, "active contact latches the last facing actually permitted by the scheduler")
				await _finish()
	for index in [0, 1, 2]:
		for direction in [-1, 1]:
			await _combo_begin("step%d windup active recovery reversal direction%d" % [index, direction])
			actor.reset_actor(actor.position, direction)
			await _start_step(index)
			await _step(_direction(-direction))
			_check(actor.facing == -direction, "permitted windup facing follows fresh direction immediately")
			await _attack_phase("active", _direction(-direction))
			var serial: int = actor.attack_serial
			await _step(_direction(direction))
			_check(actor.facing == -direction and actor.attack_facing == -direction, "default active commitment refuses reversal of body and strike")
			await _attack_phase("recovery")
			await _step(_direction(direction))
			_check(actor.facing == direction and actor.attack_facing == -direction, "recovery body turn does not rotate the committed weapon direction")
			if index < 2:
				await _step(_direction(direction, {"attack": true}))
				await _until(func(): return actor.attack_serial > serial, _direction(direction), .5)
				_check(int(_state().attack_step_index) == index + 1 and actor.attack_facing == direction, "next-step admission resamples the now-permitted facing with a new serial")
			await _finish()
	for direction in [-1, 1]:
		await _combo_begin("configured active body turn retains strike latch direction%d" % direction)
		actor.reset_actor(actor.position, direction); actor.melee_chain.steps[0].allow_turn_active = true
		await _start_step(0); await _attack_phase("active")
		await _step(_direction(-direction))
		_check(actor.facing == -direction and actor.attack_facing == direction and int(actor.strike_snapshot().facing) == direction, "explicit active body turning cannot retroactively rotate committed contact geometry")
		await _finish()
	for index in [0, 1, 2]:
		await _combo_begin("step%d host move and turn permission intersection" % index)
		await _start_step(index)
		actor.set_weapon_permissions({"can_move": false, "can_turn": true, "move_scale": .25})
		var at: Vector2 = actor.position
		await _step({"left": 1.0})
		_check(actor.facing == -1 and actor.position.distance_to(at) < .03, "host move denial preserves independently allowed windup turning")
		_near(float(actor.weapon_permissions.move_scale), .25 * actor.melee_chain.steps[index].windup_move_scale, .000001, "windup movement scale composes with the external scale")
		await _attack_phase("active", {"left": 1.0})
		at = actor.position; await _step({"left": 1.0}, 2)
		_near(actor.position.x, at.x, .03, "host movement denial also blocks the authored active ground nudge")
		actor.set_weapon_permissions({"can_move": true, "can_turn": false})
		await _attack_phase("recovery", {"right": 1.0}); await _step({"right": 1.0})
		_check(actor.facing == -1, "recovery restores only turning also allowed by the host")
		await _finish()

func _contact_lifetime_cases() -> void:
	for change in ["source_relocation", "target_relocation", "target_removed", "target_queued_delete"]:
		await _combo_begin("resolved physical contact callback " + change)
		var target := _target(Vector2(130, 200), "Resolved")
		var skipped := _target(Vector2(300, 200), "SkippedPath")
		var target_reference: WeakRef = weakref(target)
		await _sync_geometry()
		var seen := {"count": 0, "point": Vector2.ZERO}
		actor.movement_event.connect(func(label, data):
			if label != &"strike_confirmed" or seen.count > 0: return
			seen.count = 1; seen.point = data.contact_position
			if change == "source_relocation": actor.global_position = Vector2(500, 200)
			elif change == "target_relocation": target_reference.get_ref().global_position = Vector2(500, 200)
			elif change == "target_removed": world.remove_child(target_reference.get_ref())
			else: target_reference.get_ref().queue_free())
		await _start_step(0); await _until(func(): return seen.count > 0, {}, .4)
		await _seconds({}, .15)
		var applied := target_receipts.filter(func(row): return row.target_name == "Resolved")
		_check(seen.count == 1 and applied.size() == (1 if change.ends_with("relocation") else 0), "only a surviving contact identity may receive its already-resolved frozen effect")
		_check(skipped.hits == 0, "observed callback relocation never creates a following strike sweep across the skipped world path")
		if not applied.is_empty(): _near(Vector2(applied[0].payload.contact_position[0], applied[0].payload.contact_position[1]).distance_to(seen.point), 0, .000001, "applied contact keeps its frozen physical point after relocation")
		if change == "target_removed": target.free()
		await _finish()
	await _combo_begin("live prop becomes ineligible inside strike confirmation")
	var crate = load("res://scenes/props/crate.tscn").instantiate(); crate.position = Vector2(131, 186); world.add_child(crate)
	await _sync_geometry()
	var revoked := [false]
	actor.movement_event.connect(func(label, _data):
		if label == &"strike_confirmed" and not revoked[0]: revoked[0] = true; crate.alive = false)
	await _start_step(0); await _until(func(): return revoked[0], {}, .4)
	_check(revoked[0] and crate.hit_count == 0 and contact_receipts.is_empty(), "a still-live prop withdrawn before application receives neither launch nor confirmed-effect feedback")
	await _finish()
	await _combo_begin("stale step snapshot and old confirmation cannot hit a new target")
	await _start_step(0); await _attack_phase("active")
	var old: Dictionary = actor.strike_snapshot().duplicate(true)
	await _follow_to(1); await _attack_phase("active")
	var target := _target(actor.position + Vector2(31, 0), "LateTarget")
	await _sync_geometry()
	var hits_before: int = target.hits
	actor.get_node("ContactAdapter").sample_strike(actor, old)
	_check(target.hits == hits_before and not actor.confirm_strike(int(old.serial), target.get_instance_id(), target.position), "a previous step payload and serial cannot borrow the new step's authority")
	await _finish()

func _air_carrier_cases() -> void:
	await _combo_begin("chain preserves spent air budgets and actual fall excursion", Vector2(100, -600), false)
	await _step({"jump": true}); await _step({"roll": true})
	await _until(func(): return float(_state().roll_elapsed) >= actor.combat_profile.roll_jump_cancel_after)
	await _step({"down": 1.0, "jump": true})
	_check(actor.main_action == &"dive" and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "the setup spends jump roll and dive through actual admitted airborne actions")
	await _step({"attack": true})
	var start_tick := ticks
	await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
	var air_frames := frames.filter(func(row): return row.tick >= start_tick)
	_check(air_frames.all(func(row): return row.after.air_jumps_left == 0 and not row.after.air_roll_available and not row.after.dive_available and not row.after.grounded), "every airborne step preserves the separately spent resources")
	_check(air_frames.all(func(row): return row.after.fall_history_active) and float(_state().fall_distance) > 100, "melee never erases the falling excursion or creates a hover support")
	_check(_count("landed") == 0 and _count("air_jump") == 1 and _count("dive_started") == 1, "chain advancement adds no fake landing or repeated traversal action")
	await _finish()
	for direction in [-1, 1]:
		await _combo_begin("paused moving carrier cannot sweep chain through skipped target direction%d" % direction, Vector2(100, 200), false)
		var carrier := _box(Vector2(100, 220), Vector2(500, 40), false, true)
		await _sync_geometry(); await _until(func(): return actor.grounded)
		actor.reset_actor(actor.position, direction); await _step()
		var target := _target(actor.position + Vector2(direction * 50, 0), "PausedPath")
		target.size = Vector2(2, 24); await _sync_geometry()
		await _start_step(0); await _attack_phase("active")
		var at: Vector2 = actor.position
		actor.apply_hitpause(.22)
		before_tick = func(delta):
			if actor.hitpause_remaining > 0: carrier.position.x += direction * 300 * delta
		await _until(func(): return actor.hitpause_remaining <= 0, {}, .4)
		_check((actor.position.x - at.x) * direction > 50 and actor.grounded, "the supported actor actually travels with its carrier while its attack is paused")
		await _step({}, 3)
		_check(target.hits == 0, "resume samples only live travel and cannot hit a narrow target skipped during pause transport")
		_near(float(_state().fall_distance), 0, .03, "supported carrier transport is excluded from free-fall history")
		measurements.merge(_trace_bounds()); await _finish()

func _host_lifetime_cases() -> void:
	await _combo_begin("recursive public tick refuses extra simulation and later fresh attack remains usable")
	var recursive := {"called": false, "before": {}, "after": {}}
	actor.movement_event.connect(func(label, _data):
		if label != &"attack_started" or recursive.called: return
		recursive.called = true; actor.finish_main_action()
		recursive.before = actor.telemetry().duplicate(true)
		actor.physics_tick(dt, {"attack": true, "attack_pressed": true})
		recursive.after = actor.telemetry().duplicate(true))
	await _step({"attack": true})
	_check(recursive.called and float(recursive.before.time) == float(recursive.after.time) and int(recursive.before.attack_input_id) == int(recursive.after.attack_input_id), "an explicit recursive API call cannot advance a second clock or capture another input inside this sample")
	_check(actor.weapon_phase == &"idle" and _count("attack_started") == 1, "synchronous forced retirement remains authoritative after rejected recursive admission")
	await _step(); await _step({"attack": true})
	_check(actor.weapon_phase == &"windup" and _count("attack_started") == 2 and int(_state().attack_input_id) == 2, "a later real callback still admits exactly one genuinely new strike")
	measurements["recursive_api_probe"] = _safe(recursive)
	await _finish()
	for index in [0, 1, 2]:
		for phase in ["windup", "active", "recovery"]:
			await _combo_begin("admission withdrawal preserves committed step%d %s" % [index, phase])
			await _start_step(index); await _attack_phase(phase)
			var serial: int = actor.attack_serial
			actor.set_weapon_permissions({"can_attack": false})
			await _step({"attack": true})
			_check(actor.attack_serial == serial and actor.weapon_phase != &"idle", "host attack admission denial does not retroactively cancel the committed step")
			await _seconds({}, .7)
			_check(actor.attack_serial == serial and actor.weapon_phase == &"idle" and int(_state().chain_pending_input_id) == 0, "the existing step finishes while future denied input expires without a new strike")
			await _finish()
	for revoke_at in ["queued", "finished"]:
		await _combo_begin("synchronous host denial at " + revoke_at + " boundary")
		var seen := {"count": 0}
		actor.movement_event.connect(func(label, data):
			var selected: bool = label == &"chain_input_queued" and data.get("kind") == &"start" if revoke_at == "queued" else label == &"attack_finished" and data.get("early_chain", false)
			if selected and seen.count == 0: seen.count = 1; actor.set_weapon_permissions({"can_attack": false}))
		await _step({"attack": true})
		if revoke_at == "finished":
			await _attack_phase("active"); await _step(); await _step({"attack": true})
			await _until(func(): return seen.count == 1, {}, .5)
		var identity: int = _state().chain_pending_input_id
		_check(seen.count == 1 and identity > 0 and actor.weapon_phase == &"idle", "callback admission withdrawal prevents the new commit while preserving its bounded request")
		await _seconds({}, .03); actor.set_weapon_permissions({"can_attack": true})
		await _step()
		_check(int(_state().attack_consumed_input_id) == identity and int(_state().attack_step_index) == (0 if revoke_at == "queued" else 1), "restored permission admits exactly the reserved step and input identity")
		await _finish()
	for airborne in [false, true]:
		await _combo_begin("ground versus air cancellation entry %s" % ("air" if airborne else "ground"), Vector2(100, 200), not airborne)
		actor.melee_chain.steps[0].windup_cancels = PackedStringArray(["jump" if airborne else "air_jump"])
		await _start_step(0); await _step({"jump": true})
		_check(actor.weapon_phase == &"windup" and _count("ground_jump") == 0 and _count("air_jump") == 0, "the opposite jump-kind permission cannot authorize this actual supported or airborne request")
		await _finish()
	await _combo_begin("late retained idle request survives retention expiry under host lock")
	await _start_step(0); await _attack_phase("idle")
	await _until(func(): return float(_state().chain_retention_remaining) <= dt * 1.5)
	actor.set_weapon_permissions({"can_attack": false}); await _step({"attack": true})
	var identity: int = _state().chain_pending_input_id
	await _step({}, 3)
	_check(float(_state().chain_retention_remaining) == 0 and int(_state().chain_pending_input_id) == identity and identity > 0, "retention expiry cannot erase the distinct still-valid reserved input")
	actor.set_weapon_permissions({"can_attack": true}); await _step()
	_check(int(_state().attack_step_index) == 1 and int(_state().attack_consumed_input_id) == identity, "the latched retained request cannot turn into a new step-zero episode after expiry")
	await _finish()

func _profile_limit_cases() -> void:
	await _combo_begin("same-value chain assignment is inert during a live strike")
	await _start_step(0); await _attack_phase("active")
	var original_resource = actor.melee_chain
	var current_serial: int = actor.attack_serial
	actor.melee_chain = original_resource
	_check(actor.is_strike_current(current_serial), "assigning the identical resource cannot withdraw a live strike")
	await _step()
	_check(actor.attack_serial == current_serial and actor.weapon_phase == &"active", "inert same-value assignment preserves the existing phase and identity")
	await _finish()
	await _combo_begin("chain reconfiguration without melee context preserves active shield")
	await _open_shield()
	var shield_serial: int = actor.shield_serial
	var shield_lock: float = _state().shield_lock_remaining
	actor.melee_chain = actor.melee_chain.duplicate(true)
	await _step({"shield": true})
	_check(actor.shield_serial == shield_serial and actor.shield_phase == &"parry" and _count("shield_cancelled") == 0, "unrelated melee configuration changes cannot silently retire an admitted shield")
	_near(float(_state().shield_lock_remaining), shield_lock - dt, .00000001, "shield lock retains its own independent clock across unrelated configuration assignment")
	await _finish()
	for active in [false, true]:
		await _combo_begin("configuration assignment round trip in one callback %s" % ("active" if active else "pending"), Vector2(100, 200), true, false, active)
		var original = actor.melee_chain
		if active: await _start_step(0); await _attack_phase("active")
		else: actor.set_weapon_permissions({"can_attack": false}); await _step({"attack": true})
		var serial: int = actor.attack_serial
		actor.melee_chain = null if active else load("res://combat_pc/resources/light_chain.tres").duplicate(true)
		actor.melee_chain = original
		if active: _check(not actor.is_strike_current(serial), "restoring the same resource identity cannot revive a withdrawn committed strike epoch")
		actor.set_weapon_permissions({"can_attack": true}); await _seconds({}, .4)
		_check(actor.weapon_phase == &"idle" and actor.attack_serial == serial and int(_state().chain_pending_input_id) == 0, "same-callback configuration restoration cannot revive old pending or live melee authority")
		await _finish()
	for trigger in ["strike_noise", "active_phase"]:
		await _combo_begin("minimum active phase retains contact after " + trigger + " pause")
		actor.melee_chain.steps.resize(1)
		var definition = actor.melee_chain.steps[0]
		definition.next_step = -1; definition.windup_seconds = .001; definition.active_seconds = .001; definition.recovery_seconds = .001
		var target := _target(Vector2(131, 200), "PausedShortPhase")
		await _sync_geometry()
		var paused := [false]
		if trigger == "strike_noise": actor.noise_requested.connect(func(_at, kind, _loud, _source):
			if kind == &"strike" and not paused[0]: paused[0] = true; actor.apply_hitpause(.08))
		else: actor.movement_event.connect(func(label, data):
			if label == &"attack_phase_changed" and data.get("phase") == &"active" and not paused[0]: paused[0] = true; actor.apply_hitpause(.08))
		await _step({"attack": true}); await _seconds({}, .3)
		_check(paused[0] and target.hits == 1, "entry feedback pause cannot consume a short active phase's only physical contact opportunity")
		_check(actor.weapon_phase == &"idle" and _count("attack_started") == 1, "short-phase residual clocks still finish one finite strike after pause and contact")
		await _finish()
	await _combo_begin("fallback pending intent is retired across a configuration round trip", Vector2(100, 200), true, false, false)
	var unexpected := _target(Vector2(131, 200), "RetiredFallback")
	await _sync_geometry()
	actor.set_weapon_permissions({"can_attack": false}); await _step({"attack": true})
	actor.melee_chain = load("res://combat_pc/resources/light_chain.tres").duplicate(true); await _step()
	actor.melee_chain = null; actor.set_weapon_permissions({"can_attack": true}); await _seconds({}, .4)
	_check(_count("attack_started") == 0 and unexpected.hits == 0, "restoring the fallback cannot revive a press captured under a retired configuration")
	await _step({"attack": true}); await _until(func(): return unexpected.hits == 1, {}, .5)
	_check(_count("attack_started") == 1 and unexpected.hits == 1, "a genuinely new fallback press still admits its normal physical contact")
	await _finish()
	for valid in [false, true]:
		await _combo_begin("short phase resource %s minimum" % ("at" if valid else "below"))
		actor.melee_chain.steps.resize(1)
		var definition = actor.melee_chain.steps[0]
		definition.next_step = -1
		definition.windup_seconds = .001 if valid else .0005
		definition.active_seconds = .001 if valid else .0005
		definition.recovery_seconds = .001 if valid else .0005
		var target := _target(Vector2(131, 200), "ShortPhase")
		await _sync_geometry(); await _step({"attack": true}); await _seconds({}, .2)
		_check(_count("attack_started") == (1 if valid else 0), "phase validation accepts the declared minimum and safely refuses a subminimum resource")
		_check(target.hits == (1 if valid else 0), "an admitted short active phase receives one real contact sample without a skipped hit or duplicate")
		_check(frames.all(func(row): return float(row.after.weapon_phase_progress) >= 0 and float(row.after.weapon_phase_progress) <= 1), "presentation phase progress stays bounded while residual simulation time carries")
		_check(actor.weapon_phase == &"idle", "oversized-per-phase callback residual reaches a finite settled owner")
		await _finish()
	await _combo_begin("same actor reset cycles preserve identity without sharing runtime resource state")
	var resource_before = _definition(actor.melee_chain)
	var serials := []; var inputs := []; var chains := []
	for cycle in range(6):
		actor.reset_actor(Vector2(100, 200), 1 if cycle % 2 == 0 else -1)
		await _step(); await _start_step(0); await _follow_to(1); await _follow_to(2)
		serials.append(actor.attack_serial); inputs.append(int(_state().attack_consumed_input_id)); chains.append(int(_state().chain_serial))
		await _attack_phase("idle"); await _step()
	var monotonic := true
	for index in range(1, serials.size()): monotonic = monotonic and serials[index] > serials[index - 1] and inputs[index] > inputs[index - 1] and chains[index] > chains[index - 1]
	_check(monotonic, "repeated reset and complete reuse never recycle strike input or chain identities")
	_check(_definition(actor.melee_chain) == resource_before, "runtime progression and reset never write into the shared configuration resource")
	_check(actor.weapon_phase == &"idle" and int(_state().chain_pending_input_id) == 0, "reused actor settles without an orphaned request or active strike")
	measurements["cycle_serials"] = serials; measurements["cycle_input_ids"] = inputs; measurements["cycle_chain_ids"] = chains
	await _finish()

func _traversal_intersections() -> void:
	await _combo_begin("one-way drop cleanup survives replacement by a complete chain", Vector2(100, 200), true, true)
	await _step({"down": 1.0, "jump": true})
	_check(actor.main_action == &"drop" and bool(_state().drop_exception_active), "the actual support is ignored through the existing targeted drop admission")
	await _step({"attack": true})
	_check(actor.weapon_phase == &"windup" and bool(_state().drop_exception_active), "melee may replace the finite drop owner without prematurely clearing its safety cleanup")
	var start_tick := ticks
	await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
	var unsafe_expansion := frames.filter(func(row): return row.tick >= start_tick and row.after.drop_exception_active and float(row.after.body_height) > actor.profile.crouching_height)
	_check(unsafe_expansion.is_empty() and not bool(_state().drop_exception_active), "every overlapping cleanup tick keeps the required small body and eventually restores the exact platform")
	_check(_count("air_jump") == 0 and _count("dive_started") == 0, "the consumed drop chord never becomes a jump or dive during chaining")
	await _finish()
	await _combo_begin("removed support during paused active step resumes ordinary fall", Vector2(100, 200), false)
	var support := _box(Vector2(100, 220), Vector2(500, 40), false, true)
	await _sync_geometry(); await _until(func(): return actor.grounded)
	await _start_step(0); await _attack_phase("active")
	var landings_before_removal := _count("landed")
	actor.apply_hitpause(.06); support.queue_free()
	await _step(); await _step({"attack": true})
	await _until(func(): return actor.hitpause_remaining <= 0); await _step({}, 3)
	_check(not actor.grounded and actor.velocity.y > 0, "support removal cannot leave the resumed attack artificially grounded or suspended")
	await _until(func(): return int(_state().attack_step_index) == 1, {}, .5)
	_check(_count("landed") == landings_before_removal and int(_state().attack_step_index) == 1, "a still-valid queued follow-up survives support loss without an extra landing")
	await _finish()
	for attacking in [false, true]:
		await _combo_begin("ledge geometry %s" % ("refuses automatic catch during chain" if attacking else "idle physical control"), Vector2(100, 200), false)
		_box(Vector2(148, 210), Vector2(80, 80)); await _sync_geometry()
		actor.reset_actor(Vector2(100, 200))
		if attacking:
			await _step({"attack": true}); await _seconds({"right": 1.0}, .25)
			_check(frames.all(func(row): return row.after.weapon_phase == "idle" or row.after.main_action != "ledge"), "automatic ledge detection cannot retire a committed weapon step")
		else:
			await _until(func(): return actor.main_action == &"ledge", {"right": 1.0}, .5)
			_check(actor.main_action == &"ledge", "the same real geometry admits a normal ledge catch without weapon ownership")
		measurements.merge(_trace_bounds()); await _finish()
	for entry in ["rising", "apex", "falling"]:
		await _combo_begin("airborne chain entry during " + entry, Vector2(100, -400), false)
		await _step({"jump": true})
		if entry == "apex": await _until(func(): return absf(actor.velocity.y) <= 45, {"jump": true}, .5)
		elif entry == "falling": await _until(func(): return actor.velocity.y >= 100, {"jump": true}, .8)
		params["entry_vertical_speed"] = actor.velocity.y
		await _step({"attack": true})
		var air_start_tick := ticks
		await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
		var falling := frames.filter(func(row): return row.tick > air_start_tick and float(row.before.velocity[1]) >= 0)
		var error := 0.0
		for row in falling:
			var expected: float = minf(float(row.before.velocity[1]) + actor.profile.gravity * actor.profile.falling_gravity_multiplier * dt, actor.profile.terminal_fall_speed)
			error = maxf(error, absf(float(row.after.velocity[1]) - expected))
		_check(falling.size() >= 5 and error <= .002, "each falling callback retains the ordinary profile gravity rather than a chain hover or lift")
		_check(actor.air_jumps_left == 0 and actor.air_roll_available and actor.dive_available and _count("landed") == 0, "three steps do not alter independent air budgets or manufacture a support contact")
		measurements["maximum_fall_velocity_error"] = error; await _finish()
