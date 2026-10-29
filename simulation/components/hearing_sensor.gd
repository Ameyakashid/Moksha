extends Node
## Detachable event subscriber. Does not emit sounds, move actors or pick targets.
signal heard(receipt: Dictionary)
const Profile = preload("res://simulation/resources/hearing_profile.gd")
const Query = preload("res://simulation/components/hearing_query.gd")
@export_node_path("Node2D") var listener_path := NodePath("..")
@export_node_path("Node") var event_bus_path := NodePath("/root/NoiseBus")
@export var profile: Profile
@export var enabled := true
var heard_count := 0
var last_receipt: Dictionary:
	get: return _last_receipt.duplicate(true)
var _last_receipt := {}
var _listener_ref: WeakRef
var _bus_ref: WeakRef
var _epoch := 0
var _callback: Callable
func _ready() -> void:
	if profile == null: profile = Profile.new()
	if not listener_path.is_empty() and not event_bus_path.is_empty(): bind(get_node_or_null(listener_path), get_node_or_null(event_bus_path))
func _exit_tree() -> void: unbind()
func _live(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
func _same_world(listener: Node2D, bus: Node) -> bool:
	return _live(self) and _live(listener) and _live(bus) and listener.get_tree() == get_tree() and bus.get_tree() == get_tree() and listener.get_world_2d() == get_viewport().world_2d and bus.get_viewport().world_2d == get_viewport().world_2d
func bind(listener: Node2D, bus: Node) -> bool:
	unbind()
	if not _same_world(listener, bus): return false
	if not is_instance_valid(listener) or not listener.is_inside_tree() or not is_instance_valid(bus) or not bus.is_inside_tree() or listener.is_queued_for_deletion() or bus.is_queued_for_deletion(): return false
	if listener.get_world_2d() != get_viewport().world_2d: return false
	if listener.get_tree() != get_tree() or bus.get_tree() != get_tree() or not bus.has_signal("noise_emitted"): return false
	_listener_ref = weakref(listener)
	_bus_ref = weakref(bus)
	_callback = _on_noise.bind(_epoch)
	bus.connect("noise_emitted", _callback)
	return true
func unbind() -> void:
	_epoch += 1
	var bus: Node = _bus_ref.get_ref() if _bus_ref != null else null
	if is_instance_valid(bus) and _callback.is_valid() and bus.is_connected("noise_emitted", _callback): bus.disconnect("noise_emitted", _callback)
	_listener_ref = null
	_bus_ref = null
	_callback = Callable()
	_last_receipt.clear()
func _on_noise(origin: Vector2, kind: StringName, loudness: float, source: Node, epoch: int) -> void:
	if epoch != _epoch or not enabled or not is_inside_tree() or is_queued_for_deletion() or not can_process(): return
	var listener: Node2D = _listener_ref.get_ref() if _listener_ref != null else null
	var bus: Node = _bus_ref.get_ref() if _bus_ref != null else null
	if not _same_world(listener, bus) or get_tree().paused or not listener.can_process(): return
	var receipt := Query.sample(listener, origin, loudness, source, profile)
	if receipt.is_empty(): return
	receipt["kind"] = kind
	receipt["sensor_serial"] = heard_count + 1
	heard_count += 1
	_last_receipt = receipt.duplicate(true)
	var notification := receipt.duplicate(true)
	notification.make_read_only()
	heard.emit(notification)
