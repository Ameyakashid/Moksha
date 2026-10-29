extends RigidBody2D
## Scene-contained rigid-body projectile. Contact events use pre-solver velocity
## and world-space contact positions, never an arbitrary room or listener origin.

signal launched(prop: RigidBody2D)
signal impacted(prop: RigidBody2D, target: Node2D, damage: int, direction: float)
signal destroyed(prop: RigidBody2D)
signal sound_requested(key: String, db: float, pitch: float)
signal burst_requested(at: Vector2, count: int, color: Color, speed: float)
signal text_requested(at: Vector2, value: String, color: Color)
signal shake_requested(amount: float)

const PropTuning = preload("res://resources/tuning/prop_tuning.gd")
@export var tuning: PropTuning = preload("res://resources/tuning/crate_default.tres")
@export var simulation_enabled: bool = true
@export_enum("Crate", "Barrel", "Canister") var kind: int = 0
@export var enemy_group: StringName = &"enemies"
var charge := 0.0
var last_speed := Vector2.ZERO
var hit_targets := {}
var hit_count := 0
var hard_impacts := 0
var alive := true
var paused_velocity := Vector2.ZERO
var paused_spin := 0.0
var _simulation_frozen := false
var _was_frozen_before_pause := false
var _impact_cd := 0.0
var _contact_point := Vector2.ZERO
var _contact_speed := 0.0
var _physics_previous_velocity := Vector2.ZERO
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	mass = tuning.body_mass
	gravity_scale = tuning.body_gravity_scale
	linear_damp = tuning.body_linear_damp
	angular_damp = tuning.body_angular_damp
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = tuning.bounce
	physics_material_override.friction = tuning.friction
	continuous_cd = CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = maxi(8, max_contacts_reported)
	add_to_group("props")
	add_to_group("simulation_actors")
	add_to_group("actors")
	body_entered.connect(_on_body)

func launch(direction: int, force: float = 1.0) -> void:
	if not alive or not simulation_enabled: return
	charge = tuning.charge_seconds
	hit_targets.clear()
	sleeping = false
	# An impulse reaches a deterministic target speed while respecting body mass.
	var desired := Vector2(direction * tuning.launch_speed * force, tuning.launch_lift)
	apply_central_impulse((desired - linear_velocity) * mass)
	angular_velocity = direction * randf_range(tuning.launch_spin_range.x, tuning.launch_spin_range.y)
	last_speed = desired
	_physics_previous_velocity = desired
	hit_count += 1
	# Optional composed sources fence presentation after the already committed
	# physical impulse. A local token cannot be overwritten by a nested launch.
	var presentation_token: Variant = _capture_launch_presentation()
	if not _launch_presentation_is_current(presentation_token): return
	burst_requested.emit(global_position, 12, Color("ffcb79"), 100.0)
	if not _launch_presentation_is_current(presentation_token): return
	sound_requested.emit("prop", -12.0, 1.0)
	if not _launch_presentation_is_current(presentation_token): return
	text_requested.emit(global_position + Vector2(0, -20), "LAUNCHED", Color("ffcf7a"))
	if not _launch_presentation_is_current(presentation_token): return
	_emit_noise(global_position, &"prop_launch", 1.2)
	if not _launch_presentation_is_current(presentation_token): return
	launched.emit(self)

func _capture_launch_presentation() -> Variant:
	return null # Historical stock props retain their explicit callback contract.
func _launch_presentation_is_current(_token: Variant) -> bool:
	return true

func _physics_process(dt: float) -> void:
	if not simulation_enabled:
		if not _simulation_frozen:
			paused_velocity = linear_velocity
			paused_spin = angular_velocity
			_was_frozen_before_pause = freeze
			freeze = true
			_simulation_frozen = true
		return
	if _simulation_frozen:
		freeze = _was_frozen_before_pause
		linear_velocity = paused_velocity
		angular_velocity = paused_spin
		sleeping = false
		_simulation_frozen = false
	if not alive: return
	charge = maxf(0, charge - dt)
	_impact_cd = maxf(0, _impact_cd - dt)
	last_speed = linear_velocity if linear_velocity.length() > 1 else last_speed.move_toward(Vector2.ZERO, dt * 300)
	if charge > 0 and linear_velocity.length() > tuning.proximity_damage_speed and Engine.get_physics_frames() % 5 == 0:
		burst_requested.emit(global_position, 2, Color("ffd18a"), 12.0)
	sprite.self_modulate = Color(1.2, 1.1, 0.9) if charge > 0 else Color.WHITE

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not simulation_enabled or not alive: return
	var pre_velocity := _physics_previous_velocity
	if state.linear_velocity.length() > pre_velocity.length(): pre_velocity = state.linear_velocity
	var loudest_speed := 0.0
	var loudest_point := state.transform.origin
	for index in range(state.get_contact_count()):
		# Godot's "local" names identify this body, not local coordinates.
		# Both the contact point and normal are already in world space.
		var world_point := state.get_contact_local_position(index)
		var normal := state.get_contact_local_normal(index).normalized()
		var relative_velocity := pre_velocity - state.get_contact_collider_velocity_at_position(index)
		# Normal speed suppresses rolling/sliding and already resting contacts.
		var normal_speed := maxf(0, -relative_velocity.dot(normal))
		if normal_speed > loudest_speed:
			loudest_speed = normal_speed
			loudest_point = world_point
		var other := state.get_contact_collider_object(index)
		if is_instance_valid(other) and other is RigidBody2D and other.has_method("launch") and charge > 0 and pre_velocity.length() > tuning.chain_speed:
			_transfer_legacy_charge(other)
			# Momentum itself is exchanged by the solver; no fake launch teleport.
	_contact_point = loudest_point
	_contact_speed = loudest_speed
	if loudest_speed >= tuning.impact_noise_speed and _impact_cd <= 0:
		_impact_cd = tuning.impact_cooldown
		# Deferred callbacks avoid freeing/querying bodies while physics is locked.
		_register_contact_impact.call_deferred(loudest_point, loudest_speed)
	_physics_previous_velocity = state.linear_velocity

func _register_contact_impact(at: Vector2, speed: float) -> void:
	if not alive or not simulation_enabled: return
	_emit_noise(at, &"prop_impact", clampf(speed / 240.0, 0.45, 1.9))
	burst_requested.emit(at, 7, Color("aaa18c"), minf(speed * 0.25, 110.0))
	sound_requested.emit("prop", -21.0, 0.8)
	if speed >= tuning.hard_impact_speed:
		hard_impacts += 1
		if hard_impacts >= tuning.hard_impacts_to_break: _break_apart()

func _on_body(body: Node) -> void:
	if not simulation_enabled or not alive: return
	var impact_speed := maxf(last_speed.length(), _physics_previous_velocity.length())
	if body is RigidBody2D and body.has_method("launch") and charge > 0 and impact_speed > tuning.chain_speed:
		_transfer_legacy_charge(body)
	if body.has_method("take_hit") and charge > 0 and impact_speed > tuning.contact_damage_speed:
		impact_enemy.call_deferred(body)

func _transfer_legacy_charge(body: RigidBody2D) -> void:
	# Extension point: authenticated sources replace this legacy admission while
	# retaining the same material/noise/launch implementation.
	body.charge = maxf(body.charge, tuning.chain_charge_seconds)

func impact_enemy(body: Node2D) -> void:
	if not is_instance_valid(body) or not simulation_enabled or not alive or hit_targets.has(body.get_instance_id()): return
	hit_targets[body.get_instance_id()] = true
	var direction := signf(last_speed.x)
	if direction == 0: direction = 1
	body.take_hit(tuning.damage, direction, true)
	impacted.emit(self, body, tuning.damage, direction)
	shake_requested.emit(6.0)
	burst_requested.emit(global_position, 20, Color("eab779"), 130.0)
	if tuning.splash_radius > 0:
		for enemy in get_tree().get_nodes_in_group(enemy_group):
			if is_instance_valid(enemy) and enemy != body and enemy.global_position.distance_to(global_position) < tuning.splash_radius:
				enemy.take_hit(tuning.splash_damage, direction, true)
		burst_requested.emit(global_position, 40, Color("ff915c"), 210.0)
	_break_apart()

func _break_apart() -> void:
	if not alive: return
	alive = false
	_emit_noise(global_position, &"prop_break", 1.6)
	if _break_presentation_is_current(): burst_requested.emit(global_position, 20, Color("a8b4b3"), 115.0)
	# Destruction is already committed; the terminal fact and cleanup still
	# complete if a presentation observer retires an optional extension.
	destroyed.emit(self)
	queue_free()

func _break_presentation_is_current() -> bool:
	return true

func _emit_noise(at: Vector2, kind: StringName, loudness: float = 1.0) -> void:
	var bus := get_node_or_null("/root/NoiseBus")
	if is_instance_valid(bus) and bus.has_method("emit_noise"):
		bus.emit_noise(at, kind, loudness, self)
