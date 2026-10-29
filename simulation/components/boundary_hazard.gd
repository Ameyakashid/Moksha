class_name MokshaBoundaryHazard
extends Node2D
## Non-solid geometric world constraint. The configured witness point is unsafe
## strictly below local y=0. This observes positions, not shape-overlap contact.
signal boundary_observed(receipt: Dictionary)
enum InitialOutside { OCCUPANCY, REQUIRE_INSIDE_FIRST }
@export_node_path("Node2D") var scope_path := NodePath(".."):
	set(value):
		if scope_path != value: scope_path = value; _invalidate()
@export var enabled := true:
	set(value):
		if enabled != value: enabled = value; _invalidate()
@export var initial_outside: InitialOutside = InitialOutside.OCCUPANCY:
	set(value):
		if initial_outside != value: initial_outside = value; _invalidate()
@export var profile: MokshaBoundaryProfile:
	set(value):
		if profile == value: return
		if profile != null and profile.changed.is_connected(_invalidate): profile.changed.disconnect(_invalidate)
		profile = value
		if profile != null: profile.changed.connect(_invalidate)
		_invalidate()
@export var debug_draw := false
@export var debug_width := 640.0
var _epoch := 0
var _sequence := 0
var _sampling := false
var _observations: Dictionary = {}
var _scope: Dictionary = {}
var _watched_scopes: Array[WeakRef] = []
var observations := 0
var resolutions := 0
var last_receipt: Dictionary = {}
func _ready() -> void:
	process_physics_priority = 100
	profile = profile.duplicate(true) if profile != null else MokshaBoundaryProfile.new()
	set_notify_transform(true)
	set_notify_local_transform(true)
	_connect_scopes()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED, NOTIFICATION_EXIT_TREE, NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_LOCAL_TRANSFORM_CHANGED, NOTIFICATION_ENTER_CANVAS, NOTIFICATION_EXIT_CANVAS, NOTIFICATION_WORLD_2D_CHANGED]: _invalidate()
func _exit_tree() -> void:
	_disconnect_scopes()
	request_ready()
func _disconnect_scopes() -> void:
	for reference in _watched_scopes:
		var node: Variant=reference.get_ref()
		if is_instance_valid(node) and node.boundary_scope_invalidated.is_connected(_invalidate): node.boundary_scope_invalidated.disconnect(_invalidate)
	_watched_scopes.clear()
func _connect_scopes() -> void:
	_disconnect_scopes()
	var node := get_parent()
	while is_instance_valid(node):
		if node is MokshaBoundaryScope:
			node.boundary_scope_invalidated.connect(_invalidate)
			_watched_scopes.append(weakref(node))
		node=node.get_parent()
## Owners of uninstrumented ancestors must call before external reposition.
## Production room/mission roots use the synchronous BoundaryScope hook.
func invalidate_observations() -> void:
	_invalidate()
func _invalidate() -> void:
	_epoch += 1
	if not _scope.is_empty() and _scope.has("health"):
		var health: Variant = _scope.health.get_ref()
		if is_instance_valid(health): health.release_guarded_debit(_scope.guard)
	_scope.clear()
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion() and node.get_tree() == get_tree()
func world_scope() -> Node2D:
	return get_node_or_null(scope_path) as Node2D
func _available() -> bool:
	var room := world_scope()
	return _live(self) and enabled and can_process() and is_physics_processing() and not get_tree().paused \
		and _live(room) and room.is_ancestor_of(self) and room.get_world_2d() == get_world_2d() \
		and profile != null and profile.valid() and absf(global_transform.determinant()) > 0.000001
func _physics_process(_dt: float) -> void:
	if _sampling or not _available(): return
	_sampling = true
	for key in _observations.keys():
		if not _live(_observations[key].host.get_ref()): _observations.erase(key)
	for candidate in get_tree().get_nodes_in_group(&"moksha_boundary_receivers"):
		if not _available(): break
		if not candidate is MokshaBoundaryReceiver: continue
		var receiver: MokshaBoundaryReceiver = candidate
		var host := receiver.get_host()
		if not _live(host) or not world_scope().is_ancestor_of(host) or host.get_world_2d() != get_world_2d(): continue
		var snapshot := receiver.capture_observation()
		if snapshot.is_empty(): continue
		var point: Vector2 = snapshot.point
		var outside := to_local(point).y > 0.0
		var key := host.get_instance_id()
		var first: bool = not _observations.has(key) or _observations[key].life != snapshot.life
		if first:
			_observations[key] = {"host": weakref(host), "life": snapshot.life, "outside": outside,
				"point": point, "source_transform": global_transform, "offset": snapshot.offset, "armed": not outside or initial_outside == InitialOutside.OCCUPANCY, "attempted": false}
		var record: Dictionary = _observations[key]
		var was_outside: bool = record.outside
		var previous: Vector2 = record.point
		var same_geometry: bool = record.source_transform == global_transform and record.offset == snapshot.offset
		record.offset = snapshot.offset
		record.source_transform = global_transform
		record.point = point
		record.outside = outside
		if not outside:
			record.armed = true
			record.attempted = false
			continue
		if not record.armed or record.attempted: continue
		# Reserve episode before any receiver/Health/presentation callback.
		record.attempted = true
		_sequence += 1
		var packet := {"source": self, "serial": _sequence, "source_epoch": _epoch, "snapshot": snapshot,
			"point": point, "previous_point": previous, "initial_outside": first, "geometry_changed": not same_geometry, "crossed": not first and not was_outside and same_geometry,
			"physics_frame": Engine.get_physics_frames(), "source_transform": global_transform,
			"damage_mode": int(profile.damage_mode), "damage": profile.damage, "stun_seconds": profile.stun_seconds}
		packet.make_read_only()
		_scope = {"packet": packet, "receiver": weakref(receiver), "host": weakref(host), "room": weakref(world_scope())}
		var result := receiver.receive_boundary(packet)
		# Value-only observation of a completed attempt; it never authorizes more
		# effects even if ordinary defeat paused/retired the participants.
		var receipt := {"source_id": get_instance_id(), "host_id": key, "serial": packet.serial, "life": snapshot.life,
			"initial_outside": packet.initial_outside, "geometry_changed": packet.geometry_changed, "crossed": packet.crossed, "point": point,
			"previous_point": previous, "physics_frame": packet.physics_frame, "resolved": bool(result.get("resolved", false)),
			"amount": float(result.get("amount", 0.0)), "effect": result.get("effect", &"rejected"), "reason": result.get("reason", &"")}
		_invalidate()
		observations += 1
		if receipt.resolved: resolutions += 1
		receipt.make_read_only()
		last_receipt = receipt.duplicate(true)
		boundary_observed.emit(receipt)
	_sampling = false
	if debug_draw: queue_redraw()
func boundary_packet_is_current(packet: Dictionary, receiver: Variant, host: Variant) -> bool:
	return _live(host) and _live(receiver) and _available() and not _scope.is_empty() and is_same(packet, _scope.packet) \
		and _scope.receiver.get_ref() == receiver and _scope.host.get_ref() == host and _scope.room.get_ref() == world_scope() \
		and packet.source_epoch == _epoch and packet.physics_frame == Engine.get_physics_frames() \
		and packet.source_transform == global_transform and _live(host) and _live(receiver) \
		and host.get_world_2d() == get_world_2d() and world_scope().is_ancestor_of(host)
func hold_guard(packet: Dictionary, receiver: Variant, host: Variant, health: Variant, token: Dictionary) -> bool:
	if not _live(health) or not health is MokshaHealthComponent or not boundary_packet_is_current(packet, receiver, host): return false
	_scope.health = weakref(health)
	_scope.guard = token
	return true
func _draw() -> void:
	if not debug_draw: return
	draw_line(Vector2(-debug_width, 0), Vector2(debug_width, 0), Color("ef6b65"), 2.0)
