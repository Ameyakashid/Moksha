class_name MokshaGuardProjectile
extends CharacterBody2D
## Live swept circular carrier. Terrain and receivers participate in the same sweep.
signal resolved(carrier: Node2D, result: Dictionary)
signal retired(carrier: Node2D, reason: StringName)
@export var radius := 3.0
@export var lifetime_seconds := 3.5
@export var attack_damage := 10.0
@export var blockable := true
@export var parryable := true
@export var reflectable := true
@export var rollable := true
var simulation_enabled := true
var fixture_paused := false
var reflected := false
var reflection_count := 0
var attack_id := 1
var attack_owner: WeakRef
var last_result: Dictionary = {}
var last_contact := Vector2.ZERO
var age := 0.0
var _retired := false
var _last_effect_key := ""
var _sweep_contact_scope: Dictionary = {}
var _sweep_contact_ticket := 0

func _ready() -> void:
	process_physics_priority = 110
	collision_layer = 16
	collision_mask = 7
	var shape := CircleShape2D.new()
	shape.radius = maxf(0.1, radius)
	var holder := CollisionShape2D.new()
	holder.name = "CarrierShape"
	holder.shape = shape
	add_child(holder)

func configure(source: Node, launch_velocity: Vector2, identifier: int = 1) -> void:
	attack_owner = weakref(source) if is_instance_valid(source) else null
	velocity = launch_velocity
	attack_id = maxi(1, identifier)
	if source is PhysicsBody2D: add_collision_exception_with(source)

func _physics_process(dt: float) -> void:
	if not simulation_enabled or fixture_paused or _retired: return
	age += dt
	if age >= lifetime_seconds:
		retire(&"expired")
		return
	var incoming := velocity
	var previous := global_position
	var contact := move_and_collide(incoming * dt, false, 0.001)
	if contact == null: return
	last_contact = contact.get_position()
	_sweep_contact_ticket += 1
	_sweep_contact_scope = {"ticket": _sweep_contact_ticket, "collider": contact.get_collider(),
		"collider_shape": contact.get_collider_shape_index(), "contact_position": last_contact,
		"origin": previous, "incoming_velocity": incoming, "attack_id": attack_id,
		"owner": attack_owner.get_ref() if attack_owner != null else null, "reflected": reflected,
		"carrier_transform": global_transform, "carrier_velocity": velocity,
		"carrier_shape_node": get_node("CarrierShape"), "carrier_shape_resource": get_node("CarrierShape").shape,
		"carrier_shape_transform": get_node("CarrierShape").transform, "carrier_shape_rect": get_node("CarrierShape").shape.get_rect(),
		"carrier_mask":collision_mask,"carrier_layer":collision_layer,
		"target_transform":contact.get_collider().global_transform if is_instance_valid(contact.get_collider()) and contact.get_collider() is Node2D else Transform2D.IDENTITY,"target_shape_node":contact.get_collider_shape()}
	_deliver_contact(contact, previous, incoming)
	_sweep_contact_scope.clear()

func live_sweep_contact_snapshot() -> Dictionary:
	if _sweep_contact_scope.is_empty() or _retired or not simulation_enabled or fixture_paused or is_queued_for_deletion(): return {}
	var scope := _sweep_contact_scope
	var shape: Variant = scope.carrier_shape_node
	var target_shape: Variant = scope.target_shape_node
	if not is_instance_valid(shape) or shape.is_queued_for_deletion() or shape.get_parent() != self or shape.disabled or shape.shape != scope.carrier_shape_resource or shape.transform != scope.carrier_shape_transform or shape.shape.get_rect() != scope.carrier_shape_rect: return {}
	if global_transform != scope.carrier_transform or velocity != scope.carrier_velocity or collision_mask != scope.carrier_mask or collision_layer != scope.carrier_layer: return {}
	if not is_instance_valid(scope.collider) or scope.collider.is_queued_for_deletion() or scope.collider.global_transform != scope.target_transform: return {}
	if not is_instance_valid(target_shape) or target_shape.is_queued_for_deletion() or not target_shape.is_inside_tree(): return {}
	var snapshot := _sweep_contact_scope.duplicate(true)
	snapshot.make_read_only()
	return snapshot

func _deliver_contact(contact: KinematicCollision2D, previous: Vector2, incoming: Vector2) -> void:
	var target: Variant = contact.get_collider()
	if not is_instance_valid(target):
		retire(&"lost_collider")
		return
	if target.has_method("receive_attack") and not reflected:
		var source: Variant = attack_owner.get_ref() if attack_owner != null else null
		var result: Dictionary = target.receive_attack({"attack_id": attack_id, "source": source, "carrier": self,
			"origin": previous, "source_position": previous, "contact_position": last_contact, "incoming_velocity": incoming,
			"kind": &"projectile", "amount": attack_damage, "impulse": incoming.normalized() * 135 + Vector2(0, -65),
			"blockable": blockable, "parryable": parryable, "reflectable": reflectable, "counterable": false, "rollable": rollable})
		last_result = result.duplicate(true)
		resolved.emit(self, last_result.duplicate(true))
		# Actual redirect is authoritative even if a callback retired the shield
		# before its result could be confirmed. Never undo an applied reflection.
		if reflected: return
		retire(&"actor_contact")
	elif reflected and target.has_method("receive_guard_projectile"):
		var response: Variant = target.receive_guard_projectile({"carrier": self, "owner": attack_owner.get_ref() if attack_owner != null else null,
			"attack_id": attack_id, "damage": attack_damage, "contact_position": last_contact, "incoming_velocity": incoming, "reflected": true})
		last_result = response if response is Dictionary else {"accepted": false}
		resolved.emit(self, last_result.duplicate(true))
		retire(&"receiver_contact")
	else:
		retire(&"terrain_contact")

func reflect_from_shield(payload: Dictionary) -> Dictionary:
	if _retired or not simulation_enabled or fixture_paused or reflected or is_queued_for_deletion(): return {"accepted": false, "reason": &"carrier_ineligible"}
	var defender: Variant = payload.get("defender")
	var direction: Vector2 = payload.get("reflect_direction", Vector2.ZERO)
	var speed := float(payload.get("reflect_speed", velocity.length()))
	if not is_instance_valid(defender) or not defender is PhysicsBody2D or not direction.is_finite() or direction.is_zero_approx() or not is_finite(speed) or speed <= 0:
		return {"accepted": false, "reason": &"invalid_redirect"}
	_last_effect_key = String(payload.get("attack_key", ""))
	var previous_owner: Variant = attack_owner.get_ref() if attack_owner != null else null
	if is_instance_valid(previous_owner) and previous_owner is PhysicsBody2D: remove_collision_exception_with(previous_owner)
	attack_owner = weakref(defender)
	add_collision_exception_with(defender)
	velocity = direction.normalized() * speed
	reflected = true
	reflection_count += 1
	attack_id += 1
	queue_redraw()
	return {"accepted": true, "velocity": velocity, "owner_id": defender.get_instance_id(), "reflection_count": reflection_count}

func set_fixture_paused(paused: bool) -> void:
	fixture_paused = paused

func set_simulation_enabled(enabled: bool) -> void:
	simulation_enabled = enabled

func retire(reason: StringName = &"reset") -> void:
	if _retired: return
	_sweep_contact_scope.clear()
	_retired = true
	simulation_enabled = false
	collision_layer = 0
	collision_mask = 0
	retired.emit(self, reason)
	queue_free()

func _draw() -> void:
	var color := Color("76e1c5") if reflected else Color("efb275")
	draw_circle(Vector2.ZERO, radius, color, false, 1)
	if not velocity.is_zero_approx(): draw_line(-velocity.normalized() * 9, Vector2.ZERO, color, 1)
