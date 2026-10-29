class_name MokshaCharacterFootsteps
extends Node
## Optional, explicitly bracketed observer. It never moves its CharacterBody2D.
## A host must bracket one REAL move_and_slide, not poll retained motion data.
signal footstep_emitted(event: Dictionary)

const FootstepProfile = preload("res://combat_pc/resources/footstep_profile.gd")
const DEFAULT_PROFILE = preload("res://combat_pc/resources/footstep_profile.tres")
const REGISTRATION: StringName = &"_moksha_character_footsteps"

@export_node_path("CharacterBody2D") var body_path := NodePath("..")
@export_node_path("Node") var event_bus_path := NodePath("")
@export var profile: FootstepProfile = DEFAULT_PROFILE
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		reset_history()
@export var simulation_enabled := true:
	set(value):
		if simulation_enabled == value: return
		simulation_enabled = value
		reset_history()

var emitted_count := 0
var stride_distance: float:
	get: return _stride_distance
var stride_phase: float:
	get: return _stride_distance / maxf(1.0, _tuning().step_spacing)
var last_event: Dictionary:
	get: return _last_event.duplicate(true)
var recent_receipts: Array[Dictionary]:
	get: return _recent_receipts.duplicate(true)
var _body_ref: WeakRef
var _bus_ref: WeakRef
var _binding := 0
var _epoch := 0
var _motion_serial := 0
var _event_serial := 0
var _diagnostics_epoch := 0
var _pending: Dictionary = {}
var _support: Dictionary = {}
var _stride_distance := 0.0
var _total_ground_distance := 0.0
var _air_seconds := 0.0
var _air_origin := Vector2.ZERO
var _air_travel := 0.0
var _air_active := false
var _motion_suspended := false
var _suspended_position := Vector2.ZERO
var _suspended_world_id := 0
var _last_sample_frame := -1
var _sample_count := 0
var _rejected_count := 0
var _last_reason := "Unbound"
var _last_relative_travel := 0.0
var _last_support_motion := Vector2.ZERO
var _last_event: Dictionary = {}
var _recent_receipts: Array[Dictionary] = []

func _ready() -> void:
	if _body() == null and not body_path.is_empty() and not event_bus_path.is_empty():
		bind_body(get_node_or_null(body_path) as CharacterBody2D, get_node_or_null(event_bus_path))

func _exit_tree() -> void:
	unbind()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		suspend_motion()

func _live(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()

func _body() -> CharacterBody2D:
	return _body_ref.get_ref() as CharacterBody2D if _body_ref != null else null

func _bus() -> Node:
	return _bus_ref.get_ref() as Node if _bus_ref != null else null

func _same_world(node: Node, body: CharacterBody2D) -> bool:
	return _live(node) and _live(body) and node.get_tree() == body.get_tree() and node.get_viewport().world_2d == body.get_world_2d()

func _registered(body: CharacterBody2D) -> MokshaCharacterFootsteps:
	if not is_instance_valid(body) or not body.has_meta(REGISTRATION): return null
	var registration: Variant = body.get_meta(REGISTRATION, null)
	if not registration is WeakRef: return null
	var observer: Variant = registration.get_ref()
	if not is_instance_valid(observer) or not observer is MokshaCharacterFootsteps: return null
	return observer if observer._body() == body and observer.is_inside_tree() else null

func bind_body(body: CharacterBody2D, event_bus: Node) -> bool:
	if not _live(self) or not _same_world(self, body) or not _same_world(event_bus, body): return false
	if not event_bus.has_method("emit_noise") or not event_bus.has_signal("noise_emitted"): return false
	var owner := _registered(body)
	if owner != null and owner != self: return false
	if _body() == body and _bus() == event_bus: return true
	unbind()
	_body_ref = weakref(body)
	_bus_ref = weakref(event_bus)
	body.set_meta(REGISTRATION, weakref(self))
	_last_reason = "Bound; awaiting actual motion"
	return true

func unbind() -> void:
	_binding += 1
	reset_history()
	var body := _body()
	if is_instance_valid(body) and _registered(body) == self: body.remove_meta(REGISTRATION)
	_body_ref = null
	_bus_ref = null
	_last_reason = "Unbound"

func _fence_motion() -> void:
	_epoch += 1
	_pending.clear()
	_support.clear()
	_stride_distance = 0.0
	_last_sample_frame = -1
	_last_relative_travel = 0.0
	_last_support_motion = Vector2.ZERO

func reset_history() -> void:
	# Invoke BEFORE teleport/reset, impulse or replacing the mover. A real
	# motion freeze uses suspend_motion instead, preserving an existing flight.
	_fence_motion()
	_total_ground_distance = 0.0
	_clear_air()
	_motion_suspended = false
	_last_reason = "History fenced"

func suspend_motion() -> void:
	# A pause is not a new airborne episode. Fence any in-flight receipt and
	# discard ground stride/carry history, but retain measured flight evidence.
	# Repeated paused ticks and UNPAUSED must not overwrite the original anchor.
	var body := _body()
	if not _live(body):
		reset_history()
		return
	if not _motion_suspended:
		_suspended_position = body.global_position
		_suspended_world_id = body.get_world_2d().get_instance_id()
		_motion_suspended = true
	_fence_motion()
	_last_reason = "Motion frozen; flight retained"

func reset_diagnostics() -> void:
	_diagnostics_epoch += 1
	emitted_count = 0
	_sample_count = 0
	_rejected_count = 0
	_last_event.clear()
	_recent_receipts.clear()

func _tuning() -> FootstepProfile:
	return profile if profile != null else DEFAULT_PROFILE

func _valid_tuning() -> bool:
	var p := _tuning()
	for value in [p.step_spacing, p.minimum_speed, p.step_loudness, p.minimum_landing_speed, p.landing_speed_scale, p.minimum_landing_loudness, p.maximum_landing_loudness, p.minimum_air_seconds, p.minimum_air_travel, p.probe_above, p.probe_below, p.maximum_sample_seconds, p.maximum_sample_travel]:
		if not is_finite(value) or value <= 0.0: return false
	return p.sole_offset.is_finite() and is_finite(p.probe_half_width) and p.probe_half_width >= 0.0 and p.maximum_landing_loudness >= p.minimum_landing_loudness and not String(p.step_kind).is_empty() and not String(p.landing_kind).is_empty()

func _eligible() -> bool:
	var body := _body()
	return enabled and simulation_enabled and _same_world(self, body) and _same_world(_bus(), body) and not get_tree().paused and can_process() and body.can_process() and _valid_tuning()

func begin_motion_sample(dt: float, ordinary_locomotion: bool) -> int:
	if _live(self) and get_tree().paused:
		suspend_motion()
		return 0
	if not _eligible() or not is_finite(dt) or dt <= 0.0 or dt > _tuning().maximum_sample_seconds:
		reset_history()
		return 0
	var frame := Engine.get_physics_frames()
	if frame == _last_sample_frame or not _pending.is_empty():
		_rejected_count += 1
		return 0
	var body := _body()
	if _motion_suspended:
		# Unobserved movement/teleport or a world replacement is not a frozen
		# flight. It must not carry old landing qualification into a new place.
		if not body.global_position.is_equal_approx(_suspended_position) or body.get_world_2d().get_instance_id() != _suspended_world_id:
			reset_history()
		_motion_suspended = false
	elif _last_sample_frame >= 0 and frame != _last_sample_frame + 1:
		reset_history()
	# This component's support probes are for an upright, unscaled actor.
	if not body.global_transform.x.is_equal_approx(Vector2.RIGHT) or not body.global_transform.y.is_equal_approx(Vector2.DOWN) or not body.up_direction.is_equal_approx(Vector2.UP):
		_last_reason = "Unsupported actor transform/up direction"
		return 0
	_motion_serial += 1
	var grounded := body.is_on_floor()
	var prior_support := _support if grounded else {}
	if grounded and prior_support.is_empty(): prior_support = _find_support(body)
	var carry := _sample_carry(body, prior_support, dt) if grounded else {"valid": true, "travel": Vector2.ZERO}
	_pending = {"token": _motion_serial, "epoch": _epoch, "binding": _binding, "frame": frame, "dt": dt,
		"body_id": body.get_instance_id(), "position": body.global_position, "grounded": grounded,
		"ordinary": ordinary_locomotion, "carry_valid": bool(carry.valid), "carry": Vector2(carry.travel), "landing_speed": 0.0}
	return _motion_serial

func capture_landing(speed: float) -> void:
	# Call only from a real motor landing signal inside the bracketed motion.
	if _pending.is_empty() or not _eligible() or not is_finite(speed): return
	_pending.landing_speed = maxf(float(_pending.landing_speed), speed)

func finish_motion_sample(token: int, ordinary_locomotion: bool) -> void:
	if token <= 0 or _pending.is_empty() or int(_pending.token) != token: return
	var sample := _pending.duplicate()
	_pending.clear()
	if not _eligible() or int(sample.epoch) != _epoch or int(sample.binding) != _binding or int(sample.body_id) != _body().get_instance_id() or int(sample.frame) != Engine.get_physics_frames(): return
	var body := _body()
	var p := _tuning()
	_last_sample_frame = int(sample.frame)
	_sample_count += 1
	var movement := body.global_position - Vector2(sample.position)
	if not movement.is_finite() or movement.length() > p.maximum_sample_travel:
		reset_history()
		_rejected_count += 1
		_last_reason = "Motion discontinuity"
		return
	var grounded := body.is_on_floor()
	var contact := _find_support(body) if grounded else {}
	_support = contact
	_last_relative_travel = 0.0
	_last_support_motion = Vector2(sample.carry)
	if not bool(sample.grounded) or not grounded:
		if not _air_active:
			_air_active = true
			_air_origin = Vector2(sample.position)
		_air_seconds += float(sample.dt)
		_air_travel = maxf(_air_travel, absf(body.global_position.y - _air_origin.y))
	if grounded and not bool(sample.grounded):
		var real_landing := _air_active and _air_seconds >= p.minimum_air_seconds and _air_travel >= p.minimum_air_travel and float(sample.landing_speed) >= p.minimum_landing_speed
		_stride_distance = 0.0
		_clear_air()
		_last_reason = "Landed" if real_landing else "Quiet initial/short ground settle"
		if real_landing and not contact.is_empty():
			_emit_contact(contact, sample, p.landing_kind, clampf(float(sample.landing_speed) / p.landing_speed_scale, p.minimum_landing_loudness, p.maximum_landing_loudness), 0.0, 0.0)
		return
	if not grounded:
		_stride_distance = 0.0
		_last_reason = "Airborne"
		return
	_clear_air()
	if contact.is_empty() or not bool(sample.carry_valid):
		_stride_distance = 0.0
		_last_reason = "No unambiguous supported contact/carry"
		return
	if not bool(sample.ordinary) or not ordinary_locomotion:
		_stride_distance = 0.0
		_last_reason = "Non-locomotion motion"
		return
	var normal: Vector2 = contact.normal
	var tangent := Vector2(-normal.y, normal.x)
	var relative := movement - Vector2(sample.carry)
	var signed_distance := relative.dot(tangent)
	var distance := absf(signed_distance)
	var speed := distance / float(sample.dt)
	var driven_speed := body.velocity.dot(tangent)
	# Actual support-relative travel AND remaining ordinary motor motion must
	# agree. Wall pushing and passive carry cannot build stride distance.
	if speed < p.minimum_speed or absf(driven_speed) < p.minimum_speed or signed_distance * driven_speed <= 0.0:
		_stride_distance = 0.0
		_last_reason = "Idle / blocked / carried only"
		return
	_last_relative_travel = distance
	_stride_distance += distance
	_total_ground_distance += distance
	_last_reason = "Grounded locomotion"
	if _stride_distance + 0.00001 < p.step_spacing: return
	_stride_distance = fmod(_stride_distance, p.step_spacing)
	_emit_contact(contact, sample, p.step_kind, p.step_loudness, distance, speed)

func _clear_air() -> void:
	_air_active = false
	_air_seconds = 0.0
	_air_travel = 0.0
	_air_origin = Vector2.ZERO

func _find_support(body: CharacterBody2D) -> Dictionary:
	if not body.is_on_floor(): return {}
	var p := _tuning()
	var floor_normal := body.get_floor_normal()
	var floor_dot := cos(body.floor_max_angle + 0.001)
	var preferred_id := 0
	# The slide list may be empty after floor snap. Otherwise constrain the
	# probe to a floor collision with the actual reported floor normal.
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		if collision.get_normal().dot(Vector2.UP) >= floor_dot and collision.get_normal().dot(floor_normal) > 0.995:
			if preferred_id != 0 and preferred_id != collision.get_collider_id(): return {}
			preferred_id = collision.get_collider_id()
	var sole := body.to_global(p.sole_offset)
	var best: Dictionary = {}
	var best_distance := INF
	var probed_id := 0
	for offset in [0.0, -p.probe_half_width, p.probe_half_width]:
		var toe := sole + Vector2(float(offset), 0.0)
		var query := PhysicsRayQueryParameters2D.create(toe + Vector2.UP * p.probe_above, toe + Vector2.DOWN * p.probe_below, body.collision_mask, [body.get_rid()])
		query.collide_with_areas = false
		var hit := body.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		var support: Variant = hit.collider
		var normal: Vector2 = hit.normal
		if not support is PhysicsBody2D or not _same_world(support, body) or support is CharacterBody2D: continue
		if preferred_id != 0 and support.get_instance_id() != preferred_id: continue
		if not normal.is_finite() or normal.dot(Vector2.UP) < floor_dot or normal.dot(floor_normal) < 0.995: continue
		if probed_id != 0 and probed_id != support.get_instance_id(): return {}
		probed_id = support.get_instance_id()
		var point: Vector2 = hit.position
		var distance := point.distance_squared_to(sole)
		if distance >= best_distance: continue
		best_distance = distance
		best = {"ref": weakref(support), "rid": hit.rid, "support_id": support.get_instance_id(), "support_name": str(support.name),
			"origin": point, "normal": normal, "shape": int(hit.shape), "transform": support.global_transform}
	if not best.is_empty():
		# Apply the translation-only boundary to touchdown as well as cadence.
		var state := PhysicsServer2D.body_get_direct_state(best.rid)
		if state == null or absf(state.angular_velocity) > 0.0001: return {}
	return best

func _sample_carry(body: CharacterBody2D, support: Dictionary, dt: float) -> Dictionary:
	var refused := {"valid": false, "travel": Vector2.ZERO}
	if support.is_empty(): return refused
	var other: Variant = support.ref.get_ref()
	if not other is PhysicsBody2D or not _same_world(other, body): return refused
	# A wall contact can overwrite Godot's private platform RID even when
	# platform_wall_layers is zero. Floor+wall ownership is not recoverable
	# from our floor probe, so discard this transition's cadence.
	if body.is_on_wall(): return refused
	# Match CharacterBody2D's previous-floor platform mask and fresh direct
	# state point velocity. The public get_platform_velocity is a cached value.
	if (other.collision_layer & body.platform_floor_layers) == 0: return {"valid": true, "travel": Vector2.ZERO}
	var state := PhysicsServer2D.body_get_direct_state(support.rid)
	if state == null or absf(state.angular_velocity) > 0.0001: return refused
	var old_transform: Transform2D = support.transform
	if not old_transform.x.is_equal_approx(other.global_transform.x) or not old_transform.y.is_equal_approx(other.global_transform.y): return refused
	var velocity := state.get_velocity_at_local_position(body.global_position - state.transform.origin)
	if not velocity.is_finite(): return refused
	if velocity.is_zero_approx(): return {"valid": true, "travel": Vector2.ZERO}
	# Exact read-only counterpart of the engine's pre-slide platform move.
	# Subtract clipped carry travel, not requested velocity * dt at a wall.
	var parameters := PhysicsTestMotionParameters2D.new()
	parameters.from = body.global_transform
	parameters.motion = velocity * dt
	parameters.margin = body.safe_margin
	parameters.recovery_as_collision = true
	parameters.exclude_bodies = [support.rid]
	parameters.exclude_objects = [other.get_instance_id()]
	var result := PhysicsTestMotionResult2D.new()
	PhysicsServer2D.body_test_motion(body.get_rid(), parameters, result)
	return {"valid": true, "travel": result.get_travel()}

func _emit_contact(contact: Dictionary, sample: Dictionary, kind: StringName, loudness: float, distance: float, speed: float) -> void:
	var body := _body()
	var event_bus := _bus()
	var other: Variant = contact.ref.get_ref()
	if not _eligible() or not other is PhysicsBody2D or not _same_world(other, body): return
	_event_serial += 1
	var epoch := _epoch
	var binding := _binding
	var diagnostics_epoch := _diagnostics_epoch
	var receipt := {"serial": _event_serial, "epoch": epoch, "binding": binding, "physics_frame": int(sample.frame),
		"body_id": body.get_instance_id(), "source_id": body.get_instance_id(), "source_name": str(body.name),
		"kind": kind, "origin": Vector2(contact.origin), "normal": Vector2(contact.normal), "loudness": loudness,
		"relative_distance": distance, "relative_speed": speed, "landing_speed": float(sample.landing_speed),
		"support_id": int(contact.support_id), "support_name": str(contact.support_name), "support_shape": int(contact.shape),
		"support_motion": Vector2(sample.carry), "stride_distance": _stride_distance, "total_ground_distance": _total_ground_distance, "foot_index": (_event_serial - 1) % 2}
	receipt.make_read_only()
	# Commit all source state before invoking arbitrary external callbacks.
	# There is no deferred emission queue, so a reset cannot release old noise.
	emitted_count += 1
	_last_event = receipt.duplicate(true)
	_recent_receipts.append(receipt)
	while _recent_receipts.size() > clampi(_tuning().recent_receipt_limit, 0, 256): _recent_receipts.pop_front()
	event_bus.emit_noise(receipt.origin, kind, loudness, body)
	if not is_instance_valid(self): return
	if epoch != _epoch or binding != _binding or diagnostics_epoch != _diagnostics_epoch or not _eligible(): return
	if _body() != body or _bus() != event_bus: return
	footstep_emitted.emit(receipt)

func debug_snapshot() -> Dictionary:
	var body := _body()
	var event_bus := _bus()
	return {"bound": _live(body) and _live(event_bus), "enabled": enabled, "simulation_enabled": simulation_enabled,
		"body_id": body.get_instance_id() if is_instance_valid(body) else 0, "bus_id": event_bus.get_instance_id() if is_instance_valid(event_bus) else 0,
		"epoch": _epoch, "binding": _binding, "emitted_count": emitted_count, "sample_count": _sample_count,
		"rejected_count": _rejected_count, "pending_count": 0 if _pending.is_empty() else 1, "last_sample_frame": _last_sample_frame,
		"stride_distance": stride_distance, "stride_phase": stride_phase, "total_ground_distance": _total_ground_distance, "air_seconds": _air_seconds, "air_travel": _air_travel,
		"motion_suspended": _motion_suspended,
		"last_relative_travel": _last_relative_travel, "last_support_motion": _last_support_motion,
		"support_id": int(_support.get("support_id", 0)), "reason": _last_reason, "last_event": last_event, "recent_receipts": recent_receipts}
