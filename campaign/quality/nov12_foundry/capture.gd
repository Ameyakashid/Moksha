extends SceneTree
## Direct visual fixtures, not traversal evidence.
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1280,720)
	var prefix:=""
	var output:="user://foundry-review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.start_new(true);host.input_override={}
	for id in ["l2_thermal_foundry","l2_freight"]:
		for i in host.sectors.size():
			if host.sectors[i].id!=id:continue
			host.load_sector(i);host.chapter_left=0
			host.player.position=Vector2(1900,60) if id=="l2_thermal_foundry" else Vector2(1800,180);host.player.velocity=Vector2.ZERO
			host.camera.position=host.camera_follow.reset(host.player.position,host.sectors[i])
			for tick in 12:await physics_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(output+"/"+prefix+id+".png")
			print("FOUNDRY_FRAME ",id," workers=",host.art.atmosphere.visible_workers if is_instance_valid(host.art.atmosphere) else 0)
	host.state="choice";host.choose_sight(true)
	for tick in 6:await physics_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output+"/"+prefix+"blind.png")
	host.free();await process_frame;quit()
