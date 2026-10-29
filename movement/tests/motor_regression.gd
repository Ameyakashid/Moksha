extends SceneTree
## Isolated, actual-physics regressions for the shared movement motor.
## Run: godot --headless --path . --fixed-fps 120 --script res://movement/tests/motor_regression.gd
## Each scene instance gets its own tuning copy. No production resource is changed.

const PLAYER := preload("res://movement/actors/player.tscn")
const DT := 1.0 / 120.0
const FLOOR_Y := 300.0

class PhysicsHarness:
	extends Node
	signal stepped
	var motor: MokshaMovementMotor
	func _physics_process(delta: float) -> void:
		if is_instance_valid(motor):
			motor.step_motor(delta)
		stepped.emit()

var harness: PhysicsHarness
var fixture: Node2D
var motor: MokshaMovementMotor
var failures: Array[String] = []
var checks := 0
var jumps: Array[bool] = []
var dashes: Array[int] = []
var landing_speeds: Array[float] = []

func _initialize() -> void:
	Engine.physics_ticks_per_second = 120
	_run.call_deferred()

func _run() -> void:
	harness = PhysicsHarness.new()
	root.add_child(harness)
	await _test_ground_response()
	await _test_instant_response()
	await _test_input_adapter()
	await _test_variable_jump()
	await _test_release_and_apex_rules()
	await _test_ineligible_apex()
	await _test_coyote_and_walkoff()
	await _test_landing_buffer()
	await _test_double_jump()
	await _test_air_reversal()
	await _test_dash_latch()
	await _test_air_dash_budget()
	await _test_dash_jump_cancel()
	await _test_swept_collisions()
	await _test_one_way_platform()
	await _test_modes_and_reset()
	await _test_slopes_and_snap()
	await _test_pause_buffers()
	await _test_knockback()
	_dispose_fixture()
	print("MOTOR REGRESSION: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("  FAILED: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String, detail: String = "") -> void:
	checks += 1
	if not condition:
		var message := label + (" | " + detail if not detail.is_empty() else "")
		failures.append(message)
		printerr("FAIL: " + message)

func _ticks(count: int = 1) -> void:
	for _index in count:
		await harness.stepped

func _dispose_fixture() -> void:
	harness.motor = null
	motor = null
	if is_instance_valid(fixture):
		fixture.free()
	fixture = null

func _start_fixture(start: Vector2, floor_kind: String = "flat", settle: bool = true) -> void:
	_dispose_fixture()
	jumps.clear()
	dashes.clear()
	landing_speeds.clear()
	fixture = Node2D.new()
	root.add_child(fixture)
	if floor_kind == "flat":
		_box(Vector2(0, FLOOR_Y + 30), Vector2(2400, 60))
	elif floor_kind == "ledge":
		_box(Vector2(-160, FLOOR_Y + 30), Vector2(320, 60))
	elif floor_kind == "slope":
		_polygon(PackedVector2Array([
			Vector2(-500, 260), Vector2(-160, 260), Vector2(160, 420),
			Vector2(500, 420), Vector2(500, 600), Vector2(-500, 600)]))
	motor = PLAYER.instantiate()
	motor.tuning = motor.tuning.duplicate(true)
	motor.position = start
	fixture.add_child(motor)
	motor.set_physics_process(false)
	var driver := motor.get_node("Intent")
	driver.active = false
	driver.set_physics_process(false)
	driver.set_process_unhandled_input(false)
	motor.jumped.connect(func(air_jump: bool): jumps.append(air_jump))
	motor.dash_started.connect(func(direction: int): dashes.append(direction))
	motor.landed.connect(func(speed: float): landing_speeds.append(speed))
	harness.motor = motor
	await _ticks(40 if settle else 2)
	if settle:
		_check(motor.is_on_floor(), "fixture settles on real floor", str(start))

func _box(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	fixture.add_child(body)
	return body

func _polygon(points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	fixture.add_child(body)

func _test_ground_response() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.tuning.instant_ground_response = false
	motor.tuning.instant_air_steering = false
	var initial_x := motor.position.x
	motor.set_intent(1)
	await _ticks()
	_check(motor.velocity.x > 0 and motor.velocity.x < motor.tuning.run_speed, "run accelerates rather than teleports to speed")
	await _ticks(12)
	_check(absf(motor.velocity.x - motor.tuning.run_speed) < 0.01, "ground reaches run speed")
	_check(motor.position.x > initial_x + 15, "run moves actual body")
	motor.set_intent(-1)
	_check(motor.facing == -1 and motor.velocity.x > 0, "facing reverses immediately before velocity reverses")
	var body_drawing := motor.get_node("Wireframe")
	_check(body_drawing.motor == motor and body_drawing.scale.x > 0 and motor.scale.x > 0, "wireframe uses authoritative motor without inverse parent scale")
	await _ticks()
	_check(motor.velocity.x > 0 and motor.velocity.x < motor.tuning.run_speed, "reversal brakes existing momentum")
	await _ticks(8)
	_check(motor.velocity.x < -175, "ground reversal reaches substantial leftward travel within 75 ms")
	await _ticks(4)
	_check(absf(motor.velocity.x + motor.tuning.run_speed) < 0.01, "ground reversal reaches full opposite speed within 110 ms")
	motor.set_intent(0)
	await _ticks(8)
	_check(absf(motor.velocity.x) < 0.01 and motor.state == &"IDLE", "release brakes to idle")
	_check(motor.facing == -1, "release preserves last facing")
	print("CHECKED: ground acceleration, braking, reversal, facing")

func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _test_input_adapter() -> void:
	await _start_fixture(Vector2(0, 280))
	var driver := motor.get_node("Intent")
	driver.active = true
	driver.set_physics_process(true)
	driver.set_process_unhandled_input(true)
	_action(&"right", true)
	await _ticks(10)
	_check(motor.axis == 1 and motor.facing == 1 and motor.velocity.x > 200, "real input event reaches horizontal intent and physics")
	_action(&"right", false)
	_action(&"left", true)
	await _ticks()
	_check(motor.axis == -1 and motor.facing == -1 and motor.velocity.x == -motor.tuning.run_speed, "input adapter changes facing and source-style ground speed within one tick")
	_action(&"left", false)
	_action(&"jump", true)
	await _ticks()
	_check(jumps.size() == 1 and motor.velocity.y < -350, "real jump press dispatches through unhandled input adapter")
	_action(&"jump", false)
	await _ticks()
	_check(motor.velocity.y > -220 and motor.velocity.y < 0, "real jump release shortens current rise")
	await _ticks(90)
	motor.apply_pause(0.1)
	_action(&"dash", true)
	_action(&"dash", false)
	await _ticks(15)
	_check(dashes.size() == 1 and dashes[0] == -1, "press and release within one input frame survives physics pause")
	print("CHECKED: actual Godot input adapter event path")

func _jump_height(release_after: int) -> float:
	await _start_fixture(Vector2(0, 280))
	var start_y := motor.position.y
	var lowest_y := start_y
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	lowest_y = minf(lowest_y, motor.position.y)
	for frame in 160:
		motor.set_intent(0, false, frame == release_after, false, release_after < 0 or frame < release_after)
		await _ticks()
		lowest_y = minf(lowest_y, motor.position.y)
		if motor.is_on_floor() and frame > 5:
			break
	_check(motor.is_on_floor(), "jump arc returns to floor")
	_check(jumps.size() == 1, "held jump does not auto-repeat")
	return start_y - lowest_y

func _test_variable_jump() -> void:
	var held_height := await _jump_height(-1)
	var tap_height := await _jump_height(2)
	_check(held_height > 55 and held_height < 85, "held jump has expected physical height", "height=%.3f" % held_height)
	_check(tap_height > 8 and tap_height < held_height * 0.6, "early release materially shortens actual jump arc", "held=%.3f tap=%.3f" % [held_height, tap_height])
	print("CHECKED: variable jump; hold %.2f px, tap %.2f px" % [held_height, tap_height])

func _walk_off() -> bool:
	motor.set_intent(1)
	for _frame in 80:
		await _ticks()
		if not motor.is_on_floor():
			return true
	return false

func _test_coyote_and_walkoff() -> void:
	await _start_fixture(Vector2(-30, 280), "ledge")
	_check(await _walk_off(), "walk leaves real platform edge")
	motor.set_intent(0)
	await _ticks(4)
	_check(not motor.is_on_floor() and motor.coyote > 0, "real ledge departure opens grace interval")
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(jumps.size() == 1 and not jumps[0], "coyote jump uses ground jump")
	_check(motor.velocity.y < -350 and motor.jump_count == 1, "coyote jump lifts actual body with air jump reserved")
	await _start_fixture(Vector2(-30, 280), "ledge")
	_check(await _walk_off(), "second fixture walks off edge")
	motor.set_intent(0)
	await _ticks(18)
	_check(motor.coyote <= 0 and motor.jump_count == 1, "expired grace spends missing ground jump")
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(jumps.size() == 1 and jumps[0] and motor.jump_count == 2, "walkoff leaves exactly one air jump")
	var rising_speed := motor.velocity.y
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(jumps.size() == 1 and motor.velocity.y > rising_speed, "walkoff cannot gain a third jump")
	print("CHECKED: actual ledge coyote and walkoff accounting")

func _test_landing_buffer() -> void:
	await _start_fixture(Vector2(0, 205), "flat", false)
	motor.double_jump_enabled = false
	motor.velocity.y = 280
	var pressed := false
	for _frame in 80:
		if not pressed and FLOOR_Y - motor.position.y < 17 and not motor.is_on_floor():
			motor.set_intent(0, true, false, false, true)
			pressed = true
		await _ticks()
		if not jumps.is_empty():
			break
	_check(pressed and landing_speeds.size() == 1, "buffer fixture actually lands after button press")
	_check(jumps.size() == 1 and not jumps[0] and motor.velocity.y < -350, "prelanding buffer launches ground jump on contact")
	await _start_fixture(Vector2(0, 120), "flat", false)
	motor.double_jump_enabled = false
	motor.set_intent(0, true, false, false, true)
	await _ticks(100)
	_check(motor.is_on_floor() and jumps.is_empty(), "expired airborne jump buffer does not launch on much later landing")
	await _start_fixture(Vector2(0, 274), "flat", false)
	motor.double_jump_enabled = false
	motor.velocity.y = 320
	motor.set_intent(0, true, true, false, false)
	var minimum_y := FLOOR_Y
	for _frame in 65:
		await _ticks()
		if not jumps.is_empty():
			minimum_y = minf(minimum_y, motor.position.y)
	_check(jumps.size() == 1 and FLOOR_Y - minimum_y < 30, "press and release before landing yields a short buffered jump", "height=%.3f" % (FLOOR_Y - minimum_y))
	print("CHECKED: landing buffer, expiry, release before launch")

func _test_double_jump() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(0, true, false, false, true)
	await _ticks(8)
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(jumps.size() == 2 and not jumps[0] and jumps[1], "second jump is airborne and distinct")
	_check(motor.jump_count == 2 and motor.velocity.y < -350, "air jump refreshes upward velocity once")
	motor.set_intent(0, true, false, false, true)
	await _ticks(4)
	_check(jumps.size() == 2, "third jump is rejected")
	await _ticks(130)
	_check(motor.is_on_floor() and motor.jump_count == 0, "landing restores jump budget")
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(jumps.size() == 3 and not jumps[2], "jump works again after landing")
	print("CHECKED: double jump limit and landing reset")

func _test_air_reversal() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.tuning.instant_ground_response = false
	motor.tuning.instant_air_steering = false
	motor.set_intent(1)
	await _ticks(12)
	motor.set_intent(1, true, false, false, true)
	await _ticks(3)
	motor.set_intent(-1, false, false, false, true)
	_check(motor.facing == -1 and motor.velocity.x > 0, "air intent owns facing independently of inertia")
	await _ticks()
	_check(motor.velocity.x > 0 and motor.velocity.x < motor.tuning.run_speed, "air reversal decelerates before changing direction")
	await _ticks(12)
	_check(not motor.is_on_floor() and motor.velocity.x < -100, "air reversal changes physical travel during jump")
	print("CHECKED: air steering and reversal")

func _test_dash_latch() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(1, false, false, true)
	await _ticks()
	_check(dashes.size() == 1 and dashes[0] == 1 and motor.velocity.x > 600, "dash starts in current input-facing")
	var dash_x := motor.position.x
	motor.set_intent(-1)
	await _ticks(5)
	_check(motor.facing == -1 and motor.dash_direction == 1, "reverse input changes face without changing latched dash direction")
	_check(motor.velocity.x > 600 and motor.position.x > dash_x + 20, "active dash keeps physical travel direction through reversal")
	await _ticks(32)
	_check(motor.velocity.x < -200, "current input resumes after latched dash")
	motor.set_intent(0)
	await _ticks(8)
	motor.set_intent(0, false, false, true)
	await _ticks()
	_check(dashes.size() == 2 and dashes[1] == -1 and motor.velocity.x < -600, "neutral dash uses preserved facing")
	print("CHECKED: dash direction latch and neutral-facing fallback")

func _test_air_dash_budget() -> void:
	await _start_fixture(Vector2(0, -650), "flat", false)
	motor.set_intent(1, false, false, true)
	await _ticks()
	_check(dashes.size() == 1 and motor.air_dash_count == 1, "air dash spends one charge")
	await _ticks(50)
	_check(not motor.is_on_floor() and motor.dash_cooldown <= 0, "second dash attempted airborne after actual cooldown")
	motor.set_intent(1, false, false, true)
	await _ticks(20)
	_check(dashes.size() == 1, "second air dash is rejected despite elapsed cooldown")
	motor.set_intent(0)
	for _frame in 220:
		await _ticks()
		if motor.is_on_floor():
			break
	_check(motor.is_on_floor() and motor.air_dash_count == 0, "landing restores air dash charge")
	motor.set_intent(0, true, false, false, true)
	await _ticks(2)
	motor.set_intent(-1, false, false, true, true)
	await _ticks()
	_check(dashes.size() == 2 and motor.air_dash_count == 1 and motor.velocity.x < -600, "new flight can spend restored dash charge")
	print("CHECKED: air dash budget and landing reset")

func _test_dash_jump_cancel() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(1, false, false, true)
	await _ticks()
	motor.set_intent(1, true, false, false, true)
	await _ticks()
	_check(jumps.is_empty() and motor.dash_left > 0, "dash cannot be jump-cancelled before cancel interval")
	var elapsed_frames := 2
	while jumps.is_empty() and elapsed_frames < 20:
		await _ticks()
		elapsed_frames += 1
	_check(jumps.size() == 1 and elapsed_frames * DT >= motor.tuning.dash_jump_cancel_after, "buffered jump waits for cancel interval", "elapsed=%.4f" % (elapsed_frames * DT))
	_check(elapsed_frames * DT < motor.tuning.dash_jump_cancel_after + DT * 3, "cancel fires promptly once permitted", "elapsed=%.4f" % (elapsed_frames * DT))
	_check(motor.dash_left <= 0 and motor.velocity.y < -350 and not motor.is_on_floor(), "jump cancel actually exits dash and rises")
	print("CHECKED: dash jump-cancel timing")

func _test_swept_collisions() -> void:
	await _start_fixture(Vector2(0, 280))
	_box(Vector2(201, 120), Vector2(2, 400))
	motor.tuning.dash_speed = 12000
	await _ticks(2)
	motor.set_intent(1, false, false, true)
	await _ticks(4)
	_check(motor.position.x <= 192.1 and motor.position.x > 185, "high-speed dash cannot tunnel through two-pixel wall", "x=%.4f" % motor.position.x)
	_check(motor.dash_left <= 0 and absf(motor.velocity.x) < 0.01, "wall collision terminates dash and horizontal velocity")
	await _start_fixture(Vector2(0, 280))
	_box(Vector2(0, 201), Vector2(400, 2))
	motor.tuning.jump_speed = 6000
	await _ticks(2)
	motor.set_intent(0, true, false, false, true)
	await _ticks(2)
	_check(motor.position.y >= 237.9, "high-speed jump cannot tunnel through two-pixel ceiling", "feet_y=%.4f" % motor.position.y)
	_check(motor.velocity.y >= 0 and motor.is_on_ceiling(), "ceiling collision clears upward speed")
	await _start_fixture(Vector2(0, 0), "none", false)
	_box(Vector2(0, 300.5), Vector2(500, 1))
	motor.tuning.terminal_speed = 9000
	motor.velocity.y = 7200
	await _ticks(8)
	_check(motor.is_on_floor() and absf(motor.position.y - FLOOR_Y) < 0.2, "high-speed fall cannot tunnel through one-pixel floor", "feet_y=%.4f" % motor.position.y)
	print("CHECKED: swept wall, ceiling, and floor collisions")

func _test_slopes_and_snap() -> void:
	await _start_fixture(Vector2(-250, 240), "slope")
	motor.set_intent(1)
	var lost_ground := 0
	var slope_samples := 0
	for _frame in 230:
		await _ticks()
		if not motor.is_on_floor():
			lost_ground += 1
		if absf(motor.get_floor_normal().x) > 0.1:
			slope_samples += 1
	_check(motor.position.x > 190 and motor.position.y > 418, "run physically descends and exits slope", str(motor.position))
	_check(lost_ground == 0 and slope_samples > 80, "floor snap keeps continuous contact down walkable slope", "airborne_ticks=%d slope_ticks=%d" % [lost_ground, slope_samples])
	motor.set_intent(-1)
	for _frame in 125:
		await _ticks()
		if not motor.is_on_floor():
			lost_ground += 1
	_check(motor.position.x < 0 and motor.position.y < 355, "reverse run climbs slope", str(motor.position))
	motor.set_intent(0)
	await _ticks(15)
	var stopped := motor.position
	await _ticks(30)
	_check(lost_ground == 0 and motor.is_on_floor(), "uphill traversal stays grounded")
	_check(motor.position.distance_to(stopped) < 0.02, "neutral grounded body does not slide down slope", "drift=%.5f" % motor.position.distance_to(stopped))
	print("CHECKED: ascending, descending, floor snap, slope rest")

func _test_pause_buffers() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.apply_pause(0.12)
	var paused_position := motor.position
	motor.set_intent(-1, true, true, false, false)
	var captured_buffer := motor.jump_buffer
	await _ticks(12)
	_check(motor.position == paused_position and jumps.is_empty(), "hit pause freezes physical movement")
	_check(motor.facing == -1 and is_equal_approx(motor.jump_buffer, captured_buffer), "hit pause captures facing and freezes jump-buffer lifetime")
	await _ticks(5)
	_check(jumps.size() == 1 and motor.velocity.y < 0 and motor.velocity.y > -250, "pause-preserved press and release launch short jump afterward")
	await _start_fixture(Vector2(0, 280))
	motor.apply_pause(0.20)
	paused_position = motor.position
	motor.set_intent(-1, false, false, true)
	await _ticks(20)
	_check(motor.position == paused_position and dashes.is_empty() and motor.dash_buffer > 0, "pause longer than ordinary dash-buffer lifetime retains input")
	await _ticks(8)
	_check(dashes.size() == 1 and dashes[0] == -1 and motor.position.x < paused_position.x, "paused dash starts in preserved face when simulation resumes")
	print("CHECKED: pause capture, buffer lifetime, release preservation")

func _test_knockback() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(1, false, false, true)
	await _ticks(2)
	motor.apply_impulse(Vector2(-300, -160), 0.15)
	_check(motor.dash_left <= 0 and motor.velocity.x == -300, "external impulse immediately interrupts dash")
	motor.set_intent(1)
	await _ticks(2)
	_check(motor.state == &"STUN" and motor.velocity.x < -250 and motor.position.y < FLOOR_Y, "stun preserves physical knockback despite opposing input")
	_check(motor.facing == 1, "knockback does not own facing")
	await _ticks(36)
	_check(motor.stun_left <= 0 and motor.velocity.x > 200, "ordinary control returns after stun expires")
	_check(dashes.size() == 1, "interrupted dash does not restart by itself")
	print("CHECKED: knockback interruption and control return")

func _test_instant_response() -> void:
	await _start_fixture(Vector2(0, 280))
	_check(motor.tuning.instant_ground_response and motor.tuning.instant_air_steering, "player defaults select source-grounded immediate response")
	var start_x := motor.position.x
	motor.set_intent(1)
	await _ticks()
	_check(is_equal_approx(motor.velocity.x, motor.tuning.run_speed) and absf(motor.position.x - start_x - motor.tuning.run_speed * DT) < 0.01, "default ground input reaches target velocity and displacement in one tick")
	motor.set_intent(-1)
	await _ticks()
	_check(is_equal_approx(motor.velocity.x, -motor.tuning.run_speed) and motor.facing == -1, "default ground reversal changes travel and facing in one tick")
	var stopped_x := motor.position.x
	motor.set_intent(0)
	await _ticks()
	_check(motor.velocity.x == 0 and is_equal_approx(stopped_x, motor.position.x) and motor.facing == -1, "default ground release stops immediately and retains facing")
	motor.set_intent(1, true, false, false, true)
	await _ticks()
	_check(motor.jump_flight and motor.velocity.x == motor.tuning.run_speed, "launched jump keeps full horizontal target speed")
	motor.set_intent(-1, false, false, false, true)
	await _ticks()
	_check(motor.velocity.x == -motor.tuning.run_speed and motor.facing == -1, "default jump steering reverses in one physics tick")
	await _start_fixture(Vector2(-30, 280), "ledge")
	_check(await _walk_off(), "reduced-steering fixture leaves an actual ledge")
	motor.set_intent(1, false, false, false, true)
	await _ticks()
	_check(not motor.jump_flight and is_equal_approx(motor.velocity.x, motor.tuning.run_speed * motor.tuning.walk_off_speed_ratio), "walk-off fall uses reduced steering target instead of jump speed")
	motor.set_intent(-1, false, false, false, true)
	await _ticks()
	_check(is_equal_approx(motor.velocity.x, -motor.tuning.run_speed * motor.tuning.walk_off_speed_ratio), "walk-off reversal retains reduced steering target")
	var npc_tuning := load("res://movement/resources/npc.tres") as MokshaMovementTuning
	_check(not npc_tuning.instant_ground_response and not npc_tuning.instant_air_steering, "NPC tuning preserves optional smooth response")
	print("CHECKED: source-grounded immediate response and reduced ledge-fall steering")

func _wait_for_rising_apex() -> bool:
	for _frame in 100:
		if not motor.is_on_floor() and motor.velocity.y < -15 and absf(motor.velocity.y) < motor.tuning.apex_speed:
			return true
		await _ticks()
	return false

func _test_release_and_apex_rules() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(0, true, false, false, true)
	await _ticks(2)
	motor.set_intent(0, false, true, false, false)
	await _ticks()
	_check(absf(motor.velocity.y - (-motor.tuning.jump_release_speed_cap + motor.tuning.gravity * DT)) < 0.05, "early release caps ascent at configured speed before one gravity tick", "vy=%.3f" % motor.velocity.y)
	var previous_vy := motor.velocity.y
	await _ticks()
	_check(absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "release cap applies once rather than repeatedly cutting ascent")
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(await _wait_for_rising_apex(), "ordinary ground jump enters natural rising apex band")
	previous_vy = motor.velocity.y
	await _ticks()
	_check(absf(motor.velocity.y - previous_vy - motor.tuning.gravity * motor.tuning.apex_gravity_multiplier * DT) < 0.05, "held eligible jump receives measured apex gravity assistance")
	previous_vy = motor.velocity.y
	motor.set_intent(0, false, true, false, false)
	await _ticks()
	_check(absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "release near apex does not overcut already-slow ascent", "before=%.3f after=%.3f" % [previous_vy, motor.velocity.y])
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(await _wait_for_rising_apex(), "held-gate fixture enters natural rising apex band")
	motor.set_intent(0, false, false, false, false)
	previous_vy = motor.velocity.y
	await _ticks()
	_check(absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "apex assist requires current held intent even without a release edge")
	print("CHECKED: release speed cap, one-shot cut, near-apex release, held gating")

func _test_ineligible_apex() -> void:
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(0, true, false, false, true)
	await _ticks(5)
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(await _wait_for_rising_apex(), "air jump enters its own natural apex band")
	var previous_vy := motor.velocity.y
	await _ticks()
	_check(motor.apex_assist_blocked and absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "held air jump receives full gravity, without ground-jump apex assistance")
	await _start_fixture(Vector2(-30, 280), "ledge")
	_check(await _walk_off(), "walk-off apex exclusion starts at actual ledge")
	motor.set_intent(1, false, false, false, true)
	previous_vy = motor.velocity.y
	await _ticks()
	_check(not motor.jump_flight and absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "held button cannot create apex assistance during walk-off fall")
	await _start_fixture(Vector2(0, 280))
	_box(Vector2(0, 251), Vector2(400, 2))
	await _ticks(2)
	motor.set_intent(0, true, false, false, true)
	var hit_ceiling := false
	for _frame in 20:
		await _ticks()
		if motor.is_on_ceiling():
			hit_ceiling = true
			break
	_check(hit_ceiling and motor.apex_assist_blocked, "actual ceiling collision blocks held apex assistance")
	previous_vy = motor.velocity.y
	await _ticks()
	_check(absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "ceiling rebound receives full gravity despite held jump")
	await _start_fixture(Vector2(0, 280))
	motor.set_intent(0, true, false, false, true)
	await _ticks(8)
	motor.set_intent(1, false, false, true, true)
	await _ticks()
	_check(motor.apex_assist_blocked, "air dash blocks current flight's apex assistance")
	while motor.dash_left > 0:
		await _ticks()
	previous_vy = motor.velocity.y
	await _ticks()
	_check(absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "post-dash zero-vertical-speed frame uses full gravity")
	motor.apply_impulse(Vector2(0, -30), 0.05)
	previous_vy = motor.velocity.y
	await _ticks()
	_check(not motor.jump_flight and motor.apex_assist_blocked and absf(motor.velocity.y - previous_vy - motor.tuning.gravity * DT) < 0.05, "small rising impulse cannot inherit held-jump apex assistance")
	print("CHECKED: air-jump, walk-off, ceiling, dash, and impulse apex exclusions")

func _test_one_way_platform() -> void:
	await _start_fixture(Vector2(0, 280))
	var platform := _box(Vector2(0, 252), Vector2(180, 4))
	var collider: CollisionShape2D = platform.get_child(0)
	collider.one_way_collision = true
	collider.one_way_collision_margin = 4.0
	await _ticks(2)
	motor.set_intent(0, true, false, false, true)
	var passed_upward := false
	var hit_ceiling := false
	var landed_on_platform := false
	for _frame in 140:
		await _ticks()
		hit_ceiling = hit_ceiling or motor.is_on_ceiling()
		if motor.velocity.y < 0 and motor.position.y < 249:
			passed_upward = true
		if passed_upward and motor.is_on_floor():
			landed_on_platform = absf(motor.position.y - 250.0) < 0.2
			break
	_check(passed_upward and not hit_ceiling, "actual capsule passes upward through one-way platform")
	_check(landed_on_platform and motor.position.y < FLOOR_Y - 45, "same one-way platform catches capsule on downward return", str(motor.position))
	_check(not motor.jump_flight and motor.apex_assist_blocked and motor.jump_count == 0, "one-way landing clears flight eligibility and restores jump budget")
	print("CHECKED: actual one-way upward passage and downward landing")

func _test_modes_and_reset() -> void:
	await _start_fixture(Vector2(0, 280))
	var permission := MokshaMovementMotor.Permission
	var mode := MokshaMovementMotor.LocomotionMode
	_check(motor.locomotion_mode == mode.GROUND and (motor.allowed_actions & permission.GROUND_JUMP) != 0 and (motor.allowed_actions & permission.AIR_JUMP) == 0, "ground policy permits ground jump but not air-jump branch")
	motor.set_intent(0, true, false, false, true)
	await _ticks()
	_check(motor.locomotion_mode == mode.JUMP and (motor.allowed_actions & permission.AIR_JUMP) != 0 and (motor.allowed_actions & permission.GROUND_JUMP) == 0 and (motor.allowed_actions & permission.STEER) != 0, "launched-jump policy refreshes immediately and permits air steering")
	motor.set_intent(1, false, false, true, true)
	await _ticks()
	_check(motor.locomotion_mode == mode.DASH and (motor.allowed_actions & permission.STEER) == 0 and (motor.allowed_actions & permission.DASH) == 0 and (motor.allowed_actions & permission.TURN) != 0, "dash policy permits facing but suppresses steering and nested dash")
	motor.set_intent(-1, false, false, false, true)
	await _ticks()
	_check(motor.facing == -1 and motor.velocity.x > 600, "dash action policy changes facing without redirecting travel")
	motor.apply_impulse(Vector2(120, -90), 0.12)
	_check(motor.locomotion_mode == mode.STUN and motor.allowed_actions == permission.TURN, "external impulse switches immediately to turn-only policy")
	var jumps_before := jumps.size()
	var dashes_before := dashes.size()
	motor.set_intent(-1, true, false, true, true)
	await _ticks(4)
	_check(jumps.size() == jumps_before and dashes.size() == dashes_before and motor.velocity.x > 0 and motor.facing == -1, "stun rejects jump/dash/steering while preserving facing control")
	motor.reset_at(Vector2(0, FLOOR_Y))
	_check(motor.last_event == "RESET" and motor.state != &"STUN" and motor.state != &"DASH" and not motor.last_jump_was_air, "reset refreshes action/state telemetry immediately")
	_check(not motor.jump_flight and motor.apex_assist_blocked and motor.jump_buffer == 0 and motor.dash_buffer == 0, "reset clears flight eligibility and all buffered actions")
	await _ticks(3)
	_check(motor.locomotion_mode == mode.GROUND and motor.state == &"IDLE", "reset recomputes actual grounded policy and idle telemetry")
	await _start_fixture(Vector2(-30, 280), "ledge")
	_check(await _walk_off(), "ledge-mode policy fixture departs actual geometry")
	_check(motor.locomotion_mode == mode.LEDGE_FALL and (motor.allowed_actions & permission.GROUND_JUMP) != 0 and (motor.allowed_actions & permission.AIR_JUMP) != 0, "ledge-fall policy retains gated coyote and air-jump routes")
	print("CHECKED: locomotion permissions, physical enforcement, and reset telemetry")
