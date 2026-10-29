extends "res://combat_pc/ground_response_review.gd"
## Single optional receiver response; the old motor and contact path stay intact.
const APPROVED_MOVEMENT = preload("res://combat_pc/resources/air_response_agile.tres")
const APPROVED_CHAIN = preload("res://combat_pc/resources/responsive_chain.tres")
const CASES = ["OPEN FLOOR / THREE STRIKES", "RIGHT WALL / COLLISION STOP", "LEFT WALL / MIRRORED RESPONSE"]
@onready var target = $Target
@onready var hurtbox = $Target/Hurtbox
@onready var response = $Target/Knockback
var target_start := Vector2(310,270)
var trial := -1
var events: Array[Dictionary] = []

func _ready() -> void:
	_apply_profile(1)
	_reset()
	response.knockback_applied.connect(_on_response)
	hurtbox.struck.connect(_on_contact)
	DirAccess.make_dir_recursive_absolute("res://delivery/knockback_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")

func _apply_profile(index: int) -> void:
	profile_index=clampi(index,0,1)
	player.profile=APPROVED_MOVEMENT
	player.melee_chain=APPROVED_CHAIN
	player.melee_input_profile=null
	view.ground_presentation=PRESENTATION
	response.enabled=profile_index==1

func _reset() -> void:
	$Slope/Shape.disabled=true
	platform.moving=false; platform.get_node("Shape").disabled=true
	var direction := -1 if case_index==2 else 1
	var start := Vector2(360,270) if case_index==2 else Vector2(280,270)
	target_start=Vector2(330,270) if case_index==2 else Vector2(310,270)
	$ImpactWall.position=Vector2(292,210) if case_index==2 else Vector2(348,210)
	$ImpactWall/Shape.disabled=case_index==0
	player.reset_actor(start,direction)
	target.reset_at(target_start)
	target.facing=-direction
	response.reset_diagnostics()
	event_bus.clear_history()
	$Player/NoiseRelay.reset_diagnostics()
	trail.clear(); markers.clear(); _last_guided_phase=""; trial=-1

func _guided_input(t: float) -> Dictionary:
	var selected := 0 if t<2.5 else (1 if t<5.0 else 2)
	if selected!=trial:
		case_index=selected; _reset(); trial=selected
	var local_time := t-(0.0 if selected==0 else 2.5 if selected==1 else 5.0)
	var pressed := false
	for edge in [0.35,0.55,0.78]:
		if local_time>=edge and local_time<edge+0.018: pressed=true
	instruction=CASES[case_index]
	return {"attack":pressed}

func _on_contact(payload: Dictionary) -> void:
	if recording>0:
		events.append({"seconds":(Time.get_ticks_usec()-capture_started)/1000000.0,"profile":profile_index,"case":case_index,"kind":"actual_contact","payload":_json_value(payload),"target_position":_json_value(target.global_position)})

func _on_response(receipt: Dictionary) -> void:
	if recording>0:
		events.append({"seconds":(Time.get_ticks_usec()-capture_started)/1000000.0,"profile":profile_index,"case":case_index,"kind":"knockback_applied","receipt":_json_value(receipt)})

func _json_value(value):
	if value is Vector2: return [value.x,value.y]
	if value is Dictionary:
		var result := {}
		for key in value: result[String(key)]=_json_value(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_json_value(item))
		return result
	if value is Object: return value.get_instance_id() if is_instance_valid(value) else 0
	return value

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode==KEY_P:
		get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Strike-Knockback.png")
	elif event.physical_keycode==KEY_O:
		events.clear(); super._unhandled_key_input(event)
	else: super._unhandled_key_input(event)

func _process(dt: float) -> void:
	queue_redraw()
	if recording<=0: return
	recording-=dt; capture_clock+=dt
	if capture_clock>=1.0/60.0:
		capture_clock-=1.0/60.0
		await RenderingServer.frame_post_draw
		var filename := "frame_%04d.jpg"%frames.size()
		get_viewport().get_texture().get_image().save_jpg("res://delivery/knockback_capture/"+filename,0.94)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		trace.append({"seconds":elapsed,"profile":profile_index,"case":case_index,"guided":guided,"instruction":instruction,"paused":paused,"pc_position":_json_value(player.position),"pc_pose":view.pose_name,"pc_phase":String(player.weapon_phase),"pc_facing":player.facing,"pc_pause":player.hitpause_remaining,"target_position":_json_value(target.position),"target_velocity":_json_value(target.velocity),"target_grounded":target.is_on_floor(),"target_pause":target.pause_left,"target_stun":target.stun_left,"actual_hits":hurtbox.hits,"response":_json_value(response.diagnostic_snapshot()),"health":$Player/Health.current_health})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/player.gd","combat_pc/components/contact_adapter.gd","combat_pc/components/strike_knockback.gd","combat_pc/resources/knockback_profile.gd","combat_pc/fixtures/knockback_target.gd","combat_pc/fixtures/contact_target.gd","combat_pc/fixtures/chain_target.gd","movement/components/movement_motor.gd","combat_pc/knockback_review.gd"]:
			var script: Script=load("res://"+path)
			hashes[path]=script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M21-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Completed native viewport. Same three actual strikes with receiver response OFF then ON, reset per labelled floor/wall/mirrored trial. Existing motor resolves all motion and contacts.","frames":frames,"trace":trace,"events":events},"  "))

func _draw() -> void:
	draw_rect(Rect2(0,0,640,360),Color("070b10"))
	draw_line(Vector2(28,270),Vector2(612,270),Color("728694"),0.8)
	for x in range(40,615,22): draw_line(Vector2(x,273),Vector2(x,277),Color("33434f"),0.7)
	if case_index!=0:
		draw_rect(Rect2($ImpactWall.position-Vector2(4,60),Vector2(8,120)),Color("91a5b1"),false,0.9)
	if is_instance_valid(target):
		draw_line(target_start+Vector2(0,4),target_start+Vector2(0,13),Color("64727f"),0.8)
		draw_line(target_start+Vector2(0,7),target.position+Vector2(0,7),Color("e6b47e"),1)
		draw_circle(target.position,1.4,Color("e6b47e"))

func render_hud(canvas: Node2D) -> void:
	if not is_instance_valid(response): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8095a7")
	var accent := Color("a4f0d5") if profile_index==1 else Color("e6b584")
	canvas.draw_rect(Rect2(0,0,640,117),Color("070b10"))
	canvas.draw_rect(Rect2(0,294,640,66),Color("070b10"))
	canvas.draw_string(font,Vector2(28,27),"MOKSHA / STRIKE KNOCKBACK",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	canvas.draw_string(font,Vector2(28,48),"PHYSICAL RESPONSE "+("ON" if profile_index==1 else "OFF")+"    "+CASES[case_index],HORIZONTAL_ALIGNMENT_LEFT,-1,9,accent)
	canvas.draw_string(font,Vector2(28,69),"HITS %d   APPLIED %d   ROOT TRAVEL %+.1f px"%[hurtbox.hits,response.applied_count,target.position.x-target_start.x],HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)
	canvas.draw_string(font,Vector2(28,92),"TARGET VX %+.0f   %s   PC %s"%[target.velocity.x,"RECOVERING" if target.stun_left>0 else "READY",String(player.weapon_phase).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,310),"J attack   A/D chase   1 response off / 2 on   R reset",HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)
	canvas.draw_string(font,Vector2(28,329),"Q same-input comparison   F floor/wall/mirror   ESC pause",HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,348),"Existing strike impulse and collision motor. One detachable response.",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	if paused: canvas.draw_string(font,Vector2(260,165),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
