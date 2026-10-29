extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	Engine.physics_ticks_per_second = 60
	var world := Node2D.new()
	root.add_child(world)
	var actor = load("res://combat_pc/player.tscn").instantiate()
	actor.automatic_physics = false
	world.add_child(actor)
	actor.add_child(load("res://combat_pc/components/shield_contact_adapter.gd").new())
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 5)
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(500, 10)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var fixture = load("res://combat_pc/fixtures/guard_prop_fixture.tscn").instantiate()
	fixture.position = Vector2(75, 0)
	world.add_child(fixture)
	await physics_frame
	actor.physics_tick(1.0 / 60, {})
	await process_frame
	var prop = fixture.throw_prop()
	var bridge = prop.get_node("GuardPropAdapter")
	for frame in range(25):
		await physics_frame
		actor.physics_tick(1.0 / 60, {"shield": true})
		await process_frame
		var state := PhysicsServer2D.body_get_direct_state(prop.get_rid())
		var contacts: Array = []
		for index in state.get_contact_count():
			contacts.append({"target": state.get_contact_collider_object(index).name, "point": state.get_contact_local_position(index), "normal": state.get_contact_local_normal(index)})
		print({"frame": frame, "position": prop.global_position, "velocity": prop.linear_velocity, "previous": bridge._previous_velocity, "contacts": contacts, "result": fixture.last_result})
	quit()
