extends "res://combat_pc/tests/traversal_regression.gd"
## Independent connected ladder/vine acceptance. Earlier harnesses stay immutable.
const CLIMBABLE = preload("res://combat_pc/components/climbable.tscn")

class SensorMotion extends Node:
	var sensor: Node2D
	var velocity := Vector2.ZERO
	var enabled := true
	func _physics_process(delta: float) -> void:
		if enabled and is_instance_valid(sensor): sensor.global_position += velocity * delta

func _run() -> void:
	production_paths.append("res://combat_pc/tests/combat_regression.gd")
	production_paths.append("res://combat_pc/components/climbable.gd")
	production_paths.append("res://combat_pc/components/climbable.tscn")
	production_paths.append("res://combat_pc/tests/traversal_regression.gd")
	production_paths.append("res://combat_pc/tests/climb_regression.gd")
	for path in production_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _climb_cases()
	var hashes := {}
	for path in production_paths: hashes[path] = FileAccess.get_sha256(path)
	var stable := true
	for path in starting_hashes: stable = stable and starting_hashes[path] == hashes[path]
	if not stable: failures.append("Source files changed during climb run; final rerun required")
	var report := {
		"milestone": 4, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(),
		"generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "Actual Godot physics callbacks, production player scene, collision sweeps and independent space queries",
		"numeric_source": "Original MOKSHA profile values; no recovered Dead Cells timings or executable parity",
		"movement_profile": _resource_values(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _resource_values(load("res://combat_pc/resources/combat_profile.tres"))
	}
	FileAccess.open("res://combat_pc/tests/climb_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  "))
	print("MOKSHA CLIMB %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _climb_cases() -> void:
	await _basic_motion()
	await _selection_and_gates()
	await _ends_and_top_entry()
	await _detach_actions()
	await _target_adversaries()
	await _moving_and_blocked()
	await _native_and_reset()
	await _review_edges()
	await _released_grip_grace()

func _sensor(at: Vector2, height := 200.0, type_ := "ladder", width := 20.0, priority := 0, label := "Climbable") -> Node:
	var sensor = CLIMBABLE.instantiate(); sensor.position = at; sensor.height = height; sensor.width = width
	sensor.climb_type = type_; sensor.selection_priority = priority; sensor.name = label
	world.add_child(sensor)
	return sensor

func _motion(sensor: Node2D, velocity: Vector2) -> SensorMotion:
	var motion = SensorMotion.new(); motion.sensor = sensor; motion.velocity = velocity; motion.process_physics_priority = -30
	world.add_child(motion)
	return motion

func _setup_grip(label: String, type_ := "ladder", at := Vector2(100, 140)) -> Node:
	await _begin(label, at, false)
	_surface(Vector2(-500, 360), Vector2(1500, 30))
	var sensor = _sensor(Vector2(100, 240), 220, type_)
	await _step({}, 2); await _step({"up": 1.0})
	await _until(func(): return actor.main_action == &"climb", {"up": 1.0}, .5)
	await _step({}, 2)
	_check(actor.main_action == &"climb", "actual overlapping sensor attaches on deliberate vertical input")
	return sensor

func _detach_reasons() -> Array:
	return events.filter(func(e): return e.event == "climb_detached").map(func(e): return e.data.reason)

func _basic_motion() -> void:
	for type_ in ["ladder", "vine"]:
		await _begin(type_ + " deliberate align ascend stop descend", Vector2(107, 200), true)
		_sensor(Vector2(100, 200), 160, type_)
		await _seconds({}, .1)
		_check(actor.main_action != &"climb" and actor.global_position.x == 107, "sensor overlap without vertical intent never snaps or auto-attaches")
		var before: Vector2 = actor.global_position
		await _step({"up": 1.0})
		_check(actor.main_action == &"climb" and actor.telemetry().climb_type == type_, "deliberate Up attaches selected sensor type")
		_check(absf(actor.global_position.x - before.x) <= actor.profile.climb_align_speed * dt + .01, "alignment advances by swept speed rather than teleporting to axis")
		await _until(func(): return absf(actor.global_position.x - 100) <= actor.profile.climb_end_tolerance, {"up": 1.0})
		await _seconds({"up": 1.0}, actor.profile.climb_up_speed / actor.profile.climb_acceleration + 2 * dt)
		_near(actor.velocity.y, -actor.profile.climb_up_speed, .01, "ascent reaches authored speed")
		var rise_start: float = actor.global_position.y
		await _seconds({"up": 1.0}, .2)
		measurements["steady_rise_distance"] = rise_start - actor.global_position.y
		await _seconds({}, actor.profile.climb_up_speed / actor.profile.climb_braking + 2 * dt)
		_check(actor.main_action == &"climb" and absf(actor.velocity.y) < .01 and actor.telemetry().climb_phase == &"idle", "neutral input brakes into stable attached idle")
		await _seconds({"down": 1.0}, actor.profile.climb_down_speed / actor.profile.climb_acceleration + 2 * dt)
		_near(actor.velocity.y, actor.profile.climb_down_speed, .01, "descent reaches independent authored speed")
		_check(not _ordinary_solid_overlap(), "ordinary climb has no terrain overlap")
		await _finish()

func _selection_and_gates() -> void:
	for criterion in ["priority", "distance", "path"]:
		await _begin("overlap selection by " + criterion, Vector2(100, 140), false)
		var first = _sensor(Vector2(104, 240), 220, "ladder", 30, 0, "BFirst")
		var second = _sensor(Vector2(96, 240), 220, "vine", 30, 0, "ASecond")
		var wanted = second
		if criterion == "priority": first.selection_priority = 3; wanted = first
		elif criterion == "distance": first.position.x = 101; wanted = first
		await _step({}, 2); await _step({"up": 1.0})
		_check(actor.telemetry().climb_target_id == wanted.get_instance_id(), "overlapping physical candidates resolve deterministically by configured rule")
		await _finish()
	for gate in ["ability", "host_climb", "host_move", "main", "input"]:
		await _begin("climb entry gate " + gate, Vector2(100, 140), false)
		_sensor(Vector2(100, 240)); await _step({}, 2)
		if gate == "ability": actor.allow_climb = false
		elif gate == "host_climb": actor.set_weapon_permissions({"can_climb": false})
		elif gate == "host_move": actor.set_weapon_permissions({"can_move": false})
		elif gate == "main": actor.begin_main_action(&"gated", {"can_climb": false})
		else: actor.allow_input = false
		await _seconds({"up": 1.0}, .1)
		_check(actor.main_action != &"climb" and _count("climb_attached") == 0, "ability, capabilities and host controls remain authoritative over sensor overlap")
		await _finish()
	await _setup_grip("attached movement lock preserves grip")
	actor.set_weapon_permissions({"can_move": false}); var before: Vector2 = actor.global_position
	await _seconds({"up": 1.0}, .2)
	_check(actor.main_action == &"climb" and actor.global_position == before and actor.velocity == Vector2.ZERO, "host movement lock idles a valid grip without unintended climb drift")
	actor.set_weapon_permissions(); await _step({"up": 1.0})
	_check(actor.velocity.y < 0, "restoring movement resumes attached ascent")
	await _finish()

func _ends_and_top_entry() -> void:
	await _begin("ladder upward one-way top exit and held loop", Vector2(100, 200), true)
	_sensor(Vector2(100, 200), 120); _oneway(Vector2(40, 80), Vector2(120, 8)); await _step({}, 2)
	await _step({"up": 1.0}); await _until(func(): return _detach_reasons().has("top_exit"), {"up": 1.0}, 2)
	_check(actor.grounded and absf(actor.global_position.y - 80) < .2 and _count("climb_attached") == 1, "ascent exits onto actual top one-way support")
	await _seconds({"up": 1.0}, actor.profile.climb_regrab_delay + .2)
	_check(_count("climb_attached") == 1 and actor.main_action != &"climb", "held Up after top exit cannot loop through attachment")
	await _finish()
	for floor_kind in ["bottom", "intermediate"]:
		await _setup_grip("climb descends to " + floor_kind + " floor")
		var floor_y := 240.0 if floor_kind == "bottom" else 195.0
		_surface(Vector2(40, floor_y), Vector2(120, 12)); await _step()
		await _until(func(): return actor.main_action != &"climb", {"down": 1.0}, 2)
		await _step({"down": 1.0}, 2)
		_check(actor.grounded and absf(actor.global_position.y - floor_y) < .2 and not _ordinary_solid_overlap(), "real floor contact ends descent with supported collider")
		await _seconds({"down": 1.0}, .3)
		_check(_count("climb_attached") == 1, "held Down cannot automatically reattach after floor exit")
		await _finish()

func _detach_actions() -> void:
	for action in ["jump", "roll", "attack", "dive", "damage", "horizontal"]:
		await _setup_grip("attached detach action " + action)
		actor.air_jumps_left = 0
		var air_roll_before: bool = actor.air_roll_available; var dive_before: bool = actor.dive_available
		if action == "damage": actor.receive_hit({"rollable": false, "hitpause": .06})
		elif action == "dive": await _step({"down": 1.0, "jump": true})
		elif action == "horizontal": await _step({"right": 1.0})
		else: await _step({action: true})
		_check(actor.main_action != &"climb" and _count("climb_detached") == 1, "accepted action detaches live sensor exactly once")
		if action == "jump":
			var jumps = events.filter(func(e): return e.event == "ground_jump")
			_check(actor.velocity.y < 0 and jumps.size() == 1 and jumps[0].data.from_climb, "fresh grip jump launches even when air jump is already spent")
			_check(actor.air_jumps_left == 0 and actor.air_roll_available == air_roll_before and actor.dive_available == dive_before, "grip jump preserves all three airborne budgets")
		elif action == "roll": _check(actor.main_action == &"roll" and not actor.air_roll_available, "roll detach spends its ordinary airborne allowance")
		elif action == "dive": _check(actor.main_action == &"dive" and not actor.dive_available, "down-jump detach enters eligible dive and spends dive allowance")
		elif action == "attack": _check(actor.weapon_phase == &"windup", "melee detach starts live weapon windup")
		elif action == "damage": _check(actor.main_action == &"hurt" and actor.hitpause_remaining > 0, "damage detaches into actual hurt freeze")
		else: _near(actor.velocity.x, actor.profile.climb_release_speed, .01, "side release uses profile velocity")
		await _finish()
	for action in ["roll", "dive", "jump"]:
		await _setup_grip("unavailable attached action " + action)
		if action == "roll": actor.air_roll_available = false
		elif action == "dive": actor.dive_available = false
		else: actor.set_weapon_permissions({"can_jump": false})
		await _step({"down": 1.0, "jump": true} if action == "dive" else {action: true})
		_check(actor.main_action == &"climb" and _count("climb_detached") == 0, "unavailable action leaves valid grip intact and does not fall back")
		await _finish()
	await _begin("physical spent budgets grip jump and reattachment", Vector2(100, 494), false)
	var original_floor = _surface(Vector2(-200, 500), Vector2(1500, 30)); await _until(func(): return actor.grounded)
	await _seconds({"jump": true}, .1); await _step(); await _step({"jump": true})
	await _step(); await _step({"down": 1.0, "jump": true}); await _step({"roll": true})
	original_floor.queue_free()
	await _until(func(): return actor.main_action != &"roll", {}, .6)
	_check(_count("air_jump") == 1 and _count("dive_started") == 1 and _count("roll_started") == 1 and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "actual connected air jump, dive and roll spend all airborne allowances")
	var sensor = _sensor(Vector2(actor.global_position.x, actor.global_position.y + 120), 360)
	await _step({}, 2); await _step({"up": 1.0}); await _step()
	_check(actor.main_action == &"climb" and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "physical attachment does not refill any spent airborne resource")
	var jump_count = _count("ground_jump"); await _step({"jump": true})
	_check(_count("ground_jump") == jump_count + 1 and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "supported grip detach supplies one jump without manufacturing air resources")
	await _seconds({"jump": true, "up": 1.0}, actor.profile.climb_regrab_delay + .04)
	_check(_count("climb_attached") == 1 and _count("ground_jump") == jump_count + 1, "held jump and vertical input cannot regrab or repeatedly launch")
	await _step(); await _step({"jump": true})
	_check(_count("ground_jump") == jump_count + 1 and _count("air_jump") == 1, "fresh airborne press without reattachment cannot reuse grip jump")
	await _seconds({}, actor.profile.jump_buffer_seconds + 2 * dt)
	await _step({"up": 1.0}); await _step()
	_check(actor.main_action == &"climb" and actor.telemetry().climb_target_id == sensor.get_instance_id(), "neutral plus delay and actual overlap permit physical reattachment")
	await _step({"jump": true})
	_check(_count("ground_jump") == jump_count + 2 and actor.air_jumps_left == 0, "a second real attachment permits one new supported jump")
	await _finish()

func _target_adversaries() -> void:
	for change in ["disabled", "removed", "rotated", "negative_scale", "width", "shape_null", "shape_resize", "shape_transform", "shape_other", "shape_removed", "script_withdrawn", "layer", "teleport", "ability", "host"]:
		var sensor = await _setup_grip("attached sensor change " + change)
		var before: Vector2 = actor.global_position
		match change:
			"disabled": sensor.enabled = false
			"removed": sensor.queue_free()
			"rotated": sensor.rotation = .1
			"negative_scale": sensor.scale.x = -1
			"width": sensor.width += 8
			"shape_null": sensor.get_node("SensorShape").shape = null
			"shape_resize": sensor.get_node("SensorShape").shape.size.x += 8
			"shape_transform": sensor.get_node("SensorShape").position.x += 8
			"shape_other": sensor.get_node("SensorShape").shape = CircleShape2D.new()
			"shape_removed": sensor.get_node("SensorShape").queue_free()
			"script_withdrawn": sensor.set_script(null)
			"layer": sensor.collision_layer = 0
			"teleport": sensor.position.x += 200
			"ability": actor.allow_climb = false
			"host": actor.set_weapon_permissions({"can_climb": false})
		await _step({}, 2)
		_check(actor.main_action != &"climb" and _count("climb_detached") == 1 and actor.telemetry().climb_target_id == 0, "invalidated sensor or gate releases grip once and clears live target")
		_check(absf(actor.global_position.x - before.x) < 1 and not _ordinary_solid_overlap(), "invalid target cannot teleport or embed actor")
		await _finish()
	await _begin("directionally ineligible overlap does not mask valid sensor", Vector2(100, 200), true)
	_sensor(Vector2(100, 200), 160, "ladder", 24, 0, "ValidBelow")
	var ineligible = _sensor(Vector2(100, 340), 140, "vine", 24, 9, "AtTopIneligible")
	await _step({}, 2); await _step({"up": 1.0})
	_check(actor.main_action == &"climb" and actor.telemetry().climb_target_id != ineligible.get_instance_id(), "directional endpoint eligibility is filtered before priority ranking")
	await _finish()

func _moving_and_blocked() -> void:
	for motion in [Vector2(60, 0), Vector2(-60, -30)]:
		var sensor = await _setup_grip("moving sensor transport " + str(motion))
		var start: Vector2 = actor.global_position
		_motion(sensor, motion); await _seconds({}, .2)
		_near(actor.global_position.x - start.x, motion.x * ceili(.2 / dt) * dt, .05, "idle grip follows swept horizontal sensor transport")
		_near(actor.global_position.y - start.y, motion.y * ceili(.2 / dt) * dt, .05, "idle grip follows swept vertical sensor transport")
		_check(actor.main_action == &"climb" and not _ordinary_solid_overlap(), "supported translation keeps valid grip without terrain overlap")
		await _finish()
	for paused_motion in [false, true]:
		var sensor = await _setup_grip("sensor transport wall blockage paused " + str(paused_motion))
		_surface(Vector2(112, 50), Vector2(4, 260)); await _step()
		_motion(sensor, Vector2(80, 0))
		if paused_motion: actor.apply_hitpause(.15)
		await _until(func(): return actor.main_action != &"climb", {}, .3)
		_check(_detach_reasons().has("transport_blocked") and actor.global_position.x <= 104.15 and not _ordinary_solid_overlap(), "moving sensor releases on real swept wall obstruction, including local pause")
		await _finish()
	var fast = await _setup_grip("fast sensor movement releases without chasing")
	var old: Vector2 = actor.global_position; _motion(fast, Vector2(actor.profile.climb_max_transport_speed * 3, 0)); await _step()
	_check(_detach_reasons().has("target_moved_away") and absf(actor.global_position.x - old.x) < 1, "excessive target speed cannot drag or teleport actor")
	await _finish()
	await _begin("horizontal alignment blocked by thin wall", Vector2(100, 140), false)
	_sensor(Vector2(128, 240), 220, "ladder", 60)
	_surface(Vector2(110, 20), Vector2(4, 280)); await _step({}, 2); await _step({"up": 1.0})
	await _seconds({"up": 1.0}, .2)
	_check(_detach_reasons().has("alignment_blocked") and actor.global_position.x <= 102.15 and not _ordinary_solid_overlap(), "wide-sensor alignment cannot teleport through a separate wall")
	await _finish()
	await _setup_grip("climb reaches solid ceiling then reverses")
	_surface(Vector2(70, 65), Vector2(60, 10)); await _step()
	await _until(func(): return actor.telemetry().climb_phase == &"blocked", {"up": 1.0}, 1)
	_check(actor.main_action == &"climb" and actor.telemetry().climb_phase == &"blocked" and not _ordinary_solid_overlap(), "upward sweep stops safely at actual ceiling")
	await _seconds({"down": 1.0}, .15)
	_check(actor.main_action == &"climb" and actor.velocity.y > 0 and not _ordinary_solid_overlap(), "reverse input escapes blocked ceiling without losing valid grip")
	await _finish()

func _native_and_reset() -> void:
	await _begin("native parsed climb and grip jump", Vector2(100, 140), false)
	_sensor(Vector2(100, 240)); await _step({}, 2)
	actor.automatic_physics = true
	_key(KEY_W, true); await _step(null); _key(KEY_W, false); await _step(null)
	_check(actor.main_action == &"climb", "native vertical input attaches actual sensor")
	_key(KEY_C, true); await _step(null); _key(KEY_C, false); await _step(null)
	_check(actor.main_action != &"climb" and _count("ground_jump") == 1, "native fresh Jump detaches supported grip once")
	await _finish()
	await _setup_grip("reset clears active sensor and regrab lifecycle")
	actor.apply_hitpause(.2); actor.reset_actor(Vector2(100, 140))
	var t: Dictionary = actor.telemetry()
	_check(actor.main_action == &"locomotion" and t.climb_target_id == 0 and t.climb_regrab_remaining == 0 and not t.climb_needs_neutral and actor.hitpause_remaining == 0, "reset clears live grip, pause and regrab state")
	await _step({"up": 1.0})
	_check(actor.main_action == &"climb", "initial post-reset input can attach real overlapping sensor")
	await _finish()
	for ending in ["continue", "attack", "damage", "reset"]:
		await _begin("one-way top entry cleanup " + ending, Vector2(100, 74), false)
		var top = _oneway(Vector2(40, 80), Vector2(120, 8)); _surface(Vector2(-200, 300), Vector2(800, 30))
		_sensor(Vector2(100, 260), 180); await _until(func(): return actor.grounded)
		await _step({"down": 1.0})
		_check(actor.main_action == &"climb" and _exceptions().has(top) and actor.crouched, "Down from supported top uses one validated target exception and safe small body")
		if ending == "attack": await _step({"attack": true})
		elif ending == "damage": actor.receive_hit({"rollable": false, "hitpause": .06, "impulse": Vector2(0, -80)})
		elif ending == "reset": actor.reset_actor(Vector2(240, 80))
		await _seconds({"down": 1.0} if ending == "continue" else {}, .7)
		_check(_exceptions().is_empty() and not actor.telemetry().drop_exception_active, "top-entry exception clears independently of continued climb or replacement action")
		_check(not _ordinary_solid_overlap(), "top entry and cancellation preserve all independent solid collisions")
		await _finish()

func _review_edges() -> void:
	for paused_delay in [false, true]:
		await _setup_grip("regrab delay after actual neutral paused " + str(paused_delay))
		await _step({"right": 1.0}); await _step()
		if paused_delay:
			var cooldown: float = actor.telemetry().climb_regrab_remaining
			actor.apply_hitpause(.3); await _until(func(): return actor.hitpause_remaining <= 0)
			_near(actor.telemetry().climb_regrab_remaining, cooldown, .000001, "local hitpause freezes regrab simulation-time delay")
		await _step({"up": 1.0})
		_check(actor.main_action != &"climb" and _count("climb_attached") == 1, "neutral alone cannot bypass remaining regrab delay")
		await _seconds({"up": 1.0}, actor.profile.climb_regrab_delay + 2 * dt)
		_check(actor.main_action == &"climb" and _count("climb_attached") == 2, "valid overlap reattaches after both real neutral and elapsed delay")
		await _finish()
	await _begin("fresh moving sensor overlap cannot use stale broadphase", Vector2(100, 170), false)
	var shifted = _sensor(Vector2(100, 240), 180); await _step({}, 3)
	var one_tick = _motion(shifted, Vector2(200.0 / dt, 0))
	await _step({"up": 1.0}); one_tick.enabled = false
	_check(actor.main_action != &"climb" and _count("climb_attached") == 0, "sensor translated before actor callback cannot attach using previous physics overlap")
	_check(absf(actor.global_position.x - 100) < .01, "stale sensor candidate cannot begin alignment toward distant current axis")
	await _finish()

func _released_grip_grace() -> void:
	for gate in ["jump_permission", "climb_ability"]:
		await _setup_grip("released grip grace respects " + gate)
		actor.air_jumps_left = 0; await _step({"right": 1.0})
		if gate == "jump_permission": actor.set_weapon_permissions({"can_jump": false})
		else: actor.allow_climb = false
		await _step({"jump": true})
		_check(_count("ground_jump") == 0 and _count("air_jump") == 0, "recent grip support cannot override host jump lock or disabled climb ability")
		await _finish()
	await _begin("released grip grace respects outstanding top cleanup", Vector2(100, 74), false)
	_oneway(Vector2(40, 80), Vector2(120, 8)); _sensor(Vector2(100, 260), 180)
	await _until(func(): return actor.grounded); await _step({"down": 1.0}); actor.air_jumps_left = 0
	await _step({"right": 1.0}); await _step({"jump": true})
	_check(actor.telemetry().drop_exception_active and actor.crouched and _count("ground_jump") == 0, "adjacent-key grace cannot expand into the still-ignored top-entry platform")
	await _finish()
	for direction in [-1, 1]:
		await _setup_grip("native adjacent horizontal then jump " + str(direction))
		actor.air_jumps_left = 0; actor.air_roll_available = false; actor.dive_available = false; actor.automatic_physics = true
		var key: Key = KEY_D if direction > 0 else KEY_A
		_key(key, true); await _step(null)
		_check(actor.main_action != &"climb" and actor.telemetry().climb_jump_grace > 0, "native horizontal key releases grip with bounded grace")
		_key(KEY_SPACE, true); await _step(null)
		_check(_count("ground_jump") == 1 and actor.velocity.y < 0 and actor.air_jumps_left == 0 and not actor.air_roll_available and not actor.dive_available, "next actual physics tick Space uses prior supported grip and preserves spent budgets")
		_key(KEY_SPACE, false); _key(key, false); await _step(null); _key(KEY_SPACE, true); await _step(null)
		_check(_count("ground_jump") == 1 and _count("air_jump") == 0 and actor.telemetry().climb_jump_grace == 0, "grace is consumed once and cannot supply a repeated fresh jump")
		_key(KEY_SPACE, false); await _step(null); await _finish()
	await _setup_grip("released grip grace expires in actor time")
	actor.air_jumps_left = 0; await _step({"right": 1.0})
	await _seconds({}, actor.profile.climb_jump_grace_seconds + dt); await _step({"jump": true})
	_check(actor.telemetry().climb_jump_grace == 0 and _count("ground_jump") == 0 and _count("air_jump") == 0, "expired released-grip support cannot bypass spent air jump")
	await _finish()
	await _setup_grip("released grip grace and queued jump survive local pause")
	actor.air_jumps_left = 0; await _step({"right": 1.0}); var grace: float = actor.telemetry().climb_jump_grace
	actor.apply_hitpause(.2); await _step({"jump": true}); await _until(func(): return actor.hitpause_remaining <= 0, {"jump": true})
	_near(actor.telemetry().climb_jump_grace, grace, .000001, "actor hitpause freezes released-grip grace timer")
	await _step({"jump": true})
	_check(_count("ground_jump") == 1 and actor.air_jumps_left == 0, "paused queued jump consumes recent support once on resume")
	await _finish()
	for invalidation in ["removed", "disabled", "moved_away", "shape_changed"]:
		var sensor = await _setup_grip("released grip grace invalidation " + invalidation)
		actor.air_jumps_left = 0; await _step({"right": 1.0})
		match invalidation:
			"removed": sensor.queue_free()
			"disabled": sensor.enabled = false
			"moved_away": sensor.position.x += 200
			"shape_changed": sensor.get_node("SensorShape").shape = null
		await _step({"jump": true})
		_check(_count("ground_jump") == 0 and actor.telemetry().climb_jump_grace == 0, "recent support is invalidated before jump when target disappears or changes")
		await _finish()
	for action in ["roll", "attack", "dive", "damage", "forced", "reset"]:
		await _setup_grip("released grip grace cleared by " + action)
		actor.air_jumps_left = 0; await _step({"right": 1.0})
		if action == "dive": await _step({"down": 1.0, "jump": true})
		elif action == "damage": actor.receive_hit({"rollable": false, "hitpause": 0.0})
		elif action == "forced": actor.begin_main_action(&"host_forced", {})
		elif action == "reset": actor.reset_actor(Vector2(100, 140))
		else: await _step({action: true})
		_check(actor.telemetry().climb_jump_grace == 0, "accepted replacement action retires recent grip-jump authority")
		await _finish()
	for type_ in ["ladder", "vine"]:
		await _begin("positive scale actual geometry " + type_, Vector2(100, 140), false)
		var scaled = _sensor(Vector2(100, 240), 140, type_); scaled.scale = Vector2(1.5, 1.5)
		await _step({}, 2); await _step({"up": 1.0})
		var t: Dictionary = actor.telemetry()
		_check(actor.main_action == &"climb" and absf(t.climb_top_y - 30) < .01 and absf(t.climb_width - 30) < .01, "positive-scale sensor uses actual world dimensions")
		_near(t.climb_rung_spacing, 18, .001, "rung metadata follows actual vertical scale")
		await _finish()
	await _setup_grip("movement lock preserves independently allowed grip jump")
	actor.air_jumps_left = 0; actor.set_weapon_permissions({"can_move": false, "can_jump": true})
	await _step({"jump": true})
	_check(actor.main_action != &"climb" and _count("ground_jump") == 1 and actor.air_jumps_left == 0, "ordinary movement lock does not suppress independently permitted supported jump")
	await _finish()
	for horizontal in [-1.0, 1.0, .2]:
		await _begin("entry vertical dominance " + str(horizontal), Vector2(100, 140), false)
		_sensor(Vector2(100, 240), 220, "ladder", 40); await _step({}, 2)
		await _step(_direction(int(signf(horizontal)), {"up": 1.0}).merged({"left": absf(horizontal) if horizontal < 0 else 0.0, "right": absf(horizontal) if horizontal > 0 else 0.0}, true))
		_check((actor.main_action == &"climb") == (absf(horizontal) < .5), "equal diagonal does not attach; deliberately dominant vertical analog input does")
		await _finish()
	for mode in ["climb", "carrier", "paused_carrier"]:
		await _begin("forbidden upward one-way crossing " + mode, Vector2(100, 170), false)
		var sensor = _sensor(Vector2(100, 240), 220)
		var upper = _oneway(Vector2(40, 120), Vector2(120, 8)); await _step({}, 2)
		actor.begin_main_action(&"no_upward_pass", {"can_jump_through_up": false})
		await _step({"up": 1.0}); await _step()
		if mode == "climb":
			await _until(func(): return actor.telemetry().climb_phase == &"blocked", {"up": 1.0}, .6)
			_check(actor.main_action == &"climb" and actor.telemetry().climb_phase == &"blocked", "carried no-upward-pass capability blocks ordinary climb at one-way underside")
		else:
			_motion(sensor, Vector2(0, -80))
			if mode == "paused_carrier": actor.apply_hitpause(.3)
			await _until(func(): return actor.main_action != &"climb", {}, .5)
			_check(_detach_reasons().has("transport_blocked"), "sensor transport cannot bypass denied one-way crossing, including pause")
		_check(actor.global_position.y - actor.body_height >= upper.global_position.y + upper.size.y - .15, "whole actor remains below denied one-way surface")
		await _finish()
	await _begin("top descent reversal returns to same one-way", Vector2(100, 74), false)
	var platform = _oneway(Vector2(40, 80), Vector2(120, 8)); _sensor(Vector2(100, 260), 180)
	await _until(func(): return actor.grounded); await _step({"down": 1.0})
	_check(actor.main_action == &"climb" and _exceptions().has(platform), "top descent begins with validated cleanup target")
	await _until(func(): return actor.main_action != &"climb", {"up": 1.0}, .6)
	await _until(func(): return actor.grounded, {"up": 1.0}, .6)
	_check(actor.grounded and absf(actor.global_position.y - 80) < .2 and _exceptions().is_empty(), "reversing top entry rises far enough to restore target and settle safely onto it")
	await _finish()
	await _begin("top descent jump respects outstanding cleanup", Vector2(100, 74), false)
	_oneway(Vector2(40, 80), Vector2(120, 8)); _sensor(Vector2(100, 260), 180)
	await _until(func(): return actor.grounded); await _step({"down": 1.0}); actor.air_jumps_left = 0
	await _step({"jump": true})
	_check(actor.main_action == &"climb" and actor.crouched and _count("ground_jump") == 0, "grip jump cannot expand through uncleared top-entry platform")
	await _until(func(): return not actor.telemetry().drop_exception_active, {"down": 1.0}, .8)
	await _until(func(): return actor.can_stand(), {"down": 1.0}, .6)
	await _seconds({}, actor.profile.jump_buffer_seconds + dt); await _step({"jump": true})
	_check(actor.main_action != &"climb" and _count("ground_jump") == 1 and actor.air_jumps_left == 0, "fresh jump after full standing clearance receives the supported grip impulse")
	await _finish()
	var sensor = await _setup_grip("disabled input cannot fake regrab neutral")
	sensor.enabled = false; await _step({"up": 1.0}); actor.allow_input = false
	await _seconds({"up": 1.0}, actor.profile.climb_regrab_delay + .02)
	sensor.enabled = true; actor.allow_input = true; await _step({"up": 1.0})
	_check(actor.main_action != &"climb" and _count("climb_attached") == 1, "held physical Up through disabled controls cannot clear regrab latch")
	await _step(); await _step({"up": 1.0})
	_check(actor.main_action == &"climb" and _count("climb_attached") == 2, "actual neutral plus new vertical intent reattaches after delay")
	await _finish()
