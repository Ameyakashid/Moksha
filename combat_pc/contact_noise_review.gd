extends Node2D
## One source component: impulses create real collisions; only the optional
## contact observer decides whether those committed contacts make a noise.
const Prop = preload("res://combat_pc/fixtures/contact_noise_prop.tscn")
const CASE_NAMES = ["FLOOR DROP / REPEATED BOUNCES", "WALL THROW / FLOOR LANDING", "PROP INTO PROP / ONE SHARED CONTACT"]
@onready var player = $Player
@onready var relay = $Player/NoiseRelay
@onready var event_bus = $SoundEvents
@onready var surface = $SurfacePulse
var paused := false
var guides := true
var sources_enabled := true
var case_index := 0
var case_run := 0
var impact_count := 0
var last_impact: Dictionary = {}
var marks: Array[Dictionary] = []
var recording := 0.0
var capture_clock := 0.0
var capture_started := 0
var frames: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []
var _pending_case := -1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://delivery/contact_capture")
	FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE).store_string("Generated review captures.\n")
	queue_redraw()

func _physics_process(dt: float) -> void:
	if paused: return
	if _pending_case >= 0:
		var requested := _pending_case
		_pending_case = -1
		_apply_case(requested)
	player.physics_tick(dt)

func _retire_props() -> void:
	for body in $Props.get_children():
		var emitter := body.get_node_or_null("ImpactNoise")
		if emitter != null: emitter.unbind()
		body.collision_layer = 0
		body.collision_mask = 0
		$Props.remove_child(body)
		body.queue_free()

func reset_review() -> void:
	surface.unbind_surface()
	_retire_props()
	player.reset_actor(Vector2(92,270),1)
	event_bus.clear_history()
	relay.reset_diagnostics()
	impact_count = 0
	last_impact.clear()
	marks.clear()
	surface.bind_surface(self,player,event_bus)
	queue_redraw()

func _spawn_prop(at: Vector2, velocity: Vector2, spin: float, color: Color) -> RigidBody2D:
	var body := Prop.instantiate() as RigidBody2D
	body.name = "Prop%d"%($Props.get_child_count()+1)
	body.position = at
	body.wire_color = color
	body.tuning = body.tuning.duplicate(true)
	body.tuning.bounce = 0.6
	body.tuning.body_linear_damp = 0.05
	body.tuning.body_angular_damp = 0.8
	body.tuning.friction = 0.6
	body.tuning.hard_impacts_to_break = 100000
	var emitter := body.get_node("ImpactNoise")
	emitter.event_bus_path = NodePath("../../../SoundEvents")
	emitter.enabled = sources_enabled
	$Props.add_child(body)
	emitter.reset_contact_history(true)
	emitter.impact_emitted.connect(_on_impact)
	# A single real impulse; the existing rigid-body solver handles the flight,
	# rotation, momentum exchange, bounces and final rest from here.
	body.apply_central_impulse((velocity-body.linear_velocity)*body.mass)
	body.angular_velocity = spin
	body.sleeping = false
	return body

func start_case(index: int) -> void:
	if paused: return
	# Spawn/reset/launch at the known host physics boundary, before the
	# observer's priority120 callback and the next rigid-body solver step.
	_pending_case = clampi(index,0,2)

func _apply_case(index: int) -> void:
	case_index = clampi(index,0,2)
	case_run += 1
	reset_review()
	match case_index:
		0: _spawn_prop(Vector2(280,126),Vector2(65,-35),0.0,Color("e6c69a"))
		1: _spawn_prop(Vector2(450,181),Vector2(430,-35),1.0,Color("e6c69a"))
		2:
			_spawn_prop(Vector2(435,256),Vector2.ZERO,0.0,Color("9ebfd9"))
			_spawn_prop(Vector2(265,210),Vector2(330,-70),2.0,Color("e6c69a"))
	surface.refresh_geometry()

func _on_impact(event: Dictionary) -> void:
	impact_count += 1
	last_impact = event.duplicate(true)
	marks.append({"origin":event.origin,"age":0.0})
	while marks.size()>16: marks.pop_front()
	if recording>0:
		var saved: Dictionary = _json_value(event)
		saved["raw_seconds"] = (Time.get_ticks_usec()-capture_started)/1000000.0
		saved["case_index"] = case_index
		saved["case_run"] = case_run
		saved["impact_count"] = impact_count
		saved["bus_count"] = event_bus.event_count
		saved["surface_count"] = surface.accepted_event_count
		events.append(saved)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_1: start_case(0)
		KEY_2: start_case(1)
		KEY_3: start_case(2)
		KEY_Q: start_case(case_index)
		KEY_E:
			sources_enabled = not sources_enabled
			for body in $Props.get_children(): body.get_node("ImpactNoise").enabled = sources_enabled
		KEY_G: guides = not guides
		KEY_R: reset_review()
		KEY_ESCAPE:
			paused = not paused
			surface.simulation_enabled = not paused
			get_tree().paused = paused
		KEY_O:
			recording = 18
			capture_clock = 0
			capture_started = Time.get_ticks_usec()
			frames.clear(); trace.clear(); events.clear()
		KEY_P: get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Physics-Contact.png")
	queue_redraw()

func _json_value(value):
	if value is Vector2: return [value.x,value.y]
	if value is Dictionary:
		var result := {}
		for key in value: result[String(key)] = _json_value(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_json_value(item))
		return result
	return value

func _process(dt: float) -> void:
	if not paused:
		for mark in marks: mark.age += dt
		marks = marks.filter(func(mark):return mark.age<0.4)
	queue_redraw()
	if recording<=0: return
	recording -= dt
	capture_clock += dt
	if capture_clock>=1.0/60.0:
		capture_clock -= 1.0/60.0
		var filename := "frame_%04d.png"%frames.size()
		get_viewport().get_texture().get_image().save_png("res://delivery/contact_capture/"+filename)
		var elapsed := (Time.get_ticks_usec()-capture_started)/1000000.0
		frames.append({"file":filename,"raw_seconds":elapsed})
		var bodies := []
		for body in $Props.get_children():
			bodies.append({"id":body.get_instance_id(),"name":body.name,"position":_json_value(body.global_position),"velocity":_json_value(body.linear_velocity),"rotation":body.rotation,"sleeping":body.sleeping})
		trace.append({"seconds":elapsed,"case_index":case_index,"case_run":case_run,"sources_enabled":sources_enabled,"bus_count":event_bus.event_count,"surface_count":surface.accepted_event_count,"impact_count":impact_count,"pulse_count":surface.pulses.size(),"paused":paused,"guides":guides,"bodies":bodies})
	if recording<=0:
		var hashes := {}
		for path in ["combat_pc/components/physics_contact_noise.gd","combat_pc/resources/contact_noise_profile.gd","combat_pc/contact_noise_review.gd","combat_pc/fixtures/contact_noise_prop.gd","combat_pc/fixtures/contact_review_hud.gd","prop.gd","combat_pc/player.gd","scripts/sensory/noise_bus.gd","combat_pc/components/surface_pulse.gd"]:
			var script: Script = load("res://"+path)
			hashes[path] = script.get_source_code().sha256_text()
		FileAccess.open("res://delivery/M16-NATIVE-CAPTURE.json",FileAccess.WRITE).store_string(JSON.stringify({"hashes":hashes,"method":"Actual native physics and input; each numbered fixture applies one initial impulse; only real contact observers emit prop impact events","frames":frames,"trace":trace,"events":events},"  "))

func _draw() -> void:
	draw_rect(Rect2(0,0,640,360),Color("030608"))
	if guides:
		draw_line(Vector2(28,270),Vector2(612,270),Color("24353d"),0.7)
		draw_line(Vector2(28,140),Vector2(28,270),Color("24353d"),0.7)
		draw_line(Vector2(612,140),Vector2(612,270),Color("24353d"),0.7)
	for mark in marks:
		var c := Color(1.0,0.75,0.45,1.0-mark.age/0.4)
		draw_line(mark.origin-Vector2(3,0),mark.origin+Vector2(3,0),c,1)
		draw_line(mark.origin-Vector2(0,3),mark.origin+Vector2(0,3),c,1)

func render_hud(canvas: Node2D) -> void:
	if not is_instance_valid(surface): return
	var font := ThemeDB.fallback_font
	var ink := Color("dce9ee")
	var muted := Color("8099a9")
	var accent := Color("8fe0ca") if sources_enabled else Color("e9b27e")
	canvas.draw_rect(Rect2(0,0,640,110),Color("030608"))
	canvas.draw_rect(Rect2(0,294,640,66),Color("030608"))
	canvas.draw_string(font,Vector2(28,29),"MOKSHA / ONE PIECE: PHYSICS CONTACT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	canvas.draw_string(font,Vector2(28,49),CASE_NAMES[case_index],HORIZONTAL_ALIGNMENT_LEFT,-1,9,muted)
	canvas.draw_string(font,Vector2(28,76),"SOURCES "+("CONNECTED" if sources_enabled else "DISCONNECTED"),HORIZONTAL_ALIGNMENT_LEFT,-1,11,accent)
	canvas.draw_string(font,Vector2(399,76),"IMPACTS %d  /  NOISE %d"%[impact_count,event_bus.event_count],HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	var description := "PRESS 1, 2 OR 3 TO APPLY ONE IMPULSE TO REAL PROPS"
	if not last_impact.is_empty():
		description = "%s / %s   %.0f PX/S   LOUD %.2f   AT %.0f, %.0f"%[last_impact.source_name,last_impact.collider_name,last_impact.closing_speed,last_impact.loudness,last_impact.origin.x,last_impact.origin.y]
	canvas.draw_string(font,Vector2(28,101),description,HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	if guides:
		canvas.draw_string(font,Vector2(28,121),"DIM COLLISION GUIDES ON  /  WHITE EDGES ARE SOUND",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	canvas.draw_string(font,Vector2(28,308),"1 DROP   2 WALL   3 PROP INTO PROP   Q REPEAT",HORIZONTAL_ALIGNMENT_LEFT,-1,9,ink)
	canvas.draw_string(font,Vector2(28,328),"E SOURCES   G GUIDES   R CLEAR   ESC PAUSE   A/D MOVE   J HIT",HORIZONTAL_ALIGNMENT_LEFT,-1,8,muted)
	canvas.draw_string(font,Vector2(28,348),"IMPACTS ONLY. RESTING CONTACT DOES NOT KEEP MAKING PULSES.",HORIZONTAL_ALIGNMENT_LEFT,-1,7,muted)
	if paused: canvas.draw_string(font,Vector2(283,149),"PAUSED",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
