class_name MokshaSharedProjectile
extends "res://combat_pc/fixtures/guard_projectile.gd"
## The stock continuous sweep is the only motion solver. This opt-in carrier
## admits only registered receivers during that real synchronous collision.
class ReflectorFence extends Node:
	var carrier_ref: WeakRef
	func _notification(what: int) -> void:
		var carrier: Variant = carrier_ref.get_ref() if carrier_ref != null else null
		if not is_instance_valid(carrier): return
		if what in [NOTIFICATION_DISABLED, NOTIFICATION_ENABLED, NOTIFICATION_EXIT_TREE]: carrier.retire(&"reflector_retired")
		elif what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED]: carrier.invalidate_contact()
const Receiver = preload("res://simulation/components/projectile_receiver.gd")
var _emitter_ref: WeakRef
var _lease: Dictionary = {}
var _settings: Dictionary = {}
var _original_damage := 0.0
var _configured := false
var _flight_velocity := Vector2.ZERO
var _contact_epoch := 0
var _delivery: Dictionary = {}
var _dispatching := false
var _reflector_ref: WeakRef
var _reflector_epoch := -1
var _reflector_fence: Node
func configure_shared(emitter: Node, lease: Dictionary, settings: Dictionary, damage: float, launch_velocity: Vector2) -> bool:
	if _configured or is_inside_tree() or not emitter is MokshaProjectileEmitter or MokshaProjectileEmitter.registered(lease.get("source")) != emitter: return false
	if not emitter.claim_launch(self,lease,settings,damage,launch_velocity): return false
	if emitter._launch_scope.is_empty() or not emitter._launch_scope.claimed or emitter._launch_scope.carrier != self or not emitter._structural(): return false
	_configured = true
	_emitter_ref = weakref(emitter)
	_lease = lease.duplicate(true)
	_settings = settings.duplicate(true)
	_original_damage = damage
	radius = settings.radius
	lifetime_seconds = settings.lifetime_seconds
	attack_damage = damage
	blockable = settings.outbound_blockable
	parryable = settings.outbound_parryable
	rollable = settings.outbound_rollable
	reflectable = settings.reflectable
	_flight_velocity = launch_velocity
	configure(lease.source, launch_velocity, int(lease.serial))
	return true
func _ready() -> void:
	if not _configured:
		retire(&"unauthorized_launch")
		return
	super._ready()
	collision_mask = _settings.outbound_mask
	add_to_group("shared_projectiles")
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_EXIT_TREE]: invalidate_contact()
	elif what in [NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: retire(&"carrier_process_changed")
func _exit_tree() -> void:
	if is_instance_valid(_reflector_fence):
		_reflector_fence.carrier_ref = null
		_reflector_fence.queue_free()
		_reflector_fence = null
	if not _retired: retired.emit(self,&"source_exit")
func invalidate_contact() -> void:
	_contact_epoch += 1
	_delivery.clear()
	_sweep_contact_scope.clear()
func set_fixture_paused(paused: bool) -> void:
	if fixture_paused != paused: invalidate_contact()
	super.set_fixture_paused(paused)
func set_simulation_enabled(value: bool) -> void:
	if simulation_enabled != value:
		if not value: retire(&"carrier_disabled")
		else: invalidate_contact()
	super.set_simulation_enabled(value)
func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()
func _lease_current() -> bool:
	var emitter: Variant = _emitter_ref.get_ref() if _emitter_ref != null else null
	if not _configured or not _live(self) or _retired or not simulation_enabled or fixture_paused or not _live(emitter) or not emitter is MokshaProjectileEmitter: return false
	if MokshaProjectileEmitter.registered(_lease.source) != emitter: return false
	if not emitter.lease_is_current(self,_lease): return false
	# The public lease check is an extension point. Reread stable ownership.
	if not _live(emitter) or emitter._binding != _lease.binding or emitter.get_bound_actor() != _lease.source or not _live(_lease.source) or _lease.source.damage_generation() != _lease.source_epoch: return false
	if emitter._leases.get(get_instance_id(),{}) != _lease: return false
	if not emitter._carriers.has(get_instance_id()) or emitter._carriers[get_instance_id()].get_ref() != self or not emitter._structural(): return false
	var shape := get_node_or_null("CarrierShape") as CollisionShape2D
	if not _live(shape) or shape.get_parent() != self or shape.transform != Transform2D.IDENTITY or shape.disabled or not shape.shape is CircleShape2D or shape.shape.radius != _settings.radius or radius != _settings.radius or lifetime_seconds != _settings.lifetime_seconds: return false
	if collision_layer != 16 or collision_mask != (_settings.reflected_mask if reflected else _settings.outbound_mask): return false
	if velocity != _flight_velocity or attack_id != int(_lease.serial) + (1 if reflected else 0): return false
	var expected_owner: Variant = _reflector_ref.get_ref() if reflected and _reflector_ref != null else _lease.source
	if attack_owner == null or attack_owner.get_ref() != expected_owner: return false
	if attack_damage != (maxf(_original_damage,_settings.return_minimum_damage) if reflected else _original_damage): return false
	if reflected:
		var reflector: Variant = _reflector_ref.get_ref() if _reflector_ref != null else null
		if not _live(reflector) or not reflector.can_process() or not reflector.is_physics_processing() or reflector.get_world_2d() != get_world_2d() or reflector.damage_generation() != _reflector_epoch or reflector.is_defeated(): return false
		if not _live(_reflector_fence) or _reflector_fence.get_parent() != reflector: return false
	return can_process() and is_physics_processing() and not get_tree().paused and get_world_2d() == _lease.source.get_world_2d()
func _physics_process(dt: float) -> void:
	if get_tree().paused or fixture_paused: return
	if not _lease_current():
		retire(&"lease_retired")
		return
	super._physics_process(dt)
func _deliver_contact(contact: KinematicCollision2D, previous: Vector2, incoming: Vector2) -> void:
	# Capture damage-policy inputs at physical dispatch entry, before any source
	# or receiver extension hook can change layers and borrow the old contact.
	var captured_owner: Variant = attack_owner.get_ref() if attack_owner != null else null
	if not is_instance_valid(captured_owner) or not captured_owner is CollisionObject2D: return
	var source_body_layer: int = captured_owner.collision_layer
	if _dispatching or not _lease_current(): return
	var canonical := live_sweep_contact_snapshot()
	if canonical.is_empty() or canonical.collider != contact.get_collider() or canonical.collider_shape != contact.get_collider_shape_index() or canonical.contact_position != contact.get_position() or canonical.origin != previous or canonical.incoming_velocity != incoming or canonical.attack_id != attack_id: return
	if canonical.owner != captured_owner or captured_owner.collision_layer != source_body_layer: return
	var target: Variant = canonical.collider
	var receiver := Receiver.registered(target)
	if receiver == null:
		retire(&"obstruction_or_unregistered")
		return
	var target_shape: Variant = canonical.target_shape_node
	if not target_shape is CollisionShape2D or target_shape.shape == null: return
	var shape_resource: Shape2D = target_shape.shape
	var shape_transform: Transform2D = target_shape.global_transform
	var shape_rect: Rect2 = shape_resource.get_rect()
	var epoch := _contact_epoch
	var receiver_binding: Variant = receiver.get("_binding")
	var receiver_filter: Variant = receiver.get("accepted_source_layers")
	if not receiver_binding is int or not receiver_filter is int: return
	var token: Dictionary = receiver.capture_projectile_generation()
	if token.is_empty() or not _lease_current() or epoch != _contact_epoch or live_sweep_contact_snapshot() != canonical or Receiver.registered(target) != receiver: return
	if not is_instance_valid(captured_owner) or canonical.owner != captured_owner or captured_owner.collision_layer != source_body_layer or receiver.get("_binding") != receiver_binding or receiver.get("accepted_source_layers") != receiver_filter: return
	if not _live(target_shape) or target_shape.disabled or target_shape.shape != shape_resource or target_shape.global_transform != shape_transform or shape_resource.get_rect() != shape_rect: return
	var settings_impulse: Vector2 = _settings.return_impulse if reflected else _settings.outbound_impulse
	var packet := {"carrier":self,"receiver":receiver,"target":target,"receiver_generation":token,"contact_epoch":epoch,
		"contact_ticket":canonical.ticket,"attack_id":attack_id,"source":canonical.owner,"source_epoch":_lease.source_epoch,
		"source_body_layer":source_body_layer,"origin":previous,"contact_position":canonical.contact_position,"incoming_velocity":incoming,"collider_shape":canonical.collider_shape,
		"damage":attack_damage,"impulse":Vector2(signf(incoming.x)*settings_impulse.x,settings_impulse.y),"stun_seconds":_settings.return_stun_seconds if reflected else -1.0,
		"blockable":_settings.return_blockable if reflected else _settings.outbound_blockable,
		"parryable":_settings.return_parryable if reflected else _settings.outbound_parryable,
		"rollable":_settings.return_rollable if reflected else _settings.outbound_rollable,
		"reflectable":_settings.reflectable and not reflected,"reflected":reflected}
	_delivery = {"packet":packet.duplicate(true),"canonical":canonical.duplicate(true),"epoch":epoch,"claimed":false}
	packet.make_read_only()
	_dispatching = true
	var response: Dictionary = receiver.receive_projectile(packet)
	_dispatching = false
	_delivery.clear()
	last_result = response.duplicate(true)
	resolved.emit(self,last_result.duplicate(true))
	if not reflected or bool(packet.reflected): retire(&"actor_contact")
func contact_source_is_current(packet: Dictionary) -> bool:
	if not _dispatching or _delivery.is_empty() or _delivery.epoch != _contact_epoch or packet != _delivery.packet: return false
	if not _lease_current() or live_sweep_contact_snapshot() != _delivery.canonical: return false
	var owner: Variant = attack_owner.get_ref() if attack_owner != null else null
	return packet.attack_id == attack_id and packet.source == owner and packet.reflected == reflected and owner is CollisionObject2D and packet.source_body_layer == owner.collision_layer
func contact_is_current(packet: Dictionary, receiver: Node) -> bool:
	if not contact_source_is_current(packet) or packet.receiver != receiver or Receiver.registered(packet.target) != receiver: return false
	if not receiver.projectile_generation_is_current(packet.receiver_generation): return false
	return contact_source_is_current(packet) and Receiver.registered(packet.target) == receiver
func claim_contact(packet: Dictionary, receiver: Node) -> bool:
	if not contact_is_current(packet,receiver) or bool(_delivery.get("claimed",true)): return false
	_delivery.claimed = true
	return true
func reflect_from_shield(payload: Dictionary) -> Dictionary:
	if not _lease_current() or not _dispatching or _delivery.is_empty() or not bool(_delivery.get("claimed",false)) or reflected: return {"accepted":false,"reason":&"no_live_contact"}
	var defender: Variant = payload.get("defender")
	if not _live(defender) or defender != _delivery.packet.target or not defender.has_method("shield_effect_snapshot"): return {"accepted":false,"reason":&"wrong_defender"}
	var canonical: Dictionary = defender.shield_effect_snapshot()
	if canonical.is_empty() or canonical.get("effect") != &"reflect" or canonical.get("carrier") != self: return {"accepted":false,"reason":&"no_canonical_reflection"}
	for key in canonical:
		if payload.get(key) != canonical[key]: return {"accepted":false,"reason":&"altered_reflection"}
	if payload.get("defender_id") != defender.get_instance_id() or not contact_source_is_current(_delivery.packet): return {"accepted":false,"reason":&"retired_reflection"}
	var receiver: Node = _delivery.packet.receiver
	var generation: Dictionary = _delivery.packet.receiver_generation
	if Receiver.registered(defender) != receiver or not receiver.projectile_generation_is_current(generation): return {"accepted":false,"reason":&"retired_receiver"}
	if not contact_source_is_current(_delivery.packet): return {"accepted":false,"reason":&"retired_source"}
	if not receiver._generation_current(generation) or defender.shield_effect_snapshot() != canonical: return {"accepted":false,"reason":&"retired_reflection"}
	var epoch: int = defender.damage_generation()
	var result := super.reflect_from_shield(payload)
	if result.get("accepted",false):
		_flight_velocity = velocity
		_reflector_ref = weakref(defender)
		_reflector_epoch = epoch
		var fence := ReflectorFence.new()
		fence.name = "ProjectileOwnerFence"
		fence.carrier_ref = weakref(self)
		_reflector_fence = fence
		defender.add_child(fence)
		collision_mask = _settings.reflected_mask
		attack_damage = maxf(_original_damage,_settings.return_minimum_damage)
	return result
func retire(reason: StringName = &"reset") -> void:
	if _retired: return
	if is_instance_valid(_reflector_fence):
		_reflector_fence.carrier_ref = null
		_reflector_fence.queue_free()
		_reflector_fence = null
	invalidate_contact()
	super.retire(reason)
