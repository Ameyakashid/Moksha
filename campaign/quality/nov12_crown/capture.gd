extends SceneTree
## Direct visual fixtures, not traversal evidence.
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(640,360)
	var prefix:=""
	var output:="user://crown-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.start_new(true);host.input_override={}
	for id in ["crown_ascent","crown_last_warden"]:
		for i in host.sectors.size():
			if host.sectors[i].id!=id:continue
			host.load_sector(i);host.chapter_left=0
			host.player.position=Vector2(2970,135) if id=="crown_ascent" else Vector2(2600,300);host.player.velocity=Vector2.ZERO
			host.camera.position=host.camera_follow.reset(host.player.position,host.sectors[i])
			for tick in 12:await physics_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(output+"/"+prefix+id+".png")
			print("CROWN_FRAME ",id)
	host.state="choice";host.choose_sight(true)
	for tick in 6:await physics_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output+"/"+prefix+"blind.png")
	host.free()
	# External fixture teardown: drain pending audio/process references.
	await create_timer(.5).timeout
	for tick in 5:await physics_frame
	quit()
