extends "res://combat_pc/player.gd"
## Mission facade only. Inherited controller and composed Health remain authoritative.
const HearingQuery = preload("res://simulation/components/hearing_query.gd")
const HearingProfile = preload("res://simulation/resources/hearing_profile.gd")
const TerrainProfile = preload("res://simulation/resources/terrain_probe_profile.gd")
const ArchetypeProfile = preload("res://demo/resources/melee_archetype.gd")
class HearingPauseFence extends Node:
	var retire: Callable
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and retire.is_valid(): retire.call()
signal defeated(enemy: Node2D)
signal attack_resolved(enemy: Node2D, result: Dictionary)
@export var kind := "sentinel"
@export var emits_attack_warning := true
@export var archetype_profile: ArchetypeProfile
@export var room_left := -100000.0
@export var room_right := 100000.0
@export var patrol_radius := 68.0
@export var detection_range := 210.0
@export var max_health := 0.0
@export var hearing_range := 340.0:
	set(value):
		hearing_range = value
		if is_node_ready() and _legacy_hearing_profile: hearing_profile.range_at_unit_loudness = value
@export var hearing_profile: HearingProfile
@export var terrain_probe_profile: TerrainProfile = preload("res://simulation/resources/terrain_probe_default.tres")
@export var hearing_peer_group: StringName = &"mission_melee_hearing"
@export var ai_enabled := true
@export var enabled := true:
	set(value):
		enabled = value
		if is_node_ready(): _refresh_enabled()
@export var movement_speed := 0.0
@export var windup_override := 0.0
@export var attack_damage_override := 0.0
var dead := false
var health: float:
	get: return float(_health.current_health) if is_instance_valid(_health) else 0.0
var ai_state: StringName:
	get:
		if dead: return &"dead"
		if main_action == &"hurt": return &"stagger"
		if weapon_phase == &"recovery": return &"recover"
		if weapon_phase in [&"windup", &"active"]: return weapon_phase
		return _policy.state if is_instance_valid(_policy) else &"patrol"
var _phase_elapsed: float:
	get: return float(attack_plan_snapshot().elapsed)
var _windup: float:
	get: return float(attack_plan_snapshot().windup_seconds)
var _damage: float:
	get: return float(attack_plan_snapshot().damage)
var _reach: float:
	get: return Vector2(attack_plan_snapshot().size).x
var _noise_memory: float:
	get: return _policy.noise_memory if is_instance_valid(_policy) else 0.0
var last_attack_result: Dictionary = {}
var blind_mode := false
var reveal_remaining := 0.0
var _player: Node2D
var _bus: Node
var _health: Node
var _policy: Node
var _spawn := Vector2.ZERO
var _death_elapsed := 0.0
var _damage_flash := 0.0
var _legacy_hearing_profile := false
var _observed_receiver: Node
var _hearing_callback: Callable
var _hearing_binding := 0
var _hearing_sensor_ref: WeakRef
var _hearing_pause_fence: Node
func _ready() -> void:
	# Driver already owns private movement/combat/shield resources. Melee data is
	# independently copied here before any action is admitted.
	melee_chain = melee_chain.duplicate(true) if melee_chain != null else null
	archetype_profile = archetype_profile.duplicate(true) if archetype_profile != null else ArchetypeProfile.new()
	profile.run_speed = archetype_profile.movement_speed
	if movement_speed > 0: profile.run_speed = movement_speed
	_configure_melee_tuning()
	terrain_probe_profile = terrain_probe_profile.duplicate(true) if terrain_probe_profile != null else TerrainProfile.new()
	_legacy_hearing_profile = hearing_profile == null
	hearing_profile = HearingProfile.new() if hearing_profile == null else hearing_profile.duplicate(true)
	if _legacy_hearing_profile:
		hearing_profile.ear_offset = Vector2.ZERO
		hearing_profile.range_at_unit_loudness = hearing_range
	super._ready()
	var fence := HearingPauseFence.new()
	fence.name = "HearingPauseFence"
	fence.process_mode = Node.PROCESS_MODE_PAUSABLE
	fence.retire = _refresh_hearing_callback
	_hearing_pause_fence = fence
	add_child(fence)
	_spawn = global_position
	_policy = get_node("SentinelPolicy")
	_health = get_node("Health")
	_health.maximum_health = max_health if max_health > 0 else archetype_profile.health_capacity
	_health.reset_to_full()
	_health.damage_processed.connect(_on_health_receipt)
	get_node("DefeatResponse").defeat_started.connect(_on_defeat_started)
	movement_event.connect(_on_mission_event)
	get_node("HearingSensor").profile = hearing_profile
	_refresh_hearing_callback()
	if not hearing_peer_group.is_empty(): add_to_group(hearing_peer_group)
	_refresh_enabled()
func _configure_melee_tuning() -> void:
	if melee_chain == null or melee_chain.steps.is_empty() or melee_chain.steps[0] == null: return
	melee_chain.steps[0].windup_seconds = windup_override if windup_override > 0 else archetype_profile.windup_seconds
	melee_chain.steps[0].recovery_seconds = archetype_profile.recovery_seconds
	if attack_damage_override > 0: melee_chain.steps[0].damage = attack_damage_override
func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: _refresh_hearing_callback()
func _refresh_hearing_callback() -> void:
	_hearing_binding += 1
	var previous: Node = _hearing_sensor_ref.get_ref() if _hearing_sensor_ref != null else null
	if is_instance_valid(previous) and _hearing_callback.is_valid() and previous.heard.is_connected(_hearing_callback): previous.heard.disconnect(_hearing_callback)
	var sensor := get_node_or_null("HearingSensor")
	_hearing_sensor_ref = weakref(sensor) if is_instance_valid(sensor) else null
	if sensor == null: return
	_hearing_callback = _on_heard.bind(_hearing_binding, damage_generation(), weakref(sensor))
	sensor.heard.connect(_hearing_callback)
func _on_heard(evidence: Dictionary, binding: int, generation: int, sensor_ref: WeakRef) -> void:
	if binding != _hearing_binding or generation != damage_generation(): return
	if not is_instance_valid(_hearing_pause_fence) or not _hearing_pause_fence.is_inside_tree() or _hearing_pause_fence.is_queued_for_deletion() or _hearing_pause_fence.get_parent() != self or _hearing_pause_fence.process_mode != Node.PROCESS_MODE_PAUSABLE: return
	var sensor: Node = sensor_ref.get_ref()
	if not is_instance_valid(sensor) or sensor != get_node_or_null("HearingSensor") or not sensor.is_inside_tree() or sensor.is_queued_for_deletion() or not sensor.enabled or not sensor.can_process(): return
	# Rebinding clears the sensor's public receipt; a later genuine event
	# installs a fresh receipt and remains usable without a second facade bind.
	if sensor.last_receipt != evidence: return
	if not is_inside_tree() or is_queued_for_deletion() or not can_process() or get_tree().paused or dead or not enabled: return
	_policy.admit_hearing(evidence)
func _refresh_enabled() -> void:
	_refresh_hearing_callback()
	set_physics_process(enabled and not dead)
	var sensor := get_node_or_null("HearingSensor")
	if sensor != null: sensor.enabled = enabled and not dead and get_node("IntentDriver").capabilities.can_hear
func configure(player: Node2D, event_bus: Node = null) -> void:
	if is_instance_valid(_observed_receiver) and _observed_receiver.strike_resolved.is_connected(_on_target_strike): _observed_receiver.strike_resolved.disconnect(_on_target_strike)
	_player = player
	_bus = event_bus if _bus_live(event_bus) else null
	get_node("NoiseRelay").unbind()
	var sensor := get_node_or_null("HearingSensor")
	if sensor != null: sensor.unbind()
	if is_instance_valid(_bus):
		get_node("NoiseRelay").bind(self, _bus)
		if sensor != null: sensor.bind(self, _bus)
	_refresh_hearing_callback()
	_observed_receiver = player.get_node_or_null("BodyShape/IncomingStrikeReceiver") if is_instance_valid(player) else null
	if is_instance_valid(_observed_receiver): _observed_receiver.strike_resolved.connect(_on_target_strike)
func _bus_live(bus: Node) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(bus) and bus.is_inside_tree() and not bus.is_queued_for_deletion() and bus.get_tree() == get_tree() and bus.get_viewport().world_2d == get_world_2d()
func _exit_tree() -> void:
	_hearing_binding += 1
	var sensor: Node = _hearing_sensor_ref.get_ref() if _hearing_sensor_ref != null else null
	if is_instance_valid(sensor) and _hearing_callback.is_valid() and sensor.heard.is_connected(_hearing_callback): sensor.heard.disconnect(_hearing_callback)
	if is_instance_valid(_observed_receiver) and _observed_receiver.strike_resolved.is_connected(_on_target_strike): _observed_receiver.strike_resolved.disconnect(_on_target_strike)
	super._exit_tree()
func set_room_bounds(left: float, right: float, _floor_y: float = 0.0) -> void:
	room_left = minf(left, right)
	room_right = maxf(left, right)
func set_blind_mode(value: bool) -> void:
	blind_mode = value
	var visual := get_node_or_null("Visual")
	if visual != null: visual.queue_redraw()
func hear_noise(origin: Vector2, _kind: StringName, loudness: float, source: Node = null) -> void:
	if dead or not enabled or not is_inside_tree() or is_queued_for_deletion() or not can_process() or get_tree().paused: return
	if _legacy_hearing_profile: hearing_profile.range_at_unit_loudness = hearing_range
	_policy.admit_hearing(HearingQuery.sample(self, origin, loudness, source, hearing_profile))
func _terrain_visible(point: Vector2) -> bool:
	return _policy.terrain_visible(self, point)
func _on_target_strike(receipt: Dictionary) -> void:
	# A completed confirmed-counter parry remains observable even if it killed
	# this attacker. Never infer an outcome from source contact confirmation.
	if receipt.get("source_id") != get_instance_id() or receipt.get("source_epoch") != damage_generation() or receipt.get("serial") != attack_serial: return
	last_attack_result = receipt.duplicate(true)
	attack_resolved.emit(self, last_attack_result.duplicate(true))
func _commit_noise(origin: Vector2, noise_kind: StringName, loudness: float, generation: int) -> void:
	# Semantic presentation only; base implementation retains generation/serial
	# and the one committed-noise relay. HIT requires the Health observer below.
	if noise_kind == &"hurt": return
	var aliases := {&"footstep": &"enemy_step", &"strike": &"enemy_attack", &"land": &"landing", &"hard_land": &"landing", &"dive_impact": &"landing"}
	super._commit_noise(origin, aliases.get(noise_kind, noise_kind), loudness, generation)
	if generation == damage_generation(): reveal_remaining = maxf(reveal_remaining, 0.38)
func _on_health_receipt(receipt: Dictionary) -> void:
	if receipt.get("actor_id") != get_instance_id() or receipt.get("generation") != damage_generation() or float(receipt.get("applied", 0)) <= 0: return
	reveal_remaining = maxf(reveal_remaining, 0.45)
	_damage_flash = 0.12
	_commit_noise(global_position + Vector2(0, -20), &"enemy_damage", 0.9, int(receipt.generation))
func _on_mission_event(event: StringName, payload: Dictionary) -> void:
	if event == &"attack_started" and emits_attack_warning and not dead and weapon_phase == &"windup" and payload.get("serial") == attack_serial:
		_commit_noise(global_position + Vector2(0, -26), &"enemy_windup", 0.8, damage_generation())
	elif event == &"reset":
		dead = false
		_spawn = global_position
		_death_elapsed = 0.0
		_damage_flash = 0.0
		reveal_remaining = 0.0
		last_attack_result.clear()
		get_node("BodyShape").set_deferred("disabled", false)
		get_node("BodyShape/IncomingStrikeReceiver/Shape").set_deferred("disabled", false)
		get_node("ContactConfig").configure(get_node("ContactConfig").profile)
		_refresh_enabled()
func _on_defeat_started() -> void:
	if dead or not is_defeated() or health > 0: return
	dead = true
	_death_elapsed = 0.0
	var generation := damage_generation()
	# Defer collision/scheduler retirement until the synchronous terminal receipt
	# returns; an intervening reset invalidates this exact cleanup operation.
	_retire_defeated.call_deferred(generation)
	_commit_noise(global_position, &"enemy_death", 1.25, generation)
	if generation == damage_generation() and dead and is_defeated(): defeated.emit(self)
func _retire_defeated(generation: int) -> void:
	if generation != damage_generation() or not dead or not is_defeated() or health > 0: return
	collision_layer = 0
	collision_mask = 0
	get_node("BodyShape").disabled = true
	get_node("BodyShape/IncomingStrikeReceiver").collision_layer = 0
	get_node("BodyShape/IncomingStrikeReceiver/Shape").disabled = true
	_refresh_enabled()
func take_hit(amount: float, direction: float, _from_prop: bool = false) -> void:
	# Documented legacy stock-prop boundary. The prop admitted/deduplicated its
	# real collision; this is not authenticated shared-cargo contact evidence.
	if dead or not enabled or not is_finite(amount) or amount <= 0 or not is_finite(direction): return
	receive_attack({"amount": amount, "impulse": Vector2(signf(direction) * 180, -80), "stun_seconds": 0.42, "rollable": false})
func reset() -> void:
	reset_at(_spawn)
func reset_at(at: Vector2) -> void:
	enabled = true
	reset_actor(at, initial_facing)
func _process(dt: float) -> void:
	reveal_remaining = maxf(0, reveal_remaining - dt)
	_damage_flash = maxf(0, _damage_flash - dt)
	if dead: _death_elapsed += dt
	var visual := get_node_or_null("Visual")
	if visual != null: visual.queue_redraw()
