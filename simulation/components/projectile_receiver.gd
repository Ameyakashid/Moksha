extends Node
## Real-body projectile admission, outbound and reflected. No extra hurtbox,
## clocks, health assignment, recoil solver, or legacy damage fallback.
signal projectile_resolved(receipt: Dictionary)
const REGISTRATION: StringName = &"_moksha_projectile_receiver"
const HISTORY: StringName = &"_moksha_projectile_history"
class PauseFence extends Node:
	var invalidate: Callable
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_PAUSED,NOTIFICATION_UNPAUSED] and invalidate.is_valid(): invalidate.call()
## Zero admits any genuine owner. Collision is never disabled by this filter.
@export_flags_2d_physics var accepted_source_layers := 0:
	set(value):
		if accepted_source_layers == value: return
		accepted_source_layers = value
		invalidate_generation()
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		invalidate_generation()
var accepted_count := 0
var rejected_count := 0
var last_receipt: Dictionary:
	get: return _last_receipt.duplicate(true)
var _last_receipt: Dictionary = {}
var _host_ref: WeakRef
var _health_ref: WeakRef
var _body_ref: WeakRef
var _binding := 0
var _consuming := false
var _history: Dictionary = {}
var _pause_fence: Node
var _reject_through_frame := -1
func _ready() -> void:
	var fence := PauseFence.new()
	fence.name = "PauseFence"
	fence.process_mode = Node.PROCESS_MODE_PAUSABLE
	fence.invalidate = invalidate_generation
	_pause_fence = fence
	add_child(fence)
	var host := get_parent()
	if host.is_node_ready(): bind(host)
	else: host.ready.connect(func(): bind(host),CONNECT_ONE_SHOT)
func _exit_tree() -> void: unbind()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED,NOTIFICATION_UNPAUSED,NOTIFICATION_DISABLED,NOTIFICATION_ENABLED]: invalidate_generation()
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
func get_bound_actor() -> Node2D: return _host_ref.get_ref() as Node2D if _host_ref != null else null
func _health() -> Node: return _health_ref.get_ref() as Node if _health_ref != null else null
func _body() -> CollisionShape2D: return _body_ref.get_ref() as CollisionShape2D if _body_ref != null else null
static func registered(host: Variant) -> Node:
	if not is_instance_valid(host) or not host is Node: return null
	var ref: Variant = host.get_meta(REGISTRATION) if host.has_meta(REGISTRATION) else null
	var receiver: Variant = ref.get_ref() if ref is WeakRef else null
	return receiver if is_instance_valid(receiver) and receiver is Node and receiver.is_inside_tree() and not receiver.is_queued_for_deletion() and receiver.has_method("get_bound_actor") and receiver.get_bound_actor() == host else null
func bind(host: Node) -> bool:
	if not _live(host) or not host is CharacterBody2D or get_parent() != host or not host.has_method("receive_attack"): return false
	var health := host.get_node_or_null("Health")
	var body := host.get_node_or_null("BodyShape") as CollisionShape2D
	if not _live(health) or not health is MokshaHealthComponent or health.get_bound_actor() != host or not _live(body) or body.shape == null: return false
	var old := registered(host)
	if old != null and old != self: return false
	if get_bound_actor() == host and _health() == health and _body() == body: return true
	unbind()
	_host_ref = weakref(host)
	_health_ref = weakref(health)
	_body_ref = weakref(body)
	_history = host.get_meta(HISTORY,{})
	host.set_meta(HISTORY,_history)
	host.set_meta(REGISTRATION,weakref(self))
	host.movement_event.connect(_on_actor_event)
	return true
func unbind() -> void:
	invalidate_generation()
	var host := get_bound_actor()
	if is_instance_valid(host):
		if host.movement_event.is_connected(_on_actor_event): host.movement_event.disconnect(_on_actor_event)
		if registered(host) == self: host.remove_meta(REGISTRATION)
	_host_ref = null
	_health_ref = null
	_body_ref = null
	_history = {}
func invalidate_generation() -> void:
	_binding += 1
	_reject_through_frame = Engine.get_physics_frames()
func _on_actor_event(kind: StringName,_packet: Dictionary) -> void:
	if kind == &"reset": invalidate_generation()
func _structural() -> bool:
	var host := get_bound_actor()
	var health := _health()
	var body := _body()
	return _live(self) and enabled and _live(host) and get_parent() == host and registered(host) == self \
		and _live(health) and host.get_node_or_null("Health") == health and health.get_bound_actor() == host \
		and _live(body) and host.get_node_or_null("BodyShape") == body and body.get_parent() == host and body.shape != null and not body.disabled \
		and _live(_pause_fence) and _pause_fence.get_parent() == self and _pause_fence.process_mode == Node.PROCESS_MODE_PAUSABLE \
		and can_process() and host.can_process() and host.is_physics_processing() and not get_tree().paused and host.collision_layer != 0
func capture_projectile_generation() -> Dictionary:
	if not _structural() or Engine.get_physics_frames() <= _reject_through_frame or _health().current_health <= 0 or get_bound_actor().is_defeated(): return {}
	var body := _body()
	var token := {"binding":_binding,"host_id":get_bound_actor().get_instance_id(),"generation":get_bound_actor().damage_generation(),
		"accepted_source_layers":accepted_source_layers,"body":body,"shape":body.shape,"rect":body.shape.get_rect(),"transform":body.global_transform,"layer":get_bound_actor().collision_layer,"world":get_bound_actor().get_world_2d()}
	token.make_read_only()
	return token
func projectile_generation_is_current(token: Dictionary) -> bool: return _generation_current(token)
func _generation_current(token: Dictionary) -> bool:
	return _structural() and token.get("binding") == _binding and token.get("host_id") == get_bound_actor().get_instance_id() and token.get("generation") == get_bound_actor().damage_generation() \
		and token.get("body") == _body() and token.get("shape") == _body().shape and token.get("rect") == _body().shape.get_rect() and token.get("transform") == _body().global_transform \
		and token.get("accepted_source_layers") == accepted_source_layers and token.get("layer") == get_bound_actor().collision_layer and token.get("world") == get_bound_actor().get_world_2d()
func _reject(reason: StringName) -> Dictionary:
	rejected_count += 1
	return {"accepted":false,"reason":reason}
func receive_projectile(packet: Dictionary) -> Dictionary:
	if _consuming: return _reject(&"reentrant")
	if not _structural() or Engine.get_physics_frames() <= _reject_through_frame or _health().current_health <= 0 or get_bound_actor().is_defeated(): return _reject(&"unavailable")
	for field in ["contact_ticket","attack_id","contact_epoch","source_epoch","collider_shape","source_body_layer"]:
		if not packet.get(field) is int or int(packet[field]) < 0: return _reject(&"invalid_identity")
	for field in ["origin","contact_position","incoming_velocity","impulse"]:
		if not packet.get(field) is Vector2 or not Vector2(packet[field]).is_finite(): return _reject(&"invalid_vector")
	if not packet.get("damage") is float or not is_finite(packet.damage) or packet.damage < 0 or not packet.get("receiver_generation") is Dictionary: return _reject(&"invalid_damage")
	var carrier: Variant = packet.get("carrier")
	if not _live(carrier) or not carrier is MokshaSharedProjectile or not carrier.has_method("claim_contact") or carrier.get_world_2d() != get_bound_actor().get_world_2d(): return _reject(&"invalid_carrier")
	_consuming = true
	var result := _consume(packet,carrier)
	_consuming = false
	return result
func _consume(packet: Dictionary, carrier: Node) -> Dictionary:
	if packet.target != get_bound_actor() or packet.receiver != self or not _generation_current(packet.receiver_generation) or not carrier.contact_is_current(packet,self): return _reject(&"stale_contact")
	var host := get_bound_actor()
	var owner_id: int = host.shape_find_owner(packet.collider_shape)
	if host.shape_owner_get_owner(owner_id) != _body(): return _reject(&"wrong_body_shape")
	var id := carrier.get_instance_id()
	for key in _history.keys():
		if not is_instance_valid(_history[key].carrier.get_ref()): _history.erase(key)
	if _history.has(id) and int(_history[id].attack_id) >= packet.attack_id: return _reject(&"duplicate")
	if _history.size() >= 128: return _reject(&"history_capacity")
	if not carrier.claim_contact(packet,self): return _reject(&"spent_contact")
	if not carrier.contact_source_is_current(packet): return _reject(&"retired_claim")
	# The last virtual source hook may retire this target after returning true.
	if not _generation_current(packet.receiver_generation): return _reject(&"retired_claim")
	# Final local read after every extension hook: owner identity/layers come
	# from the genuine current sweep, never from a role label or caller claim.
	if accepted_source_layers != packet.receiver_generation.get("accepted_source_layers"): return _reject(&"retired_filter")
	if not is_instance_valid(packet.source) or not packet.source is CollisionObject2D or not packet.source.is_inside_tree() or packet.source.is_queued_for_deletion() or packet.source.get_world_2d() != host.get_world_2d() or packet.source.collision_layer != packet.source_body_layer: return _reject(&"retired_source_layers")
	if carrier.attack_owner == null or carrier.attack_owner.get_ref() != packet.source or carrier.attack_id != packet.attack_id or carrier.reflected != packet.reflected: return _reject(&"retired_owner")
	if accepted_source_layers != 0 and (packet.source_body_layer & accepted_source_layers) == 0:
		return {"accepted":false,"intercepted":true,"reason":&"source_layer_filtered","carrier_id":id,"host_id":host.get_instance_id(),"attack_id":packet.attack_id,"reflected":packet.reflected}
	var health := _health()
	var generation: int = host.damage_generation()
	var key := "%d:projectile:%d" % [id,packet.attack_id]
	var completed: Array[Dictionary] = []
	var observe := func(receipt: Dictionary):
		if receipt.get("actor_id") == host.get_instance_id() and receipt.get("generation") == generation and receipt.get("attack_key") == key: completed.append(receipt.duplicate(true))
	health.damage_processed.connect(observe)
	_history[id] = {"carrier":weakref(carrier),"attack_id":packet.attack_id}
	var attack := {"attack_id":packet.attack_id,"source":packet.source,"carrier":carrier,"kind":&"projectile","origin":packet.origin,"source_position":packet.origin,
		"contact_position":packet.contact_position,"incoming_velocity":packet.incoming_velocity,"amount":packet.damage,"impulse":packet.impulse,
		"blockable":packet.blockable,"parryable":packet.parryable,"rollable":packet.rollable,"reflectable":packet.reflectable,"counterable":false}
	if packet.stun_seconds >= 0: attack.stun_seconds = packet.stun_seconds
	var result: Dictionary = host.receive_attack(attack)
	if is_instance_valid(health) and health.damage_processed.is_connected(observe): health.damage_processed.disconnect(observe)
	var receipt := {"accepted":bool(result.get("consumed",false)) and not completed.is_empty(),"outcome":result.get("outcome",&"rejected"),
		"amount":float(completed[0].applied) if not completed.is_empty() else 0.0,"reflection_confirmed":bool(result.get("reflection_confirmed",false)),
		"carrier_id":id,"attack_id":packet.attack_id,"host_id":host.get_instance_id(),"generation":generation,"reflected":packet.reflected,
		"origin":packet.origin,"contact_position":packet.contact_position,"physics_frame":Engine.get_physics_frames()}
	# Completed facts survive source retirement and lethal defeat. New-life or
	# replacement components do not receive old-life notifications.
	var current := _generation_current(packet.receiver_generation) and _health() == health
	receipt["retired"] = not current or not is_instance_valid(carrier) or carrier._retired
	receipt.make_read_only()
	if current:
		if receipt.accepted: accepted_count += 1
		_last_receipt = receipt.duplicate(true)
		projectile_resolved.emit(receipt)
	return receipt
