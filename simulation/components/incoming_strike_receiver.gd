extends Area2D
## Detachable real-contact bridge. The controller owns defense and recoil;
## Health observes its receipts. This node never assigns motion or health.
signal strike_resolved(receipt: Dictionary)
const REGISTRATION: StringName = &"_moksha_incoming_strike_receiver"
const HISTORY: StringName = &"_moksha_incoming_strike_history"
const SOURCE_LIMIT := 64
class PauseFence extends Node:
	var retire: Callable
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and retire.is_valid(): retire.call()
class StrikeHistory extends RefCounted:
	var sources: Array[Dictionary] = []
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		invalidate_generation()
@export var blockable := true:
	set(value):
		if blockable == value: return
		blockable = value
		invalidate_generation()
@export var parryable := true:
	set(value):
		if parryable == value: return
		parryable = value
		invalidate_generation()
@export var counterable := false:
	set(value):
		if counterable == value: return
		counterable = value
		invalidate_generation()
@export var rollable := true:
	set(value):
		if rollable == value: return
		rollable = value
		invalidate_generation()
var accepted_count := 0
var rejected_count := 0
var last_reason: StringName = &"unbound"
var last_receipt: Dictionary:
	get: return _last_receipt.duplicate(true)
var _last_receipt: Dictionary = {}
var _host_ref: WeakRef
var _health_ref: WeakRef
var _body_ref: WeakRef
var _history: StrikeHistory
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
	monitoring = false
	monitorable = true
	var host := get_parent().get_parent()
	if host.is_node_ready(): bind(host)
	else: host.ready.connect(func(): bind(host), CONNECT_ONE_SHOT)
func _exit_tree() -> void: unbind()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: invalidate_generation()
func _host() -> Node2D: return _host_ref.get_ref() as Node2D if _host_ref != null else null
func _health() -> Node: return _health_ref.get_ref() as Node if _health_ref != null else null
func _body() -> CollisionShape2D: return _body_ref.get_ref() as CollisionShape2D if _body_ref != null else null
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
func _same_world(node: Variant) -> bool:
	return _live(self) and _live(node) and node.get_viewport().world_2d == get_world_2d()
static func registered(host: Node) -> Node:
	if not is_instance_valid(host) or not host.has_meta(REGISTRATION): return null
	var reference: Variant = host.get_meta(REGISTRATION)
	if not reference is WeakRef: return null
	var receiver: Variant = reference.get_ref()
	if not is_instance_valid(receiver) or not receiver is Area2D or not receiver.is_inside_tree() or receiver.is_queued_for_deletion(): return null
	return receiver if receiver.has_method("_host") and receiver._host() == host else null
func bind(host: Node) -> bool:
	var body := get_parent() as CollisionShape2D
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if not _live(shape): return false
	var health := host.get_node_or_null("Health") if is_instance_valid(host) else null
	if not host is CharacterBody2D or not _same_world(host) or not _same_world(body) or not _same_world(health): return false
	if body.get_parent() != host or host.get_node_or_null("BodyShape") != body or not body.shape is RectangleShape2D: return false
	if not health is MokshaHealthComponent or health.get_bound_actor() != host or not host.has_method("receive_attack"): return false
	if not host.has_method("damage_generation") or not host.has_signal("movement_event"): return false
	var current := registered(host)
	if current != null and current != self: return false
	if _host() == host and _body() == body and _health() == health: return true
	unbind()
	_host_ref = weakref(host)
	_body_ref = weakref(body)
	_health_ref = weakref(health)
	var retained: Variant = host.get_meta(HISTORY) if host.has_meta(HISTORY) else null
	_history = retained if retained is StrikeHistory else StrikeHistory.new()
	host.set_meta(HISTORY, _history)
	host.set_meta(REGISTRATION, weakref(self))
	transform = Transform2D.IDENTITY
	shape.transform = Transform2D.IDENTITY
	shape.shape = body.shape
	host.movement_event.connect(_on_actor_event)
	last_reason = &"ready"
	return true
func unbind() -> void:
	invalidate_generation()
	var host := _host()
	if is_instance_valid(host):
		if host.movement_event.is_connected(_on_actor_event): host.movement_event.disconnect(_on_actor_event)
		if registered(host) == self: host.remove_meta(REGISTRATION)
	_host_ref = null
	_health_ref = null
	_body_ref = null
	_history = null
	last_reason = &"unbound"
func invalidate_generation() -> void:
	_binding += 1
	_reject_through_frame = Engine.get_physics_frames()
func _on_actor_event(kind: StringName, _payload: Dictionary) -> void:
	if kind == &"reset": invalidate_generation()
func _structural() -> bool:
	var host := _host()
	var health := _health()
	var body := _body()
	var shape := get_node_or_null("Shape") as CollisionShape2D
	return _live(_pause_fence) and _pause_fence.get_parent() == self and _pause_fence.process_mode == Node.PROCESS_MODE_PAUSABLE \
		and _live(shape) and shape.get_parent() == self and enabled and _same_world(host) and _same_world(health) and _same_world(body) and registered(host) == self \
		and host.get_node_or_null("BodyShape") == body and get_parent() == body and body.get_parent() == host \
		and not body.disabled and body.shape != null and shape.shape == body.shape and not shape.disabled \
		and transform == Transform2D.IDENTITY and shape.transform == Transform2D.IDENTITY \
		and can_process() and host.can_process() and host.is_physics_processing() and not get_tree().paused \
		and collision_layer != 0 and host.collision_layer != 0 and health.get_bound_actor() == host
func _eligible() -> bool:
	return _structural() and Engine.get_physics_frames() > _reject_through_frame and _health().current_health > 0 and not _host().is_defeated()
func capture_strike_generation() -> Dictionary:
	if not _eligible(): return {}
	var token := {"binding": _binding, "host_generation": _host().damage_generation(), "host_id": _host().get_instance_id(),
		"body_layer": _host().collision_layer, "hurtbox_layer": collision_layer}
	token.make_read_only()
	return token
func strike_generation_is_current(token: Dictionary) -> bool:
	return _strike_generation_state_current(token)
func _strike_generation_state_current(token: Dictionary) -> bool:
	return _structural() and token.get("binding") == _binding and token.get("host_generation") == _host().damage_generation() \
		and token.get("host_id") == _host().get_instance_id() and token.get("body_layer") == _host().collision_layer and token.get("hurtbox_layer") == collision_layer
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
	var adapter: Variant = packet.get("contact_adapter")
	var source: Variant = packet.get("source")
	var token: Variant = packet.get("receiver_generation")
	if not token is Dictionary or not strike_generation_is_current(token) or not _same_world(source) or source == _host(): return false
	if not _same_world(adapter) or not adapter is MokshaContactAdapter or not source.is_ancestor_of(adapter) or adapter.actor != source: return false
	var current: bool = adapter.contact_is_current(packet, self)
	return current and _same_world(source) and _same_world(adapter) and strike_generation_is_current(token)
func receive_strike(packet: Dictionary) -> Dictionary:
	if _consuming: return _reject(&"reentrant")
	if not _eligible(): return _reject(&"unavailable")
	for key in ["serial", "source_epoch", "contact_ticket"]:
		if not packet.get(key) is int or int(packet[key]) < (0 if key == "source_epoch" else 1): return _reject(&"invalid_identity")
	for key in ["origin", "source_position", "contact_position", "impulse"]:
		if not packet.get(key) is Vector2 or not Vector2(packet[key]).is_finite(): return _reject(&"invalid_vector")
	var amount: Variant = packet.get("damage")
	if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0: return _reject(&"invalid_damage")
	_consuming = true
	var result := _consume(packet)
	_consuming = false
	return result
func _consume(packet: Dictionary) -> Dictionary:
	if not _permit_current(packet): return _reject(&"stale_contact")
	var source: Node2D = packet.source
	var serial: int = packet.serial
	var index := _source_index(source)
	if index >= 0 and int(_history.sources[index].serial) >= serial: return _reject(&"duplicate")
	if index < 0 and _history.sources.size() >= SOURCE_LIMIT: return _reject(&"source_capacity")
	var host := _host()
	var health := _health()
	var generation: int = host.damage_generation()
	var key := "%d:melee:%d" % [source.get_instance_id(), serial]
	var completed: Array[Dictionary] = []
	var observe := func(event: Dictionary):
		if event.get("actor_id") == host.get_instance_id() and event.get("generation") == generation and event.get("attack_key") == key: completed.append(event.duplicate(true))
	health.damage_processed.connect(observe)
	# Identity is retained on the actor before committing the one host operation.
	var consumed := {"source": weakref(source), "serial": serial}
	if index < 0: _history.sources.append(consumed)
	else: _history.sources[index] = consumed
	var attack := {"attack_id": serial, "source": source, "kind": &"melee", "origin": packet.source_position,
		"source_position": packet.source_position, "contact_position": packet.contact_position, "incoming_velocity": Vector2.ZERO,
		"amount": packet.damage, "impulse": packet.impulse, "blockable": blockable, "parryable": parryable,
		"rollable": rollable, "counterable": counterable, "reflectable": false}
	var result: Dictionary = host.receive_attack(attack)
	if is_instance_valid(health) and health.damage_processed.is_connected(observe): health.damage_processed.disconnect(observe)
	# Dispatch commits one controller response. Retirement cannot roll it back;
	# target reset/removal is separately fenced by receive_attack itself.
	var current_contact := _permit_current(packet)
	var completed_counter_parry: bool = result.get("outcome") == &"parried" and bool(result.get("counter_confirmed", false)) and not completed.is_empty() \
		and packet.contact_adapter.contact_receipt_is_current(packet, self)
	# Both public validation paths can run hooks. The final local target-state
	# check must follow them, without invoking either hook again.
	if (not current_contact and not completed_counter_parry) or _host() != host or _health() != health or not _strike_generation_state_current(packet.receiver_generation):
		return {"accepted": bool(result.get("consumed", false)), "retired": true, "reason": &"retired_during_response"}
	var receipt := {"accepted": bool(result.get("consumed", false)), "outcome": result.get("outcome", &"rejected"),
		"amount": float(completed[0].get("applied", 0.0)) if not completed.is_empty() else 0.0,
		"counter_confirmed": bool(result.get("counter_confirmed", false)), "residual_damage": float(result.get("residual_damage", 0.0)), "source_id": source.get_instance_id(),
		"host_id": host.get_instance_id(), "source_epoch": packet.source_epoch, "serial": serial,
		"contact_position": packet.contact_position, "origin": packet.source_position, "impulse": packet.impulse,
		"physics_frame": Engine.get_physics_frames()}
	if receipt.accepted: accepted_count += 1
	last_reason = &"resolved" if receipt.accepted else &"host_rejected"
	receipt.make_read_only()
	_last_receipt = receipt.duplicate(true)
	strike_resolved.emit(receipt)
	return receipt
