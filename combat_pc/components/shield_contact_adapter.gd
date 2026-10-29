class_name MokshaShieldContactAdapter
extends Node2D
## Actual synchronous counter ray / legacy reflection boundary. No response writes.
signal effect_resolved(report: Dictionary)
const COUNTER_REGISTRATION: StringName = &"_moksha_shield_counter_receiver"
const REQUEST_FIELDS := ["shield_serial", "attack_key", "effect", "source", "source_id", "carrier", "carrier_id", "target_id", "origin", "defender_origin", "incoming_origin", "contact_position", "facing", "normal", "damage", "impulse", "reflect_direction", "reflect_speed", "max_range"]
const PERMIT_FIELDS := ["shield_serial", "attack_key", "effect", "source", "source_id", "target_id", "origin", "defender_origin", "incoming_origin", "contact_position", "facing", "normal", "damage", "impulse", "max_range", "defender", "defender_id", "defender_epoch", "counter_target", "counter_receiver", "counter_generation", "counter_contact_position", "counter_ticket"]
class PauseFence extends Node:
	var retire: Callable
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and retire.is_valid(): retire.call()
@export var actor_path := NodePath("..")
@export_flags_2d_physics var obstruction_mask := 1:
	set(value):
		if obstruction_mask == value: return
		obstruction_mask = value
		_retire()
@export_range(1, 32, 1) var maximum_hurtbox_shapes := 16:
	set(value):
		if maximum_hurtbox_shapes == value: return
		maximum_hurtbox_shapes = value
		_retire()
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		_retire()
var actor: Node2D
var confirmed_counters := 0
var confirmed_reflections := 0
var rejected_effects := 0
var last_report: Dictionary = {}
var _binding := 0
var _resolving := false
var _ticket := 0
var _delivery_scope: Dictionary = {}
var _pause_fence: Node
func _ready() -> void:
	var fence := PauseFence.new()
	_pause_fence = fence
	fence.name = "PauseFence"
	fence.process_mode = Node.PROCESS_MODE_PAUSABLE
	fence.retire = _retire
	add_child(fence)
	bind_actor(get_node_or_null(actor_path))
func _exit_tree() -> void: bind_actor(null)
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: _retire()
func _retire() -> void:
	_binding += 1
	_delivery_scope.clear()
func _on_actor_event(kind: StringName, _payload: Dictionary) -> void:
	if kind == &"reset": _retire()
func bind_actor(value: Node2D) -> void:
	_retire()
	if is_instance_valid(actor):
		if actor.has_signal("shield_effect_requested") and actor.is_connected("shield_effect_requested", resolve_effect): actor.disconnect("shield_effect_requested", resolve_effect)
		if actor.has_signal("movement_event") and actor.is_connected("movement_event", _on_actor_event): actor.disconnect("movement_event", _on_actor_event)
	actor = value
	if is_instance_valid(actor):
		if actor.has_signal("shield_effect_requested"): actor.connect("shield_effect_requested", resolve_effect)
		if actor.has_signal("movement_event"): actor.connect("movement_event", _on_actor_event)
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
func _current(owner_actor: Variant, request: Dictionary) -> bool:
	return _live(self) and enabled and can_process() and not get_tree().paused and _live(_pause_fence) and _pause_fence.get_parent() == self and _pause_fence.process_mode == Node.PROCESS_MODE_PAUSABLE \
		and _live(owner_actor) and owner_actor == actor and owner_actor.is_ancestor_of(self) and owner_actor.can_process() and owner_actor.is_physics_processing() and owner_actor.get_world_2d() == get_world_2d() \
		and owner_actor.has_method("shield_effect_is_current") and owner_actor.shield_effect_is_current(int(request.get("shield_serial", -1)), String(request.get("attack_key", "")), StringName(request.get("effect", &"")))
func _registered(target: Node) -> Node:
	if not _live(target) or not target.has_meta(COUNTER_REGISTRATION): return null
	var reference: Variant = target.get_meta(COUNTER_REGISTRATION)
	var receiver: Variant = reference.get_ref() if reference is WeakRef else null
	if not _live(receiver) or not receiver.has_method("get_bound_actor") or receiver.get_bound_actor() != target: return null
	return receiver
func _canonical(owner_actor: Node, request: Dictionary) -> bool:
	if not owner_actor.has_method("shield_effect_snapshot"): return false
	var canonical: Dictionary = owner_actor.shield_effect_snapshot()
	if canonical.is_empty(): return false
	for key in REQUEST_FIELDS:
		if not request.has(key) or request[key] != canonical.get(key): return false
	return true
func _receiver_current(receiver: Node, target: Node, token: Dictionary) -> bool:
	return _live(target) and _registered(target) == receiver and _live(receiver) and receiver.has_method("counter_generation_is_current") and receiver.counter_generation_is_current(token)
func counter_contact_is_current(packet: Dictionary, receiver: Node) -> bool:
	if not _resolving or _delivery_scope.is_empty() or packet.get("counter_adapter") != self: return false
	for key in PERMIT_FIELDS:
		if packet.get(key) != _delivery_scope.get(key): return false
	if receiver != _delivery_scope.counter_receiver or _binding != _delivery_scope.binding: return false
	var defender: Node = _delivery_scope.defender
	var binding: int = _delivery_scope.binding
	var target: Node = _delivery_scope.counter_target
	if not _current(defender, packet) or defender.damage_generation() != packet.defender_epoch: return false
	if not _receiver_current(receiver, target, packet.counter_generation): return false
	# Receiver hooks may retire the source after evaluating their own token.
	return counter_source_is_current(packet, binding)
func counter_source_is_current(packet: Dictionary, expected_binding: int = -1) -> bool:
	if not _resolving or _delivery_scope.is_empty() or packet.get("counter_adapter") != self: return false
	var binding: int = _delivery_scope.binding
	if binding != _binding or (expected_binding >= 0 and binding != expected_binding): return false
	var defender: Node = _delivery_scope.defender
	return _current(defender, packet) and defender.damage_generation() == packet.defender_epoch and binding == _binding and not _delivery_scope.is_empty()
func claim_counter_contact(packet: Dictionary, receiver: Node) -> bool:
	if not counter_contact_is_current(packet, receiver) or bool(_delivery_scope.get("claimed", false)): return false
	_delivery_scope.claimed = true
	return true
func resolve_effect(owner_actor: Node2D, request: Dictionary) -> void:
	if _resolving or not _current(owner_actor, request): return
	# The controller's immutable defensive copy is authoritative, not signal data.
	if owner_actor.has_method("shield_effect_snapshot") and not _canonical(owner_actor, request): return
	var binding := _binding
	_resolving = true
	_resolve(owner_actor, request.duplicate(true), binding)
	_delivery_scope.clear()
	_resolving = false
func _resolve(owner_actor: Node2D, request: Dictionary, binding: int) -> void:
	var effect := StringName(request.get("effect", &""))
	var target: Variant = request.get("source") if effect == &"counter" else request.get("carrier")
	var target_id := int(request.get("target_id", 0))
	var report := {"effect": effect, "target_id": target_id, "attack_key": request.get("attack_key", ""), "applied": false, "confirmed": false, "reason": &"invalid_target"}
	if _live(target) and target.get_instance_id() == target_id and target != owner_actor and target.get_viewport().world_2d == owner_actor.get_world_2d():
		var payload := request.duplicate(true)
		payload["defender"] = owner_actor
		payload["defender_id"] = owner_actor.get_instance_id()
		if effect == &"counter":
			var receiver := _registered(target)
			if receiver != null:
				if owner_actor.has_method("damage_generation") and _canonical(owner_actor, request):
					var epoch: int = owner_actor.damage_generation()
					var token: Dictionary = receiver.capture_counter_generation()
					if not token.is_empty() and binding == _binding and _current(owner_actor, request) and owner_actor.damage_generation() == epoch and _receiver_current(receiver, target, token):
						var hurtbox: Variant = receiver.get_counter_hurtbox()
						if binding == _binding and _current(owner_actor, request) and owner_actor.damage_generation() == epoch and _receiver_current(receiver, target, token):
							var contact := _counter_contact(owner_actor, target, request, hurtbox)
							if not contact.is_empty() and binding == _binding and _current(owner_actor, request) and owner_actor.damage_generation() == epoch and _receiver_current(receiver, target, token):
								_ticket += 1
								payload.merge({"counter_adapter": self, "counter_ticket": _ticket, "defender_epoch": epoch, "counter_target": target, "counter_receiver": receiver, "counter_generation": token, "counter_contact_position": contact.position}, true)
								_delivery_scope = payload.duplicate(true)
								_delivery_scope.merge({"binding": binding, "claimed": false})
								payload.make_read_only()
								report = _response_report(report, receiver.receive_shield_counter(payload))
								_delivery_scope.clear()
				if report.reason == &"invalid_target": report.reason = &"no_reachable_counter_receiver"
			elif target.has_method("receive_shield_counter"):
				var contact := _counter_contact(owner_actor, target, request)
				if not contact.is_empty() and binding == _binding and _live(target) and _current(owner_actor, request):
					payload["counter_contact_position"] = contact.position
					report = _response_report(report, target.receive_shield_counter(payload))
				else: report.reason = &"no_reachable_counter_receiver"
			else: report.reason = &"no_reachable_counter_receiver"
		elif effect == &"reflect" and target.has_method("reflect_from_shield"):
			if binding == _binding and _live(target) and _current(owner_actor, request): report = _response_report(report, target.reflect_from_shield(payload))
		else: report.reason = &"unsupported_effect_receiver"
	# Accepted physical work is a fact even if a callback prevents confirmation.
	if binding == _binding and _live(target) and _current(owner_actor, request) and not bool(report.get("receiver_details", {}).get("retired", false)):
		report.confirmed = bool(owner_actor.confirm_shield_effect(int(request.shield_serial), String(request.attack_key), effect, target_id, bool(report.applied), report.duplicate(true)))
	if report.confirmed:
		if effect == &"counter": confirmed_counters += 1
		elif effect == &"reflect": confirmed_reflections += 1
	else: rejected_effects += 1
	last_report = report.duplicate(true)
	effect_resolved.emit(last_report.duplicate(true))
func _response_report(report: Dictionary, response: Variant) -> Dictionary:
	if response is Dictionary and response.get("accepted") is bool:
		report.applied = response.accepted
		report.reason = response.get("reason", &"accepted" if response.accepted else &"receiver_rejected")
		report["receiver_details"] = response.duplicate(true)
	else: report.reason = &"receiver_did_not_explicitly_accept"
	return report
func _exclude_descendants(node: Node, excluded: Array[RID]) -> void:
	if node is CollisionObject2D: excluded.append(node.get_rid())
	for child in node.get_children(): _exclude_descendants(child, excluded)
func _counter_contact(owner_actor: Node2D, target: Node, request: Dictionary, explicit_hurtbox: Variant = null) -> Dictionary:
	var hurtbox: Variant = explicit_hurtbox if explicit_hurtbox != null else (target.get_shield_counter_hurtbox() if target.has_method("get_shield_counter_hurtbox") else target)
	if not _live(target) or not _live(hurtbox) or not hurtbox is CollisionObject2D or hurtbox.get_world_2d() != owner_actor.get_world_2d() or not _current(owner_actor, request): return {}
	var origin: Vector2 = request.get("defender_origin", request.get("origin", Vector2.INF))
	var facing := -1.0 if int(request.get("facing", 1)) < 0 else 1.0
	var maximum := maxf(0, float(request.get("max_range", 0)))
	if not origin.is_finite() or not is_finite(maximum) or maximum <= 0 or hurtbox.collision_layer == 0: return {}
	var excluded: Array[RID] = []
	_exclude_descendants(owner_actor, excluded)
	var checked := 0
	for owner_id in hurtbox.get_shape_owners():
		if hurtbox.is_shape_owner_disabled(owner_id): continue
		for index in range(hurtbox.shape_owner_get_shape_count(owner_id)):
			checked += 1
			if checked > maximum_hurtbox_shapes: return {}
			var shape: Shape2D = hurtbox.shape_owner_get_shape(owner_id, index)
			if shape == null: continue
			var shape_transform: Transform2D = hurtbox.global_transform * hurtbox.shape_owner_get_transform(owner_id)
			var center := shape_transform * shape.get_rect().get_center()
			if (center.x - origin.x) * facing <= 0.001: continue
			var query := PhysicsRayQueryParameters2D.create(origin, center, obstruction_mask | hurtbox.collision_layer, excluded)
			query.collide_with_areas = true
			query.collide_with_bodies = true
			query.hit_from_inside = true
			var hit := owner_actor.get_world_2d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.collider != hurtbox: continue
			if (Vector2(hit.position).x - origin.x) * facing < -0.001 or origin.distance_to(hit.position) > maximum: continue
			return hit
	return {}
func reset_counters() -> void:
	_retire()
	confirmed_counters = 0
	confirmed_reflections = 0
	rejected_effects = 0
	last_report.clear()
