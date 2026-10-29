extends Node2D
## A bounded input fixture reuses the existing NPC motor. Only the detachable
## source decides whether its completed physical motion creates a noise.
const CASE_NAMES = ["FLAT WALK / STOP / REVERSE / HOP", "SLOPE WALK / CONTACT ORIGINS", "MOVING SUPPORT / QUIET RIDING"]
@onready var player = $Player
@onready var npc = $NPC
@onready var source = $NPC/Footsteps
@onready var event_bus = $SoundEvents
@onready var surface = $SurfacePulse
@onready var platform = $MovingSupport
var paused := false
var guides := true
var walking := false
var direction := 1
var case_index := 0
var case_run := 0
var step_count := 0
var landing_count := 0
var last_event: Dictionary = {}
var marks: Array[Dictionary] = []
var _pending_case := -1
var _jump_pending := false
var _jump_hold := 0.0
var _was_jump_held := false
var recording := 0.0
var capture_clock := 0.0
var capture_started := 0
var frames: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []

func _ready() -> void:
	npc.tuning = npc.tuning.duplicate(true)
	npc.tuning.run_speed = 95.0
	source.footstep_emitted.connect(_on_footstep)
	_apply_case(0)
	DirAccess.make_dir_recursive_absolute("res://delivery/npc_step_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")

func _physics_process(dt: float) -> void:
	if paused: return
	if _pending_case>=0:
		var selected := _pending_case
		_pending_case=-1
		_apply_case(selected)
	player.physics_tick(dt)
	if walking:
		var low := 180.0 if case_index==0 else 190.0
		var high := 552.0 if case_index==0 else 534.0
		if case_index==2:
			low=platform.global_position.x+38.0
			high=platform.global_position.x+202.0
		if npc.global_position.x>=high and direction>0: direction=-1
		elif npc.global_position.x<=low and direction<0: direction=1
	var held := _jump_hold>0.0
	npc.set_intent(float(direction) if walking else 0.0,_jump_pending,_was_jump_held and not held,false,held)
	_jump_pending=false
	_was_jump_held=held
	_jump_hold=maxf(0,_jump_hold-dt)

func select_case(index: int) -> void:
	if not paused: _pending_case=clampi(index,0,2)

func _apply_case(index: int) -> void:
	surface.unbind_surface()
	source.reset_history()
	case_index=clampi(index,0,2)
	case_run+=1
	walking=false
	direction=1
	_jump_pending=false; _jump_hold=0.0; _was_jump_held=false
	$Slope/Shape.disabled=case_index!=1
	platform.moving=false
	platform.get_node("Shape").disabled=case_index!=2
	var start := Vector2(280,270)
	if case_index==1: start=Vector2(210,260)
	elif case_index==2: start=platform.global_position+Vector2(80,0)
	npc.reset_at(start)
	player.reset_actor(Vector2(92,270),1)
	event_bus.clear_history()
	$Player/NoiseRelay.reset_diagnostics()
	source.reset_diagnostics()
	step_count=0; landing_count=0
	last_event.clear(); marks.clear()
	platform.moving=case_index==2
	surface.bind_surface(self,player,event_bus)
	queue_redraw()

func _on_footstep(event: Dictionary) -> void:
	if event.kind==&"enemy_step": step_count+=1
	elif event.kind==&"enemy_land": landing_count+=1
	last_event=event.duplicate(true)
	marks.append({"origin":event.origin,"age":0.0,"landing":event.kind==&"enemy_land"})
	while marks.size()>16: marks.pop_front()
	if recording>0:
		var saved: Dictionary=_json_value(event)
		saved["raw_seconds"]=(Time.get_ticks_usec()-capture_started)/1000000.0
		saved["case_index"]=case_index; saved["case_run"]=case_run
		saved["bus_count"]=event_bus.event_count
		saved["surface_count"]=surface.accepted_event_count
		events.append(saved)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1: select_case(0)
		KEY_2: select_case(1)
		KEY_3: select_case(2)
		KEY_Q: walking=not walking
		KEY_A: direction=-1; walking=true
		KEY_D: direction=1; walking=true
		KEY_SPACE:
			if not paused and npc.is_on_floor(): _jump_pending=true; _jump_hold=0.16
		KEY_E: source.enabled=not source.enabled
		KEY_G: guides=not guides
		KEY_R: select_case(case_index)
		KEY_ESCAPE:
			paused=not paused
			surface.simulation_enabled=not paused
			get_tree().paused=paused
		KEY_O:
			recording=20.0; capture_clock=0.0; capture_started=Time.get_ticks_usec()
			frames.clear(); trace.clear(); events.clear()
		KEY_P: get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-NPC-Footstep.png")
	queue_redraw()

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
	return value

func _process(dt: float) -> void:
	if not paused:
		for mark in marks: mark.age+=dt
		marks=marks.filter(func(mark):return mark.age<0.4)
	queue_redraw()
	if recording<=0: return
	recording-=dt; capture_clock+=dt
	if capture_clock>=1.0/60.0:
		capture_clock-=1.0/60.0
		var filename := "frame_%04d.png"%frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/npc_step_capture/"+filename)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		trace.append({"seconds":elapsed,"case_index":case_index,"case_run":case_run,"source_enabled":source.enabled,"walking":walking,"direction":direction,"bus_count":event_bus.event_count,"surface_count":surface.accepted_event_count,"steps":step_count,"landings":landing_count,"pulse_count":surface.pulses.size(),"paused":paused,"guides":guides,"npc_position":_json_value(npc.global_position),"npc_velocity":_json_value(npc.velocity),"npc_grounded":npc.is_on_floor(),"npc_facing":npc.facing,"platform_position":_json_value(platform.global_position),"source":_json_value(source.debug_snapshot())})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/components/character_footsteps.gd","combat_pc/resources/footstep_profile.gd","combat_pc/fixtures/footstep_npc_motor.gd","combat_pc/fixtures/npc_footstep_wire.gd","combat_pc/npc_footstep_review.gd","movement/components/movement_motor.gd","combat_pc/player.gd","scripts/sensory/noise_bus.gd","combat_pc/components/surface_pulse.gd"]:
			var script: Script=load("res://"+path)
			hashes[path]=script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M17-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Actual native input, existing NPC motor and physics; optional explicit post-motion contact source; no timed synthetic noise","frames":frames,"trace":trace,"events":events},"  "))

func _draw() -> void:
	draw_rect(Rect2(0,0,640,360),Color("030608"))
	if guides:
		draw_line(Vector2(28,270),Vector2(612,270),Color("24353d"),0.7)
		if case_index==1: draw_polyline(PackedVector2Array([Vector2(180,270),Vector2(340,220),Vector2(460,220),Vector2(550,270)]),Color("35434b"),0.7)
		elif case_index==2 and is_instance_valid(platform): draw_rect(Rect2(platform.position,platform.size),Color("35434b"),false,0.7)
	for mark in marks:
		var c := Color(1.0,0.72,0.4,1.0-mark.age/0.4)
		draw_line(mark.origin-Vector2(4,0),mark.origin+Vector2(4,0),c,1.2)
		if mark.landing: draw_circle(mark.origin,3,c,false,1)

func render_hud(canvas: Node2D) -> void:
	if not is_instance_valid(source): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8099a9")
	canvas.draw_rect(Rect2(0,0,640,110),Color("030608"))
	canvas.draw_rect(Rect2(0,294,640,66),Color("030608"))
	canvas.draw_string(font,Vector2(28,29),"MOKSHA / ONE PIECE: NPC FOOTSTEPS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	canvas.draw_string(font,Vector2(28,49),CASE_NAMES[case_index],HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,77),"SOURCE "+("CONNECTED" if source.enabled else "DISCONNECTED"),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8fe0ca") if source.enabled else Color("e9b27e"))
	canvas.draw_string(font,Vector2(376,77),"STEPS %d  LAND %d  NOISE %d"%[step_count,landing_count,event_bus.event_count],HORIZONTAL_ALIGNMENT_LEFT,-1,8,ink)
	var description := "Q STARTS THE NPC. IDLE AND PASSIVE RIDING STAY QUIET."
	if not last_event.is_empty(): description="%s / %s  AT %.0f, %.0f"%[String(last_event.kind).to_upper(),last_event.support_name,last_event.origin.x,last_event.origin.y]
	canvas.draw_string(font,Vector2(28,101),description,HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	if guides: canvas.draw_string(font,Vector2(28,121),"DIM GUIDES ON / WHITE SURFACES FOLLOW ACTUAL SOUND",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	canvas.draw_string(font,Vector2(28,308),"1 FLAT   2 SLOPE   3 MOVING FLOOR   Q WALK / IDLE",HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	canvas.draw_string(font,Vector2(28,328),"A/D DIRECTION   SPACE HOP   E SOURCE   G GUIDES   R RESET   ESC PAUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	canvas.draw_string(font,Vector2(28,348),"STEP SPACING FOLLOWS GROUND TRAVEL. LANDING HAS ITS OWN EVENT.",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	if paused: canvas.draw_string(font,Vector2(283,150),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
