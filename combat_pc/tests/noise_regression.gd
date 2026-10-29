extends "res://combat_pc/tests/health_regression.gd"
## M14: focused actor-receipt/optional-bus integration, driven once per real tick.
const RELAY = preload("res://combat_pc/components/noise_relay.tscn")
const BUS = preload("res://scripts/sensory/noise_bus.gd")
const DEFEAT = preload("res://combat_pc/components/defeat_response.tscn")
const NOISE_SOURCES = ["res://combat_pc/player.gd", "res://combat_pc/player.tscn", "res://combat_pc/components/noise_relay.gd", "res://combat_pc/components/noise_relay.tscn", "res://scripts/sensory/noise_bus.gd", "res://combat_pc/components/health_component.gd", "res://combat_pc/components/defeat_response.gd"]
var relay: Node
var bus: Node
var noise_receipts: Array[Dictionary] = []
var legacy_noise: Array[Dictionary] = []
var forwarded: Array[Dictionary] = []
var movement_origins: Dictionary = {}

func _run() -> void:
	for path in NOISE_SOURCES: hashes[path] = FileAccess.get_sha256(path)
	await _physical_origins()
	await _snapshot_teleport()
	await _movement_callback_resets()
	await _legacy_and_receipt_resets()
	await _nested_noise()
	await _binding_lifetime()
	await _bus_callback_retirement()
	await _filter_and_pause()
	await _attached_motor_parity()
	await _health_defeat_integration()
	var stable := true
	for path in NOISE_SOURCES: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "production sources stayed unchanged during run")
	var report := {"milestone":14,"suite":"focused noise relay","physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"engine":Engine.get_version_info().string,"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Real reusable actor and local unchanged NoiseBus; one driver call per engine physics callback. Contract and retirement cases explicitly invoke committed-noise admission or retained relay callables.","limitations":["Focused headless integration; parent owns native visual review","Noise provenance only, with no audio playback or sensory behavior"]}
	FileAccess.open("res://combat_pc/tests/noise_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("NOISE_M14 %dHz: %d checks, %d scenarios, %d failures" % [hz,checks.size(),scenarios.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _begin(name_: String, attach := true) -> void:
	await super._begin(name_,false)
	relay = null
	bus = BUS.new()
	bus.name = "LocalNoiseBus"
	world.add_child(bus)
	noise_receipts = []; legacy_noise = []; forwarded = []; movement_origins = {}
	actor.noise_requested.connect(func(origin: Vector2, kind: StringName, loudness: float, source: Node): legacy_noise.append({"origin":origin,"kind":kind,"loudness":loudness,"source_id":source.get_instance_id()}))
	actor.noise_committed.connect(func(event: Dictionary): noise_receipts.append(event))
	actor.movement_event.connect(func(kind: StringName, payload: Dictionary): movement_origins[kind] = payload.position)
	if attach: _attach_relay()

func _attach_relay(target: Node = null, target_bus: Node = null) -> Node:
	var result: Node = RELAY.instantiate()
	result.forwarded.connect(func(event: Dictionary): forwarded.append(event))
	(target if target != null else actor).add_child(result)
	_check(result.bind(target if target != null else actor,target_bus if target_bus != null else bus),"optional relay explicitly binds a live actor and bus")
	relay = result
	return result

func _clear_noise() -> void:
	noise_receipts.clear(); legacy_noise.clear(); forwarded.clear(); movement_origins.clear()
	bus.clear_history()
	if is_instance_valid(relay): relay.reset_diagnostics()

func _count_kind(kind: StringName) -> int:
	var result := 0
	for event in noise_receipts:
		if event.kind == kind: result += 1
	return result

func _verify_delivery() -> void:
	var matches: bool = noise_receipts.size() == bus.event_count and noise_receipts.size() == forwarded.size() and relay.forwarded_count == noise_receipts.size()
	var immutable := true
	var serials: Dictionary = {}
	for index in mini(noise_receipts.size(),bus.event_history.size()):
		var event := noise_receipts[index]
		var delivered: Dictionary = bus.event_history[index]
		matches = matches and event.origin == delivered.origin and event.kind == delivered.kind and event.loudness == delivered.loudness and event.actor_id == delivered.source_id and event.generation == actor.noise_generation()
		immutable = immutable and event.is_read_only() and forwarded[index].is_read_only() and event.keys().size() == 6 and event.origin is Vector2 and not serials.has(event.serial)
		serials[event.serial] = true
	_check(matches,"each committed event forwards once with exact origin kind loudness source and live generation")
	_check(immutable,"committed and forwarded receipts are readonly scalar snapshots with distinct serials")

func _physical_origins() -> void:
	await _begin("real walking footstep and quiet idle")
	_check(await _until(func(): return _count_kind(&"footstep") > 0,{"right":1.0}),"actual walking crosses the configured footstep distance")
	_check(_count_kind(&"footstep") == 1 and noise_receipts[0].origin == movement_origins[&"footstep"],"one walking threshold commits its physical foot origin")
	_verify_delivery()
	await _step({},ceili(0.2/dt))
	_clear_noise()
	await _step({},ceili(0.3/dt))
	_check(noise_receipts.is_empty() and bus.event_count == 0,"settled idle emits no noise or repeats")
	await _finish()
	await _begin("real landing and active strike origins")
	actor.reset_actor(Vector2(100,65))
	_clear_noise()
	_check(await _until(func(): return _count_kind(&"land") > 0),"actual falling actor contacts the floor")
	_check(_count_kind(&"land") == 1 and noise_receipts[0].origin == movement_origins[&"landed"],"landing commits the exact physical foot contact once")
	_verify_delivery()
	await _step({},3)
	_clear_noise()
	var strike_center := [Vector2.ZERO]
	actor.noise_requested.connect(func(_origin: Vector2,kind: StringName,_loudness: float,_source: Node):
		if kind == &"strike": strike_center[0] = actor._strike_center())
	_check(await _until(func(): return _count_kind(&"strike") > 0,{"attack":true}),"actual weapon windup reaches active phase")
	_check(_count_kind(&"strike") == 1 and noise_receipts[0].origin == strike_center[0] and noise_receipts[0].origin != actor.global_position,"strike uses the blade center captured synchronously at active entry rather than the actor root")
	_verify_delivery()
	actor.apply_hitpause(0.2)
	var count_before: int = bus.event_count
	await _step({"attack":true,"right":1.0},maxi(1,ceili(0.08/dt)))
	_check(bus.event_count == count_before and actor.hitpause_remaining > 0,"paused physics ticks never replay the current strike noise")
	await _finish()

func _snapshot_teleport() -> void:
	for phase in ["hurt_started","noise_requested"]:
		await _begin("committed origin survives same-generation teleport at "+phase)
		var origin: Vector2 = actor.global_position
		var generation: int = actor.noise_generation()
		if phase == "hurt_started":
			actor.movement_event.connect(func(kind: StringName,_payload: Dictionary):
				if kind == &"hurt_started": actor.global_position += Vector2(330,-20))
		else:
			actor.noise_requested.connect(func(_origin: Vector2,_kind: StringName,_loudness: float,_source: Node): actor.global_position += Vector2(330,-20))
		actor.receive_hit({"amount":1.0,"impulse":Vector2.ZERO,"hitpause":0.0})
		_check(actor.noise_generation() == generation and actor.global_position != origin,"fixture teleports without resetting the actor generation")
		_check(noise_receipts.size() == 1 and noise_receipts[0].origin == origin and bus.event_history[0].origin == origin,"receipt and bus retain the pre-callback physical event origin")
		_verify_delivery()
		await _finish()

func _movement_callback_resets() -> void:
	for phase in ["footstep","landed","roll_started","hurt_started"]:
		await _begin("reset from actual "+phase+" callback")
		if phase == "landed": actor.reset_actor(Vector2(100,65))
		var reset := [false]
		var generation: int = actor.noise_generation()
		actor.movement_event.connect(func(kind: StringName,_payload: Dictionary):
			if String(kind) == phase and not reset[0]: reset[0] = true; actor.reset_actor(Vector2(350,200)))
		if phase == "footstep": await _until(func(): return reset[0],{"right":1.0})
		elif phase == "landed": await _until(func(): return reset[0])
		elif phase == "roll_started": await _step({"roll":true})
		else: actor.receive_hit({"amount":1.0,"hitpause":0.0})
		_check(reset[0] and actor.noise_generation() > generation,"real event callback installs a new actor generation")
		_check(noise_receipts.is_empty() and legacy_noise.is_empty() and bus.event_count == 0,"pre-reset movement cannot emit legacy or committed noise into the replacement life")
		_check(actor.position == Vector2(350,200) and actor.main_action == &"locomotion","outer callback cannot overwrite the replacement motor position or action")
		await _finish()

func _legacy_and_receipt_resets() -> void:
	await _begin("legacy noise observer resets before commitment")
	actor.noise_requested.connect(func(_origin: Vector2,_kind: StringName,_loudness: float,_source: Node): actor.reset_actor(Vector2(350,200)))
	actor.receive_hit({"amount":1.0,"hitpause":0.0})
	_check(legacy_noise.size() == 1 and noise_receipts.is_empty() and bus.event_count == 0,"legacy callback can retire the event before appended receipt delivery")
	await _finish()
	await _begin("earlier receipt observer resets before relay",false)
	actor.noise_committed.connect(func(_event: Dictionary): actor.reset_actor(Vector2(350,200)))
	_attach_relay()
	actor.receive_hit({"amount":1.0,"hitpause":0.0})
	_check(noise_receipts.size() == 1 and bus.event_count == 0 and forwarded.is_empty(),"later relay rejects the already-emitted old-generation receipt")
	_check(noise_receipts[0].generation != actor.noise_generation(),"captured receipt remains an immutable historical generation")
	await _finish()

func _nested_noise() -> void:
	await _begin("nested valid noise delivers higher then lower serial",false)
	var nested := [false]
	actor.noise_committed.connect(func(_event: Dictionary):
		if not nested[0]: nested[0] = true; actor.receive_hit({"amount":2.0,"hitpause":0.0}))
	_attach_relay()
	var committed_before_callback := [true]
	bus.noise_emitted.connect(func(origin: Vector2,kind: StringName,_loudness: float,_source: Node): committed_before_callback[0] = committed_before_callback[0] and relay.forwarded_count == bus.event_count and relay.last_event.origin == origin and relay.last_event.kind == kind)
	actor.receive_hit({"amount":1.0,"hitpause":0.0})
	_check(bus.event_count == 2 and forwarded.size() == 2 and forwarded[0].serial > forwarded[1].serial,"valid nested and outer sounds both forward despite reverse serial order")
	_check(committed_before_callback[0] and relay.forwarded_count == 2,"relay diagnostics commit before each synchronous bus callback")
	var copy: Dictionary = relay.last_event
	copy.origin = Vector2(-999,-999)
	_check(relay.last_event.origin != copy.origin,"external diagnostic copies cannot mutate relay storage")
	await _finish({"forwarded_serials":forwarded.map(func(event: Dictionary): return event.serial)})

func _binding_lifetime() -> void:
	await _begin("mute unmute detach reattach and actor replacement")
	actor.receive_hit({"amount":1.0,"hitpause":0.0})
	var receipt: Dictionary = noise_receipts[0]
	var old: Callable = relay._callback
	var state: Array = _motor_state(actor)
	_clear_noise()
	relay.enabled = false
	old.call(receipt)
	actor._commit_noise(actor.position,&"muted",1.0,actor.noise_generation())
	_check(bus.event_count == 0 and _motor_state(actor) == state,"mute disconnects and invalidates retained callbacks without changing motor state")
	relay.enabled = true
	old.call(receipt)
	_check(bus.event_count == 0,"unmute cannot revive a callback captured before mute")
	actor._commit_noise(actor.position,&"unmuted",1.0,actor.noise_generation())
	_check(bus.event_count == 1,"fresh events resume exactly once after unmute")
	old = relay._callback
	actor.remove_child(relay)
	old.call(receipt)
	actor._commit_noise(actor.position,&"detached",1.0,actor.noise_generation())
	_check(bus.event_count == 1,"tree detach unbinds relay and invalidates retained callbacks")
	actor.add_child(relay)
	_check(relay.bind(actor,bus),"reattached relay can explicitly bind again")
	old.call(receipt)
	_check(bus.event_count == 1,"reattach does not revive old callbacks")
	for _index in 3: relay.bind(actor,bus)
	actor._commit_noise(actor.position,&"rebound",1.0,actor.noise_generation())
	_check(bus.event_count == 2,"repeated bind installs only one active subscription")
	var replacement := _new_actor(Vector2(400,200))
	old = relay._callback
	_check(relay.bind(replacement,bus),"relay can bind a replacement actor")
	old.call(receipt)
	relay._callback.call(receipt)
	actor._commit_noise(actor.position,&"old_actor",1.0,actor.noise_generation())
	_check(bus.event_count == 2,"old callbacks and foreign actor receipts cannot reach replacement binding")
	replacement._commit_noise(replacement.position,&"replacement",1.0,replacement.noise_generation())
	_check(bus.event_count == 3 and bus.event_history.back().source_id == replacement.get_instance_id(),"replacement actor forwards with its own source identity")
	_check(not relay.bind(_source(),bus),"bind rejects nodes without committed-noise contract")
	replacement._commit_noise(replacement.position,&"failed_binding",1.0,replacement.noise_generation())
	_check(bus.event_count == 3,"failed bind remains safely disconnected")
	await _finish()
	await _begin("freed relay removes subscription without driving actor")
	var retained: Callable = relay._callback
	var state_before_free: Array = _motor_state(actor)
	relay.free()
	actor._commit_noise(actor.position,&"after_relay_free",1.0,actor.noise_generation())
	_check(not retained.is_valid() and bus.event_count == 0 and forwarded.is_empty(),"fully freed relay leaves no live callback or bus subscription")
	_check(_motor_state(actor) == state_before_free and noise_receipts.size() == 1,"relay destruction preserves actor state and independent committed-noise production")
	await _finish()
	for disposition in ["queued_relay","queued_actor","queued_bus","freed_bus","freed_actor"]:
		await _begin("lifetime retirement "+disposition)
		actor.receive_hit({"amount":1.0,"hitpause":0.0})
		var event: Dictionary = noise_receipts[0]
		var callback: Callable = relay._callback
		_clear_noise()
		if disposition == "queued_relay": relay.queue_free()
		elif disposition == "queued_actor": actor.queue_free()
		elif disposition == "queued_bus": bus.queue_free()
		elif disposition == "freed_bus": bus.free()
		else:
			actor.remove_child(relay)
			world.add_child(relay)
			relay.bind(actor,bus)
			callback = relay._callback
			actor.free()
		callback.call(event)
		_check(forwarded.is_empty() and relay.forwarded_count == 0,"queued or freed dependency cannot forward through a retained callable")
		if is_instance_valid(bus): _check(bus.event_count == 0,"retired lifetime does not touch the still-live bus")
		await _finish()

func _bus_callback_retirement() -> void:
	for disposition in ["reset_actor","rebind","mute_unmute","detach","reset_diagnostics","queue_relay"]:
		await _begin("bus callback invalidates outer forwarded signal: "+disposition)
		var replacement_bus: Node = BUS.new()
		world.add_child(replacement_bus)
		var saw_committed := [false]
		bus.noise_emitted.connect(func(_origin: Vector2,_kind: StringName,_loudness: float,_source: Node):
			saw_committed[0] = relay.forwarded_count == 1 and not relay.last_event.is_empty()
			if disposition == "reset_actor": actor.reset_actor(Vector2(350,200))
			elif disposition == "rebind": relay.bind(actor,replacement_bus)
			elif disposition == "mute_unmute": relay.enabled = false; relay.enabled = true
			elif disposition == "detach": actor.remove_child(relay)
			elif disposition == "reset_diagnostics": relay.reset_diagnostics()
			else: relay.queue_free())
		actor.receive_hit({"amount":1.0,"hitpause":0.0})
		_check(bus.event_count == 1 and saw_committed[0],"bus receives the committed event and sees committed diagnostics before retirement")
		_check(forwarded.is_empty(),"invalidated outer operation emits no stale forwarded notification")
		if disposition == "rebind":
			actor._commit_noise(actor.position,&"fresh_binding",1.0,actor.noise_generation())
			_check(replacement_bus.event_count == 1 and forwarded.size() == 1,"new bus binding accepts a later independent event")
		if disposition == "detach": relay.free()
		await _finish()

func _filter_and_pause() -> void:
	await _begin("finite positive input validation at actor and relay")
	for loudness in [0.0,-1.0,INF,NAN]: actor._commit_noise(actor.position,&"invalid",loudness,actor.noise_generation())
	actor._commit_noise(Vector2.INF,&"invalid",1.0,actor.noise_generation())
	_check(noise_receipts.is_empty() and bus.event_count == 0,"actor does not commit nonfinite origins or nonpositive/nonfinite loudness")
	var good := {"actor_id":actor.get_instance_id(),"generation":actor.noise_generation(),"serial":800,"origin":actor.position,"kind":&"valid","loudness":1.0}
	for patch in [{"origin":Vector2.INF},{"origin":"bad"},{"loudness":0.0},{"loudness":-1.0},{"loudness":INF},{"loudness":NAN},{"loudness":"loud"},{"kind":&""},{"kind":17},{"actor_id":0},{"generation":-1}]: relay._callback.call(good.merged(patch,true))
	_check(bus.event_count == 0 and relay.forwarded_count == 0,"relay independently rejects malformed foreign and stale snapshots")
	var missing_serial: Dictionary = good.duplicate()
	missing_serial.erase("serial")
	relay._callback.call(missing_serial)
	_check(bus.event_count == 0 and relay.forwarded_count == 0,"relay rejects a receipt missing its serial")
	for invalid_serial in [0,-1,"1",1.0]:
		relay._callback.call(good.merged({"serial":invalid_serial},true))
		_check(bus.event_count == 0 and relay.forwarded_count == 0,"relay requires a positive integer serial",{"input":str(invalid_serial),"type":type_string(typeof(invalid_serial))})
	relay._callback.call(good)
	_check(bus.event_count == 1 and forwarded.size() == 1,"finite positive current snapshot passes relay validation")
	await _finish()
	await _begin("valid noise remains current when legacy callback applies hitpause")
	actor.noise_requested.connect(func(_origin: Vector2,_kind: StringName,_loudness: float,_source: Node): actor.apply_hitpause(0.2))
	actor.receive_hit({"amount":1.0,"hitpause":0.0})
	_check(actor.hitpause_remaining > 0 and bus.event_count == 1 and forwarded.size() == 1,"local pause does not invalidate a committed same-generation sound")
	_verify_delivery()
	await _finish()

func _attached_motor_parity() -> void:
	await _begin("relay attached versus absent exact motor parity")
	var bare := _new_actor()
	driver.actors.append(bare)
	actor.reset_actor(Vector2(100,200)); bare.reset_actor(Vector2(100,200))
	var bare_events: Array[String] = []
	bare.movement_event.connect(func(kind: StringName,_payload: Dictionary): bare_events.append(String(kind)))
	movement.clear()
	var mismatches := 0
	var sampled := 0
	for segment in [{"frame":{"right":1.0},"seconds":0.3},{"frame":{"jump":true},"seconds":0.1},{"frame":{},"seconds":0.6},{"frame":{"roll":true},"seconds":0.4},{"frame":{},"seconds":0.4},{"frame":{"shield":true},"seconds":0.4},{"frame":{},"seconds":0.4},{"frame":{"attack":true},"seconds":0.4}]:
		for _index in ceili(segment.seconds/dt):
			await _step(segment.frame)
			sampled += 1
			if _motor_state(actor) != _motor_state(bare): mismatches += 1
	_check(mismatches == 0 and movement == bare_events,"optional relay preserves exact per-tick movement combat permissions and original event sequence",{"samples":sampled,"mismatches":mismatches})
	for mode in ["hurt","guard","parry","roll"]:
		actor.reset_actor(Vector2(100,200)); bare.reset_actor(Vector2(100,200))
		await _step({},3)
		await _enter(mode)
		var payload := _attack(_source(),1,25)
		var attached_result: Dictionary = actor.receive_attack(payload)
		var bare_result: Dictionary = bare.receive_attack(payload)
		_check(attached_result == bare_result and _motor_state(actor) == _motor_state(bare),"relay preserves immediate "+mode+" outcome and motor state")
		for _index in ceili(0.2/dt):
			await _step({"shield":mode == "guard"})
			if _motor_state(actor) != _motor_state(bare): mismatches += 1
	_check(mismatches == 0,"post-contact pause recoil and recovery remain exactly equal")
	await _finish({"motor_samples":sampled,"mismatched_ticks":mismatches})

func _health_defeat_integration() -> void:
	await _begin("Health DefeatResponse and NoiseRelay coexist on one PC")
	_attach_health()
	var response: Node = DEFEAT.instantiate()
	actor.add_child(response)
	actor.receive_hit({"amount":15.0,"hitpause":0.0})
	_check(health.current_health == 85 and not actor.is_defeated() and bus.event_count == 1,"nonlethal hurt debits Health and independently forwards physical hurt noise")
	actor.receive_hit({"amount":150.0,"hitpause":0.0})
	_check(health.current_health == 0 and actor.is_defeated() and response.active and bus.event_count == 2,"lethal hurt forwards once while Health acquires existing defeat policy")
	var before: int = bus.event_count
	await _step({"attack":true,"right":1.0,"roll":true},ceili(0.4/dt))
	var only_physical_landing := true
	for event in bus.event_history.slice(before): only_physical_landing = only_physical_landing and event.kind == &"land"
	_check(actor.is_defeated() and only_physical_landing,"defeated inputs cannot start fresh action sounds; physical recoil landing remains audible")
	actor.reset_actor(Vector2(100,200))
	_check(health.current_health == 100 and not actor.is_defeated(),"explicit actor reset preserves existing health refill and defeat release")
	await _step({},3)
	before = bus.event_count
	await _step({"roll":true})
	_check(bus.event_count == before+1 and bus.event_history.back().kind == &"roll","all three components remain usable after explicit reset")
	await _finish()
