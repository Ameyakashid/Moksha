extends Node
## Read-only direct-state oracle; runs before the adapter each real physics tick.
var body: RigidBody2D
var samples: Dictionary = {}
var trajectory: Array = []
var on_sample: Callable

func _ready() -> void:
	process_physics_priority = -100000

func _physics_process(_dt: float) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree(): return
	var state := PhysicsServer2D.body_get_direct_state(body.get_rid())
	if state == null: return
	var frame := Engine.get_physics_frames()
	var contacts: Array = []
	for index in state.get_contact_count():
		var other = state.get_contact_collider_object(index)
		var normal := state.get_contact_local_normal(index)
		var local_velocity := state.get_contact_local_velocity_at_position(index)
		var collider_velocity := state.get_contact_collider_velocity_at_position(index)
		contacts.append({"body_id":body.get_instance_id(),"collider_id":other.get_instance_id() if is_instance_valid(other) else 0,"local_shape":state.get_contact_local_shape(index),"collider_shape":state.get_contact_collider_shape(index),"origin":state.get_contact_collider_position(index),"local_origin":state.get_contact_local_position(index),"normal":normal,"local_velocity":local_velocity,"collider_velocity":collider_velocity,"closing_speed":maxf(0.0,-(local_velocity-collider_velocity).dot(normal.normalized())),"linear_velocity":state.linear_velocity,"angular_velocity":state.angular_velocity,"transform":state.transform,"sleeping":state.sleeping,"body_sleeping":body.sleeping})
	samples[frame] = contacts
	trajectory.append({"position":state.transform.origin,"rotation":state.transform.get_rotation(),"velocity":state.linear_velocity,"angular_velocity":state.angular_velocity,"sleeping":state.sleeping,"body_sleeping":body.sleeping})
	if on_sample.is_valid(): on_sample.call(contacts,frame)
