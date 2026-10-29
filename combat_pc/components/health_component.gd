class_name MokshaHealthComponent
extends Node
## Optional scalar health store. Defense, recoil and attack identity remain
## owned by the actor. Zero emits depletion; it does not impose a death policy.
signal health_changed(current: float, maximum: float)
signal damage_processed(receipt: Dictionary)
signal depleted()

@export_node_path("Node2D") var actor_path := NodePath("..")
@export_range(1.0, 10000.0, 1.0) var maximum_health := 100.0
@export var reset_with_actor := true
var current_health: float:
	get: return _current
var capacity: float:
	get: return _capacity
var _current := 0.0
var _capacity := 100.0
var _actor_ref: WeakRef
var _binding := 0
var _minimum_damage_serial := 0
var _change_generation := 0
var _damage_callback: Callable
var _movement_callback: Callable
var _damage_delivery_scope: Dictionary = {}
# Optional guarded delivery: tokens and emitted receipts remain scalar-only.
# References live only in this bounded, synchronous, Health-owned table.
const GUARDED_DEBIT_LIMIT := 16
const GUARDED_FIELDS := ["guard_health_id", "guard_binding", "guard_change", "guard_serial"]
var _guard_serial := 0
var _guarded_debits: Dictionary = {}
const GUARDED_HISTORY_LIMIT := 128
var _guard_history_generation := -1
var _guard_history: Array[Vector2i] = []

func _ready() -> void:
	reset_to_full()
	if not actor_path.is_empty(): bind_actor(get_node_or_null(actor_path))

func _exit_tree() -> void:
	unbind_actor()

func _actor() -> Node:
	return _actor_ref.get_ref() if _actor_ref != null else null

func get_bound_actor() -> Node:
	return _actor()

func bind_actor(actor: Node) -> bool:
	unbind_actor()
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion(): return false
	if not actor.has_signal("damage_resolved") or not actor.has_signal("movement_event") or not actor.has_method("damage_generation"): return false
	_actor_ref = weakref(actor)
	# Fixed floor for this binding, not a last-seen high-water mark: nested
	# receipt N+1 may still arrive before an independently admitted receipt N.
	_minimum_damage_serial = int(actor.damage_admission_sequence()) + 1 if actor.has_method("damage_admission_sequence") else 0
	_damage_callback = _on_damage.bind(_binding)
	_movement_callback = _on_movement.bind(_binding)
	actor.connect("damage_resolved", _damage_callback)
	actor.connect("movement_event", _movement_callback)
	return true

func unbind_actor() -> void:
	_guarded_debits.clear()
	_guard_history.clear()
	_guard_history_generation = -1
	_binding += 1
	_change_generation += 1
	var actor := _actor()
	_actor_ref = null
	if is_instance_valid(actor):
		if _damage_callback.is_valid() and actor.is_connected("damage_resolved", _damage_callback): actor.disconnect("damage_resolved", _damage_callback)
		if _movement_callback.is_valid() and actor.is_connected("movement_event", _movement_callback): actor.disconnect("movement_event", _movement_callback)

func reset_to_full() -> void:
	_guarded_debits.clear()
	_change_generation += 1
	_capacity = maximum_health if is_finite(maximum_health) and maximum_health >= 1.0 else 100.0
	_current = _capacity
	health_changed.emit(_current, _capacity)

func _on_movement(kind: StringName, _payload: Dictionary, binding: int) -> void:
	if binding == _binding and kind == &"reset" and reset_with_actor: reset_to_full()

func _on_damage(receipt: Dictionary, binding: int) -> void:
	var actor := _actor()
	if binding != _binding or not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion(): return
	if receipt.get("actor_id") != actor.get_instance_id() or receipt.get("generation") != actor.damage_generation(): return
	if _minimum_damage_serial > 0 and (not receipt.get("serial") is int or int(receipt.serial) < _minimum_damage_serial): return
	var amount: Variant = receipt.get("amount")
	if not (amount is float or amount is int) or not is_finite(float(amount)) or float(amount) < 0: return
	if receipt.get("outcome") not in [&"hurt", &"guarded", &"parried", &"evaded"]: return
	# A prior signal listener may have reset/rebound this very store or retired
	# the observation after the controller emitted. Check at the actual debit.
	if receipt.has("guard_health_id") or _guarded_admission_seen(int(receipt.get("generation", -1)), int(receipt.get("serial", -1))):
		if not _guarded_debit_current(receipt): return
		var reservation: Dictionary = _guarded_debits[int(receipt.guard_serial)]
		if not is_same(receipt, reservation.get("receipt")): return
		if receipt.serial != reservation.serial or receipt.generation != reservation.generation: return
		_guarded_debits.erase(int(receipt.guard_serial)) # Before any nested delivery.
	# No highest-serial filter: a synchronous nested hit can deliver N+1 before N.
	# The actor already deduplicates identified contacts; this connection is unique.
	_change_generation += 1
	var change := _change_generation
	var previous := _current
	_current = maxf(0.0, previous - float(amount))
	var became_empty := previous > 0.0 and _current == 0.0
	var event := receipt.duplicate()
	event.merge({"applied": previous - _current, "before": previous, "after": _current, "maximum": _capacity})
	event.make_read_only()
	if _current != previous: health_changed.emit(_current, _capacity)
	if not _notification_is_current(change, binding, actor, receipt.generation): return
	var previous_scope := _damage_delivery_scope
	_damage_delivery_scope = {"receipt": event, "change": change, "binding": binding, "actor": weakref(actor), "generation": int(receipt.generation)}
	damage_processed.emit(event)
	# Nested damage/reset/rebind permanently retires older notification scope.
	_damage_delivery_scope = previous_scope if _delivery_scope_current(previous_scope) else {}
	if not _notification_is_current(change, binding, actor, receipt.generation): return
	if became_empty: depleted.emit()

func _notification_is_current(change: int, binding: int, actor: Node, generation: int) -> bool:
	return change == _change_generation and binding == _binding and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion() and actor.damage_generation() == generation

func _delivery_scope_current(scope: Dictionary) -> bool:
	if scope.is_empty(): return false
	var actor: Node = scope.actor.get_ref()
	return _notification_is_current(int(scope.change), int(scope.binding), actor, int(scope.generation)) and _actor() == actor

## Synchronous genuine Health notification observation; equal copied scalars
## are not authority. This accessor never invokes an extension callback.
func damage_receipt_is_current(receipt: Dictionary) -> bool:
	return _delivery_scope_current(_damage_delivery_scope) and is_same(receipt, _damage_delivery_scope.receipt)

## Role-neutral optional admission reservation. No extension callback is invoked
## by the debit-time validator. The owner releases it on synchronous return.
func reserve_guarded_debit(owner: Variant, source: Variant, scope: Variant, generation: int, serial: int) -> Dictionary:
	for key in _guarded_debits.keys():
		if not _guarded_debit_current(_guarded_debits[key].token): _guarded_debits.erase(key)
	var actor := _actor() as Node2D
	if _guarded_debits.size() >= GUARDED_DEBIT_LIMIT or not _guard_live(self) or not _guard_live(actor): return {}
	if not _guard_live(owner) or not _guard_live(source) or not _guard_live(scope): return {}
	if not owner is Node2D or not source is Node2D or not scope is Node2D: return {}
	if not actor.is_ancestor_of(owner) or not scope.is_ancestor_of(actor) or not scope.is_ancestor_of(source): return {}
	if generation != actor.damage_generation() or serial != actor.damage_admission_sequence() + 1: return {}
	_guard_serial += 1
	var token := {"guard_health_id": get_instance_id(), "guard_binding": _binding, "guard_change": _change_generation, "guard_serial": _guard_serial}
	token.make_read_only()
	var nodes: Array[Dictionary] = []
	for node in [actor, owner, source, scope]:
		nodes.append({"node": weakref(node), "transform": node.global_transform, "physics_processing": node.is_physics_processing()})
	_guarded_debits[_guard_serial] = {"token": token, "nodes": nodes, "world": actor.get_world_2d(),
		"frame": Engine.get_physics_frames(), "generation": generation, "serial": serial}
	return token

func _guard_live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion() 		and node.get_tree() == get_tree() and node.can_process() and not get_tree().paused

func _guarded_debit_current(token: Dictionary) -> bool:
	for key in GUARDED_FIELDS:
		if not token.get(key) is int: return false
	if token.guard_health_id != get_instance_id() or token.guard_binding != _binding or token.guard_change != _change_generation: return false
	if not _guard_live(self) or not _guarded_debits.has(token.guard_serial): return false
	var held: Dictionary = _guarded_debits[token.guard_serial]
	if held.frame != Engine.get_physics_frames(): return false
	for key in GUARDED_FIELDS:
		if token[key] != held.token[key]: return false
	for item in held.nodes:
		var node: Variant = item.node.get_ref()
		if not _guard_live(node) or not node is Node2D or node.get_world_2d() != held.world or node.global_transform != item.transform or node.is_physics_processing() != item.physics_processing: return false
	var actor: Variant = held.nodes[0].node.get_ref()
	return _actor() == actor and actor.is_physics_processing()

func guarded_debit_is_current(token: Dictionary) -> bool:
	return _guarded_debit_current(token)

func seal_guarded_debit(token: Dictionary, receipt: Dictionary) -> bool:
	if not _guarded_debit_current(token) or not receipt.is_read_only(): return false
	var held: Dictionary = _guarded_debits[token.guard_serial]
	if not held.get("claimed", false) or held.has("receipt") or receipt.get("actor_id") != _actor().get_instance_id() 		or receipt.get("generation") != held.generation or receipt.get("serial") != held.serial: return false
	for key in GUARDED_FIELDS:
		if receipt.get(key) != token[key]: return false
	for value in receipt.values():
		if not (value is int or value is float or value is bool or value is String or value is StringName): return false
	held.receipt = receipt
	return true

func release_guarded_debit(token: Dictionary) -> void:
	if token.get("guard_health_id") == get_instance_id() and token.get("guard_serial") is int:
		_guarded_debits.erase(int(token.guard_serial))

# Compressed scalar tombstones distinguish guarded admissions even if a listener
# strips all optional fields. Bounded per binding/life, no retained Node/token.
# At capacity a new disjoint guarded admission fails closed; adjacent admissions
# merge, so repeated ordinary boundary episodes do not consume extra ranges.
func _guarded_admission_seen(generation: int, serial: int) -> bool:
	if generation != _guard_history_generation: return false
	for span in _guard_history:
		if serial >= span.x and serial <= span.y: return true
	return false

func claim_guarded_debit(token: Dictionary) -> bool:
	if not _guarded_debit_current(token): return false
	var held: Dictionary = _guarded_debits[token.guard_serial]
	if held.get("claimed", false) or _actor().damage_admission_sequence() != held.serial: return false
	if held.generation != _guard_history_generation:
		_guard_history.clear()
		_guard_history_generation = held.generation
	var serial: int = held.serial
	var merged := false
	for i in _guard_history.size():
		if serial >= _guard_history[i].x-1 and serial <= _guard_history[i].y+1:
			_guard_history[i]=Vector2i(mini(serial,_guard_history[i].x),maxi(serial,_guard_history[i].y));merged=true;break
	if not merged:
		if _guard_history.size() >= GUARDED_HISTORY_LIMIT: return false
		_guard_history.append(Vector2i(serial,serial))
	held.claimed = true
	return true
