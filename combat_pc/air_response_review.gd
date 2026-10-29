extends "res://combat_pc/ground_response_review.gd"
## Reuse the prior one-PC review host, geometry, reset and profile controls.
## Only horizontal ordinary-air acceleration differs between these resources.
const AIR_BASELINE = preload("res://combat_pc/resources/ground_response_agile.tres")
const AIR_CANDIDATE = preload("res://combat_pc/resources/air_response_agile.tres")
const AIR_CASES = ["FLAT / AIR CORRECTION", "SLOPE / JUMP AND LAND", "MOVING FLOOR / JUMP DEPARTURE"]
var flight_path: Array[Vector2] = []
var reverse_points: Array[Dictionary] = []
var prior_air_input := 0.0

func _ready() -> void:
	_apply_profile(1)
	_reset()
	player.movement_event.connect(_movement)
	DirAccess.make_dir_recursive_absolute("res://delivery/air_response_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")

func _apply_profile(index: int) -> void:
	profile_index=clampi(index,0,1)
	player.profile=AIR_BASELINE if profile_index==0 else AIR_CANDIDATE
	view.ground_presentation=PRESENTATION

func _reset() -> void:
	super._reset()
	flight_path.clear(); reverse_points.clear(); prior_air_input=0

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	if paused: return
	if not player.grounded:
		flight_path.append(player.global_position)
		if player.move_x!=0 and prior_air_input!=0 and signf(player.move_x)!=signf(prior_air_input):
			reverse_points.append({"at":player.global_position,"age":0.0})
	prior_air_input=player.move_x
	while flight_path.size()>110: flight_path.pop_front()
	for marker in reverse_points: marker.age+=dt
	reverse_points=reverse_points.filter(func(m):return m.age<1.2)

func _guided_input(t: float) -> Dictionary:
	var f := {}
	var label := "READY / SAME APPROVED GROUND RESPONSE"
	if t>=0.3 and t<0.55: f={"right":1.0}; label="RUN RIGHT"
	elif t>=0.55 and t<0.70: f={"right":1.0,"jump":true}; label="JUMP RIGHT"
	elif t>=0.70 and t<1.20: f={"left":1.0,"jump":t<0.82}; label="CORRECT LEFT IN AIR"
	elif t>=1.20 and t<1.60: label="LAND / SETTLE"
	elif t>=1.60 and t<1.90: f={"left":1.0}; label="RUN LEFT"
	elif t>=1.90 and t<2.05: f={"left":1.0,"jump":true}; label="JUMP LEFT"
	elif t>=2.05 and t<2.55: f={"right":1.0,"jump":t<2.17}; label="CORRECT RIGHT IN AIR"
	elif t>=2.55 and t<3.00: label="LAND / SETTLE"
	elif t>=3.00 and t<3.30: f={"right":1.0}; label="BUILD RIGHT"
	elif t>=3.30 and t<3.45: f={"right":1.0,"jump":true}; label="JUMP / RELEASE STEERING"
	elif t>=3.45 and t<3.80: f={"jump":t<3.60}; label="NEUTRAL DRIFT / UNCHANGED"
	elif t>=3.80 and t<4.10: f={"left":1.0}; label="CORRECT / LAND"
	elif t>=4.10 and t<4.40: label="SETTLE"
	elif t>=4.40 and t<4.65: f={"left":1.0}; label="RUN LEFT"
	elif t>=4.65 and t<4.90: f={"left":1.0,"jump":true}; label="JUMP LEFT"
	elif t>=4.90 and t<5.05: f={"right":1.0}; label="CORRECT RIGHT"
	elif t>=5.05 and t<5.25: f={"right":1.0,"jump":true}; label="EXISTING AIR JUMP / SAME BUDGET"
	elif t>=5.25 and t<5.85: f={"left":1.0}; label="CORRECT LEFT / FALL"
	elif t>=5.85 and t<6.20: label="LAND / SETTLE"
	elif t>=6.20 and t<6.40: f={"right":1.0}; label="RUN RIGHT"
	elif t>=6.40 and t<6.50: f={"right":1.0,"jump":t<6.46}; label="SHORT JUMP / SAME HEIGHT"
	elif t>=6.50 and t<6.80: f={"left":1.0}; label="SHORT-JUMP CORRECTION"
	elif t>=6.80: label="LAND / SETTLE"
	instruction=label; _last_guided_phase=label
	return f

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_P:
		get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Air-Response.png")
	else: super._unhandled_key_input(event)

func _process(dt: float) -> void:
	queue_redraw()
	if recording<=0: return
	recording-=dt; capture_clock+=dt
	if capture_clock>=1.0/60.0:
		capture_clock-=1.0/60.0
		await RenderingServer.frame_post_draw
		var filename := "frame_%04d.png"%frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/air_response_capture/"+filename)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		trace.append({"seconds":elapsed,"profile":profile_index,"course":case_index,"guided":guided,"instruction":instruction,"paused":paused,"position":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"move_x":player.move_x,"grounded":player.grounded,"facing":player.facing,"visual_facing":view.get_pose().get("facing",0),"pose":view.pose_name,"main_action":String(player.main_action),"weapon_phase":String(player.weapon_phase),"air_jumps_left":player.air_jumps_left,"health":$Player/Health.current_health,"noise_count":event_bus.event_count})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/player.gd","combat_pc/visuals/wireframe.gd","combat_pc/air_response_review.gd","combat_pc/ground_response_review.gd","combat_pc/resources/movement_profile.gd","combat_pc/resources/air_response_profile.gd"]:
			var script: Script=load("res://"+path)
			hashes[path]=script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M19-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Actual native Godot viewport after completed draw. Identical ordinary input sequence applied to previous and candidate profiles; actual physics and existing jump actions.","frames":frames,"trace":trace},"  "))

func _draw() -> void:
	super._draw()
	var accent := Color("a4f0d5") if profile_index==1 else Color("e6b584")
	if flight_path.size()>1:
		for i in range(1,flight_path.size()):
			if flight_path[i].distance_to(flight_path[i-1])<12:
				draw_line(flight_path[i-1],flight_path[i],Color(accent,0.10+float(i)/flight_path.size()*0.35),0.6)
	for marker in reverse_points:
		draw_circle(marker.at,2.2,Color(accent,1-marker.age/1.2),false,0.8)
	if is_instance_valid(player):
		# These are inspection cues only: facing/input and actual momentum can
		# disagree during a finite correction. Neither arrow drives the actor.
		var origin: Vector2=player.position+Vector2(0,12)
		draw_line(origin,origin+Vector2(player.velocity.x/9.0,0),Color("dcaa70"),1.0)
		if not is_zero_approx(player.velocity.x):
			var tip: Vector2=origin+Vector2(player.velocity.x/9.0,0)
			draw_line(tip,tip+Vector2(-signf(player.velocity.x)*3,-2),Color("dcaa70"),0.8)

func render_hud(canvas: Node2D) -> void:
	if not is_instance_valid(player): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8095a7")
	var accent := Color("a4f0d5") if profile_index==1 else Color("e6b584")
	canvas.draw_rect(Rect2(0,0,640,111),Color("070b10"))
	canvas.draw_rect(Rect2(0,294,640,66),Color("070b10"))
	canvas.draw_string(font,Vector2(28,27),"MOKSHA / AIR STEERING",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	canvas.draw_string(font,Vector2(28,49),("2  QUICKER AIR" if profile_index==1 else "1  PREVIOUS AIR")+"    "+AIR_CASES[case_index],HORIZONTAL_ALIGNMENT_LEFT,-1,10,accent)
	canvas.draw_string(font,Vector2(28,68),("SAME INPUT  /  " if guided else "")+instruction,HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	canvas.draw_string(font,Vector2(28,91),"HORIZONTAL %+.0f   FACE %s   %s   AIR JUMP %d"%[player.velocity.x,"RIGHT" if player.facing>0 else "LEFT",view.pose_name.to_upper(),player.air_jumps_left],HORIZONTAL_ALIGNMENT_LEFT,-1,10,muted)
	canvas.draw_string(font,Vector2(28,310),"A/D steer   SPACE jump / air jump   1 previous / 2 quicker",HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)
	canvas.draw_string(font,Vector2(28,329),"Q same-input comparison   F course   R reset   ESC pause",HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,348),"Gold arrow = momentum. Same jump height, speed cap and neutral drift.",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	if paused: canvas.draw_string(font,Vector2(260,173),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
