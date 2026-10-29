class_name MokshaBoundaryReceiver
extends Node2D
## Opt-in response capability to authenticated geometric boundary observations.
enum Effect { ACTOR_HEALTH, CARGO_RETIRE }
const REGISTRATION := &"_moksha_boundary_receiver"
@export_node_path("PhysicsBody2D") var host_path := NodePath(".."):
	set(value):
		if host_path != value: host_path = value; _invalidate()
@export_node_path("Node") var health_path := NodePath("../Health"):
	set(value):
		if health_path != value: health_path = value; _invalidate()
@export var effect: Effect = Effect.ACTOR_HEALTH:
	set(value):
		if effect != value: effect = value; _invalidate()
@export var witness_offset := Vector2.ZERO:
	set(value):
		if witness_offset != value: witness_offset = value; _invalidate()
@export var enabled := true:
	set(value):
		if enabled != value: enabled = value; _invalidate()
var _host_ref: WeakRef
var _health_ref: WeakRef
var _binding := 0
var _consuming := false
var _attack_scope: Dictionary = {}
var _guard: Dictionary = {}
var _guard_health: WeakRef
func _ready() -> void:
	add_to_group(&"moksha_boundary_receivers")
	set_notify_local_transform(true)
	bind(get_node_or_null(host_path), get_node_or_null(health_path))
func _exit_tree() -> void: unbind()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED, NOTIFICATION_LOCAL_TRANSFORM_CHANGED, NOTIFICATION_ENTER_CANVAS, NOTIFICATION_EXIT_CANVAS, NOTIFICATION_WORLD_2D_CHANGED]: _invalidate()
func _invalidate() -> void:
	_binding += 1
	_release_guard()
	_attack_scope.clear()
func _release_guard() -> void:
	var health: Variant = _guard_health.get_ref() if _guard_health != null else null
	if is_instance_valid(health): health.release_guarded_debit(_guard)
	_guard = {}
	_guard_health = null
func get_host() -> PhysicsBody2D:
	return _host_ref.get_ref() as PhysicsBody2D if _host_ref != null else null
func get_health() -> MokshaHealthComponent:
	return _health_ref.get_ref() as MokshaHealthComponent if _health_ref != null else null
static func registered(host: Variant) -> Node:
	if not is_instance_valid(host) or not host.has_meta(REGISTRATION): return null
	var reference: Variant = host.get_meta(REGISTRATION)
	if not reference is WeakRef: return null
	var value: Variant = reference.get_ref()
	return value if is_instance_valid(value) and value is MokshaBoundaryReceiver and value.is_inside_tree() and not value.is_queued_for_deletion() and value.get_host() == host else null
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion() and node.get_tree() == get_tree()
func bind(host: Variant, health: Variant = null) -> bool:
	if not _live(host) or not host is PhysicsBody2D or not host.is_ancestor_of(self) or host.get_world_2d() != get_world_2d(): return false
	if registered(host) != null and registered(host) != self: return false
	if effect == Effect.ACTOR_HEALTH and (not _live(health) or not health is MokshaHealthComponent or not host.is_ancestor_of(health) or health.get_bound_actor() != host or not host.has_method("receive_attack")): return false
	if effect == Effect.CARGO_RETIRE and (not host.has_method("retire_from_boundary") or not host.has_method("_simulating")): return false
	unbind()
	_host_ref = weakref(host)
	_health_ref = weakref(health) if is_instance_valid(health) else null
	host.set_meta(REGISTRATION, weakref(self))
	return true
func unbind() -> void:
	_invalidate()
	var host := get_host()
	if is_instance_valid(host) and registered(host) == self: host.remove_meta(REGISTRATION)
	_host_ref = null
	_health_ref = null
func _eligible() -> bool:
	var host := get_host()
	if not enabled or not _live(self) or not _live(host) or registered(host) != self or not host.is_ancestor_of(self): return false
	if host.get_world_2d() != get_world_2d() or not can_process() or not host.can_process() or not host.is_physics_processing() or get_tree().paused: return false
	if effect == Effect.CARGO_RETIRE: return host._simulating()
	var health := get_health()
	return _live(health) and host.is_ancestor_of(health) and health.get_bound_actor() == host and health.current_health > 0.0 and not host.is_defeated()
func capture_observation() -> Dictionary:
	if not _eligible() or not witness_offset.is_finite(): return {}
	var host := get_host()
	var result := {"host_id": host.get_instance_id(), "binding": _binding, "effect": int(effect),
		"life": host.damage_generation() if effect == Effect.ACTOR_HEALTH else host.get_instance_id(),
		"point": host.to_global(witness_offset), "transform": host.global_transform, "receiver_transform": global_transform,
		"offset": witness_offset, "world": get_world_2d()}
	if effect == Effect.CARGO_RETIRE:
		result.cargo_lifecycle = host._lifecycle
		result.cargo_epoch = host.impact_epoch
	result.make_read_only()
	return result
func _current(packet: Dictionary) -> bool:
	var source: Variant = packet.get("source")
	return is_instance_valid(source) and source is MokshaBoundaryHazard and _eligible() and packet.get("snapshot") == capture_observation() \
		and source.boundary_packet_is_current(packet, self, get_host())
func receive_boundary(packet: Dictionary) -> Dictionary:
	if _consuming or not _current(packet): return {"resolved": false, "reason": &"unavailable"}
	_consuming = true
	var result := _consume(packet)
	_release_guard()
	_attack_scope.clear()
	_consuming = false
	return result
func _consume(packet: Dictionary) -> Dictionary:
	var host := get_host()
	if effect == Effect.CARGO_RETIRE:
		_attack_scope = {"packet": packet, "retire_claimed": false}
		var retired: bool = host.retire_from_boundary(packet, self)
		return {"resolved": retired, "amount": 0.0, "effect": &"cargo_retired"}
	var health := get_health()
	var source: MokshaBoundaryHazard = packet.source
	_guard = health.reserve_guarded_debit(self, source, source.world_scope(), host.damage_generation(), host.damage_admission_sequence() + 1)
	if _guard.is_empty(): return {"resolved": false, "reason": &"reservation_unavailable"}
	_guard_health = weakref(health)
	if not source.hold_guard(packet, self, host, health, _guard): return {"resolved": false, "reason": &"retired"}
	var amount: float = health.current_health if packet.damage_mode == MokshaBoundaryProfile.Damage.LETHAL_CURRENT_HEALTH else packet.damage
	var attack := {"attack_id": packet.serial, "kind": &"area", "source": source, "origin": packet.point,
		"contact_position": packet.point, "incoming_velocity": host.velocity, "impulse": host.velocity,
		"amount": amount, "stun_seconds": packet.stun_seconds, "hitpause": 0.0,
		"rollable": false, "blockable": false, "parryable": false, "boundary_contact_authority": self}
	attack.make_read_only()
	_attack_scope = {"packet": packet, "attack": attack, "claimed": false, "binding": _binding}
	var completed: Array[Dictionary] = []
	var key := "%d:area:%d" % [source.get_instance_id(), packet.serial]
	var generation: int = packet.snapshot.life
	var observe := func(receipt: Dictionary):
		if receipt.get("actor_id") == host.get_instance_id() and receipt.get("generation") == generation \
			and receipt.get("attack_key") == key and health.damage_receipt_is_current(receipt): completed.append(receipt.duplicate(true))
	health.damage_processed.connect(observe)
	host.receive_attack(attack)
	if is_instance_valid(health) and health.damage_processed.is_connected(observe): health.damage_processed.disconnect(observe)
	return {"resolved": not completed.is_empty(), "amount": float(completed[0].applied) if not completed.is_empty() else 0.0,
		"effect": &"actor_health", "reason": &"" if not completed.is_empty() else &"retired_or_rejected"}
func boundary_attack_is_current(attack: Dictionary, host: Variant) -> bool:
	if not _live(host): return false
	if _attack_scope.is_empty() or _attack_scope.get("claimed", true) or host != get_host() or not is_same(attack, _attack_scope.get("attack")): return false
	_attack_scope.claimed = true
	return _scope_current(attack) and get_health().claim_guarded_debit(_guard)
func _scope_current(attack: Dictionary) -> bool:
	return not _attack_scope.is_empty() and _attack_scope.get("binding") == _binding and is_same(attack, _attack_scope.get("attack")) \
		and _current(_attack_scope.packet) and is_instance_valid(get_health()) and get_health().guarded_debit_is_current(_guard)
func guarded_receipt_fields(attack: Dictionary) -> Dictionary:
	return _guard.duplicate() if _scope_current(attack) and _attack_scope.claimed else {}
func seal_boundary_receipt(attack: Dictionary, receipt: Dictionary) -> bool:
	return _scope_current(attack) and _attack_scope.claimed and get_health().seal_guarded_debit(_guard, receipt)
func claim_cargo_retirement(packet: Dictionary, host: Variant) -> bool:
	if not _live(host): return false
	if _attack_scope.is_empty() or _attack_scope.get("retire_claimed", true) or host != get_host() or not is_same(packet, _attack_scope.get("packet")): return false
	_attack_scope.retire_claimed = true
	return effect == Effect.CARGO_RETIRE and _current(packet)
