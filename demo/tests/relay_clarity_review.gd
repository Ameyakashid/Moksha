extends "res://demo/tests/relay_works_review.gd"
## Native visual fixture only: teleports for clarity inspection, not a playthrough.
var clarity_time := 0.0
var clarity_stage := -1
func _process(dt:float)->void:
	super._process(dt)
	clarity_time += dt
	var next_stage := mini(3,int(clarity_time/2.0))
	if next_stage != clarity_stage:
		clarity_stage=next_stage
		state="playing"
		chapter_left=0
		input_override={}
		var positions=[Vector2(1480,300),Vector2(3100,300),Vector2(750,300),Vector2(1250,300)]
		player.reset_actor(positions[clarity_stage],1)
		if clarity_stage==3: state="paused"
		capture_clarity.call_deferred(clarity_stage)
	if clarity_time>8: get_tree().quit()
func capture_clarity(which:int)->void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var labels=["shutter_ladder","recovery","service","pause"]
	print("RELAY CLARITY ",labels[which]," ",get_viewport().get_texture().get_image().save_png("res://demo/evidence/relay_clarity_"+labels[which]+".png"))
