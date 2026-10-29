extends CharacterBody2D
## Place directly in any scene with world collision; a run controller is optional.

signal attack_performed(actor: Node2D, target: Node2D, damage: int, direction: float)
signal damaged(actor: Node2D, damage: int, direction: float, prop_hit: bool)
signal died(actor: Node2D, prop_hit: bool)
signal sound_requested(key: String, db: float, pitch: float)
signal burst_requested(at: Vector2, count: int, color: Color, speed: float)
signal text_requested(at: Vector2, value: String, color: Color)
signal shake_requested(amount: float)

const EnemyTuning = preload("res://resources/tuning/enemy_tuning.gd")
@export var tuning: EnemyTuning = preload("res://resources/tuning/enemy_default.tres")
@export var simulation_enabled: bool = true
@export var target_path: NodePath
@export var target_group: StringName = &"players"
@export var elite: bool = false
@export var facing: int = -1
@export var hitpause_seconds: float = 0.05
var target: Node2D
var origin := 0.0
var hp := 3
var max_hp := 3
var windup := 0.0
var cooldown := 0.6
var stun := 0.0
var hurt_flash := 0.0
var active := true
var phase := 0.0
var attack_done := false
var hitpause := 0.0
var _step_distance := 0.0
@onready var graphics: Node2D = $Graphics

func _ready() -> void:
	origin = global_position.x
	max_hp = tuning.max_health
	hp = max_hp
	cooldown = tuning.initial_cooldown
	add_to_group("enemies")
	add_to_group("simulation_actors")
	add_to_group("actors")
	_resolve_target()
	_update_graphics()

func _resolve_target() -> void:
	if not target_path.is_empty(): target = get_node_or_null(target_path) as Node2D
	if not is_instance_valid(target): target = get_tree().get_first_node_in_group(target_group) as Node2D

func _physics_process(dt: float) -> void:
	if not simulation_enabled or not active:
		_update_graphics()
		return
	if hitpause > 0:
		hitpause = maxf(0, hitpause - dt)
		_update_graphics()
		return
	if not is_instance_valid(target): _resolve_target()
	phase += dt
	cooldown -= dt
	stun -= dt
	hurt_flash -= dt
	velocity.y += tuning.gravity * dt
	var delta := Vector2.INF
	if is_instance_valid(target): delta = target.global_position - global_position
	if stun > 0:
		velocity.x = move_toward(velocity.x, 0, dt * tuning.stun_friction)
	elif windup > 0:
		windup -= dt
		velocity.x = 0
		if windup < tuning.hit_remaining and not attack_done:
			attack_done = true
			velocity.x = facing * tuning.attack_lunge_speed
			_emit_noise(global_position + Vector2(facing * 40, -25), &"enemy_attack", 1.25)
			burst_requested.emit(global_position + Vector2(facing * 20, -14), 7, Color("ff6c7e"), 100.0)
			if is_instance_valid(target) and target.has_method("take_damage") and delta.x * facing > 0 and absf(delta.x) < tuning.hit_range.x and absf(delta.y) < tuning.hit_range.y and _has_clear_attack(target):
				target.take_damage(tuning.attack_damage, facing)
				attack_performed.emit(self, target, tuning.attack_damage, float(facing))
	else:
		if absf(delta.x) < tuning.detection_range.x and absf(delta.y) < tuning.detection_range.y:
			facing = 1 if delta.x > 0 else -1
			if absf(delta.x) < tuning.attack_distance and absf(delta.y) < tuning.hit_range.y and cooldown <= 0:
				windup = tuning.attack_seconds
				cooldown = tuning.attack_cooldown
				attack_done = false
				_emit_noise(global_position + Vector2(facing * 11, -28), &"enemy_windup", 0.85)
			else: velocity.x = facing * tuning.move_speed if absf(delta.x) > tuning.stopping_distance else 0
		else:
			velocity.x = sin(phase * tuning.patrol_frequency) * tuning.patrol_speed
			if absf(velocity.x) > 1: facing = int(signf(velocity.x))
	if tuning.avoid_ledges and is_on_floor() and stun <= 0 and absf(velocity.x) > 1:
		if not _has_ground_ahead(signf(velocity.x)): velocity.x = 0
	var before_move := global_position
	move_and_slide()
	if is_on_floor() and absf(velocity.x) > 8 and stun <= 0 and windup <= 0:
		_step_distance += absf(global_position.x - before_move.x)
		if _step_distance >= tuning.footstep_spacing:
			_step_distance = fmod(_step_distance, tuning.footstep_spacing)
			_emit_noise(global_position + Vector2(facing * 3, 0), &"enemy_step", 0.8)
	else: _step_distance = 0.0
	_update_graphics()

func take_hit(damage: int, direction: float, prop_hit: bool = false) -> void:
	if not active or not simulation_enabled: return
	hp -= damage
	hurt_flash = tuning.hurt_flash_seconds
	stun = tuning.prop_stun if prop_hit else tuning.sword_stun
	windup = 0
	velocity = Vector2(direction * (tuning.prop_knockback if prop_hit else tuning.sword_knockback), tuning.prop_lift if prop_hit else tuning.sword_lift)
	burst_requested.emit(global_position + Vector2(0, -18), 18, Color("ffaf68") if prop_hit else Color("cf668b"), 150.0)
	text_requested.emit(global_position + Vector2(0, -32), str(damage * 25), Color("ffe3a1") if prop_hit else Color("c6ffe8"))
	shake_requested.emit(5.0 if prop_hit else 2.0)
	sound_requested.emit("hit", -10.0, 1.0)
	hitpause = hitpause_seconds
	_emit_noise(global_position + Vector2(0, -25), &"enemy_damage", 1.2 if prop_hit else 1.0)
	damaged.emit(self, damage, direction, prop_hit)
	if hp <= 0:
		active = false
		burst_requested.emit(global_position + Vector2(0, -18), 30, Color("fc9470"), 190.0)
		text_requested.emit(global_position + Vector2(0, -45), "IMPACT KILL" if prop_hit else "GUARD DOWN", Color("e4ba73"))
		if elite: shake_requested.emit(9.0)
		_emit_noise(global_position + Vector2(0, -20), &"enemy_death", 1.55)
		died.emit(self, prop_hit)
		queue_free()
	_update_graphics()

func _update_graphics() -> void:
	var state_name: StringName = &"idle"
	if not active: state_name = &"death"
	elif stun > 0: state_name = &"hurt"
	elif windup > tuning.hit_remaining: state_name = &"windup"
	elif windup > 0: state_name = &"attack"
	elif absf(velocity.x) > 8: state_name = &"walk"
	graphics.present(state_name, facing, simulation_enabled and hitpause <= 0, true, hurt_flash > 0)
	graphics.present_status(hp, max_hp, elite, windup > tuning.hit_remaining)

func _has_clear_attack(body: Node2D) -> bool:
	var start := global_position + Vector2(0, -20)
	var finish := body.global_position + Vector2(0, -20)
	var query := PhysicsRayQueryParameters2D.create(start, finish, 1, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _has_ground_ahead(direction: float) -> bool:
	var start := global_position + Vector2(direction * tuning.ledge_probe_forward, -7)
	var finish := start + Vector2(0, tuning.ledge_probe_depth + 7)
	var query := PhysicsRayQueryParameters2D.create(start, finish, 1, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _emit_noise(at: Vector2, kind: StringName, loudness: float = 1.0) -> void:
	var bus := get_node_or_null("/root/NoiseBus")
	if is_instance_valid(bus) and bus.has_method("emit_noise"):
		bus.emit_noise(at, kind, loudness, self)
