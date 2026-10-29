extends "res://combat_pc/ground_response_review.gd"
## Same PC, same phase/pose/contact system. Compare only fresh input admission.
const CHAIN_BEFORE = preload("res://combat_pc/resources/light_chain.tres")
const CHAIN_AFTER = preload("res://combat_pc/resources/responsive_chain.tres")
const APPROVED_MOVEMENT = preload("res://combat_pc/resources/air_response_agile.tres")
const LABELS = ["SLASH", "BACKHAND", "FINISHER"]
@onready var target = $Target
var trial := -1
var target_enabled := true
var starts: Array[String] = []
var rejected := {"too_early":0,"chain_complete":0,"queue_full":0}
var event_log: Array[Dictionary] = []
var last_event := "READY"
var last_step := -1
var last_step_age := 9.0

func _ready() -> void:
	_apply_profile(1)
	_reset()
	player.movement_event.connect(_movement)
	target.struck.connect(_contact)
	DirAccess.make_dir_recursive_absolute("res://delivery/combo_response_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")

func _apply_profile(index: int) -> void:
	profile_index=clampi(index,0,1)
	player.profile=APPROVED_MOVEMENT
	view.ground_presentation=PRESENTATION
	player.melee_chain=CHAIN_BEFORE if profile_index==0 else CHAIN_AFTER
	player.melee_input_profile=null # Explicit Fresh mode in both comparisons.

func _reset() -> void:
	case_index=0
	super._reset()
	target.reset_target()
	target.collision_layer=4 if target_enabled else 0
	starts.clear(); rejected={"too_early":0,"chain_complete":0,"queue_full":0}
	last_event="READY"; last_step=-1; last_step_age=9.0
	trial=-1

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	if not paused: last_step_age+=dt

func _guided_input(t: float) -> Dictionary:
	var wanted_trial := 0 if t<1.8 else (1 if t<4.8 else 2)
	if wanted_trial!=trial:
		_reset()
		trial=wanted_trial
	var held := false
	if trial==0:
		instruction="EARLY FOLLOW-UP / THREE DISTINCT TAPS"
		for edge in [0.30,0.34,0.60]:
			if t>=edge and t<edge+0.018: held=true
	elif trial==1:
		var local_time := t-1.8
		instruction="RAPID FRESH TAPS / ONE NEXT STRIKE"
		if local_time>=0.35 and local_time<1.85:
			held=fposmod(local_time-0.35,0.10)<0.025
	else:
		var local_time := t-4.8
		instruction="HOLD ATTACK / FRESH MODE GIVES ONE STRIKE"
		held=local_time>=0.35 and local_time<1.35
	return {"attack":held}

func _movement(kind: StringName, payload: Dictionary) -> void:
	if kind==&"attack_started":
		var label := String(payload.get("step_label","Strike"))
		starts.append(label)
		while starts.size()>9: starts.pop_front()
		last_step=int(payload.get("step_index",-1)); last_step_age=0
		last_event="STARTED "+label.to_upper()
	elif kind==&"chain_input_queued":
		last_event="QUEUED "+String(payload.get("kind","" )).to_upper()
	elif kind==&"chain_input_rejected":
		var reason := String(payload.get("reason",""))
		if rejected.has(reason): rejected[reason]+=1
	elif kind in [&"chain_input_expired", &"chain_reset"]:
		last_event=String(payload.get("reason",kind)).to_upper()
	if recording>0 and kind in [&"attack_started",&"attack_finished",&"attack_phase_changed",&"chain_input_queued",&"chain_input_rejected",&"chain_input_expired",&"chain_reset",&"strike_confirmed",&"reset"]:
		event_log.append({"seconds":(Time.get_ticks_usec()-capture_started)/1000000.0,"profile":profile_index,"trial":trial,"kind":String(kind),"payload":_json_value(payload)})

func _contact(payload: Dictionary) -> void:
	if recording>0:
		event_log.append({"seconds":(Time.get_ticks_usec()-capture_started)/1000000.0,"profile":profile_index,"trial":trial,"kind":"actual_target_contact","payload":_json_value(payload)})

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
		get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Combo-Response.png")
	elif event.physical_keycode==KEY_E and not paused:
		target_enabled=not target_enabled
		target.collision_layer=4 if target_enabled else 0
	elif event.physical_keycode==KEY_O:
		event_log.clear()
		super._unhandled_key_input(event)
	elif event.physical_keycode!=KEY_F:
		super._unhandled_key_input(event)

func _process(dt: float) -> void:
	queue_redraw()
	if recording<=0: return
	recording-=dt; capture_clock+=dt
	if capture_clock>=1.0/60.0:
		capture_clock-=1.0/60.0
		await RenderingServer.frame_post_draw
		var filename := "frame_%04d.png"%frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/combo_response_capture/"+filename)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		var state: Dictionary=player.telemetry()
		frames.append({"file":filename,"raw_seconds":elapsed})
		trace.append({"seconds":elapsed,"profile":profile_index,"trial":trial,"guided":guided,"instruction":instruction,"paused":paused,"position":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"facing":player.facing,"visual_facing":view.get_pose().get("facing",0),"pose":view.pose_name,"main_action":String(player.main_action),"weapon_phase":String(player.weapon_phase),"step":state.attack_step_index,"chain_serial":state.chain_serial,"attack_serial":player.attack_serial,"pending_step":state.chain_pending_step,"pending_kind":String(state.chain_pending_kind),"pending_remaining":state.chain_pending_remaining,"starts":starts.duplicate(),"rejected":rejected.duplicate(),"target_enabled":target_enabled,"actual_hits":target.hits,"health":$Player/Health.current_health,"noise_count":event_bus.event_count})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/player.gd","combat_pc/visuals/wireframe.gd","combat_pc/combo_response_review.gd","combat_pc/ground_response_review.gd","combat_pc/resources/melee_chain.gd","combat_pc/resources/melee_step.gd","combat_pc/fixtures/chain_target.gd"]:
			var script: Script=load("res://"+path)
			hashes[path]=script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M20-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Completed native viewport; same fresh-input program and public resets per labelled trial; existing actual strike/contact system, phase clocks and hitpause.","frames":frames,"trace":trace,"events":event_log},"  "))

func render_hud(canvas: Node2D) -> void:
	if not is_instance_valid(player): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8095a7")
	var accent := Color("a4f0d5") if profile_index==1 else Color("e6b584")
	var state: Dictionary=player.telemetry()
	canvas.draw_rect(Rect2(0,0,640,133),Color("070b10"))
	canvas.draw_rect(Rect2(0,294,640,66),Color("070b10"))
	canvas.draw_string(font,Vector2(28,26),"MOKSHA / COMBO RESPONSE",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	canvas.draw_string(font,Vector2(28,47),("2  RESPONSIVE TAPS" if profile_index==1 else "1  PREVIOUS TAPS")+"    FRESH INPUT / ONE QUEUED STRIKE",HORIZONTAL_ALIGNMENT_LEFT,-1,9,accent)
	canvas.draw_string(font,Vector2(28,66),("SAME INPUT  /  " if guided else "")+instruction,HORIZONTAL_ALIGNMENT_LEFT,-1,8,ink)
	for i in 3:
		var x := 28.0+i*143.0
		var active: bool = int(state.attack_step_index)==i and player.weapon_phase!=&"idle"
		canvas.draw_rect(Rect2(x,79,134,23),Color(accent,0.16) if active else Color("142029"))
		canvas.draw_string(font,Vector2(x+7,94),str(i+1)+" "+LABELS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,9,accent if active else muted)
	var next_label: String=LABELS[int(state.chain_pending_step)] if int(state.chain_pending_step)>=0 and int(state.chain_pending_step)<3 else "EMPTY"
	canvas.draw_string(font,Vector2(28,121),"NEXT "+next_label+"   "+String(player.weapon_phase).to_upper()+"   ACTUAL HITS %d"%target.hits,HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,310),"J tap attack   A/D move   1 previous / 2 responsive   R reset",HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	canvas.draw_string(font,Vector2(28,329),"Q compare   E target "+("ON" if target_enabled else "OFF / WHIFF")+"   ESC pause   Hold J = one strike",HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,348),"Same strike poses, phase timing and power. One fresh tap can wait; no backlog.",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	if paused: canvas.draw_string(font,Vector2(260,165),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
