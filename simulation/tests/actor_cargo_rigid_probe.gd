extends "res://demo/components/mission_prop.gd"
## Observation-only source. Actual Godot point velocities precede unchanged
## canonical admission; no packet, impulse or damage is created by this probe.
var material_contacts:Array[Dictionary]=[]
func _integrate_forces(state:PhysicsDirectBodyState2D) -> void:
	for index in state.get_contact_count():
		var body:Variant=state.get_contact_collider_object(index)
		if not is_instance_valid(body) or not body is CharacterBody2D: continue
		var normal:=state.get_contact_local_normal(index).normalized()
		var source_velocity:=state.get_contact_local_velocity_at_position(index)
		var target_velocity:=state.get_contact_collider_velocity_at_position(index)
		if material_contacts.size()<2048: material_contacts.append({"frame":Engine.get_physics_frames(),"target_id":body.get_instance_id(),"normal":normal,"source_point_velocity":source_velocity,"target_point_velocity":target_velocity,"normal_speed":maxf(0,-(source_velocity-target_velocity).dot(normal)),"charge":charge,"epoch":impact_epoch,"source_position":state.transform.origin,"target_position":body.position})
	super._integrate_forces(state)
