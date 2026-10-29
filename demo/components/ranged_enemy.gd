extends "res://demo/components/enemy.gd"
## Fragile ranged sentry: readable locked aim, safe spacing, physical reflection.
const PROJECTILE = preload("res://demo/components/ranged_projectile.tscn")
const PROJECTILE_SCRIPT = preload("res://demo/components/ranged_projectile.gd")
signal projectile_launched(enemy: Node2D, projectile: Node2D)

@export var projectile_speed := 245.0
@export var preferred_distance := 170.0
@export var minimum_distance := 115.0
@export var projectile_lifetime := 2.2
@export var reflected_damage := 2.0
var projectile_epoch := 0
var shots_fired := 0
var _aim_point := Vector2.ZERO
var _shots: Array[WeakRef] = []
var _returned_shots: Dictionary = {}

func _apply_archetype() -> void:
	# Keep the original motor/knockback/health composition and host overrides.
	tuning.run_speed = movement_speed if movement_speed > 0.0 else 58.0
	_windup = windup_override if windup_override > 0.0 else 0.72
	_recovery = 0.95
	_damage = attack_damage_override if attack_damage_override > 0.0 else 1.0
	_base_tint = Color("83c8dc")
	_health.maximum_health = max_health if max_health > 0.0 else 2.0
	_health.reset_to_full()

func _tick_ai(dt: float) -> void:
	if ai_state == &"stagger":
		ai_state = &"recover"
		_phase_elapsed = 0.0
		_cooldown = maxf(_cooldown, 0.45)
	if ai_state in [&"windup", &"recover"]:
		clear_intent()
		_phase_elapsed += dt
		if ai_state == &"windup" and _phase_elapsed >= _windup:
			_fire_projectile()
			if dead: return
			ai_state = &"recover"
			_phase_elapsed = 0.0
		elif ai_state == &"recover" and _phase_elapsed >= _recovery:
			ai_state = &"patrol"
			_phase_elapsed = 0.0
			_cooldown = maxf(_cooldown, 0.3)
		return
	if _player_available():
		var offset := _player.global_position - global_position
		var target := _player.global_position + Vector2(0, -20)
		if absf(offset.x) <= detection_range and absf(offset.y) < 80.0 and _terrain_visible(target):
			var direction := -1 if offset.x < 0.0 else 1
			facing = direction
			ai_state = &"aim"
			# Commit even at close range, giving the player a full readable window
			# to interrupt; this enemy never kites forever at melee distance.
			if _cooldown <= 0.0 and is_on_floor():
				_begin_attack(direction)
			elif absf(offset.x) < minimum_distance:
				_walk_safely(-float(direction), 0.75, dt)
			elif absf(offset.x) > preferred_distance + 65.0:
				_walk_safely(float(direction), 0.65, dt)
			else:
				clear_intent()
			return
	# Idle sentries hold their lane rather than walking into another encounter.
	ai_state = &"patrol"
	clear_intent()

func _begin_attack(direction: int) -> void:
	if dead or stun_left > 0.0 or not _player_available(): return
	super._begin_attack(direction)
	_aim_point = _player.global_position + Vector2(0, -20)

func _muzzle() -> Vector2:
	return global_position + Vector2(_attack_facing * 15.0, -22.0)

func _clear_shot(origin: Vector2, target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin, target, 1, [get_rid()])
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _fire_projectile() -> void:
	if dead or _attack_spent or ai_state != &"windup" or not _player_available(): return
	_attack_spent = true
	var origin := _muzzle()
	var direction := (_aim_point - origin).normalized()
	# Recheck at release. A door/prop wall that closed during telegraph must
	# not permit a shot to appear on its far side. Aim never tracks late dodges.
	if direction.is_zero_approx() or not _clear_shot(global_position + Vector2(0, -22), origin) or not _clear_shot(origin, _aim_point): return
	var shot = PROJECTILE.instantiate()
	shot.position = get_parent().to_local(origin)
	shot.lifetime_seconds = maxf(0.1, projectile_lifetime)
	shot.attack_damage = _damage
	shot.reflected_damage = reflected_damage
	shot.blind_mode = blind_mode
	get_parent().add_child(shot)
	shot.configure_encounter(self, direction * maxf(1.0, projectile_speed), attack_serial, projectile_epoch)
	_shots.append(weakref(shot))
	shot.resolved.connect(_on_projectile_resolved)
	shot.retired.connect(_on_projectile_retired)
	shots_fired += 1
	_emit_noise(origin, &"enemy_attack", 1.0)
	projectile_launched.emit(self, shot)

func _on_projectile_resolved(_shot: Node2D, result: Dictionary) -> void:
	if dead: return
	last_attack_result = result.duplicate(true)
	attack_resolved.emit(self, last_attack_result)

func _on_projectile_retired(shot: Node2D, _reason: StringName) -> void:
	for index in range(_shots.size() - 1, -1, -1):
		var existing: Variant = _shots[index].get_ref()
		if not is_instance_valid(existing) or existing == shot: _shots.remove_at(index)

func receive_guard_projectile(payload: Dictionary) -> Dictionary:
	if dead or not enabled or is_queued_for_deletion(): return {"accepted": false, "reason": &"dead"}
	var carrier: Variant = payload.get("carrier")
	var owner_actor: Variant = payload.get("owner")
	if not is_instance_valid(carrier) or not carrier.is_inside_tree() or carrier.is_queued_for_deletion() \
		or carrier.get_script() != PROJECTILE_SCRIPT or carrier._retired \
		or carrier.get_world_2d() != get_world_2d():
		return {"accepted": false, "reason": &"invalid_carrier"}
	if not carrier.reflected or not is_instance_valid(owner_actor) or owner_actor != _player \
		or carrier.attack_owner == null or carrier.attack_owner.get_ref() != owner_actor \
		or int(payload.get("attack_id", -1)) != carrier.attack_id:
		return {"accepted": false, "reason": &"invalid_reflection"}
	var contact: Vector2 = payload.get("contact_position", Vector2.INF)
	var incoming: Vector2 = payload.get("incoming_velocity", Vector2.ZERO)
	var amount := float(payload.get("damage", 0.0))
	var key := str(carrier.get_instance_id()) + ":" + str(carrier.attack_id)
	if not contact.is_finite() or not incoming.is_finite() or not is_finite(amount) or amount <= 0.0 \
		or contact.distance_to(carrier.last_contact) > 0.01 or _returned_shots.has(key):
		return {"accepted": false, "reason": &"invalid_or_duplicate_contact"}
	_returned_shots[key] = true
	apply_impulse(incoming.normalized() * 100.0 + Vector2(0, -45), 0.5)
	var provider := get_node("StrikeHealth")
	provider.damage_resolved.emit({"actor_id": provider.get_instance_id(), "generation": provider.damage_generation(),
		"outcome": &"hurt", "amount": amount, "serial": carrier.attack_id,
		"source_id": owner_actor.get_instance_id(), "cause": &"reflected_projectile"})
	return {"accepted": true, "reason": &"physical_reflection"}

func _retire_projectiles(reason: StringName) -> void:
	projectile_epoch += 1
	var pending := _shots.duplicate()
	_shots.clear()
	for reference in pending:
		var shot: Variant = reference.get_ref()
		if is_instance_valid(shot) and not shot.is_queued_for_deletion(): shot.retire(reason)

func _on_depleted() -> void:
	if dead: return
	_retire_projectiles(&"shooter_defeated")
	super._on_depleted()

func reset_at(at: Vector2) -> void:
	_retire_projectiles(&"shooter_reset")
	_returned_shots.clear()
	super.reset_at(at)

func _exit_tree() -> void:
	_retire_projectiles(&"shooter_exit")

func set_blind_mode(value: bool) -> void:
	super.set_blind_mode(value)
	for reference in _shots:
		var shot: Variant = reference.get_ref()
		if is_instance_valid(shot): shot.blind_mode = value

func _draw() -> void:
	super._draw()
	if dead: return
	var alpha := clampf(reveal_remaining / 0.2, 0.0, 1.0) if blind_mode else 1.0
	if alpha <= 0.0: return
	var color := Color(_base_tint, alpha)
	var f := float(facing)
	# Bow/antenna silhouette distinguishes the ranged lane at a glance.
	draw_arc(Vector2(f * 12, -22), 11.0, -PI * 0.5, PI * 0.5, 10, color, 1.6)
	draw_line(Vector2(f * 12, -33), Vector2(f * 12, -11), color, 1.0)
	if ai_state == &"windup":
		var ray := to_local(_aim_point) - Vector2(_attack_facing * 15.0, -22)
		var start := Vector2(_attack_facing * 15.0, -22)
		draw_line(start, start + ray.normalized() * minf(ray.length(), 54.0), Color(1.0, 0.57, 0.33, alpha * 0.7), 1.0)
		draw_circle(start, 2.0 + 2.0 * clampf(_phase_elapsed / _windup, 0.0, 1.0), Color(1.0, 0.74, 0.4, alpha), false, 1.1)
