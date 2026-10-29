extends SceneTree
const RECEIVER = preload("res://demo/components/freight_receiver.gd")
const CRADLE = preload("res://demo/components/freight_cradle.gd")
var hz := 60
var receiver
var cradle
var world: Node2D
var rows: Array = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	for trial in 12:
		seed(trial + 200)
		world = Node2D.new()
		root.add_child(world)
		receiver = RECEIVER.new()
		receiver.position = Vector2(500, 300)
		world.add_child(receiver)
		cradle = CRADLE.new()
		cradle.position = Vector2(254, 270)
		cradle.bind_receiver(receiver)
		world.add_child(cradle)
		await frames(hz)
		var prop = cradle.cargo
		prop.launch(1)
		var spin: float = prop.angular_velocity
		var trajectory: Array = []
		for step in hz * 7:
			await frames(1)
			if step % maxi(1,hz/10) == 0 and is_instance_valid(prop): trajectory.append([step, prop.position, prop.linear_velocity, prop.angular_velocity])
			if receiver.is_latched: break
		var row := {"trial": trial, "spin": spin, "latched": receiver.is_latched, "position": prop.global_position if is_instance_valid(prop) else Vector2.INF, "alive": is_instance_valid(prop), "hard_impacts": prop.hard_impacts if is_instance_valid(prop) else -1, "trajectory": trajectory}
		rows.append(row)
		print("TRIAL ", trial, " hz=", hz, " spin=",spin," latch=",row.latched," position=",row.position, " impacts=", row.hard_impacts)
		world.queue_free()
		await frames(2)
	var output := "res://demo/evidence/freight_component_probe_%dhz.json" % hz
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  ") + "\n")
	quit(0)
