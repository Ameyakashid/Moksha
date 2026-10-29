extends Node
## Forward collision-shape melee with terrain occlusion, independent of a run.

signal shake_requested(amount: float)
signal strike_resolved(actor: Node2D, combo: int, touched: bool)
const StrikeTuning = preload("res://resources/tuning/strike_tuning.gd")
@export var tuning: StrikeTuning = preload("res://resources/tuning/strike_default.tres")
@export var prop_group: StringName = &"props"
@export var enemy_group: StringName = &"enemies"
var _swing_actor: Node2D
var _swing_combo := 1
var _hit_targets: Dictionary = {}

func resolve_attack(actor: Node2D, combo: int) -> void:
	# This entry point fires once per swing. The remainder of its active window
	# continues sampling real contacts, with at most one hit per target.
	_swing_actor = actor
	_swing_combo = combo
	_hit_targets.clear()
	_sample_contacts(actor, combo)

func _physics_process(_dt: float) -> void:
	if not is_instance_valid(_swing_actor): return
	if _swing_actor.dead or _swing_actor.dash_time > 0 or _swing_actor.attack_phase != _swing_actor.AttackPhase.ACTIVE:
		cancel_attack()
		return
	if not _swing_actor.simulation_enabled or _swing_actor.hitpause > 0: return
	_sample_contacts(_swing_actor, _swing_combo)

func cancel_attack() -> void:
	_swing_actor = null
	_hit_targets.clear()

func _sample_contacts(actor: Node2D, combo: int) -> void:
	if actor.dead or actor.dash_time > 0 or not actor.simulation_enabled: return
	var shape := RectangleShape2D.new()
	shape.size = tuning.hitbox_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, actor.global_position + Vector2(actor.facing * tuning.center_offset.x, tuning.center_offset.y))
	query.collision_mask = tuning.target_mask
	query.exclude = [actor.get_rid()]
	var touched := false
	var visited := {}
	for contact in actor.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body = contact.collider
		if not is_instance_valid(body) or visited.has(body.get_instance_id()) or _hit_targets.has(body.get_instance_id()): continue
		visited[body.get_instance_id()] = true
		# A hurtbox may graze the near edge, but never reach behind the player.
		if (body.global_position.x - actor.global_position.x) * actor.facing <= 0: continue
		if not _clear_contact(actor, body, int(contact.shape)): continue
		if body.is_in_group(prop_group) and body.has_method("launch") and body.alive:
			_hit_targets[body.get_instance_id()] = true
			body.launch(actor.facing, tuning.finisher_launch_multiplier if combo == 3 else 1.0)
			touched = true
		elif body.is_in_group(enemy_group) and body.has_method("take_hit") and body.active:
			_hit_targets[body.get_instance_id()] = true
			body.take_hit(tuning.finisher_damage if combo == 3 else tuning.damage, actor.facing)
			touched = true
	if touched:
		shake_requested.emit(3.0)
		if actor.has_method("apply_hitpause"): actor.apply_hitpause()
	strike_resolved.emit(actor, combo, touched)

func _clear_contact(actor: Node2D, body: CollisionObject2D, shape_index: int) -> bool:
	var owner_id := body.shape_find_owner(shape_index)
	var owner_transform := body.global_transform * body.shape_owner_get_transform(owner_id)
	var shape := body.shape_owner_get_shape(owner_id, 0)
	var bounds := owner_transform * shape.get_rect()
	var origin := actor.global_position + Vector2(0, -22)
	# Clamp to the actual collider, so a 40px actor is hit at its torso rather
	# than its foot pivot, and large props use the near contact surface.
	var contact_point := Vector2(clampf(origin.x, bounds.position.x, bounds.end.x), clampf(origin.y, bounds.position.y, bounds.end.y))
	var ray := PhysicsRayQueryParameters2D.create(origin, contact_point, tuning.terrain_mask, [actor.get_rid(), body.get_rid()])
	return actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
