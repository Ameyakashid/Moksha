class_name MokshaStrikeHealth
extends Node2D
## Optional confirmed-strike provider for the existing scalar Health component.
## ContactAdapter alone admits hits. This node never moves or kills the target.
signal damage_resolved(receipt: Dictionary)
signal movement_event(kind: StringName, payload: Dictionary)

const REGISTRATION: StringName = &"_moksha_strike_health"
const HISTORY: StringName = &"_moksha_strike_health_history"
const SOURCE_LIMIT := 64

class StrikeHistory extends RefCounted:
	var sources: Array[Dictionary] = []

@export_node_path("Node2D") var receiver_path := NodePath("..")
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		reset_history()

var resolved_count := 0
var rejected_count := 0
var last_reason: StringName = &"unbound"
var last_receipt: Dictionary:
	get: return _last_receipt.duplicate(true)
var _receiver_ref: WeakRef
var _history: StrikeHistory
var _strike_callback: Callable
var _binding := 0
var _generation := 0
var _reject_through_frame := -1
var _consuming := false
var _last_receipt: Dictionary = {}

func _ready() -> void:
	if _receiver() == null and not receiver_path.is_empty():
		bind_receiver(get_node_or_null(receiver_path) as Node2D)

func _exit_tree() -> void:
	unbind()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]:
		reset_history()

func damage_generation() -> int:
	return _generation

func _receiver() -> Node2D:
	return _receiver_ref.get_ref() as Node2D if _receiver_ref != null else null

func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()

func _same_world(node: Variant) -> bool:
	return _live(self) and _live(node) and node.get_tree() == get_tree() and node.get_viewport().world_2d == get_world_2d()

func _registered(receiver: Node2D) -> MokshaStrikeHealth:
	if not is_instance_valid(receiver) or not receiver.has_meta(REGISTRATION): return null
	var reference: Variant = receiver.get_meta(REGISTRATION, null)
	if not reference is WeakRef: return null
	var component: Variant = reference.get_ref()
	if not _live(component) or not component is MokshaStrikeHealth: return null
	return component if component._receiver() == receiver else null

func bind_receiver(receiver: Node2D) -> bool:
	if not _same_world(receiver) or receiver == self or not receiver.has_signal("struck"): return false
	var existing := _registered(receiver)
	if existing != null and existing != self: return false
	if _receiver() == receiver: return true
	unbind()
	_receiver_ref = weakref(receiver)
	var retained: Variant = receiver.get_meta(HISTORY) if receiver.has_meta(HISTORY) else null
	_history = retained if retained is StrikeHistory else StrikeHistory.new()
	# Receiver-lifetime history survives reset, rebind and component replacement.
	# Only weak sources are retained; no actor lifetime is extended.
	receiver.set_meta(HISTORY, _history)
	receiver.set_meta(REGISTRATION, weakref(self))
	_strike_callback = _on_struck.bind(_binding)
	receiver.connect("struck", _strike_callback)
	last_reason = &"ready"
	return true

func unbind() -> void:
	_binding += 1
	reset_history()
	var receiver := _receiver()
	if is_instance_valid(receiver):
		if _strike_callback.is_valid() and receiver.is_connected("struck", _strike_callback):
			receiver.disconnect("struck", _strike_callback)
		if _registered(receiver) == self: receiver.remove_meta(REGISTRATION)
	_receiver_ref = null
	_history = null
	last_reason = &"unbound"

func reset_history() -> void:
	# Invalidate before host teleport/reset. Never rearm consumed identities.
	_generation += 1
	_reject_through_frame = Engine.get_physics_frames()
	_prune_sources()

func reset_to_full() -> void:
	reset_history()
	# Existing Health owns capacity, refill, change notification and depletion.
	movement_event.emit(&"reset", {})

func reset_diagnostics() -> void:
	resolved_count = 0
	rejected_count = 0
	_last_receipt = {}
	last_reason = &"ready" if _receiver() != null else &"unbound"

func _prune_sources() -> void:
	if _history == null: return
	for index in range(_history.sources.size() - 1, -1, -1):
		if not is_instance_valid(_history.sources[index].source_ref.get_ref()):
			_history.sources.remove_at(index)

func _source_index(source: Node2D) -> int:
	_prune_sources()
	for index in _history.sources.size():
		if _history.sources[index].source_ref.get_ref() == source: return index
	return -1

func _eligible() -> bool:
	var receiver := _receiver()
	return enabled and _same_world(receiver) and _registered(receiver) == self \
		and can_process() and receiver.can_process() and not get_tree().paused \
		and Engine.get_physics_frames() > _reject_through_frame

func _reject(reason: StringName) -> bool:
	rejected_count += 1
	last_reason = reason
	return false

func _on_struck(payload: Dictionary, binding: int) -> void:
	if binding == _binding: consume_strike(payload)

func _commit_is_current(binding: int, generation: int, source: Variant, serial: int) -> bool:
	if binding != _binding or generation != _generation or not _eligible() or not _same_world(source): return false
	var current: bool = source.is_strike_current(serial)
	# A custom source can call out during this query. Recheck all lifetimes.
	return current and binding == _binding and generation == _generation and _eligible() and _same_world(source)

func consume_strike(payload: Dictionary) -> bool:
	if _consuming: return _reject(&"reentrant")
	if not _eligible(): return _reject(&"unavailable")
	if not payload.get("serial") is int or int(payload.serial) < 0: return _reject(&"invalid_serial")
	if not payload.get("eligible") is bool or not bool(payload.eligible): return _reject(&"inactive_packet")
	if not (payload.get("phase") is String or payload.get("phase") is StringName) or String(payload.phase) != "active":
		return _reject(&"inactive_packet")
	var amount: Variant = payload.get("damage")
	if not (amount is float or amount is int) or not is_finite(float(amount)) or float(amount) < 0.0:
		return _reject(&"invalid_damage")
	if not payload.get("contact_position") is Vector2 or not Vector2(payload.contact_position).is_finite():
		return _reject(&"invalid_contact")
	var source: Variant = payload.get("source")
	var receiver := _receiver()
	if not _same_world(source) or not source is Node2D or source == receiver or source == self:
		return _reject(&"invalid_source")
	if not source.has_method("is_strike_current") or not source.can_process(): return _reject(&"invalid_source")
	var serial: int = payload.serial
	var source_index := _source_index(source)
	if source_index >= 0 and int(_history.sources[source_index].serial) >= serial: return _reject(&"duplicate")
	if source_index < 0 and _history.sources.size() >= SOURCE_LIMIT: return _reject(&"source_capacity")
	var binding := _binding
	var generation := _generation
	_consuming = true
	# Source confirmation has already started hitpause. Query its admitted live
	# strike, not a fresh eligibility snapshot that would reject that pause.
	if not _commit_is_current(binding, generation, source, serial):
		_consuming = false
		return _reject(&"retired_strike")
	var consumed := {"source_ref": weakref(source), "serial": serial}
	if source_index >= 0: _history.sources[source_index] = consumed
	else: _history.sources.append(consumed)
	var receipt := {"actor_id": get_instance_id(), "generation": generation, "outcome": &"hurt",
		"amount": float(amount), "source_id": source.get_instance_id(), "receiver_id": receiver.get_instance_id(),
		"serial": serial, "contact_position": Vector2(payload.contact_position),
		"step_label": str(payload.get("step_label", "Strike")), "physics_frame": Engine.get_physics_frames()}
	receipt.make_read_only()
	resolved_count += 1
	_last_receipt = receipt.duplicate(true)
	last_reason = &"resolved"
	_consuming = false
	# Health validates provider generation when its slot runs. Earlier listeners
	# can reset/rebind/free; nested valid later strikes remain distinct. No stale
	# state writes follow publication. This count describes resolved receipts,
	# not a guarantee that a still-attached Health subscriber accepted each one.
	damage_resolved.emit(receipt)
	return true

func diagnostic_snapshot() -> Dictionary:
	return {"enabled": enabled, "bound": _receiver() != null, "resolved_count": resolved_count,
		"rejected_count": rejected_count, "last_reason": last_reason,
		"tracked_sources": _history.sources.size() if _history != null else 0, "last_receipt": last_receipt}
