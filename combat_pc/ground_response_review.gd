extends Node2D
## One PC, two explicit resources, the same physical course and input sequence.
## Guided comparison supplies ordinary input to the unchanged action graph.
const BASELINE = preload("res://combat_pc/resources/movement_profile.tres")
const AGILE = preload("res://combat_pc/resources/ground_response_agile.tres")
const PRESENTATION = preload("res://combat_pc/resources/ground_presentation_agile.tres")
const CASE_NAMES = ["FLAT / START, STOP AND REVERSE", "SLOPE / KEEP CONTACT", "MOVING FLOOR / RELATIVE MOTION"]
@onready var player = $Player
@onready var view = $Player/Visual
@onready var event_bus = $SoundEvents
@onready var platform = $MovingSupport
var profile_index := 1
var case_index := 0
var paused := false
var guided := false
var guided_time := 0.0
var guided_pass := 0
var instruction := "FREE CONTROL"
var _pending_reset := false
var _pending_profile := -1
var _pending_case := -1
var trail: Array[Vector2] = []
var markers: Array[Dictionary] = []
var recording := 0.0
var capture_clock := 0.0
var capture_started := 0
var frames: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var _last_guided_phase := ""

func _ready() -> void:
	_apply_profile(1)
	_reset()
	player.movement_event.connect(_movement)
	DirAccess.make_dir_recursive_absolute("res://delivery/ground_response_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")

func _apply_profile(index: int) -> void:
	profile_index=clampi(index,0,1)
	player.profile=BASELINE if profile_index==0 else AGILE
	view.ground_presentation=null if profile_index==0 else PRESENTATION

func _reset() -> void:
	$Slope/Shape.disabled=case_index!=1
	platform.moving=case_index==2
	platform.get_node("Shape").disabled=case_index!=2
	var at := Vector2(280,270)
	if case_index==1: at=Vector2(210,260)
	elif case_index==2: at=platform.global_position+Vector2(80,0)
	player.reset_actor(at,1)
	event_bus.clear_history()
	$Player/NoiseRelay.reset_diagnostics()
	trail.clear(); markers.clear()
	_last_guided_phase=""

func _physics_process(dt: float) -> void:
	if paused: return
	if _pending_profile>=0:
		_apply_profile(_pending_profile); _pending_profile=-1; _pending_reset=true
	if _pending_case>=0:
		case_index=_pending_case; _pending_case=-1; _pending_reset=true
	if _pending_reset:
		_pending_reset=false; _reset()
	var inputs: Variant=null
	if guided:
		if guided_time>=8.0:
			if guided_pass==0:
				guided_pass=1; guided_time=0.0; _apply_profile(1); _reset()
			else: guided=false; instruction="COMPARISON FINISHED / TRY IT YOURSELF"
		if guided:
			inputs=_guided_input(guided_time)
			guided_time+=dt
	player.physics_tick(dt,inputs)
	trail.append(player.global_position)
	while trail.size()>24: trail.pop_front()
	for marker in markers: marker.age+=dt
	markers=markers.filter(func(m):return m.age<1.0)
	queue_redraw()

func _guided_input(t: float) -> Dictionary:
	var f := {}
	var label := "READY"
	if t>=0.5 and t<1.1: f={"right":1.0}; label="START / SAME TOP SPEED"
	elif t>=1.1 and t<1.35: label="RELEASE / SHORT SKID"
	elif t>=1.35 and t<1.9: f={"left":1.0}; label="REVERSE LEFT"
	elif t>=1.9 and t<2.0: f={"right":1.0}; label="QUICK RIGHT TAP"
	elif t>=2.0 and t<2.1: f={"left":1.0}; label="QUICK LEFT TAP"
	elif t>=2.1 and t<2.75: f={"right":1.0}; label="BUILD RIGHT"
	elif t>=2.75 and t<3.5: f={"left":1.0}; label="FULL-SPEED REVERSAL"
	elif t>=3.5 and t<3.85: label="RELEASE / SETTLE"
	elif t>=3.85 and t<4.15: f={"right":1.0}; label="RUN INTO JUMP"
	elif t>=4.15 and t<4.65: f={"right":1.0,"jump":t<4.37}; label="JUMP / AIR TUNING UNCHANGED"
	elif t>=4.65 and t<5.1: f={"left":1.0}; label="AIR REVERSE / LAND"
	elif t>=5.1 and t<5.65: label="LAND / SETTLE"
	elif t>=5.65 and t<6.15: f={"right":1.0,"roll":t<5.73}; label="ROLL / EXISTING ACTION"
	elif t>=6.15 and t<6.4: label="ROLL RECOVERY"
	elif t>=6.4 and t<6.65: f={"attack":t<6.48}; label="ATTACK / EXISTING ACTION"
	elif t>=6.65 and t<7.0: label="ATTACK RECOVERY"
	elif t>=7.0 and t<7.6: f={"left":1.0}; label="RESTART LEFT"
	elif t>=7.6: label="RELEASE / SETTLE"
	instruction=label
	_last_guided_phase=label
	return f

func _movement(kind: StringName, _payload: Dictionary) -> void:
	if kind in [&"brake", &"turn"]:
		markers.append({"point":player.global_position,"kind":String(kind),"age":0.0})

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1,KEY_2:
			if not paused:
				guided=false; _pending_profile=event.physical_keycode-KEY_1; instruction="FREE CONTROL"
		KEY_F:
			if not paused:
				guided=false; _pending_case=(case_index+1)%3; instruction="FREE CONTROL"
		KEY_R:
			if not paused: guided=false; _pending_reset=true; instruction="FREE CONTROL"
		KEY_Q:
			if not paused:
				guided=true; guided_time=0; guided_pass=0; _pending_case=0; _pending_profile=0
		KEY_ESCAPE:
			paused=not paused; get_tree().paused=paused
		KEY_O:
			recording=18.0; capture_clock=0; capture_started=Time.get_ticks_usec(); frames.clear(); trace.clear()
		KEY_P: get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Ground-Response.png")
	queue_redraw()

func _process(dt: float) -> void:
	queue_redraw()
	if recording<=0: return
	recording-=dt; capture_clock+=dt
	if capture_clock>=1.0/60.0:
		capture_clock-=1.0/60.0
		# Read the completed draw, so the recorded HUD and telemetry describe
		# the same frame rather than pairing a previous image with new state.
		await RenderingServer.frame_post_draw
		var filename := "frame_%04d.png"%frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/ground_response_capture/"+filename)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		trace.append({"seconds":elapsed,"profile":profile_index,"course":case_index,"guided":guided,"instruction":instruction,"paused":paused,"position":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"grounded":player.grounded,"facing":player.facing,"visual_facing":view.get_pose().get("facing",0),"pose":view.pose_name,"key":view.pose_key,"phase":view.get_pose().get("phase",0),"main_action":String(player.main_action),"weapon_phase":String(player.weapon_phase),"health":$Player/Health.current_health,"noise_count":event_bus.event_count})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/player.gd","combat_pc/visuals/wireframe.gd","combat_pc/ground_response_review.gd","combat_pc/resources/movement_profile.gd","combat_pc/resources/ground_response_profile.gd","combat_pc/resources/ground_presentation_profile.gd"]:
			var script: Script=load("res://"+path)
			hashes[path]=script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M18-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Actual native Godot viewport. Q supplies the same ordinary input sequence to each profile; movement and collision remain physical.","frames":frames,"trace":trace},"  "))

func _draw() -> void:
	draw_rect(Rect2(0,0,640,360),Color("070b10"))
	var ink := Color("a4f0d5") if profile_index==1 else Color("e6b584")
	for x in range(40,615,22): draw_line(Vector2(x,273),Vector2(x,277),Color("33434f"),0.7)
	draw_line(Vector2(28,270),Vector2(612,270),Color("728694"),0.8)
	draw_line(Vector2(28,140),Vector2(28,270),Color("728694"),0.8)
	draw_line(Vector2(612,140),Vector2(612,270),Color("728694"),0.8)
	if case_index==1: draw_polyline(PackedVector2Array([Vector2(180,270),Vector2(340,220),Vector2(460,220),Vector2(550,270)]),Color("728694"),0.8)
	elif case_index==2: draw_rect(Rect2(platform.position,platform.size),Color("728694"),false,0.8)
	for i in trail.size(): draw_circle(trail[i]+Vector2(0,3),0.8,Color(ink,0.08+float(i)/maxf(trail.size(),1)*0.3))
	for marker in markers:
		draw_line(marker.point+Vector2(0,3),marker.point+Vector2(0,11),Color(ink,1-marker.age),1.0)
	if is_instance_valid(player):
		draw_line(player.position+Vector2(player.facing*12,-24),player.position+Vector2(player.facing*18,-24),ink,1.2)

func render_hud(canvas: Node2D) -> void:
	if not is_instance_valid(player): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8095a7")
	var accent := Color("a4f0d5") if profile_index==1 else Color("e6b584")
	canvas.draw_rect(Rect2(0,0,640,111),Color("070b10"))
	canvas.draw_rect(Rect2(0,294,640,66),Color("070b10"))
	canvas.draw_string(font,Vector2(28,27),"MOKSHA / GROUND RESPONSE",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	canvas.draw_string(font,Vector2(28,49),("2  AGILE" if profile_index==1 else "1  PREVIOUS")+"    "+CASE_NAMES[case_index],HORIZONTAL_ALIGNMENT_LEFT,-1,10,accent)
	canvas.draw_string(font,Vector2(28,68),("SAME INPUT COMPARISON  /  " if guided else "")+instruction,HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	canvas.draw_string(font,Vector2(28,91),"SPEED %+.0f   FACE %s   %s   NOISE %d"%[player.velocity.x,"RIGHT" if player.facing>0 else "LEFT",view.pose_name.to_upper(),event_bus.event_count],HORIZONTAL_ALIGNMENT_LEFT,-1,10,muted)
	canvas.draw_string(font,Vector2(28,310),"A/D move   SPACE jump   SHIFT roll   J attack   K shield",HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)
	canvas.draw_string(font,Vector2(28,329),"1 previous / 2 agile   Q compare   F course   R reset   ESC pause",HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,348),"Same 218 px/s cap and air settings. Original MOKSHA response tuning.",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	if paused: canvas.draw_string(font,Vector2(260,173),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
