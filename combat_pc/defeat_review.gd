extends "res://combat_pc/health_review.gd"
## One additional component attached to the previous health review fixture.
## The response itself never resets the actor; R is the existing host command.
func _ready() -> void:
	super._ready()
	DirAccess.make_dir_recursive_absolute("res://delivery/defeat_capture")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_Q,KEY_1]: start_replay(0)
	elif event.physical_keycode not in [KEY_2,KEY_3,KEY_4]: super._unhandled_key_input(event)
	queue_redraw()

func _process(dt: float) -> void:
	if recording <= 0: return
	recording -= dt
	capture_clock += dt
	if capture_clock >= 1.0 / 60.0:
		capture_clock -= 1.0 / 60.0
		var filename := "frame_%04d.png" % frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/defeat_capture/" + filename)
		var elapsed := (Time.get_ticks_usec() - capture_started) / 1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		var t: Dictionary = player.telemetry()
		trace.append({"seconds":elapsed,"health":health.current_health,"defeated":player.is_defeated(),"progress":t.get("defeat_progress",0),"outcome":last_outcome,"position":player.position,"velocity":player.velocity,"grounded":player.grounded,"state":player.main_action,"pose":player.pose,"weapon":player.weapon_phase,"shield":player.shield_phase,"fixture_contacts":contact.contacts,"paused":paused,"inputs":{"right":Input.is_action_pressed("cp_right"),"left":Input.is_action_pressed("cp_left"),"jump":Input.is_action_pressed("cp_jump"),"attack":Input.is_action_pressed("cp_attack"),"shield":Input.is_action_pressed("cp_shield")}})
	if recording <= 0:
		var hashes := {}
		for path in ["player.gd","components/health_component.gd","components/defeat_response.gd","visuals/defeat_pose.gd","visuals/wireframe.gd","visuals/wireframe_pose.gd","defeat_review.gd"]:
			var script: Script = load("res://combat_pc/"+path)
			hashes[path]=script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M13-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Actual native viewport; real physical lethal contact, ordinary manual input and explicit R reset","frames":frames,"trace":trace,"receipts":receipts},"  "))

func _draw() -> void:
	if not is_instance_valid(health): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8099a9")
	var defeated: bool = player.is_defeated()
	var accent := Color("ed917c") if defeated else Color("8fe0ca")
	draw_rect(Rect2(0,0,640,360),Color("091018"))
	draw_string(font,Vector2(28,30),"MOKSHA / ONE PIECE: ZERO HEALTH",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	draw_string(font,Vector2(28,49),"LETHAL HIT > COLLAPSE > EXPLICIT RESET",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_string(font,Vector2(28,82),"HEALTH  %.0f / %.0f"%[health.current_health,health.capacity],HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	draw_rect(Rect2(28,94,584,16),Color("22303b"))
	draw_rect(Rect2(28,94,584*health.current_health/health.capacity,16),accent)
	draw_string(font,Vector2(28,133),"DEFEATED / INPUT LOCKED" if defeated else "CONTROL AVAILABLE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
	draw_string(font,Vector2(28,155),"R RESETS THE PC" if defeated else ("REPLAY: LETHAL CONTACT" if replay>=0 else "FREE CONTROL"),HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	var attempts: PackedStringArray = []
	for action in ["left","right","jump","attack","shield"]:
		if Input.is_action_pressed("cp_"+action): attempts.append(action.to_upper())
	draw_string(font,Vector2(28,177),"INPUT: "+(" + ".join(attempts) if not attempts.is_empty() else "NONE"),HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_line(Vector2(28,260),Vector2(612,260),Color("7897a5"),1)
	draw_string(font,Vector2(232,281),"HEALTH + DEFEAT RESPONSE",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	draw_string(font,Vector2(28,310),"Q REPLAY LETHAL HIT     F SEND HIT     R RESET",HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	draw_string(font,Vector2(28,329),"TRY A/D MOVE, SPACE JUMP, J ATTACK OR K SHIELD AT ZERO",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_string(font,Vector2(28,348),"ESC PAUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	if paused: draw_string(font,Vector2(282,190),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
