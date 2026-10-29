extends "res://combat_pc/tests/soft_slope_regression.gd"
## M19: authored ordinary-air steering only. Real production motor callbacks.
const BASELINE = preload("res://combat_pc/resources/ground_response_agile.tres")
const CANDIDATE = preload("res://combat_pc/resources/air_response_agile.tres")
var variant := "baseline"
var selected_profile: Resource
var response_rows: Array[Dictionary] = []
var jump_rows: Array[Dictionary] = []
var vertical_signatures := {}
var neutral_signatures := {}
var hashes := {}
var total_ticks := 0

func _run() -> void:
	for path in ["res://combat_pc/player.gd", "res://combat_pc/player.tscn", "res://combat_pc/resources/movement_profile.gd", "res://combat_pc/resources/ground_response_agile.tres", "res://combat_pc/resources/ground_response_profile.gd", "res://combat_pc/resources/air_response_agile.tres", "res://combat_pc/resources/air_response_profile.gd", "res://combat_pc/visuals/wireframe.gd", "res://combat_pc/visuals/wireframe_keys.gd", "res://combat_pc/visuals/wireframe_pose.gd", "res://combat_pc/tests/soft_slope_regression.gd", "res://combat_pc/tests/air_response_regression.gd"]:
		hashes[path] = FileAccess.get_sha256(path)
	_resource_contract()
	for mode in ["baseline", "candidate"]:
		variant = mode
		selected_profile = (BASELINE if mode == "baseline" else CANDIDATE).duplicate(true)
		for direction in [-1, 1]:
			await _response_case(direction)
			await _neutral_case(direction)
			await _analog_taps_case(direction)
			await _native_air_case(direction)
			for jump_kind in ["held", "release", "air_jump"]:
				await _jump_case(direction, jump_kind)
			await _correction_case(direction)
			await _coyote_case(direction, true)
			await _coyote_case(direction, false)
			await _one_way_case(direction)
			await _support_departure_case(direction)
		await _buffer_case()
		for gradient in [-1.0, -.5, .5, 1.0]:
			await _plane_case("air reversal to slope %.1f" % gradient, gradient, 218, 400, -1, 80, .8)
		await _component_blocking()
		await _grounded_callback_replacement()
		await _reset_pause_case()
		await _resource_fallback_case()
	var stable := true
	for path in hashes: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	name_ = "final provenance"
	_check(stable, "runtime resource and unchanged original fixture hashes remain stable during run")
	var result := {"milestone":19,"suite":"ordinary air steering","physics_hz":hz,"engine":Engine.get_version_info().string,"generated_utc":Time.get_datetime_string_from_system(true),"checks":checks,"failures":failures,"scenario_count":scenarios.size(),"scenarios":scenarios,"response_rows":response_rows,"jump_rows":jump_rows,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"candidate_resource":"res://combat_pc/resources/air_response_agile.tres","baseline_resource":"res://combat_pc/resources/ground_response_agile.tres","method":"Each observed step is one stock physics_tick in a consecutive real Godot physics callback. Numerical assertions summarize behavior, never inflate counts with individual frames or bones.","limits":["Authored MOKSHA air tuning, not source-game numerical or executable parity.","Matched airborne Y comparison allows 0.00005 px floating-point sweep tolerance; vertical velocity, facing, budgets and local pose are exact. Changed horizontal steering may change geometry contact times.","Landing precision compares a fixed timed correction against a marked target on a wide real floor; it is not a general guarantee of player accuracy.","Headless body and pose telemetry only; no native visual review claim."]}
	FileAccess.open("res://combat_pc/tests/air_response_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(_safe(result),"  ")+"\n")
	print("AIR_RESPONSE_M19 %dHz: %d scenarios, %d behavioral assertions, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for row in response_rows: print(JSON.stringify(row))
	for row in jump_rows: print(JSON.stringify(row))
	quit(0 if failures.is_empty() else 1)

func _resource_contract() -> void:
	name_ = "resource contract"
	var equal := true
	var differences: Array[String] = []
	for property in BASELINE.get_property_list():
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or property.name == "ordinary_air_response": continue
		var old = BASELINE.get(property.name)
		var now = CANDIDATE.get(property.name)
		var same: bool = _resource_values(old) == _resource_values(now) if old is Resource else old == now
		if not same: differences.append(property.name)
		equal = equal and same
	_check(equal, "candidate preserves every v22 MovementProfile scalar and ground-response resource; differences " + str(differences))
	_check(BASELINE.ordinary_air_response == null and CANDIDATE.ordinary_air_response != null and CANDIDATE.ordinary_air_response.is_valid(), "air steering is opt-in and absent from approved v22 profile")
	_check(CANDIDATE.ordinary_air_response.air_acceleration == 2300.0 and BASELINE.air_acceleration == 1450.0, "ordinary steering candidate 2300 retains authored fallback 1450 px/s²")
	_check(CANDIDATE.run_speed == 218.0 and CANDIDATE.air_idle_drag == 120.0 and CANDIDATE.jump_speed == 365.0 and CANDIDATE.air_jump_speed == 350.0, "run cap neutral drag ground launch and air launch remain 218 120 365 350")

func _begin(label: String, at: Vector2, use_probe := false) -> void:
	await super._begin(variant + ": " + label,at,use_probe)
	actor.profile = selected_profile.duplicate(true)

func _sample() -> Dictionary:
	var result := super._sample()
	var view = actor.get_node("Visual")
	var pose_data: Dictionary = view.get_pose()
	var state: Dictionary = actor.telemetry()
	result.visual_head = pose_data.get("bones",{}).get("head",Vector2.ZERO)
	result.visual_bones = pose_data.get("bones",{})
	result.visual_mode = pose_data.get("mode","")
	result.visual_facing = pose_data.get("facing",0)
	result.visual_phase = pose_data.get("phase",0.0)
	result.visual_root_untouched = view.position == Vector2.ZERO and view.rotation == 0 and view.scale == Vector2.ONE
	result.telemetry_coherent = state.position == actor.global_position and state.velocity == actor.velocity and state.facing == actor.facing
	return result

func _air(label: String, velocity := Vector2.ZERO) -> void:
	await _begin(label,Vector2(0,-1000))
	await _start(velocity)

func _flat(label: String) -> void:
	await _begin(label,Vector2(0,298))
	_terrain([Vector2(-2000,0),Vector2(2000,0)],Vector2(0,300))
	await _start()
	_check(await _until(func(): return actor.grounded),"establishes actual floor contact")

func _response_case(direction: int) -> void:
	await _air("air start reverse and release direction%d" % direction)
	var row := {"variant":variant,"direction":direction,"physics_hz":hz,"speed_cap":218}
	var start_tick := ticks
	var start_position: Vector2 = actor.position
	await _until(func():return absf(actor.velocity.x-direction*218)<.001,_direction(direction),.5)
	row.start_to_cap_seconds=(ticks-start_tick)*dt
	row.start_to_cap_distance=absf(actor.position.x-start_position.x)
	_check(absf(actor.velocity.x-direction*218)<.001 and not actor.grounded,"ordinary air acceleration reaches unchanged cap")
	start_tick=ticks;start_position=actor.position
	await _step(_direction(-direction))
	_check(actor.facing == -direction and actor.velocity.x*direction>0,"air reversal turns facing on first callback while old physical momentum persists")
	await _until(func():return actor.velocity.x*direction<=0,_direction(-direction),.5)
	row.reverse_zero_seconds=(ticks-start_tick)*dt
	row.reverse_zero_distance=(actor.position.x-start_position.x)*direction
	var farthest := 0.0
	for frame in frames:
		if frame.tick>start_tick:farthest=maxf(farthest,(float(frame.after.position[0])-start_position.x)*direction)
	row.reversal_overshoot=farthest
	await _until(func():return absf(actor.velocity.x+direction*218)<.001,_direction(-direction),.5)
	row.reverse_full_seconds=(ticks-start_tick)*dt
	_check(absf(actor.velocity.x+direction*218)<.001,"air reversal reaches opposite cap without overshoot")
	start_tick=ticks;start_position=actor.position
	await _until(func():return absf(actor.velocity.x)<.001,{},2.0)
	row.neutral_stop_seconds=(ticks-start_tick)*dt
	row.neutral_stop_distance=absf(actor.position.x-start_position.x)
	_check(actor.velocity.x == 0,"unchanged low neutral drag eventually reaches exact finite stop")
	var maximum := 0.0
	for frame in frames: maximum=maxf(maximum,absf(float(frame.after.velocity[0])))
	row.maximum_speed=maximum
	_check(maximum<=218.001,"every start reversal release sample stays within original speed cap")
	response_rows.append(row);measurements.merge(row)
	await _finish()

func _neutral_case(direction: int) -> void:
	await _air("matched initial neutral drift direction%d" % direction,Vector2(120*direction,-50))
	await _seconds({},1.1)
	var signature := []
	for frame in frames:signature.append({"position":frame.after.position,"velocity":frame.after.velocity,"facing":frame.after.facing,"main_action":frame.after.main_action})
	if variant == "baseline": neutral_signatures[direction]=signature
	else:_check(signature == neutral_signatures[direction],"release from identical initial state preserves complete position velocity facing and action trace")
	_check(actor.velocity.x==0,"neutral initial momentum stops after unchanged authored drag interval")
	measurements.final_position=actor.position
	await _finish()

func _analog_taps_case(direction: int) -> void:
	await _air("analog taps cancellation direction%d" % direction)
	var proportional := true
	for strength in [.25,.75,.4,1.0]:
		await _seconds({"right" if direction>0 else "left":strength},.3)
		proportional=proportional and absf(actor.velocity.x-direction*218*strength)<.001
	_check(proportional,"analog input reaches proportional unchanged air speed targets")
	var tap_rows := []
	var repeatable := true
	for index in 6:
		actor.reset_actor(Vector2(0,-1000),direction)
		await _seconds(_direction(direction),1.0/30.0)
		var released_speed: float = absf(actor.velocity.x)
		var released_at: Vector2 = actor.position
		await _seconds({},.1)
		var remaining: float = absf(actor.velocity.x)
		var row := {"released_speed":released_speed,"remaining_speed":remaining,"coast_distance":absf(actor.position.x-released_at.x)}
		if index>0:repeatable=repeatable and row==tap_rows[0]
		tap_rows.append(row)
		_near(remaining,maxf(0,released_speed-120*.1),.001,"tap neutral coast obeys retained 120 px/s² drag")
	_check(repeatable,"six identical real input taps produce identical directional and neutral responses")
	actor.reset_actor(Vector2(0,-1000),direction);actor.velocity.x=120*direction
	await _seconds({"left":1.0,"right":1.0},.1)
	_near(absf(actor.velocity.x),108,.001,"equal opposing inputs select neutral drag rather than directional acceleration")
	var within_cap := true
	for index in 12:
		await _seconds(_direction(direction if index%2==0 else -direction),.05)
		within_cap=within_cap and absf(actor.velocity.x)<=218.001
	_check(within_cap and not actor.grounded,"rapid alternate taps retain airborne cap and finite steering")
	measurements.tap_rows=tap_rows
	await _finish()

func _native_air_case(direction: int) -> void:
	await _air("native parsed air correction direction%d" % direction)
	var forward := KEY_D if direction>0 else KEY_A
	var backward := KEY_A if direction>0 else KEY_D
	_key(forward,true);await _seconds(null,.25)
	_check(absf(actor.velocity.x-direction*218)<.001,"native physical key reaches airborne cap through production InputMap")
	_key(forward,false);_key(backward,true);await _step(null)
	_check(actor.facing == -direction and actor.velocity.x*direction>0,"native opposite key turns immediately during residual drift")
	await _seconds(null,.35);_key(backward,false)
	var before: float=absf(actor.velocity.x)
	await _seconds(null,.1)
	_near(absf(actor.velocity.x),before-12,.001,"native release retains ordinary neutral air drag")
	await _finish()

func _key(code: int, pressed: bool) -> void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event);Input.flush_buffered_events()

func _jump_case(direction: int, kind: String) -> void:
	await _flat("matched %s jump trace direction%d" % [kind,direction])
	var launch_y: float=actor.position.y
	var launch_tick := ticks
	await _step(_direction(direction,{"jump":true}))
	var minimum_y: float=actor.position.y
	var trace := []
	var held := true
	for index in roundi(2*hz):
		var elapsed: float=(ticks-launch_tick)*dt
		var intent := direction if elapsed<.25 else -direction
		if kind=="release":held=elapsed<.05
		elif kind=="air_jump":held=not (elapsed>=.15 and elapsed<.20)
		await _step(_direction(intent,{"jump":held}))
		minimum_y=minf(minimum_y,actor.position.y)
		var sample: Dictionary=frames.back().after
		if not actor.grounded:
			trace.append({"y":sample.position[1],"vy":sample.velocity[1],"facing":sample.facing,"main_action":sample.main_action,"air_jumps_left":sample.air_jumps_left,"head":sample.visual_head,"bones":sample.visual_bones,"visual_mode":sample.visual_mode,"visual_phase":sample.visual_phase})
		if actor.grounded:break
	_check(actor.grounded and _count("ground_jump")==1 and _count("air_jump")== (1 if kind=="air_jump" else 0),"real jump launches once and lands without held repeat or excess jump")
	_check(actor.air_jumps_left==1 and actor.air_roll_available and actor.dive_available,"real landing restores existing air jump roll and dive budgets")
	var key:=kind+str(direction)
	if variant=="baseline":vertical_signatures[key]=trace
	else:
		var reference: Array=vertical_signatures[key]
		var exact_other_state: bool=trace.size()==reference.size()
		var maximum_y_error:=0.0
		for index in mini(trace.size(),reference.size()):
			var observed:Dictionary=trace[index].duplicate(true)
			var expected:Dictionary=reference[index].duplicate(true)
			maximum_y_error=maxf(maximum_y_error,absf(float(observed.y)-float(expected.y)))
			observed.erase("y");expected.erase("y")
			exact_other_state=exact_other_state and observed==expected
		_check(exact_other_state and maximum_y_error<=.00005,"identical jump inputs preserve Y within 0.00005 px and exactly preserve vertical velocity budget facing and local head/bone samples")
		measurements.maximum_baseline_y_error=maximum_y_error
		measurements.non_y_airborne_trace_exact=exact_other_state
	var row: Dictionary={"variant":variant,"direction":direction,"kind":kind,"apex_height":launch_y-minimum_y,"air_seconds":(ticks-launch_tick)*dt,"landing_x":actor.position.x}
	jump_rows.append(row);measurements.merge(row);measurements.vertical_trace=trace
	await _finish()

func _correction_case(direction: int) -> void:
	await _flat("fixed timed jump landing correction direction%d" % direction)
	await _seconds(_direction(direction),.2)
	var launch: Vector2=actor.position
	var launch_tick:=ticks
	await _step(_direction(direction,{"jump":true}))
	while not actor.grounded and ticks-launch_tick<2*hz:
		await _step(_direction(direction if (ticks-launch_tick)*dt<.25 else -direction,{"jump":true}))
	_check(actor.grounded and _count("ground_jump")==1,"timed opposite air correction returns to actual floor once")
	var row: Dictionary={"variant":variant,"direction":direction,"kind":"landing_correction","target_x":launch.x,"landing_x":actor.position.x,"landing_error":absf(actor.position.x-launch.x),"correction_after_seconds":.25,"air_seconds":(ticks-launch_tick)*dt}
	jump_rows.append(row);measurements.merge(row)
	measurements.merge(_trace_bounds())
	await _finish()

func _coyote_case(direction: int, within: bool) -> void:
	await _begin("coyote %s direction%d" % [within,direction],Vector2(-20*direction,298))
	_box(Vector2(-100*direction,315),Vector2(200,30))
	await _start();await _until(func():return actor.grounded)
	actor.velocity.x=218*direction
	await _until(func():return not actor.grounded,_direction(direction),1)
	await _seconds(_direction(direction),.0125 if within else .075)
	await _step(_direction(direction,{"jump":true}))
	_check(_count("ground_jump")== (1 if within else 0) and _count("air_jump")== (0 if within else 1),"coyote boundary preserves ground-grace versus finite-air-jump selection")
	_check(actor.air_jumps_left==(1 if within else 0),"coyote decision preserves existing air-jump resource accounting")
	await _step();await _step({"jump":true});await _step();await _step({"jump":true})
	_check(_count("air_jump")==1 and actor.air_jumps_left==0,"repeated fresh air presses cannot exceed one air jump")
	await _finish()

func _buffer_case() -> void:
	await _begin("landing jump buffer and expired request",Vector2(0,286))
	_terrain([Vector2(-1000,0),Vector2(1000,0)],Vector2(0,300))
	await _start(Vector2(0,140));actor.air_jumps_left=0
	await _step({"jump":true,"right":1.0});await _seconds({"jump":true,"right":1.0},1)
	_check(_count("ground_jump")==1 and _count("air_jump")==0 and actor.grounded,"buffered unavailable air press launches once on real landing without held repeat")
	actor.reset_actor(Vector2(0,0),1);actor.air_jumps_left=0
	await _step({"jump":true});await _seconds({"jump":true},1.2)
	_check(actor.grounded and _count("ground_jump")==1 and _count("air_jump")==0,"expired airborne buffer cannot trigger an unrequested launch")
	await _finish()

func _one_way_case(direction: int) -> void:
	await _flat("one way crossing steering and touchdown direction%d" % direction)
	var upper:=_box(Vector2(0,258),Vector2(800,6),true)
	await _sync_geometry()
	await _step(_direction(direction,{"jump":true}))
	var crossed:=false
	for index in hz:
		await _step(_direction(direction if index<roundi(.2*hz) else -direction,{"jump":true}))
		crossed=crossed or actor.position.y<255
		if actor.grounded:break
	_check(crossed and actor.grounded and actor.telemetry().support_id==upper.get_instance_id(),"steered jump crosses upward one-way and lands on its real upper support")
	_check(actor.get_collision_exceptions().is_empty(),"ordinary air steering never creates drop-through exceptions")
	measurements.merge(_trace_bounds());await _finish()

func _support_departure_case(direction: int) -> void:
	await _begin("moving support departure and lower touchdown direction%d" % direction,Vector2(0,298))
	var upper:=_box(Vector2(0,310),Vector2(100,20),false,true)
	var lower:=_box(Vector2(0,450),Vector2(2000,40))
	await _start();await _until(func():return actor.grounded)
	before_tick=func(delta):upper.position+=Vector2(25*direction,-10)*delta
	await _seconds({},.1)
	var initial_landings := _count("landed")
	_check(actor.grounded and actor.telemetry().support_id==upper.get_instance_id(),"moving carrier owns initial physical support")
	await _until(func():return not actor.grounded,_direction(direction),1)
	_check(not actor.grounded,"running beyond carrier edge becomes genuinely airborne")
	# Clear the upper platform body before correction; faster steering must not
	# turn this fixture into a different valid landing back on its departure top.
	await _until(func():return actor.position.y>upper.position.y+actor.body_height+12,_direction(direction),1)
	await _until(func():return actor.grounded,_direction(-direction),2)
	_check(actor.grounded and actor.telemetry().support_id==lower.get_instance_id(),"air correction transitions to independent lower support")
	_check(_count("landed")==initial_landings+1 and actor.air_jumps_left==1,"support transfer dispatches exactly one new landing and budget refresh")
	measurements.merge(_trace_bounds());await _finish()

func _reset_pause_case() -> void:
	await _air("air pause resume and reset authority",Vector2(100,-100))
	await _step({"right":1.0})
	actor.apply_hitpause(.1)
	var initial: Vector2=actor.position
	var initial_velocity: Vector2=actor.velocity
	await _seconds({"left":1.0},.05)
	_check(actor.position==initial and actor.velocity==initial_velocity,"hitpause freezes ordinary air root and velocity despite changed input")
	await _seconds({"left":1.0},.22)
	_check(actor.facing==-1 and actor.velocity.x<0,"ordinary steering resumes after local pause expires")
	actor.reset_actor(Vector2(100,-500),1)
	await _step({"right":1.0})
	_near(actor.velocity.x,(2300 if variant=="candidate" else 1450)*dt,.001,"reset removes old authority and applies selected ordinary-air response immediately")
	_check(actor.air_jumps_left==1 and actor.hitpause_remaining==0 and actor.main_action==&"locomotion","reset preserves budgets and clears transient pause ownership")
	await _finish()

func _resource_fallback_case() -> void:
	await _air("null invalid and duplicate resource fallback")
	var profile_identity: int=actor.profile.get_instance_id()
	var cases: Array=[null,0.0,-1.0,NAN,INF]
	var all_fallback:=true
	for value in cases:
		actor.reset_actor(Vector2(0,-1000),1)
		if value==null: actor.profile.ordinary_air_response=null
		else:
			actor.profile.ordinary_air_response=CANDIDATE.ordinary_air_response.duplicate(true)
			actor.profile.ordinary_air_response.air_acceleration=value
		await _step({"right":1.0})
		all_fallback=all_fallback and absf(actor.velocity.x-1450*dt)<.001
	_check(all_fallback,"null zero negative NaN and infinite opt-in values use unchanged base air acceleration")
	actor.profile.ordinary_air_response=CANDIDATE.ordinary_air_response.duplicate(true)
	actor.reset_actor(Vector2(0,-1000),1)
	await _step({"right":1.0})
	_near(actor.velocity.x,2300*dt,.001,"restored valid optional resource takes effect without actor replacement")
	_check(actor.profile.get_instance_id()==profile_identity and CANDIDATE.ordinary_air_response.air_acceleration==2300 and BASELINE.ordinary_air_response==null,"instance tuning never mutates shared authored resources")
	await _finish()

func _finish() -> void:
	_check(engine_gaps.all(func(gap):return gap==1) and deltas.all(func(value):return absf(value-dt)<.0000001),"one production call per consecutive real physics callback at requested rate")
	_check(frames.all(func(frame):return frame.after.telemetry_coherent and frame.after.visual_root_untouched and frame.after.visual_facing==frame.after.facing),"attached view preserves motor root and exposes authoritative telemetry and facing")
	measurements.physics_samples=frames.size();total_ticks+=frames.size()
	var trace:=[]
	for frame in frames:trace.append({"tick":frame.tick,"position":frame.after.position,"velocity":frame.after.velocity,"grounded":frame.after.grounded,"owner":frame.after.main_action,"facing":frame.after.facing,"head":frame.after.visual_head,"pose":frame.after.visual_mode,"air_jumps_left":frame.after.air_jumps_left})
	scenarios.append({"name":name_,"variant":variant,"params":params,"failures":failures.size()-start_failures,"assertions":assertions,"measurements":measurements,"events":events,"trace":trace})
	driver.enabled=false;_release_input();world.queue_free()
	await physics_frame;await process_frame
	world=null;actor=null;driver=null;terrain=null
