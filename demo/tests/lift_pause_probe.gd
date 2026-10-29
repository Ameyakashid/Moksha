extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var world:=Node2D.new()
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	root.add_child(world)
	for i in 2:
		var lift:=AnimatableBody2D.new()
		lift.set_script(load("res://demo/components/mission_lift.gd"))
		lift.position=Vector2(250+i*200,280)
		world.add_child(lift)
	for pass_index in 4:
		for i in 120:await physics_frame
		print("PAUSE ",pass_index)
		paused=true
		for i in 20:await physics_frame
		print("RESUME ",pass_index)
		paused=false
	world.queue_free()
	await process_frame
	quit()
