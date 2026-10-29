extends Resource
## Authored grounded walking/crouching pressure, not a rigid impact/mass model.
## A real sweep contact is required; Godot owns the rigid response and collisions.
@export var push_enabled := true
@export var maximum_push_force := 1400.0
func impulse_budget(dt: float) -> float:
	return maximum_push_force * dt if push_enabled and is_finite(maximum_push_force) and maximum_push_force > 0 and is_finite(dt) and dt > 0 else 0.0
func respond(actor: CharacterBody2D, hit: KinematicCollision2D, incoming: Vector2, voluntary_target: Vector2, budget: float, ground_follow_contact: bool) -> Dictionary:
	if not push_enabled or budget <= 0 or not is_finite(budget) or not incoming.is_finite() or not voluntary_target.is_finite(): return {}
	# Continuous side pressure has a force budget. One-shot landings, ceiling
	# impacts, airborne recoil and neutral carrier motion do not reuse that budget.
	if not ground_follow_contact or actor.main_action != &"locomotion" or actor.weapon_phase != &"idle" or absf(actor.move_x) < 0.01: return {}
	var normal := hit.get_normal()
	if actor._floor_normal(normal) or normal.y > 0.1 or absf(normal.x) < 0.65 or actor.move_x * normal.x >= 0: return {}
	var body := hit.get_collider() as RigidBody2D
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion() or body.freeze or not body.can_process(): return {}
	if body.get_world_2d() != actor.get_world_2d() or (body.collision_layer & actor.collision_mask) == 0: return {}
	if body.get("simulation_enabled") == false or body.get("alive") == false: return {}
	var state := PhysicsServer2D.body_get_direct_state(body.get_rid())
	if state == null or state.inverse_mass <= 0: return {}
	var point := hit.get_position()
	var direction := -hit.get_normal().normalized()
	var offset := point - state.transform.origin
	var lever := offset - state.center_of_mass
	var at_contact := state.linear_velocity + Vector2(-lever.y,lever.x) * state.angular_velocity
	var closing := (incoming-at_contact).dot(direction)
	if not point.is_finite() or not direction.is_finite() or not is_finite(closing) : return {}
	# Constant force preserves mass differences. Cap against the existing motor
	# command, not collision-clipped re-acceleration (which scales with dt).
	# This sustained-pressure model compares commanded motor speed to actual
	# rigid point speed. A real sweep still gates it; there is no remote force.
	var target_closing := (voluntary_target-at_contact).dot(direction)
	if target_closing <= 0.001: return {}
	var inverse_effective_mass := state.inverse_mass + pow(lever.cross(direction),2) * state.inverse_inertia
	if not is_finite(inverse_effective_mass) or inverse_effective_mass <= 0: return {}
	var magnitude := minf(budget,target_closing/inverse_effective_mass)
	body.apply_impulse(direction*magnitude,offset)
	return {"body_id":body.get_instance_id(),"position":point,"normal":-direction,
		"actual_closing_speed":closing,"target_closing_speed":target_closing,"actor_world_velocity":incoming,"voluntary_world_target":voluntary_target,"body_contact_velocity":at_contact,"impulse":direction*magnitude,"magnitude":magnitude,"physics_frame":Engine.get_physics_frames()}

func capture_body_configuration(body: RigidBody2D) -> Dictionary:
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): return {}
	var geometry:Array=[]
	for owner_id in body.get_shape_owners():
		var shapes:Array=[]
		for index in body.shape_owner_get_shape_count(owner_id):
			var shape:=body.shape_owner_get_shape(owner_id,index)
			if shape==null: return {}
			shapes.append({"id":shape.get_instance_id(),"rid":shape.get_rid(),"data":PhysicsServer2D.shape_get_data(shape.get_rid())})
		geometry.append({"owner":owner_id,"transform":body.shape_owner_get_transform(owner_id),"disabled":body.is_shape_owner_disabled(owner_id),"one_way":body.is_shape_owner_one_way_collision_enabled(owner_id),"shapes":shapes})
	var material:=body.physics_material_override
	var contact_material:Dictionary={} if material==null else {"id":material.get_instance_id(),"friction":material.friction,"bounce":material.bounce,"rough":material.rough,"absorbent":material.absorbent}
	# Body pose and current velocities intentionally remain dynamic. Configuration
	# and source lifecycle changes cannot release demand captured before them.
	return {"rid":body.get_rid(),"layer":body.collision_layer,"mask":body.collision_mask,"geometry":geometry,"mass":body.mass,"inertia":body.inertia,"center_mode":body.center_of_mass_mode,"center":body.center_of_mass,"gravity":body.gravity_scale,"lock_rotation":body.lock_rotation,"custom_integrator":body.custom_integrator,"linear_damp_mode":body.linear_damp_mode,"angular_damp_mode":body.angular_damp_mode,"linear_damp":body.linear_damp,"angular_damp":body.angular_damp,"material":contact_material,"lifecycle":body.get("_lifecycle"),"epoch":body.get("impact_epoch")}
