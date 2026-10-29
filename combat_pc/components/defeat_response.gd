class_name MokshaDefeatResponse
extends Node
## Optional zero-health policy. Health owns the quantity; this component owns
## only the actor's defeated lease. Reset/release is explicit, never timed.
signal defeat_started()
signal defeat_cleared()
@export_node_path("Node2D") var actor_path := NodePath("..")
@export_node_path("Node") var health_path := NodePath("../Health")
@export_range(0.01, 2.0, 0.01) var collapse_seconds := 0.36
var active: bool:
	get:
		var actor := _actor()
		return _live(actor) and actor.is_defeated_by(self)
var _actor_ref: WeakRef
var _health_ref: WeakRef
var _binding := 0
var _reported_active := false
var _depleted_callback: Callable
var _reset_callback: Callable
var _health_exit_callback: Callable

func _ready() -> void:
	if not actor_path.is_empty() and not health_path.is_empty(): bind(get_node_or_null(actor_path), get_node_or_null(health_path))

func _exit_tree() -> void:
	unbind()

func _live(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()

func _actor() -> Node:
	return _actor_ref.get_ref() if _actor_ref != null else null

func _health() -> Node:
	return _health_ref.get_ref() if _health_ref != null else null

func bind(actor: Node, health: Node) -> bool:
	var previous := _binding
	unbind()
	if _binding != previous + 1: return false
	if not _live(actor) or not _live(health): return false
	if not actor.has_method("enter_defeated") or not actor.has_method("release_defeated") or not actor.has_method("is_defeated_by"): return false
	if not actor.has_signal("movement_event") or not health.has_signal("depleted") or not health.has_method("get_bound_actor") or not "current_health" in health: return false
	if health.get_bound_actor() != actor: return false
	_actor_ref = weakref(actor)
	_health_ref = weakref(health)
	_depleted_callback = _on_depleted.bind(_binding)
	_reset_callback = _on_actor_event.bind(_binding)
	_health_exit_callback = _on_health_exit.bind(_binding)
	health.connect("depleted", _depleted_callback)
	health.tree_exiting.connect(_health_exit_callback)
	actor.connect("movement_event", _reset_callback)
	if health.current_health <= 0: _on_depleted(_binding)
	return _actor() == actor and _health() == health

func unbind() -> void:
	_binding += 1
	var binding := _binding
	var actor := _actor()
	var health := _health()
	var was_active := _reported_active
	_actor_ref = null
	_health_ref = null
	_reported_active = false
	if is_instance_valid(health) and _depleted_callback.is_valid() and health.is_connected("depleted", _depleted_callback): health.disconnect("depleted", _depleted_callback)
	if is_instance_valid(health) and _health_exit_callback.is_valid() and health.tree_exiting.is_connected(_health_exit_callback): health.tree_exiting.disconnect(_health_exit_callback)
	if is_instance_valid(actor):
		if _reset_callback.is_valid() and actor.is_connected("movement_event", _reset_callback): actor.disconnect("movement_event", _reset_callback)
		actor.release_defeated(self)
	if binding == _binding and was_active and is_inside_tree() and not is_queued_for_deletion(): defeat_cleared.emit()

func _on_depleted(binding: int) -> void:
	var actor := _actor()
	var health := _health()
	if binding != _binding or not _live(self) or not _live(actor) or not _live(health) or health.get_bound_actor() != actor or health.current_health > 0 or active: return
	var accepted: bool = actor.enter_defeated(self, collapse_seconds)
	if binding != _binding or not accepted or not _live(self) or not _live(actor) or not actor.is_defeated_by(self): return
	if not _live(health) or health.get_bound_actor() != actor or health.current_health > 0:
		actor.release_defeated(self)
		return
	_reported_active = true
	defeat_started.emit()

func _on_actor_event(kind: StringName, _payload: Dictionary, binding: int) -> void:
	if binding != _binding or kind != &"reset": return
	var was_active := _reported_active
	_reported_active = false
	if was_active: defeat_cleared.emit()

func _on_health_exit(binding: int) -> void:
	if binding == _binding: unbind()
