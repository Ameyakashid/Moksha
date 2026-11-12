extends SceneTree
## Explicit placement/goal fixtures for native layout inspection, not playthrough evidence.
var host:Node
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for i in n:await physics_frame;await process_frame
func capture(label:String,at:Vector2)->void:
	host.player.position=at;host.player.velocity=Vector2.ZERO;host.input_override={}
	await frames(6)
	# Hold only for the labelled fixture frame, not any route receipt.
	host.set_process(false);host.set_physics_process(false)
	await RenderingServer.frame_post_draw
	var path:="res://campaign/quality/nov12_opening_layout/"+label+".png"
	root.get_texture().get_image().save_png(path)
	print("CLINIC_NATIVE_FIXTURE ",path)
	host.set_process(true);host.set_physics_process(true)
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.start_new(true);host.load_sector(1);host.input_override={}
	await frames(5)
	for enemy in host.enemies:enemy.set_process(false);enemy.set_physics_process(false)
	await capture("clinic-return-headroom",Vector2(1880,245))
	await capture("clinic-outbound-roof",Vector2(2700,-80))
	await capture("clinic-street-closed",Vector2(2670,300))
	host.free();quit()
