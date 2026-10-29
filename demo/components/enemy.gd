extends "res://combat_pc/fixtures/health_target.gd"
const HearingPeerFilter = preload("res://simulation/components/ai_hearing_filter.gd")
@export var hearing_peer_group: StringName = &"mission_melee_hearing"
const HearingQuery = preload("res://simulation/components/hearing_query.gd")
const HearingProfile = preload("res://simulation/resources/hearing_profile.gd")
const TerrainProfile = preload("res://simulation/resources/terrain_probe_profile.gd")
@export var terrain_probe_profile: TerrainProfile = preload("res://simulation/resources/terrain_probe_default.tres")
const TerrainProbe = preload("res://simulation/components/terrain_probe.gd")
## Authored demo encounter policy around preserved motor/contact/health parts.
## AI never writes damage into the player directly: a physical overlap commits
## one identified incoming attack, which the stock PC may guard, parry or evade.
signal defeated(enemy: Node2D)
signal attack_resolved(enemy: Node2D, result: Dictionary)
signal noise_requested(origin: Vector2, kind: StringName, loudness: float, source: Node)

@export_enum("sentinel", "listener", "warden") var kind: String = "sentinel"
@export var room_left := -100000.0
@export var room_right := 100000.0
@export var patrol_radius := 68.0
@export var detection_range := 210.0
@export var max_health := 0.0
@export var hearing_range := 340.0
@export var hearing_profile: HearingProfile
var _legacy_hearing_profile := false
@export var ai_enabled := true
@export var movement_speed := 0.0
@export var windup_override := 0.0
@export var attack_damage_override := 0.0

var dead := false
var health: float:
	get: return float(_health.current_health) if is_instance_valid(_health) else 0.0
var ai_state: StringName = &"patrol"
var attack_serial := 0
var last_attack_result: Dictionary = {}
var blind_mode := false
var reveal_remaining := 0.0
var _player: Node2D
var _bus: Node
var _health: Node
var _spawn := Vector2.ZERO
var _phase_elapsed := 0.0
var _cooldown := 0.6
var _attack_facing := 1
var _attack_spent := false
var _attack_epoch := 0
var _patrol_direction := 1
var _noise_goal := Vector2.ZERO
var _noise_memory := 0.0
var _step_distance := 0.0
var _last_position := Vector2.ZERO
var _death_elapsed := 0.0
var _counter_keys: Dictionary = {}
var _reach := 43.0
var _windup := 0.56
var _active_duration := 0.14
var _recovery := 0.72
var _damage := 1.0
var _base_tint := Color("e3b688")

func _ready() -> void:
	terrain_probe_profile = terrain_probe_profile.duplicate(true) if terrain_probe_profile != null else TerrainProfile.new()
	super._ready()
	add_to_group("enemies")
	add_to_group("actors")
	if not hearing_peer_group.is_empty(): add_to_group(hearing_peer_group)
	collision_layer = 32
	collision_mask = 9
	_legacy_hearing_profile = hearing_profile == null
	if _legacy_hearing_profile:
		hearing_profile = HearingProfile.new()
		hearing_profile.ear_offset = Vector2.ZERO
	else:
		hearing_profile = hearing_profile.duplicate(true)
	_spawn = global_position
	_last_position = global_position
	_health = get_node("StrikeHealth/Health")
	tuning = tuning.duplicate(true)
	_apply_archetype()
	_health.depleted.connect(_on_depleted)
	_health.damage_processed.connect(_on_damage_processed)
	get_node("Visual").visible = false
	landed.connect(_on_landed)

func _apply_archetype() -> void:
	var capacity := 3.0
	tuning.run_speed = 82.0
	if kind == "listener":
		capacity = 2.0
		tuning.run_speed = 112.0
		_windup = 0.46
		_recovery = 0.68
		_base_tint = Color("c6b5e9")
	elif kind == "warden":
		capacity = 8.0
		tuning.run_speed = 70.0
		_windup = 0.86
		_recovery = 0.96
		_reach = 57.0
		_damage = 2.0
		_base_tint = Color("f09070")
	if movement_speed > 0.0: tuning.run_speed = movement_speed
	if windup_override > 0.0: _windup = windup_override
	if attack_damage_override > 0.0: _damage = attack_damage_override
	_health.maximum_health = max_health if max_health > 0.0 else capacity
	_health.reset_to_full()

func configure(player: Node2D, event_bus: Node = null) -> void:
	if is_instance_valid(_bus) and _bus.has_signal("noise_emitted") and _bus.is_connected("noise_emitted", _on_bus_noise):
		_bus.disconnect("noise_emitted", _on_bus_noise)
	_player = player
	_bus = event_bus if _hearing_bus_live(event_bus) else null
	if is_instance_valid(_bus) and _bus.has_signal("noise_emitted"):
		_bus.connect("noise_emitted", _on_bus_noise)

func set_room_bounds(left: float, right: float, _floor_y: float = 0.0) -> void:
	room_left = minf(left, right)
	room_right = maxf(left, right)

func set_blind_mode(value: bool) -> void:
	blind_mode = value
	queue_redraw()

func _hearing_bus_live(event_bus: Node) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(event_bus) and event_bus.is_inside_tree() and not event_bus.is_queued_for_deletion() and event_bus.get_tree() == get_tree() and event_bus.get_viewport().world_2d == get_world_2d()

func _on_bus_noise(origin: Vector2, noise_kind: StringName, loudness: float, source: Node) -> void:
	if _hearing_bus_live(_bus): hear_noise(origin, noise_kind, loudness, source)

func hear_noise(origin: Vector2, _kind: StringName, loudness: float, source: Node = null) -> void:
	if dead or not enabled or not is_inside_tree() or is_queued_for_deletion() or not can_process() or get_tree().paused: return
	# Configured AI peer policy preserves authored hearing equivalence without
	# depending on a particular actor/controller script.
	if HearingPeerFilter.ignores(source, hearing_peer_group): return
	if _legacy_hearing_profile: hearing_profile.range_at_unit_loudness = hearing_range
	var evidence := HearingQuery.sample(self, origin, loudness, source, hearing_profile)
	if not evidence.is_empty():
		_noise_goal = evidence.origin
		_noise_memory = 3.2 if kind == "listener" else 1.8

func _exit_tree() -> void:
	if is_instance_valid(_bus) and _bus.has_signal("noise_emitted") and _bus.is_connected("noise_emitted", _on_bus_noise):
		_bus.disconnect("noise_emitted", _on_bus_noise)
	_bus = null

func _physics_process(dt: float) -> void:
	if dead:
		clear_intent()
		return
	if not enabled: return
	var previous := global_position
	if pause_left <= 0.0:
		_cooldown = maxf(0.0, _cooldown - dt)
		_noise_memory = maxf(0.0, _noise_memory - dt)
		if stun_left > 0.0:
			_cancel_attack(&"stagger")
			clear_intent()
		elif ai_enabled:
			_tick_ai(dt)
		else:
			_cancel_attack(&"patrol")
			clear_intent()
	step_motor(dt)
	if dead: return
	# Edge avoidance belongs to intent, never to a post-collision velocity clamp.
	# External momentum may carry any actor beyond support; gravity then wins.
	if is_on_floor() and absf(global_position.x - previous.x) > 0.1:
		_step_distance += absf(global_position.x - previous.x)
		if _step_distance >= 26.0:
			_step_distance = fmod(_step_distance, 26.0)
			_emit_noise(global_position, &"enemy_step", 0.42)
	_last_position = global_position

func _tick_ai(dt: float) -> void:
	if ai_state == &"stagger":
		ai_state = &"recover"
		_phase_elapsed = 0.0
		_cooldown = maxf(_cooldown, 0.45)
	if ai_state in [&"windup", &"active", &"recover"]:
		clear_intent()
		_phase_elapsed += dt
		if ai_state == &"windup" and _phase_elapsed >= _windup:
			ai_state = &"active"
			_phase_elapsed = 0.0
			_emit_noise(global_position + Vector2(_attack_facing * 12.0, -22.0), &"enemy_attack", 1.0)
		elif ai_state == &"active" and _phase_elapsed >= _active_duration:
			ai_state = &"recover"
			_phase_elapsed = 0.0
		elif ai_state == &"recover" and _phase_elapsed >= _recovery:
			ai_state = &"patrol"
			_phase_elapsed = 0.0
		if ai_state == &"active": _try_strike()
		return
	var has_target := _player_available()
	var to_player := _player.global_position - global_position if has_target else Vector2.INF
	var near := has_target and absf(to_player.y) < 58.0 and absf(to_player.x) <= detection_range
	# A listener sees only immediately nearby movement, but pursues remembered
	# physical sound even if the player is far away or behind the listener.
	if kind == "listener": near = near and absf(to_player.x) < 86.0
	if near and _terrain_visible(_player.global_position + Vector2(0, -20)):
		ai_state = &"chase"
		if absf(to_player.x) <= _reach - 2.0 and absf(to_player.y) < 27.0 and is_on_floor():
			clear_intent()
			if _cooldown <= 0.0: _begin_attack(int(signf(to_player.x)) if absf(to_player.x) > 0.1 else facing)
			return
		_walk_safely(signf(to_player.x), 1.0, dt)
	elif _noise_memory > 0.0:
		ai_state = &"investigate"
		var dx := _noise_goal.x - global_position.x
		if absf(dx) < 12.0:
			clear_intent()
		else: _walk_safely(signf(dx), 1.0, dt)
	else:
		ai_state = &"patrol"
		if global_position.x >= minf(room_right - 12.0, _spawn.x + patrol_radius): _patrol_direction = -1
		if global_position.x <= maxf(room_left + 12.0, _spawn.x - patrol_radius): _patrol_direction = 1
		if not _walk_safely(float(_patrol_direction), 0.43, dt): _patrol_direction *= -1

func _player_available() -> bool:
	return is_instance_valid(_player) and _player.is_inside_tree() and not _player.is_queued_for_deletion() \
		and (not _player.has_method("is_defeated") or not _player.is_defeated())

func _walk_safely(direction: float, scale_value: float = 1.0, dt: float = 1.0 / 120.0) -> bool:
	var speed := maxf(0.0, velocity.x * direction)
	var ahead := TerrainProbe.stopping_lookahead(speed, tuning.braking, dt, terrain_probe_profile.body_margin, terrain_probe_profile.minimum_lookahead)
	var predicted := global_position.x + direction * ahead
	var obstacle := TerrainProbe.obstacle(self, direction, ahead, deg_to_rad(tuning.max_slope_degrees), collision_mask, terrain_probe_profile) if is_on_floor() else ""
	if predicted < room_left + 8.0 or predicted > room_right - 8.0 or not obstacle.is_empty():
		clear_intent()
		return false
	set_intent(direction * scale_value)
	return true

func _terrain_visible(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -23), point, 1, [get_rid()])
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _begin_attack(direction: int) -> void:
	if dead or stun_left > 0.0 or not _player_available(): return
	attack_serial += 1
	_attack_epoch += 1
	_attack_facing = -1 if direction < 0 else 1
	facing = _attack_facing
	_attack_spent = false
	_phase_elapsed = 0.0
	ai_state = &"windup"
	velocity.x = 0.0
	clear_intent()
	_emit_noise(global_position + Vector2(0, -26), &"enemy_windup", 0.8)

func _try_strike() -> void:
	if dead or _attack_spent or ai_state != &"active" or not _player_available(): return
	var epoch := _attack_epoch
	var origin := global_position + Vector2(0, -22)
	var size := Vector2(_reach, 27.0)
	var center := origin + Vector2(_attack_facing * (_reach * 0.5 + 4.0), 0)
	var box := RectangleShape2D.new()
	box.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0, center)
	query.collision_mask = 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		if hit.collider != _player: continue
		if not _player.has_method("receive_attack"): return
		var body_width: float = _player.profile.body_width
		var height: float = _player.body_height
		var body := Rect2(_player.global_position - Vector2(body_width * 0.5, height), Vector2(body_width, height))
		var overlap := body.intersection(Rect2(center - size * 0.5, size))
		if not overlap.has_area(): return
		# Center of the forward-facing body edge lies inside both actual shapes
		# and the stock shield's frontal rectangle, allowing its own adjudication.
		var contact := Vector2(overlap.end.x - 0.05 if _attack_facing < 0 else overlap.position.x + 0.05, clampf(origin.y, overlap.position.y + 0.05, overlap.end.y - 0.05))
		if not _terrain_visible(contact): return
		_attack_spent = true
		var payload := {"kind": &"melee", "attack_id": attack_serial, "source": self,
			"origin": origin, "contact_position": contact, "incoming_velocity": Vector2(_attack_facing * 180.0, 0),
			"amount": _damage, "impulse": Vector2(_attack_facing * 130.0, -65.0),
			"blockable": true, "parryable": true, "counterable": true, "rollable": true}
		var result: Dictionary = _player.receive_attack(payload)
		# Defense callbacks may kill/reset/stagger this enemy synchronously.
		if not is_inside_tree() or is_queued_for_deletion() or epoch != _attack_epoch: return
		last_attack_result = result.duplicate(true)
		if result.get("outcome") == &"parried":
			apply_impulse(Vector2(-_attack_facing * 160.0, -65.0), 0.75)
		attack_resolved.emit(self, result)
		return

func apply_impulse(impulse: Vector2, seconds: float = 0.14) -> void:
	if dead: return
	_cancel_attack(&"stagger")
	super.apply_impulse(impulse, seconds)

func _cancel_attack(next: StringName) -> void:
	if ai_state in [&"windup", &"active"]: _attack_epoch += 1
	ai_state = next
	_phase_elapsed = 0.0
	_attack_spent = true

func get_shield_counter_hurtbox() -> CollisionObject2D:
	return get_node("Hurtbox") as CollisionObject2D

func receive_shield_counter(payload: Dictionary) -> Dictionary:
	if dead: return {"accepted": false, "reason": &"dead"}
	var defender: Variant = payload.get("defender")
	if not is_instance_valid(defender) or defender != _player or not defender.has_method("shield_effect_is_current"):
		return {"accepted": false, "reason": &"invalid_defender"}
	var serial := int(payload.get("shield_serial", -1))
	var key := String(payload.get("attack_key", ""))
	if not defender.shield_effect_is_current(serial, key, &"counter") or payload.get("target_id") != get_instance_id() or _counter_keys.has(key):
		return {"accepted": false, "reason": &"retired_counter"}
	var amount := maxf(0.0, float(payload.get("damage", 0.0)))
	var impulse: Vector2 = payload.get("impulse", Vector2.ZERO)
	if not is_finite(amount) or not impulse.is_finite(): return {"accepted": false, "reason": &"invalid_counter"}
	_counter_keys[key] = true
	# The preserved shield adapter has already ray-tested the real Hurtbox.
	# Feed a generation-stamped receipt into the same scalar health store.
	apply_impulse(impulse.limit_length(220.0), 0.78)
	var provider := get_node("StrikeHealth")
	provider.damage_resolved.emit({"actor_id": provider.get_instance_id(), "generation": provider.damage_generation(),
		"outcome": &"hurt", "amount": amount, "serial": serial, "source_id": defender.get_instance_id(), "cause": &"shield_counter"})
	return {"accepted": true, "reason": &"physical_counter"}

func take_hit(amount: float, direction: float, _from_prop: bool = false) -> void:
	# Compatibility boundary for prop.gd's already collision-admitted projectile.
	# The prop owns contact and per-launch identity; PC melee only sees Hurtbox4.
	if dead or not is_finite(amount) or amount <= 0.0 or not is_finite(direction): return
	apply_impulse(Vector2(signf(direction) * 180.0, -80.0), 0.42)
	var provider := get_node("StrikeHealth")
	provider.damage_resolved.emit({"actor_id": provider.get_instance_id(), "generation": provider.damage_generation(),
		"outcome": &"hurt", "amount": amount, "serial": -1, "cause": &"prop_contact"})

func _on_damage_processed(receipt: Dictionary) -> void:
	if float(receipt.get("applied", 0.0)) > 0.0:
		reveal_remaining = maxf(reveal_remaining, 0.45)
		_emit_noise(global_position + Vector2(0, -20), &"enemy_damage", 0.9)

func _on_depleted() -> void:
	if dead: return
	dead = true
	_attack_epoch += 1
	_cancel_attack(&"dead")
	clear_intent()
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	get_node("BodyShape").set_deferred("disabled", true)
	get_node("Hurtbox/Shape").set_deferred("disabled", true)
	get_node("Hurtbox").collision_layer = 0
	get_node("StrikeHealth").enabled = false
	get_node("Knockback").enabled = false
	_death_elapsed = 0.0
	_emit_noise(global_position, &"enemy_death", 1.25)
	defeated.emit(self)

func _on_landed(speed: float) -> void:
	if not dead: _emit_noise(global_position, &"landing", clampf(speed / 350.0, 0.35, 1.2))

func _emit_noise(origin: Vector2, noise_kind: StringName, loudness: float) -> void:
	reveal_remaining = maxf(reveal_remaining, 0.38)
	noise_requested.emit(origin, noise_kind, loudness, self)
	if is_instance_valid(_bus) and _bus.has_method("emit_noise"):
		_bus.emit_noise(origin, noise_kind, loudness, self)

func reset() -> void:
	reset_at(_spawn)

func reset_at(at: Vector2) -> void:
	_attack_epoch += 1
	dead = false
	enabled = true
	get_node("StrikeHealth").enabled = true
	get_node("Knockback").enabled = true
	collision_layer = 32
	collision_mask = 9
	get_node("BodyShape").set_deferred("disabled", false)
	get_node("Hurtbox/Shape").set_deferred("disabled", false)
	get_node("Hurtbox").collision_layer = 4
	super.reset_at(at)
	_spawn = at
	_last_position = at
	_noise_memory = 0.0
	_step_distance = 0.0
	_death_elapsed = 0.0
	_cooldown = 0.6
	_phase_elapsed = 0.0
	ai_state = &"patrol"
	_attack_spent = true
	last_attack_result.clear()
	reveal_remaining = 0.0
	# Attack serial deliberately never rewinds: PC's incoming identities survive
	# enemy resets, and no old packet should match a new life.

func _process(dt: float) -> void:
	reveal_remaining = maxf(0.0, reveal_remaining - dt)
	if dead: _death_elapsed += dt
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0
	if blind_mode: alpha = clampf(reveal_remaining / 0.2, 0.0, 1.0)
	if alpha <= 0.0: return
	var color := Color(_base_tint, alpha)
	if dead:
		color.a *= clampf(1.0 - _death_elapsed / 0.9, 0.0, 1.0)
		draw_line(Vector2(-12, -3), Vector2(10, -3), color, 1.5)
		draw_circle(Vector2(13, -5), 4, color, false, 1.3)
		return
	var hurtbox := get_node_or_null("Hurtbox")
	if is_instance_valid(hurtbox) and hurtbox.flash > 0: color = Color(1.0, 0.97, 0.86, alpha)
	var f := float(facing)
	var sway := sin(float(Time.get_ticks_msec()) * 0.018) * minf(absf(velocity.x) * 0.025, 2.0)
	var lean := clampf(velocity.x / 95.0, -1.0, 1.0) * 2.0
	var head := Vector2(lean, -31)
	draw_circle(head, 4.8, color, false, 1.3)
	draw_line(head + Vector2(f * 2, -1), head + Vector2(f * 6, -1), color, 1.4)
	draw_polyline(PackedVector2Array([Vector2(-5, -25), Vector2(5, -25), Vector2(4, -13), Vector2(-4, -13), Vector2(-5, -25)]), color, 1.2)
	draw_line(Vector2(-3, -13), Vector2(-5 - sway, 0), color, 1.4)
	draw_line(Vector2(3, -13), Vector2(5 + sway, 0), color, 1.4)
	var hand := Vector2(f * 10, -20)
	if ai_state == &"windup": hand = Vector2(-f * 9, -27)
	if ai_state == &"active": hand = Vector2(f * 18, -22)
	draw_line(Vector2(f * 4, -24), hand, color, 1.5)
	draw_line(hand + Vector2(-f * 5, 6), hand + Vector2(f * (22 if kind == "warden" else 15), -4), color, 1.5)
	if kind == "listener":
		draw_arc(head, 8.0, -0.8, 0.8, 8, color, 1.2)
	elif kind == "warden":
		draw_polyline(PackedVector2Array([Vector2(-6, -35), Vector2(-5, -42), Vector2(0, -38), Vector2(5, -42), Vector2(6, -35)]), color, 1.5)
		draw_line(Vector2(-8, -26), Vector2(8, -26), color, 2.8)
	if ai_state == &"windup":
		var charge := clampf(_phase_elapsed / _windup, 0.0, 1.0)
		draw_arc(Vector2(0, -22), 21, -PI * 0.5, -PI * 0.5 + TAU * charge, 28, Color(1, 0.48, 0.32, alpha), 1.6)
		draw_string(ThemeDB.fallback_font, Vector2(-2, -48), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.72, 0.42, alpha))
	elif ai_state == &"active":
		draw_line(Vector2(f * 9, -22), Vector2(f * (_reach + 4), -22), Color(1, 0.83, 0.6, alpha), 2.0)
	if is_instance_valid(_health) and health < _health.capacity:
		draw_line(Vector2(-12, -48), Vector2(12, -48), Color(color, alpha * 0.2), 2.0)
		draw_line(Vector2(-12, -48), Vector2(-12 + 24 * health / _health.capacity, -48), color, 2.0)
