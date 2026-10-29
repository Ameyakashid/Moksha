extends Node
## Detachable counter admission. Existing controller/Health own every consequence.
signal counter_resolved(receipt: Dictionary)
const StrikeReceiver = preload("res://simulation/components/incoming_strike_receiver.gd")
const REGISTRATION: StringName = &"_moksha_shield_counter_receiver"
const HISTORY: StringName = &"_moksha_shield_counter_history"
const SOURCE_LIMIT := 64
class CounterHistory extends RefCounted:
	var sources: Array[Dictionary] = []
class PauseFence extends Node:
	var retire: Callable
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and retire.is_valid(): retire.call()
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		invalidate_generation()
## -1 omits the override and preserves the actor's ordinary hurt duration.
## This target capability is usable only after the canonical ray/one-use claim.
@export_range(-1.0, 5.0, 0.01) var response_stun_seconds := -1.0:
	set(value):
		if response_stun_seconds == value: return
		response_stun_seconds = value
		invalidate_generation()
var accepted_count := 0
var rejected_count := 0
var last_reason: StringName = &"unbound"
var last_receipt: Dictionary:
	get: return _last_receipt.duplicate(true)
var _last_receipt: Dictionary = {}
var _host_ref: WeakRef
var _health_ref: WeakRef
var _hurtbox_ref: WeakRef
var _history: CounterHistory
var _binding := 0
var _consuming := false
var _reject_through_frame := -1
var _pause_fence: Node
func _ready() -> void:
	var fence := PauseFence.new()
	_pause_fence = fence
	fence.name = "PauseFence"
	fence.process_mode = Node.PROCESS_MODE_PAUSABLE
	fence.retire = invalidate_generation
	add_child(fence)
	var host := get_parent()
	if host.is_node_ready(): bind(host)
	else: host.ready.connect(func(): bind(host), CONNECT_ONE_SHOT)
func _exit_tree() -> void: unbind()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: invalidate_generation()
func get_bound_actor() -> Node2D: return _host_ref.get_ref() as Node2D if _host_ref != null else null
func _health() -> Node: return _health_ref.get_ref() as Node if _health_ref != null else null
func _hurtbox() -> Area2D: return _hurtbox_ref.get_ref() as Area2D if _hurtbox_ref != null else null
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
static func registered(host: Node) -> Node:
	if not is_instance_valid(host) or not host.has_meta(REGISTRATION): return null
	var reference: Variant = host.get_meta(REGISTRATION)
	var receiver: Variant = reference.get_ref() if reference is WeakRef else null
	if not is_instance_valid(receiver) or not receiver is Node or not receiver.is_inside_tree() or receiver.is_queued_for_deletion(): return null
	return receiver if receiver.has_method("get_bound_actor") and receiver.get_bound_actor() == host else null
func bind(host: Node) -> bool:
	if not _live(self) or not _live(host) or not host is CharacterBody2D or get_parent() != host: return false
	var health := host.get_node_or_null("Health")
	var hurtbox := StrikeReceiver.registered(host)
	if not _live(health) or not health is MokshaHealthComponent or health.get_bound_actor() != host or not _live(hurtbox): return false
	if not host.has_method("receive_attack") or not host.has_method("damage_generation") or not host.has_signal("movement_event"): return false
	var existing := registered(host)
	if existing != null and existing != self: return false
	if get_bound_actor() == host and _health() == health and _hurtbox() == hurtbox: return true
	unbind()
	_host_ref = weakref(host)
	_health_ref = weakref(health)
	_hurtbox_ref = weakref(hurtbox)
	var retained: Variant = host.get_meta(HISTORY) if host.has_meta(HISTORY) else null
	_history = retained if retained is CounterHistory else CounterHistory.new()
	host.set_meta(HISTORY, _history)
	host.set_meta(REGISTRATION, weakref(self))
	host.movement_event.connect(_on_actor_event)
	last_reason = &"ready"
	return true
func unbind() -> void:
	invalidate_generation()
	var host := get_bound_actor()
	if is_instance_valid(host):
		if host.movement_event.is_connected(_on_actor_event): host.movement_event.disconnect(_on_actor_event)
		if registered(host) == self: host.remove_meta(REGISTRATION)
	_host_ref = null
	_health_ref = null
	_hurtbox_ref = null
	_history = null
	last_reason = &"unbound"
func invalidate_generation() -> void:
	_binding += 1
	_reject_through_frame = Engine.get_physics_frames()
func _on_actor_event(kind: StringName, _payload: Dictionary) -> void:
	if kind == &"reset": invalidate_generation()
func _response_config_valid() -> bool:
	return is_finite(response_stun_seconds) and (response_stun_seconds == -1.0 or (response_stun_seconds >= 0.0 and response_stun_seconds <= 5.0))
func _local_generation_current(token: Dictionary) -> bool:
	return _structural() and token.get("binding") == _binding and token.get("host_id") == get_bound_actor().get_instance_id() \
		and token.get("host_generation") == get_bound_actor().damage_generation() and token.get("response_stun_seconds") == response_stun_seconds
func _captured_target_state_current(token: Dictionary) -> bool:
	# Deliberately no public validation hook: the final source callback has
	# already run. A replaced/toggled incoming binding cannot borrow its claim.
	if not _local_generation_current(token) or token.get("hurtbox") != _hurtbox() or not token.get("incoming") is Dictionary: return false
	var incoming: Dictionary = token.incoming
	var host := get_bound_actor()
	if incoming.get("binding") != _hurtbox().get("_binding") or not _hurtbox()._structural(): return false
	if incoming.get("host_id") != host.get_instance_id() or incoming.get("host_generation") != host.damage_generation(): return false
	if incoming.get("body_layer") != host.collision_layer or incoming.get("hurtbox_layer") != _hurtbox().collision_layer: return false
	var shape := _hurtbox().get_node_or_null("Shape") as CollisionShape2D
	return _live(shape) and token.get("shape") == shape.shape and token.get("shape_rect") == shape.shape.get_rect() and token.get("transform") == _hurtbox().global_transform
func _claimed_source_state_current(packet: Dictionary) -> bool:
	# Final non-callback reads mirror the adapter/controller's current scope.
	# Repeating the public source validator would allow another stale return.
	var adapter: Variant = packet.get("counter_adapter")
	var defender: Variant = packet.get("defender")
	var host := get_bound_actor()
	if not _live(adapter) or not adapter is MokshaShieldContactAdapter or not _live(defender) or not defender is Node2D: return false
	if not adapter.enabled or not adapter.can_process() or get_tree().paused: return false
	if adapter.actor != defender or not defender.is_ancestor_of(adapter) or not defender.can_process() or not defender.is_physics_processing(): return false
	if adapter.get_world_2d() != host.get_world_2d() or defender.get_world_2d() != host.get_world_2d(): return false
	var fence: Variant = adapter.get("_pause_fence")
	if not _live(fence) or fence.get_parent() != adapter or fence.process_mode != Node.PROCESS_MODE_PAUSABLE: return false
	var delivery: Dictionary = adapter.get("_delivery_scope")
	if not bool(adapter.get("_resolving")) or delivery.is_empty() or not bool(delivery.get("claimed", false)): return false
	if delivery.get("binding") != adapter.get("_binding") or delivery.get("counter_ticket") != packet.counter_ticket: return false
	if delivery.get("counter_receiver") != self or delivery.get("counter_target") != host or delivery.get("defender") != defender: return false
	for field in MokshaShieldContactAdapter.PERMIT_FIELDS:
		if delivery.get(field) != packet.get(field): return false
	if defender.get("_reset_epoch") != packet.defender_epoch or defender.get("_defeat_owner") != null: return false
	var scope_value: Variant = defender.get("_shield_effect_scope")
	if not scope_value is Dictionary: return false
	var scope: Dictionary = scope_value
	if scope.is_empty() or bool(scope.get("confirmed", false)): return false
	if scope.get("serial") != packet.shield_serial or scope.get("key") != packet.attack_key or scope.get("effect") != &"counter": return false
	if scope.get("target_id") != host.get_instance_id() or not scope.get("target") is WeakRef or scope.target.get_ref() != host: return false
	if scope.get("action_generation") != defender.get("_action_generation") or scope.get("weapon_generation") != defender.get("_weapon_generation"): return false
	var capabilities: Variant = defender.get("_capabilities")
	var permissions: Variant = defender.get("_external_weapon_permissions")
	if not capabilities is Dictionary or not permissions is Dictionary: return false
	return defender.get("shield_phase") != &"idle" and bool(defender.get("allow_shield")) and bool(capabilities.get("can_shield", false)) and bool(permissions.get("can_shield", false))
func _structural() -> bool:
	var host := get_bound_actor()
	var health := _health()
	var hurtbox := _hurtbox()
	return _live(self) and _live(_pause_fence) and _pause_fence.get_parent() == self and _pause_fence.process_mode == Node.PROCESS_MODE_PAUSABLE \
		and enabled and _response_config_valid() and _live(host) and _live(health) and _live(hurtbox) and get_parent() == host and registered(host) == self \
		and StrikeReceiver.registered(host) == hurtbox and host.get_node_or_null("Health") == health and health.get_bound_actor() == host \
		and can_process() and host.can_process() and host.is_physics_processing() and not get_tree().paused
func capture_counter_generation() -> Dictionary:
	if not _structural() or Engine.get_physics_frames() <= _reject_through_frame or _health().current_health <= 0 or get_bound_actor().is_defeated(): return {}
	var incoming: Dictionary = _hurtbox().capture_strike_generation()
	if incoming.is_empty() or not _structural(): return {}
	var shape := _hurtbox().get_node("Shape") as CollisionShape2D
	var token := {"binding": _binding, "host_id": get_bound_actor().get_instance_id(), "host_generation": get_bound_actor().damage_generation(), "incoming": incoming,
		"response_stun_seconds": response_stun_seconds, "hurtbox": _hurtbox(), "shape": shape.shape, "shape_rect": shape.shape.get_rect(), "transform": _hurtbox().global_transform}
	token.make_read_only()
	return token
func counter_generation_is_current(token: Dictionary) -> bool:
	return _generation_state_current(token)
func _generation_state_current(token: Dictionary) -> bool:
	if not _local_generation_current(token): return false
	if token.get("hurtbox") != _hurtbox() or not token.get("incoming") is Dictionary or not _hurtbox().strike_generation_is_current(token.incoming): return false
	# The public incoming validator is an extension hook. It may return a
	# pre-callback true; reread both modules' stable binding state afterward.
	if not _local_generation_current(token): return false
	if token.get("hurtbox") != _hurtbox() or token.incoming.get("binding") != _hurtbox().get("_binding") or not _hurtbox()._structural(): return false
	if token.incoming.get("body_layer") != get_bound_actor().collision_layer or token.incoming.get("hurtbox_layer") != _hurtbox().collision_layer: return false
	var shape := _hurtbox().get_node_or_null("Shape") as CollisionShape2D
	return _live(shape) and token.get("shape") == shape.shape and token.get("shape_rect") == shape.shape.get_rect() and token.get("transform") == _hurtbox().global_transform
func get_counter_hurtbox() -> CollisionObject2D:
	return _hurtbox() if _structural() else null
func _source_index(source: Node) -> int:
	for index in range(_history.sources.size() - 1, -1, -1):
		if not is_instance_valid(_history.sources[index].source.get_ref()): _history.sources.remove_at(index)
	for index in _history.sources.size():
		if _history.sources[index].source.get_ref() == source: return index
	return -1
func _reject(reason: StringName) -> Dictionary:
	rejected_count += 1
	last_reason = reason
	return {"accepted": false, "reason": reason}
func _permit_current(packet: Dictionary) -> bool:
	var adapter: Variant = packet.get("counter_adapter")
	var defender: Variant = packet.get("defender")
	var token: Variant = packet.get("counter_generation")
	if not token is Dictionary or not counter_generation_is_current(token) or not _live(defender) or defender == get_bound_actor(): return false
	if not _live(adapter) or not adapter is MokshaShieldContactAdapter or not defender.is_ancestor_of(adapter) or adapter.actor != defender: return false
	if not adapter.counter_contact_is_current(packet, self): return false
	# No trailing virtual validation hook: its callback could retire the source
	# after the adapter had checked it. Recheck stable local ownership directly.
	return _generation_state_current(token) and adapter.counter_source_is_current(packet)
func receive_shield_counter(packet: Dictionary) -> Dictionary:
	if _consuming: return _reject(&"reentrant")
	if not _structural() or _health().current_health <= 0 or get_bound_actor().is_defeated() or Engine.get_physics_frames() <= _reject_through_frame: return _reject(&"unavailable")
	for field in ["shield_serial", "defender_epoch", "counter_ticket"]:
		if not packet.get(field) is int or int(packet[field]) < (0 if field == "defender_epoch" else 1): return _reject(&"invalid_identity")
	for field in ["defender_origin", "counter_contact_position", "impulse"]:
		if not packet.get(field) is Vector2 or not Vector2(packet[field]).is_finite(): return _reject(&"invalid_vector")
	var damage: Variant = packet.get("damage")
	if not (damage is float or damage is int) or not is_finite(float(damage)) or float(damage) < 0: return _reject(&"invalid_damage")
	_consuming = true
	var result := _consume(packet)
	_consuming = false
	return result
func _consume(packet: Dictionary) -> Dictionary:
	if not _permit_current(packet): return _reject(&"stale_contact")
	var defender: Node2D = packet.defender
	var serial: int = packet.shield_serial
	var index := _source_index(defender)
	if index >= 0 and int(_history.sources[index].serial) >= serial: return _reject(&"duplicate")
	if index < 0 and _history.sources.size() >= SOURCE_LIMIT: return _reject(&"source_capacity")
	if not packet.counter_adapter.claim_counter_contact(packet, self): return _reject(&"spent_contact")
	# A virtual receiver validation may mutate us after returning an earlier true.
	# Read our final state directly after the one-use claim, before committing.
	if not _generation_state_current(packet.counter_generation) or not packet.counter_adapter.counter_source_is_current(packet): return _reject(&"retired_claim")
	# Source validation is also a callback boundary. Reread local configuration
	# after it, so even an away-and-back setter change cannot borrow this claim.
	if not _captured_target_state_current(packet.counter_generation) or not _claimed_source_state_current(packet): return _reject(&"retired_claim")
	var host := get_bound_actor()
	var health := _health()
	var generation: int = host.damage_generation()
	var key := "%d:area:%d" % [defender.get_instance_id(), serial]
	var completed: Array[Dictionary] = []
	var observe := func(event: Dictionary):
		if event.get("actor_id") == host.get_instance_id() and event.get("generation") == generation and event.get("attack_key") == key: completed.append(event.duplicate(true))
	health.damage_processed.connect(observe)
	var consumed := {"source": weakref(defender), "serial": serial}
	if index < 0: _history.sources.append(consumed)
	else: _history.sources[index] = consumed
	var attack := {"attack_id": serial, "source": defender, "kind": &"area", "origin": packet.defender_origin,
		"source_position": packet.defender_origin, "contact_position": packet.counter_contact_position, "incoming_velocity": Vector2.ZERO,
		"amount": packet.damage, "impulse": packet.impulse, "blockable": false, "parryable": false, "rollable": false, "counterable": false, "reflectable": false}
	if response_stun_seconds >= 0.0: attack.stun_seconds = response_stun_seconds
	var result: Dictionary = host.receive_attack(attack)
	if is_instance_valid(health) and health.damage_processed.is_connected(observe): health.damage_processed.disconnect(observe)
	# One controller operation committed. No callback can roll it back. Reset,
	# removal and rebinding may suppress diagnostics; ordinary defeat may not.
	if not _permit_current(packet) or get_bound_actor() != host or _health() != health:
		return {"accepted": not completed.is_empty(), "retired": true, "reason": &"retired_during_response"}
	var receipt := {"accepted": bool(result.get("consumed", false)) and not completed.is_empty(), "outcome": result.get("outcome", &"rejected"),
		"amount": float(completed[0].get("applied", 0.0)) if not completed.is_empty() else 0.0, "host_id": host.get_instance_id(),
		"defender_id": defender.get_instance_id(), "defender_epoch": packet.defender_epoch, "shield_serial": serial, "attack_key": key,
		"incoming_attack_key": packet.attack_key, "contact_position": packet.counter_contact_position, "origin": packet.defender_origin,
		"impulse": packet.impulse, "physics_frame": Engine.get_physics_frames()}
	if receipt.accepted: accepted_count += 1
	last_reason = &"resolved" if receipt.accepted else &"host_rejected"
	receipt.make_read_only()
	_last_receipt = receipt.duplicate(true)
	counter_resolved.emit(receipt)
	# The just-emitted value is a completed fact. A receipt observer can retire
	# the target/bridge before adapter confirmation, which must stay separate.
	if not _permit_current(packet):
		return receipt.merged({"retired": true, "reason": &"retired_after_receipt"}, true)
	return receipt
