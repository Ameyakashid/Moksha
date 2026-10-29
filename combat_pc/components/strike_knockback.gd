class_name MokshaStrikeKnockback
extends Node
## Detachable receiver response. The contact adapter owns hit admission and the
## existing movement motor alone owns motion, gravity, stun and collisions.
signal knockback_applied(receipt: Dictionary)

const KnockbackProfile = preload("res://combat_pc/resources/knockback_profile.gd")
const DEFAULT_PROFILE = preload("res://combat_pc/resources/knockback_profile.tres")
const REGISTRATION: StringName = &"_moksha_strike_knockback"
const HISTORY: StringName = &"_moksha_strike_knockback_history"
const SOURCE_LIMIT := 64
const RECEIPT_LIMIT := 16

class StrikeHistory extends RefCounted:
	var sources: Array[Dictionary] = []

@export_node_path("Node2D") var receiver_path := NodePath("..")
@export_node_path("CharacterBody2D") var motor_path := NodePath("..")
@export var receiver_signal: StringName = &"struck"
@export var profile: KnockbackProfile = DEFAULT_PROFILE
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		reset_history()

var applied_count := 0
var rejected_count := 0
var last_reason: StringName = &"unbound"
var last_receipt: Dictionary:
	get: return _last_receipt.duplicate(true)
var recent_receipts: Array[Dictionary]:
	get: return _recent_receipts.duplicate(true)
var _receiver_ref: WeakRef
var _motor_ref: WeakRef
var _history: StrikeHistory
var _strike_callback: Callable
var _bound_signal: StringName
var _binding := 0
var _epoch := 0
var _reject_through_frame := -1
var _consuming := false
var _last_receipt: Dictionary = {}
var _recent_receipts: Array[Dictionary] = []

func _ready() -> void:
	if _receiver() == null and not receiver_path.is_empty() and not motor_path.is_empty():
		bind_receiver(get_node_or_null(receiver_path) as Node2D, get_node_or_null(motor_path) as MokshaMovementMotor)

func _exit_tree() -> void:
	unbind()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]:
		reset_history()

func _receiver() -> Node2D:
	return _receiver_ref.get_ref() as Node2D if _receiver_ref != null else null

func _motor() -> MokshaMovementMotor:
	return _motor_ref.get_ref() as MokshaMovementMotor if _motor_ref != null else null

func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()

func _same_world(node: Variant, motor: Variant) -> bool:
	return _live(node) and _live(motor) and node.get_tree() == motor.get_tree() and node.get_viewport().world_2d == motor.get_world_2d()

func _registered(receiver: Node2D) -> MokshaStrikeKnockback:
	if not is_instance_valid(receiver) or not receiver.has_meta(REGISTRATION): return null
	var reference: Variant = receiver.get_meta(REGISTRATION, null)
	if not reference is WeakRef: return null
	var component: Variant = reference.get_ref()
	if not _live(component) or not component is MokshaStrikeKnockback: return null
	return component if component._receiver() == receiver else null

func bind_receiver(receiver: Node2D, motor: MokshaMovementMotor) -> bool:
	if not _same_world(self, motor) or not _same_world(receiver, motor): return false
	if receiver != motor and not motor.is_ancestor_of(receiver): return false
	if receiver_signal.is_empty() or not receiver.has_signal(receiver_signal): return false
	var existing := _registered(receiver)
	if existing != null and existing != self: return false
	if _receiver() == receiver and _motor() == motor and _bound_signal == receiver_signal: return true
	unbind()
	_receiver_ref = weakref(receiver)
	_motor_ref = weakref(motor)
	_bound_signal = receiver_signal
	var retained: Variant = receiver.get_meta(HISTORY) if receiver.has_meta(HISTORY) else null
	_history = retained if retained is StrikeHistory else StrikeHistory.new()
	# Keep consumed identities with the receiver across detach/replacement. This
	# runtime-only metadata holds weak sources, never keeps actors alive, and is
	# deliberately not erased by reset or a diagnostics clear.
	receiver.set_meta(HISTORY, _history)
	receiver.set_meta(REGISTRATION, weakref(self))
	_strike_callback = _on_struck.bind(_binding)
	receiver.connect(_bound_signal, _strike_callback)
	last_reason = &"ready"
	return true

func unbind() -> void:
	_binding += 1
	reset_history()
	var receiver := _receiver()
	if is_instance_valid(receiver):
		if _strike_callback.is_valid() and receiver.is_connected(_bound_signal, _strike_callback):
			receiver.disconnect(_bound_signal, _strike_callback)
		if _registered(receiver) == self: receiver.remove_meta(REGISTRATION)
	_receiver_ref = null
	_motor_ref = null
	_history = null
	last_reason = &"unbound"

func reset_history() -> void:
	# Call BEFORE receiver teleport/reset. Also rejects later subscribers to a
	# pre-reset struck signal within this physics frame. No effect is queued.
	_epoch += 1
	_reject_through_frame = Engine.get_physics_frames()
	_prune_sources()

func reset_diagnostics() -> void:
	applied_count = 0
	rejected_count = 0
	_last_receipt = {}
	_recent_receipts.clear()
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
	var motor := _motor()
	var receiver := _receiver()
	return enabled and _same_world(self, motor) and _same_world(receiver, motor) \
		and (receiver == motor or motor.is_ancestor_of(receiver)) \
		and _registered(receiver) == self and motor.enabled and motor.can_process() and motor.is_physics_processing() and receiver.can_process() \
		and can_process() and not get_tree().paused and Engine.get_physics_frames() > _reject_through_frame

func _reject(reason: StringName) -> bool:
	rejected_count += 1
	last_reason = reason
	return false

func _on_struck(payload: Dictionary, binding: int) -> void:
	if binding == _binding: consume_strike(payload)

func _commit_is_current(binding: int, epoch: int, source: Variant, serial: int) -> bool:
	if binding != _binding or epoch != _epoch or not _eligible() or not _same_world(source, _motor()): return false
	var current: bool = source.is_strike_current(serial)
	# A custom source may call out while answering. Check its lifetime and the
	# receiver binding again before any following motor mutation.
	return current and binding == _binding and epoch == _epoch and _eligible() and _same_world(source, _motor())

func consume_strike(payload: Dictionary) -> bool:
	if _consuming: return _reject(&"reentrant")
	if not _eligible(): return _reject(&"unavailable")
	var tuning: KnockbackProfile = profile if profile != null else DEFAULT_PROFILE
	if not tuning.is_valid_profile(): return _reject(&"invalid_profile")
	if not payload.get("serial") is int or int(payload.serial) < 0: return _reject(&"invalid_serial")
	if not payload.get("eligible") is bool or not bool(payload.eligible):
		return _reject(&"inactive_packet")
	if not (payload.get("phase") is String or payload.get("phase") is StringName) or String(payload.phase) != "active":
		return _reject(&"inactive_packet")
	if not payload.get("impulse") is Vector2 or not Vector2(payload.impulse).is_finite(): return _reject(&"invalid_impulse")
	if not payload.get("contact_position") is Vector2 or not Vector2(payload.contact_position).is_finite(): return _reject(&"invalid_contact")
	var source: Variant = payload.get("source")
	var motor := _motor()
	var receiver := _receiver()
	if not _live(source) or not source is Node2D or source == receiver or source == motor or not _same_world(source, motor):
		return _reject(&"invalid_source")
	if not source.has_method("is_strike_current") or not source.can_process(): return _reject(&"invalid_source")
	var serial: int = payload.serial
	var source_index := _source_index(source)
	if source_index >= 0 and int(_history.sources[source_index].serial) >= serial: return _reject(&"duplicate")
	if source_index < 0 and _history.sources.size() >= SOURCE_LIMIT: return _reject(&"source_capacity")
	var impulse: Vector2 = payload.impulse
	var contact: Vector2 = payload.contact_position
	var velocity := impulse * tuning.velocity_scale
	if not velocity.is_finite(): return _reject(&"invalid_velocity")
	# Very large finite inputs can overflow length_squared; normalize using a
	# bounded intermediate before applying the total-vector speed limit.
	var largest := maxf(absf(velocity.x), absf(velocity.y))
	if largest > tuning.maximum_speed:
		velocity = (velocity / largest).normalized() * tuning.maximum_speed
	else:
		velocity = velocity.limit_length(tuning.maximum_speed)
	var stun := tuning.stun_seconds
	var pause := 0.0
	if tuning.copy_source_pause:
		var remaining: Variant = source.get("hitpause_remaining")
		if remaining != null:
			if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining) < 0.0:
				return _reject(&"invalid_source_pause")
			pause = minf(float(remaining), tuning.maximum_pause_seconds)
	var binding := _binding
	var epoch := _epoch
	_consuming = true
	# Confirmation starts the source pause before delivery. Current lifetime is
	# authoritative; a NEW strike_snapshot().eligible would incorrectly reject.
	if not _commit_is_current(binding, epoch, source, serial):
		_consuming = false
		return _reject(&"retired_strike")
	# Commit identity before any motor call, so nested callbacks cannot replay.
	var consumed := {"source_ref": weakref(source), "serial": serial}
	if source_index >= 0: _history.sources[source_index] = consumed
	else: _history.sources.append(consumed)
	var receipt := {"source_id": source.get_instance_id(), "receiver_id": receiver.get_instance_id(), "motor_id": motor.get_instance_id(),
		"serial": serial, "contact_position": contact, "input_impulse": impulse, "applied_velocity": velocity,
		"stun_seconds": stun, "pause_seconds": pause, "physics_frame": Engine.get_physics_frames()}
	applied_count += 1
	motor.apply_impulse(velocity, stun)
	# The stock motor does not call out. An integrating subclass may reset,
	# detach or disable during its hook; no old pause or receipt may follow it.
	if not _commit_is_current(binding, epoch, source, serial):
		_consuming = false
		return true
	if pause > 0.0: motor.apply_pause(pause)
	if not _commit_is_current(binding, epoch, source, serial):
		_consuming = false
		return true
	receipt.make_read_only()
	_last_receipt = receipt.duplicate(true)
	_recent_receipts.append(receipt.duplicate(true))
	if _recent_receipts.size() > RECEIPT_LIMIT: _recent_receipts.pop_front()
	last_reason = &"applied"
	_consuming = false
	# No component writes after publication. Listeners may reset, replace or
	# delete the receiver; the value-only receipt describes a completed commit.
	knockback_applied.emit(receipt)
	return true

func diagnostic_snapshot() -> Dictionary:
	return {"enabled": enabled, "bound": _receiver() != null, "applied_count": applied_count, "rejected_count": rejected_count,
		"last_reason": last_reason, "tracked_sources": _history.sources.size() if _history != null else 0,
		"last_receipt": last_receipt, "recent_receipts": recent_receipts}
