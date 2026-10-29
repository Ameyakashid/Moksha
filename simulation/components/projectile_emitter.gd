class_name MokshaProjectileEmitter
extends Node
## One optional action observer. Controller owns clocks and action cancellation;
## this component owns pending aim and launched-shot lifetime, separately.
signal projectile_emitted(receipt: Dictionary)
const Profile = preload("res://simulation/resources/projectile_profile.gd")
const Carrier = preload("res://simulation/components/shared_projectile.gd")
const REGISTRATION: StringName = &"_moksha_projectile_emitter"
const HISTORY: StringName = &"_moksha_projectile_emission_history"
class PauseFence extends Node:
	var invalidate: Callable
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and invalidate.is_valid(): invalidate.call()
@export var profile: Profile:
	set(value):
		retire_owned(&"profile_replaced")
		if profile != null and profile.changed.is_connected(_on_profile_changed): profile.changed.disconnect(_on_profile_changed)
		profile = value.duplicate(true) if value != null else Profile.new()
		_profile_snapshot = profile.snapshot()
		profile.changed.connect(_on_profile_changed)
@export_node_path("Node") var aim_path := NodePath("../ProjectileAim")
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		retire_owned(&"emitter_disabled")
var emitted_count := 0
var last_receipt: Dictionary = {}
var _actor_ref: WeakRef
var _profile_snapshot: Dictionary = {}
var _pending: Dictionary = {}
var _carriers: Dictionary = {}
var _binding := 0
var _history: Dictionary = {}
var _releasing := false
var _launch_scope: Dictionary = {}
var _leases: Dictionary = {}
var _pause_fence: Node
func _ready() -> void:
	var fence := PauseFence.new()
	fence.name = "PauseFence"
	fence.process_mode = Node.PROCESS_MODE_PAUSABLE
	fence.invalidate = invalidate_pending
	_pause_fence = fence
	add_child(fence)
	configure_profile(profile)
	var host := get_parent()
	if host.is_node_ready(): bind(host)
	else: host.ready.connect(func(): bind(host), CONNECT_ONE_SHOT)
func _exit_tree() -> void: unbind()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED]: invalidate_pending()
	elif what in [NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: retire_owned(&"emitter_process_changed")
func get_bound_actor() -> Node2D: return _actor_ref.get_ref() as Node2D if _actor_ref != null else null
static func registered(actor: Node) -> Node:
	var ref: Variant = actor.get_meta(REGISTRATION) if is_instance_valid(actor) and actor.has_meta(REGISTRATION) else null
	var emitter: Variant = ref.get_ref() if ref is WeakRef else null
	return emitter if is_instance_valid(emitter) and emitter.is_inside_tree() and not emitter.is_queued_for_deletion() and emitter.has_method("get_bound_actor") and emitter.get_bound_actor() == actor else null
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
func configure_profile(value: Profile) -> void:
	profile = value
func _on_profile_changed() -> void:
	retire_owned(&"profile_changed")
	_profile_snapshot = profile.snapshot()
func bind(actor: Node) -> bool:
	if not _live(actor) or not actor is CharacterBody2D or get_parent() != actor or not actor.has_method("active_action_sample_snapshot"): return false
	var existing := registered(actor)
	if existing != null and existing != self: return false
	if get_bound_actor() == actor: return true
	unbind()
	_actor_ref = weakref(actor)
	actor.set_meta(REGISTRATION, weakref(self))
	_history = actor.get_meta(HISTORY, {})
	_history["last_started"] = maxi(int(_history.get("last_started",0)), actor.attack_serial)
	actor.set_meta(HISTORY, _history)
	actor.movement_event.connect(_on_actor_event)
	actor.strike_sample.connect(_on_sample)
	var defeat := actor.get_node_or_null("DefeatResponse")
	if defeat != null: defeat.defeat_started.connect(_on_defeat)
	return true
func unbind() -> void:
	retire_owned(&"emitter_unbound")
	var actor := get_bound_actor()
	if is_instance_valid(actor):
		if actor.movement_event.is_connected(_on_actor_event): actor.movement_event.disconnect(_on_actor_event)
		if actor.strike_sample.is_connected(_on_sample): actor.strike_sample.disconnect(_on_sample)
		var defeat := actor.get_node_or_null("DefeatResponse")
		if defeat != null and defeat.defeat_started.is_connected(_on_defeat): defeat.defeat_started.disconnect(_on_defeat)
		if registered(actor) == self: actor.remove_meta(REGISTRATION)
	_actor_ref = null
	_history = {}
func invalidate_pending() -> void:
	_pending.clear()
	for ref in _carriers.values():
		var carrier: Variant = ref.get_ref()
		if is_instance_valid(carrier): carrier.invalidate_contact()
func retire_owned(reason: StringName = &"reset") -> void:
	_binding += 1
	_pending.clear()
	var owned := _carriers.values()
	_carriers.clear()
	_leases.clear()
	_launch_scope.clear()
	for ref in owned:
		var carrier: Variant = ref.get_ref()
		if is_instance_valid(carrier): carrier.retire(reason)
func _on_defeat() -> void: retire_owned(&"source_defeated")
func _structural() -> bool:
	var actor := get_bound_actor()
	return _live(self) and enabled and _live(actor) and get_parent() == actor and registered(actor) == self \
		and _live(_pause_fence) and _pause_fence.get_parent() == self and _pause_fence.process_mode == Node.PROCESS_MODE_PAUSABLE \
		and profile != null and profile.valid() and profile.snapshot() == _profile_snapshot \
		and can_process() and actor.can_process() and actor.is_physics_processing() and not get_tree().paused and not actor.is_defeated()
func lease_is_current(carrier: Node, lease: Dictionary) -> bool:
	var actor := get_bound_actor()
	return _structural() and lease.get("binding") == _binding and lease.get("source") == actor and lease.get("source_epoch") == actor.damage_generation() \
		and _carriers.has(carrier.get_instance_id()) and _carriers[carrier.get_instance_id()].get_ref() == carrier \
		and _leases.get(carrier.get_instance_id(),{}) == lease
func _on_actor_event(kind: StringName, packet: Dictionary) -> void:
	if kind == &"reset":
		retire_owned(&"source_reset")
		return
	if kind in [&"attack_cancelled", &"attack_finished", &"chain_reset"]:
		_pending.clear()
		return
	if kind != &"attack_started" or not _structural(): return
	var actor := get_bound_actor()
	var canonical: Dictionary = actor.strike_snapshot()
	if actor.weapon_phase != &"windup" or packet.get("serial") != actor.attack_serial or int(packet.get("serial",0)) <= int(_history.get("last_started",0)): return
	for key in packet:
		if packet[key] != (actor.global_position if key == "position" else canonical.get(key)): return
	_history.last_started = actor.attack_serial
	if canonical.get("attack_pose_id") != profile.release_pose or canonical.get("charge_role") != profile.release_charge_role: return
	var binding := _binding
	var generation: int = actor.damage_generation()
	var aim := get_node_or_null(aim_path)
	if not _live(aim) or not actor.is_ancestor_of(aim) or not aim.can_process() or not aim.has_method("sample_aim"): return
	var muzzle := actor.global_position + Vector2(profile.muzzle_offset.x * actor.attack_facing, profile.muzzle_offset.y)
	var point: Variant = aim.sample_aim(actor, muzzle)
	if not point is Vector2 or not Vector2(point).is_finite() or not _structural() or binding != _binding or actor.damage_generation() != generation or actor.weapon_phase != &"windup" or actor.attack_serial != canonical.serial: return
	_pending = {"serial": actor.attack_serial,"epoch":generation,"binding":binding,"aim":point,"aim_provider":weakref(aim),"metadata":packet.duplicate(true)}
	actor._commit_noise(muzzle, profile.warning_kind, profile.warning_loudness, generation)
func _on_sample(actor: Node2D, packet: Dictionary) -> void:
	if _releasing or actor != get_bound_actor() or not _structural() or _pending.is_empty(): return
	var canonical: Dictionary = actor.active_action_sample_snapshot()
	if canonical.is_empty() or packet != canonical or not bool(canonical.get("eligible", false)): return
	if canonical.get("serial") != _pending.serial or _pending.binding != _binding or actor.damage_generation() != _pending.epoch: return
	if canonical.get("attack_pose_id") != profile.release_pose or canonical.get("charge_role") != profile.release_charge_role: return
	var aim: Variant = _pending.aim_provider.get_ref()
	if not _live(aim) or get_node_or_null(aim_path) != aim or not actor.is_ancestor_of(aim) or not aim.can_process(): return
	var pending := _pending.duplicate(true)
	_pending.clear() # Claim before any construction, tree or signal callback.
	_releasing = true
	_release(actor, canonical, pending)
	_releasing = false
func _release(actor: Node2D, canonical: Dictionary, pending: Dictionary) -> void:
	var muzzle := actor.global_position + Vector2(profile.muzzle_offset.x * actor.attack_facing, profile.muzzle_offset.y)
	var direction: Vector2 = pending.aim - muzzle
	if direction.is_zero_approx(): direction = Vector2(actor.attack_facing, 0)
	# Blocked spawn is rejected against the whole carrier circle and the segment
	# from body origin to muzzle; no actor is damaged through a muzzle-side wall.
	var circle := CircleShape2D.new()
	circle.radius = profile.radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0,muzzle)
	query.collision_mask = profile.obstruction_mask
	query.exclude = [actor.get_rid()]
	var space := actor.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position + Vector2(0,profile.muzzle_offset.y),muzzle,profile.obstruction_mask,[actor.get_rid()])
	ray.hit_from_inside = true
	if not space.intersect_shape(query,1).is_empty() or not space.intersect_ray(ray).is_empty(): return
	if profile.require_clear_aim_on_release:
		var aim_ray := PhysicsRayQueryParameters2D.create(muzzle,pending.aim,profile.obstruction_mask,[actor.get_rid()])
		aim_ray.hit_from_inside = true
		if not space.intersect_ray(aim_ray).is_empty(): return
	if not _structural() or pending.binding != _binding or pending.epoch != actor.damage_generation() or actor.active_action_sample_snapshot() != canonical: return
	var carrier := Carrier.new()
	var lease := {"binding":_binding,"source":actor,"source_epoch":actor.damage_generation(),"serial":canonical.serial}
	_launch_scope = {"carrier":carrier,"lease":lease.duplicate(true),"settings":profile.snapshot(),"damage":float(canonical.damage),"velocity":direction.normalized()*profile.speed,"sample":canonical.duplicate(true),"claimed":false}
	var configured: bool = carrier.configure_shared(self,lease,profile.snapshot(),float(canonical.damage),direction.normalized()*profile.speed)
	_launch_scope.clear()
	if not configured:
		carrier.free()
		return
	_leases[carrier.get_instance_id()] = lease.duplicate(true)
	_carriers[carrier.get_instance_id()] = weakref(carrier) # Own before _ready can reenter.
	carrier.retired.connect(_on_carrier_retired)
	carrier.position = actor.get_parent().to_local(muzzle)
	actor.get_parent().add_child(carrier)
	if not lease_is_current(carrier,lease) or carrier.is_queued_for_deletion():
		carrier.retire(&"retired_during_creation")
		return
	emitted_count += 1
	var receipt := {"source_id":actor.get_instance_id(),"source_epoch":lease.source_epoch,"serial":canonical.serial,"carrier_id":carrier.get_instance_id(),"muzzle":muzzle,"aim":pending.aim,"velocity":carrier.velocity,"damage":canonical.damage,"physics_frame":Engine.get_physics_frames()}
	receipt.make_read_only()
	last_receipt = receipt.duplicate(true)
	actor._commit_noise(muzzle, profile.release_kind, profile.release_loudness, lease.source_epoch)
	if lease_is_current(carrier,lease): projectile_emitted.emit(receipt)
## Defensive presentation only. This never authorizes a sample or a launch.
func pending_aim_snapshot() -> Dictionary:
	if not _structural() or _pending.is_empty(): return {}
	var actor := get_bound_actor()
	if _pending.binding != _binding or _pending.epoch != actor.damage_generation() or _pending.serial != actor.attack_serial or actor.weapon_phase != &"windup": return {}
	var value := {"aim":_pending.aim,"serial":_pending.serial,"source_epoch":_pending.epoch}
	value.make_read_only()
	return value
func claim_launch(carrier: Node, lease: Dictionary, settings: Dictionary, damage: float, launch_velocity: Vector2) -> bool:
	if not _releasing or _launch_scope.is_empty() or _launch_scope.claimed or not _structural(): return false
	if _launch_scope.carrier != carrier or _launch_scope.lease != lease or _launch_scope.settings != settings or _launch_scope.damage != damage or _launch_scope.velocity != launch_velocity: return false
	if get_bound_actor().active_action_sample_snapshot() != _launch_scope.sample: return false
	_launch_scope.claimed = true
	return true
func _on_carrier_retired(carrier: Node2D, _reason: StringName) -> void:
	_carriers.erase(carrier.get_instance_id())
	_leases.erase(carrier.get_instance_id())
