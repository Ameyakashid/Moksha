extends SceneTree
## M16: independent direct-state oracle and actual Godot collisions only.
const BUS = preload("res://scripts/sensory/noise_bus.gd")
const PROBE = preload("res://combat_pc/tests/contact_noise_physics_probe.gd")
const SURFACE = preload("res://combat_pc/components/surface_pulse.tscn")
var SENSOR: PackedScene
var hz := 60
var dt := 1.0 / 60.0
var checks: Array = []
var failures: Array = []
var scenarios: Array = []
var label := ""
var check_start := 0
var total_ticks := 0
var hashes := {}
var adapter_hashes := {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
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
	await _tick(ceili(seconds / dt))

func _until(predicate: Callable, seconds := 2.0) -> bool:
	for _i in ceili(seconds / dt):
		await _tick()
		if predicate.call(): return true
	return false

func _fixture(case_name: String) -> Dictionary:
	label = case_name
	check_start = checks.size()
	var world := Node2D.new()
	world.name = "ContactNoiseWorld"
	root.add_child(world)
	var bus := BUS.new()
	world.add_child(bus)
	var f := {"world":world,"bus":bus,"events":[],"receipts":[],"probes":{},"sensors":[],"bodies":[],"surface":null}
	bus.noise_emitted.connect(func(origin: Vector2, kind: StringName, loudness: float, source: Node):
		f.events.append({"origin":origin,"kind":kind,"loudness":loudness,"source_id":source.get_instance_id(),"physics_frame":Engine.get_physics_frames()}))
	return f

func _shape(parent: Node2D, size: Vector2, offset := Vector2.ZERO) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	shape.position = offset
	parent.add_child(shape)
	return shape

func _static(f: Dictionary, position_: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position_
	_shape(body,size)
	f.world.add_child(body)
	return body

func _rigid(f: Dictionary, position_: Vector2, velocity := Vector2.ZERO, size := Vector2(20,20), bounce := 0.0, gravity := 0.0, instrument := true) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = position_
	body.gravity_scale = gravity
	body.linear_damp = 0
	body.angular_damp = 0
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.lock_rotation = true
	body.linear_velocity = velocity
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0
	body.physics_material_override.bounce = bounce
	_shape(body,size)
	f.world.add_child(body)
	f.bodies.append(body)
	var probe := PROBE.new()
	probe.body = body
	body.add_child(probe)
	f.probes[body.get_instance_id()] = probe
	if instrument: _sensor(f,body)
	return body

func _sensor(f: Dictionary, body: RigidBody2D) -> Node:
	var sensor := SENSOR.instantiate()
	body.add_child(sensor)
	sensor.impact_emitted.connect(func(receipt: Dictionary): f.receipts.append(receipt))
	_check(sensor.bind_body(body,f.bus),"explicit live rigid body and local bus bind")
	f.sensors.append(sensor)
	return sensor

func _surface(f: Dictionary) -> Node:
	var excluded := Node2D.new()
	f.world.add_child(excluded)
	var surface := SURFACE.instantiate()
	root.add_child(surface)
	surface.set_process(false)
	_check(surface.bind_surface(f.world,excluded,f.bus),"unchanged SurfacePulse binds to local bus")
	f.surface = surface
	return surface

func _verify_receipts(f: Dictionary) -> void:
	var matching := true
	var finite := true
	var readonly := true
	var unique := {}
	var sample_details: Array = []
	for event in f.receipts:
		readonly = readonly and event.is_read_only()
		var key := "%s:%s" % [event.body_id,event.serial]
		matching = matching and not unique.has(key)
		unique[key] = true
		finite = finite and event.origin.is_finite() and event.normal.is_finite() and is_finite(event.closing_speed) and is_finite(event.loudness)
		finite = finite and absf(event.normal.length()-1.0)<0.0001 and event.closing_speed>=85.0
		var oracle: Dictionary = {}
		if f.probes.has(event.body_id):
			for sample in f.probes[event.body_id].samples.get(event.physics_frame,[]):
				if sample.collider_id == event.collider_id and sample.local_shape == event.local_shape and sample.collider_shape == event.collider_shape and sample.origin.distance_to(event.origin)<0.001 and absf(sample.closing_speed-event.closing_speed)<0.001:
					oracle = sample
		matching = matching and not oracle.is_empty()
		if not oracle.is_empty():
			matching = matching and oracle.normal.normalized().distance_to(event.normal)<0.0001
			matching = matching and absf(event.loudness-clampf(event.closing_speed/240.0,0.45,1.9))<0.0001
			sample_details.append({"receipt":event,"oracle":oracle})
	_check(matching,"every receipt exactly matches an independent same-frame direct-state contact position normal velocities and loudness")
	_check(finite and readonly,"receipts are finite immutable normalized scalar snapshots")
	var bus_match: bool = f.events.size() == f.receipts.size()
	for event in f.receipts:
		var count := 0
		for delivered in f.events:
			if delivered.source_id == event.body_id and delivered.origin == event.origin and delivered.loudness == event.loudness and delivered.kind == &"prop_impact" and delivered.physics_frame == event.physics_frame: count += 1
		bus_match = bus_match and count == 1
	_check(bus_match,"one local bus prop_impact precedes each receipt with identical provenance")
	f["oracle_matches"] = sample_details

func _done(f: Dictionary, details: Dictionary = {}) -> void:
	if f.has("oracle_matches"): details["contact_samples"] = f.oracle_matches
	scenarios.append({"name":label,"checks":checks.slice(check_start),"details":details})
	if is_instance_valid(f.surface): f.surface.free()
	f.world.free()
	await _tick(2)

func _run() -> void:
	SENSOR = load("res://combat_pc/components/physics_contact_noise.tscn")
	if SENSOR == null:
		printerr("Component scene unavailable")
		quit(2)
		return
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://combat_pc/tests/contact_noise_baseline_hashes.json"))
	for record in baseline.files: hashes[record.path] = FileAccess.get_sha256("res://"+record.path)
	for path in ["combat_pc/components/physics_contact_noise.gd","combat_pc/components/physics_contact_noise.tscn","combat_pc/resources/contact_noise_profile.gd","combat_pc/resources/contact_noise_profile.tres","combat_pc/fixtures/contact_noise_prop.gd","combat_pc/fixtures/contact_noise_prop.tscn"]: adapter_hashes[path] = FileAccess.get_sha256("res://"+path)
	await _floor_wall_strength()
	await _prop_pairs()
	await _bounces_rest_sleep()
	await _corner_shapes()
	await _angular_contact()
	await _compound_pairs_and_rotated_surface()
	await _contact_cap()
	await _declarative_binding()
	await _lifecycle_real()
	await _composed_prop()
	await _trajectory_parity()
	await _invalid_inputs()
	var stable := true
	for path in hashes: stable = stable and hashes[path] == FileAccess.get_sha256("res://"+path)
	label = "protected v19 baseline"
	_check(baseline.all_match and stable,"all 21 actor surface relay bus and old prop sources remain byte-for-byte v19")
	var adapters_stable := true
	for path in adapter_hashes: adapters_stable = adapters_stable and adapter_hashes[path]==FileAccess.get_sha256("res://"+path)
	_check(adapters_stable,"component and composed fixture sources remained stable throughout run")
	var report := {"adapter_source_hashes":adapter_hashes,"adapter_sources_stable_during_run":adapters_stable,"milestone":16,"suite":"real physics contact noise","physics_hz":hz,"engine":Engine.get_version_info().string,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"source_hashes":hashes,"protected_sources_unchanged":stable and baseline.all_match,"generated_utc":Time.get_datetime_string_from_system(true),"method":"Actual Godot Physics 2D collisions. Read-only high-priority probe independently captures direct-state contact positions and both contact-point velocity vectors before the component each physics frame. No injected physical receipts. Lifecycle hooks explicitly labeled.","limitations":["Headless physics and retained contour integration; native visual review is separate.","Focused optional adapter; no full NPC/audio/sliding model or broad actor regression.","Receipt geometry uses solver collider contact, including expected penetration tolerance."]}
	FileAccess.open("res://combat_pc/tests/contact_noise_results_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("CONTACT_NOISE_M16 %dHz: %d checks, %d scenarios, %d failures"%[hz,checks.size(),scenarios.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func _floor_wall_strength() -> void:
	var loudnesses: Array = []
	var radii: Array = []
	for speed in [140.0,360.0]:
		var f := _fixture("real floor impact at "+str(speed))
		_static(f,Vector2(0,100),Vector2(1000,20))
		var body := _rigid(f,Vector2(37,0),Vector2(0,speed))
		var surface := _surface(f)
		_check(await _until(func(): return f.receipts.size()>0),"thrown body reaches floor in real physics")
		await _seconds(0.25)
		_check(f.receipts.size()==1,"multi-point floor manifold emits once and resting contact does not chatter")
		_verify_receipts(f)
		if not f.receipts.is_empty():
			var event: Dictionary = f.receipts[0]
			_check(absf(event.origin.y-90.0)<0.01 and absf(event.origin.x-37.0)<=10.01,"origin is on struck floor face and displaced from body root")
			_check(event.origin.distance_to(body.global_position)>5.0,"surface contact origin is never the rigid-body root")
			_check(surface.accepted_event_count==1 and surface.pulses.size()==1 and surface.pulses[0].origin==event.origin,"one actual collision produces one retained contour pulse at original contact")
			var diagnostic_copy: Dictionary = f.sensors[0].last_event
			diagnostic_copy.origin = Vector2(-99999,-99999)
			_check(f.sensors[0].last_event.origin==event.origin,"mutating returned diagnostics cannot alter recorded receipt")
			loudnesses.append(event.loudness)
			radii.append(surface.pulses[0].radius)
		await _done(f,{"loudness":loudnesses.back() if not loudnesses.is_empty() else 0.0,"radius":radii.back() if not radii.is_empty() else 0.0})
	label = "strength comparison"
	_check(loudnesses.size()==2 and loudnesses[1]>loudnesses[0] and radii[1]>radii[0],"stronger physical impact increases both loudness and retained contour range")
	var f := _fixture("real wall impact and tangential sliding")
	_static(f,Vector2(100,0),Vector2(20,1000))
	_rigid(f,Vector2(0,0),Vector2(270,130))
	_check(await _until(func(): return f.receipts.size()>0),"thrown body reaches wall")
	await _seconds(0.5)
	_check(f.receipts.size()==1,"energetic tangential sliding makes no repeated wall impacts")
	if not f.receipts.is_empty(): _check(absf(f.receipts[0].origin.x-90)<0.01,"wall origin lies on struck vertical face")
	_verify_receipts(f)
	await _done(f)

func _prop_pairs() -> void:
	for variant in ["lone emitter lower id","lone emitter higher id","two emitters","both moving"]:
		var f := _fixture("real rigid-body pair "+variant)
		var first := _rigid(f,Vector2(-70,0),Vector2(220,0),Vector2(20,20),0.0,0.0,false)
		var second := _rigid(f,Vector2(70,0),Vector2(-160,0) if variant=="both moving" else Vector2.ZERO,Vector2(20,20),0.0,0.0,false)
		if variant != "lone emitter higher id": _sensor(f,first)
		if variant != "lone emitter lower id": _sensor(f,second)
		_check(await _until(func(): return f.receipts.size()>0),"actual pair contacts produce an event")
		await _seconds(0.35)
		_check(f.receipts.size()==1 and f.events.size()==1,"one physical pair episode produces exactly one bus event across instrumented peers")
		_verify_receipts(f)
		if variant=="both moving" and not f.receipts.is_empty(): _check(absf(f.receipts[0].closing_speed-380.0)<0.01,"closing speed includes the other moving body")
		var observed_contacts := {}
		for id in f.probes:
			var hits := {}
			for frame in f.probes[id].samples:
				if not f.probes[id].samples[frame].is_empty() and (hits.size()<4 or f.probes[id].samples[frame].any(func(sample): return sample.closing_speed>=85)): hits[frame] = f.probes[id].samples[frame]
			observed_contacts[id] = hits
		await _done(f,{"all_contacts":observed_contacts,"snapshots":f.sensors.map(func(sensor): return sensor.debug_snapshot())})

func _bounces_rest_sleep() -> void:
	var f := _fixture("real energetic bounces then settling sleeping and stale wake")
	_static(f,Vector2(0,180),Vector2(1000,20))
	var body := _rigid(f,Vector2(0,0),Vector2(0,100),Vector2(20,20),0.68,1.0)
	await _seconds(6.0)
	_check(f.receipts.size()>=3,"separated repeated energetic floor bounces each produce new episodes")
	var count: int = f.receipts.size()
	await _seconds(2.0)
	_check(f.receipts.size()==count,"settled floor contact has no sustained chatter")
	_check(body.sleeping,"resting body reaches actual engine sleep")
	_verify_receipts(f)
	var bounce_events: Array = f.receipts.duplicate(true)
	body.sleeping = false
	await _seconds(0.4)
	_check(f.receipts.size()==count,"waking a resting body cannot replay cached sleeping contact samples")
	body.apply_central_impulse(Vector2(0,-400)*body.mass)
	_check(await _until(func(): return f.receipts.size()>count,2.0),"fresh real re-impact after wake emits normally")
	await _done(f,{"bounces_before_wake":bounce_events,"total_events":f.receipts.size()})

func _corner_shapes() -> void:
	var f := _fixture("simultaneous floor wall shapes on one static body")
	var corner := StaticBody2D.new()
	_shape(corner,Vector2(1000,20),Vector2(0,100))
	_shape(corner,Vector2(20,1000),Vector2(100,0))
	f.world.add_child(corner)
	_rigid(f,Vector2.ZERO,Vector2(250,250))
	_check(await _until(func(): return f.receipts.size()>=2),"independent floor and wall contacts both emit")
	await _seconds(0.3)
	var shapes := {}
	var frames := {}
	for event in f.receipts:
		shapes[event.collider_shape] = true
		frames[event.physics_frame] = true
	_check(f.receipts.size()==2 and shapes.size()==2 and frames.size()==1,"same-body shapes retain distinct same-frame episodes without global cooldown masking")
	_verify_receipts(f)
	await _done(f)

func _angular_contact() -> void:
	var f := _fixture("angular contact-point velocity with stationary center")
	_static(f,Vector2(0,90),Vector2(1000,20))
	var body := _rigid(f,Vector2(0,55),Vector2.ZERO,Vector2(100,8))
	body.lock_rotation = false
	body.rotation = -0.4
	body.angular_velocity = 9.0
	_check(await _until(func(): return f.receipts.size()>0),"rotating rod reaches floor without initial linear motion")
	if not f.receipts.is_empty():
		var event: Dictionary = f.receipts[0]
		var rotational_difference := false
		for sample in f.probes[event.body_id].samples.get(event.physics_frame,[]):
			if sample.origin.distance_to(event.origin)<0.001: rotational_difference = absf(event.closing_speed-maxf(0.0,-(sample.linear_velocity-sample.collider_velocity).dot(event.normal)))>30.0
		_check(rotational_difference,"angular point motion changes closing speed from center-of-mass-only estimate")
	_verify_receipts(f)
	await _done(f)

func _compound_pairs_and_rotated_surface() -> void:
	var f := _fixture("two instrumented compound props with two shape pairs")
	var first := _rigid(f,Vector2(-60,0),Vector2(250,0))
	var second := _rigid(f,Vector2(60,0),Vector2(-100,0))
	for body in [first,second]:
		body.get_child(0).position.y = -25
		_shape(body,Vector2(20,20),Vector2(0,25))
	_check(await _until(func(): return f.events.size()>=2),"both separated shape pairs collide physically")
	await _seconds(0.2)
	var pairs := {}
	for event in f.receipts: pairs[str(event.local_shape)+":"+str(event.collider_shape)] = true
	_check(f.events.size()==2 and pairs.size()==2,"symmetric arbitration keeps two shape pairs and suppresses both peer duplicates")
	_verify_receipts(f)
	await _done(f)
	f = _fixture("rotated translated collider world contact provenance")
	var surface := _static(f,Vector2(120,70),Vector2(20,600))
	surface.rotation = 0.28
	_rigid(f,Vector2(-40,70),Vector2(330,0))
	_check(await _until(func(): return f.events.size()>0),"actual throw reaches transformed surface")
	if not f.receipts.is_empty():
		var local_point: Vector2 = surface.to_local(f.receipts[0].origin)
		_check(absf(local_point.x+10.0)<0.01,"world contact converts exactly onto rotated collider face")
	_verify_receipts(f)
	await _done(f)
	f = _fixture("stationary instrumented body struck by rotating other body")
	var rod := _rigid(f,Vector2(0,10),Vector2.ZERO,Vector2(120,8),0,0,false)
	rod.lock_rotation = false
	rod.rotation = -0.3
	rod.angular_velocity = 8.0
	var target := _rigid(f,Vector2(48,52),Vector2.ZERO,Vector2(20,20),0,0,true)
	_check(await _until(func(): return f.events.size()>0,0.4),"rotating uninstrumented prop strikes stationary instrumented target")
	if not f.receipts.is_empty():
		var receipt: Dictionary = f.receipts[0]
		_check(receipt.body_id==target.get_instance_id() and receipt.collider_velocity.length()>85.0,"other body's angular point velocity contributes to target closing speed")
	_verify_receipts(f)
	await _done(f)

func _declarative_binding() -> void:
	var f := _fixture("declarative optional child explicit bus path")
	f.bus.name = "LocalNoiseBus"
	_static(f,Vector2(100,0),Vector2(20,1000))
	var body := _rigid(f,Vector2.ZERO,Vector2(260,0),Vector2(20,20),0,0,false)
	var sensor := SENSOR.instantiate()
	sensor.event_bus_path = NodePath("../../LocalNoiseBus")
	sensor.impact_emitted.connect(func(receipt: Dictionary): f.receipts.append(receipt))
	body.add_child(sensor)
	_check(sensor.debug_snapshot().bound,"default parent-body path and explicit bus path bind during ready")
	_check(await _until(func(): return f.events.size()>0),"declaratively composed child observes actual body impact")
	_verify_receipts(f)
	await _done(f)

func _contact_cap() -> void:
	var f := _fixture("real finite contact reporting cap")
	var corner := StaticBody2D.new()
	_shape(corner,Vector2(1000,20),Vector2(0,100))
	_shape(corner,Vector2(20,1000),Vector2(100,0))
	f.world.add_child(corner)
	var body := _rigid(f,Vector2.ZERO,Vector2(250,250),Vector2(20,20),0,0,false)
	var sensor := SENSOR.instantiate()
	sensor.profile = sensor.profile.duplicate(true)
	sensor.profile.max_contacts_reported = 1
	body.add_child(sensor)
	sensor.impact_emitted.connect(func(receipt: Dictionary): f.receipts.append(receipt))
	sensor.bind_body(body,f.bus)
	_check(await _until(func(): return f.events.size()>0),"real corner collision reports through capped buffer")
	_check(body.max_contacts_reported==1 and sensor.debug_snapshot().capacity_reached_count>0,"capacity saturation is explicitly observable; unreported contacts are not synthesized")
	_check(f.receipts.size()==1 and f.receipts[0].contact_count==1,"one-slot reporting produces one measured contact receipt")
	_verify_receipts(f)
	await _done(f,{"snapshot":sensor.debug_snapshot()})

func _lifecycle_real() -> void:
	for mode in ["fresh host spawn","existing host reset"]:
		var f := _fixture("known pre-step first-impact "+mode)
		_static(f,Vector2(100,0),Vector2(20,1000))
		var body: RigidBody2D
		if mode=="existing host reset":
			body = _rigid(f,Vector2(-300,-200))
			await _tick(4)
		await physics_frame
		if mode=="fresh host spawn":
			body = _rigid(f,Vector2(79,0),Vector2(600,0))
			f.sensors[0].reset_contact_history(true)
		else:
			f.sensors[0].reset_contact_history(true)
			body.position = Vector2(79,0)
			PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0.0,Vector2(79,0)))
			body.linear_velocity = Vector2(600,0)
			body.sleeping = false
		await process_frame
		await _tick(4)
		_check(f.events.size()==1,"known pre-solver reset admits first subsequent solver contact")
		_verify_receipts(f)
		await _done(f)
	for side in ["floor","wall"]:
		var f := _fixture("first completed physics-step fresh "+side+" impact")
		if side=="floor": _static(f,Vector2(0,100),Vector2(1000,20))
		else: _static(f,Vector2(100,0),Vector2(20,1000))
		_rigid(f,Vector2(0,79) if side=="floor" else Vector2(79,0),Vector2(0,600) if side=="floor" else Vector2(600,0))
		await _tick(5)
		_check(f.events.size()==1,"freshly bound near-surface throw emits its first real collision")
		_verify_receipts(f)
		await _done(f)
	for operation in ["disable","simulation pause","unbind","detach","history reset","rebind","free emitter","free body","free bus","free collider","sleep body","freeze body","tree pause"]:
		var f := _fixture("real pending receipt retired by "+operation)
		var wall := _static(f,Vector2(100,0),Vector2(20,1000))
		var body := _rigid(f,Vector2.ZERO,Vector2(260,0))
		var sensor: Node = f.sensors[0]
		var replacement := _rigid(f,Vector2(-500,-200),Vector2.ZERO,Vector2(20,20),0,0,false)
		var hook := PROBE.new()
		hook.body = body
		f.world.add_child(hook)
		hook.process_physics_priority = 100000
		f["triggered"] = false
		hook.on_sample = func(_contacts: Array,_frame: int):
			if f.triggered or sensor.debug_snapshot().pending_count==0: return
			f.triggered = true
			hook.on_sample = Callable()
			match operation:
				"disable": sensor.enabled = false
				"simulation pause": sensor.simulation_enabled = false
				"unbind": sensor.unbind()
				"detach": body.remove_child(sensor)
				"history reset":
					sensor.reset_contact_history()
					body.position = Vector2(-400,-300)
					body.force_update_transform()
					body.linear_velocity = Vector2.ZERO
				"rebind": sensor.bind_body(replacement,f.bus)
				"free emitter": sensor.free()
				"free body": body.free()
				"free bus": f.bus.free()
				"free collider": wall.free()
				"sleep body": body.sleeping = true
				"freeze body": body.freeze = true
				"tree pause": paused = true
		_check(await _until(func(): return f.triggered),"real contact was sampled and queued before lifecycle operation")
		await _tick(5)
		_check(f.events.is_empty() and f.receipts.is_empty(),"invalidated deferred contact never reaches bus or receipt observers")
		paused = false
		if operation=="detach": sensor.free()
		await _done(f)
	for operation in ["unbind emitter","rebind emitter","free emitter","free peer","reset diagnostics","reset history"]:
		var f := _fixture("pair bus callback "+operation)
		var first := _rigid(f,Vector2(-60,0),Vector2(250,0))
		var second := _rigid(f,Vector2(60,0),Vector2(-100,0))
		var replacement := _rigid(f,Vector2(-500,-200),Vector2.ZERO,Vector2(20,20),0,0,false)
		f["triggered"] = false
		var callback := func(_origin: Vector2,_kind: StringName,_loudness: float,source: Node):
			if f.triggered: return
			f.triggered = true
			var emitter: Node = f.sensors[0] if source==first else f.sensors[1]
			var peer: Node = f.sensors[1] if source==first else f.sensors[0]
			match operation:
				"unbind emitter": emitter.unbind()
				"rebind emitter": emitter.bind_body(replacement,f.bus)
				"free emitter": emitter.queue_free()
				"free peer": peer.free()
				"reset diagnostics": emitter.reset_diagnostics()
				"reset history": emitter.reset_contact_history()
		f.bus.noise_emitted.connect(callback)
		_check(await _until(func(): return f.triggered),"actual paired collision reaches callback")
		await _seconds(0.3)
		_check(f.events.size()==1,"shared pair claim survives callback mutation without duplicate bus event")
		_check(f.receipts.size()<=1,"callback retirement cannot deliver duplicate stale receipts")
		await _done(f)
	var f := _fixture("pause resume and diagnostics on live physical observer")
	_static(f,Vector2(0,100),Vector2(1000,20))
	var body := _rigid(f,Vector2.ZERO,Vector2(0,240))
	var sensor: Node = f.sensors[0]
	_check(await _until(func(): return f.events.size()==1),"first actual floor impact emits")
	await _seconds(0.2)
	sensor.reset_diagnostics()
	_check(sensor.emitted_count==0 and sensor.last_event.is_empty() and sensor.recent_receipts.is_empty(),"diagnostic reset clears diagnostics without rearming physical episode")
	await _seconds(0.2)
	_check(f.events.size()==1,"diagnostic reset does not replay settled contact")
	paused = true
	var position_: Vector2 = body.position
	await _tick(8)
	_check(body.position==position_ and f.events.size()==1,"SceneTree pause freezes physical motion and event intake")
	paused = false
	await _tick(5)
	_check(f.events.size()==1,"SceneTree resume does not replay prior contact")
	sensor.simulation_enabled = false
	sensor.reset_contact_history()
	body.position = Vector2(0,-100)
	body.force_update_transform()
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0.0,Vector2(0,-100)))
	body.linear_velocity = Vector2(0,400)
	body.sleeping = false
	await _seconds(0.8)
	_check(f.events.size()==1 and body.position.y>50,"local emission pause preserves independent physical simulation")
	sensor.simulation_enabled = true
	await _tick(5)
	_check(f.events.size()==1,"local resume does not replay paused impact")
	sensor.reset_contact_history()
	body.position = Vector2(0,-100)
	body.force_update_transform()
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0.0,Vector2(0,-100)))
	body.linear_velocity = Vector2(0,400)
	body.sleeping = false
	_check(await _until(func(): return f.events.size()==2),"fresh reset then real collision after resume emits normally")
	await _done(f,{"snapshot":sensor.debug_snapshot(),"body_position":body.position,"body_velocity":body.linear_velocity,"body_sleeping":body.sleeping,"events":f.events})

func _composed_prop() -> void:
	var f := _fixture("actual composed reusable prop fixture")
	_static(f,Vector2(140,0),Vector2(20,1000))
	var body = load("res://combat_pc/fixtures/contact_noise_prop.tscn").instantiate()
	body.position = Vector2.ZERO
	f.world.add_child(body)
	body.gravity_scale = 0
	body.linear_damp = 0
	body.angular_damp = 0
	body.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	body.lock_rotation = true
	body.linear_velocity = Vector2(280,0)
	body.collision_mask = 1
	var probe := PROBE.new()
	probe.body = body
	body.add_child(probe)
	f.probes[body.get_instance_id()] = probe
	var sensor = body.get_node("ImpactNoise")
	sensor.impact_emitted.connect(func(receipt: Dictionary): f.receipts.append(receipt))
	_check(sensor.bind_body(body,f.bus),"composed scene explicitly binds its optional child")
	var autoload_before: int = root.get_node("NoiseBus").event_count
	_check(await _until(func(): return f.receipts.size()>0),"actual inherited prop reaches wall and emits")
	await _seconds(0.2)
	_check(f.events.size()==1 and root.get_node("NoiseBus").event_count==autoload_before,"composed prop has one local route with no legacy autoload duplicate")
	_verify_receipts(f)
	await _done(f)

func _trajectory_parity() -> void:
	var paths := {}
	for mode in ["absent","attached","removed","removed midflight","removed after contact"]:
		var f := _fixture("physical trajectory "+mode)
		_static(f,Vector2(0,160),Vector2(1000,20))
		_static(f,Vector2(200,0),Vector2(20,1000))
		var body := _rigid(f,Vector2(0,0),Vector2(140,0),Vector2(20,20),0.55,1.0,mode!="absent")
		body.lock_rotation = false
		body.angular_velocity = 2.3
		if mode=="removed": f.sensors[0].free()
		if mode=="removed midflight" or mode=="removed after contact":
			var removal_tick := ceili((0.2 if mode=="removed midflight" else 0.7)/dt)
			await _tick(removal_tick)
			f.sensors[0].free()
			await _tick(ceili(2.0/dt)-removal_tick)
		else: await _seconds(2.0)
		paths[mode] = f.probes[body.get_instance_id()].trajectory.duplicate(true)
		await _done(f)
	label = "component physical trajectory parity"
	var max_position_error := 0.0
	var max_velocity_error := 0.0
	var max_rotation_error := 0.0
	var max_spin_error := 0.0
	for mode in ["attached","removed","removed midflight","removed after contact"]:
		_check(paths[mode].size()==paths.absent.size(),mode+" and absent trajectories have equal real sample counts")
		for index in mini(paths[mode].size(),paths.absent.size()):
			max_position_error = maxf(max_position_error,paths[mode][index].position.distance_to(paths.absent[index].position))
			max_velocity_error = maxf(max_velocity_error,paths[mode][index].velocity.distance_to(paths.absent[index].velocity))
			max_rotation_error = maxf(max_rotation_error,absf(paths[mode][index].rotation-paths.absent[index].rotation))
			max_spin_error = maxf(max_spin_error,absf(paths[mode][index].angular_velocity-paths.absent[index].angular_velocity))
	_check(max_position_error<=0.001 and max_velocity_error<=0.001 and max_rotation_error<=0.00001 and max_spin_error<=0.00001,"optional attachment/removal preserves solver trajectory within 0.001 world units")
	scenarios.append({"name":label,"max_position_error":max_position_error,"max_velocity_error":max_velocity_error,"max_rotation_error":max_rotation_error,"max_spin_error":max_spin_error,"samples_per_trajectory":paths.absent.size()})

func _invalid_inputs() -> void:
	var f := _fixture("invalid binding tuning capacity ownership and diagnostics copies")
	var body := _rigid(f,Vector2.ZERO,Vector2.ZERO,Vector2(20,20),0,0,false)
	var sensor := SENSOR.instantiate()
	body.add_child(sensor)
	_check(sensor.body_path==NodePath("..") and sensor.event_bus_path.is_empty() and not sensor.debug_snapshot().bound,"optional default never finds an autoload bus")
	var detached := RigidBody2D.new()
	var invalid_bus := Node.new()
	f.world.add_child(invalid_bus)
	_check(not sensor.bind_body(null,f.bus) and not sensor.bind_body(detached,f.bus) and not sensor.bind_body(body,invalid_bus) and not sensor.bind_body(body,null),"null detached and incompatible bindings are rejected")
	detached.free()
	var foreign_view := SubViewport.new()
	foreign_view.world_2d = World2D.new()
	root.add_child(foreign_view)
	var foreign_body := RigidBody2D.new()
	var foreign_bus := BUS.new()
	foreign_view.add_child(foreign_body)
	foreign_view.add_child(foreign_bus)
	_check(not sensor.bind_body(foreign_body,foreign_bus) and not sensor.bind_body(body,foreign_bus),"different World2D body and bus bindings are rejected")
	foreign_view.free()
	_check(sensor.bind_body(body,f.bus) and body.max_contacts_reported==16 and body.contact_monitor,"default explicit binding declares 16-contact reporting capacity")
	var epoch: int = sensor.debug_snapshot().epoch
	for _i in 3: sensor.bind_body(body,f.bus)
	_check(sensor.debug_snapshot().epoch==epoch,"repeated same-body same-bus binding is idempotent")
	var duplicate := SENSOR.instantiate()
	body.add_child(duplicate)
	_check(not duplicate.bind_body(body,f.bus),"duplicate observer cannot bind the same body")
	duplicate.free()
	sensor.unbind()
	_check(not body.contact_monitor and body.max_contacts_reported==0,"unbind restores reporting settings owned by observer")
	body.contact_monitor = true
	body.max_contacts_reported = 32
	sensor.bind_body(body,f.bus)
	sensor.unbind()
	_check(body.contact_monitor and body.max_contacts_reported==32,"host-provided reporting settings survive attach and detach")
	sensor.bind_body(body,f.bus)
	sensor.profile = sensor.profile.duplicate(true)
	for field in ["minimum_closing_speed","loudness_speed_scale","minimum_loudness","maximum_loudness","quiet_closing_speed","quiet_rearm_seconds","separation_rearm_seconds"]:
		var original = sensor.profile.get(field)
		for value in [NAN,INF,-1.0]:
			sensor.profile.set(field,value)
			_check(not sensor._valid_tuning(),"invalid "+field+" rejects emission policy")
		sensor.profile.set(field,original)
	sensor.profile.kind = &""
	_check(not sensor._valid_tuning(),"empty event kind is rejected")
	sensor.profile = null
	_check(sensor._valid_tuning(),"null profile safely uses authored defaults")
	sensor.unbind()
	body.max_contacts_reported = 0
	sensor.profile = load("res://combat_pc/resources/contact_noise_profile.tres").duplicate(true)
	sensor.profile.max_contacts_reported = 100000
	sensor.bind_body(body,f.bus)
	_check(body.max_contacts_reported==128,"reporting capacity clamps at documented hard cap of 128")
	await _done(f)
