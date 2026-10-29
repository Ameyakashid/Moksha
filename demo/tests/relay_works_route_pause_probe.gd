extends SceneTree
## Isolated engine-log probe. No gameplay completion claims.
func _initialize()->void: run.call_deferred()
func run()->void:
	if "--outside-deferred" in OS.get_cmdline_user_args(): await process_frame
	var host=load("res://demo/tests/relay_works_review.tscn").instantiate()
	print("PAUSE PROBE BEFORE HOST ADD")
	root.add_child(host)
	print("PAUSE PROBE AFTER HOST ADD")
	host.save_enabled=false
	for tick in range(300):
		if tick==60 and "--choice" in OS.get_cmdline_user_args():
			print("PAUSE PROBE BEFORE CHOICE INTERACT")
			host.interact()
		if tick==61 and host.state=="choice":
			print("PAUSE PROBE BEFORE CHOICE RESUME")
			host.choose_sight(false)
			print("PAUSE PROBE AFTER CHOICE RESUME")
		if tick==2 and "--query" in OS.get_cmdline_user_args():
			print("PAUSE PROBE BEFORE QUERY")
			var shape=host.player.get_node("BodyShape")
			var q:=PhysicsShapeQueryParameters2D.new()
			q.shape=shape.shape
			q.transform=shape.global_transform
			q.collision_mask=1
			q.exclude=[host.player.get_rid()]
			print("QUERY HITS ",host.player.get_world_2d().direct_space_state.intersect_shape(q,32))
		if tick==120 and not "--no-pause" in OS.get_cmdline_user_args():
			print("PAUSE PROBE BEFORE PAUSE")
			var event:=InputEventKey.new()
			event.physical_keycode=KEY_ESCAPE
			event.pressed=true
			host._unhandled_key_input(event)
			if "--physics-resume" in OS.get_cmdline_user_args():
				for _i in 30: await physics_frame
				print("PAUSE PROBE BEFORE PHYSICS SIGNAL RESUME")
				host._unhandled_key_input(event)
				print("PAUSE PROBE AFTER PHYSICS SIGNAL RESUME")
		if tick==150 and host.state=="paused":
			print("PAUSE PROBE BEFORE RESUME")
			var event:=InputEventKey.new()
			event.physical_keycode=KEY_ESCAPE
			event.pressed=true
			host._unhandled_key_input(event)
		await physics_frame
		await process_frame
	print("PAUSE PROBE FINISHED")
	quit()
