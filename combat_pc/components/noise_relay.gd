class_name MokshaNoiseRelay
extends Node
## Optional adapter from committed PC noise receipts to the existing NoiseBus
## contract. This component never recomputes an origin or drives the actor.
signal forwarded(event: Dictionary)
@export_node_path("Node2D") var actor_path := NodePath("..")
@export_node_path("Node") var event_bus_path := NodePath("")
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		_refresh_connection()
var forwarded_count := 0
var last_event: Dictionary:
	get: return _last_event.duplicate(true)
var _last_event: Dictionary = {}
var _actor_ref: WeakRef
var _bus_ref: WeakRef
var _binding := 0
var _operation := 0
var _callback: Callable

func _ready() -> void:
	if not actor_path.is_empty() and not event_bus_path.is_empty(): bind(get_node_or_null(actor_path),get_node_or_null(event_bus_path))

func _exit_tree() -> void:
	unbind()

func _live(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()

func _actor() -> Node:
	return _actor_ref.get_ref() if _actor_ref != null else null

func _bus() -> Node:
	return _bus_ref.get_ref() if _bus_ref != null else null

func bind(actor: Node, event_bus: Node) -> bool:
	unbind()
	if not _live(actor) or not _live(event_bus) or actor == event_bus: return false
	if actor.get_tree() != event_bus.get_tree(): return false
	if not actor.has_signal("noise_committed") or not actor.has_method("noise_generation"): return false
	if not event_bus.has_method("emit_noise") or not event_bus.has_signal("noise_emitted"): return false
	_actor_ref = weakref(actor)
	_bus_ref = weakref(event_bus)
	_refresh_connection()
	return true

func unbind() -> void:
	_disconnect()
	_actor_ref = null
	_bus_ref = null

func _disconnect() -> void:
	_binding += 1
	_operation += 1
	var actor := _actor()
	if is_instance_valid(actor) and _callback.is_valid() and actor.is_connected("noise_committed",_callback): actor.disconnect("noise_committed",_callback)
	_callback = Callable()

func _refresh_connection() -> void:
	_disconnect()
	var actor := _actor()
	if enabled and _live(actor) and _live(_bus()):
		_callback = _on_noise.bind(_binding)
		actor.connect("noise_committed",_callback)

func reset_diagnostics() -> void:
	_operation += 1
	forwarded_count = 0
	_last_event.clear()

func _on_noise(event: Dictionary, binding: int) -> void:
	var actor := _actor()
	var event_bus := _bus()
	if binding != _binding or not enabled or not _live(self) or not _live(actor) or not _live(event_bus): return
	if event.get("actor_id") != actor.get_instance_id() or event.get("generation") != actor.noise_generation(): return
	if not event.get("serial") is int or int(event.serial) <= 0: return
	if not event.get("origin") is Vector2 or not Vector2(event.origin).is_finite(): return
	if not (event.get("kind") is String or event.get("kind") is StringName) or String(event.kind).is_empty(): return
	if not (event.get("loudness") is float or event.get("loudness") is int): return
	var loudness := float(event.loudness)
	if not is_finite(loudness) or loudness <= 0: return
	var operation := _operation
	var receipt := event.duplicate()
	receipt.make_read_only()
	# Commit diagnostics before callbacks. Nested sounds can arrive in reverse
	# receipt order, so never deduplicate using a highest-serial threshold.
	forwarded_count += 1
	_last_event = receipt.duplicate(true)
	event_bus.emit_noise(receipt.origin,StringName(receipt.kind),loudness,actor)
	if operation != _operation or binding != _binding or not enabled or not _live(self) or not _live(actor) or not _live(event_bus): return
	if _actor() != actor or _bus() != event_bus or receipt.generation != actor.noise_generation(): return
	forwarded.emit(receipt)
