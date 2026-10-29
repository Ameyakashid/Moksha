extends "res://demo/tests/freight_lock_review.gd"
## Native capture fixture: explicitly teleported viewpoints; no route or pacing claim.
## Enemies remain visible but inactive to isolate visual inspection.
func _ready()->void:
	super._ready()
	input_override={}
	chapter_left=0
	for enemy in enemies: enemy.process_mode=Node.PROCESS_MODE_DISABLED
	visual_sequence.call_deferred()
func visual_sequence()->void:
	player.reset_actor(Vector2(450,300),1)
	await get_tree().create_timer(0.8).timeout
	await capture_visual("loading_lane")
	player.reset_actor(Vector2(1214,240),1)
	await get_tree().create_timer(0.8).timeout
	await capture_visual("cradle_closed")
	player.reset_actor(Vector2(1460,300),1)
	await get_tree().create_timer(0.8).timeout
	await capture_visual("receiver_closed_door")
	player.reset_actor(Vector2(1214,240),1)
	await get_tree().create_timer(0.5).timeout
	input_override={"attack":true}
	await get_tree().create_timer(0.15).timeout
	input_override={}
	await get_tree().create_timer(8.0).timeout
	print("FREIGHT VISUAL real J delivery seated=",room.freight_receiver.is_latched," shutter_open=",room.freight_shutter.is_open)
	player.reset_actor(Vector2(1460,300),1)
	await get_tree().create_timer(0.8).timeout
	await capture_visual("cargo_seated")
	blind=true
	sonar.set_blind(true)
	tap_weapon()
	await get_tree().create_timer(0.25).timeout
	await capture_visual("blind_contours")
	state="paused"
	await capture_visual("pause")
	get_tree().quit()
func capture_visual(label:String)->void:
	await RenderingServer.frame_post_draw
	print("FREIGHT VISUAL ",label," ",get_viewport().get_texture().get_image().save_png("res://demo/evidence/freight_visual_"+label+".png"))
