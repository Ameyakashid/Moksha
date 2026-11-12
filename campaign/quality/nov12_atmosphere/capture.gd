extends SceneTree
## Direct scene fixtures for presentation review, never route/playthrough evidence.
var output_dir:="user://atmosphere-review"
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output_dir=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	run.call_deferred()
func run()->void:
	var host=load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled=false
	root.add_child(host)
	host.start_new(true);host.input_override={};host.chapter_left=0
	for item in [[0,Vector2(180,300),"opening"],[0,Vector2(550,300),"street"],[0,Vector2(2500,-160),"upper"],[1,Vector2(710,180),"clinic"]]:
		host.load_sector(item[0]);host.chapter_left=0
		host.player.position=item[1];host.player.velocity=Vector2.ZERO
		host.camera.position=host.camera_follow.reset(item[1],host.sectors[item[0]])
		for i in 12:await physics_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(output_dir+"/"+item[2]+".png")
		print("ATMOSPHERE_FRAME ",item[2]," civilians=",host.art.atmosphere.visible_citizens)
	host.state="choice";host.choose_sight(true)
	for i in 6:await physics_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output_dir+"/blind.png")
	host.queue_free();await process_frame;await process_frame
	quit()
