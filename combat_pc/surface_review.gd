extends Node2D
## One review piece: real committed PC noises reveal existing collision contours.
@onready var player = $Player
@onready var relay = $Player/NoiseRelay
@onready var event_bus = $SoundEvents
@onready var surface = $SurfacePulse
var paused := false
var guides := false
var recording := 0.0
var capture_clock := 0.0
var capture_started := 0
var frames: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []

func _ready() -> void:
	relay.forwarded.connect(_on_sound)
	DirAccess.make_dir_recursive_absolute("res://delivery/surface_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")
	queue_redraw()

func _physics_process(dt: float) -> void:
	if not paused: player.physics_tick(dt)

func _on_sound(event: Dictionary) -> void:
	if recording>0:
		var saved := event.duplicate(true)
		saved.origin = [event.origin.x,event.origin.y]
		saved["raw_seconds"] = (Time.get_ticks_usec()-capture_started)/1000000.0
		saved["bus_count"] = event_bus.event_count
		saved["surface_count"] = surface.accepted_event_count
		events.append(saved)

func reset_review() -> void:
	# Retire old subscriptions before resetting any event-producing component.
	surface.unbind_surface()
	player.reset_actor(Vector2(250,270),1)
	event_bus.clear_history()
	relay.reset_diagnostics()
	surface.bind_surface(self,player,event_bus)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_E: surface.enabled = not surface.enabled
		KEY_G: guides = not guides
		KEY_R: reset_review()
		KEY_ESCAPE:
			paused = not paused
			surface.simulation_enabled = not paused
		KEY_O:
			recording = 12
			capture_clock = 0
			capture_started = Time.get_ticks_usec()
			frames.clear(); trace.clear(); events.clear()
		KEY_P: get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Surface-Pulse.png")
	queue_redraw()

func _process(dt: float) -> void:
	queue_redraw()
	if recording<=0: return
	recording -= dt
	capture_clock += dt
	if capture_clock>=1.0/60.0:
		capture_clock -= 1.0/60.0
		var filename := "frame_%04d.png"%frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/surface_capture/"+filename)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		var snapshot: Dictionary = surface.debug_snapshot()
		trace.append({"seconds":elapsed,"surface_enabled":surface.enabled,"bus_count":event_bus.event_count,"surface_count":surface.accepted_event_count,"pulse_count":snapshot.pulse_count,"active_segments":snapshot.active_geometry_segments,"draw_segments":snapshot.draw_segments,"blackout":snapshot.draw_blackout,"position":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"pose":player.pose,"paused":paused,"guides":guides,"inputs":{"left":Input.is_action_pressed("cp_left"),"right":Input.is_action_pressed("cp_right"),"jump":Input.is_action_pressed("cp_jump"),"attack":Input.is_action_pressed("cp_attack")}})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/player.gd","combat_pc/components/noise_relay.gd","combat_pc/components/surface_pulse.gd","combat_pc/surface_review.gd","scripts/sensory/noise_bus.gd","scripts/sensory/sonar_view.gd","scripts/sensory/sonar_geometry.gd"]:
			var script: Script = load("res://"+path)
			hashes[path] = script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M15-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Actual native viewport and input; one PC, local bus and detachable surface adapter; original contour solver","frames":frames,"trace":trace,"events":events},"  "))

func _draw() -> void:
	if not is_instance_valid(surface): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8099a9")
	var accent := Color("8fe0ca") if surface.enabled else Color("e9b27e")
	draw_rect(Rect2(0,0,640,360),Color("030608"))
	draw_string(font,Vector2(28,30),"MOKSHA / ONE PIECE: SURFACE PULSE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	draw_string(font,Vector2(28,49),"REAL NOISE  >  NEAREST CONTACT  >  TRAVELLING EDGE  >  FADE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_string(font,Vector2(28,79),"SURFACES "+("CONNECTED" if surface.enabled else "DISCONNECTED"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
	draw_string(font,Vector2(395,79),"NOISE %d   /   PULSES %d"%[event_bus.event_count,surface.accepted_event_count],HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	var last: Dictionary = relay.last_event
	var description := "SWING ONCE. WATCH THE FLOOR, THEN THE RAISED BLOCK."
	if not last.is_empty():
		description = "LAST %s  /  ORIGIN %.0f, %.0f  /  ACTIVE WAVES %d"%[String(last.kind).to_upper(),last.origin.x,last.origin.y,surface.pulses.size()]
	draw_string(font,Vector2(28,103),description,HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	if guides:
		for body_name in ["Floor","LeftWall","RightWall","Block"]:
			var shape_node: CollisionShape2D = get_node(NodePath(body_name+"/Shape"))
			var shape := shape_node.shape as RectangleShape2D
			draw_rect(Rect2(shape_node.global_position-shape.size*0.5,shape.size),Color("263c45"),false,0.7)
		draw_string(font,Vector2(28,125),"GUIDES ON: STATIC COLLISION EDGES FOR COMPARISON",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_string(font,Vector2(28,309),"A/D MOVE   SPACE JUMP   J SWING   SHIFT ROLL",HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	draw_string(font,Vector2(28,329),"E CONNECT / DISCONNECT   G GUIDES   R RESET   ESC PAUSE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	draw_string(font,Vector2(28,348),"ONLY SOUNDED EDGES APPEAR. SILENCE LEAVES THE GEOMETRY HIDDEN.",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	if paused: draw_string(font,Vector2(285,146),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
