extends CharacterBody2D
## Reusable player controller. The scene owns collisions, combat, and graphics.
## A run controller may listen to presentation/lifecycle signals but is optional.

signal tapped(actor: Node2D, contact_point: Vector2)
signal attack_requested(actor: Node2D, combo: int)
signal damaged(actor: Node2D, amount: int, direction: float)
signal died(actor: Node2D)
signal sound_requested(key: String, db: float, pitch: float)
signal burst_requested(at: Vector2, count: int, color: Color, speed: float)
signal ghost_requested(at: Vector2, facing: int)
signal shake_requested(amount: float)
signal flash_requested(seconds: float)

const PlayerTuning = preload("res://resources/tuning/player_tuning.gd")
@export var tuning: PlayerTuning = preload("res://resources/tuning/player_default.tres")
@export var simulation_enabled: bool = true:
	set(value):
		if not value: clear_input_buffers()
		simulation_enabled = value
@export var input_enabled: bool = true
@export var facing: int = 1
@export var speed_multiplier: float = 1.0
@export var hitpause_seconds: float = 0.045
@export_category("Input actions")
@export var left_action: StringName = &"left"
@export var right_action: StringName = &"right"
@export var jump_action: StringName = &"jump"
@export var dash_action: StringName = &"dash"
@export var attack_action: StringName = &"attack"
@export var tap_action: StringName = &"tap"
@export_category("Optional level bounds")
@export var world_limits_enabled: bool = false
@export var horizontal_limits: Vector2 = Vector2(16, 2630)
@export var fall_death_y: float = 410.0

var max_hp: int:
	get: return tuning.max_health
var hp := 5
enum AttackPhase { IDLE, STARTUP, ACTIVE, RECOVERY }
var attack_phase: AttackPhase = AttackPhase.IDLE
var attack_time := 0.0
var attack_cd := 0.0
var combo := 0
var combo_reset := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var invuln := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var dash_buffer := 0.0
var attack_buffer := 0.0
var _jump_release_buffered := false
var jumps := 0
var step_clock := 0.0
var attack_hit := false
var dead := false
var last_floor := false
var air_lock := 0.0
var tap_cd := 0.0
var tap_time := 0.0
var tap_contact := Vector2.ZERO
var hitpause := 0.0
var _step_distance := 0.0
@onready var graphics: Node2D = $Graphics

func _ready() -> void:
	add_to_group("players")
	add_to_group("simulation_actors")
	add_to_group("actors")
	hp = tuning.max_health
	_update_graphics()

func _physics_process(dt: float) -> void:
	if not simulation_enabled or dead:
		clear_input_buffers()
		_update_graphics()
		return
	# Capture intent before local hitpause. Buffer lifetimes use gameplay time,
	# so even a press and release wholly inside a hit pause survives it.
	_capture_input()
	var axis := Input.get_axis(left_action, right_action) if input_enabled and InputMap.has_action(left_action) and InputMap.has_action(right_action) else 0.0
	if axis != 0 and dash_time <= 0: facing = int(sign(axis))
	if hitpause > 0:
		hitpause = maxf(0, hitpause - dt)
		_update_graphics()
		return
	tap_cd = maxf(0, tap_cd - dt)
	tap_time = maxf(0, tap_time - dt)
	attack_cd = maxf(0, attack_cd - dt)
	combo_reset -= dt
	dash_cd = maxf(0, dash_cd - dt)
	invuln = maxf(0, invuln - dt)
	air_lock = maxf(0, air_lock - dt)
	if combo_reset <= 0: combo = 0
	if is_on_floor():
		coyote = tuning.coyote_seconds
		jumps = 0
	else: coyote -= dt
	if dash_buffer > 0 and dash_cd <= 0:
		cancel_attack()
		dash_buffer = 0
		attack_buffer = 0
		dash_time = tuning.dash_seconds
		dash_cd = tuning.dash_cooldown
		invuln = tuning.dash_invulnerability
		sound_requested.emit("dash", -12.0, 1.0)
		_emit_noise(global_position + Vector2(0, -12), &"player_dash", 0.85)
	if jump_buffer > 0 and dash_time <= 0 and (coyote > 0 or jumps < tuning.max_jumps):
		velocity.y = -tuning.jump_speed if (coyote > 0 or jumps == 0) else -tuning.double_jump_speed
		jumps += 1
		coyote = 0
		jump_buffer = 0
		burst_requested.emit(global_position + Vector2(0, -2), 9, Color("74e9d1"), 65.0)
		sound_requested.emit("jump", -15.0, 1.0)
	if _jump_release_buffered and velocity.y < tuning.release_cut_threshold:
		velocity.y *= tuning.release_cut_factor
	_jump_release_buffered = false
	if _pressed(tap_action) and tap_cd <= 0 and attack_time <= 0 and dash_time <= 0:
		tap_weapon()
	if attack_buffer > 0 and attack_cd <= 0 and dash_time <= 0 and air_lock <= 0:
		_start_attack()
	jump_buffer = maxf(0, jump_buffer - dt)
	dash_buffer = maxf(0, dash_buffer - dt)
	attack_buffer = maxf(0, attack_buffer - dt)
	if dash_time > 0:
		dash_time -= dt
		velocity = Vector2(facing * tuning.dash_speed * speed_multiplier, 0)
		if Engine.get_physics_frames() % 3 == 0: ghost_requested.emit(global_position, facing)
	else:
		if air_lock <= 0: velocity.x = axis * tuning.move_speed * speed_multiplier
		velocity.y = minf(velocity.y + tuning.gravity * dt, tuning.terminal_speed)
	if attack_phase != AttackPhase.IDLE:
		_advance_attack(dt)
		if is_on_floor() and axis == 0 and attack_time > tuning.attack_lunge_remaining: velocity.x = facing * tuning.attack_lunge_speed
	var before_move := global_position
	var landing_speed := velocity.y
	move_and_slide()
	if world_limits_enabled: global_position.x = clampf(global_position.x, horizontal_limits.x, horizontal_limits.y)
	if is_on_floor() and not last_floor and landing_speed >= tuning.minimum_landing_speed:
		burst_requested.emit(global_position, 7, Color("738d8e"), 40.0)
		_emit_noise(global_position, &"player_land", clampf(landing_speed / 320.0, 0.55, 1.55))
	if is_on_floor() and absf(velocity.x) > 25 and dash_time <= 0:
		_step_distance += absf(global_position.x - before_move.x)
		if _step_distance >= tuning.footstep_spacing:
			_step_distance = fmod(_step_distance, tuning.footstep_spacing)
			_emit_noise(global_position + Vector2(facing * 3, 0), &"player_step", 0.65)
	else: _step_distance = 0.0
	last_floor = is_on_floor()
	step_clock += dt * (absf(velocity.x) * 0.1 + 2)
	if absf(velocity.x) > 30 and is_on_floor() and Engine.get_physics_frames() % 13 == 0:
		burst_requested.emit(global_position, 2, Color("59727b"), 25.0)
	if world_limits_enabled and global_position.y > fall_death_y: take_damage(9, 0)
	_update_graphics()

func take_damage(amount: int, direction: float) -> void:
	if invuln > 0 or dead or not simulation_enabled: return
	hp -= amount
	cancel_attack()
	clear_input_buffers()
	dash_time = 0
	invuln = tuning.damage_invulnerability
	air_lock = tuning.damage_air_lock
	velocity = Vector2(direction * tuning.damage_knockback, tuning.damage_lift)
	shake_requested.emit(5.0)
	flash_requested.emit(0.15)
	burst_requested.emit(global_position + Vector2(0, -18), 20, Color("f06481"), 130.0)
	sound_requested.emit("hurt", -9.0, 1.0)
	_emit_noise(global_position + Vector2(0, -24), &"player_damage", 1.0)
	apply_hitpause()
	damaged.emit(self, amount, direction)
	if hp <= 0:
		dead = true
		_emit_noise(global_position + Vector2(0, -20), &"player_death", 1.5)
		died.emit(self)
	_update_graphics()

func _capture_input() -> void:
	if not input_enabled:
		clear_input_buffers()
		return
	if _just_pressed(jump_action): jump_buffer = tuning.jump_buffer_seconds
	if _just_pressed(dash_action): dash_buffer = tuning.dash_buffer_seconds
	# Holding attack retains the original repeat-combo control; a brief tap is
	# also retained through recovery or hitpause by this short buffer.
	if _pressed(attack_action) or _just_pressed(attack_action): attack_buffer = tuning.attack_buffer_seconds
	if _just_released(jump_action): _jump_release_buffered = true

func clear_input_buffers() -> void:
	jump_buffer = 0
	dash_buffer = 0
	attack_buffer = 0
	_jump_release_buffered = false

func _start_attack() -> void:
	attack_buffer = 0
	combo = combo % 3 + 1
	combo_reset = tuning.combo_reset_seconds
	attack_time = tuning.attack_seconds if combo < 3 else tuning.finisher_seconds
	attack_cd = tuning.attack_cooldown if combo < 3 else tuning.finisher_cooldown
	attack_phase = AttackPhase.STARTUP
	attack_hit = false
	sound_requested.emit("swing", -11.0, 1.15 - combo * 0.08)

func _advance_attack(dt: float) -> void:
	attack_time = maxf(0, attack_time - dt)
	var hit_remaining := tuning.attack_hit_remaining if combo < 3 else tuning.finisher_hit_remaining
	if attack_time > hit_remaining:
		attack_phase = AttackPhase.STARTUP
	elif attack_time > maxf(0, hit_remaining - tuning.attack_active_seconds):
		attack_phase = AttackPhase.ACTIVE
	else:
		attack_phase = AttackPhase.RECOVERY
	if not attack_hit and attack_time <= hit_remaining:
		attack_hit = true
		_update_graphics()
		_emit_noise(graphics.weapon_tip(), &"player_strike", 1.05 if combo < 3 else 1.3)
		attack_requested.emit(self, combo)
	if attack_time <= 0: attack_phase = AttackPhase.IDLE

func cancel_attack() -> void:
	# Clear both a pending startup and any already-open contact window.
	attack_time = 0
	attack_hit = true
	attack_phase = AttackPhase.IDLE
	var strike := get_node_or_null("StrikeComponent")
	if is_instance_valid(strike): strike.cancel_attack()

func heal_to_full() -> void:
	hp = tuning.max_health

func _on_strike_shake(amount: float) -> void:
	shake_requested.emit(amount)

func _update_graphics() -> void:
	var state_name: StringName = &"idle"
	if dead: state_name = &"death"
	elif dash_time > 0: state_name = &"dash"
	elif attack_time > 0: state_name = StringName("attack_%d" % combo)
	elif air_lock > 0: state_name = &"hurt"
	elif tap_time > 0: state_name = &"tap"
	elif not is_on_floor(): state_name = &"jump" if velocity.y < 0 else &"fall"
	elif absf(velocity.x) > 10: state_name = &"run"
	var shown := dead or not (invuln > 0 and dash_time <= 0 and int(invuln * 16) % 2 == 0)
	graphics.present(state_name, facing, simulation_enabled and hitpause <= 0, shown)
	var attack_duration := tuning.attack_seconds if combo < 3 else tuning.finisher_seconds
	var attack_progress := 1.0 - attack_time / attack_duration if attack_time > 0 else -1.0
	graphics.present_combat(attack_progress, combo, dash_time > 0, tap_contact, tap_time > 0)

func _pressed(action: StringName) -> bool:
	return input_enabled and InputMap.has_action(action) and Input.is_action_pressed(action)

func _just_pressed(action: StringName) -> bool:
	return input_enabled and InputMap.has_action(action) and Input.is_action_just_pressed(action)

func _just_released(action: StringName) -> bool:
	return input_enabled and InputMap.has_action(action) and Input.is_action_just_released(action)

func tap_weapon() -> bool:
	if dead or not simulation_enabled or tap_cd > 0: return false
	tap_cd = tuning.tap_cooldown
	tap_time = tuning.tap_pose_seconds
	var hand := global_position + Vector2(facing * 8, -25)
	var aim := global_position + Vector2(facing * 26, 5)
	var query := PhysicsRayQueryParameters2D.create(hand, aim, 1 | 8, [get_rid()])
	var contact := get_world_2d().direct_space_state.intersect_ray(query)
	tap_contact = contact.position if not contact.is_empty() else global_position + Vector2(facing * 25, -2)
	_update_graphics()
	_emit_noise(tap_contact, &"weapon_tap", 1.1)
	sound_requested.emit("prop", -16.0, 1.5)
	tapped.emit(self, tap_contact)
	return true

func apply_hitpause(seconds: float = -1.0) -> void:
	hitpause = maxf(hitpause, hitpause_seconds if seconds < 0 else seconds)

func _emit_noise(at: Vector2, kind: StringName, loudness: float = 1.0) -> void:
	var bus := get_node_or_null("/root/NoiseBus")
	if is_instance_valid(bus) and bus.has_method("emit_noise"):
		bus.emit_noise(at, kind, loudness, self)
