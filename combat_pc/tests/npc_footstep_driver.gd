extends Node
## Independent M17 harness: calls the unchanged original motor in real physics.
var actors: Array = []
var carriers: Array = []
var frame_count := 0

func _ready() -> void:
	process_physics_priority = 10

func _physics_process(dt: float) -> void:
	frame_count += 1
	for carrier in carriers:
		if is_instance_valid(carrier.body): carrier.body.position += carrier.velocity * dt
	for entry in actors:
		var body: CharacterBody2D = entry.body
		if not is_instance_valid(body) or entry.skip: continue
		var before := body.global_position
		var was_grounded := body.is_on_floor()
		var was_on_wall := body.is_on_wall()
		var oracle_support_velocity := Vector2.ZERO
		var support: PhysicsBody2D = entry.get("probe_support")
		if is_instance_valid(support):
			var state := PhysicsServer2D.body_get_direct_state(support.get_rid())
			if state != null: oracle_support_velocity = state.get_velocity_at_local_position(body.global_position-state.transform.origin)
		var source: Node = entry.source if is_instance_valid(entry.source) else null
		var token := 0
		var ordinary: bool = body.enabled and body.pause_left <= 0.0 and body.stun_left <= 0.0 and body.dash_left <= 0.0
		if source != null and not entry.composed: token = source.begin_motion_sample(dt, ordinary)
		body.step_motor(dt)
		var contacts: Array = []
		for index in body.get_slide_collision_count():
			var hit := body.get_slide_collision(index)
			contacts.append({"position":hit.get_position(),"normal":hit.get_normal(),"collider_id":hit.get_collider_id()})
		var sample := {"physics_frame":Engine.get_physics_frames(),"before":before,"position":body.global_position,"travel":body.global_position-before,"was_grounded":was_grounded,"was_on_wall":was_on_wall,"oracle_support_velocity":oracle_support_velocity,"grounded":body.is_on_floor(),"velocity":body.velocity,"contacts":contacts,"state":body.state,"facing":body.facing}
		entry.samples.append(sample)
		if source != null and is_instance_valid(source) and not entry.composed:
			source.finish_motion_sample(token, ordinary and body.stun_left <= 0.0 and body.dash_left <= 0.0)
