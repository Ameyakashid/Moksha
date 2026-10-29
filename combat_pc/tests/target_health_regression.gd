extends "res://combat_pc/tests/knockback_response_regression.gd"
## Real PC/ContactAdapter/motor checks plus separately labelled boundary probes.
const HEALTH_PATH := "res://combat_pc/components/strike_health.tscn"
var health_targets: Array[Dictionary] = []
var paired_outcomes: Array[Dictionary] = []

func _run() -> void:
	source_paths.append_array([
		"res://combat_pc/components/health_component.gd", "res://combat_pc/components/health_component.tscn",
		"res://combat_pc/components/strike_health.gd", HEALTH_PATH,
		"res://combat_pc/components/strike_knockback.gd", "res://movement/components/movement_motor.gd",
		"res://combat_pc/fixtures/knockback_target.gd", TARGET_PATH,
		"res://combat_pc/fixtures/chain_target.gd", "res://combat_pc/fixtures/contact_target.gd",
		"res://combat_pc/resources/responsive_chain.tres", "res://combat_pc/resources/air_response_agile.tres",
		"res://combat_pc/tests/target_health_regression.gd", "res://combat_pc/tests/target_health_api_source.gd"])
	for path in source_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _real_damage_cases()
	await _real_chain_cases()
	await _real_noncontacts()
	await _real_distinct_sources()
	await _malformed_health_packets()
	await _interrupted_health_delivery()
	await _health_replay_boundaries()
	await _health_signal_callbacks()
	await _health_binding_cases()
	await _health_pause_cases()
	await _health_movement_parity()
	await _health_api_limits()
	var stable := true; var hashes := {}
	for path in starting_hashes:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Source changed during focused run; rerun final files")
	var output := {"suite":"confirmed-strike target health", "physics_hz":hz, "checks":checks,
		"failures":failures,"scenarios":scenarios,"paired_outcomes":paired_outcomes,
		"engine":Engine.get_version_info(), "production_hash_stable_during_run":stable,
		"starting_hashes":starting_hashes,"hashes":hashes,
		"execution":"Real engine callbacks run the unchanged PC, ContactAdapter, and passive movement motor. Explicit API, malformed-input, replay and lifecycle probes are separately labelled; trace frames are evidence, not assertion counts.",
		"limits":["No death, AI, healing, player rewrite, or exact Dead Cells rules.","Headless functional acceptance, not native visual review."]}
	var output_path := "res://combat_pc/tests/target_health_results_%dhz.json" % hz
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(_safe(output),"  ")+"\n")
	print("TARGET_HEALTH %dHz: %d scenarios, %d assertions, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _health_begin(label: String) -> void:
	health_targets = []
	await _knockback_begin(label)
	actor.profile = load("res://combat_pc/resources/air_response_agile.tres").duplicate(true)

func _health_target(at: Vector2, label := "HealthTarget") -> Dictionary:
	var target := _knockback_target(at,label)
	var provider = load(HEALTH_PATH).instantiate()
	provider.receiver_path = NodePath("../Hurtbox")
	target.body.add_child(provider)
	target.provider = provider; target.health = provider.get_node("Health")
	target.damage = []; target.depletion = []; target.changes = []
	target.health.damage_processed.connect(func(receipt:Dictionary): target.damage.append(receipt))
	target.health.depleted.connect(func(): target.depletion.append(ticks))
	target.health.health_changed.connect(func(value:float,capacity:float): target.changes.append([value,capacity]))
	health_targets.append(target)
	return target

func _health_finish() -> void:
	var rows := []
	for target in health_targets:
		rows.append({"damage":_safe(target.damage),"depletion":target.depletion.duplicate(),
			"changes":target.changes.duplicate(true), "health":target.health.current_health if is_instance_valid(target.health) else null,
			"diagnostics":_safe(target.provider.diagnostic_snapshot()) if is_instance_valid(target.provider) else {"removed":true}})
	await _knockback_finish()
	scenarios.back().health_targets = rows
	health_targets = []

func _real_damage_cases() -> void:
	for direction in [-1,1]:
		for index in [0,1,2]:
			await _health_begin("real damage step%d direction%d" % [index,direction])
			actor.reset_actor(actor.position,direction)
			await _start_step(index)
			var target := _health_target(actor.position+Vector2(direction*31,0))
			await _sync_geometry()
			_check(await _until(func(): return target.damage.size()==1,{},.6),"actual confirmed strike reaches existing health store")
			var expected: float = actor.melee_chain.steps[index].damage
			_near(target.health.current_health,3.0-expected,.000001,"unscaled authored strike damage debits capacity3")
			_check(target.receipts.size()==1 and target.receiver.hits==1 and target.provider.resolved_count==1,"one real contact has independent health and knockback responses")
			if not target.damage.is_empty():
				_check(target.damage[0].is_read_only() and target.damage[0].source_id==actor.get_instance_id(),"immutable scalar receipt identifies actual source")
				_near(target.damage[0].applied,expected,.000001,"applied loss matches positive balance")
			await _seconds({},.5)
			_check(target.damage.size()==1 and target.depletion.is_empty(),"same active swing never repeatedly debits health")
			paired_outcomes.append({"case":name_,"health":target.health.current_health,"damage_events":target.damage.size(),"knockback_events":target.receipts.size()})
			await _health_finish()

func _real_chain_cases() -> void:
	for direction in [-1,1]:
		await _health_begin("real three-step health chain direction%d" % direction)
		actor.reset_actor(actor.position,direction)
		var target := _health_target(actor.position+Vector2(direction*31,0))
		await _sync_geometry(); await _start_step(0); await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
		await _seconds({},.45)
		_check(target.damage.size()==3 and target.receipts.size()==3 and target.receiver.hits==3,"ordinary three presses physically reach moving target three times")
		if target.damage.size()==3:
			_near(target.damage[0].after,2.0,.000001,"Slash leaves2 health")
			_near(target.damage[1].after,.85,.000001,"Backhand leaves0.85 health")
			_near(target.damage[2].after,0.0,.000001,"Finisher clamps at0")
			_near(target.damage[2].amount,1.8,.000001,"finisher preserves authored1.8 incoming amount")
			_near(target.damage[2].applied,.85,.000001,"overkill actual loss is remaining0.85")
		_check(target.depletion.size()==1,"positive-to-zero crossing emits exactly one depletion")
		_check(target.body.enabled and target.body.is_on_floor(),"zero imposes no defeat or motor-disable policy")
		target.body.reset_at(actor.position+Vector2(direction*31,0))
		await _step(); await _step({"attack":true}); await _seconds({},.45)
		_check(target.damage.size()==4 and target.health.current_health==0 and target.depletion.size()==1,"later real overkill remains0 without another depletion")
		target.provider.reset_to_full(); target.body.reset_at(actor.position+Vector2(direction*31,0))
		await _step(); await _step({"attack":true}); await _seconds({},.4)
		_check(target.damage.size()==5 and target.health.current_health<3 and target.health.current_health>0,"explicit refill permits a later fresh strike")
		paired_outcomes.append({"case":name_,"progression":target.damage.slice(0,3).map(func(r):return r.after),"depletions_before_reset":target.depletion.size()})
		await _health_finish()

func _real_noncontacts() -> void:
	for route in ["miss","occluded","confirmation reset"]:
		await _health_begin("real health "+route)
		var target := _health_target(actor.position+Vector2(300 if route=="miss" else 31,0))
		if route=="occluded": _box(actor.position+Vector2(18,-35),Vector2(2,100))
		if route=="confirmation reset":
			actor.movement_event.connect(func(kind:StringName,_data:Dictionary):
				if kind==&"strike_confirmed": actor.reset_actor(actor.position,1))
		await _sync_geometry(); await _start_step(0); await _seconds({},.5)
		_check(target.damage.is_empty() and target.health.current_health==3 and target.receiver.hits==0,"unconfirmed or retired strike cannot debit health")
		_check(target.receipts.is_empty() and _count("hitpause_started")==0,"original contact authority also withholds knockback and pause")
		await _health_finish()

func _real_distinct_sources() -> void:
	await _health_begin("real two sources with same strike serial")
	var target := _health_target(Vector2(132,200))
	secondary=PLAYER.instantiate(); secondary.automatic_physics=false; secondary.position=Vector2(164,200)
	secondary.melee_chain=load("res://combat_pc/resources/responsive_chain.tres").duplicate(true)
	world.add_child(secondary); secondary.reset_actor(secondary.position,-1)
	await _sync_geometry(); secondary_input={"attack":true}; await _step({"attack":true}); secondary_input={}
	await _until(func():return target.damage.size()>=2,{},.5)
	_check(target.damage.size()==2 and target.health.current_health==1,"different real sources each remove1 from same target")
	if target.damage.size()==2:
		_check(target.damage[0].serial==target.damage[1].serial and target.damage[0].source_id!=target.damage[1].source_id,"dedup distinguishes source identity when serials match")
	await _health_finish()

func _malformed_health_packets() -> void:
	await _health_begin("API malformed packets within real admitted delivery")
	var target := _health_target(actor.position+Vector2(31,0)); target.provider.unbind()
	var plain := Node2D.new(); world.add_child(plain)
	var results := []
	target.receiver.struck.connect(func(payload:Dictionary):
		var variants := [{"serial":-1},{"serial":1.0},{"serial":"1"},{"serial":true},{"eligible":1},{"eligible":false},{"eligible":"yes"},
			{"phase":"recovery"},{"phase":0},{"damage":-1},{"damage":NAN},{"damage":INF},{"damage":"1"},{"damage":true},
			{"contact_position":Vector2(0,INF)},{"contact_position":Vector2(NAN,0)},{"contact_position":[]},
			{"source":null},{"source":plain},{"source":target.receiver},{"source":target.provider},{"source":7},{"source":Vector2.ONE},{"source":Resource.new()}]
		for changed in variants:
			var accepted:bool=target.provider.consume_strike(payload.merged(changed,true))
			results.append({"fields":changed.keys(),"accepted":accepted,"unchanged":target.health.current_health==3})
		for missing in ["serial","eligible","phase","damage","contact_position","source"]:
			var copy := payload.duplicate(true); copy.erase(missing)
			results.append({"missing":missing,"accepted":target.provider.consume_strike(copy),"unchanged":target.health.current_health==3}))
	target.provider.bind_receiver(target.receiver)
	await _sync_geometry(); await _start_step(0); await _until(func():return target.damage.size()==1,{},.5)
	_check(results.size()==30 and results.all(func(row):return not row.accepted and row.unchanged),"thirty malformed variants reject before health changes")
	_check(target.damage.size()==1 and target.health.current_health==2,"rejected malformed inputs do not consume the valid identity")
	var copy:Dictionary=target.provider.last_receipt; copy.amount=999
	_check(target.provider.last_receipt.amount==1,"diagnostic copy cannot change stored receipt or health")
	measurements.rejections=results
	await _health_finish()

func _interrupted_health_delivery() -> void:
	for operation in ["reset","unbind","disable","detach","rebind","remove","source reset"]:
		await _health_begin("real earlier struck listener "+operation)
		var target := _health_target(actor.position+Vector2(31,0)); target.provider.unbind()
		var fired := []
		target.receiver.struck.connect(func(_payload:Dictionary):
			if not fired.is_empty(): return
			fired.append(true)
			match operation:
				"reset": target.provider.reset_to_full()
				"unbind": target.provider.unbind()
				"disable": target.provider.enabled=false
				"detach": target.body.remove_child(target.provider)
				"rebind": target.provider.unbind(); target.provider.bind_receiver(target.receiver)
				"remove": target.provider.queue_free()
				"source reset": actor.reset_actor(actor.position,1)
		)
		target.provider.bind_receiver(target.receiver)
		await _sync_geometry(); await _start_step(0); await _seconds({},.4)
		_check(fired.size()==1 and target.damage.is_empty(),"real earlier listener retirement prevents old health debit")
		if is_instance_valid(target.health): _near(target.health.current_health,3,.000001,"reset generation remains full")
		_check(target.receipts.size()==1,"already committed independent knockback remains an applied fact")
		if operation=="detach":target.provider.free()
		await _health_finish()

func _health_replay_boundaries() -> void:
	for operation in ["reset","unbind rebind","disable enable","replace","diagnostics"]:
		await _health_begin("API consumed health replay after "+operation)
		var target := _health_target(actor.position+Vector2(31,0))
		var duplicate := []
		target.receiver.struck.connect(func(payload:Dictionary):duplicate.append(target.provider.consume_strike(payload)))
		await _sync_geometry(); await _start_step(0); await _until(func():return target.damage.size()==1,{},.5)
		_check(duplicate==[false] and target.health.current_health==2,"duplicate synchronous delivery never double-debits")
		if target.delivered.is_empty(): await _health_finish(); continue
		var old:Dictionary=target.delivered[0]
		match operation:
			"reset":target.provider.reset_to_full()
			"unbind rebind":target.provider.unbind();target.provider.bind_receiver(target.receiver)
			"disable enable":target.provider.enabled=false;target.provider.enabled=true
			"replace":
				target.provider.free(); target.provider=load(HEALTH_PATH).instantiate();target.provider.receiver_path=NodePath("../Hurtbox");target.body.add_child(target.provider);target.health=target.provider.get_node("Health")
			"diagnostics":target.provider.reset_diagnostics()
		await _step()
		var before:float=target.health.current_health
		_check(not target.provider.consume_strike(old) and target.health.current_health==before,"lifecycle change does not rearm already consumed identity")
		var replay := []
		actor.strike_sample.connect(func(_source:Node2D,snapshot:Dictionary):
			if snapshot.serial!=old.serial or not replay.is_empty():return
			replay.append({"current":actor.is_strike_current(old.serial),"accepted":target.provider.consume_strike(old),"reason":target.provider.last_reason}))
		await _until(func():return not replay.is_empty(),{},.2)
		_check(replay.size()==1 and replay[0].current and not replay[0].accepted and replay[0].reason==&"duplicate" and target.health.current_health==before,"replay still rejects when original strike becomes current again after pause")
		measurements.live_replay=replay
		await _health_finish()

func _health_signal_callbacks() -> void:
	for signal_name in ["health_changed","damage_processed"]:
		for operation in ["reset","unbind","remove"]:
			await _health_begin("real "+signal_name+" listener "+operation)
			var target := _health_target(actor.position+Vector2(31,0))
			target.health.maximum_health=1;target.provider.reset_to_full()
			var fired := []
			var retire := func():
				if not fired.is_empty():return
				fired.append(true)
				match operation:
					"reset":target.provider.reset_to_full()
					"unbind":target.provider.unbind()
					"remove":target.provider.queue_free()
			if signal_name=="health_changed":target.health.health_changed.connect(func(_v:float,_c:float):retire.call())
			else:target.health.damage_processed.connect(func(_r:Dictionary):retire.call())
			await _sync_geometry();await _start_step(0);await _seconds({},.4)
			_check(fired.size()==1 and target.depletion.is_empty(),"retired notification cannot emit a stale depletion")
			if operation=="reset":_near(target.health.current_health,1,.000001,"callback reset is not overwritten by retiring debit")
			_check(target.receipts.size()==1,"health callbacks do not duplicate physical response")
			await _health_finish()
	await _health_begin("API earlier provider listener reset before Health slot")
	var target := _health_target(actor.position+Vector2(31,0))
	target.health.unbind_actor()
	target.provider.damage_resolved.connect(func(_receipt:Dictionary):target.provider.reset_to_full())
	target.health.bind_actor(target.provider)
	await _sync_geometry();await _start_step(0);await _seconds({},.4)
	_check(target.damage.is_empty() and target.health.current_health==3,"existing Health generation check rejects receipt retired before its slot")
	await _health_finish()

func _health_binding_cases() -> void:
	await _health_begin("API health binding ownership and failed rebind")
	var target := _health_target(actor.position+Vector2(31,0))
	var other := _health_target(actor.position+Vector2(300,0),"Other")
	var plain := Node2D.new();world.add_child(plain)
	var detached = load(TARGET_PATH).instantiate()
	_check(not target.provider.bind_receiver(null) and not target.provider.bind_receiver(plain) and not target.provider.bind_receiver(detached.get_node("Hurtbox")),"invalid and detached receiver bindings fail")
	_check(not target.provider.bind_receiver(other.receiver),"second health provider cannot own another occupied receiver")
	_check(target.provider.bind_receiver(target.receiver),"same receiver bind remains idempotent after failed replacement")
	detached.free()
	await _sync_geometry();await _start_step(0);await _until(func():return target.damage.size()==1,{},.5)
	_check(target.health.current_health==2 and other.health.current_health==3,"failed replacement preserves original live accounting")
	await _health_finish()

func _health_pause_cases() -> void:
	for operation in ["tree pause","processing disabled","receiver disabled"]:
		await _health_begin("API health admission "+operation)
		var target := _health_target(actor.position+Vector2(31,0));target.provider.unbind()
		var results := []
		target.receiver.struck.connect(func(payload:Dictionary):
			match operation:
				"tree pause":paused=true
				"processing disabled":target.provider.process_mode=Node.PROCESS_MODE_DISABLED
				"receiver disabled":target.receiver.process_mode=Node.PROCESS_MODE_DISABLED
			results.append(target.provider.consume_strike(payload))
			match operation:
				"tree pause":paused=false
				"processing disabled":target.provider.process_mode=Node.PROCESS_MODE_INHERIT
				"receiver disabled":target.receiver.process_mode=Node.PROCESS_MODE_INHERIT
		)
		target.provider.bind_receiver(target.receiver)
		await _sync_geometry();await _start_step(0);await _seconds({},.4)
		_check(results==[false],"paused or disabled delivery rejects")
		# Disabling only the receiver does not notify a sibling provider; actual
		# delivery resumes once the receiver can process, in the same callback.
		_near(target.health.current_health,2 if operation=="receiver disabled" else 3,.000001,"provider pause/enable boundary fences remainder of same frame")
		await _health_finish()

func _health_movement_parity() -> void:
	var paths := {}
	for mode in ["absent","disabled","unbound","enabled"]:
		await _health_begin("real movement with health "+mode)
		var target := _health_target(actor.position+Vector2(31,0))
		if mode=="absent":target.provider.free()
		elif mode=="disabled":target.provider.enabled=false
		elif mode=="unbound":target.provider.unbind()
		await _sync_geometry();var start_tick:=ticks
		await _start_step(0);await _follow_to(1);await _follow_to(2);await _attack_phase("idle");await _seconds({},.4)
		var path := []
		for row in motor_frames:
			if row.tick>start_tick:path.append({"body":row.bodies[0],"source_pause":row.source_pause,"source_weapon_age":row.source_weapon_age})
		paths[mode]=path
		_check(target.receipts.size()==3 and target.receiver.hits==3,"health attachment choice preserves three real physical contacts")
		_check(target.damage.size()==(3 if mode=="enabled" else 0),"only enabled health accounts for accepted contacts")
		await _health_finish()
	await _health_begin("health off/on complete motor trajectory parity")
	for mode in ["disabled","unbound","enabled"]:
		_check(paths[mode]==paths.absent,"every recorded motor position velocity stun pause collision and source-clock sample matches absent health for "+mode)
	measurements.sample_counts=paths.keys().map(func(key):return {"mode":key,"samples":paths[key].size()})
	await _health_finish()

func _health_api_limits() -> void:
	await _health_begin("API zero huge finite and noncurrent damage")
	var target := _health_target(actor.position+Vector2(300,0))
	var source = load("res://combat_pc/tests/target_health_api_source.gd").new();world.add_child(source)
	await _step()
	var packet := {"source":source,"serial":1,"eligible":true,"phase":&"active","damage":0.0,"contact_position":target.body.position}
	_check(target.provider.consume_strike(packet) and target.health.current_health==3 and target.damage.size()==1,"zero damage accounts once without health loss")
	source.serial=2;packet.serial=2;packet.damage=1.0e300
	_check(target.provider.consume_strike(packet) and target.health.current_health==0 and target.depletion.size()==1,"huge finite damage safely clamps without nonfinite health")
	source.serial=3;packet.serial=3
	_check(target.provider.consume_strike(packet) and target.depletion.size()==1,"further overkill does not repeat depletion")
	target.provider.reset_to_full();await _step();source.serial=4;packet.serial=4
	_check(target.provider.consume_strike(packet) and target.depletion.size()==2,"explicit refill rearms a later zero crossing")
	source.serial=5;packet.serial=5;source.active=false
	_check(not target.provider.consume_strike(packet),"retired source rejects a superficially active captured packet")
	await _health_finish()
	await _health_begin("API source query reentrancy and reset")
	target=_health_target(actor.position+Vector2(300,0));source=load("res://combat_pc/tests/target_health_api_source.gd").new();world.add_child(source);await _step()
	packet={"source":source,"serial":1,"eligible":true,"phase":&"active","damage":1.0,"contact_position":target.body.position}
	var recursive := []
	source.hook=func():recursive.append(target.provider.consume_strike(packet))
	_check(target.provider.consume_strike(packet) and recursive==[false] and target.health.current_health==2,"source query recursion cannot double-debit")
	source.serial=2;packet.serial=2;source.hook=func():target.provider.reset_to_full()
	_check(not target.provider.consume_strike(packet) and target.health.current_health==3,"source query reset invalidates retiring commit")
	await _health_finish()
