extends SceneTree
## M7 authored horizontal-momentum and supported-slope acceptance.
## Each real physics callback records immediately before/after one stock call.
const PLAYER = preload("res://combat_pc/player.tscn")
const PROBE = preload("res://combat_pc/tests/soft_slope_probe_player.gd")
const CLIMBABLE = preload("res://combat_pc/components/climbable.tscn")

class TickDriver extends Node:
	var harness: SceneTree
	var enabled := false
	func _physics_process(delta: float) -> void:
		if enabled: harness.physics_sample(delta)

var world: Node2D
var actor: Node
var driver: TickDriver
var hz := 120
var dt := 1.0 / 120.0
var ticks := 0
var input_frame: Variant = {}
var last_engine_tick := -1
var engine_gaps: Array[int] = []
var deltas: Array[float] = []
var name_ := ""
var params := {}
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var assertions: Array[Dictionary] = []
var measurements := {}
var scenarios: Array[Dictionary] = []
var failures: Array[String] = []
var checks := 0
var start_checks := 0
var start_failures := 0
var instrumented := false
var terrain: PhysicsBody2D
var terrain_points: Array[Vector2] = []
var boxes: Array[Dictionary] = []
var before_tick: Callable = Callable()
var only_group := ""
var starting_hashes := {}
var source_paths: Array[String] = ["res://combat_pc/player.gd", "res://combat_pc/player.tscn",
	"res://combat_pc/resources/movement_profile.gd", "res://combat_pc/resources/movement_profile.tres",
	"res://combat_pc/resources/combat_profile.gd", "res://combat_pc/resources/combat_profile.tres",
	"res://combat_pc/components/contact_adapter.gd", "res://combat_pc/components/climbable.gd", "res://combat_pc/components/climbable.tscn",
	"res://combat_pc/fixtures/slope_course.gd", "res://combat_pc/fixtures/slope_course.tscn",
	"res://combat_pc/tests/soft_slope_regression.gd", "res://combat_pc/tests/soft_slope_probe_player.gd"]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
		if argument.begins_with("--group="): only_group = argument.trim_prefix("--group=")
	Engine.physics_ticks_per_second = hz; dt = 1.0 / hz
	_run.call_deferred()

func _run() -> void:
	for filename in DirAccess.get_files_at("res://combat_pc/visuals"):
		if filename.ends_with(".gd"): source_paths.append("res://combat_pc/visuals/" + filename)
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	if only_group in ["", "planes"]:
		await _slope_matrix()
		await _neutral_phase_and_probe_equivalence()
	if only_group in ["", "connected"]:
		await _continuous_joins()
		await _actual_lab_course()
		await _discontinuous_edges()
		await _component_blocking()
		await _action_and_carrier_flows()
		await _lifecycle_and_bounded_safety()
	if only_group in ["", "connected", "callback"]: await _grounded_callback_replacement()
	var hashes := {}; var stable := true
	for path in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Source changed during soft-slope run; final rerun required")
	var output := {"milestone": 7, "selected_group": only_group, "physics_hz": hz, "checks": checks, "failures": failures, "scenarios": scenarios,
		"engine": Engine.get_version_info(), "generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "One production call per actual physics callback, immediate before/after samples, exact current collision rectangle and independent piecewise terrain-plane clearance",
		"numeric_source": "Authored MOKSHA contact/locomotion policy, not recovered Dead Cells slope behavior or constants",
		"movement_profile": _resource_values(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _resource_values(load("res://combat_pc/resources/combat_profile.tres"))}
	FileAccess.open("res://combat_pc/tests/soft_slope_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  "))
	print("MOKSHA SOFT SLOPE %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _begin(label: String, at: Vector2, use_probe := false) -> void:
	_release_input()
	name_ = label; params = {}; frames = []; events = []; assertions = []; measurements = {}
	start_checks = checks; start_failures = failures.size(); ticks = 0; last_engine_tick = -1; engine_gaps = []; deltas = []
	terrain = null; terrain_points = []; boxes = []; before_tick = Callable(); input_frame = {}; instrumented = use_probe
	world = Node2D.new(); world.name = "Case"; root.add_child(world)
	actor = PLAYER.instantiate()
	if instrumented: actor.set_script(PROBE)
	actor.profile = actor.profile.duplicate(true); actor.combat_profile = actor.combat_profile.duplicate(true)
	actor.automatic_physics = false; actor.enable_hard_landing = false; actor.position = at
	world.add_child(actor)
	actor.movement_event.connect(func(label_: StringName, data: Dictionary): events.append({"event": String(label_), "tick": ticks, "data": _safe(data)}))
	driver = TickDriver.new(); driver.harness = self; driver.process_physics_priority = 20; world.add_child(driver)
	await _sync_geometry()
	actor.reset_actor(at, 1)

func _sync_geometry() -> void:
	for _i in 2:
		await physics_frame
		await process_frame

func _terrain(points: Array[Vector2], at := Vector2.ZERO, moving := false) -> PhysicsBody2D:
	var body: PhysicsBody2D = AnimatableBody2D.new() if moving else StaticBody2D.new()
	body.name = "Terrain"; body.position = at; body.collision_layer = 1; body.collision_mask = 0
	if moving: body.sync_to_physics = false
	var polygon := CollisionPolygon2D.new()
	var outline := PackedVector2Array(points)
	var bottom := -INF
	for point in points: bottom = maxf(bottom, point.y)
	outline.append(Vector2(points.back().x, bottom + 150))
	outline.append(Vector2(points.front().x, bottom + 150))
	polygon.polygon = outline; body.add_child(polygon); world.add_child(body)
	terrain = body; terrain_points = points.duplicate()
	return body

func _start(velocity := Vector2.ZERO) -> void:
	await _sync_geometry()
	actor.reset_actor(actor.global_position, 1)
	actor.velocity = velocity
	driver.enabled = true

func physics_sample(delta: float) -> void:
	if not is_instance_valid(actor): return
	ticks += 1
	var engine_tick := Engine.get_physics_frames()
	if last_engine_tick >= 0: engine_gaps.append(engine_tick - last_engine_tick)
	last_engine_tick = engine_tick; deltas.append(delta)
	if before_tick.is_valid(): before_tick.call(delta)
	var before := _sample()
	if instrumented: actor.probe_operations.clear()
	actor.physics_tick(delta, input_frame)
	var record := {"tick": ticks, "engine_tick": engine_tick, "delta": delta, "input": _safe(input_frame), "native_input": _sample_native_input() if input_frame == null else null, "before": before, "after": _sample()}
	if instrumented: record["operations"] = _safe(actor.probe_operations)
	frames.append(_safe(record))

func _sample_native_input() -> Dictionary:
	var result := {}
	for key in ["left", "right", "up", "down"]: result[key] = Input.get_action_strength("cp_" + key)
	for key in ["jump", "roll", "attack"]:
		result[key] = Input.is_action_pressed("cp_" + key)
		result[key + "_pressed"] = Input.is_action_just_pressed("cp_" + key)
		result[key + "_released"] = Input.is_action_just_released("cp_" + key)
	return result

func _sample() -> Dictionary:
	var shape_node = actor.get_node("BodyShape") as CollisionShape2D
	var rectangle = shape_node.shape as RectangleShape2D
	var shape_transform: Transform2D = actor.global_transform * shape_node.transform
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = rectangle; query.transform = shape_transform; query.collision_mask = actor.terrain_mask
	query.margin = 0; query.exclude = [actor.get_rid()]
	var hits: Array[Dictionary] = []
	for hit in actor.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider = hit.collider as CollisionObject2D
		hits.append({"name": String(collider.name), "shape": int(hit.shape), "one_way": collider.is_shape_owner_one_way_collision_enabled(collider.shape_find_owner(int(hit.shape)))})
	var clearance := INF
	if is_instance_valid(terrain):
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				clearance = minf(clearance, _clearance_at(shape_transform * Vector2(sx * rectangle.size.x * .5, sy * rectangle.size.y * .5)))
		var left: float = actor.global_position.x - rectangle.size.x * .5
		var right: float = actor.global_position.x + rectangle.size.x * .5
		for point in terrain_points:
			var world_point: Vector2 = terrain.global_transform * point
			if world_point.x >= left and world_point.x <= right: clearance = minf(clearance, _clearance_at(Vector2(world_point.x, actor.global_position.y)))
	var box_depth := 0.0
	var body_bounds := Rect2(actor.global_position - Vector2(rectangle.size.x * .5, rectangle.size.y), rectangle.size)
	for item in boxes:
		if not is_instance_valid(item.body) or item.one_way: continue
		var bounds := Rect2(item.body.global_position - item.size * .5, item.size)
		var overlap := body_bounds.intersection(bounds)
		if overlap.has_area(): box_depth = maxf(box_depth, minf(overlap.size.x, overlap.size.y))
	var state: Dictionary = actor.telemetry()
	return {"position": actor.global_position, "velocity": actor.velocity, "grounded": actor.grounded,
		"main_action": String(actor.main_action), "action_phase": String(actor.action_phase), "facing": actor.facing,
		"body_height": actor.body_height, "floor_normal": state.floor_normal, "support_id": state.support_id,
		"support_displacement": state.support_displacement, "fall_distance": state.fall_distance,
		"hard_land_active": state.hard_land_active, "air_jumps_left": actor.air_jumps_left,
		"air_roll_available": actor.air_roll_available, "dive_available": actor.dive_available,
		"terrain_clearance_normal": null if is_inf(clearance) else clearance, "solid_rectangle_overlap_depth": box_depth,
		"floor_relative_velocity": state.floor_relative_velocity, "weapon_phase": state.weapon_phase, "drop_exception_active": state.drop_exception_active, "exact_shape_hits": hits,
		"ceiling_contact": state.ceiling_contact, "wall_normal": state.wall_normal, "ground_follow_segments": state.get("ground_follow_segments", 0), "ground_follow_limited": state.get("ground_follow_limited", false)}

func _clearance_at(point: Vector2) -> float:
	if terrain_points.size() < 2 or not is_instance_valid(terrain): return INF
	var local: Vector2 = terrain.global_transform.affine_inverse() * point
	var answer := INF
	for index in range(terrain_points.size() - 1):
		var a: Vector2 = terrain_points[index]; var b: Vector2 = terrain_points[index + 1]
		if local.x < a.x - .0001 or local.x > b.x + .0001: continue
		var gradient := (b.y - a.y) / (b.x - a.x)
		var surface_y := a.y + (local.x - a.x) * gradient
		answer = minf(answer, (surface_y - local.y) / sqrt(1 + gradient * gradient))
	return answer

func _step(frame: Variant = {}, count := 1) -> void:
	input_frame = frame
	for _i in count:
		var target := ticks + 1
		while ticks < target:
			await physics_frame
			await process_frame

func _seconds(frame: Variant, seconds: float) -> void: await _step(frame, maxi(1, ceili(seconds / dt)))
func _until(predicate: Callable, frame: Variant = {}, seconds := 3.0) -> bool:
	for _i in range(ceili(seconds / dt)):
		if bool(predicate.call()): return true
		await _step(frame)
	return bool(predicate.call())
func _count(label: String) -> int: return events.filter(func(event): return event.event == label).size()
func _check(condition: bool, label: String) -> void:
	checks += 1; assertions.append({"passed": condition, "label": label})
	if not condition: failures.append(name_ + ": " + label); printerr("FAIL: " + failures.back())
func _near(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(actual - expected) <= tolerance, "%s actual %.6f expected %.6f ± %.6f" % [label, actual, expected, tolerance])
func _direction(direction: int, extra: Dictionary = {}) -> Dictionary:
	return ({"right": 1.0} if direction > 0 else ({"left": 1.0} if direction < 0 else {})).merged(extra)
func _resource_values(resource: Resource) -> Dictionary:
	var output := {}
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: output[property.name] = _safe(resource.get(property.name))
	return output
func _safe(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Array:
		var output := []
		for item in value: output.append(_safe(item))
		return output
	if value is Dictionary:
		var output := {}
		for key in value: output[str(key)] = _safe(value[key])
		return output
	return value
func _release_input() -> void:
	for code in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE, KEY_C, KEY_J, KEY_SHIFT]:
		var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = false; Input.parse_input_event(event)
	for action in ["cp_left", "cp_right", "cp_up", "cp_down", "cp_jump", "cp_roll", "cp_attack"]:
		if InputMap.has_action(action): Input.action_release(action)
func _finish() -> void:
	if not engine_gaps.all(func(gap): return gap == 1): _check(false, "every observation must be one consecutive real physics callback")
	measurements["physics_samples"] = frames.size(); measurements["engine_gaps"] = engine_gaps; measurements["callback_deltas"] = deltas
	scenarios.append({"name": name_, "params": params, "checks": checks - start_checks, "failures": failures.size() - start_failures,
		"frames": frames, "events": events, "assertions": assertions, "measurements": measurements})
	driver.enabled = false; _release_input(); world.queue_free()
	await physics_frame; await process_frame
	world = null; actor = null; driver = null; terrain = null


func _plane_case(label: String, gradient: float, initial_x: float, initial_y: float, intent: int, gap: float, duration := .8, use_probe := false) -> Dictionary:
	var p = load("res://combat_pc/resources/movement_profile.tres")
	await _begin(label, Vector2(0, -absf(gradient) * p.body_width * .5 - gap), use_probe)
	_terrain([Vector2(-1200, -1200 * gradient), Vector2(1200, 1200 * gradient)])
	params = {"gradient": gradient, "initial_vx": initial_x, "initial_vy": initial_y, "input_x": intent, "gap": gap, "post_contact_seconds": duration, "instrumented": use_probe}
	await _start(Vector2(initial_x, initial_y))
	await _until(func(): return _count("landed") > 0, _direction(intent), 3)
	var contact_tick := -1
	for event in events:
		if event.event == "landed": contact_tick = int(event.tick); break
	_check(contact_tick > 0 and not actor.enable_hard_landing, "ordinary stock motion reaches a real soft-floor contact with the optional hard trigger disabled")
	if contact_tick < 0:
		await _finish()
		return {}
	await _until(func(): return ticks >= contact_tick + roundi(duration * hz), _direction(intent), duration + .1)
	var contact: Dictionary = _at_tick(contact_tick).after
	var support_losses := 0
	var minimum_clearance := INF
	var maximum_speed := 0.0
	var maximum_gain := 0.0
	var maximum_displacement_excess := 0.0
	var settled := -1.0
	for frame in frames:
		var before: Dictionary = frame.before; var after: Dictionary = frame.after
		maximum_speed = maxf(maximum_speed, absf(float(after.velocity[0])))
		if intent == 0: maximum_gain = maxf(maximum_gain, absf(float(after.velocity[0])) - absf(float(before.velocity[0])))
		var allowed_speed: float = absf(float(before.velocity[0])) if intent == 0 else actor.profile.run_speed
		maximum_displacement_excess = maxf(maximum_displacement_excess, absf(float(after.position[0]) - float(before.position[0])) - allowed_speed * float(frame.delta))
		if after.terrain_clearance_normal != null: minimum_clearance = minf(minimum_clearance, float(after.terrain_clearance_normal))
		if int(frame.tick) >= contact_tick:
			if not bool(after.grounded): support_losses += 1
			if settled < 0 and absf(float(after.velocity[0])) <= .02: settled = (int(frame.tick) - contact_tick) * dt
	measurements["entry_vx"] = float(contact.velocity[0])
	measurements["support_loss_ticks"] = support_losses
	measurements["min_normal_clearance"] = minimum_clearance
	measurements["max_horizontal_speed"] = maximum_speed
	measurements["max_neutral_speed_gain"] = maximum_gain
	measurements["max_horizontal_step_excess"] = maximum_displacement_excess
	measurements["settle_seconds"] = settled
	for time_ in [.05, .10, .20, .40, .80, 1.0, 2.0]:
		if time_ > duration + .000001: continue
		var sample: Dictionary = _at_tick(contact_tick + roundi(time_ * hz)).after
		measurements["travel_x_%.2f" % time_] = float(sample.position[0]) - float(contact.position[0])
		measurements["velocity_x_%.2f" % time_] = float(sample.velocity[0])
	_check(maximum_speed <= actor.profile.run_speed + .02, "vertical floor impact cannot manufacture horizontal momentum beyond the supplied run-speed bound")
	_check(maximum_displacement_excess <= actor.profile.collision_margin * 2 + .001, "each actual X displacement respects its horizontal travel budget independently of final velocity")
	_check(support_losses == 0 and _count("landed") == 1, "continuous plane retains genuine support and emits one landing throughout the post-contact interval")
	_check(minimum_clearance >= -actor.profile.collision_margin - .001, "independent exact-body plane clearance stays within the existing collision skin")
	if intent == 0:
		_check(maximum_gain <= .02, "neutral contact never converts falling motion into new horizontal speed")
		_check(settled >= 0 and settled <= absf(float(contact.velocity[0])) / actor.profile.ground_braking + 2 * dt, "neutral residual motion stops within the authored ground-braking interval")
	else:
		_near(actor.velocity.x, intent * actor.profile.run_speed, .02, "held uphill or downhill intent reaches the same authored horizontal run speed")
		var early: Dictionary = _at_tick(contact_tick + roundi(.4 * hz)).after
		var late: Dictionary = _at_tick(contact_tick + roundi(.8 * hz)).after
		_near(float(late.position[0]) - float(early.position[0]), intent * actor.profile.run_speed * .4, .05, "steady supported root travel preserves horizontal speed over time")
	var signature := {"frames": [], "events": []}
	for frame in frames:
		var before: Dictionary = frame.before.duplicate(true); var after: Dictionary = frame.after.duplicate(true)
		before.erase("support_id"); after.erase("support_id")
		signature.frames.append({"tick": frame.tick, "before": before, "after": after})
	for event in events:
		var copy: Dictionary = event.duplicate(true)
		copy.data.erase("surface_id")
		signature.events.append(copy)
	await _finish()
	return signature

func _at_tick(value: int) -> Dictionary:
	for frame in frames:
		if int(frame.tick) == value: return frame
	return {}

func _slope_matrix() -> void:
	var p = load("res://combat_pc/resources/movement_profile.tres")
	for magnitude in [1.0, .5]:
		for mirror in [-1, 1]:
			for vx_factor in [-1, 0, 1]:
				for vy in [300.0, float(p.terminal_fall_speed)]:
					for intent in [-1, 0, 1]:
						var label = "plane %.1f mirror%d vx%d vy%.0f input%d" % [magnitude, mirror, vx_factor, vy, intent]
						await _plane_case(label, magnitude * mirror, p.run_speed * vx_factor * mirror, vy, intent * mirror, 40)

func _neutral_phase_and_probe_equivalence() -> void:
	var p = load("res://combat_pc/resources/movement_profile.tres")
	for mirror in [-1, 1]:
		for gap in [38.0, 40.0]:
			var label := "zero-X phase mirror%d gap%.0f" % [mirror, gap]
			var stock: Dictionary = await _plane_case(label + " stock", float(mirror), 0, p.terminal_fall_speed, 0, gap, 2.0)
			var observed: Dictionary = await _plane_case(label + " instrumented", float(mirror), 0, p.terminal_fall_speed, 0, gap, 2.0, true)
			# The next assertion belongs to the instrumented scenario already saved.
			var identical := stock == observed
			checks += 1
			scenarios.back().checks += 1
			scenarios.back().assertions.append({"passed": identical, "label": "observational sweep/probe subclass matches unmodified stock actor exactly"})
			if not identical:
				failures.append(label + ": instrumented observer changed the stock result")
				scenarios.back().failures += 1
	for magnitude in [1.0, .5]:
		for mirror in [-1, 1]:
			await _plane_case("long neutral %.1f mirror%d" % [magnitude, mirror], magnitude * mirror, p.run_speed * mirror, p.terminal_fall_speed, 0, 40, 2.0)

	for mirror in [-1, 1]:
		for intent in [-1, 1]:
			var label := "held observer mirror%d input%d" % [mirror, intent]
			var stock: Dictionary = await _plane_case(label + " stock", float(mirror), p.run_speed * mirror, 300, intent * mirror, 40)
			var observed: Dictionary = await _plane_case(label + " instrumented", float(mirror), p.run_speed * mirror, 300, intent * mirror, 40, .8, true)
			var identical := stock == observed
			checks += 1; scenarios.back().checks += 1
			scenarios.back().assertions.append({"passed": identical, "label": "held-motion observer preserves every stock before/after sample and event"})
			if not identical:
				failures.append(label + ": instrumented observer changed stock result"); scenarios.back().failures += 1

func _box(center: Vector2, size: Vector2, one_way := false, moving := false) -> PhysicsBody2D:
	var body: PhysicsBody2D = AnimatableBody2D.new() if moving else StaticBody2D.new()
	body.name = "Box%d" % boxes.size(); body.position = center; body.collision_layer = 1; body.collision_mask = 0
	if moving: body.sync_to_physics = false
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = size
	collision.shape = shape; collision.one_way_collision = one_way; body.add_child(collision); world.add_child(body)
	boxes.append({"body": body, "size": size, "one_way": one_way})
	return body

func _trace_bounds(from_tick := 0, supported := false) -> Dictionary:
	var minimum := INF; var depth := 0.0; var losses := 0; var work := 0
	for frame in frames:
		if int(frame.tick) < from_tick: continue
		var sample: Dictionary = frame.after
		if sample.terrain_clearance_normal != null: minimum = minf(minimum, float(sample.terrain_clearance_normal))
		depth = maxf(depth, float(sample.solid_rectangle_overlap_depth))
		if not sample.grounded: losses += 1
		work = maxi(work, int(sample.ground_follow_segments))
	_check(minimum >= -actor.profile.collision_margin - .001 and depth <= actor.profile.collision_margin + .001, "independent full-body terrain and rectangle clearance stays within the unchanged collision skin")
	_check(work <= 32, "supported segmentation stays within its finite per-callback work budget")
	if supported: _check(losses == 0, "continuous supported travel has no airborne sample")
	return {"minimum_clearance": null if is_inf(minimum) else minimum, "maximum_rectangle_depth": depth, "support_losses": losses, "maximum_segments": work}

func _continuous_joins() -> void:
	for shape in ["hill", "valley"]:
		for magnitude in [.5, 1.0]:
			for direction in [-1, 1]:
				await _begin("continuous %s %.1f direction%d" % [shape, magnitude, direction], Vector2(-230 * direction, 298))
				var rise: float = 100 * magnitude * (-1 if shape == "hill" else 1)
				_terrain([Vector2(-500, 0), Vector2(-100, 0), Vector2(0, rise), Vector2(100, 0), Vector2(500, 0)], Vector2(0, 300))
				params = {"continuous_polygon": shape, "gradient_magnitude": magnitude, "direction": direction}
				await _start(); await _until(func(): return actor.grounded)
				var contact_tick := ticks; var initial_landings := _count("landed")
				await _until(func(): return actor.position.x * direction > 225, _direction(direction), 3)
				_check(actor.position.x * direction > 225 and _count("landed") == initial_landings, "one physical landing connects flat incline crest or valley and opposite flat without extra floor dispatch")
				_near(actor.velocity.x, direction * actor.profile.run_speed, .02, "far flat retains intended horizontal speed after every join")
				measurements.merge(_trace_bounds(contact_tick, true))
				measurements["crossing_seconds"] = (ticks - contact_tick) * dt
				await _finish()
	for direction in [-1, 1]:
		await _begin("separate slope flat seam direction%d" % direction, Vector2(-100 * direction, 190))
		if direction == 1:
			_terrain([Vector2(-500, -500), Vector2(0, 0)], Vector2(0, 300))
			_box(Vector2(250, 330), Vector2(500, 60))
		else:
			_terrain([Vector2(0, 0), Vector2(500, -500)], Vector2(0, 300))
			_box(Vector2(-250, 330), Vector2(500, 60))
		await _start(); await _until(func(): return actor.grounded)
		var contact_tick := ticks; var initial_support: int = actor.telemetry().support_id; var initial_landings := _count("landed")
		await _until(func(): return actor.position.x * direction > 100, _direction(direction), 2)
		_check(actor.grounded and actor.telemetry().support_id != initial_support and _count("landed") == initial_landings, "coplanar body seam changes physical support without manufacturing a landing")
		measurements.merge(_trace_bounds(contact_tick, true)); await _finish()

func _discontinuous_edges() -> void:
	for slope in [false, true]:
		for direction in [-1, 1]:
			await _begin("discontinuous %s edge direction%d" % ["slope" if slope else "flat", direction], Vector2(-70 * direction, 300 - (80 if slope else 2)))
			if direction == 1:
				_terrain([Vector2(-500, -500 if slope else 0), Vector2(0, 0)], Vector2(0, 300))
			else:
				_terrain([Vector2(0, 0), Vector2(500, -500 if slope else 0)], Vector2(0, 300))
			_box(Vector2(240 * direction, 338), Vector2(400, 60))
			await _start(); await _until(func(): return actor.grounded)
			var initial_landings := _count("landed")
			await _until(func(): return actor.position.x * direction > 85, _direction(direction), 2)
			var gap_samples := 0; var false_support := 0
			for frame in frames:
				var x: float = float(frame.after.position[0]) * direction
				if x > actor.profile.body_width * .5 + .1 and x < 40 - actor.profile.body_width * .5 - .1:
					gap_samples += 1
					if frame.after.grounded: false_support += 1
			_check(gap_samples > 0 and false_support == 0, "genuine unsupported gap becomes airborne instead of extending slope following to a disconnected lower floor")
			_check(actor.grounded and _count("landed") == initial_landings + 1, "separate lower support receives exactly one new physical landing")
			measurements["gap_airborne_samples"] = gap_samples; measurements.merge(_trace_bounds()); await _finish()
	for direction in [-1, 1]:
		await _begin("slope jump departure direction%d" % direction, Vector2(0, 290))
		_terrain([Vector2(-500, -500 * direction), Vector2(500, 500 * direction)], Vector2(0, 300))
		await _start(); await _until(func(): return actor.grounded)
		await _seconds(_direction(direction), .15)
		var departure: Vector2 = actor.position
		await _step(_direction(direction, {"jump": true}))
		_check(not actor.grounded and actor.velocity.y < 0 and _count("ground_jump") == 1, "fresh slope jump departs real support once")
		await _seconds(_direction(direction, {"jump": true}), .08)
		_check(not actor.grounded and actor.position.y < departure.y - 15, "supported following remains disabled over multiple upward jump callbacks")
		measurements.merge(_trace_bounds()); await _finish()

func _component_blocking() -> void:
	for direction in [-1, 1]:
		for gap in [4.0, 38.0]:
			await _begin("floor wall component ordering direction%d gap%.0f" % [direction, gap], Vector2(49 * direction, 341 - gap), true)
			_terrain([Vector2(-500, -500 * direction), Vector2(500, 500 * direction)], Vector2(0, 300))
			_box(Vector2(62 * direction, 270), Vector2(4, 240))
			await _start(Vector2(actor.profile.run_speed * direction, 300))
			await _seconds(_direction(direction), .4)
			_check(actor.position.x * direction <= 52.021 and absf(actor.velocity.x) <= .02, "real thin-wall blocking retires horizontal motion before and after floor contact")
			_check(actor.grounded and _count("landed") == 1, "blocked floor corner remains supported without repeated landing")
			measurements.merge(_trace_bounds()); await _finish()
		await _begin("uphill low ceiling direction%d" % direction, Vector2(0, 290))
		_terrain([Vector2(-500, 500 * direction), Vector2(500, -500 * direction)], Vector2(0, 300))
		await _start(); await _until(func(): return actor.grounded)
		_box(Vector2(0, actor.position.y - actor.body_height - 18), Vector2(300, 12))
		await _sync_geometry(); var before: Vector2 = actor.position
		await _seconds(_direction(direction), .5)
		_check((actor.position.x - before.x) * direction < 20 and actor.grounded, "uphill tangent sweep stops under actual ceiling instead of tunneling or losing support")
		measurements.merge(_trace_bounds()); await _finish()
		await _begin("ceiling stops Y preserves X direction%d" % direction, Vector2(0, 298))
		_terrain([Vector2(-500, 0), Vector2(500, 0)], Vector2(0, 300))
		_box(Vector2(0, 240), Vector2(500, 12))
		await _start(); await _until(func(): return actor.grounded)
		await _step(_direction(direction, {"jump": true})); await _seconds(_direction(direction, {"jump": true}), .06)
		var observed := false
		for frame in frames:
			if frame.after.ceiling_contact and float(frame.after.velocity[0]) * direction > 0: observed = true
		_check(observed, "ceiling collision removes blocked upward component while permitted horizontal motion survives")
		measurements.merge(_trace_bounds()); await _finish()
		await _begin("sidewall preserves upward jump direction%d" % direction, Vector2(0, 298))
		_terrain([Vector2(-500, 0), Vector2(500, 0)], Vector2(0, 300))
		_box(Vector2(22 * direction, 180), Vector2(4, 300))
		await _start(); await _until(func(): return actor.grounded)
		await _step(_direction(direction, {"jump": true})); await _seconds(_direction(direction, {"jump": true}), .15)
		_check(actor.position.x * direction <= 12.021 and actor.position.y < 260 and actor.velocity.y < 0, "sidewall suppresses X without swallowing upward departure")
		measurements.merge(_trace_bounds()); await _finish()

func _action_and_carrier_flows() -> void:
	for direction in [-1, 1]:
		await _begin("slope reverse brake and parsed jump direction%d" % direction, Vector2(0, 290))
		_terrain([Vector2(-800, -800 * direction), Vector2(800, 800 * direction)], Vector2(0, 300))
		await _start(); await _until(func(): return actor.grounded)
		await _seconds(_direction(direction), .2)
		await _step(_direction(-direction))
		_check(actor.facing == -direction and actor.velocity.x * direction > 0, "permitted facing reverses immediately while physical slope momentum still brakes")
		await _seconds(_direction(-direction), .2)
		_near(actor.velocity.x, -direction * actor.profile.run_speed, .02, "reverse slope movement reaches authored speed")
		await _seconds({}, actor.profile.run_speed / actor.profile.ground_braking + 2 * dt)
		_near(actor.velocity.x, 0, .02, "neutral slope input reaches a short finite stop")
		var event := InputEventKey.new(); event.physical_keycode = KEY_SPACE; event.pressed = true; Input.parse_input_event(event)
		await _step(null)
		event = InputEventKey.new(); event.physical_keycode = KEY_SPACE; event.pressed = false; Input.parse_input_event(event)
		await _step(null); await _seconds(null, .06)
		_check(_count("ground_jump") == 1 and actor.velocity.y >= -actor.profile.jump_release_rise_cap - .02 and not actor.grounded, "parsed native tap across real slope callbacks jumps once and retains release cut")
		measurements.merge(_trace_bounds()); await _finish()
		for action in ["roll", "melee", "hurt", "hard"]:
			await _begin("shared slope movement %s direction%d" % [action, direction], Vector2(0, 290))
			_terrain([Vector2(-1000, -1000 * direction), Vector2(1000, 1000 * direction)], Vector2(0, 300))
			await _start(); await _until(func(): return actor.grounded)
			await _seconds(_direction(direction), .15)
			var start_tick := ticks
			if action == "roll": await _step(_direction(direction, {"roll": true}))
			elif action == "melee": await _step(_direction(direction, {"attack": true}))
			elif action == "hurt": actor.receive_hit({"impulse": Vector2(218 * direction, 0), "hitpause": 0.0, "stun_seconds": .2})
			else:
				actor.enable_hard_landing = true
				actor.reset_actor(actor.position - Vector2(0, 350), direction)
				await _until(func(): return actor.telemetry().hard_land_active, _direction(direction), 2)
				start_tick = ticks
			await _seconds(_direction(direction), .5)
			var expected := "roll_started" if action == "roll" else ("attack_started" if action == "melee" else ("hurt_started" if action == "hurt" else "hard_land_started"))
			# These events are inspected alongside the actual owner/phase samples.
			var action_seen := false
			for frame in frames:
				if (action == "melee" and frame.after.weapon_phase != "idle") or frame.after.main_action == ("hard_land" if action == "hard" else action): action_seen = true
			_check(action_seen and actor.grounded, "real action entry resolves back to supported ordinary movement on the same incline")
			if action == "hard": _check(_count("hard_land_finished") == 1 and _count("hard_land_cancelled") == 0, "shared solver preserves full hard recovery")
			var completed := expected.replace("_started", "_finished")
			_check(_count(expected) == 1 and _count(completed) == 1, "connected action starts and completes exactly once on the incline")
			var start_event := events.filter(func(item): return item.event == expected)
			var end_event := events.filter(func(item): return item.event == completed)
			if not start_event.is_empty() and not end_event.is_empty(): measurements["action_duration_seconds"] = (int(end_event[0].tick) - int(start_event[0].tick)) * dt
			measurements.merge(_trace_bounds(start_tick, action != "hurt")); await _finish()
		await _begin("moving slope pause transport direction%d" % direction, Vector2(0, 290))
		var carrier := _terrain([Vector2(-500, -500 * direction), Vector2(500, 500 * direction)], Vector2(0, 300), true)
		await _start(); await _until(func(): return actor.grounded)
		var local_before: Vector2 = actor.position - carrier.position
		before_tick = func(delta): carrier.position += Vector2(30 * direction, -20) * delta
		actor.apply_hitpause(.2); await _seconds({}, .15)
		_near((actor.position - carrier.position).distance_to(local_before), 0, .05, "paused support transport follows actual moving slope without adding ordinary travel")
		_check(actor.grounded, "moving supported pause retains floor authority")
		before_tick = Callable(); await _seconds(_direction(direction), .3)
		_check(actor.grounded and actor.velocity.x * direction > 0, "post-pause input resumes supported movement")
		measurements.merge(_trace_bounds()); await _finish()
	await _begin("one-way jump and targeted drop after slope approach", Vector2(-100, 190))
	_terrain([Vector2(-500, -500), Vector2(0, 0)], Vector2(0, 300))
	var upper := _box(Vector2(150, 304), Vector2(300, 8), true)
	var lower := _box(Vector2(150, 364), Vector2(300, 8), true)
	await _start(); await _until(func(): return actor.grounded)
	await _until(func(): return actor.position.x > 70, {"right": 1.0}, 2)
	_check(actor.grounded and actor.telemetry().support_id == upper.get_instance_id(), "slope approach reaches the separate dedicated one-way top")
	await _seconds({}, .2); await _step({"down": 1.0, "jump": true}); await _step()
	_check(actor.get_collision_exceptions() == [upper], "fresh down chord targets only the physical one-way support after slope travel")
	await _until(func(): return actor.grounded and actor.telemetry().support_id == lower.get_instance_id(), {}, 1)
	_check(actor.grounded and actor.telemetry().support_id == lower.get_instance_id() and actor.get_collision_exceptions().is_empty(), "lower separate one-way remains collidable and cleanup is retired after full clearance")
	measurements.merge(_trace_bounds()); await _finish()

func _actual_lab_course() -> void:
	for native_position in [false, true]:
		for direction in [-1, 1]:
			var origin := Vector2(2460, 270) if native_position else Vector2(0, 300)
			var start_x := (40 if direction == 1 else 810) if native_position else (30 if direction == 1 else 810)
			await _begin("actual lab slope course direction%d%s" % [direction, " native origin" if native_position else ""], origin + Vector2(start_x, 0 if native_position else -2))
			var course = load("res://combat_pc/fixtures/slope_course.tscn").instantiate()
			course.position = origin; world.add_child(course)
			terrain = course
			for point in course.get_node("Shape").polygon:
				if terrain_points.size() >= 10: break
				terrain_points.append(point)
			await _start(); await _until(func(): return actor.grounded)
			var start_tick := ticks; var landings := _count("landed")
			var target_x := origin.x + (805 if direction == 1 else 35)
			await _until(func(): return (actor.position.x - target_x) * direction >= 0, _direction(direction), 4.5)
			_check((actor.position.x - target_x) * direction >= 0, "real native-lab concave polygon crosses all four incline directions and its flat crest joins under held input")
			_check(_count("landed") == landings, "continuous native course emits no false extra landings")
			measurements.merge(_trace_bounds(start_tick, true)); measurements["crossing_seconds"] = (ticks - start_tick) * dt
			await _finish()

func _lifecycle_and_bounded_safety() -> void:
	for direction in [-1, 1]:
		await _begin("supported huge host speed meets thin wall direction%d" % direction, Vector2(0, 290))
		_terrain([Vector2(-600, -600 * direction), Vector2(600, 600 * direction)], Vector2(0, 300))
		_box(Vector2(72 * direction, 300), Vector2(4, 300))
		await _start(); await _until(func(): return actor.grounded)
		actor.begin_main_action(&"bounded_host", {"can_wall_grab": false}, func(player, _delta, _frame): player.velocity = Vector2(5000 * direction, 0); return true)
		await _step()
		_check(actor.position.x * direction <= 62.021 and actor.position.x * direction >= 0, "bounded support work falls back to a real sweep and cannot cross a thin wall")
		_check(actor.telemetry().ground_follow_limited and int(actor.telemetry().ground_follow_segments) <= 32, "oversized host motion explicitly reaches the finite work limit")
		measurements.merge(_trace_bounds()); await _finish()
		await _begin("paused slope parsed tap and reset direction%d" % direction, Vector2(0, 290))
		_terrain([Vector2(-500, -500 * direction), Vector2(500, 500 * direction)], Vector2(0, 300))
		await _start(); await _until(func(): return actor.grounded)
		var identity: int = actor.get_instance_id(); var paused_at: Vector2 = actor.position
		actor.apply_hitpause(.12)
		var key := InputEventKey.new(); key.physical_keycode = KEY_SPACE; key.pressed = true; Input.parse_input_event(key)
		await _step(null)
		key = InputEventKey.new(); key.physical_keycode = KEY_SPACE; key.pressed = false; Input.parse_input_event(key)
		await _seconds(null, .04)
		_near(actor.position.distance_to(paused_at), 0, .0001, "stationary actor-local pause cannot advance tangent locomotion or ground following")
		await _until(func(): return _count("ground_jump") == 1, null, .3); await _seconds(null, .05)
		_check(not actor.grounded and actor.velocity.y >= -actor.profile.jump_release_rise_cap - .02 and _count("ground_jump") == 1, "paused parsed tap resumes exactly once with release history and no upward snap")
		actor.reset_actor(Vector2(0, 150), direction); await _step()
		_check(actor.get_instance_id() == identity and not actor.grounded and actor.telemetry().ground_follow_segments == 0 and actor.hitpause_remaining == 0, "same actor reset discards old support and paused intent before airborne movement")
		await _until(func(): return actor.grounded, {}, 2)
		_check(actor.grounded and _count("ground_jump") == 1, "same instance can physically land again without a replayed tap")
		measurements.merge(_trace_bounds()); await _finish()
		await _begin("removed slope during paused support direction%d" % direction, Vector2(0, 290))
		var floor := _terrain([Vector2(-500, -500 * direction), Vector2(500, 500 * direction)], Vector2(0, 300))
		await _start(); await _until(func(): return actor.grounded)
		actor.apply_hitpause(.06); floor.queue_free(); await _seconds({}, .12)
		_check(not actor.grounded and actor.velocity.y > 0 and actor.telemetry().support_id == 0, "removed sloped support cannot survive resume as a cached plane")
		measurements.merge(_trace_bounds()); await _finish()
		await _begin("explicit upward host departure direction%d" % direction, Vector2(0, 290))
		_terrain([Vector2(-500, -500 * direction), Vector2(500, 500 * direction)], Vector2(0, 300))
		await _start(); await _until(func(): return actor.grounded)
		var initial_y: float = actor.position.y
		actor.begin_main_action(&"upward_host", {"can_wall_grab": false}, func(player, _delta, _frame): player.velocity = Vector2(100 * direction, -300); return true)
		await _seconds({}, .1)
		_check(not actor.grounded and actor.position.y < initial_y - 20 and actor.telemetry().ground_follow_segments == 0, "new explicit upward motion is not mistaken for old supported slope travel")
		measurements.merge(_trace_bounds()); await _finish()
	await _begin("ceiling callback replacement keeps upward owner", Vector2(0, 298))
	_terrain([Vector2(-500, 0), Vector2(500, 0)], Vector2(0, 300))
	var roof := _box(Vector2(0, 240), Vector2(500, 12))
	await _start(); await _until(func(): return actor.grounded)
	var callback_state := {"called": false, "roof": roof}
	actor.movement_event.connect(func(label, _data):
		if label == &"ceiling_contact" and not callback_state.called:
			callback_state.called = true
			actor.receive_hit({"impulse": Vector2(90, -220), "hitpause": .1, "stun_seconds": .2})
			callback_state.roof.queue_free()
			callback_state.roof = null)
	await _until(func(): return callback_state.called, {"jump": true}, .3)
	_check(callback_state.called and actor.main_action == &"hurt" and not actor.grounded and actor.velocity.y < 0, "synchronous ceiling callback's newer upward hurt owner survives old collision work")
	var paused_position: Vector2 = actor.position
	await _seconds({}, .04)
	_near(actor.position.distance_to(paused_position), 0, .0001, "new pause freezes callbacks after the already-admitted replacement step")
	measurements.merge(_trace_bounds()); await _finish()

func _grounded_callback_replacement() -> void:
	for direction in [-1, 1]:
		await _begin("grounded uphill ceiling replacement direction%d" % direction, Vector2(0, 290))
		_terrain([Vector2(-500, 500 * direction), Vector2(500, -500 * direction)], Vector2(0, 300))
		await _start(); await _until(func(): return actor.grounded)
		var roof := _box(Vector2(0, actor.position.y - actor.body_height - 18), Vector2(300, 12))
		await _sync_geometry()
		var callback_state := {"called": false, "roof": roof}
		actor.movement_event.connect(func(label, _data):
			if label == &"ceiling_contact" and not callback_state.called:
				callback_state.called = true
				actor.receive_hit({"impulse": Vector2(-90 * direction, -220), "hitpause": .1, "stun_seconds": .2})
				callback_state.roof.queue_free()
				callback_state.roof = null)
		await _until(func(): return callback_state.called, _direction(direction), .5)
		_check(callback_state.called and actor.main_action == &"hurt" and not actor.grounded and actor.velocity.y < 0, "new upward hurt owner invalidates prior slope support within the same grounded ceiling sweep")
		var position_after_callback: Vector2 = actor.position
		var velocity_after_callback: Vector2 = actor.velocity
		await _seconds({}, .04)
		_near(actor.position.distance_to(position_after_callback), 0, .0001, "replacement hitpause freezes subsequent callbacks without restoring the old supporting plane")
		_near(actor.velocity.distance_to(velocity_after_callback), 0, .0001, "replacement upward impulse survives its local paused interval")
		await _seconds({}, .12)
		_check(actor.position.y < position_after_callback.y - 5 and not actor.grounded, "accepted upward replacement survives multiple resumed callbacks instead of being regrounded by stale floor evidence")
		measurements.merge(_trace_bounds()); await _finish()
