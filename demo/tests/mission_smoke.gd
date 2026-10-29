extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host = load("res://demo/mission.tscn").instantiate()
	root.add_child(host)
	host.save_enabled = false
	host.start_new(true)
	for i in range(180):
		host.input_override = {"right":1.0,"attack":i%35==0,"jump":i==40 or i==65}
		await physics_frame
	print("SMOKE ",host.player.position," health=",host.health.current_health," state=",host.state)
	quit()
