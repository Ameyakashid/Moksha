extends "res://combat_pc/tests/soft_slope_regression.gd"
## M18 ground response: production calls in real callbacks, independent geometry.
## Reuses the unchanged M7 observation/geometry helpers, not a simulated motor.
const BASE_PROFILE = preload("res://combat_pc/resources/movement_profile.tres")
const AGILE_PATH = "res://combat_pc/resources/ground_response_agile.tres"
var variant := "baseline"
var candidate_from_file := false
var response_rows: Array[Dictionary] = []
var selected_profile: Resource
var protected_hashes := {}
var owner_signatures := {}

func _candidate() -> Resource:
	if ResourceLoader.exists(AGILE_PATH):
		candidate_from_file = true
		return load(AGILE_PATH).duplicate(true)
	var result = BASE_PROFILE.duplicate(true)
	result.ground_acceleration = 4800.0
	result.ground_braking = 2700.0
	result.reversal_acceleration = 6200.0
	result.turn_pose_seconds = .07
	return result

func _run() -> void:
	for path in ["res://combat_pc/player.gd", "res://combat_pc/player.tscn", "res://combat_pc/resources/movement_profile.gd", "res://combat_pc/resources/movement_profile.tres", "res://combat_pc/tests/soft_slope_regression.gd", "res://combat_pc/resources/ground_response_profile.gd", AGILE_PATH]:
		protected_hashes[path] = FileAccess.get_sha256(path)
	for mode in ["baseline", "candidate"]:
		variant = mode
		selected_profile = BASE_PROFILE.duplicate(true) if mode == "baseline" else _candidate()
		for direction in [-1, 1]:
			await _response_case(direction)
			await _sequence_case(direction)
			await _native_case(direction)
			await _interaction_case(direction, "jump")
			await _interaction_case(direction, "roll")
			await _interaction_case(direction, "attack")
			await _moving_flat_case(direction)
			for owner in ["crouch", "shield", "attack", "hurt", "roll", "air"]:
				await _owner_case(direction,owner)
		# Retained rigorous suites: exact full-body clearance, callback deltas,
		# slope contact/no momentum creation, seams, thin walls, action transitions.
		for gradient in [-1.0, -.5, .5, 1.0]:
			await _plane_case("neutral fall slope %.1f" % gradient, gradient, 0, 780, 0, 40, .4)
			await _plane_case("running fall slope %.1f" % gradient, gradient, 218, 780, -1, 40, .8)
		await _continuous_joins()
		await _component_blocking()
		await _action_and_carrier_flows()
	var stable := true
	for path in protected_hashes: stable = stable and protected_hashes[path] == FileAccess.get_sha256(path)
	name_ = "report"
	_check(stable, "protected runtime and original harness sources remain stable during this run")
	var report := {"milestone":18, "suite":"ground response", "physics_hz":hz, "engine":Engine.get_version_info().string,
		"candidate_loaded_from_actual_resource":candidate_from_file,"candidate_resource_sha256":FileAccess.get_sha256(AGILE_PATH) if candidate_from_file else "prototype duplicate",
		"checks":checks,"failures":failures,"scenario_count":scenarios.size(),"scenarios":scenarios,"response_rows":response_rows,
		"source_hashes":protected_hashes,"production_hash_stable_during_run":stable,
		"method":"One production physics_tick per actual engine callback. Reused unchanged M7 collision, exact-body clearance, moving support and action fixtures. Summary assertions are per behavior, never per-frame totals.",
		"limits":["Ground responsiveness only; no numerical parity claim to another game.","Headless physical acceptance; visual judgment is separate.","Reverse zero is first sample at or past zero; actual crossing occurs within that preceding callback."]}
	FileAccess.open("res://combat_pc/tests/ground_response_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(_safe(report),"  ")+"\n")
	print("GROUND_RESPONSE_M18 %dHz: %d scenarios, %d failures; actual resource %s" % [hz,scenarios.size(),failures.size(),candidate_from_file])
	for row in response_rows: print(JSON.stringify(row))
	quit(0 if failures.is_empty() else 1)

func _begin(label: String, at: Vector2, use_probe := false) -> void:
	await super._begin(variant + ": " + label, at, use_probe)
	actor.profile = selected_profile.duplicate(true)
	actor.initial_facing = 1

func _flat(label: String) -> void:
	await _begin(label,Vector2(0,198))
	_terrain([Vector2(-2000,0),Vector2(2000,0)],Vector2(0,200))
	await _start()
	_check(await _until(func():return actor.grounded),"actor establishes real floor contact before input")

func _response_case(direction: int) -> void:
	await _flat("start stop reverse direction%d" % direction)
	var row := {"variant":variant,"direction":direction,"physics_hz":hz,"speed_cap":actor.profile.run_speed}
	var start_tick := ticks
	var start_position: Vector2 = actor.position
	await _until(func():return absf(actor.velocity.x-direction*218)<.01,_direction(direction),.5)
	row.start_to_cap_seconds = (ticks-start_tick)*dt
	row.start_to_cap_distance = absf(actor.position.x-start_position.x)
	_check(absf(actor.velocity.x-direction*218)<.01,"start reaches unchanged 218 px/s cap")
	start_tick=ticks;start_position=actor.position
	await _until(func():return absf(actor.velocity.x)<.01,{},.5)
	row.stop_seconds=(ticks-start_tick)*dt
	row.stop_distance=absf(actor.position.x-start_position.x)
	_check(actor.velocity.x==0,"release reaches an exact finite stop")
	await _seconds(_direction(direction),.2)
	start_tick=ticks;start_position=actor.position
	await _step(_direction(-direction))
	_check(actor.facing==-direction and actor.velocity.x*direction>0,"opposite input turns on the first callback while old momentum remains")
	_check(actor.pose==&"turn","physical reversal uses turn pose")
	await _until(func():return actor.velocity.x*direction<=0,_direction(-direction),.5)
	row.reverse_zero_seconds=(ticks-start_tick)*dt
	row.reverse_zero_distance=(actor.position.x-start_position.x)*direction
	await _until(func():return absf(actor.velocity.x+direction*218)<.01,_direction(-direction),.5)
	row.reverse_full_seconds=(ticks-start_tick)*dt
	_check(absf(actor.velocity.x+direction*218)<.01,"reversal reaches opposite unchanged cap")
	var max_speed:=0.0
	for frame in frames:max_speed=maxf(max_speed,absf(float(frame.after.velocity[0])))
	_check(max_speed<=218.001,"start brake and reversal never overshoot cap")
	row.max_speed=max_speed
	measurements.merge(row)
	measurements.merge(_trace_bounds(1,true))
	response_rows.append(row)
	await _finish()

func _sequence_case(direction: int) -> void:
	await _flat("repeated taps analog and opposite inputs direction%d" % direction)
	var tap_distances: Array[float]=[]
	var cap_ok := true
	for _i in 6:
		var before: Vector2=actor.position
		await _seconds(_direction(direction),.033333333333)
		await _seconds({},.15)
		tap_distances.append((actor.position.x-before.x)*direction)
		cap_ok = cap_ok and absf(actor.velocity.x)<.01
	_check(cap_ok and tap_distances.all(func(value):return absf(value-tap_distances[0])<.01),"six press/release taps settle consistently with no residual drift")
	for strength in [.25,.75,.4,1.0]:
		await _seconds({"right" if direction>0 else "left":strength},.2)
		cap_ok=cap_ok and absf(actor.velocity.x-direction*218*strength)<.01
	_check(cap_ok,"analog strength changes settle at proportional run targets")
	await _seconds({"left":1.0,"right":1.0},.2)
	_check(actor.velocity.x==0,"equal opposing inputs cancel and brake to zero")
	for _i in 12:
		await _seconds(_direction(direction),.05)
		await _seconds(_direction(-direction),.05)
	var max_speed:=0.0
	for frame in frames:max_speed=maxf(max_speed,absf(float(frame.after.velocity[0])))
	_check(max_speed<=218.001 and actor.grounded,"rapid alternating input stays supported and within run cap")
	measurements={"tap_distances":tap_distances,"max_speed":max_speed}
	measurements.merge(_trace_bounds(1,true))
	await _finish()

func _native_case(direction: int) -> void:
	await _flat("native parsed run reverse release direction%d" % direction)
	var forward=KEY_D if direction>0 else KEY_A
	var backward=KEY_A if direction>0 else KEY_D
	_key(forward,true)
	await _seconds(null,.2)
	_check(absf(actor.velocity.x-direction*218)<.01,"parsed physical key reaches native cap")
	_key(forward,false);_key(backward,true)
	await _step(null)
	_check(actor.facing==-direction,"native opposite key changes facing on its next real callback")
	await _seconds(null,.2)
	_key(backward,false)
	await _seconds(null,.2)
	_check(actor.velocity.x==0 and actor.grounded,"native key release settles without stuck direction")
	await _finish()

func _key(code: int,pressed: bool) -> void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)

func _interaction_case(direction: int, action: String) -> void:
	await _flat("run into %s direction%d" % [action,direction])
	await _seconds(_direction(direction),.2)
	var start_tick:=ticks
	await _step(_direction(direction,{action:true}))
	if action=="jump":
		_check(not actor.grounded and actor.velocity.y<0 and _count("ground_jump")==1,"full-speed run accepts ground jump on next callback")
		var air_left: int=actor.air_jumps_left
		await _seconds(_direction(-direction,{"jump":true}),.06)
		_check(actor.air_jumps_left==air_left and actor.velocity.x*direction>0,"ground tuning does not replace slower authored airborne steering or consume extra jump")
		await _until(func():return actor.grounded,_direction(direction),2)
		_check(actor.grounded and _count("ground_jump")==1,"jump returns to support with one launch")
	else:
		var owner: bool=actor.main_action==&"roll" if action=="roll" else actor.weapon_phase!=&"idle"
		_check(owner,"full-speed run accepts requested action on next callback")
		await _seconds(_direction(direction),.7)
		_check(actor.main_action==&"locomotion" and actor.weapon_phase==&"idle" and actor.grounded,"action completes and returns to supported movement")
		_check(_count(action+"_started")==1 and _count(action+"_finished")==1,"action starts and finishes exactly once")
		var starts=events.filter(func(item):return item.event==action+"_started")
		var ends=events.filter(func(item):return item.event==action+"_finished")
		if not starts.is_empty() and not ends.is_empty():measurements.action_seconds=(ends[0].tick-starts[0].tick)*dt
	measurements.entry_latency_seconds=dt
	measurements.elapsed_seconds=(ticks-start_tick)*dt
	measurements.merge(_trace_bounds())
	await _finish()

func _moving_flat_case(direction: int) -> void:
	await _begin("moving flat run brake reverse direction%d" % direction,Vector2(0,198))
	var carrier:=_terrain([Vector2(-1500,0),Vector2(1500,0)],Vector2(0,200),true)
	await _start();await _until(func():return actor.grounded)
	before_tick=func(delta):carrier.position+=Vector2(36*direction,-12)*delta
	var relative_start: Vector2=actor.position-carrier.position
	await _seconds({},.3)
	_near((actor.position-carrier.position).distance_to(relative_start),0,.03,"neutral rider follows translation without extra locomotion")
	await _seconds(_direction(direction),.2)
	await _seconds(_direction(-direction),.2)
	await _seconds({},.2)
	_check(actor.velocity.x==0 and actor.grounded,"run reverse brake remains attached to translating support")
	measurements.merge(_trace_bounds(1,true));await _finish()

func _finish() -> void:
	_check(engine_gaps.all(func(gap):return gap==1) and deltas.all(func(value):return absf(value-dt)<.0000001),"one production call per consecutive real callback at requested delta")
	measurements.physics_samples=frames.size()
	scenarios.append({"name":name_,"variant":variant,"params":params,"failures":failures.size()-start_failures,"assertions":assertions,"measurements":measurements,"events":events})
	driver.enabled=false;_release_input();world.queue_free()
	await physics_frame;await process_frame
	world=null;actor=null;driver=null;terrain=null


func _owner_case(direction: int, owner: String) -> void:
	await _flat("unchanged %s owner direction%d" % [owner,direction])
	actor.velocity.x=120*direction
	var input:=_direction(-direction)
	if owner=="crouch": input["down"]=1.0
	elif owner=="shield": input["shield"]=true
	elif owner=="attack": input["attack"]=true
	elif owner=="roll": input["roll"]=true
	elif owner=="hurt": actor.receive_hit({"impulse":Vector2(120*direction,0),"hitpause":0.0,"stun_seconds":.4})
	elif owner=="air":
		actor.reset_actor(Vector2(0,100),direction)
		actor.velocity=Vector2(120*direction,-50)
	var sequence: Array[Dictionary]=[]
	var covered := false
	var observed_phases: Dictionary={}
	var duration:=.1 if owner=="air" else (.25 if owner=="roll" else .3)
	for _i in roundi(duration*hz):
		var adjusted:=input.duplicate()
		adjusted.erase("left");adjusted.erase("right")
		if _i<roundi(duration*hz)/3:adjusted.merge(_direction(-direction))
		elif _i>=roundi(duration*hz)*2/3:adjusted.merge(_direction(direction))
		await _step(adjusted)
		observed_phases[String(actor.weapon_phase) if owner=="attack" else (String(actor.roll_phase) if owner=="roll" else String(actor.shield_phase))]=true
		var owned: bool = actor.crouched if owner=="crouch" else (actor.shield_phase!=&"idle" if owner=="shield" else (actor.weapon_phase!=&"idle" if owner=="attack" else (not actor.grounded if owner=="air" else actor.main_action==StringName(owner))))
		covered=covered or owned
		sequence.append({"position":actor.position,"velocity":actor.velocity,"facing":actor.facing,"grounded":actor.grounded,"main_action":actor.main_action,"weapon_phase":actor.weapon_phase,"shield_phase":actor.shield_phase,"crouched":actor.crouched})
	_check(covered,"trace reaches the intended excluded movement owner")
	var key:=owner+str(direction)
	if variant=="baseline":owner_signatures[key]=sequence
	else:
		var reference: Array=owner_signatures[key]
		var equal:=reference.size()==sequence.size()
		var max_position_error:=0.0
		var max_velocity_error:=0.0
		for index in mini(reference.size(),sequence.size()):
			max_position_error=maxf(max_position_error,reference[index].position.distance_to(sequence[index].position))
			max_velocity_error=maxf(max_velocity_error,reference[index].velocity.distance_to(sequence[index].velocity))
			for field in ["facing","grounded","main_action","weapon_phase","shield_phase","crouched"]:equal=equal and reference[index][field]==sequence[index][field]
		_check(equal and max_position_error<.00001 and max_velocity_error<.00001,"candidate preserves baseline position velocity and ownership throughout excluded owner interval")
		measurements.maximum_position_error=max_position_error
		measurements.maximum_velocity_error=max_velocity_error
	measurements.owner=owner
	measurements.sampled_seconds=duration
	measurements.observed_phases=observed_phases.keys()
	if owner=="attack":_check(observed_phases.has("windup") and observed_phases.has("active") and observed_phases.has("recovery"),"equality interval covers weapon windup active and recovery")
	if owner=="roll":_check(observed_phases.has("start") and observed_phases.has("travel") and observed_phases.has("recovery"),"equality interval covers roll start travel and recovery")
	await _finish()
