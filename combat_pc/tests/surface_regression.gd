extends "res://combat_pc/tests/noise_regression.gd"
## M15: optional local-bus surface adapter; real actor integration and contour probes.
const SURFACE = preload("res://combat_pc/components/surface_pulse.tscn")
const SURFACE_SOURCES = ["res://combat_pc/components/surface_pulse.gd", "res://combat_pc/components/surface_pulse.tscn", "res://combat_pc/resources/surface_pulse_default.tres", "res://scripts/sensory/sonar_view.gd", "res://scripts/sensory/sonar_geometry.gd", "res://scripts/sensory/sonar_canvas.gd"]
var surface: Node
var measurements := {}

func _run() -> void:
	for path in NOISE_SOURCES + SURFACE_SOURCES: hashes[path] = FileAccess.get_sha256(path)
	_contour_arrivals()
	_geometry_lifetime()
	_source_scope()
	_pause_and_binding()
	_dependency_retirement()
	_callback_retirement()
	await _contour_only_rendering()
	await _real_relay_events()
	await _surface_motor_parity()
	var stable := true
	for path in hashes: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable,"production sources stayed unchanged during focused run")
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://combat_pc/tests/surface_baseline_hashes.json"))
	_check(baseline.get("all_match",false),"motor Health Defeat NoiseRelay and retained contour engine match v18 backup byte-for-byte")
	var report := {"milestone":15,"suite":"surface pulse adapter","physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"measurements":measurements,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"v18_baseline_all_match":baseline.get("all_match",false),"engine":Engine.get_version_info().string,"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Actual reusable PC movement/strike and unchanged NoiseRelay driven once per real physics callback; local-bus contour tests use real collision bodies and deterministic simulation advancement.","limitations":["Headless draw-command and collision/contract checks; native visual QA belongs to parent","No broad level, blindness, NPC, audio or full motor retesting"]}
	FileAccess.open("res://combat_pc/tests/surface_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("SURFACE_M15 %dHz: %d checks, %d scenarios, %d failures" % [hz,checks.size(),scenarios.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _fixture(case_name: String, bind_now := true) -> Dictionary:
	label = case_name
	scenario_check_start = checks.size()
	var scope := Node2D.new()
	root.add_child(scope)
	var excluded := Node2D.new()
	scope.add_child(excluded)
	var local_bus: Node = BUS.new()
	scope.add_child(local_bus)
	var overlay: Node = SURFACE.instantiate()
	overlay.tuning = overlay.tuning.duplicate(true)
	root.add_child(overlay)
	overlay.set_process(false)
	if bind_now: _check(overlay.bind_surface(scope,excluded,local_bus),"explicit live world actor and local bus bind")
	return {"world":scope,"actor":excluded,"bus":local_bus,"surface":overlay}

func _box_in(parent: Node, at: Vector2, size: Vector2, moving := false) -> CollisionShape2D:
	var body: PhysicsBody2D = RigidBody2D.new() if moving else StaticBody2D.new()
	if moving: body.freeze = true
	body.position = at
	parent.add_child(body)
	var collider := CollisionShape2D.new()
	collider.shape = RectangleShape2D.new()
	collider.shape.size = size
	body.add_child(collider)
	return collider

func _fixture_done(f: Dictionary, details: Dictionary = {}) -> void:
	scenarios.append({"name":label,"assertions":checks.slice(scenario_check_start),"measurements":details})
	if is_instance_valid(f.surface): f.surface.free()
	if is_instance_valid(f.world): f.world.free()

func _noise(f: Dictionary, origin := Vector2.ZERO, kind: StringName = &"weapon_tap") -> void:
	f.bus.emit_noise(origin,kind,1.0,f.actor)

func _contour_arrivals() -> void:
	var f := _fixture("near far arrival corner progression overlap and silence")
	_box_in(f.world,Vector2(0,100),Vector2(120,40))
	_box_in(f.world,Vector2(0,300),Vector2(120,40))
	f.surface.refresh_geometry()
	_noise(f)
	var near_point := Vector2(0,80)
	var far_point := Vector2(0,280)
	var near_sample: Dictionary = f.surface.debug_sample(near_point)
	var far_sample: Dictionary = f.surface.debug_sample(far_point)
	var near_arrival: float = near_sample.arrival_times[0].arrival
	var far_arrival: float = far_sample.arrival_times[0].arrival
	_check(near_arrival < far_arrival and near_sample.alpha == 0 and far_sample.alpha == 0,"surfaces wait for their own distance-dependent arrival")
	f.surface.advance_simulation(near_arrival+0.01)
	_check(f.surface.debug_sample(near_point).alpha > 0.5 and f.surface.debug_sample(far_point).alpha == 0,"near face lights while farther face remains absent")
	f.surface.advance_simulation(far_arrival-near_arrival)
	_check(f.surface.debug_sample(far_point).alpha > 0.3,"far face arrives later at its scheduled time")
	_check(not f.surface.debug_sample(Vector2(0,40),1.0).on_geometry and f.surface.debug_sample(Vector2(0,40),1.0).alpha == 0,"empty space has zero contour contribution")
	f.surface.clear_pulses()
	_noise(f,Vector2(0,0))
	var corner_points := [Vector2(0,80),Vector2(60,100),Vector2(0,120)]
	var arrivals: Array[float] = []
	for point in corner_points: arrivals.append(f.surface.debug_sample(point).arrival_times[0].arrival)
	_check(arrivals[0] < arrivals[1] and arrivals[1] < arrivals[2],"wave progresses from top through side corner onto underside")
	f.surface.advance_simulation(arrivals[0]+0.01)
	_check(f.surface.debug_sample(corner_points[0]).alpha > 0 and f.surface.debug_sample(corner_points[2]).alpha == 0,"first contact reveals fragments before the underside")
	f.surface.advance_simulation(arrivals[2]-arrivals[0])
	_check(f.surface.debug_sample(corner_points[2]).alpha > 0,"contour wraps onto underside")
	f.surface.clear_pulses()
	_noise(f)
	_noise(f,Vector2(20,0),&"prop_impact")
	var overlap_sample: Dictionary = f.surface.debug_sample(near_point)
	f.surface.advance_simulation(maxf(overlap_sample.arrival_times[0].arrival,overlap_sample.arrival_times[1].arrival)+0.015)
	overlap_sample = f.surface.debug_sample(near_point)
	_check(overlap_sample.sources.size() == 2 and overlap_sample.alpha > overlap_sample.sources[0].alpha and overlap_sample.alpha <= 1,"independent overlapping pulses add and clamp without replacing each other")
	_check(f.surface.pulses[0].origin == Vector2.ZERO and f.surface.pulses[1].origin == Vector2(20,0),"each pulse retains its immutable emission origin")
	f.surface.advance_simulation(10.0)
	_check(f.surface.pulses.is_empty() and f.surface.debug_snapshot().active_geometry_segments == 0 and f.surface.debug_sample(near_point).alpha == 0,"silence expires pulses and all surface alpha to zero")
	measurements.arrivals = {"near_seconds":near_arrival,"far_seconds":far_arrival,"top_side_bottom_seconds":arrivals}
	_fixture_done(f,measurements.arrivals)

func _geometry_lifetime() -> void:
	var f := _fixture("transformed moving disabled and deleted collision bodies")
	var transform_root := Node2D.new()
	f.world.add_child(transform_root)
	transform_root.position = Vector2(180,130)
	transform_root.rotation = 0.35
	transform_root.scale = Vector2(1.4,0.8)
	var box := _box_in(transform_root,Vector2(20,-10),Vector2(80,30),true)
	box.rotation = -0.2
	_box_in(f.actor,Vector2.ZERO,Vector2(30,30))
	var ignored := _box_in(f.world,Vector2(500,100),Vector2(20,20))
	ignored.get_parent().add_to_group("sonar_ignore")
	var disabled := _box_in(f.world,Vector2(600,100),Vector2(20,20))
	disabled.disabled = true
	var trigger := Area2D.new()
	f.world.add_child(trigger)
	var trigger_shape := CollisionShape2D.new()
	trigger_shape.shape = RectangleShape2D.new()
	trigger.add_child(trigger_shape)
	f.surface.refresh_geometry()
	var original: Vector2 = box.to_global(Vector2(0,-15))
	_check(f.surface.geometry.size() == 1 and f.surface.debug_sample(original,0.1).on_geometry,"world transforms are respected; actor disabled ignore-group and Area2D geometry are excluded")
	# Rotation below nonuniform scale deforms the collider in world space. Probe
	# emission-time preservation on a genuinely rigid transform separately.
	transform_root.free()
	box = _box_in(f.world,Vector2(80,80),Vector2(50,30),true)
	f.surface.refresh_geometry()
	original = box.to_global(Vector2(0,-15))
	_noise(f,original+Vector2(0,-80))
	var arrival: float = f.surface.debug_sample(original,0.1).arrival_times[0].arrival
	f.surface.advance_simulation(arrival+0.02)
	box.get_parent().position += Vector2(130,-40)
	box.get_parent().rotation += 0.6
	f.surface.refresh_geometry()
	var moved: Vector2 = box.to_global(Vector2(0,-15))
	var sample: Dictionary = f.surface.debug_sample(moved,0.1)
	_check(sample.on_geometry and sample.alpha > 0 and is_equal_approx(sample.arrival_times[0].arrival,arrival),"moving rotated body keeps active contour and emission-time arrival schedule")
	_check(not f.surface.debug_sample(original,1.0).on_geometry,"moving body leaves no contour at old position")
	box.shape.size = Vector2(100,30)
	f.surface.refresh_geometry()
	_check(f.surface.debug_sample(box.to_global(Vector2(50,0)),0.1).on_geometry,"runtime shape edit recollects actual surface")
	box.disabled = true
	_check(not f.surface.debug_sample(box.to_global(Vector2(50,0)),0.1).on_geometry,"disabled body stops contributing even before recollection")
	box.get_parent().free()
	f.surface.refresh_geometry()
	_check(f.surface.geometry.is_empty() and f.surface.pulses[0].tracks.is_empty(),"deleted body removes contour and pulse track without ghost")
	_fixture_done(f)

func _source_scope() -> void:
	var f := _fixture("explicit local bus and source provenance")
	var autoload_bus := root.get_node("NoiseBus")
	var untouched_count: int = autoload_bus.event_count
	_check(not autoload_bus.noise_emitted.get_connections().any(func(connection): return connection.callable.get_object() == f.surface),"surface never subscribes to autoload NoiseBus")
	autoload_bus.emit_noise(Vector2.ZERO,&"autoload",1.0,f.actor)
	_check(f.surface.accepted_event_count == 0,"same-world autoload noise cannot enter local binding")
	var foreign := Node2D.new()
	root.add_child(foreign)
	var detached := Node2D.new()
	var queued := Node2D.new()
	f.world.add_child(queued)
	queued.queue_free()
	for source in [null,foreign,detached,queued]: f.bus.emit_noise(Vector2.ZERO,&"invalid_scope",1.0,source)
	for bad in [0.0,-1.0,INF,NAN]: f.bus.noise_emitted.emit(Vector2.ZERO,&"invalid",bad,f.actor)
	f.bus.noise_emitted.emit(Vector2.INF,&"invalid",1.0,f.actor)
	f.bus.noise_emitted.emit(Vector2.ZERO,&"",1.0,f.actor)
	_check(f.surface.accepted_event_count == 0,"foreign null detached queued and malformed sources/events cannot reveal surfaces")
	_noise(f)
	_check(f.surface.accepted_event_count == 1 and autoload_bus.event_count == untouched_count+1,"one valid local event produces one pulse without forwarding into autoload")
	foreign.free()
	detached.free()
	_fixture_done(f)

func _pause_and_binding() -> void:
	var f := _fixture("local pause enable reset rebind detach and retained callback")
	_box_in(f.world,Vector2(0,80),Vector2(200,20))
	f.surface.refresh_geometry()
	_noise(f)
	f.surface.advance_simulation(0.1)
	var age: float = f.surface.pulses[0].age
	f.surface.simulation_enabled = false
	_noise(f)
	f.surface.advance_simulation(2.0)
	_check(f.surface.accepted_event_count == 1 and is_equal_approx(f.surface.pulses[0].age,age),"local pause freezes existing pulse ages and rejects new intake")
	f.surface.simulation_enabled = true
	f.surface.advance_simulation(dt)
	_noise(f)
	_check(f.surface.accepted_event_count == 2 and f.surface.pulses[0].age > age,"local resume accepts fresh events and advances previous pulse")
	paused = true
	age = f.surface.pulses[0].age
	f.surface.advance_simulation(2.0)
	_noise(f)
	_check(f.surface.accepted_event_count == 2 and f.surface.pulses[0].age == age,"SceneTree pause independently freezes time and intake")
	paused = false
	var old: Callable = f.surface._receiver
	f.surface.enabled = false
	old.call(Vector2.ZERO,&"old",1.0,f.actor)
	_noise(f)
	_check(f.surface.pulses.is_empty() and f.surface.accepted_event_count == 2,"disable clears pulses and invalidates previous subscription")
	f.surface.enabled = true
	old.call(Vector2.ZERO,&"old",1.0,f.actor)
	_noise(f)
	_check(f.surface.accepted_event_count == 3 and f.surface.pulses.size() == 1,"enable reconnects once without reviving retained callbacks")
	old = f.surface._receiver
	for _index in 3: _check(f.surface.bind_surface(f.world,f.actor,f.bus),"repeat explicit binding succeeds")
	old.call(Vector2.ZERO,&"old",1.0,f.actor)
	_check(f.surface.accepted_event_count == 0 and f.surface.pulses.is_empty() and f.surface.event_history.is_empty() and f.surface.elapsed == 0,"rebind resets diagnostics time pulses and callbacks")
	_noise(f)
	_check(f.surface.accepted_event_count == 1 and f.bus.noise_emitted.get_connections().size() == 1,"repeated bind leaves a single subscription")
	var replacement_bus: Node = BUS.new()
	f.world.add_child(replacement_bus)
	old = f.surface._receiver
	f.surface.bind_surface(f.world,f.actor,replacement_bus)
	_noise(f)
	old.call(Vector2.ZERO,&"stale",1.0,f.actor)
	_check(f.surface.accepted_event_count == 0 and f.bus.noise_emitted.get_connections().is_empty(),"old bus and retained callback cannot enter new binding")
	replacement_bus.emit_noise(Vector2.ZERO,&"fresh",1.0,f.actor)
	_check(f.surface.accepted_event_count == 1,"replacement bus independently admits fresh source")
	f.surface.unbind_surface()
	_check(f.surface.geometry.is_empty() and f.surface.pulses.is_empty() and f.surface.event_history.is_empty() and replacement_bus.noise_emitted.get_connections().is_empty(),"explicit unbind clears surface state and disconnects")
	f.surface.bind_surface(f.world,f.actor,f.bus)
	old = f.surface._receiver
	root.remove_child(f.surface)
	old.call(Vector2.ZERO,&"detached",1.0,f.actor)
	_check(f.surface.accepted_event_count == 0 and f.bus.noise_emitted.get_connections().is_empty(),"tree detach retires binding and callback")
	root.add_child(f.surface)
	_check(f.surface.bind_surface(f.world,f.actor,f.bus),"reattached optional surface can explicitly bind again")
	_noise(f)
	_check(f.surface.accepted_event_count == 1,"reattached surface receives once")
	var detached_world := Node2D.new()
	_check(not f.surface.bind_surface(detached_world,f.actor,f.bus) and f.bus.noise_emitted.get_connections().is_empty(),"failed binding safely removes old subscription")
	_check(not f.surface.bind_surface(null,f.actor,f.bus) and not f.surface.bind_surface(f.world,f.world,f.bus),"null world and invalid actor hierarchy are rejected")
	_check(not f.surface.bind_surface(RefCounted.new(),f.actor,f.bus) and not f.surface.bind_surface(f.world,RefCounted.new(),f.bus) and not f.surface.bind_surface(f.world,f.actor,RefCounted.new()),"live non-Node dependencies are rejected safely before tree access")
	detached_world.free()
	_fixture_done(f)

func _dependency_retirement() -> void:
	for disposition in ["queued_actor","freed_actor","queued_world","freed_world","queued_bus","freed_bus","queued_surface"]:
		var f := _fixture("dependency retirement "+disposition)
		_box_in(f.world,Vector2(0,80),Vector2(200,20))
		f.surface.refresh_geometry()
		_noise(f)
		var callback: Callable = f.surface._receiver
		if disposition == "queued_actor": f.actor.queue_free()
		elif disposition == "freed_actor": f.actor.free()
		elif disposition == "queued_world": f.world.queue_free()
		elif disposition == "freed_world": f.world.free()
		elif disposition == "queued_bus": f.bus.queue_free()
		elif disposition == "freed_bus": f.bus.free()
		else: f.surface.queue_free()
		callback.call(Vector2.ZERO,&"retired",1.0,f.actor)
		_check(f.surface.accepted_event_count == 1,"queued or freed dependency rejects retained callback immediately")
		if disposition != "queued_surface":
			f.surface._process(dt)
			_check(f.surface.pulses.is_empty() and f.surface.geometry.is_empty() and f.surface.accepted_event_count == 0,"next surface process safely retires invalid dependency and existing contours")
		_fixture_done(f)

func _callback_retirement() -> void:
	for disposition in ["free_source","free_actor","free_world","rebind"]:
		var f := _fixture("earlier bus subscriber "+disposition,false)
		var source := Node2D.new()
		f.world.add_child(source)
		var bus_holder := f.bus as Node
		f.world.remove_child(bus_holder)
		root.add_child(bus_holder)
		var other_bus: Node = BUS.new()
		root.add_child(other_bus)
		f.bus.noise_emitted.connect(func(_origin,_kind,_loudness,_source):
			if disposition == "free_source": source.free()
			elif disposition == "free_actor": f.actor.free()
			elif disposition == "free_world": f.world.free()
			else: f.surface.bind_surface(f.world,f.actor,other_bus))
		_check(f.surface.bind_surface(f.world,f.actor,f.bus),"adapter subscribes after retiring observer")
		f.bus.emit_noise(Vector2.ZERO,&"retired_during_emission",1.0,source)
		_check(f.surface.accepted_event_count == 0,"earlier synchronous observer cannot deliver stale freed or rebound event to surface")
		_fixture_done(f)
		bus_holder.free()
		other_bus.free()
	var f := _fixture("freed surface invalidates callback")
	var callback: Callable = f.surface._receiver
	f.surface.free()
	_noise(f)
	_check(not callback.is_valid() and f.bus.noise_emitted.get_connections().is_empty(),"freeing optional surface leaves no callback or bus connection")
	_fixture_done(f)

func _contour_only_rendering() -> void:
	var f := _fixture("renderer submits surface fragments only")
	root.canvas_transform = Transform2D.IDENTITY
	_box_in(f.world,Vector2(320,180),Vector2(480,40))
	f.surface.refresh_geometry()
	f.surface.blind = true
	f.surface.tuning.draw_proprioception = true
	f.surface.tuning.draw_origin_labels = true
	f.surface.tuning.draw_threat_direction = true
	f.surface.tuning.draw_contact_feedback = true
	f.surface.tuning.max_draw_segments = 10
	_noise(f,Vector2(320,80),&"prop_break")
	f.surface.advance_simulation(0.3)
	await process_frame
	RenderingServer.force_draw(false)
	var drawn: Dictionary = f.surface.debug_snapshot()
	_check(drawn.draw_segments > 0 and drawn.draw_segments <= 10,"renderer submits bounded active surface fragments")
	_check(not drawn.draw_blackout and not drawn.draw_proprioception and drawn.draw_origins == 0 and drawn.draw_labels == 0 and drawn.draw_threats == 0 and drawn.draw_contacts == 0,"adapter prevents blackout body origin label threat and contact rendering even with inherited flags enabled")
	f.surface.advance_simulation(10.0)
	await process_frame
	RenderingServer.force_draw(false)
	_check(f.surface.debug_snapshot().draw_segments == 0,"silent render submits no permanent collision outline")
	measurements.rendered_active_segments = drawn.draw_segments
	_fixture_done(f)

func _attach_surface() -> void:
	surface = SURFACE.instantiate()
	world.add_child(surface)
	_check(surface.bind_surface(world,actor,bus),"surface explicitly binds real reusable PC and unchanged local relay bus")

func _assert_exact_surface_delivery() -> void:
	var exact: bool = surface.accepted_event_count == bus.event_count and bus.event_count == relay.forwarded_count and bus.event_count == noise_receipts.size() and surface.event_history.size() == bus.event_history.size()
	for index in mini(surface.event_history.size(),bus.event_history.size()):
		var event: Dictionary = surface.event_history[index]
		var emitted: Dictionary = bus.event_history[index]
		exact = exact and event.origin == emitted.origin and event.kind == emitted.kind and event.loudness == emitted.loudness and event.source_id == emitted.source_id
	_check(exact,"every actual PC receipt forwards exactly once to one surface pulse with exact origin kind loudness and source")

func _real_relay_events() -> void:
	await _begin("real walking landing and strike through local NoiseRelay")
	_attach_surface()
	_check(await _until(func(): return _count_kind(&"footstep") > 0,{"right":1.0}),"actual movement commits walking footstep")
	_assert_exact_surface_delivery()
	await _step({},ceili(0.3/dt))
	actor.reset_actor(Vector2(100,65))
	_check(await _until(func(): return _count_kind(&"land") > 0),"actual fall commits physical floor landing")
	_assert_exact_surface_delivery()
	await _step({},3)
	_check(await _until(func(): return _count_kind(&"strike") > 0,{"attack":true}),"real input drives weapon into active strike")
	_assert_exact_surface_delivery()
	var kinds := noise_receipts.map(func(event): return String(event.kind))
	var count_before: int = surface.accepted_event_count
	actor.apply_hitpause(0.2)
	await _step({"attack":true},maxi(1,ceili(0.08/dt)))
	_check(surface.accepted_event_count == count_before,"hitpause does not replay physical noise or duplicate pulses")
	await _finish({"actual_noise_kinds":kinds,"surface_events":count_before})

func _surface_motor_parity() -> void:
	await _begin("surface attachment disable removal and exact PC motor parity")
	_attach_surface()
	var bare := _new_actor()
	driver.actors.append(bare)
	actor.reset_actor(Vector2(100,200))
	bare.reset_actor(Vector2(100,200))
	var bare_events: Array[String] = []
	bare.movement_event.connect(func(kind: StringName,_payload: Dictionary): bare_events.append(String(kind)))
	movement.clear()
	var samples := 0
	var mismatches := 0
	for segment in [{"frame":{"right":1.0},"seconds":0.3},{"frame":{"jump":true},"seconds":0.1},{"frame":{},"seconds":0.6},{"frame":{"roll":true},"seconds":0.4},{"frame":{},"seconds":0.4},{"frame":{"shield":true},"seconds":0.4},{"frame":{},"seconds":0.4},{"frame":{"attack":true},"seconds":0.4}]:
		for _index in ceili(segment.seconds/dt):
			await _step(segment.frame)
			samples += 1
			if _motor_state(actor) != _motor_state(bare): mismatches += 1
	_check(mismatches == 0 and movement == bare_events,"attached surface preserves exact per-tick movement combat permissions and motor event sequence",{"samples":samples,"mismatches":mismatches})
	var state: Array = _motor_state(actor)
	surface.enabled = false
	_check(_motor_state(actor) == state,"disabling visualization does not mutate motor")
	surface.unbind_surface()
	surface.free()
	_check(_motor_state(actor) == state,"unbind and removal do not mutate motor")
	for _index in ceili(0.4/dt):
		await _step({"right":1.0})
		samples += 1
		if _motor_state(actor) != _motor_state(bare): mismatches += 1
	_check(mismatches == 0 and movement == bare_events,"actor continues identical movement after surface is removed",{"samples":samples,"mismatches":mismatches})
	measurements.motor_parity_samples = samples
	await _finish({"motor_samples":samples,"mismatched_ticks":mismatches})
