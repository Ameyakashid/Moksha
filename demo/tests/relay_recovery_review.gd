extends "res://demo/tests/relay_works_review.gd"
## Native direct-position recovery views, not a traversed route.
func _ready()->void:
	super._ready()
	chapter_left=0
	input_override={}
	for enemy in enemies: enemy.process_mode=Node.PROCESS_MODE_DISABLED
	capture_sequence.call_deferred()
func capture_sequence()->void:
	player.reset_actor(Vector2(1790,300),1)
	await get_tree().create_timer(0.8).timeout
	await capture_recovery("lift")
	player.reset_actor(Vector2(1740,0),1)
	await get_tree().create_timer(0.5).timeout
	await capture_recovery("lift_top")
	player.reset_actor(Vector2(3640,300),1)
	await get_tree().create_timer(0.8).timeout
	await capture_recovery("dispatch")
	player.reset_actor(Vector2(3610,-40),1)
	await get_tree().create_timer(0.5).timeout
	await capture_recovery("dispatch_top")
	player.reset_actor(Vector2(3640,300),1)
	await get_tree().create_timer(0.5).timeout
	blind=true
	sonar.set_blind(true)
	tap_weapon()
	await get_tree().create_timer(0.3).timeout
	await capture_recovery("dispatch_blind")
	get_tree().quit()
func capture_recovery(label:String)->void:
	await RenderingServer.frame_post_draw
	print("RELAY RECOVERY ",label," ",get_viewport().get_texture().get_image().save_png("res://demo/evidence/relay_recovery_"+label+".png"))
