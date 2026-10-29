extends "res://combat_pc/tests/climb_regression.gd"
## M5 independent real-physics wall acceptance. All numeric policy is MOKSHA-authored.
## Historical developer footage establishes approach/run/outward-kick intent only.

class PhysicsRecorder extends Node:
	var capture := Callable()
	var enabled := true
	func _physics_process(_delta: float) -> void:
		if enabled and capture.is_valid(): capture.call()

var recorder: PhysicsRecorder
var tracked_bodies: Array[Node2D] = []
var pending_native_events: Array[Dictionary] = []
var recorded_tick := -1
var sampling_gaps: Array[Dictionary] = []

func _run() -> void:
	production_paths.append_array([
		"res://combat_pc/tests/combat_regression.gd", "res://combat_pc/tests/traversal_regression.gd",
		"res://combat_pc/tests/climb_regression.gd", "res://combat_pc/tests/wall_regression.gd",
		"res://combat_pc/components/climbable.gd", "res://combat_pc/components/climbable.tscn"
	])
	for path in production_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _wall_cases()
	_release_native_input()
	var hashes := {}
	for path in production_paths: hashes[path] = FileAccess.get_sha256(path)
	var stable := true
	for path in starting_hashes: stable = stable and starting_hashes[path] == hashes[path]
	if not stable: failures.append("Source files changed during wall run; final rerun required")
	var report := {
		"milestone": 5, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(),
		"generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "Actual Godot physics with post-actor per-physics recording, production sweeps, per-shape queries and parsed native keyboard events",
		"numeric_source": "Authored MOKSHA wall policy; no recovered Dead Cells timing, exhaustion rule or executable parity",
		"movement_profile": _resource_values(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _resource_values(load("res://combat_pc/resources/combat_profile.tres"))
	}
	FileAccess.open("res://combat_pc/tests/wall_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  "))
	print("MOKSHA WALL %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _wall_cases() -> void:
	await _wall_gates_and_geometry()
	await _wall_run_and_kick()
	await _wall_interruptions()
	await _wall_contact_lifecycle()
	await _wall_ledge_handoff()
	await _wall_native_pause_and_grace()
	await _wall_rearm_and_reuse()
	await _wall_extra_permissions_and_cleanup()
	await _wall_connected_budgets_and_landing()
	await _wall_damage_locks_and_thin_geometry()
	await _wall_rate_and_additional_geometry()
	await _wall_final_intersections()
	await _wall_native_recontact_jump()
	await _wall_denied_entry_keeps_air_jump()
	await _wall_supported_rectangle_variants()
	await _wall_native_regrab_boundary()
	await _wall_queued_tap_and_guard_lifecycle()
	await _wall_waiting_gate_recheck()

func _begin(label: String, at := Vector2(100, 200), floor_present := true) -> void:
	_release_native_input()
	name_ = label; frames = []; assertions = []; events = []; strikes = []; measurements = {}
	start_failures = failures.size(); start_checks = checks
	tracked_bodies = []; one_way_bodies = []; pending_native_events = []; sampling_gaps = []; recorded_tick = -1
	world = Node2D.new(); root.add_child(world)
	if floor_present: _surface(Vector2(-1000, 200), Vector2(3000, 40))
	actor = PLAYER.instantiate(); actor.position = at; actor.automatic_physics = false
	actor.profile = actor.profile.duplicate(true); actor.combat_profile = actor.combat_profile.duplicate(true)
	world.add_child(actor)
	actor.movement_event.connect(func(event_name: StringName, payload: Dictionary):
		events.append({"event": String(event_name), "tick": driver.ticks + (1 if Engine.is_in_physics_frame() else 0) if is_instance_valid(driver) else 0, "data": _safe(payload)}))
	actor.strike_sample.connect(func(_source: Node, snapshot: Dictionary):
		strikes.append({"tick": driver.ticks + (1 if Engine.is_in_physics_frame() else 0) if is_instance_valid(driver) else 0, "sample": _safe(snapshot)}))
	contact = actor.get_node("ContactAdapter")
	driver = PhysicsDriver.new(); driver.actor = actor; driver.process_physics_priority = 20; world.add_child(driver)
	recorder = PhysicsRecorder.new(); recorder.capture = _capture_physics; recorder.process_physics_priority = 90; world.add_child(recorder)
	await _step({}, 2)

func _capture_physics() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(driver): return
	if recorded_tick >= 0 and driver.ticks != recorded_tick + 1:
		sampling_gaps.append({"previous": recorded_tick, "current": driver.ticks})
	recorded_tick = driver.ticks
	var snapshot: Dictionary = actor.telemetry()
	snapshot["tick"] = driver.ticks; snapshot["input"] = _safe(driver.frame)
	snapshot["native_events"] = pending_native_events.duplicate(true); pending_native_events.clear()
	var geometry: Array[Dictionary] = []
	for body in tracked_bodies:
		if not is_instance_valid(body): continue
		var sample := {"id": body.get_instance_id(), "name": String(body.name), "node_origin": body.global_position, "node_rotation": body.global_rotation}
		if body is PhysicsBody2D:
			var committed: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
			sample["server_origin"] = committed.origin; sample["server_rotation"] = committed.get_rotation()
		geometry.append(sample)
	snapshot["geometry"] = geometry
	snapshot["shape_contacts"] = _per_shape_contacts()
	frames.append(_safe(snapshot))

func _step(frame: Variant = {}, count := 1) -> void:
	driver.frame = frame
	for _i in count:
		var target = driver.ticks + 1
		while driver.ticks < target:
			await physics_frame
			await process_frame

func _finish() -> void:
	measurements["physics_samples"] = frames.size()
	measurements["sampling_gaps"] = sampling_gaps.duplicate(true)
	if not sampling_gaps.is_empty(): _check(false, "post-actor recorder must observe every actual physics tick exactly once")
	_release_native_input()
	recorder.enabled = false
	await super._finish()
	recorder = null

func _key(code: Key, pressed: bool) -> void:
	var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	pending_native_events.append({"physical_keycode": int(code), "pressed": pressed, "after_tick": driver.ticks if is_instance_valid(driver) else -1})
	Input.parse_input_event(event)

func _release_native_input() -> void:
	for code in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE, KEY_C, KEY_J, KEY_SHIFT]:
		var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = false
		Input.parse_input_event(event)
	for action in ["cp_left", "cp_right", "cp_up", "cp_down", "cp_jump", "cp_roll", "cp_attack"]:
		if InputMap.has_action(action): Input.action_release(action)

func _per_shape_contacts() -> Array[Dictionary]:
	var query = PhysicsShapeQueryParameters2D.new(); var shape = RectangleShape2D.new()
	shape.size = Vector2(actor.profile.body_width - .12, actor.body_height - .12)
	query.shape = shape; query.transform = Transform2D(0, actor.global_position + Vector2(0, -actor.body_height * .5))
	query.collision_mask = actor.terrain_mask; query.exclude = [actor.get_rid()]
	var result: Array[Dictionary] = []
	for overlap in actor.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body = overlap.collider as CollisionObject2D
		if body == null: continue
		var shape_index: int = overlap.shape
		var owner_id: int = body.shape_find_owner(shape_index)
		var one_way := body.is_shape_owner_one_way_collision_enabled(owner_id)
		var current_overlap := true
		for local_index in body.shape_owner_get_shape_count(owner_id):
			if body.shape_owner_get_shape_index(owner_id, local_index) == shape_index:
				current_overlap = _current_rect_overlap(body, owner_id, local_index)
		result.append({"body_id": body.get_instance_id(), "body_name": String(body.name), "shape": shape_index, "one_way": one_way, "committed_query_overlap": true, "current_geometry_overlap": current_overlap})
	# Transport is reconciled to a body's already-updated Node pose after the
	# solver's committed pose was used. Check that actual pending geometry too,
	# rather than hiding a moving support behind a blanket RID exclusion.
	for body in tracked_bodies:
		if not is_instance_valid(body) or not body is PhysicsBody2D or (body.collision_layer & actor.terrain_mask) == 0: continue
		for owner_id in body.get_shape_owners():
			if body.is_shape_owner_disabled(owner_id): continue
			for local_index in body.shape_owner_get_shape_count(owner_id):
				var shape_index: int = body.shape_owner_get_shape_index(owner_id, local_index)
				if result.any(func(item): return int(item.body_id) == body.get_instance_id() and int(item.shape) == shape_index): continue
				if _current_rect_overlap(body, owner_id, local_index, false):
					result.append({"body_id": body.get_instance_id(), "body_name": String(body.name), "shape": shape_index, "one_way": body.is_shape_owner_one_way_collision_enabled(owner_id), "committed_query_overlap": false, "current_geometry_overlap": true})
	return result

func _current_rect_overlap(body: PhysicsBody2D, owner_id: int, local_index: int, unknown := true) -> bool:
	var shape = body.shape_owner_get_shape(owner_id, local_index)
	var transform_: Transform2D = body.global_transform * body.shape_owner_get_transform(owner_id)
	if not shape is RectangleShape2D or absf(transform_.x.y) > .000001 or absf(transform_.y.x) > .000001: return unknown
	var bounds: Rect2 = transform_ * shape.get_rect()
	var actor_bounds = Rect2(actor.global_position + Vector2(-actor.profile.body_width * .5 + .06, -actor.body_height + .06), Vector2(actor.profile.body_width - .12, actor.body_height - .12))
	return bounds.intersects(actor_bounds)

func _has_solid_overlap() -> bool:
	return _per_shape_contacts().any(func(contact_: Dictionary): return not bool(contact_.one_way) and bool(contact_.get("current_geometry_overlap", true)))

func _trace_has_solid_overlap() -> bool:
	return frames.any(func(frame: Dictionary): return frame.get("shape_contacts", []).any(func(contact_: Dictionary): return not bool(contact_.one_way) and bool(contact_.get("current_geometry_overlap", true))))

func _wall_body(direction := 1, face := 112.0, top := -500.0, bottom := 650.0, width := 32.0, one_way := false) -> Node2D:
	var body = _surface(Vector2(face if direction > 0 else face - width, top), Vector2(width, bottom - top), one_way)
	tracked_bodies.append(body)
	return body

func _wall_phase() -> String:
	return String(actor.telemetry().get("wall_phase", actor.action_phase))

func _setup_wall(label: String, direction := 1) -> Node2D:
	await _begin(label, Vector2(100, 280), false)
	actor.allow_wall_run = true
	var body = _wall_body(direction, 112 if direction > 0 else 88)
	await _step({}, 2)
	await _until(func(): return actor.main_action == &"wall", _direction(direction), .6)
	_check(actor.main_action == &"wall", "toward input establishes an actual supported airborne wall action")
	return body

func _wall_gates_and_geometry() -> void:
	for direction in [-1, 1]:
		await _begin("locked wall ability preserves ordinary air movement %d" % direction, Vector2(100, 280), false)
		_wall_body(direction, 112 if direction > 0 else 88)
		await _seconds(_direction(direction), .25)
		_check(not actor.allow_wall_run and actor.main_action != &"wall", "reusable actor defaults locked until the wall ability is explicitly granted")
		_check(not _trace_has_solid_overlap(), "locked wall approach still obeys real solid collision")
		await _finish()
	for gate in ["ability", "host_wall", "host_move", "main_wall", "main_inputs", "main_interrupt", "facing", "input"]:
		await _begin("wall entry denial " + gate, Vector2(100, 280), false)
		actor.allow_wall_run = true
		_wall_body(1, 112)
		match gate:
			"ability": actor.allow_wall_run = false
			"host_wall": actor.set_weapon_permissions({"can_wall_traverse": false})
			"host_move": actor.set_weapon_permissions({"can_move": false})
			"main_wall": actor.begin_main_action(&"gate", {"can_wall_grab": false})
			"main_inputs": actor.begin_main_action(&"gate", {"uses_inputs": false})
			"main_interrupt": actor.begin_main_action(&"gate", {"interruptible_by": ["locomotion"]})
			"facing": actor.facing = -1; actor.set_weapon_permissions({"can_turn": false})
			"input": actor.allow_input = false
		await _seconds({"right": 1.0}, .15)
		_check(actor.main_action != &"wall", "wall assistance cannot bypass the selected ability, host, main-owner or input denial")
		if gate == "facing": _check(actor.facing == -1, "contact cannot force an opposite facing while host turning is locked")
		await _finish()
	for mode in ["neutral", "away", "down", "grounded", "no_wall"]:
		await _begin("wall entry context " + mode, Vector2(100, 200 if mode == "grounded" else 280), mode == "grounded")
		actor.allow_wall_run = true
		if mode != "no_wall": _wall_body(1, 108.1)
		var frame := {"right": 1.0}
		if mode == "neutral": frame = {}
		elif mode == "away": frame = {"left": 1.0}
		elif mode == "down": frame = {"right": 1.0, "down": 1.0}
		await _seconds(frame, .15)
		_check(actor.main_action != &"wall", "entry requires genuine airborne solid contact and eligible toward intent")
		await _finish()
	for geometry in ["one_way", "mixed", "multi_solid", "rotated", "negative_scale", "non_rectangle"]:
		await _begin("unsupported wall geometry " + geometry, Vector2(100, 280), false)
		actor.allow_wall_run = true
		var body: Node2D
		if geometry in ["mixed", "multi_solid"]:
			body = _shaped_body(Vector2(112, -500), [Rect2(0, 0, 32, 580), Rect2(0, 580, 32, 570)], [false, geometry == "mixed"])
			tracked_bodies.append(body)
		else:
			body = _wall_body(1, 112, -500, 650, 32, geometry == "one_way")
			if geometry == "rotated": body.position = Vector2(114, 262); body.get_node("Shape").position = Vector2(16, 0); body.rotation = .08
			elif geometry == "negative_scale": body.position.x = 144; body.scale.x = -1
			elif geometry == "non_rectangle":
				var capsule = CapsuleShape2D.new(); capsule.radius = 16; capsule.height = 1150
				body.get_node("Shape").shape = capsule
		await _step({}, 2); await _seconds({"right": 1.0}, .15)
		_check(actor.main_action != &"wall", "conservative wall policy safely refuses unsupported actual body geometry")
		_check(actor.get_collision_exceptions().is_empty(), "refused geometry never creates a collision exclusion")
		if geometry != "one_way": _check(not _trace_has_solid_overlap(), "unsupported wall still physically blocks the actor")
		await _finish()

func _wall_contact_lifecycle() -> void:
	for change in ["removed", "disabled", "layer", "rotated", "teleported", "shape_removed", "shape_replaced"]:
		var body = await _setup_wall("live wall mutation " + change)
		var before: Vector2 = actor.global_position
		match change:
			"removed": body.queue_free()
			"disabled": body.get_node("Shape").set_deferred("disabled", true)
			"layer": body.collision_layer = 0
			"rotated": body.rotation = .12
			"teleported": body.position.x += 240
			"shape_removed": body.get_node("Shape").queue_free()
			"shape_replaced": body.get_node("Shape").shape = CircleShape2D.new()
		await _step({"right": 1.0}, 2)
		_check(actor.main_action != &"wall", "removed or invalid actual wall contact releases ownership promptly")
		_check(actor.global_position.distance_to(before) < actor.profile.terminal_fall_speed * 3 * dt + 2, "invalid wall geometry cannot teleport the actor to its new pose")
		_check(actor.get_collision_exceptions().is_empty(), "contact invalidation leaves no stale body exception")
		await _finish()
	for lock in ["ability", "host_wall", "movement", "input"]:
		await _setup_wall("live wall lock releases " + lock)
		if lock == "ability": actor.allow_wall_run = false
		elif lock == "host_wall": actor.set_weapon_permissions({"can_wall_traverse": false})
		elif lock == "movement": actor.set_weapon_permissions({"can_move": false})
		else: actor.allow_input = false
		await _step({"right": 1.0})
		_check(actor.main_action != &"wall", "live gate revocation releases wall ownership into ordinary physics")
		await _finish()
	for pause in [false, true]:
		var body = await _setup_wall("moving wall transport " + ("paused" if pause else "live"))
		await _seconds({"right": 1.0}, actor.profile.wall_probe_reach / actor.profile.wall_contact_push_speed + 2 * dt)
		var motion = _motion(body, Vector2(30, -20))
		var relative_before: Vector2 = actor.global_position - body.global_position
		if pause: actor.apply_hitpause(.2)
		await _seconds({"right": 1.0}, .1)
		var relative_after: Vector2 = actor.global_position - body.global_position
		_check(actor.main_action == &"wall" and absf(relative_after.x - relative_before.x) < .25, "valid moving wall carries the contact through swept horizontal transport")
		if pause: _near(relative_after.y, relative_before.y, .25, "local pause freezes wall ascent while retaining safe carrier transport")
		_check(not bool(actor.telemetry().wall_rearm_ready) and int(actor.telemetry().wall_episode_serial) == 1, "held moving contact cannot rearm its episode from pending carrier displacement")
		_check(not _trace_has_solid_overlap(), "wall transport preserves ordinary solid separation")
		motion.enabled = false
		await _finish()
	for pause in [false, true]:
		var body = await _setup_wall("wall transport obstruction " + ("paused" if pause else "live"))
		_surface(Vector2(65, -500), Vector2(16, 1100))
		await _step({"right": 1.0})
		var motion = _motion(body, Vector2(-120, 0))
		if pause: actor.apply_hitpause(.2)
		await _until(func(): return actor.main_action != &"wall", {"right": 1.0}, .22)
		motion.enabled = false
		_check(actor.main_action != &"wall", "obstructed carrier motion releases wall ownership instead of moving through an independent solid")
		# A carrier may geometrically crush an actor if it keeps advancing. Check the
		# independent stationary obstacle, not an impossible overlap-free escape.
		_check(actor.global_position.x >= 81 + actor.profile.body_width * .5 - .1, "blocked transport never sweeps through the independent thin obstacle")
		await _finish()

func _wall_ledge_handoff() -> void:
	for direction in [-1, 1]:
		for blocked in [false, true]:
			await _begin("wall top handoff %d %s" % [direction, "blocked" if blocked else "clear"], Vector2(100, 230), false)
			actor.allow_wall_run = true
			_wall_body(direction, 112 if direction > 0 else 88, 160, 500, 100)
			if blocked: _surface(Vector2(110 if direction > 0 else -14, 112), Vector2(104, 30))
			await _step({}, 2)
			await _until(func(): return actor.main_action == &"wall", _direction(direction), .5)
			_check(actor.main_action == &"wall", "physical airborne approach starts ascent below the real top edge")
			await _until(func(): return actor.main_action == &"ledge" or actor.grounded, _direction(direction), 1)
			if not blocked:
				await _until(func(): return actor.grounded, _direction(direction), 1)
				_check(actor.grounded and absf(actor.global_position.y - 160) < .2 and _count("pullup_end") == 1, "wall run hands off to swept existing ledge pull and lands on its actual top")
			else:
				await _seconds(_direction(direction), .25)
				_check(_count("pullup_end") == 0 and not actor.grounded, "blocked standing headroom never completes a false top landing")
			_check(not _trace_has_solid_overlap(), "top handoff and blocked pull maintain full solid clearance")
			await _finish()

func _wall_run_and_kick() -> void:
	for direction in [-1, 1]:
		await _setup_wall("finite run slide and exhaustion %d" % direction, direction)
		var entry_y: float = actor.global_position.y
		var entry_tick: int = driver.ticks
		await _until(func(): return _wall_phase() == "slide", _direction(direction), actor.profile.wall_run_max_seconds + .3)
		var sliding = actor.telemetry()
		_check(actor.main_action == &"wall" and _wall_phase() == "slide", "finite ascent transitions into the authored controlled slide")
		_check(float(sliding.wall_run_elapsed) <= actor.profile.wall_run_max_seconds + dt + .000001 and float(sliding.wall_run_rise) <= actor.profile.wall_run_max_rise + actor.profile.wall_run_speed * dt + .1, "ascent obeys its independent authored time and relative-distance bounds")
		measurements["run_seconds"] = (driver.ticks - entry_tick) * dt
		measurements["run_rise"] = entry_y - actor.global_position.y
		await _seconds(_direction(direction), (actor.profile.wall_run_speed + actor.profile.wall_slide_speed) / actor.profile.wall_slide_acceleration + 2 * dt)
		_near(actor.velocity.y, actor.profile.wall_slide_speed, .01, "held contact reaches the configured downward slide speed")
		await _until(func(): return actor.main_action != &"wall", _direction(direction), actor.profile.wall_slide_max_seconds + .3)
		var attaches: int = _count("wall_attached")
		await _seconds(_direction(direction), actor.profile.wall_regrab_delay + .2)
		_check(actor.main_action != &"wall" and _count("wall_attached") == attaches, "exhausted held contact cannot create a fresh run episode")
		_check(not _trace_has_solid_overlap(), "complete run and slide remain outside the actual solid wall")
		await _finish()
	for direction in [-1, 1]:
		await _setup_wall("supported outward kick preserves spent budgets %d" % direction, direction)
		actor.air_jumps_left = 0; actor.air_roll_available = false; actor.dive_available = false
		await _step(_direction(direction, {"jump": true}))
		_check(actor.main_action == &"wall" and _wall_phase() == "kick" and _count("wall_kick") == 1, "fresh Jump supplies the supported outward kick with spent airborne budgets")
		_check(actor.velocity.x * direction < 0 and actor.velocity.y < 0, "kick leaves the actual wall outward and upward")
		_near(absf(actor.velocity.x), actor.profile.wall_kick_horizontal_speed, .01, "kick uses its authored horizontal impulse")
		var start_tick: int = driver.ticks
		await _seconds(_direction(direction, {"jump": true}), actor.profile.wall_kick_commit_seconds * .5)
		_check(_wall_phase() == "kick" and actor.velocity.x * direction < 0, "toward steering cannot erase the finite outward commitment")
		await _until(func(): return actor.main_action != &"wall", _direction(direction, {"jump": true}), .3)
		measurements["kick_commit_seconds"] = (driver.ticks - start_tick) * dt
		_check(actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "wall attachment and kick neither refill nor spend ordinary airborne allowances")
		_check(_count("air_jump") == 0 and _count("wall_kick") == 1, "a held jump edge cannot be reused after commitment")
		_check(not _trace_has_solid_overlap(), "outward kick collision sweep never crosses the source wall")
		await _finish()

func _wall_interruptions() -> void:
	for phase in ["run", "slide"]:
		for action in ["roll", "jump", "attack", "dive", "damage"]:
			await _setup_wall("wall %s interruption %s" % [phase, action])
			if phase == "slide": await _until(func(): return _wall_phase() == "slide", {"right": 1.0}, .8)
			if action == "damage": actor.receive_hit({"rollable": false, "hitpause": .06, "impulse": Vector2(-110, -80)})
			elif action == "dive": await _step({"right": 1.0, "down": 1.0, "jump": true})
			else: await _step({"right": 1.0, action: true})
			if action == "jump": _check(_wall_phase() == "kick" and _count("wall_kick") == 1, "eligible supported Jump replaces run or slide with one kick")
			elif action == "attack": _check(actor.main_action != &"wall" and actor.weapon_phase == &"windup", "eligible melee detaches contact into live weapon windup")
			else: _check(actor.main_action == StringName("hurt" if action == "damage" else action), "eligible replacement action takes ownership of motion")
			_check(not _has_solid_overlap(), "replacement action retains the common solid collision body")
			await _finish()
	for action in ["roll", "attack", "jump"]:
		await _setup_wall("host denied wall interruption " + action)
		actor.set_weapon_permissions({"can_" + action: false})
		await _step({"right": 1.0, action: true})
		_check(actor.main_action == &"wall" and _wall_phase() == "run", "wall owner cannot reopen an external denial of an interruption")
		await _finish()
	for action in ["roll", "attack", "dive", "jump"]:
		await _setup_wall("kick commitment rejects early " + action)
		await _step({"right": 1.0, "jump": true}); await _step({"right": 1.0})
		if action == "dive": await _step({"right": 1.0, "down": 1.0, "jump": true})
		else: await _step({"right": 1.0, action: true})
		_check(actor.main_action == &"wall" and _wall_phase() == "kick" and actor.weapon_phase == &"idle", "ordinary input cannot interrupt the authored committed kick interval")
		_check(_count("roll_started") == 0 and _count("dive_started") == 0 and _count("air_jump") == 0, "denied early cancellation has no resource-spending side effect")
		await _finish()
	await _setup_wall("wall simultaneous action priority")
	await _step({"right": 1.0, "down": 1.0, "jump": true, "roll": true, "attack": true})
	_check(actor.main_action == &"roll" and _count("wall_kick") == 0 and _count("dive_started") == 0 and actor.weapon_phase == &"idle", "simultaneous eligible requests keep roll above down-action, supported jump and melee")
	await _finish()

func _wall_native_pause_and_grace() -> void:
	for direction in [-1, 1]:
		await _setup_wall("native wall jump tap through hitpause %d" % direction, direction)
		actor.air_jumps_left = 0; actor.air_roll_available = false; actor.dive_available = false
		actor.automatic_physics = true
		var toward: Key = KEY_D if direction > 0 else KEY_A
		_key(toward, true); await _step(null)
		actor.apply_hitpause(.2)
		var before: Dictionary = actor.telemetry()
		var root_before: Vector2 = actor.global_position
		_key(KEY_SPACE, true); await _step(null); _key(KEY_SPACE, false); await _step(null)
		_check(_count("wall_kick") == 0 and actor.global_position == root_before, "parsed Jump tap is captured while wall motion is locally frozen")
		_near(float(actor.telemetry().wall_run_elapsed), float(before.wall_run_elapsed), .000001, "local hitpause freezes ascent allowance time")
		await _until(func(): return actor.hitpause_remaining <= 0, null)
		var final_paused_tick: int = driver.ticks
		await _step(null)
		_check(driver.ticks == final_paused_tick + 1 and _count("wall_kick") == 1 and _wall_phase() == "kick", "exact first resumed physics tick consumes one captured supported Jump edge")
		_check(actor.velocity.y < 0 and absf(actor.velocity.y) <= actor.profile.jump_release_rise_cap + .01, "release captured inside pause cuts the resumed kick ascent")
		await _seconds(null, actor.profile.wall_kick_commit_seconds + .05)
		_check(_count("wall_kick") == 1 and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "paused edge does not repeat or change unrelated airborne budgets")
		await _finish()
	for direction in [-1, 1]:
		await _setup_wall("native adjacent wall away then jump %d" % direction, direction)
		actor.air_jumps_left = 0; actor.air_roll_available = false; actor.dive_available = false; actor.automatic_physics = true
		var toward: Key = KEY_D if direction > 0 else KEY_A
		var away: Key = KEY_A if direction > 0 else KEY_D
		_key(toward, true); await _step(null)
		_key(toward, false); _key(away, true); await _step(null)
		var release_tick: int = driver.ticks
		_check(actor.main_action != &"wall" and float(actor.telemetry().wall_kick_grace) > 0, "voluntary away input creates the authored recent-wall kick grace")
		_key(KEY_SPACE, true); await _step(null)
		_check(driver.ticks == release_tick + 1 and _count("wall_kick") == 1 and actor.velocity.x * direction < 0, "adjacent actual key ticks produce outward supported kick with no air jump available")
		_check(actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "adjacent-key assistance preserves all spent budgets")
		_key(KEY_SPACE, false); await _step(null); _key(KEY_SPACE, true); await _step(null)
		_check(_count("wall_kick") == 1 and _count("air_jump") == 0, "a second press cannot reuse consumed wall grace")
		await _finish()
	for mode in ["expired", "removed", "ability", "jump_gate", "paused"]:
		var body = await _setup_wall("recent wall kick grace " + mode)
		actor.air_jumps_left = 0
		await _step({"left": 1.0})
		if mode == "expired": await _seconds({}, actor.profile.wall_kick_grace_seconds + 2 * dt)
		elif mode == "removed": body.queue_free(); await _step()
		elif mode == "ability": actor.allow_wall_run = false
		elif mode == "jump_gate": actor.set_weapon_permissions({"can_jump": false})
		else:
			actor.apply_hitpause(.2); await _step({"jump": true}); await _step()
			await _until(func(): return actor.hitpause_remaining <= 0)
		await _step({"jump": true})
		if mode == "paused": _check(_count("wall_kick") == 1, "recent-contact authority and captured Jump survive actor-local pause")
		else: _check(_count("wall_kick") == 0 and _count("air_jump") == 0, "expired, invalid or host-denied recent wall contact cannot authorize a kick")
		await _finish()
	for action in ["roll", "attack", "dive", "damage", "forced", "reset"]:
		await _setup_wall("recent wall grace cleared by " + action)
		await _step({"left": 1.0})
		if action == "damage": actor.receive_hit({"rollable": false, "hitpause": .1})
		elif action == "forced": actor.begin_main_action(&"replacement", {})
		elif action == "reset": actor.reset_actor(Vector2(20, 280))
		elif action == "dive": await _step({"down": 1.0, "jump": true})
		else: await _step({action: true})
		_check(float(actor.telemetry().wall_kick_grace) == 0, "accepted replacement action retires prior wall grace immediately")
		await _finish()

func _wall_rearm_and_reuse() -> void:
	await _setup_wall("melee cancellation preserves same contact allowance")
	await _seconds({"right": 1.0}, .2)
	var before = actor.telemetry()
	await _step({"right": 1.0, "attack": true})
	await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .8)
	var after = actor.telemetry()
	_check(actor.main_action == &"wall" and int(after.wall_episode_serial) == int(before.wall_episode_serial), "attack cancellation and reentry on continuous contact do not create a fresh wall episode")
	_check(float(after.wall_run_elapsed) >= float(before.wall_run_elapsed) and float(after.wall_run_rise) >= float(before.wall_run_rise), "action naming and cancellation preserve the already consumed ascent allowance")
	await _finish()
	for policy in [0, 1]:
		await _setup_wall("physical separation rearm policy %d" % policy)
		actor.profile.wall_rearm_policy = policy
		await _seconds({"right": 1.0}, .16)
		var old_serial: int = int(actor.telemetry().wall_episode_serial)
		await _seconds({"left": 1.0}, .12)
		var gap: float = 112 - actor.global_position.x - actor.profile.body_width * .5
		_check(gap > actor.profile.wall_separation_distance, "ordinary away movement produces genuine geometric separation")
		await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .8)
		var returned = actor.telemetry()
		_check(actor.main_action == &"wall", "fresh physical recontact can attach after the authored delay")
		_check(int(returned.wall_episode_serial) == old_serial + (1 if policy == 0 else 0), "configured separation or real-ground policy decides whether recontact grants a fresh finite run")
		await _finish()
	await _begin("coplanar collider seam cannot refresh run", Vector2(100, 305), false)
	actor.allow_wall_run = true
	var lower = _wall_body(1, 112, 260, 650)
	var upper = _wall_body(1, 112, -500, 260)
	await _step({}, 2); await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .5)
	var episode: int = int(actor.telemetry().wall_episode_serial)
	await _seconds({"right": 1.0}, 1.0)
	var ids: Array = []
	for frame in frames:
		var id: int = int(frame.get("wall_contact_id", 0))
		if id != 0 and not ids.has(id): ids.append(id)
	_check(ids.has(lower.get_instance_id()) and ids.has(upper.get_instance_id()), "connected physical ascent actually traverses both adjacent collider faces")
	_check(int(actor.telemetry().wall_episode_serial) == episode, "crossing a coplanar body-ID seam does not rearm a run")
	_check(not _trace_has_solid_overlap(), "seam transition retains continuous solid clearance")
	await _finish()
	await _setup_wall("same instance reset and replacement wall cycles")
	var original_id: int = actor.get_instance_id()
	for cycle in range(3):
		await _step({"right": 1.0, "jump": true})
		actor.apply_hitpause(.1); await _step({"roll": true, "attack": true})
		tracked_bodies.back().queue_free(); await _step()
		actor.reset_actor(Vector2(100, 280), 1)
		_wall_body(1, 112)
		var reset = actor.telemetry()
		_check(actor.get_instance_id() == original_id and not bool(reset.wall_active) and float(reset.wall_kick_grace) == 0 and float(reset.wall_regrab_remaining) == 0 and float(reset.wall_run_elapsed) == 0, "same reusable actor reset clears contact, grace, timers and consumed wall allowance")
		await _step({}, 2); await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .5)
		_check(actor.main_action == &"wall" and _wall_phase() == "run", "reset actor can physically reenter a fresh finite run")
	await _finish()

func _wall_extra_permissions_and_cleanup() -> void:
	for deny in ["ability", "budget", "host"]:
		await _setup_wall("denied wall down chord " + deny)
		if deny == "ability": actor.allow_dive = false
		elif deny == "budget": actor.dive_available = false
		else: actor.set_weapon_permissions({"can_dive": false})
		await _step({"right": 1.0, "down": 1.0, "jump": true})
		_check(actor.main_action == &"wall" and _count("wall_kick") == 0 and _count("air_jump") == 0 and _count("dive_started") == 0, "denied fresh Down+Jump consumes its intent without fallback or same-tick voluntary release")
		await _step({"right": 1.0, "down": 1.0, "jump": true})
		_check(actor.main_action != &"wall", "continued Down on a later tick still requests ordinary release")
		await _finish()
	for pause in [false, true]:
		await _setup_wall("wall metadata refusal " + ("paused" if pause else "live"))
		tracked_bodies[0].set_meta("wall_traversal_blocked", true)
		if pause: actor.apply_hitpause(.2)
		await _step({"right": 1.0})
		_check(actor.main_action != &"wall", "explicit blocked-surface metadata revokes active contact even during local pause")
		await _finish()
	await _begin("wall blocked surface entry", Vector2(100, 280), false)
	actor.allow_wall_run = true
	_wall_body(1, 112).set_meta("wall_traversal_blocked", true)
	await _seconds({"right": 1.0}, .2)
	_check(actor.main_action != &"wall", "explicit blocked-surface metadata rejects fresh entry")
	await _finish()
	for mode in ["run", "carrier", "paused_carrier"]:
		await _setup_wall("wall forbidden upward one-way " + mode)
		# Establish the inherited gate on the owner before a new contact episode.
		_check(actor.begin_main_action(&"forced", {"can_jump_through_up": false}), "upward-restricted owner is accepted before reacquiring wall")
		await _seconds({"right": 1.0}, actor.profile.wall_regrab_delay + 2 * dt)
		await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .5)
		var ceiling_bottom: float = actor.global_position.y - actor.body_height - 5
		_oneway(Vector2(40, ceiling_bottom - 6), Vector2(72, 6)); await _step({"right": 1.0})
		if mode != "run": _motion(tracked_bodies[0], Vector2(0, -100))
		if mode == "paused_carrier": actor.apply_hitpause(.2)
		await _seconds({"right": 1.0}, .12)
		_check(actor.global_position.y - actor.body_height >= ceiling_bottom - .1, "full body cannot pass upward through a forbidden one-way during wall motion or transport")
		var disallowed: Array = []
		for frame in frames:
			for overlap in frame.get("shape_contacts", []):
				if bool(overlap.one_way): disallowed.append(overlap)
		_check(disallowed.is_empty(), "per-shape oracle observes no hidden overlap with the independent one-way ceiling")
		await _finish()
	await _begin("drop cleanup blocks wall standing expansion", Vector2(100, 134), false)
	actor.allow_wall_run = true
	var top = _oneway(Vector2(40, 140), Vector2(72, 22))
	_wall_body(1, 112, -300, 600)
	await _until(func(): return actor.grounded)
	await _step({"down": 1.0, "jump": true})
	await _step({"right": 1.0, "attack": true})
	var had_cleanup := false
	var cleanup_safe := true
	for _i in range(ceili(.3 / dt)):
		if not bool(actor.telemetry().drop_exception_active): break
		had_cleanup = true
		cleanup_safe = cleanup_safe and actor.main_action != &"wall" and actor.crouched and actor.get_collision_exceptions() == [top]
		await _step({"right": 1.0})
	_check(cleanup_safe, "active targeted cleanup keeps its small body and cannot authorize wall entry or global exclusions")
	_check(had_cleanup and not bool(actor.telemetry().drop_exception_active), "real drop traverses the thick one-way and eventually clears its target exception")
	await _finish()

func _wall_connected_budgets_and_landing() -> void:
	for direction in [-1, 1]:
		await _begin("connected approach run kick higher opposite landing %d" % direction, Vector2(230 * direction, 400), false)
		actor.allow_wall_run = true
		_surface(Vector2(-600, 400), Vector2(1200, 32))
		_wall_body(direction, 280 * direction, -200, 400)
		_surface(Vector2(60 if direction > 0 else -190, 245), Vector2(130, 20))
		await _until(func(): return actor.grounded)
		await _step(_direction(direction, {"jump": true}))
		await _until(func(): return actor.main_action == &"wall", _direction(direction, {"jump": true}), .7)
		_check(actor.main_action == &"wall", "actual grounded jump and airborne approach connect to the wall run")
		await _seconds(_direction(direction, {"jump": true}), .3)
		await _step(_direction(direction)); await _step(_direction(direction, {"jump": true}))
		_check(_count("wall_kick") == 1, "fresh second jump input kicks outward from the physical run")
		await _until(func(): return actor.grounded, _direction(-direction, {"jump": true}), 1.3)
		_check(actor.grounded and absf(actor.global_position.y - 245) < .2, "outward kick reaches and lands on the higher opposite platform")
		_check(not _trace_has_solid_overlap(), "complete approach ascent kick and higher landing obey all terrain collisions")
		await _finish()
	await _begin("connected spent air budgets preserved by wall kick", Vector2(100, 700), false)
	actor.allow_wall_run = true
	var floor = _surface(Vector2(-500, 700), Vector2(1400, 30))
	await _until(func(): return actor.grounded)
	await _seconds({"jump": true}, .1); await _step(); await _step({"jump": true})
	await _step(); await _step({"down": 1.0, "jump": true}); await _step({"roll": true})
	floor.queue_free()
	await _until(func(): return actor.main_action != &"roll", {}, .6)
	_check(_count("air_jump") == 1 and _count("dive_started") == 1 and _count("roll_started") == 1 and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "connected actions physically spend all three airborne allowances")
	_wall_body(1, actor.global_position.x + 12, actor.global_position.y - 500, actor.global_position.y + 500)
	await _step({}, 2); await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .5)
	await _step({"right": 1.0, "jump": true})
	_check(_count("wall_kick") == 1 and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "supported kick adds no hidden refill after actual air jump dive and roll expenditure")
	await _finish()
	await _setup_wall("ground-only wall budget resets on buffered landing jump")
	actor.profile.wall_rearm_policy = 1
	await _until(func(): return _wall_phase() == "slide", {"right": 1.0}, .8)
	var serial_before: int = int(actor.telemetry().wall_episode_serial)
	await _step({"down": 1.0})
	var floor_y: float = actor.global_position.y + 70
	_surface(Vector2(-500, floor_y), Vector2(1000, 30))
	await _until(func(): return actor.velocity.y > 0 and floor_y - actor.global_position.y < 10, {}, .6)
	var lands: int = _count("landed")
	actor.air_jumps_left = 0
	await _step({"jump": true})
	await _until(func(): return _count("landed") > lands and actor.velocity.y < 0, {"jump": true}, .4)
	_check(_count("landed") > lands and actor.velocity.y < 0, "real landing consumes a still-live jump buffer on the landing tick")
	await _until(func(): return actor.main_action == &"wall", {"right": 1.0, "jump": true}, .6)
	_check(actor.main_action == &"wall" and int(actor.telemetry().wall_episode_serial) == serial_before + 1 and _wall_phase() == "run", "ground-only rearm observes actual floor even when buffered jump departs immediately")
	await _finish()

func _wall_damage_locks_and_thin_geometry() -> void:
	for phase in ["run", "slide", "kick"]:
		await _setup_wall("wall reset during " + phase)
		if phase == "slide": await _until(func(): return _wall_phase() == "slide", {"right": 1.0}, .8)
		elif phase == "kick": await _step({"right": 1.0, "jump": true})
		actor.apply_hitpause(.2); await _step({"jump": true, "roll": true, "attack": true})
		actor.reset_actor(Vector2(20, 280), -1)
		var state = actor.telemetry()
		_check(not bool(state.wall_active) and String(state.wall_phase).is_empty() and float(state.wall_kick_grace) == 0 and float(state.wall_regrab_remaining) == 0 and float(state.wall_run_elapsed) == 0 and float(state.wall_slide_elapsed) == 0, "reset clears every active wall phase and episode allowance")
		_check(state.hitpause_remaining == 0 and state.jump_buffer == 0 and state.roll_buffer == 0 and state.attack_buffer == 0 and actor.get_collision_exceptions().is_empty(), "wall reset clears local pause queued intent and collision exclusions")
		await _step(); _check(actor.main_action != &"wall" and not _has_solid_overlap(), "reset resumes ordinary physics from the requested safe root")
		await _finish()
	await _setup_wall("independent host move lock still allows supported kick")
	actor.set_weapon_permissions({"can_move": false, "can_jump": true, "can_turn": false})
	await _step({"right": 1.0, "jump": true})
	_check(_wall_phase() == "kick" and actor.velocity.x < 0 and actor.facing == 1, "permitted jump resolves before movement-lock release while respecting facing lock")
	await _finish()
	for lock in ["ability", "input", "movement"]:
		await _setup_wall("committed kick survives later lock " + lock)
		await _step({"right": 1.0, "jump": true})
		if lock == "ability": actor.allow_wall_run = false
		elif lock == "input": actor.allow_input = false
		else: actor.set_weapon_permissions({"can_move": false})
		await _step({"right": 1.0})
		_check(_wall_phase() == "kick" and actor.velocity.x < 0, "new voluntary gate cannot stretch or remove an already committed collision sweep")
		await _until(func(): return actor.main_action != &"wall", {"right": 1.0}, actor.profile.wall_kick_commit_seconds + 2 * dt)
		_check(actor.main_action != &"wall", "committed kick still expires after gate revocation")
		await _finish()
	for direction in [-1, 1]:
		await _setup_wall("high speed outward kick thin opposite wall %d" % direction, direction)
		actor.profile.wall_kick_horizontal_speed *= 8
		var face := 54.0 if direction > 0 else 146.0
		_wall_body(-direction, face, -500, 650, 4)
		await _step(_direction(direction)); await _step(_direction(direction, {"jump": true}))
		await _seconds(_direction(-direction, {"jump": true}), actor.profile.wall_kick_commit_seconds + dt)
		_check(actor.global_position.x >= face + actor.profile.body_width * .5 - .1 if direction > 0 else actor.global_position.x <= face - actor.profile.body_width * .5 + .1, "swept eight-times-speed kick cannot skip a four-pixel opposite wall")
		_check(not _trace_has_solid_overlap(), "thin opposite wall remains solid throughout kick collision and expiry")
		await _finish()
	for mode in ["rising", "toward", "removed", "invalidated"]:
		var body = await _setup_wall("hurt pause keeps only validated wall carrier " + mode)
		await _seconds({"right": 1.0}, actor.profile.wall_probe_reach / actor.profile.wall_contact_push_speed + 2 * dt)
		var relative: Vector2 = actor.global_position - body.global_position
		var recoil = Vector2(-110, -90)
		actor.air_jumps_left = 0; actor.air_roll_available = false; actor.dive_available = false
		actor.receive_hit({"rollable": false, "impulse": recoil, "hitpause": .2})
		var motion: SensorMotion
		if mode == "removed": body.queue_free()
		elif mode == "invalidated": body.set_meta("wall_traversal_blocked", true)
		else: motion = _motion(body, Vector2(0, -35) if mode == "rising" else Vector2(-35, 0))
		var before: Vector2 = actor.global_position
		await _seconds({}, .1)
		_check(actor.main_action == &"hurt" and actor.hitpause_remaining > 0 and actor.velocity == recoil, "hurt freezes recoil with no active wall owner or forced velocity rewrite")
		if mode in ["rising", "toward"]:
			var after: Vector2 = actor.global_position - body.global_position
			_check(after.distance_to(relative) < .25 and not _trace_has_solid_overlap(), "validated carrier transports hurt freeze without penetrating current wall geometry")
			motion.enabled = false
		else: _check(actor.global_position == before, "removed or invalid carrier cannot transport the frozen hurt actor")
		_check(actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "hurt carrier transport does not replenish airborne budgets")
		await _until(func(): return actor.hitpause_remaining <= 0); await _step()
		_check(actor.main_action == &"hurt" and actor.velocity.x < 0, "resumed recoil detaches transport and advances ordinary swept hurt motion")
		await _finish()
	await _setup_wall("disabled native held jump cannot synthesize wall kick")
	actor.automatic_physics = true; actor.allow_input = false
	_key(KEY_D, true); _key(KEY_SPACE, true); await _step(null, 2)
	actor.allow_input = true; await _step(null, 2)
	_check(_count("wall_kick") == 0 and _count("air_jump") == 0, "re-enabling controls does not manufacture an edge from physically held Jump")
	_key(KEY_SPACE, false); await _step(null)
	await _until(func(): return actor.main_action == &"wall", null, .6)
	_key(KEY_SPACE, true); await _step(null)
	_check(_count("wall_kick") == 1, "a real new key edge remains usable after disabled input and reattachment")
	await _finish()

func _wall_rate_and_additional_geometry() -> void:
	await _setup_wall("steady profile wall ascent interval")
	await _until(func(): return absf(actor.velocity.y + actor.profile.wall_run_speed) < .01, {"right": 1.0}, .35)
	var start_y: float = actor.global_position.y
	await _seconds({"right": 1.0}, .15)
	measurements["steady_rise_distance"] = start_y - actor.global_position.y
	_near(float(measurements.steady_rise_distance), actor.profile.wall_run_speed * .15, .01, "steady wall interval independently equals configured speed times elapsed seconds")
	_check(_wall_phase() == "run", "measurement remains within the finite run window")
	await _finish()
	await _setup_wall("solid ceiling safely ends upward run")
	var ceiling_bottom: float = actor.global_position.y - actor.body_height - 16
	_surface(Vector2(40, ceiling_bottom - 12), Vector2(72, 12))
	await _until(func(): return _wall_phase() == "slide", {"right": 1.0}, .5)
	_check(_wall_phase() == "slide" and actor.global_position.y - actor.body_height >= ceiling_bottom - .1 and not _trace_has_solid_overlap(), "head contact ends ascent into slide without ceiling penetration or infinite upward pressure")
	await _finish()
	await _setup_wall("allowed wall ascent through independent one-way")
	var top_y: float = actor.global_position.y - actor.body_height - 16
	var platform = _oneway(Vector2(40, top_y), Vector2(72, 6))
	await _until(func(): return actor.global_position.y < top_y - actor.profile.collision_margin, {"right": 1.0}, actor.profile.wall_run_max_seconds)
	_check(actor.global_position.y < top_y and actor.get_collision_exceptions().is_empty(), "ordinary allowed upward passage crosses an independent one-way without globally ignoring it")
	await _step({"down": 1.0})
	await _until(func(): return actor.grounded, {}, 1)
	_check(actor.grounded and absf(actor.global_position.y - top_y) < .2 and actor.telemetry().support_id == platform.get_instance_id(), "the same one-way remains a real downward landing surface after wall release")
	await _finish()
	await _begin("fresh wall entry ignores stale moved-away body", Vector2(100, 280), false)
	actor.allow_wall_run = true
	var body = _wall_body(1, 110)
	await _step({}, 2)
	var motion = _motion(body, Vector2(200 / dt, 0))
	await _step({"right": 1.0}); motion.enabled = false
	_check(actor.main_action != &"wall" and actor.global_position.x < 110, "pre-actor body displacement cannot teleport actor to stale query contact")
	_check(_count("wall_attached") == 0, "stale committed contact cannot consume an episode before current moved-away geometry is validated")
	await _finish()

func _wall_final_intersections() -> void:
	await _setup_wall("forced damage interrupts committed kick")
	await _step({"right": 1.0, "jump": true})
	actor.receive_hit({"rollable": false, "impulse": Vector2(70, -40), "hitpause": .1})
	_check(actor.main_action == &"hurt" and String(actor.telemetry().wall_phase).is_empty() and float(actor.telemetry().wall_kick_grace) == 0 and actor.velocity == Vector2(70, -40), "forced hit immediately retires kick ownership and installs hurt recoil")
	await _step({"jump": true, "roll": true, "attack": true})
	_check(actor.main_action == &"hurt" and _count("wall_kick") == 1, "pause input cannot revive a cancelled committed wall kick")
	await _finish()
	await _setup_wall("wall grace cannot kick through new obstruction")
	actor.air_jumps_left = 0
	await _step({"left": 1.0})
	_surface(Vector2(110, -400), Vector2(.5, 900)); await _step({"jump": true})
	_check(_count("wall_kick") == 0 and _count("air_jump") == 0, "new intervening solid invalidates the clear path back to a recent wall")
	await _finish()
	await _begin("targeted drop roll keeps thin wall with ability enabled", Vector2(100, 134), false)
	actor.allow_wall_run = true
	var platform = _oneway(Vector2(40, 140), Vector2(72, 20))
	_wall_body(1, 112, -300, 600, 4)
	await _until(func(): return actor.grounded)
	await _step({"down": 1.0, "jump": true}); await _step({"right": 1.0, "roll": true})
	await _seconds({"right": 1.0}, .12)
	_check(actor.main_action == &"roll" and _count("wall_attached") == 0, "wall ability cannot steal a committed roll after targeted drop")
	_check(actor.global_position.x <= 112 - actor.profile.body_width * .5 + .1 and not _trace_has_solid_overlap(), "target-only platform exclusion keeps the adjacent four-pixel wall solid")
	_check(actor.get_collision_exceptions().is_empty() or actor.get_collision_exceptions() == [platform], "drop-roll intersection never broadens collision exclusions")
	await _finish()
	await _setup_wall("wall jump buffer expires during host denial")
	actor.set_weapon_permissions({"can_jump": false})
	await _step({"right": 1.0, "jump": true})
	actor.apply_hitpause(.2)
	var remaining: float = actor.telemetry().jump_buffer
	await _until(func(): return actor.hitpause_remaining <= 0, {"right": 1.0, "jump": true})
	_near(float(actor.telemetry().jump_buffer), remaining, .000001, "host-denied wall jump buffer freezes during local pause")
	await _seconds({"right": 1.0, "jump": true}, actor.profile.jump_buffer_seconds + 2 * dt)
	actor.set_weapon_permissions(); await _step({"right": 1.0, "jump": true})
	_check(_count("wall_kick") == 0 and float(actor.telemetry().jump_buffer) == 0, "expired edge does not launch merely because jump permission returns")
	await _step({"right": 1.0}); await _step({"right": 1.0, "jump": true})
	_check(_count("wall_kick") == 1, "a genuinely fresh press remains available after buffer expiration")
	await _finish()
	await _setup_wall("wall release regrab delay freezes in actor pause")
	await _step()
	var delay: float = actor.telemetry().wall_regrab_remaining
	var attaches: int = _count("wall_attached")
	actor.apply_hitpause(.2)
	await _until(func(): return actor.hitpause_remaining <= 0, {"right": 1.0})
	_near(float(actor.telemetry().wall_regrab_remaining), delay, .000001, "local pause cannot advance wall regrab eligibility")
	await _seconds({"right": 1.0}, actor.profile.wall_regrab_delay * .5)
	_check(_count("wall_attached") == attaches, "toward input before unpaused delay cannot reattach")
	await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, actor.profile.wall_regrab_delay + .1)
	_check(actor.main_action == &"wall" and int(actor.telemetry().wall_episode_serial) == 1, "same contact reattaches with remaining allowance only after real simulation delay")
	await _finish()

func _wall_native_recontact_jump() -> void:
	for direction in [-1, 1]:
		await _setup_wall("native fresh toward jump after expired wall grace %d" % direction, direction)
		actor.automatic_physics = true
		var toward: Key = KEY_D if direction > 0 else KEY_A
		_key(toward, true); await _step(null)
		await _until(func(): return _wall_phase() == "slide", null, .8)
		_key(toward, false); await _step(null)
		await _seconds(null, maxf(actor.profile.wall_kick_grace_seconds, actor.profile.wall_regrab_delay) + 2 * dt)
		var before: Dictionary = actor.telemetry()
		_check(actor.main_action != &"wall" and float(before.wall_kick_grace) == 0 and float(before.wall_regrab_remaining) == 0, "fixture has released slide with expired assistance and remains beside the real wall")
		var jumps: int = _count("air_jump")
		var kicks: int = _count("wall_kick")
		var at_tick: int = driver.ticks
		_key(toward, true); _key(KEY_SPACE, true); await _step(null)
		_check(driver.ticks == at_tick + 1 and _count("wall_kick") == kicks + 1 and _wall_phase() == "kick", "fresh parsed toward and Jump resolve supported wall intent on that exact physics tick")
		_check(_count("air_jump") == jumps and actor.air_jumps_left == int(before.air_jumps_left), "supported recontact never spends air jump then overwrites its impulse with slide")
		_check(actor.velocity.x * direction < 0 and actor.velocity.y < 0, "recontact input preserves the actual outward upward kick")
		await _finish()

func _wall_denied_entry_keeps_air_jump() -> void:
	for direction in [-1, 1]:
		await _setup_wall("native ordinary jump survives denied wall entry %d" % direction, direction)
		_check(actor.begin_main_action(&"forced", {"can_wall_grab": false}), "custom owner explicitly denies wall entry while allowing ordinary jump")
		actor.automatic_physics = true
		var toward: Key = KEY_D if direction > 0 else KEY_A
		_key(toward, true); await _seconds(null, actor.profile.wall_regrab_delay + 2 * dt)
		var attached: int = _count("wall_attached")
		var jumps: int = _count("air_jump")
		var before: int = actor.air_jumps_left
		var previous_tick: int = driver.ticks
		_key(KEY_SPACE, true); await _step(null)
		_check(driver.ticks == previous_tick + 1 and _count("air_jump") == jumps + 1 and actor.air_jumps_left == before - 1, "denied support intent resolves one legitimate ordinary air jump on its input tick")
		_check(_count("wall_attached") == attached and _count("wall_kick") == 0 and actor.main_action == &"air_jump" and actor.velocity.y < 0, "automatic wall acquisition cannot overwrite an already accepted ordinary jump after its owner changes")
		var launch_y: float = actor.global_position.y
		await _seconds(null, actor.profile.air_jump_speed / actor.profile.gravity * .6)
		_check(_count("wall_attached") == attached and actor.main_action == &"air_jump" and actor.velocity.y < 0 and actor.global_position.y < launch_y, "accepted ordinary jump preserves upward ascent against the same contact for multiple physics ticks")
		await _finish()

func _wall_supported_rectangle_variants() -> void:
	for kind in ["static", "positive_scale"]:
		await _begin("supported dedicated wall " + kind, Vector2(100, 280), false)
		actor.allow_wall_run = true
		if kind == "static":
			var body = _shaped_body(Vector2(112, -500), [Rect2(0, 0, 32, 1150)], [false])
			tracked_bodies.append(body)
		else: _wall_body(1, 112).scale = Vector2(1.5, .75)
		await _step({}, 2); await _until(func(): return actor.main_action == &"wall", {"right": 1.0}, .5)
		_check(actor.main_action == &"wall" and _wall_phase() == "run", "dedicated upright static or positively scaled rectangle supports the advertised wall action")
		await _step({"right": 1.0, "jump": true})
		_check(_wall_phase() == "kick" and actor.velocity.x < 0 and not _trace_has_solid_overlap(), "supported variant retains real outward kick and collision safety")
		await _finish()

func _wall_native_regrab_boundary() -> void:
	for direction in [-1, 1]:
		for offset in [-1, 0, 1]:
			var boundary := "before" if offset < 0 else ("at" if offset == 0 else "after")
			await _setup_wall("native wall regrab boundary %d %s" % [direction, boundary], direction)
			actor.automatic_physics = true
			var toward: Key = KEY_D if direction > 0 else KEY_A
			_key(toward, true); await _step(null)
			await _until(func(): return _wall_phase() == "slide", null, .8)
			_key(toward, false); await _step(null)
			var release_tick: int = driver.ticks
			# 'At' is the first physics sample at or beyond the authored duration.
			# The default .16 seconds does not fall exactly on either rate's grid.
			var eligible_index := ceili((actor.profile.wall_regrab_delay - .000000001) / dt)
			var request_index: int = eligible_index + offset
			await _step(null, request_index - 1)
			var budget_before: int = actor.air_jumps_left
			var kicks_before: int = _count("wall_kick")
			var jumps_before: int = _count("air_jump")
			_key(toward, true); _key(KEY_SPACE, true); await _step(null)
			measurements["request_after_release_seconds"] = (driver.ticks - release_tick) * dt
			measurements["request_tick_index"] = driver.ticks - release_tick
			measurements["first_eligible_tick_index"] = eligible_index
			_check(driver.ticks == release_tick + request_index, "parsed boundary chord is sampled on the intended exact physics tick")
			_check(_count("air_jump") == jumps_before and actor.air_jumps_left == budget_before, "near-boundary supported intent never spends an ordinary air jump")
			if offset < 0:
				_check(_count("wall_kick") == kicks_before and actor.main_action != &"wall" and float(actor.telemetry().jump_buffer) > 0, "cooldown-only blocker reserves the existing jump buffer without early attachment")
				await _step(null)
			_check(_count("wall_kick") == kicks_before + 1 and _wall_phase() == "kick", "first eligible physics tick consumes one supported outward kick")
			var launch_tick: int = driver.ticks
			var launch_y: float = actor.global_position.y
			await _seconds(null, actor.profile.wall_kick_commit_seconds * .5)
			_check(_count("wall_kick") == kicks_before + 1 and _count("air_jump") == jumps_before and actor.velocity.x * direction < 0 and actor.velocity.y < 0 and actor.global_position.y < launch_y, "supported kick survives subsequent physics ticks without slide swallowing or repeated edge use")
			measurements["launch_after_release_seconds"] = (launch_tick - release_tick) * dt
			await _finish()

func _wall_queued_tap_and_guard_lifecycle() -> void:
	for pause in [false, true]:
		await _setup_wall("native queued wall tap " + ("with pause" if pause else "without pause"))
		actor.automatic_physics = true
		_key(KEY_D, true); await _step(null)
		await _until(func(): return _wall_phase() == "slide", null, .8)
		_key(KEY_D, false); await _step(null)
		await _seconds(null, actor.profile.wall_kick_grace_seconds + 2 * dt)
		var budget: int = actor.air_jumps_left
		_key(KEY_D, true); _key(KEY_SPACE, true); await _step(null)
		_check(bool(actor.telemetry().wall_jump_waiting) and _count("air_jump") == 0 and _count("wall_kick") == 0, "cooldown-only contact reserves the queued native Jump without an early action")
		var remaining: float = actor.telemetry().wall_regrab_remaining
		var buffered: float = actor.telemetry().jump_buffer
		if pause: actor.apply_hitpause(.2)
		_key(KEY_SPACE, false); await _step(null)
		if pause:
			await _until(func(): return actor.hitpause_remaining <= 0, null)
			_near(float(actor.telemetry().wall_regrab_remaining), remaining, .000001, "paused queued wall intent freezes its contact cooldown")
			_near(float(actor.telemetry().jump_buffer), buffered, .000001, "paused queued wall intent freezes its existing input lifetime")
		await _until(func(): return _count("wall_kick") == 1, null, actor.profile.jump_buffer_seconds + dt)
		_check(_count("wall_kick") == 1 and actor.air_jumps_left == budget and not bool(actor.telemetry().wall_jump_waiting), "eligible queued contact consumes exactly one supported kick without air-budget spending")
		_check(actor.velocity.y < 0 and absf(actor.velocity.y) <= actor.profile.jump_release_rise_cap + .01, "release edge captured while waiting cuts the eventual supported jump ascent")
		await _seconds(null, actor.profile.wall_kick_commit_seconds + 2 * dt)
		_check(_count("wall_kick") == 1 and _count("air_jump") == 0, "released queued tap cannot recur after its committed kick")
		await _finish()
	for condition in ["apex", "separation", "pause", "damage", "reset", "roll", "attack", "dive"]:
		await _setup_wall("ordinary wall-adjacent jump guard clears on " + condition)
		_check(actor.begin_main_action(&"forced", {"can_wall_grab": false}), "fixture establishes a genuine wall-entry denial")
		await _seconds({"right": 1.0}, actor.profile.wall_regrab_delay + 2 * dt)
		await _step({"right": 1.0, "jump": true})
		_check(actor.main_action == &"air_jump" and int(actor.telemetry().wall_air_jump_guard_sides) != 0, "accepted ordinary jump protects its actual adjacent contact during ascent")
		if condition == "apex":
			var start_y: float = actor.global_position.y
			await _until(func(): return actor.main_action == &"wall", {"right": 1.0, "jump": true}, actor.profile.air_jump_speed / actor.profile.gravity + .15)
			_check(actor.main_action == &"wall" and int(actor.telemetry().wall_air_jump_guard_sides) == 0 and actor.global_position.y < start_y - 30, "guard permits full ordinary ascent and retires by apex so real wall entry can resume")
		elif condition == "separation":
			await _seconds({"left": 1.0, "jump": true}, .14)
			_check(int(actor.telemetry().wall_air_jump_guard_sides) == 0 and 112 - actor.global_position.x - actor.profile.body_width * .5 > actor.profile.wall_separation_distance, "genuine separation clears only the old contact protection")
		elif condition == "pause":
			actor.apply_hitpause(.2); var at: Vector2 = actor.global_position
			await _until(func(): return actor.hitpause_remaining <= 0, {"right": 1.0, "jump": true})
			_check(actor.global_position == at and int(actor.telemetry().wall_air_jump_guard_sides) != 0, "local pause preserves valid ascent protection without advancing the jump")
			await _seconds({"right": 1.0, "jump": true}, .1)
			_check(actor.main_action == &"air_jump" and actor.velocity.y < 0, "paused ordinary jump resumes its ascent without automatic slide replacement")
		else:
			if condition == "damage": actor.receive_hit({"rollable": false, "hitpause": .1})
			elif condition == "reset": actor.reset_actor(Vector2(20, 280))
			elif condition == "dive": await _step({"down": 1.0, "jump": false}); await _step({"down": 1.0, "jump": true})
			else: await _step({condition: true})
			_check(int(actor.telemetry().wall_air_jump_guard_sides) == 0, "accepted replacement action or reset retires ordinary-jump contact protection")
		await _finish()

func _wall_waiting_gate_recheck() -> void:
	for change in ["jump_lock", "ability", "removed", "input_disabled", "reset"]:
		var body = await _setup_wall("queued wall intent rechecks " + change)
		actor.automatic_physics = true
		_key(KEY_D, true); await _step(null)
		await _until(func(): return _wall_phase() == "slide", null, .8)
		_key(KEY_D, false); await _step(null)
		await _seconds(null, actor.profile.wall_kick_grace_seconds + 2 * dt)
		_key(KEY_D, true); _key(KEY_SPACE, true); await _step(null)
		_check(bool(actor.telemetry().wall_jump_waiting), "fixture reserves a still-live jump solely behind regrab cooldown")
		_key(KEY_SPACE, false)
		match change:
			"jump_lock": actor.set_weapon_permissions({"can_jump": false})
			"ability": actor.allow_wall_run = false
			"removed": body.queue_free()
			"input_disabled": actor.allow_input = false
			"reset": actor.reset_actor(Vector2(20, 280))
		await _step(null)
		if change == "jump_lock":
			_check(_count("wall_kick") == 0 and _count("air_jump") == 0, "new host jump denial prevents a waiting request from executing")
			actor.set_weapon_permissions()
			await _until(func(): return _count("wall_kick") == 1, null, actor.profile.jump_buffer_seconds)
			_check(_count("wall_kick") == 1 and _count("air_jump") == 0, "restored permission consumes the original supported request once while its buffer remains live")
			_check(actor.velocity.y < 0 and absf(actor.velocity.y) <= actor.profile.jump_release_rise_cap + .01, "brief host denial cannot erase a waiting tap's release cut")
		elif change in ["ability", "removed"]:
			_check(_count("wall_kick") == 0 and _count("air_jump") == 1 and actor.main_action == &"air_jump", "when supported eligibility disappears the still-valid ordinary jump resolves without stale wall authority")
		else:
			if change == "input_disabled": actor.allow_input = true
			await _seconds(null, actor.profile.wall_regrab_delay + 2 * dt)
			_check(_count("wall_kick") == 0 and _count("air_jump") == 0 and not bool(actor.telemetry().wall_jump_waiting), "input disable or reset retires the queued request without a later ghost launch")
		await _finish()
