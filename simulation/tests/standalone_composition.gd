extends SceneTree
## Real solver composition probe: no mission, no sound bus and no input source.
## Initial placement is fixture setup; support loss/falling is never assigned.
const Actor = preload("res://simulation/actors/shared_actor.tscn")
const Cargo = preload("res://simulation/world/mission_cargo.tscn")
const Lift = preload("res://simulation/world/moving_lift.tscn")
var hz := 60
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func step(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _run() -> void:
	var bus := root.get_node_or_null("NoiseBus")
	if bus != null:
		root.remove_child(bus)
		bus.free()
	var world := Node2D.new()
	root.add_child(world)
	var floor := StaticBody2D.new()
	floor.position = Vector2(320, 300)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(640, 20)
	shape.shape = box
	floor.add_child(shape)
	world.add_child(floor)
	var actors: Array[Node2D] = []
	for x in [100, 200]:
		var a := Actor.instantiate() as Node2D
		a.position = Vector2(x, 100)
		world.add_child(a)
		actors.append(a)
	var cargo := Cargo.instantiate() as RigidBody2D
	cargo.position = Vector2(450,100)
	world.add_child(cargo)
	var lift := Lift.instantiate() as AnimatableBody2D
	lift.position = Vector2(560,240)
	lift.travel = Vector2(0,-40)
	lift.period = 2.0
	world.add_child(lift)
	await step(hz * 2)
	check(root.get_node_or_null("NoiseBus") == null, "No optional sound service installed")
	for a in actors:
		check(a.grounded, "Actor without input source actually lands")
		check(a.get_node("IntentDriver").tick_count > hz, "Neutral driver still owns physics ticks")
		check(a.get_node("Health").current_health == 30, "Independent health stays intact")
	check(absf(actors[0].position.y - actors[1].position.y) < 0.01, "Same scene configuration lands at equal height")
	check(actors[0].profile != actors[1].profile, "Movement profiles are private")
	check(actors[0].get_node("ContactConfig").profile != actors[1].get_node("ContactConfig").profile, "Contact profiles are private")
	check(cargo.position.y > 250 and cargo.position.y < 290, "Production cargo actually settles without sound service")
	check(lift.clock > 1.9, "Optional-audio lift keeps real motor clock")
	for a in actors: a.hide()
	cargo.hide()
	floor.hide()
	await step(hz / 2)
	for a in actors: check(a.grounded, "Hiding root art leaves actor support live")
	check(cargo.position.y > 250 and cargo.position.y < 290, "Hiding cargo and floor does not remove collision")
	var old_y := actors[0].position.y
	floor.queue_free()
	await step(hz / 2)
	for a in actors:
		check(not a.grounded, "Removed physical support retires grounding")
		check(a.position.y > old_y + 30, "Gravity causes fall after actual support removal")
	check(cargo.position.y > 310, "Rigid cargo also falls without support")
	world.queue_free()
	await step(3)
	var report := {"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Standalone scene composition without mission, sound service or input source; real solver landing, hidden-art collision and support-removal gravity. Not AI policy or subjective feel."}
	var file := FileAccess.open("res://simulation/evidence/standalone_composition_%d.json" % hz, FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("STANDALONE COMPOSITION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
