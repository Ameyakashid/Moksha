extends "res://demo/mission.gd"
## Native-rendered fixture reel, NOT a measured end-to-end playthrough.
## Jumps between representative scenes deliberately; real input drives poses.
var review_clock := 0.0
var review_stage := 0
var captured: Dictionary = {}
var performance_samples: Array[Dictionary] = []
func _ready() -> void:
	super._ready()
	save_enabled = false
func _process(dt: float) -> void:
	super._process(dt)
	review_clock += dt
	if review_stage>0 and Engine.get_process_frames()%30==0: performance_samples.append({"stage":review_stage,"fps":Engine.get_frames_per_second(),"frame_ms":dt*1000.0})
	if review_clock>1 and not captured.has("title"): _capture("title")
	if review_clock>2 and review_stage==0:
		review_stage=1
		start_new(true)
		chapter_left=0
	if review_stage==1:
		input_override={"right":1.0,"jump":review_clock>3 and review_clock<3.22}
		if review_clock>3.3 and not captured.has("city_jump"): _capture("city_jump")
	if review_clock>5 and review_stage==1:
		review_stage=2
		load_sector(2)
		player.reset_actor(sectors[2].station,1)
		input_override={}
		interact()
	if review_clock>6 and not captured.has("exchange"): _capture("exchange")
	if review_clock>7 and review_stage==2:
		review_stage=3
		choose_sight(true)
		load_sector(3)
		player.reset_actor(Vector2(1360,-80),1)
		chapter_left=0
		tap_weapon()
	if review_stage==3:
		input_override={"right":1.0,"attack":int(review_clock*4)%2==0}
		if review_clock>7.35 and not captured.has("blind_pulse"): _capture("blind_pulse")
		if review_clock>8.3 and not captured.has("blind_combat"): _capture("blind_combat")
	if review_clock>10 and review_stage==3:
		review_stage=4
		blind=false
		load_sector(5)
		player.reset_actor(Vector2(895,300),1)
		chapter_left=0
		input_override={}
	if review_stage==4:
		input_override={"shield":true,"right":0.0}
		if review_clock>11.2 and not captured.has("warden"): _capture("warden")
	if review_clock>13 and review_stage==4:
		review_stage=5
		load_sector(6)
		player.reset_actor(Vector2(655,300),1)
		interact()
	if review_clock>14 and not captured.has("ending"): _capture("ending")
	if review_clock>15:
		var report_file=FileAccess.open("res://demo/evidence/native_performance.json",FileAccess.WRITE)
		report_file.store_string(JSON.stringify(performance_samples,"\t"))
		print("NATIVE MISSION REVIEW CAPTURE COMPLETE ",captured.keys())
		get_tree().quit()
func _capture(label: String) -> void:
	captured[label]=true
	_capture_frame.call_deferred(label)
func _capture_frame(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://demo/evidence/native_"+label+".png")
	print("NATIVE CAPTURE ",label," ",result)
