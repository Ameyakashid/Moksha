class_name MokshaPhysicsContactNoise
extends Node
## Detachable observer of committed rigid-body contacts. No impulses, motion
## changes, timers that synthesize contacts, actor scans, or global bus lookup.
signal impact_emitted(event: Dictionary)

const ContactProfile = preload("res://combat_pc/resources/contact_noise_profile.gd")
const DEFAULT_PROFILE = preload("res://combat_pc/resources/contact_noise_profile.tres")
const REGISTRATION: StringName = &"_moksha_physics_contact_noise"

@export_node_path("RigidBody2D") var body_path := NodePath("..")
@export_node_path("Node") var event_bus_path := NodePath("")
@export var profile: ContactProfile = DEFAULT_PROFILE
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		_invalidate_pending()
@export var simulation_enabled := true:
	set(value):
		if simulation_enabled == value: return
		simulation_enabled = value
		_invalidate_pending()

var emitted_count := 0
var recent_receipts: Array[Dictionary]:
	get: return _recent_receipts.duplicate(true)
var last_event: Dictionary:
	get: return _last_event.duplicate(true)
var _body_ref: WeakRef
var _bus_ref: WeakRef
var _binding := 0
var _epoch := 0
var _serial := 0
var _diagnostics_epoch := 0
var _episodes: Dictionary = {}
var _pending: Dictionary = {}
var _recent_receipts: Array[Dictionary] = []
var _last_event: Dictionary = {}
var _sampling_active := false
var _reject_through_frame := -1
var _last_sample_frame := -1
var _state_sample_frame := -1
var _state_sleeping := true
var _sample_count := 0
var _queued_count := 0
var _rejected_count := 0
var _symmetric_suppressed_count := 0
var _capacity_reached_count := 0
var _last_contact_count := 0
var _owns_monitor := false
var _owns_capacity := false
var _old_capacity := 0
var _set_capacity := 0

func _ready() -> void:
	process_physics_priority = 120
	if _body() == null and not body_path.is_empty() and not event_bus_path.is_empty():
		bind_body(get_node_or_null(body_path) as RigidBody2D, get_node_or_null(event_bus_path))

func _exit_tree() -> void:
	unbind()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_invalidate_pending()

func _live(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()

func _body() -> RigidBody2D:
	return _body_ref.get_ref() as RigidBody2D if _body_ref != null else null

func _bus() -> Node:
	return _bus_ref.get_ref() as Node if _bus_ref != null else null

func _same_world(node: Node, body: RigidBody2D) -> bool:
	return _live(node) and _live(body) and node.get_tree() == body.get_tree() and node.get_viewport().world_2d == body.get_world_2d()

func _registered(body: RigidBody2D) -> MokshaPhysicsContactNoise:
	if not is_instance_valid(body) or not body.has_meta(REGISTRATION): return null
	var registration: Variant = body.get_meta(REGISTRATION, null)
	if not registration is WeakRef: return null
	var observer: Variant = registration.get_ref()
	if not is_instance_valid(observer) or not observer is MokshaPhysicsContactNoise: return null
	return observer if observer._body() == body and observer.is_inside_tree() else null

func bind_body(body: RigidBody2D, event_bus: Node, before_physics_step := false) -> bool:
	if not _live(self) or not _same_world(self, body) or not _same_world(event_bus, body): return false
	if not event_bus.has_method("emit_noise") or not event_bus.has_signal("noise_emitted"): return false
	var existing := _registered(body)
	# A disabled observer still owns its binding; attaching a second observer is
	# an explicit error rather than a hidden double-emission source.
	if existing != null and existing != self: return false
	if _body() == body and _bus() == event_bus: return true
	unbind()
	_body_ref = weakref(body)
	_bus_ref = weakref(event_bus)
	body.set_meta(REGISTRATION, weakref(self))
	_owns_monitor = not body.contact_monitor
	if _owns_monitor: body.contact_monitor = true
	_old_capacity = body.max_contacts_reported
	_set_capacity = maxi(_old_capacity, clampi(_tuning().max_contacts_reported, 1, 128))
	_owns_capacity = _set_capacity != _old_capacity
	if _owns_capacity: body.max_contacts_reported = _set_capacity
	reset_contact_history(before_physics_step)
	return true

func unbind() -> void:
	_binding += 1
	reset_contact_history()
	var body := _body()
	if is_instance_valid(body):
		if _registered(body) == self: body.remove_meta(REGISTRATION)
		# Restore only values this observer changed and which are still ours.
		if _owns_capacity and body.max_contacts_reported == _set_capacity: body.max_contacts_reported = _old_capacity
		if _owns_monitor and body.contact_monitor: body.contact_monitor = false
	_owns_monitor = false
	_owns_capacity = false
	_body_ref = null
	_bus_ref = null

func _invalidate_pending(before_physics_step := false, require_sample_fence := true) -> void:
	_epoch += 1
	_pending.clear()
	_sampling_active = false
	if require_sample_fence:
		# _physics_process reads the PREVIOUS completed solver step. Idle and
		# post-step deferred changes must reject the next callback's old report.
		# Engine.is_in_physics_frame() cannot distinguish pre/post-step queues.
		_reject_through_frame = Engine.get_physics_frames() + (0 if before_physics_step else 1)

func reset_contact_history(before_physics_step := false) -> void:
	# Call BEFORE a host teleport/reset. No pre-reset deferred receipt survives.
	# Pass true ONLY from a known host _physics_process before solver stepping.
	_invalidate_pending(before_physics_step)
	_episodes.clear()

func reset_diagnostics() -> void:
	_diagnostics_epoch += 1
	emitted_count = 0
	_sample_count = 0
	_queued_count = 0
	_rejected_count = 0
	_symmetric_suppressed_count = 0
	_capacity_reached_count = 0
	_last_event.clear()
	_recent_receipts.clear()

func _tuning() -> ContactProfile:
	return profile if profile != null else DEFAULT_PROFILE

func _valid_tuning() -> bool:
	var tuning := _tuning()
	for value in [tuning.minimum_closing_speed, tuning.loudness_speed_scale, tuning.minimum_loudness, tuning.maximum_loudness, tuning.quiet_closing_speed, tuning.quiet_rearm_seconds, tuning.separation_rearm_seconds]:
		if not is_finite(value): return false
	return not String(tuning.kind).is_empty() and tuning.minimum_closing_speed > 0.0 and tuning.loudness_speed_scale > 0.0 and tuning.minimum_loudness > 0.0 and tuning.maximum_loudness >= tuning.minimum_loudness and tuning.quiet_closing_speed >= 0.0 and tuning.quiet_closing_speed < tuning.minimum_closing_speed and tuning.quiet_rearm_seconds > 0.0 and tuning.separation_rearm_seconds > 0.0

func _eligible(require_awake := true) -> bool:
	var body := _body()
	if not enabled or not simulation_enabled or not _live(self) or not _same_world(self, body) or not _same_world(_bus(), body): return false
	if get_tree().paused or not can_process() or not is_physics_processing() or not body.can_process(): return false
	if body.freeze or not _valid_tuning(): return false
	# The scene sleeping property can lag the synchronized direct state by a
	# tick, including the exact impact that woke this body. Sampling must read
	# direct state first. Deferred/peer checks read the current server flag so
	# a callback putting the body to sleep also takes effect immediately.
	if not require_awake: return true
	return not bool(PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_SLEEPING))

func _physics_process(dt: float) -> void:
	if not _eligible(false):
		# Preserve disarmed episodes through sleep/freeze; retained sleeping
		# contact velocities must never become a fresh impact after waking.
		if _sampling_active: _invalidate_pending()
		return
	var frame := Engine.get_physics_frames()
	if frame <= _reject_through_frame: return
	if _last_sample_frame == frame or not is_finite(dt) or dt <= 0.0: return
	_last_sample_frame = frame
	var body := _body()
	# Exactly one direct-state read, in Godot's synchronized physics window.
	var state := PhysicsServer2D.body_get_direct_state(body.get_rid())
	if state == null: return
	_state_sample_frame = frame
	_state_sleeping = state.sleeping
	_sample_count += 1
	if _state_sleeping:
		# A passive wake may be the actual incoming impact. Preserve episode
		# history without applying another first-awake sampling fence.
		if _sampling_active: _invalidate_pending(false, false)
		return
	_sampling_active = true
	_last_contact_count = state.get_contact_count()
	if _last_contact_count >= body.max_contacts_reported: _capacity_reached_count += 1
	var contacts: Dictionary = {}
	for index in range(_last_contact_count):
		var other: Variant = state.get_contact_collider_object(index)
		if not other is Node or not _live(other) or other == body or not _same_world(other, body): continue
		var normal := state.get_contact_local_normal(index)
		var origin := state.get_contact_collider_position(index)
		var local_position := state.get_contact_local_position(index)
		var local_velocity := state.get_contact_local_velocity_at_position(index)
		var collider_velocity := state.get_contact_collider_velocity_at_position(index)
		if not normal.is_finite() or normal.is_zero_approx() or not origin.is_finite() or not local_position.is_finite() or not local_velocity.is_finite() or not collider_velocity.is_finite(): continue
		normal = normal.normalized()
		var relative_velocity := local_velocity - collider_velocity
		var closing_speed := maxf(0.0, -relative_velocity.dot(normal))
		if not relative_velocity.is_finite() or not is_finite(closing_speed): continue
		var collider_id: int = other.get_instance_id()
		var local_shape := state.get_contact_local_shape(index)
		var collider_shape := state.get_contact_collider_shape(index)
		var key := "%d:%d:%d" % [collider_id, local_shape, collider_shape]
		var count := int(contacts[key].contact_count) + 1 if contacts.has(key) else 1
		if contacts.has(key) and float(contacts[key].closing_speed) >= closing_speed:
			contacts[key].contact_count = count
			continue
		# Godot 4.6: these "local" names identify this body, not a coordinate
		# transform. Positions/normals are world-space; velocities already have
		# angular effects. The impulse is a pre-solve copied accumulator with
		# warm-start history,
		# so a fresh energetic impact may correctly report zero impulse.
		contacts[key] = {"collider_id": collider_id, "collider_name": str(other.name), "collider_ref": weakref(other),
			"local_shape": local_shape, "collider_shape": collider_shape, "origin": origin, "local_position": local_position,
			"normal": normal, "local_velocity": local_velocity, "collider_velocity": collider_velocity,
			"relative_velocity": relative_velocity, "closing_speed": closing_speed, "contact_count": count}
	_update_episodes(contacts, dt, frame)

func _update_episodes(contacts: Dictionary, dt: float, frame: int) -> void:
	var tuning := _tuning()
	for key in _episodes.keys():
		if contacts.has(key): continue
		var episode: Dictionary = _episodes[key]
		episode.separation_seconds += dt
		episode.quiet_seconds = 0.0
		if float(episode.separation_seconds) + 0.000001 >= tuning.separation_rearm_seconds:
			_episodes.erase(key)
	var candidates: Dictionary = {}
	for key in contacts:
		var contact: Dictionary = contacts[key]
		if not _episodes.has(key): _episodes[key] = {"armed": true, "quiet_seconds": 0.0, "separation_seconds": 0.0}
		var episode: Dictionary = _episodes[key]
		episode.separation_seconds = 0.0
		if float(contact.closing_speed) <= tuning.quiet_closing_speed:
			episode.quiet_seconds += dt
			if float(episode.quiet_seconds) + 0.000001 >= tuning.quiet_rearm_seconds: episode.armed = true
		else:
			episode.quiet_seconds = 0.0
		if not episode.armed or float(contact.closing_speed) < tuning.minimum_closing_speed: continue
		# Disarm both sides even if symmetric arbitration later chooses a peer.
		episode.armed = false
		candidates[key] = contact
	for key in candidates: _queue_candidate(candidates[key], frame)

func _queue_candidate(contact: Dictionary, frame: int) -> void:
	var body := _body()
	var tuning := _tuning()
	_serial += 1
	var receipt := contact.duplicate()
	var collider_ref: WeakRef = receipt.collider_ref
	receipt.erase("collider_ref")
	receipt.merge({"serial": _serial, "epoch": _epoch, "binding": _binding, "physics_frame": frame,
		"source_id": body.get_instance_id(), "body_id": body.get_instance_id(), "source_name": str(body.name),
		"kind": tuning.kind, "loudness": clampf(float(receipt.closing_speed) / tuning.loudness_speed_scale, tuning.minimum_loudness, tuning.maximum_loudness)})
	receipt.make_read_only()
	# This tiny shared claim survives either observer being removed in a bus
	# callback. It contains weak references and scalar receipts, never cycles.
	var arbitration := {"committed": false, "candidates": []}
	var other: Variant = collider_ref.get_ref()
	var peer := _registered(other) if other is RigidBody2D else null
	if peer != null and peer._bus() == _bus() and peer._eligible():
		for ticket in peer._pending.values():
			var peer_receipt: Dictionary = ticket.receipt
			if int(peer_receipt.physics_frame) == frame and int(peer_receipt.collider_id) == body.get_instance_id() and int(peer_receipt.local_shape) == int(receipt.collider_shape) and int(peer_receipt.collider_shape) == int(receipt.local_shape):
				arbitration = ticket.arbitration
				break
	arbitration.candidates.append({"observer": weakref(self), "receipt": receipt})
	_pending[_serial] = {"receipt": receipt, "arbitration": arbitration, "collider_ref": collider_ref}
	_queued_count += 1
	_deliver_pending.call_deferred(_serial, _epoch, _binding)

func _receipt_live(receipt: Dictionary) -> bool:
	return _eligible() and int(receipt.epoch) == _epoch and int(receipt.binding) == _binding and int(receipt.source_id) == _body().get_instance_id() and _pending.has(int(receipt.serial))

func _deliver_pending(serial: int, epoch: int, binding: int) -> void:
	if epoch != _epoch or binding != _binding or not _pending.has(serial): return
	var ticket: Dictionary = _pending[serial]
	var receipt: Dictionary = ticket.receipt
	var arbitration: Dictionary = ticket.arbitration
	if arbitration.committed:
		_symmetric_suppressed_count += 1
		_pending.erase(serial)
		return
	var winner: MokshaPhysicsContactNoise
	var winning_receipt: Dictionary = {}
	for candidate in arbitration.candidates:
		var observer: Variant = candidate.observer.get_ref()
		if not is_instance_valid(observer) or not observer._receipt_live(candidate.receipt): continue
		if winner == null or int(candidate.receipt.source_id) < int(winning_receipt.source_id):
			winner = observer
			winning_receipt = candidate.receipt
	if winner == null:
		_rejected_count += 1
		_pending.erase(serial)
		return
	if winner != self:
		# Still outside locked physics. Deliver the elected live owner now, so
		# yielding a duplicate never depends on a later callback staying alive.
		winner._deliver_pending(int(winning_receipt.serial), int(winning_receipt.epoch), int(winning_receipt.binding))
		if epoch == _epoch and binding == _binding and _pending.has(serial):
			_symmetric_suppressed_count += 1
			_pending.erase(serial)
		return
	var body := _body()
	var event_bus := _bus()
	var collider: Variant = ticket.collider_ref.get_ref()
	if not collider is Node or not _same_world(collider, body):
		_rejected_count += 1
		_pending.erase(serial)
		return
	arbitration.committed = true
	_pending.erase(serial)
	var diagnostics_epoch := _diagnostics_epoch
	# Commit before external callbacks. Exact receipts may arrive out of serial
	# order during reentrancy; there is intentionally no highest-serial filter.
	emitted_count += 1
	_last_event = receipt.duplicate(true)
	_recent_receipts.append(receipt)
	while _recent_receipts.size() > clampi(_tuning().recent_receipt_limit, 0, 256): _recent_receipts.pop_front()
	event_bus.emit_noise(receipt.origin, StringName(receipt.kind), float(receipt.loudness), body)
	if not is_instance_valid(self): return
	if epoch != _epoch or binding != _binding or diagnostics_epoch != _diagnostics_epoch or not _eligible(): return
	if _body() != body or _bus() != event_bus: return
	impact_emitted.emit(receipt)

func debug_snapshot() -> Dictionary:
	var body := _body()
	var event_bus := _bus()
	return {"bound": _live(body) and _live(event_bus), "enabled": enabled, "simulation_enabled": simulation_enabled,
		"body_id": body.get_instance_id() if is_instance_valid(body) else 0, "bus_id": event_bus.get_instance_id() if is_instance_valid(event_bus) else 0,
		"binding": _binding, "epoch": _epoch, "emitted_count": emitted_count, "sample_count": _sample_count,
		"reject_through_frame": _reject_through_frame,
		"queued_count": _queued_count, "pending_count": _pending.size(), "rejected_count": _rejected_count,
		"symmetric_suppressed_count": _symmetric_suppressed_count, "capacity_reached_count": _capacity_reached_count,
		"last_sample_frame": _last_sample_frame, "last_contact_count": _last_contact_count, "episode_count": _episodes.size(),
		"state_sample_frame": _state_sample_frame, "state_sleeping": _state_sleeping,
		"last_event": last_event, "recent_receipts": recent_receipts}
