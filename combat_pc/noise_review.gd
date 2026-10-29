extends Node2D
## One sound-event adapter review. Rings mark event origins only; the scene
## neither reveals surfaces nor polls the PC to invent audible activity.
@onready var player = $Player
@onready var relay = $Player/NoiseRelay
@onready var event_bus = $SoundEvents
var paused := false
var markers: Array[Dictionary] = []
var recording := 0.0
var capture_clock := 0.0
var capture_started := 0
var frames: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []

func _ready() -> void:
	relay.forwarded.connect(_on_sound)
	DirAccess.make_dir_recursive_absolute("res://delivery/noise_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")
	queue_redraw()

func _physics_process(dt: float) -> void:
	if not paused: player.physics_tick(dt)

func _on_sound(event: Dictionary) -> void:
	markers.append({"origin":event.origin,"kind":event.kind,"loudness":event.loudness,"serial":event.serial,"age":0.0})
	while markers.size()>32: markers.pop_front()
	if recording>0:
		var saved := event.duplicate(true)
		saved.origin = [event.origin.x,event.origin.y]
		saved["raw_seconds"] = (Time.get_ticks_usec()-capture_started)/1000000.0
		saved["bus_count"] = event_bus.event_count
		events.append(saved)

func reset_review() -> void:
	player.reset_actor(Vector2(160,270),1)
	event_bus.clear_history()
	relay.reset_diagnostics()
	markers.clear()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_E: relay.enabled = not relay.enabled
		KEY_R: reset_review()
		KEY_ESCAPE: paused = not paused
		KEY_O:
			recording = 12
			capture_clock = 0
			capture_started = Time.get_ticks_usec()
			frames.clear();trace.clear();events.clear()
		KEY_P: get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Sound-Origins.png")
	queue_redraw()

func _process(dt: float) -> void:
	if not paused:
		for mark in markers: mark.age += dt
		markers = markers.filter(func(mark):return mark.age<0.7)
	queue_redraw()
	if recording<=0: return
	recording -= dt
	capture_clock += dt
	if capture_clock>=1.0/60.0:
		capture_clock -= 1.0/60.0
		var filename := "frame_%04d.png"%frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/noise_capture/"+filename)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		trace.append({"seconds":elapsed,"relay_enabled":relay.enabled,"bus_count":event_bus.event_count,"forwarded_count":relay.forwarded_count,"marker_count":markers.size(),"position":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"pose":player.pose,"weapon":player.weapon_phase,"paused":paused,"inputs":{"left":Input.is_action_pressed("cp_left"),"right":Input.is_action_pressed("cp_right"),"jump":Input.is_action_pressed("cp_jump"),"attack":Input.is_action_pressed("cp_attack")}})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/player.gd","combat_pc/components/noise_relay.gd","combat_pc/noise_review.gd","scripts/sensory/noise_bus.gd"]:
			var script: Script = load("res://"+path)
			hashes[path]=script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M14-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Actual native viewport and PC input; one local existing NoiseBus; markers observe only relay completion","frames":frames,"trace":trace,"events":events},"  "))

func _draw() -> void:
	if not is_instance_valid(relay): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8099a9")
	var accent := Color("8fe0ca") if relay.enabled else Color("e9b27e")
	draw_rect(Rect2(0,0,640,360),Color("091018"))
	draw_string(font,Vector2(28,30),"MOKSHA / ONE PIECE: SOUND ORIGINS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	draw_string(font,Vector2(28,49),"FOOTSTEPS, LANDINGS AND WEAPON SWINGS",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_string(font,Vector2(28,80),"RELAY "+("CONNECTED" if relay.enabled else "DISCONNECTED"),HORIZONTAL_ALIGNMENT_LEFT,-1,13,accent)
	draw_string(font,Vector2(390,80),"EVENTS RECEIVED  %d"%event_bus.event_count,HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	var last: Dictionary = relay.last_event
	if last.is_empty():
		draw_string(font,Vector2(28,107),"MOVE, LAND OR SWING TO PRODUCE A SOUND EVENT",HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	else:
		draw_string(font,Vector2(28,107),"LAST: %s   /   LOUDNESS %.2f   /   ORIGIN %.0f, %.0f"%[String(last.kind).to_upper(),last.loudness,last.origin.x,last.origin.y],HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	draw_line(Vector2(28,270),Vector2(612,270),Color("7897a5"),1)
	draw_rect(Rect2(16,140,12,130),Color("314552"),false,1)
	draw_rect(Rect2(612,140,12,130),Color("314552"),false,1)
	for mark in markers:
		var alpha: float = 1.0-mark.age/0.7
		var point: Vector2 = mark.origin
		var radius: float = lerpf(3.0,14.0+clampf(mark.loudness,0,2)*5.0,mark.age/0.7)
		draw_circle(point,radius,Color(0.94,0.98,1,alpha),false,0.75)
		draw_line(point-Vector2(2,0),point+Vector2(2,0),Color(0.94,0.98,1,alpha),1)
		draw_line(point-Vector2(0,2),point+Vector2(0,2),Color(0.94,0.98,1,alpha),1)
	draw_string(font,Vector2(28,309),"A/D MOVE   SPACE JUMP   J SWING   SHIFT ROLL",HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	draw_string(font,Vector2(28,329),"E CONNECT / DISCONNECT   R RESET   ESC PAUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_string(font,Vector2(28,348),"MARKERS STAY AT THE PLACE EACH EVENT OCCURRED",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	if paused: draw_string(font,Vector2(282,160),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
