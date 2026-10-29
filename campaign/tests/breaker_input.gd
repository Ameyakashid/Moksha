extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var host=load("res://campaign/campaign.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.start_new(true)
	# Explicit controlled arena fixture; following contact uses real PC J inputs.
	for enemy in host.enemies:enemy.queue_free()
	var objective=load("res://campaign/logic/objective.tscn").instantiate()
	objective.configure({"id":"probe","label":"BREAKER","kind":"breaker","at":Vector2(110,300)},host)
	host.room.add_child(objective);objective.changed.connect(host._goal_changed.bind(objective));host.goals.append(objective)
	for frame in 120:
		host.input_override={"attack":frame in [10,32,54,76,98]}
		await physics_frame;await process_frame
	print("BREAKER_INPUT completed=",objective.completed," receipts=",objective.breaker_health.resolved_count," health=",objective.breaker_health.get_node("Health").current_health)
	quit(0 if objective.completed else 1)
