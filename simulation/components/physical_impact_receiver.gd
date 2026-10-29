extends Node2D
## Shared admission; response is configured by capabilities, never actor role.
## Health is the existing scalar store. Only the configured motion owner moves.
signal impact_resolved(receipt: Dictionary)
const REGISTRATION: StringName = &"_moksha_physical_impact_receiver"
const HISTORY: StringName = &"_moksha_physical_impact_history"
const SOURCE_LIMIT := 64

enum Response { DEFENDED_ATTACK, HEALTH_AND_IMPULSE }
class ImpactHistory extends RefCounted:
	var sources: Array[Dictionary] = []

@export_node_path("PhysicsBody2D") var host_path := NodePath("..")
@export_node_path("Node") var health_path := NodePath("../Health")
@export_node_path("Node") var provider_path := NodePath("..")
@export var response: Response = Response.DEFENDED_ATTACK
@export var enabled := true:
	set(value):
		if value == enabled: return
		enabled = value
		_binding += 1
## Optional Boolean host property required true (e.g. movement motor enabled).
@export var required_host_flag: StringName = &""
var accepted_count := 0
var rejected_count := 0
var last_reason: StringName = &"unbound"
var last_receipt: Dictionary:
	get: return _last_receipt.duplicate(true)
var _last_receipt: Dictionary = {}
var _host_ref: WeakRef
var _health_ref: WeakRef
var _provider_ref: WeakRef
var _history: ImpactHistory
var _binding := 0
var _consuming := false
var _attack_scope: Dictionary = {}

func _ready() -> void:
	# Parent _ready may configure its health store; binding itself needs only
	# child readiness and the store's already-established provider connection.
	bind(get_node_or_null(host_path), get_node_or_null(health_path), get_node_or_null(provider_path))
func _exit_tree() -> void: unbind()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: _binding += 1
func _host() -> PhysicsBody2D: return _host_ref.get_ref() as PhysicsBody2D if _host_ref != null else null
func _health() -> Node: return _health_ref.get_ref() as Node if _health_ref != null else null
func _provider() -> Node: return _provider_ref.get_ref() as Node if _provider_ref != null else null
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
func _same_world(node: Variant) -> bool:
	return _live(self) and _live(node) and node.get_tree() == get_tree() and node.get_viewport().world_2d == get_world_2d()
static func registered(host: Node) -> Node:
	if not is_instance_valid(host) or not host.has_meta(REGISTRATION): return null
	var reference: Variant = host.get_meta(REGISTRATION)
	if not reference is WeakRef: return null
	var receiver: Variant = reference.get_ref()
	if not is_instance_valid(receiver) or not receiver is Node2D or not receiver.is_inside_tree() or receiver.is_queued_for_deletion(): return null
	return receiver if receiver.has_method("_host") and receiver._host() == host else null
func bind(host: Node, health: Node, provider: Node) -> bool:
	if not host is PhysicsBody2D or not _same_world(host) or not _same_world(health) or not _same_world(provider): return false
	if not host.is_ancestor_of(self) or (provider != host and not host.is_ancestor_of(provider)) or not host.is_ancestor_of(health): return false
	if not health is MokshaHealthComponent or health.get_bound_actor() != provider: return false
	if not provider.has_method("damage_generation") or not provider.has_signal("damage_resolved"): return false
	if response == Response.DEFENDED_ATTACK and (provider != host or not host.has_method("receive_attack")): return false
	if response == Response.HEALTH_AND_IMPULSE and not host.has_method("apply_impulse"): return false
	var current := registered(host)
	if current != null and current != self: return false
	if _host() == host and _health() == health and _provider() == provider: return true
	unbind()
	_host_ref = weakref(host)
	_health_ref = weakref(health)
	_provider_ref = weakref(provider)
	var retained: Variant = host.get_meta(HISTORY) if host.has_meta(HISTORY) else null
	_history = retained if retained is ImpactHistory else ImpactHistory.new()
	host.set_meta(HISTORY, _history)
	host.set_meta(REGISTRATION, weakref(self))
	last_reason = &"ready"
	return true
func unbind() -> void:
	_binding += 1
	_attack_scope.clear()
	var host := _host()
	if is_instance_valid(host) and registered(host) == self: host.remove_meta(REGISTRATION)
	_host_ref = null
	_health_ref = null
	_provider_ref = null
	_history = null
	last_reason = &"unbound"
func _eligible() -> bool:
	var host := _host()
	var health := _health()
	var provider := _provider()
	if not enabled or not _same_world(host) or not _same_world(health) or not _same_world(provider): return false
	if registered(host) != self or not host.is_ancestor_of(self) or not host.is_ancestor_of(health): return false
	if provider != host and not host.is_ancestor_of(provider): return false
	if not can_process() or not host.can_process() or not provider.can_process() or get_tree().paused: return false
	if host.collision_layer == 0 or not host.is_physics_processing() or health.get_bound_actor() != provider or health.current_health <= 0.0: return false
	if not required_host_flag.is_empty() and host.get(required_host_flag) != true: return false
	if response == Response.DEFENDED_ATTACK: return provider == host and host.has_method("receive_attack") and not (host.has_method("is_defeated") and host.is_defeated())
	return host.has_method("apply_impulse")
func _reject(reason: StringName) -> Dictionary:
	rejected_count += 1
	last_reason = reason
	return {"accepted": false, "reason": reason}
func capture_generation() -> int:
	return int(_provider().damage_generation()) if _eligible() else -1
func _source_index(source: Node) -> int:
	for index in range(_history.sources.size() - 1, -1, -1):
		if not is_instance_valid(_history.sources[index].source.get_ref()): _history.sources.remove_at(index)
	for index in _history.sources.size():
		if _history.sources[index].source.get_ref() == source: return index
	return -1
func _current(source: Variant, packet: Dictionary, binding: int, generation: int) -> bool:
	if binding != _binding or not _eligible() or not _same_world(source) or not source.has_method("physical_impact_is_current"): return false
	if int(_provider().damage_generation()) != generation: return false
	var current: bool = source.physical_impact_is_current(packet, _host())
	return current and binding == _binding and _eligible() and _same_world(source) and int(_provider().damage_generation()) == generation
func receive_physical_impact(packet: Dictionary) -> Dictionary:
	if _consuming: return _reject(&"reentrant")
	_consuming = true
	var result := _consume(packet)
	_consuming = false
	return result
func physical_attack_is_current(attack: Dictionary, host: Node) -> bool:
	# Only the exact derivative of an already authenticated source-owned solver
	# packet may use its captured geometry after the actor moves in this step.
	if _attack_scope.is_empty() or bool(_attack_scope.get("claimed", false)) or host != _host() or attack != _attack_scope.attack: return false
	# Reserve before any source extension query can call back into the host.
	_attack_scope.claimed = true
	return _current(_attack_scope.source, _attack_scope.packet, _attack_scope.binding, _attack_scope.generation)
func _consume(packet: Dictionary) -> Dictionary:
	if not _eligible(): return _reject(&"unavailable")
	var source: Variant = packet.get("source")
	if not _same_world(source) or source == _host() or not source.has_method("physical_impact_is_current"): return _reject(&"invalid_source")
	for field in ["epoch", "packet_id", "target_generation", "receiver_binding", "lifecycle", "physics_frame"]:
		if not packet.get(field) is int or int(packet[field]) < 0: return _reject(&"invalid_identity")
	if packet.epoch <= 0 or packet.packet_id <= 0: return _reject(&"invalid_identity")
	for field in ["blockable", "parryable", "rollable"]:
		if not packet.get(field) is bool: return _reject(&"invalid_capability")
	for field in ["origin", "contact_position", "incoming_velocity", "source_contact_velocity", "target_contact_velocity", "normal", "impulse"]:
		if not packet.get(field) is Vector2 or not Vector2(packet[field]).is_finite(): return _reject(&"invalid_vector")
	for field in ["normal_speed", "amount", "stun_seconds", "hitpause"]:
		var value: Variant = packet.get(field)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0: return _reject(&"invalid_scalar")
	if response == Response.HEALTH_AND_IMPULSE and float(packet.hitpause) > 0.0 and not _host().has_method("apply_pause"):
		return _reject(&"unsupported_pause")
	var binding := _binding
	var generation: int = packet.target_generation
	if packet.get("receiver_binding") != _binding or not _current(source, packet, binding, generation): return _reject(&"stale_contact")
	var index := _source_index(source)
	if index >= 0 and _history.sources[index].epoch >= packet.epoch: return _reject(&"duplicate")
	if index < 0 and _history.sources.size() >= SOURCE_LIMIT: return _reject(&"source_capacity")
	# Commit identity before host callbacks. Retained weak history survives
	# detach/replacement and actor reset; reset cannot replay the same launch.
	var consumed := {"source": weakref(source), "epoch": packet.epoch}
	if index < 0: _history.sources.append(consumed)
	else: _history.sources[index] = consumed
	var host := _host()
	var provider := _provider()
	var health := _health()
	var completed: Array[Dictionary] = []
	var response_at_contact := response
	var provider_id := provider.get_instance_id()
	var source_id: int = source.get_instance_id()
	var attack_key := "%d:projectile:%d" % [source_id, packet.epoch]
	var observe := func(event: Dictionary):
		if event.get("actor_id") != provider_id or event.get("generation") != generation: return
		if response_at_contact == Response.DEFENDED_ATTACK:
			if event.get("attack_key") != attack_key: return
		elif event.get("source_id") != source_id or event.get("serial") != packet.epoch or event.get("cause") != &"physical_cargo_contact": return
		completed.append(event.duplicate(true))
	health.damage_processed.connect(observe)
	var result: Dictionary
	if response == Response.DEFENDED_ATTACK:
		var attack := packet.duplicate()
		attack.merge({"attack_id": packet.epoch, "carrier": source, "kind": &"projectile", "source_position": packet.origin,
			"counterable": false, "reflectable": false, "physical_contact_authority": self}, true)
		attack.make_read_only()
		_attack_scope = {"attack": attack, "source": source, "packet": packet, "binding": binding, "generation": generation}
		result = host.receive_attack(attack)
		_attack_scope.clear()
	else:
		host.apply_impulse(packet.impulse, packet.stun_seconds)
		if not _current(source, packet, binding, generation):
			if is_instance_valid(health) and health.damage_processed.is_connected(observe): health.damage_processed.disconnect(observe)
			return {"accepted": false, "retired": true, "reason": &"retired_during_motion"}
		if float(packet.hitpause) > 0.0:
			host.apply_pause(packet.hitpause)
			if not _current(source, packet, binding, generation):
				if is_instance_valid(health) and health.damage_processed.is_connected(observe): health.damage_processed.disconnect(observe)
				return {"accepted": false, "retired": true, "reason": &"retired_during_pause"}
		var damage := {"actor_id": provider.get_instance_id(), "generation": generation, "serial": packet.epoch,
			"source_id": source.get_instance_id(), "outcome": &"hurt", "amount": packet.amount, "cause": &"physical_cargo_contact"}
		damage.make_read_only()
		provider.damage_resolved.emit(damage)
		result = {"consumed": true, "outcome": &"hurt", "residual_damage": packet.amount, "hurt_applied": true}
	if is_instance_valid(health) and health.damage_processed.is_connected(observe): health.damage_processed.disconnect(observe)
	# Ordinary NPC defeat disables its provider and advances its generation.
	# A matching completed lethal debit permits value-only outcome reporting;
	# this exception authorizes no additional health/motion/source effect.
	if binding != _binding or not _same_world(provider) or not _same_world(host) or not _same_world(health) \
		or _health() != health or health.get_bound_actor() != provider or not _same_world(source):
		return {"accepted": false, "retired": true, "reason": &"retired_during_response"}
	var terminal: bool = not completed.is_empty() and float(completed[0].get("after", -1)) == 0.0 \
		and float(completed[0].get("applied", 0)) > 0.0 and float(completed[0].get("before", 0)) > 0.0 and health.current_health == 0.0
	var final_generation: int = provider.damage_generation()
	if final_generation != generation and not (terminal and final_generation == generation + 1):
		return {"accepted": false, "retired": true, "reason": &"retired_during_response"}
	var source_current: bool = source.physical_impact_is_current(packet, host)
	# Custom source queries may call out. Recheck AFTER the last such query.
	if not source_current or binding != _binding or not _same_world(provider) or not _same_world(host) \
		or not _same_world(health) or not _same_world(source) or _health() != health or health.get_bound_actor() != provider \
		or int(provider.damage_generation()) != final_generation or (terminal and health.current_health != 0.0):
		return {"accepted": false, "retired": true, "reason": &"retired_during_response"}
	var receipt := {"accepted": bool(result.get("consumed", false)), "outcome": result.get("outcome", &"rejected"),
		"amount": float(completed[0].get("applied", 0.0)) if not completed.is_empty() else 0.0,
		"residual_damage": float(result.get("residual_damage", 0.0)), "source_id": source.get_instance_id() if is_instance_valid(source) else 0,
		"host_id": host.get_instance_id() if is_instance_valid(host) else 0, "epoch": packet.epoch,
		"target_generation": final_generation, "receiver_binding": binding,
		"contact_position": packet.contact_position, "normal_speed": packet.normal_speed, "impulse": packet.impulse,
		"source_contact_velocity": packet.source_contact_velocity, "target_contact_velocity": packet.target_contact_velocity,
		"physics_frame": packet.physics_frame}
	if binding != _binding: return receipt
	if receipt.accepted: accepted_count += 1
	last_reason = &"resolved" if receipt.accepted else &"host_rejected"
	receipt.make_read_only()
	_last_receipt = receipt.duplicate(true)
	impact_resolved.emit(receipt)
	return receipt
