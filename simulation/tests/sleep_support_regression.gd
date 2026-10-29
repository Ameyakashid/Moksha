extends SceneTree
const Cargo = preload("res://simulation/components/physical_cargo.tscn")
var hz := 60
var checks := 0
var failures: Array[String] = []
var world: Node2D
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
func solid(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return body
func setup() -> RigidBody2D:
	world = Node2D.new()
	root.add_child(world)
	var cargo := Cargo.instantiate() as RigidBody2D
	cargo.position = Vector2(200,250)
	cargo.tuning = cargo.tuning.duplicate(true)
	cargo.tuning.bounce = 0.0
	cargo.tuning.hard_impacts_to_break = 999
	world.add_child(cargo)
	return cargo
func cleanup() -> void:
	world.queue_free()
	await step(3)
func _run() -> void:
	# Real rest and loss of a real supporting body; no assigned velocities.
	for remove_mode in ["free", "disabled", "moved", "shape_moved", "mask", "paused"]:
		var cargo := setup()
		var floor := solid(Vector2(200,300), Vector2(300,20))
		await step(hz * 3)
		check(cargo.sleeping, remove_mode + ": naturally sleeping at rest")
		var y := cargo.position.y
		await step(hz)
		check(cargo.sleeping and absf(cargo.position.y-y)<0.01, remove_mode + ": stable support does not perpetually wake")
		if remove_mode == "paused": paused = true
		if remove_mode == "disabled": floor.get_child(0).set_deferred("disabled", true)
		elif remove_mode == "moved": floor.position.x += 500
		elif remove_mode == "shape_moved": floor.get_child(0).position.x += 500
		elif remove_mode == "mask": floor.collision_layer = 0
		else: floor.queue_free()
		await step(3)
		if remove_mode == "paused":
			check(absf(cargo.position.y-y)<0.01, "paused: no forced motion while paused")
			paused = false
		await step(int(hz * 0.5))
		check(not cargo.sleeping and cargo.position.y > y + 30, remove_mode + ": genuine support loss resumes solver gravity")
		check(cargo.charge == 0, remove_mode + ": wake does not grant weapon charge")
		await cleanup()
	# Actual side contact must not be mistaken for supporting contact.
	var cargo := setup()
	var floor := solid(Vector2(200,300),Vector2(300,20))
	var wall := solid(Vector2(216,260),Vector2(8,80))
	await step(hz * 3)
	check(cargo.sleeping, "side: settled before removing side collider")
	check(cargo.get_colliding_bodies().has(wall), "side: actual side contact exists")
	wall.queue_free()
	await step(int(hz * 0.5))
	check(cargo.sleeping, "side: non-support exit does not wake cargo")
	check(cargo.get_colliding_bodies().has(floor), "side: floor contact still live")
	await cleanup()
	var report := {"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Real sleeping cargo contacts: support removal/disable/pause, stable resting state and unrelated side-contact exit. Gravity/bounce tuning explicitly fixture-owned."}
	var file := FileAccess.open("res://simulation/evidence/sleep_support_%d.json" % hz,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SLEEP SUPPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
