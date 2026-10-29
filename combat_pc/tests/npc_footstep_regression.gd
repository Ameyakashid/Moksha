extends SceneTree
## M17 acceptance: actual unchanged motor steps and Godot floor collisions.
## Synthetic token calls are confined to the explicitly labelled contract case.
const BUS = preload("res://scripts/sensory/noise_bus.gd")
const DRIVER = preload("res://combat_pc/tests/npc_footstep_driver.gd")
const NPC = preload("res://movement/actors/npc.tscn")
const SURFACE = preload("res://combat_pc/components/surface_pulse.tscn")
var SOURCE: PackedScene
var COMPOSED: PackedScene
var hz := 60
var dt := 1.0 / 60.0
var checks: Array = []
var failures: Array = []
var scenarios: Array = []
var label := ""
var check_start := 0
var total_ticks := 0
var source_hashes := {}
var autoload_initial := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	dt = 1.0 / hz
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks.append({"scenario":label,"message":message,"pass":ok})
	if not ok:
		failures.append(label+": "+message)
		printerr("FAIL "+label+": "+message)

func _tick(count := 1) -> void:
	for _i in count:
		await physics_frame
		await process_frame
		total_ticks += 1

func _seconds(seconds: float) -> void:
	await _tick(ceili(seconds/dt))

func _until(predicate: Callable, seconds := 2.0) -> bool:
	for _i in ceili(seconds/dt):
		await _tick()
		if predicate.call(): return true
	return false

func _fixture(name_: String) -> Dictionary:
	label = name_
	check_start = checks.size()
	var world := Node2D.new()
	world.name = "FootstepAcceptanceWorld"
	root.add_child(world)
	var bus := BUS.new()
	world.add_child(bus)
	var driver := DRIVER.new()
	world.add_child(driver)
	var f := {"world":world,"bus":bus,"driver":driver,"actors":[],"events":[],"receipts":[],"landings":[],"surface":null,"geometry_matches":[],"readonly":true,"bus_first":true}
	bus.noise_emitted.connect(func(origin: Vector2, kind: StringName, loudness: float, source: Node):
		f.events.append({"origin":origin,"kind":kind,"loudness":loudness,"body_id":source.get_instance_id() if is_instance_valid(source) else 0,"physics_frame":Engine.get_physics_frames()}))
	return f

func _shape(parent: Node2D, size: Vector2) -> void:
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	parent.add_child(collider)

func _floor(f: Dictionary, position_ := Vector2(0,110), size := Vector2(5000,20), angle := 0.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Floor"
	body.position = position_
	body.rotation = angle
	_shape(body,size)
	f.world.add_child(body)
	return body

func _carrier(f: Dictionary, velocity: Vector2) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.name = "TranslatingFloor"
	body.position = Vector2(0,110)
	body.sync_to_physics = false
	_shape(body,Vector2(4000,20))
	f.world.add_child(body)
	f.driver.carriers.append({"body":body,"velocity":velocity})
	return body

func _actor(f: Dictionary, position_ := Vector2(0,100), instrument := true, composed := false) -> Dictionary:
	var body: CharacterBody2D = (COMPOSED if composed else NPC).instantiate()
	body.position = position_
	f.world.add_child(body)
	body.set_physics_process(false)
	body.get_node("Intent").process_mode = Node.PROCESS_MODE_DISABLED
	body.landed.connect(func(speed: float): f.landings.append({"body_id":body.get_instance_id(),"physics_frame":Engine.get_physics_frames(),"speed":speed,"position":body.global_position}))
	var source: Node = body.get_node("Footsteps") if composed else null
	if instrument and not composed:
		source = SOURCE.instantiate()
		body.add_child(source)
	if source != null:
		_check(source.bind_body(body,f.bus),"source explicitly binds a live NPC and local bus")
		source.footstep_emitted.connect(func(receipt: Dictionary):
			f.readonly = f.readonly and receipt.is_read_only()
			f.bus_first = f.bus_first and f.events.any(func(event): return event.body_id==receipt.body_id and event.origin==receipt.origin and event.physics_frame==receipt.physics_frame and event.kind==receipt.kind)
			var q := PhysicsRayQueryParameters2D.create(receipt.origin+receipt.normal*1.0,receipt.origin-receipt.normal*1.0,1)
			q.exclude = [body.get_rid()]
			var hit := body.get_world_2d().direct_space_state.intersect_ray(q)
			f.geometry_matches.append({"found":not hit.is_empty(),"receipt_origin":receipt.origin,"receipt_normal":receipt.normal,"receipt_support":receipt.support_id,"ray":hit})
			f.receipts.append(receipt))
		if not composed: body.landed.connect(source.capture_landing)
	var entry := {"body":body,"source":source,"composed":composed,"samples":[],"skip":false}
	f.actors.append(entry)
	f.driver.actors.append(entry)
	return entry

func _surface(f: Dictionary, actor: Node2D) -> Node:
	var surface := SURFACE.instantiate()
	root.add_child(surface)
	surface.set_process(false)
	_check(surface.bind_surface(f.world,actor,f.bus),"unchanged SurfacePulse explicitly binds the same local bus")
	f.surface = surface
	return surface

func _events(f: Dictionary, kind: StringName) -> Array:
	return f.receipts.filter(func(event): return event.kind == kind)

func _path(entry: Dictionary, start := 0, end := -1) -> float:
	var distance := 0.0
	var samples: Array = entry.samples.slice(start,end if end>=0 else entry.samples.size())
	for sample in samples:
		if sample.was_grounded and sample.grounded: distance += sample.travel.length()
	return distance

func _verify(f: Dictionary, expect_receipts := true) -> void:
	var good := true
	var geometry_good := true
	var motion_good := true
	var unique := {}
	for event in f.receipts:
		var key := "%s:%s:%s"%[event.body_id,event.epoch,event.serial]
		good = good and not unique.has(key)
		unique[key] = true
		good = good and event.origin.is_finite() and event.normal.is_finite() and absf(event.normal.length()-1.0)<0.001
		good = good and is_finite(event.relative_distance) and event.relative_distance>=0 and is_finite(event.relative_speed) and event.relative_speed>=0 and is_finite(event.landing_speed)
		good = good and event.support_id!=0 and not String(event.support_name).is_empty() and event.kind in [&"enemy_step",&"enemy_land"]
		var count := 0
		for delivered in f.events:
			if delivered.body_id==event.body_id and delivered.kind==event.kind and delivered.origin==event.origin and delivered.physics_frame==event.physics_frame: count += 1
		good = good and count==1
		if event.kind==&"enemy_land":
			motion_good = motion_good and f.landings.any(func(land): return land.body_id==event.body_id and land.physics_frame==event.physics_frame and absf(land.speed-event.landing_speed)<0.001)
		else:
			var found := false
			for actor in f.actors:
				if not is_instance_valid(actor.body) or actor.body.get_instance_id()!=event.body_id: continue
				for sample in actor.samples:
					if sample.physics_frame!=event.physics_frame: continue
					found = true
					var tangent := Vector2(-event.normal.y,event.normal.x)
					var measured: float = absf((sample.travel-sample.oracle_support_velocity*dt).dot(tangent))
					motion_good = motion_good and sample.grounded and sample.was_grounded and absf(measured-event.relative_distance)<0.001 and absf(measured/dt-event.relative_speed)<0.01
					if is_instance_valid(actor.get("probe_support")): motion_good = motion_good and not sample.was_on_wall
			motion_good = motion_good and found
	for match_ in f.geometry_matches:
		geometry_good = geometry_good and match_.found
		if match_.found:
			geometry_good = geometry_good and match_.ray.collider_id==match_.receipt_support and match_.ray.position.distance_to(match_.receipt_origin)<0.25 and match_.ray.normal.distance_to(match_.receipt_normal)<0.01
	_check(motion_good,"step distance/speed match independent actual ground travel and landing strength matches same-frame motor signal")
	_check(good and f.readonly and f.bus_first,"finite immutable unique receipt snapshots follow exactly one matching local bus event")
	if expect_receipts: _check(not f.receipts.is_empty() and geometry_good,"every real receipt origin and normal matches an independent current-floor ray on its named support")
	_check(root.get_node("NoiseBus").event_count==autoload_initial,"no event routes to project autoload NoiseBus")

func _done(f: Dictionary, details: Dictionary = {}) -> void:
	details["receipts"] = f.receipts
	details["bus_event_count"] = f.events.size()
	scenarios.append({"name":label,"checks":checks.slice(check_start),"details":details})
	if is_instance_valid(f.surface): f.surface.free()
	f.world.free()
	await _tick(2)

func _run() -> void:
	SOURCE = load("res://combat_pc/components/character_footsteps.tscn")
	COMPOSED = load("res://combat_pc/fixtures/footstep_npc.tscn")
	if SOURCE==null or COMPOSED==null:
		printerr("M17 source or fixture unavailable")
		quit(2)
		return
	autoload_initial = root.get_node("NoiseBus").event_count
	for path in ["combat_pc/components/character_footsteps.gd","combat_pc/components/character_footsteps.tscn","combat_pc/resources/footstep_profile.gd","combat_pc/resources/footstep_profile.tres","combat_pc/fixtures/footstep_npc_motor.gd","combat_pc/fixtures/footstep_npc.tscn","combat_pc/fixtures/npc_footstep_wire.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://"+path)
	await _cadence_and_stops()
	await _quiet_modes()
	await _late_air_pause()
	await _non_locomotion()
	await _landing_and_surface()
	await _slopes()
	await _moving_floor()
	await _changing_carrier()
	await _gap_drop()
	await _reset_and_lifecycle()
	await _bus_invalidation()
	await _trajectory_parity()
	await _contract_tokens()
	var stable := true
	for path in source_hashes: stable = stable and source_hashes[path]==FileAccess.get_sha256("res://"+path)
	label = "source stability and v20 baseline"
	_check(stable,"M17 runtime source hashes stayed stable throughout the run")
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://combat_pc/tests/npc_footstep_baseline_hashes.json"))
	var protected := bool(baseline.all_match)
	for record in baseline.files: protected = protected and record.baseline_sha256==FileAccess.get_sha256("res://"+record.path)
	_check(protected,"all 48 protected PC original motor NPC enemy contact surface and bus sources match v20 byte-for-byte")
	var report := {"milestone":17,"suite":"independent actual NPC movement footsteps","engine":Engine.get_version_info().string,"physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"runtime_source_hashes":source_hashes,"runtime_sources_stable":stable,"protected_sources_match_v20":protected,"generated_utc":Time.get_datetime_string_from_system(true),"method":"Physical cases call the unchanged original CharacterBody2D movement motor during real physics ticks. Independent actual travel totals and same-frame ray intersections check cadence and floor geometry. Token failure cases are separately labelled; no physical event is fabricated.","limitations":["Headless focused component tests; native visual review is separate.","Distances and thresholds are authored tuning, not animation footplant timing or recovered game constants.","Translating nonrotating supports only; rotation/skew/scaling support is not claimed.","No complete NPC AI, audio playback, or broad old-game regression is claimed."]}
	FileAccess.open("res://combat_pc/tests/npc_footstep_results_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("NPC_FOOTSTEP_M17 %dHz: %d checks, %d scenarios, %d failures"%[hz,checks.size(),scenarios.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func _cadence_and_stops() -> void:
	for axis_ in [0.45,1.0]:
		var f := _fixture("ground distance cadence axis "+str(axis_))
		_floor(f)
		var a := _actor(f)
		await _seconds(0.2)
		var begin: int = a.samples.size()
		a.body.set_intent(axis_)
		await _seconds(2.0)
		var travel := _path(a,begin)
		var steps := _events(f,&"enemy_step")
		_check(absf(steps.size()-travel/28.0)<=1.5,"count follows actual grounded path / authored 28px spacing at this speed")
		var spacing_good := steps.size()>=4
		var gaps: Array = []
		for i in range(1,steps.size()):
			var gap: float = steps[i].origin.distance_to(steps[i-1].origin)
			gaps.append(gap)
			spacing_good = spacing_good and absf(gap-28.0)<a.body.tuning.run_speed*dt+1.0
		_check(spacing_good,"steady footsteps are distance-spaced rather than periodic idle pings")
		a.body.set_intent(0)
		await _seconds(0.15)
		var stopped_count: int = f.events.size()
		await _seconds(0.6)
		_check(f.events.size()==stopped_count,"rest after actual braking is silent")
		var before_count: int = f.events.size()
		a.body.set_intent(-axis_)
		await _tick()
		_check(f.events.size()==before_count,"first restart/reversal tick cannot emit before traversing a new stride")
		await _seconds(0.4)
		_check(_events(f,&"enemy_step").size()>steps.size(),"reversed real ground travel resumes steps")
		_verify(f)
		await _done(f,{"ground_path":travel,"initial_steps":steps.size(),"step_origin_gaps":gaps})

func _quiet_modes() -> void:
	var f := _fixture("idle wall airborne and skipped motor quietness")
	_floor(f)
	_floor(f,Vector2(35,20),Vector2(20,160))
	var a := _actor(f)
	await _seconds(0.6)
	_check(f.events.is_empty(),"settled idle is silent")
	a.body.set_intent(1)
	await _seconds(0.4)
	var wall_x: float = a.body.position.x
	var before: int = f.events.size()
	await _seconds(0.8)
	_check(absf(a.body.position.x-wall_x)<0.1 and f.events.size()==before,"continuous intent pushing a wall with no real travel is silent")
	a.skip = true
	a.body.velocity = Vector2(175,0)
	await _seconds(0.4)
	_check(f.events.size()==before,"skipping motor ticks never polls stale movement or collision data")
	a.skip = false
	a.body.enabled = false
	await _seconds(0.3)
	_check(f.events.size()==before,"disabled motor cannot turn stale velocity into footsteps")
	a.body.enabled = true
	a.body.reset_at(Vector2(-150,-250))
	a.source.reset_history()
	a.body.set_intent(1)
	before = f.events.size()
	await _seconds(0.3)
	_check(not a.body.is_on_floor() and f.events.size()==before,"actual airborne movement is silent before touchdown")
	_verify(f,false)
	await _done(f,{"wall_x":wall_x})



func _late_air_pause() -> void:
	for mode in ["scene tree", "motor hit pause"]:
		var f := _fixture("qualified late-air landing survives "+mode)
		_floor(f)
		var a := _actor(f,Vector2(0,-110),true,true)
		var ready_to_pause := await _until(func(): return not a.body.is_on_floor() and a.body.velocity.y>300 and 100-a.body.position.y<1.5*a.body.velocity.y*dt,1.5)
		var before_pause: Dictionary = a.source.debug_snapshot()
		_check(ready_to_pause and before_pause.air_seconds>=0.06 and before_pause.air_travel>=6,"real flight is already qualified and reaches one or two physics ticks before touchdown")
		var position_before: Vector2 = a.body.position
		if mode=="scene tree": paused = true
		else: a.body.apply_pause(0.2)
		await _seconds(0.15)
		_check(a.body.position.distance_to(position_before)<0.001 and f.events.is_empty(),"late-air interruption freezes actual motor motion and emits no stale event")
		if mode=="scene tree": paused = false
		var landed := await _until(func(): return a.body.is_on_floor(),0.5)
		await _seconds(0.15)
		var lands := _events(f,&"enemy_land")
		_check(landed and lands.size()==1,"resuming the same already-qualified airborne episode emits exactly one real landing")
		_check(_events(f,&"enemy_step").is_empty(),"resumed landing cannot release a catch-up footstep burst")
		_verify(f)
		await _done(f,{"pause_mode":mode,"position_before_pause":position_before,"remaining_floor_gap":100-position_before.y,"air_seconds_before_pause":before_pause.air_seconds,"air_travel_before_pause":before_pause.air_travel,"landing_count":lands.size()})

func _non_locomotion() -> void:
	var f := _fixture("composed dash and external impulse are not ordinary footsteps")
	_floor(f)
	var a := _actor(f,Vector2(0,100),true,true)
	await _seconds(0.2)
	var start: Vector2 = a.body.position
	a.body.set_intent(1,false,false,true)
	await _seconds(0.1)
	_check(a.body.position.distance_to(start)>28 and a.body.dash_left>0,"real dash travels beyond a stride while the original motor remains in dash")
	_check(f.events.is_empty(),"non-locomotion dash travel cannot emit ordinary footsteps")
	a.body.reset_at(Vector2(0,100))
	a.body.set_intent(0)
	await _seconds(0.1)
	a.body.apply_impulse(Vector2(350,0),0.3)
	start = a.body.position
	await _seconds(0.2)
	_check(a.body.position.distance_to(start)>28 and a.body.stun_left>0,"actual external impulse moves farther than a stride while stunned")
	_check(f.events.is_empty(),"stunned impulse displacement cannot emit ordinary footsteps")
	_verify(f,false)
	await _done(f)

func _landing_and_surface() -> void:
	for mode in ["jump","drop"]:
		var f := _fixture("real "+mode+" landing and retained contour")
		_floor(f)
		var a := _actor(f,Vector2(0,100) if mode=="jump" else Vector2(0,-110))
		var surface := _surface(f,a.body)
		if mode=="jump":
			await _seconds(0.2)
			a.body.set_intent(0,true,false,false,true)
			await _tick()
			a.body.set_intent(0,false,false,false,true)
		_check(await _until(func(): return not _events(f,&"enemy_land").is_empty()),"true airborne trajectory reaches a qualifying real floor landing")
		await _seconds(0.15)
		var lands := _events(f,&"enemy_land")
		_check(lands.size()==1 and _events(f,&"enemy_step").is_empty(),"one landing event with no same-frame or catch-up footsteps")
		if not lands.is_empty():
			var land: Dictionary = lands[0]
			_check(land.landing_speed>=70 and absf(land.origin.y-100)<0.25,"landing strength and origin come from present physical touchdown")
			_check(surface.accepted_event_count==1 and surface.pulses.size()==1 and surface.pulses[0].origin==land.origin,"local NoiseBus feeds exactly one retained contour at the original landing point")
		a.body.set_intent(1)
		_check(await _until(func(): return not _events(f,&"enemy_step").is_empty(),0.6),"ordinary distance cadence resumes after landing")
		var steps := _events(f,&"enemy_step")
		if not steps.is_empty():
			_check(surface.accepted_event_count==f.events.size() and surface.pulses.back().origin==steps.back().origin,"a real step also preserves its floor origin through unchanged SurfacePulse")
		_verify(f)
		await _done(f)

func _slopes() -> void:
	for direction in [-1,1]:
		var f := _fixture("real slope "+("uphill" if direction>0 else "downhill"))
		var floor_ := _floor(f,Vector2(0,110),Vector2(4000,20),deg_to_rad(-20))
		var a := _actor(f,Vector2(0,80))
		await _seconds(0.4)
		f.events.clear()
		f.receipts.clear()
		f.geometry_matches.clear()
		a.source.reset_history()
		var start: int = a.samples.size()
		a.body.set_intent(direction)
		await _seconds(1.5)
		var distance := _path(a,start)
		var steps := _events(f,&"enemy_step")
		_check(steps.size()>=7 and absf(steps.size()-distance/28.0)<=1.5,"slope cadence follows actual two-dimensional ground path")
		_check(_events(f,&"enemy_land").is_empty(),"continuous slope movement produces no fake landing events")
		var normals_good := true
		var expected := Vector2.UP.rotated(floor_.rotation)
		for step in steps: normals_good = normals_good and step.normal.distance_to(expected)<0.01
		_check(normals_good,"uphill/downhill origins use the slope's current normal")
		_verify(f)
		await _done(f,{"ground_path":distance,"steps":steps.size(),"expected_normal":expected})

func _moving_floor() -> void:
	for variant in ["translating support", "wall-clipped translating support", "static conveyor"]:
		var clipped: bool = variant.begins_with("wall-clipped")
		var conveyor: bool = variant=="static conveyor"
		var f := _fixture(variant+" idle and relative walk")
		var carrier: PhysicsBody2D = _floor(f) if conveyor else _carrier(f,Vector2(80,0))
		if conveyor:
			carrier.constant_linear_velocity = Vector2(80,0)
			f["virtual_velocity"] = Vector2(80,0)
		if clipped: _floor(f,Vector2(75,20),Vector2(20,160))
		var a := _actor(f)
		a["probe_support"] = carrier
		await _seconds(0.25)
		a.source.reset_history()
		f.events.clear()
		f.receipts.clear()
		f.geometry_matches.clear()
		var start: Vector2 = a.body.position
		await _seconds(1.0)
		var carried: Vector2 = a.body.position-start
		_check(carried.length()>5,"actual engine platform carry moves the idle body")
		_check(f.events.is_empty(),"carried-only world displacement is silent"+(" including wall-clipped carry" if clipped else ""))
		if not clipped:
			var start_walk: Vector2 = a.body.position
			var floor_start := carrier.position
			a.body.set_intent(1)
			await _seconds(1.0)
			var relative: Vector2 = (a.body.position-start_walk)-(Vector2(80,0) if conveyor else carrier.position-floor_start)
			var steps := _events(f,&"enemy_step")
			_check(steps.size()>=4 and absf(steps.size()-relative.length()/28.0)<=1.5,"walking on translating support emits only relative own-travel cadence")
			_verify(f)
			await _done(f,{"idle_world_travel":carried,"relative_walk":relative,"step_count":steps.size()})
		else:
			await _seconds(0.3)
			_check(a.body.is_on_wall() and f.events.is_empty(),"carrier pushing an idle NPC into a wall remains quiet")
			var wall_start: Vector2 = a.body.position
			a.body.set_intent(-1)
			await _tick()
			_check(f.events.is_empty(),"first wall-escape tick cannot turn ambiguous previous carry into a footstep")
			await _seconds(0.8)
			var escape_steps := _events(f,&"enemy_step")
			_check(a.body.position.x<wall_start.x-40 and not a.body.is_on_wall(),"real motor walks away from carrier-pushed wall into unambiguous floor support")
			_check(escape_steps.size()>=3 and escape_steps.size()<=5,"ordinary distance cadence resumes after wall escape without an extra stride burst")
			_verify(f)
			await _done(f,{"idle_world_travel":carried,"escape_steps":escape_steps.size(),"escape_world_travel":a.body.position-wall_start})


func _changing_carrier() -> void:
	var f := _fixture("changing carrier reversal and stop use fresh direct-state velocity")
	var carrier := _carrier(f,Vector2(80,0))
	var a := _actor(f)
	a["probe_support"] = carrier
	await _seconds(0.25)
	a.source.reset_history()
	f.events.clear()
	f.receipts.clear()
	f.geometry_matches.clear()
	var first_sample: int = a.samples.size()
	a.body.set_intent(1)
	for velocity in [80.0,-80.0,0.0,80.0]:
		f.driver.carriers[0].velocity = Vector2(velocity,0)
		await _seconds(0.5)
	var measured_own_distance := 0.0
	var observed_velocities := {}
	var observed_positive := false
	var observed_negative := false
	var observed_stopped := false
	for sample in a.samples.slice(first_sample):
		if sample.was_grounded and sample.grounded:
			measured_own_distance += absf((sample.travel-sample.oracle_support_velocity*dt).x)
			observed_velocities[str(snappedf(sample.oracle_support_velocity.x,0.1))] = true
			observed_positive = observed_positive or sample.oracle_support_velocity.x>79
			observed_negative = observed_negative or sample.oracle_support_velocity.x < -79
			observed_stopped = observed_stopped or absf(sample.oracle_support_velocity.x)<0.1
	var steps := _events(f,&"enemy_step")
	_check(observed_positive and observed_negative and observed_stopped,"independent pre-motor physics-server oracle observes positive reverse and stopped support velocities")
	_check(absf(steps.size()-measured_own_distance/28.0)<=1.5,"changing support direction/speed preserves actual own-distance cadence")
	_check(_events(f,&"enemy_land").is_empty(),"carrier reversal/stops do not fabricate airborne landings")
	_verify(f)
	await _done(f,{"independent_own_distance":measured_own_distance,"steps":steps.size(),"observed_support_velocities":observed_velocities.keys(),"oracle":"Read support PhysicsDirectBodyState2D point velocity independently before each real motor step; do not infer reversal carry from requested transform displacement."})

func _gap_drop() -> void:
	for depth in [4.0,100.0]:
		var f := _fixture("actual ledge break depth "+str(depth))
		_floor(f,Vector2(-100,110),Vector2(200,20))
		_floor(f,Vector2(312,110+depth),Vector2(600,20))
		var a := _actor(f,Vector2(-80,100))
		await _seconds(0.2)
		a.body.set_intent(1)
		await _seconds(2.0)
		var lands := _events(f,&"enemy_land")
		var airborne := 0
		for sample in a.samples:
			if not sample.grounded: airborne += 1
		_check(a.body.position.x>150 and a.body.is_on_floor(),"original motor actually traverses the break onto the lower catch floor")
		_check(lands.size()<=1,"one airborne episode never produces repeated landings")
		if depth>=100: _check(lands.size()==1 and airborne>ceili(0.06/dt),"deep real drop exceeds authored airtime/travel thresholds and emits one landing")
		else: _check(lands.is_empty(),"brief 4px descent across 12px break does not satisfy authored landing thresholds")
		_verify(f)
		await _done(f,{"drop_depth":depth,"airborne_frames":airborne,"landing_count":lands.size(),"gap_width":12,"note":"12px break: both measured trajectories are recorded; the brief 4px descent remains below landing thresholds, while the 100px descent qualifies."})

func _reset_and_lifecycle() -> void:
	var f := _fixture("composed fixture reset pause removal and rebind")
	_floor(f)
	var a := _actor(f,Vector2(0,100),true,true)
	await _seconds(0.2)
	a.body.set_intent(1)
	await _seconds(0.4)
	_check(not _events(f,&"enemy_step").is_empty(),"actual inherited footstep NPC fixture emits during the original motor's movement")
	var before: int = f.events.size()
	a.body.apply_pause(0.3)
	await _seconds(0.25)
	_check(f.events.size()==before,"composed hit-pause does not reuse stale floor contacts")
	a.body.reset_at(Vector2(1000,100))
	a.body.set_intent(0)
	await _seconds(0.2)
	_check(f.events.size()==before,"composed teleport reset clears stride and landing history")
	a.source.enabled = false
	a.body.set_intent(1)
	await _seconds(0.5)
	_check(f.events.size()==before,"disabled source leaves moving motor silent")
	a.source.enabled = true
	a.body.set_intent(0)
	await _seconds(0.15)
	_check(f.events.size()==before,"reenabling after unobserved travel creates no distance catch-up burst")
	a.source.simulation_enabled = false
	a.body.set_intent(1)
	await _seconds(0.3)
	a.source.simulation_enabled = true
	a.body.set_intent(0)
	await _seconds(0.15)
	_check(f.events.size()==before,"simulation pause/resume discards unobserved motion")
	a.source.unbind()
	a.body.set_intent(1)
	await _seconds(0.3)
	_check(f.events.size()==before,"unbind leaves no bus route while motor continues")
	_check(a.source.bind_body(a.body,f.bus),"same source can bind again to the explicit local bus")
	a.body.set_intent(0)
	await _seconds(0.15)
	_check(f.events.size()==before,"rebind begins a fresh history without teleport or distance noise")
	a.body.set_intent(1)
	await _seconds(0.3)
	_check(f.events.size()>before,"ordinary own travel emits again after rebind")
	before = f.events.size()
	a.source.queue_free()
	await _seconds(0.4)
	_check(f.events.size()==before and a.body.velocity.x>100,"freeing detachable source leaves motor movement intact and silent")
	_verify(f)
	await _done(f)

func _bus_invalidation() -> void:
	for action in ["reset","diagnostics_reset","disable","pause","tree_pause","unbind","rebind","free","detach","bus_free"]:
		var f := _fixture("real bus callback invalidates receipt: "+action)
		_floor(f)
		var a := _actor(f)
		await _seconds(0.2)
		var second_bus := BUS.new()
		f.world.add_child(second_bus)
		f.bus.noise_emitted.connect(func(_origin, _kind, _loudness, _body):
			if not is_instance_valid(a.source): return
			match action:
				"reset": a.source.reset_history()
				"diagnostics_reset": a.source.reset_diagnostics()
				"disable": a.source.enabled = false
				"pause": a.source.simulation_enabled = false
				"tree_pause": paused = true
				"unbind": a.source.unbind()
				"rebind": a.source.bind_body(a.body,second_bus)
				"free": a.source.queue_free()
				"detach": a.body.remove_child(a.source)
				"bus_free": f.bus.queue_free()
		)
		a.body.set_intent(1)
		await _until(func(): return not f.events.is_empty(),0.5)
		a.skip = true
		paused = false
		_check(not f.events.is_empty(),"real own travel reaches and emits the bus callback")
		_check(f.receipts.is_empty(),"callback invalidation suppresses the now-stale post-bus receipt")
		if action=="detach" and is_instance_valid(a.source): a.source.free()
		await _done(f)

func _trajectory_parity() -> void:
	var f := _fixture("original vs composed present removed trajectory parity")
	_floor(f)
	var plain := _actor(f,Vector2(0,100),false)
	var composed := _actor(f,Vector2(0,100),true,true)
	var max_position_error := 0.0
	var max_velocity_error := 0.0
	var same_state := true
	for frame in range(hz*3):
		var direction := 1.0 if frame<hz else -1.0
		var jump := frame==int(hz*0.6)
		var release := frame==int(hz*0.75)
		plain.body.set_intent(direction,jump,release,false,not release)
		composed.body.set_intent(direction,jump,release,false,not release)
		if frame==int(hz*1.5):
			plain.body.apply_pause(0.13)
			composed.body.apply_pause(0.13)
		if frame==hz*2: composed.source.queue_free()
		await _tick()
		max_position_error = maxf(max_position_error,plain.body.position.distance_to(composed.body.position))
		max_velocity_error = maxf(max_velocity_error,plain.body.velocity.distance_to(composed.body.velocity))
		same_state = same_state and plain.body.state==composed.body.state and plain.body.facing==composed.body.facing
	_check(max_position_error<0.001 and max_velocity_error<0.001 and same_state,"all identical input ticks preserve original motor position velocity facing and state with source present or freed")
	_check(not _events(f,&"enemy_step").is_empty() and not _events(f,&"enemy_land").is_empty(),"parity run includes actual step and landing emissions before removal")
	_verify(f)
	await _done(f,{"max_position_error":max_position_error,"max_velocity_error":max_velocity_error,"identical_state_and_facing":same_state})

func _contract_tokens() -> void:
	var f := _fixture("labelled contract failures: synthetic stale tokens and copies")
	_floor(f)
	var a := _actor(f)
	await _seconds(0.2)
	a.body.set_intent(1)
	await _seconds(0.3)
	a.skip = true
	var before: int = f.events.size()
	var token: int = a.source.begin_motion_sample(dt,true)
	a.source.reset_history()
	a.source.capture_landing(500)
	a.source.finish_motion_sample(token,true)
	a.source.finish_motion_sample(token,true)
	_check(f.events.size()==before,"synthetic stale/duplicate token after reset cannot emit")
	token = a.source.begin_motion_sample(dt,true)
	await _tick()
	a.source.capture_landing(500)
	a.source.finish_motion_sample(token,true)
	_check(f.events.size()==before,"synthetic token crossing a physics frame is rejected")
	a.source.capture_landing(500)
	a.source.finish_motion_sample(-1,true)
	_check(f.events.size()==before,"synthetic capture outside a valid host sample and unknown token cannot emit")
	var snapshot: Dictionary = a.source.debug_snapshot()
	var original: Dictionary = snapshot.duplicate(true)
	if snapshot.has("last_event") and not snapshot.last_event.is_empty(): snapshot.last_event.origin = Vector2(-99999,-99999)
	if snapshot.has("recent_receipts"): snapshot.recent_receipts.clear()
	var again: Dictionary = a.source.debug_snapshot()
	_check(again==original,"mutating returned diagnostic copies cannot change retained source state")
	var duplicate := SOURCE.instantiate()
	a.body.add_child(duplicate)
	_check(not duplicate.bind_body(a.body,f.bus),"second source cannot register duplicate emissions for the same body")
	duplicate.free()
	_verify(f)
	await _done(f,{"synthetic_calls":"Only stale/unknown token, capture-without-sample, and copy/registration failure paths. Physical cadence and landing evidence elsewhere uses real motor movement."})
