class_name MokshaContactAdapter
extends Node2D
## Physics contact boundary. Legacy fixture/prop/enemy receivers stay supported.
## Opt-in receivers additionally require an exact, synchronous contact permit.
class PauseFence extends Node:
	var retire: Callable
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and retire.is_valid(): retire.call()
signal contact_confirmed(actor: Node2D, target: Node2D, position: Vector2, serial: int, kind: StringName)
@export_flags_2d_physics var target_mask := 12:
	set(value):
		if target_mask == value: return
		target_mask = value
		_retire()
@export_flags_2d_physics var obstruction_mask := 1:
	set(value):
		if obstruction_mask == value: return
		obstruction_mask = value
		_retire()
@export_range(1.0, 12.0, 0.5) var sweep_spacing := 3.0:
	set(value):
		if sweep_spacing == value: return
		sweep_spacing = value
		_retire()
@export var actor_path := NodePath("..")
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		_retire()
var actor: Node2D
var _serial := -1
var _visited: Dictionary = {}
var _binding := 0
var _sampling := false
var _ticket := 0
var _delivery_scope: Dictionary = {}
var _pause_fence: Node
var confirmed_contacts := 0
var occluded_contacts := 0

func _ready() -> void:
	# Explicit PAUSABLE processing observes tree transitions even beneath an
	# ALWAYS host. A pause/resume callback cannot restore an old permit.
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
func bind_actor(value: Node2D) -> void:
	_retire()
	if is_instance_valid(actor) and actor.has_signal("strike_sample") and actor.strike_sample.is_connected(sample_strike):
		actor.strike_sample.disconnect(sample_strike)
	actor = value
	_serial = -1
	_visited.clear()
	if is_instance_valid(actor) and actor.has_signal("strike_sample"): actor.strike_sample.connect(sample_strike)
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
func _source_live(source: Variant) -> bool:
	return _live(self) and _live(_pause_fence) and _pause_fence.get_parent() == self and _pause_fence.process_mode == Node.PROCESS_MODE_PAUSABLE and enabled and can_process() and not get_tree().paused and _live(source) and source == actor \
		and source.can_process() and source.is_physics_processing() and source.get_viewport().world_2d == get_world_2d()
func _source_epoch(source: Node) -> int:
	return int(source.damage_generation()) if source.has_method("damage_generation") else -1
func _current(source: Variant, serial: int, binding: int, epoch: int) -> bool:
	if binding != _binding or not _source_live(source) or not source.has_method("is_strike_current"): return false
	var current: bool = source.is_strike_current(serial)
	return current and binding == _binding and _source_live(source) and _source_epoch(source) == epoch
func _canonical_matches(packet: Dictionary, canonical: Dictionary) -> bool:
	for key in ["serial", "phase", "eligible", "center", "previous_center", "origin", "size", "facing", "damage", "impulse", "prop_launch_scale"]:
		if not packet.has(key) or packet[key] != canonical.get(key): return false
	return true
func _target_current(target: Variant, token: Dictionary) -> bool:
	return _live(target) and target.has_method("strike_generation_is_current") and target.strike_generation_is_current(token)
func contact_is_current(packet: Dictionary, receiver: Node) -> bool:
	if _delivery_scope.is_empty() or not _sampling or not _live(receiver): return false
	for key in ["contact_ticket", "source", "source_epoch", "serial", "receiver_generation", "contact_position", "source_position", "damage", "impulse", "facing", "prop_launch_scale"]:
		if packet.get(key) != _delivery_scope.get(key): return false
	if receiver != _delivery_scope.receiver or packet.get("contact_adapter") != self: return false
	var binding: int = _delivery_scope.adapter_binding
	var source: Node2D = _delivery_scope.source
	var serial: int = _delivery_scope.serial
	var epoch: int = _delivery_scope.source_epoch
	return _target_current(receiver, packet.receiver_generation) and _current(source, serial, binding, epoch)
# Observation only after a committed operation: counter recoil may cancel the
# source's strike, but cannot erase the defender's completed parry receipt. This
# never authorizes a response or resumes the sampled sweep.
func contact_receipt_is_current(packet: Dictionary, receiver: Node) -> bool:
	if _delivery_scope.is_empty() or not _sampling or not _live(receiver): return false
	for key in ["contact_ticket", "source", "source_epoch", "serial", "receiver_generation", "contact_position", "source_position", "damage", "impulse", "facing", "prop_launch_scale"]:
		if packet.get(key) != _delivery_scope.get(key): return false
	if receiver != _delivery_scope.receiver or packet.get("contact_adapter") != self or _delivery_scope.adapter_binding != _binding: return false
	var source: Node2D = _delivery_scope.source
	var binding: int = _delivery_scope.adapter_binding
	if not _source_live(source) or _source_epoch(source) != packet.source_epoch or not _target_current(receiver, packet.receiver_generation): return false
	# Target observation hooks cannot retire and restore a source permit.
	return binding == _binding and not _delivery_scope.is_empty() and _source_live(source) and _source_epoch(source) == packet.source_epoch
func sample_strike(source: Node2D, strike: Dictionary) -> void:
	if _sampling or not _source_live(source) or not bool(strike.get("eligible", false)) or str(strike.get("phase", "")) != "active": return
	if not source.has_method("confirm_strike"): return
	var serial := int(strike.get("serial", -1))
	var binding := _binding
	var epoch := _source_epoch(source)
	if serial < 0 or not _current(source, serial, binding, epoch): return
	_sampling = true
	_sample(source, strike, serial, binding, epoch)
	_delivery_scope.clear()
	_sampling = false
func _sample(source: Node2D, strike: Dictionary, serial: int, binding: int, epoch: int) -> void:
	# Snapshot before confirmation starts hitpause. Only opt-in bridges require
	# this API; older explicit receiver contracts remain compatible.
	var canonical: Dictionary = source.strike_snapshot().duplicate(true) if source.has_method("strike_snapshot") else {}
	var canonical_valid := not canonical.is_empty() and _canonical_matches(strike, canonical)
	if not _current(source, serial, binding, epoch): return
	if not canonical.is_empty() and not canonical_valid: return
	if serial != _serial:
		_serial = serial
		_visited.clear()
	var current: Vector2 = strike.get("center", source.global_position)
	var previous: Vector2 = strike.get("previous_center", current)
	var origin: Vector2 = strike.get("origin", source.global_position)
	var size: Vector2 = strike.get("size", Vector2.ONE)
	if not current.is_finite() or not previous.is_finite() or not origin.is_finite() or not size.is_finite(): return
	var direction := -1 if int(strike.get("facing", 1)) < 0 else 1
	var box := RectangleShape2D.new()
	box.size = Vector2(maxf(1, size.x), maxf(1, size.y))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.collision_mask = target_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if source is CollisionObject2D: query.exclude = [source.get_rid()]
	var steps := maxi(1, ceili(previous.distance_to(current) / maxf(1, sweep_spacing)))
	for step in range(steps + 1):
		if not _current(source, serial, binding, epoch): return
		var center := previous.lerp(current, float(step) / steps)
		var sample_origin := origin + (center - current)
		query.transform = Transform2D(0, center)
		for hit in source.get_world_2d().direct_space_state.intersect_shape(query, 64):
			if not _current(source, serial, binding, epoch): return
			var target := hit.collider as CollisionObject2D
			if not _live(target) or target == source or source.is_ancestor_of(target): continue
			var id := target.get_instance_id()
			if _visited.has(id): continue
			var kind := _target_kind(target)
			if kind == &"": continue
			var opt_in := target.has_method("capture_strike_generation")
			if opt_in and (not canonical_valid or epoch < 0): continue
			var token: Dictionary = target.capture_strike_generation() if opt_in else {}
			if not _current(source, serial, binding, epoch): return
			if not _live(target) or (opt_in and (token.is_empty() or not _target_current(target, token))): continue
			if not _current(source, serial, binding, epoch): return
			var bounds := _shape_bounds(target, int(hit.shape))
			var overlap := bounds.intersection(Rect2(center - size * 0.5, size))
			if not overlap.has_area(): continue
			var point := Vector2(clampf(sample_origin.x + direction * 0.02, overlap.position.x, overlap.end.x), clampf(sample_origin.y, overlap.position.y, overlap.end.y))
			if (point.x - sample_origin.x) * direction <= 0.01: continue
			var exclude: Array[RID] = [target.get_rid()]
			if source is CollisionObject2D: exclude.append(source.get_rid())
			var ray := PhysicsRayQueryParameters2D.create(sample_origin, point, obstruction_mask, exclude)
			ray.hit_from_inside = true
			if not source.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				occluded_contacts += 1
				continue
			# Stable actor identity prevents a replacement child hurtbox receiving
			# another confirmation/hitpause from the same live strike.
			var confirm_id := int(token.get("host_id", id)) if opt_in else id
			if _visited.has(confirm_id): continue
			if not source.confirm_strike(serial, confirm_id, point): continue
			if not _current(source, serial, binding, epoch): return
			if not _live(target) or _target_kind(target) != kind: continue
			if opt_in and not _target_current(target, token): continue
			if not _current(source, serial, binding, epoch): return
			_visited[confirm_id] = true
			var payload := (canonical if opt_in else strike).duplicate(true)
			payload.merge({"contact_position": point, "source": source, "source_position": sample_origin}, true)
			if opt_in:
				_ticket += 1
				payload.merge({"contact_adapter": self, "contact_ticket": _ticket, "source_epoch": epoch, "receiver_generation": token}, true)
				_delivery_scope = payload.duplicate(true)
				_delivery_scope.merge({"receiver": target, "adapter_binding": binding})
				payload.make_read_only()
			if kind == &"fixture": target.receive_strike(payload)
			elif kind == &"prop": target.launch(direction, float(strike.get("prop_launch_scale", 1.0)))
			elif kind == &"enemy": target.take_hit(int(strike.get("damage", 1)), direction)
			_delivery_scope.clear()
			confirmed_contacts += 1 # Physical dispatches, not guaranteed health debits.
			if not _current(source, serial, binding, epoch): return
			if opt_in and (not _live(target) or not _target_current(target, token)): return
			if not _live(target): continue
			if not _current(source, serial, binding, epoch): return
			contact_confirmed.emit(source, target, point, serial, kind)
			if not _current(source, serial, binding, epoch): return
func _target_kind(target: Node) -> StringName:
	if target.has_method("receive_strike"): return &"fixture"
	if target.is_in_group("props") and target.has_method("launch") and target.get("alive") != false: return &"prop"
	if target.is_in_group("enemies") and target.has_method("take_hit") and target.get("active") != false: return &"enemy"
	return &""
func _shape_bounds(body: CollisionObject2D, index: int) -> Rect2:
	var owner_id := body.shape_find_owner(index)
	for local_index in range(body.shape_owner_get_shape_count(owner_id)):
		if body.shape_owner_get_shape_index(owner_id, local_index) == index:
			var shape := body.shape_owner_get_shape(owner_id, local_index)
			return (body.global_transform * body.shape_owner_get_transform(owner_id)) * shape.get_rect()
	return Rect2(body.global_position - Vector2.ONE, Vector2.ONE * 2)
