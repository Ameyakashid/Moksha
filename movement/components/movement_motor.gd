class_name MokshaMovementMotor
extends CharacterBody2D
## Input source supplies intent; motor alone owns facing, velocity and collisions.
## Facing follows current intent immediately. A dash's travel vector is latched
## independently, so reversing the face cannot secretly steer an active dash.
signal landed(speed: float)
signal jumped(air_jump: bool)
signal dash_started(direction: int)
signal state_changed(previous: StringName, current: StringName)
@export var tuning: MokshaMovementTuning = preload("res://movement/resources/player.tres")
@export var facing: int = 1
@export var enabled: bool = true
@export var double_jump_enabled: bool = true
@export var air_dash_enabled: bool = true
@export var coyote_enabled: bool = true
@export var variable_jump_enabled: bool = true
@export var input_buffer_enabled: bool = true
enum LocomotionMode { GROUND, JUMP, LEDGE_FALL, DASH, STUN }
enum Permission { TURN = 1, STEER = 2, GROUND_JUMP = 4, AIR_JUMP = 8, DASH = 16 }
# SOTN's state dispatcher supplies branch flags to a common action gate. These
# original named policies express that structure without opaque bit constants.
const MODE_PERMISSIONS := {
	LocomotionMode.GROUND: Permission.TURN | Permission.STEER | Permission.GROUND_JUMP | Permission.DASH,
	LocomotionMode.JUMP: Permission.TURN | Permission.STEER | Permission.AIR_JUMP | Permission.DASH,
	LocomotionMode.LEDGE_FALL: Permission.TURN | Permission.STEER | Permission.GROUND_JUMP | Permission.AIR_JUMP | Permission.DASH,
	LocomotionMode.DASH: Permission.TURN | Permission.GROUND_JUMP | Permission.AIR_JUMP,
	LocomotionMode.STUN: Permission.TURN
}
var locomotion_mode: LocomotionMode = LocomotionMode.LEDGE_FALL
var allowed_actions: int = MODE_PERMISSIONS[LocomotionMode.LEDGE_FALL]
var jump_flight := false
var apex_assist_blocked := true
var state: StringName = &"FALL"
var axis: float = 0.0
var jump_held: bool = false
var jump_buffer: float = 0.0
var dash_buffer: float = 0.0
var coyote: float = 0.0
var jump_count: int = 0
var air_dash_count: int = 0
var dash_left: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: int = 1
var landing_left: float = 0.0
var pause_left: float = 0.0
var stun_left: float = 0.0
var last_jump_was_air: bool = false
var jump_release_pending: bool = false
var last_collision_normal := Vector2.ZERO
var last_event: String = "READY"
var last_event_seconds: float = 0.0
var _jump_this_tick := false

func _ready() -> void:
	process_physics_priority = 10
	floor_snap_length = tuning.floor_snap
	floor_max_angle = deg_to_rad(tuning.max_slope_degrees)
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = 0.04

func set_intent(horizontal: float, jump_pressed: bool = false, jump_released: bool = false, dash_pressed: bool = false, held: bool = false) -> void:
	axis = clampf(horizontal, -1.0, 1.0)
	jump_held = held
	if not enabled: return
	# Capture every event before any pause/state guard. Buffer expiry freezes
	# through a hit pause. Releasing early still cuts a buffered jump on launch.
	if jump_pressed:
		jump_buffer = tuning.jump_buffer_seconds if input_buffer_enabled else 0.0001
		jump_release_pending = false
	if jump_released: jump_release_pending = true
	if dash_pressed: dash_buffer = tuning.dash_buffer_seconds if input_buffer_enabled else 0.0001
	if absf(axis) > 0.01 and (allowed_actions & Permission.TURN) != 0: facing = int(signf(axis))

func _physics_process(dt: float) -> void:
	step_motor(dt)

func step_motor(dt: float) -> void:
	if not enabled:
		clear_intent()
		return
	if absf(axis) > 0.01 and (allowed_actions & Permission.TURN) != 0: facing = int(signf(axis))
	if pause_left > 0.0:
		pause_left = maxf(0.0, pause_left - dt)
		return
	var grounded := is_on_floor()
	var was_grounded := grounded
	_update_mode(grounded)
	_jump_this_tick = false
	last_collision_normal = Vector2.ZERO
	dash_cooldown = maxf(0.0, dash_cooldown - dt)
	landing_left = maxf(0.0, landing_left - dt)
	last_event_seconds = maxf(0.0, last_event_seconds - dt)
	if grounded:
		coyote = tuning.coyote_seconds if coyote_enabled else 0.0
		jump_count = 0
		air_dash_count = 0
		jump_flight = false
		apex_assist_blocked = true
	else:
		coyote = maxf(0.0, coyote - dt)
		# Walking off a ledge spends the ground jump once grace expires.
		if coyote <= 0.0 and jump_count == 0: jump_count = 1
	if stun_left > 0.0:
		stun_left = maxf(0.0, stun_left - dt)
		velocity.x = move_toward(velocity.x, 0.0, tuning.air_braking * dt)
		_apply_gravity(dt)
	else:
		var can_dash := (allowed_actions & Permission.DASH) != 0 and (grounded or (air_dash_enabled and air_dash_count < tuning.air_dashes))
		if dash_buffer > 0.0 and dash_left <= 0.0 and dash_cooldown <= 0.0 and can_dash:
			dash_buffer = 0.0
			apex_assist_blocked = true
			dash_direction = facing
			dash_left = tuning.dash_seconds
			dash_cooldown = tuning.dash_cooldown
			if not grounded: air_dash_count += 1
			_event("DASH START")
			dash_started.emit(dash_direction)
		var ground_jump_allowed := (allowed_actions & Permission.GROUND_JUMP) != 0 and (grounded or coyote > 0.0)
		var air_jump_allowed := (allowed_actions & Permission.AIR_JUMP) != 0 and double_jump_enabled and jump_count < tuning.max_jumps
		var can_jump := ground_jump_allowed or air_jump_allowed
		var dash_cancel_allowed := dash_left <= 0.0 or tuning.dash_seconds - dash_left >= tuning.dash_jump_cancel_after
		if jump_buffer > 0.0 and can_jump and dash_cancel_allowed:
			var air_jump := not grounded and coyote <= 0.0
			last_jump_was_air = air_jump
			jump_flight = true
			apex_assist_blocked = air_jump
			velocity.y = -tuning.air_jump_speed if air_jump else -tuning.jump_speed
			jump_count = maxi(jump_count, 1) + 1 if air_jump else 1
			coyote = 0.0
			jump_buffer = 0.0
			dash_left = 0.0
			landing_left = 0.0
			_jump_this_tick = true
			_event("AIR JUMP" if air_jump else "JUMP")
			jumped.emit(air_jump)
		_update_mode(grounded and not _jump_this_tick)
		if variable_jump_enabled and jump_release_pending and velocity.y < 0.0:
			velocity.y = maxf(velocity.y, -tuning.jump_release_speed_cap)
			jump_release_pending = false
		elif jump_buffer <= 0.0: jump_release_pending = false
		if dash_left > 0.0:
			velocity = Vector2(dash_direction * tuning.dash_speed, 0.0)
			dash_left = maxf(0.0, dash_left - dt)
		else:
			_move_horizontal(dt, grounded and not _jump_this_tick)
			_apply_gravity(dt)
	var impact_speed := velocity.y
	move_and_slide()
	for index in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if normal.y > 0.7:
			apex_assist_blocked = true
			_event("CEILING / APEX ASSIST OFF")
		last_collision_normal = normal
		if dash_left > 0.0 and tuning.wall_dash_stop and absf(normal.x) > 0.7:
			dash_left = 0.0
			velocity.x = 0.0
			_event("DASH / WALL")
	if is_on_floor() and not was_grounded:
		jump_count = 0
		air_dash_count = 0
		jump_flight = false
		apex_assist_blocked = true
		if impact_speed > 50.0:
			landing_left = tuning.landing_seconds
			_event("LAND %.0f" % impact_speed)
			landed.emit(impact_speed)
	jump_buffer = maxf(0.0, jump_buffer - dt)
	dash_buffer = maxf(0.0, dash_buffer - dt)
	_update_mode(is_on_floor())
	_resolve_state()

func _move_horizontal(dt: float, grounded: bool) -> void:
	if (allowed_actions & Permission.STEER) == 0: return
	var speed_ratio := 1.0 if grounded or jump_flight else tuning.walk_off_speed_ratio
	var target := axis * tuning.run_speed * speed_ratio
	# PlayerStepWalk assigns speed directly; jump steering does too. The
	# optional smooth response is retained for NPC tuning and later comparison.
	if grounded and tuning.instant_ground_response:
		velocity.x = target
		return
	if not grounded and tuning.instant_air_steering and absf(axis) > 0.01:
		velocity.x = target
		return
	var rate := tuning.acceleration if grounded else tuning.air_acceleration
	if absf(axis) < 0.01:
		rate = tuning.braking if grounded else tuning.air_braking
	elif velocity.x * axis < 0.0:
		rate = tuning.reversal_acceleration if grounded else tuning.air_reversal
	velocity.x = move_toward(velocity.x, target, rate * dt)

func _apply_gravity(dt: float) -> void:
	var multiplier := tuning.fall_gravity_multiplier if velocity.y > 0.0 else 1.0
	if jump_flight and jump_held and not apex_assist_blocked and absf(velocity.y) < tuning.apex_speed and not is_on_floor():
		multiplier = tuning.apex_gravity_multiplier
	velocity.y = minf(tuning.terminal_speed, velocity.y + tuning.gravity * multiplier * dt)

func _update_mode(grounded: bool) -> void:
	if stun_left > 0.0: locomotion_mode = LocomotionMode.STUN
	elif dash_left > 0.0: locomotion_mode = LocomotionMode.DASH
	elif grounded: locomotion_mode = LocomotionMode.GROUND
	else: locomotion_mode = LocomotionMode.JUMP if jump_flight else LocomotionMode.LEDGE_FALL
	allowed_actions = MODE_PERMISSIONS[locomotion_mode]

func _resolve_state() -> void:
	var next: StringName
	if stun_left > 0.0: next = &"STUN"
	elif dash_left > 0.0: next = &"DASH"
	elif not is_on_floor():
		if absf(velocity.y) <= tuning.apex_speed: next = &"APEX"
		else: next = &"RISE" if velocity.y < 0.0 else &"FALL"
	elif landing_left > 0.0: next = &"LAND"
	elif absf(velocity.x) < 0.5: next = &"IDLE"
	elif absf(axis) < 0.01 or velocity.x * axis < 0.0: next = &"BRAKE"
	else: next = &"RUN"
	if next != state:
		var previous := state
		state = next
		state_changed.emit(previous, state)

func apply_pause(seconds: float = 0.08) -> void:
	pause_left = maxf(pause_left, seconds)
	_event("HIT PAUSE / BUFFER INPUT")

func apply_impulse(impulse: Vector2, seconds: float = 0.14) -> void:
	dash_left = 0.0
	jump_flight = false
	apex_assist_blocked = true
	velocity = impulse
	stun_left = seconds
	_update_mode(is_on_floor())
	_event("EXTERNAL IMPULSE")

func clear_intent() -> void:
	axis = 0.0
	jump_buffer = 0.0
	dash_buffer = 0.0
	jump_release_pending = false
	jump_held = false

func reset_at(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	clear_intent()
	dash_left = 0.0
	dash_cooldown = 0.0
	coyote = 0.0
	jump_count = 0
	air_dash_count = 0
	pause_left = 0.0
	stun_left = 0.0
	landing_left = 0.0
	jump_flight = false
	apex_assist_blocked = true
	facing = 1
	last_jump_was_air = false
	_update_mode(is_on_floor())
	_resolve_state()
	_event("RESET")

func _event(value: String) -> void:
	last_event = value
	last_event_seconds = 1.2
