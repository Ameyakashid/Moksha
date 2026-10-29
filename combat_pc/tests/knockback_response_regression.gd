extends "res://combat_pc/tests/combo_regression.gd"
## M21: real source/controller, real ContactAdapter, passive existing motor.
## Motor runs normally at -10; the inherited recorder calls PC once at priority 0.
## Explicit malformed/lifecycle calls below are API probes, not physical contacts.

const TARGET_PATH := "res://combat_pc/fixtures/knockback_target.tscn"
const RESPONSE_PATH := "res://combat_pc/components/strike_knockback.tscn"
var targets: Array[Dictionary] = []
var motor_frames: Array[Dictionary] = []
var secondary: Node
var secondary_input := {}
var distance_rows := []

func _run() -> void:
	source_paths.append_array([
		"res://movement/components/movement_motor.gd", "res://movement/resources/player.tres", "res://movement/resources/movement_tuning.gd",
		"res://combat_pc/fixtures/chain_target.gd", "res://combat_pc/fixtures/chain_target.tscn", "res://combat_pc/fixtures/contact_target.gd",
		"res://combat_pc/resources/responsive_chain.tres", "res://combat_pc/resources/melee_chain.gd", "res://combat_pc/resources/melee_step.gd",
		"res://combat_pc/components/strike_knockback.gd", RESPONSE_PATH, "res://combat_pc/resources/knockback_profile.gd",
		"res://combat_pc/resources/knockback_profile.tres", TARGET_PATH, "res://combat_pc/fixtures/knockback_target.gd",
		"res://combat_pc/tests/knockback_response_regression.gd", "res://combat_pc/tests/knockback_response_motor_probe.gd"])
	for path in source_paths:
		if FileAccess.file_exists(path): starting_hashes[path] = FileAccess.get_sha256(path)
	await _direction_strength_cases()
	await _repeat_and_combo_cases()
	await _geometry_cases()
	await _late_pause_case()
	await _no_contact_cases()
	await _lifecycle_cases()
	await _invalid_packet_cases()
	await _distinct_source_case()
	await _off_parity_cases()
	await _profile_cases()
	await _cap_cases()
	await _binding_cases()
	await _motor_hook_cases()
	var hashes := {}; var stable := true
	for path in starting_hashes:
		hashes[path] = FileAccess.get_sha256(path)
		stable = stable and hashes[path] == starting_hashes[path]
	if not stable: failures.append("Production source changed during focused run; rerun final code")
	var output := {"milestone":21, "suite":"detachable physical strike knockback", "physics_hz":hz,
		"engine":Engine.get_version_info(), "checks":checks, "failures":failures, "scenarios":scenarios,
		"production_hash_stable_during_run":stable, "starting_hashes":starting_hashes, "hashes":hashes,
		"distance_comparison":distance_rows,
		"execution":"One production PC physics_tick per actual engine callback; passive stock MovementMotor owns its own callback. Real ContactAdapter overlap and obstruction queries deliver strikes. Explicit API replay, malformed input, lifecycle and tuning probes are separately named. Trace frames are evidence, never independent cases or assertions.",
		"limits":["Passive CharacterBody2D receiver only, no NPC AI or broad moving-platform guarantees.", "No health, damage resolver, sonar or attacker authority changes; source hashes audit preserved v24.", "Headless physics acceptance; visual review is separate."]}
	FileAccess.open("res://combat_pc/tests/knockback_response_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(output), "  ") + "\n")
	print("KNOCKBACK_RESPONSE %dHz: %d scenarios, %d assertions, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _knockback_begin(label: String) -> void:
	targets = []; motor_frames = []; secondary = null; secondary_input = {}
	await _combo_begin(label)
	driver.process_physics_priority = 0
	actor.melee_chain = load("res://combat_pc/resources/responsive_chain.tres").duplicate(true)

func _knockback_target(at: Vector2, label := "KnockbackTarget", hook_probe := false) -> Dictionary:
	var body = load(TARGET_PATH).instantiate()
	if hook_probe:body.set_script(load("res://combat_pc/tests/knockback_response_motor_probe.gd"))
	body.name = label; body.position = at; world.add_child(body)
	var receiver = body.get_node("Hurtbox")
	var component = body.get_node("Knockback")
	var target := {"body":body, "receiver":receiver, "component":component, "receipts":[], "delivered":[], "start":at}
	targets.append(target)
	component.knockback_applied.connect(func(receipt: Dictionary):
		target.receipts.append({"receipt":receipt, "velocity":body.velocity, "pause":body.pause_left, "stun":body.stun_left,
			"source_pause":float(actor.hitpause_remaining), "position":body.global_position, "tick":ticks, "readonly":receipt.is_read_only()}))
	receiver.struck.connect(func(payload: Dictionary): target.delivered.append(payload.duplicate(true)))
	return target

func _motor_sample(target: Dictionary) -> Dictionary:
	var body = target.body
	if not is_instance_valid(body): return {"freed":true}
	var shape: CollisionShape2D
	for child in body.get_children():
		if child is CollisionShape2D: shape = child; break
	var bounds: Rect2 = body.global_transform * shape.transform * shape.shape.get_rect()
	var depth := 0.0
	for box in boxes:
		if not is_instance_valid(box.body): continue
		var overlap: Rect2 = bounds.intersection(Rect2(box.body.global_position-box.size*.5, box.size))
		if overlap.has_area(): depth = maxf(depth, minf(overlap.size.x, overlap.size.y))
	return {"position":body.global_position, "velocity":body.velocity, "pause":body.pause_left, "stun":body.stun_left,
		"floor":body.is_on_floor(), "wall":body.is_on_wall(), "ceiling":body.is_on_ceiling(), "normal":body.last_collision_normal,
		"solid_overlap_depth":depth, "bounds": {"position":bounds.position,"size":bounds.size},
		"applied_count":target.component.applied_count if is_instance_valid(target.component) else -1}

func physics_sample(delta: float) -> void:
	super.physics_sample(delta)
	if is_instance_valid(secondary): secondary.physics_tick(delta, secondary_input)
	var body_rows := []
	for target in targets: body_rows.append(_motor_sample(target))
	motor_frames.append({"tick":ticks, "engine_tick":Engine.get_physics_frames(), "source_pause":float(actor.hitpause_remaining),
		"source_weapon_age":float(actor.telemetry().weapon_elapsed), "bodies":body_rows})

func _knockback_finish() -> void:
	var saved_motors: Array = _safe(motor_frames)
	var saved_targets := []
	for target in targets:
		saved_targets.append({"receipts":_safe(target.receipts), "delivered":_safe(target.delivered),
			"diagnostics":_safe(target.component.diagnostic_snapshot()) if is_instance_valid(target.component) else {"removed":true}})
	await _finish()
	scenarios.back().motor_frames = saved_motors
	scenarios.back().knockback_targets = saved_targets
	targets = []; secondary = null

func _await_hit(target: Dictionary) -> bool:
	return await _until(func(): return not target.receipts.is_empty(), {}, .6)

func _direction_strength_cases() -> void:
	for direction in [-1, 1]:
		for step in [0, 1, 2]:
			await _knockback_begin("real signed step%d direction%d" % [step,direction])
			actor.reset_actor(actor.position, direction)
			await _start_step(step)
			var target := _knockback_target(actor.position+Vector2(direction*31,0))
			await _sync_geometry()
			_check(await _await_hit(target), "real live strike reaches composed target")
			if target.receipts.is_empty(): await _knockback_finish(); continue
			var receipt: Dictionary = target.receipts[0].receipt
			var expected: Vector2 = actor.melee_chain.steps[step].impulse * Vector2(direction*.55,1)
			_check(receipt.applied_velocity.distance_to(expected)<.001 and target.receipts[0].velocity.distance_to(expected)<.001,
				"already-signed world impulse maps once to exact replacement motor velocity")
			_check(signf(receipt.applied_velocity.x)==direction and receipt.applied_velocity.y<0,
				"left and right keep attacker sign without double-facing multiplication")
			_near(receipt.pause_seconds, actor.melee_chain.steps[step].hitpause_seconds, .000001, "target copies current confirmed source pause")
			_near(target.receipts[0].stun, .18, .000001, "existing motor owns authored stun")
			_check(target.receipts[0].readonly, "published receipt is immutable value data")
			var impact_tick: int = target.receipts[0].tick
			await _seconds({}, .55)
			_check(target.receipts.size()==1 and target.receiver.hits==1 and _count("hitpause_started")==1,
				"one admitted strike has one receiver effect and one attacker pause")
			var aligned := true; var freeze_ok := true; var previous := {}; var resume_target := -1; var resume_source := -1
			var max_depth := 0.0
			for row in motor_frames:
				if row.tick < impact_tick: continue
				var sample: Dictionary = row.bodies[0]
				aligned = aligned and absf(sample.pause-row.source_pause)<.000001
				max_depth = maxf(max_depth, sample.solid_overlap_depth)
				if not previous.is_empty():
					if previous.bodies[0].pause>0:
						freeze_ok = freeze_ok and sample.position==previous.bodies[0].position and sample.stun==previous.bodies[0].stun
					elif resume_target<0 and sample.position!=previous.bodies[0].position: resume_target=row.tick
					if previous.source_pause<=0 and resume_source<0 and row.source_weapon_age!=previous.source_weapon_age: resume_source=row.tick
				previous=row
			_check(aligned and freeze_ok and resume_source==resume_target, "both clocks freeze together and resume on the same actual engine callback")
			_check(max_depth<=.081 and target.body.is_on_floor(), "lift and gravity settle onto real floor without tunneling")
			var displacement: float = (target.body.position.x-target.start.x)*direction
			_check(displacement>0 and target.body.velocity.length()<.001 and target.body.stun_left==0, "finite knockback settles through unchanged motor braking")
			distance_rows.append({"direction":direction,"step":step,"distance":displacement})
			measurements.displacement=displacement; measurements.resume_target_tick=resume_target; measurements.resume_source_tick=resume_source
			await _knockback_finish()
	await _knockback_begin("authored finisher distance comparison")
	for direction in [-1,1]:
		var rows: Array = distance_rows.filter(func(row): return row.direction==direction)
		_check(rows.size()==3 and rows[2].distance>rows[1].distance and rows[1].distance>rows[0].distance,
			"Finisher travels farther than Backhand, which travels farther than Slash direction%d" % direction)
	measurements.distances=distance_rows.duplicate(true)
	await _knockback_finish()

func _cap_cases() -> void:
	for magnitude in [5000.0,1.0e38]:
		await _knockback_begin("real authored oversized impulse "+str(magnitude))
		actor.melee_chain.steps[0].impulse=Vector2(magnitude,-magnitude)
		var target:=_knockback_target(actor.position+Vector2(31,0))
		await _sync_geometry();await _start_step(0);await _await_hit(target)
		_check(target.receipts.size()==1,"oversized finite authored strike is accepted once")
		if not target.receipts.is_empty():
			var applied:Vector2=target.receipts[0].receipt.applied_velocity
			_check(applied.is_finite() and absf(applied.length()-420)<.001 and applied.x>0 and applied.y<0,
				"total vector cap stays finite at420 even when squared magnitude would overflow")
			_check(applied.normalized().distance_to(Vector2(.55,-1).normalized())<.001,"cap preserves scaled world direction")
		await _seconds({},.8)
		var depth:=0.0
		for row in motor_frames:
			if not row.bodies.is_empty():depth=maxf(depth,row.bodies[0].solid_overlap_depth)
		_check(depth<=.081 and target.body.is_on_floor(),"bounded impulse returns to floor through unchanged solver")
		await _knockback_finish()
	for copy_pause in [true,false]:
		await _knockback_begin("real source remaining pause cap copy="+str(copy_pause))
		var target:=_knockback_target(actor.position+Vector2(31,0));target.component.unbind()
		target.component.profile=target.component.profile.duplicate(true);target.component.profile.copy_source_pause=copy_pause
		target.receiver.struck.connect(func(_payload:Dictionary):actor.apply_hitpause(.5))
		target.component.bind_receiver(target.receiver,target.body)
		await _sync_geometry();await _start_step(0);await _await_hit(target)
		_check(target.receipts.size()==1,"real confirmed strike remains current inside paused sample scope")
		if not target.receipts.is_empty():
			_near(target.receipts[0].pause,.12 if copy_pause else 0.0,.000001,"target pause follows opt-in remaining-clock cap")
			_near(actor.hitpause_remaining,.5,.000001,"response neither extends nor replaces source pause")
		_check(_count("hitpause_started")==1,"response never adds a second attacker pause event")
		await _knockback_finish()

func _binding_cases() -> void:
	await _knockback_begin("API binding ownership and disabled motor")
	var target:=_knockback_target(actor.position+Vector2(31,0))
	var other:=_knockback_target(actor.position+Vector2(300,0),"Other")
	var detached=load(TARGET_PATH).instantiate()
	var plain:=Node2D.new();world.add_child(plain)
	_check(not target.component.bind_receiver(null,target.body) and not target.component.bind_receiver(plain,target.body)
		and not target.component.bind_receiver(detached.get_node("Hurtbox"),detached),"null incompatible and detached endpoints are refused")
	_check(not target.component.bind_receiver(target.receiver,other.body),"receiver cannot bind to unrelated motor hierarchy")
	var duplicate=load(RESPONSE_PATH).instantiate();duplicate.receiver_path=NodePath();duplicate.motor_path=NodePath();target.body.add_child(duplicate)
	_check(not duplicate.bind_receiver(target.receiver,target.body),"one receiver cannot acquire two response owners")
	duplicate.free();detached.free()
	_check(target.component.bind_receiver(target.receiver,target.body),"same live receiver/motor bind is idempotent")
	await _sync_geometry();target.body.set_physics_process(false)
	await _start_step(0);await _seconds({},.35)
	_check(target.receiver.hits==1 and target.receipts.is_empty() and target.body.velocity==Vector2.ZERO,
		"stopped motor rejects physical response while visual receiver continues")
	target.body.set_physics_process(true)
	await _knockback_finish()

func _motor_hook_cases() -> void:
	for operation in ["reset","unbind","disable","source reset"]:
		await _knockback_begin("explicit motor override callback "+operation)
		var target:=_knockback_target(actor.position+Vector2(31,0),"HookProbe",true)
		target.body.impulse_hook=func():
			match operation:
				"reset":target.body.reset_at(target.start)
				"unbind":target.component.unbind()
				"disable":target.component.enabled=false
				"source reset":actor.reset_actor(actor.position,1)
		await _sync_geometry();await _start_step(0);await _seconds({},.3)
		_check(target.body.observed_impulses==1,"probe delegates exactly one admitted impulse to production motor")
		_check(target.receipts.is_empty() and target.body.pause_left==0,"callback retirement prevents old follow-on pause and receipt publication")
		if operation=="reset":_check(target.body.position.distance_to(target.start)<.081 and target.body.velocity==Vector2.ZERO,"callback reset cannot be followed by old impulse replay")
		await _knockback_finish()

func _repeat_and_combo_cases() -> void:
	await _knockback_begin("real three-step physical chain")
	var target := _knockback_target(actor.position+Vector2(31,0))
	await _sync_geometry()
	await _start_step(0); await _follow_to(1); await _follow_to(2); await _attack_phase("idle")
	await _seconds({}, .45)
	var steps := []
	for payload in target.delivered: steps.append(payload.step_index)
	_check(steps==[0,1,2] and target.receipts.size()==3, "three deliberately pressed real combo steps each affect moving target exactly once")
	_check(_count("hitpause_started")==3 and contact_receipts.size()==3, "three source pauses match three real contact confirmations")
	await _knockback_finish()
	await _knockback_begin("API duplicate inside actual struck callback")
	target=_knockback_target(actor.position+Vector2(31,0))
	var duplicate_results := []
	target.receiver.struck.connect(func(payload:Dictionary):
		var before: Vector2=target.body.velocity
		duplicate_results.append({"accepted":target.component.consume_strike(payload),"unchanged":target.body.velocity==before}))
	await _sync_geometry(); await _start_step(0); await _await_hit(target)
	_check(duplicate_results.size()==1 and not duplicate_results[0].accepted and duplicate_results[0].unchanged and target.receipts.size()==1,
		"same source/serial repeated synchronously cannot double physical effect")
	await _seconds({}, .5)
	target.body.reset_at(actor.position+Vector2(31,0)); target.component.reset_history()
	await _step(); await _step({"attack":true}); await _until(func(): return target.receipts.size()==2,{},.6)
	_check(target.receipts.size()==2 and target.receipts[0].receipt.serial!=target.receipts[1].receipt.serial,
		"later distinct real strike remains eligible after reset")
	await _knockback_finish()

func _geometry_cases() -> void:
	for surface in ["wall right","wall left","ceiling"]:
		await _knockback_begin("real solver collision "+surface)
		var direction := -1 if surface=="wall left" else 1
		actor.reset_actor(actor.position,direction)
		await _start_step(2)
		var target := _knockback_target(actor.position+Vector2(direction*31,0))
		if surface=="ceiling": _box(Vector2(target.body.position.x,159),Vector2(28,4))
		else: _box(target.body.position+Vector2(direction*21,-35),Vector2(4,150))
		await _sync_geometry(); _check(await _await_hit(target),"actual finisher contacts target before terrain response")
		await _seconds({}, .55)
		var collision := false; var depth := 0.0
		for row in motor_frames:
			if row.bodies.is_empty(): continue
			collision = collision or row.bodies[0].ceiling if surface=="ceiling" else collision or row.bodies[0].wall
			depth=maxf(depth,row.bodies[0].solid_overlap_depth)
		_check(collision,"existing move_and_slide reports intended solid collision")
		_check(depth<=.081 and target.body.is_on_floor(),"all observed body rectangles remain outside solids and settle on floor")
		measurements.maximum_solid_overlap=depth
		await _knockback_finish()

func _late_pause_case() -> void:
	await _knockback_begin("new target later in same live swing")
	var first := _knockback_target(actor.position+Vector2(31,0),"First")
	var late := _knockback_target(actor.position+Vector2(300,0),"Late")
	await _sync_geometry(); await _start_step(0); await _await_hit(first)
	await _until(func(): return actor.hitpause_remaining<=0,{},.2)
	_check(actor.weapon_phase==&"active" and _count("hitpause_started")==1,"same swing remains active after first confirmed pause drains")
	late.body.reset_at(actor.position+Vector2(32,0))
	await _until(func(): return late.receipts.size()==1,{},.12)
	_check(late.receipts.size()==1 and first.receipts.size()==1,"previously untouched target gets one late current strike")
	if not late.receipts.is_empty():
		_check(late.receipts[0].receipt.pause_seconds==0 and late.receipts[0].pause==0,
			"late target copies zero remaining source pause without restarting authored pause")
	_check(_count("hitpause_started")==1,"late physical contact does not add attacker pause")
	await _knockback_finish()

func _no_contact_cases() -> void:
	for route in ["miss","terrain blocked"]:
		await _knockback_begin("real "+route+" does not knock back")
		var target := _knockback_target(actor.position+Vector2(300 if route=="miss" else 31,0))
		if route=="terrain blocked": _box(actor.position+Vector2(18,-35),Vector2(2,100))
		await _sync_geometry(); var start:Vector2=target.body.position
		await _start_step(0); await _seconds({},.5)
		_check(target.receipts.is_empty() and target.receiver.hits==0 and target.body.position.distance_to(start)<.001,
			"unconfirmed swing cannot move passive receiver")
		_check(_count("hitpause_started")==0,"miss or occluded target never starts source hitpause")
		await _knockback_finish()

func _lifecycle_cases() -> void:
	for operation in ["reset","unbind","disable","detach","rebind","remove","source reset"]:
		await _knockback_begin("real struck callback before component "+operation)
		var target := _knockback_target(actor.position+Vector2(31,0))
		target.component.unbind()
		var fired := []
		var retire := func(_payload:Dictionary):
			if not fired.is_empty():return
			fired.append(true)
			match operation:
				"reset": target.component.reset_history(); target.body.reset_at(target.start)
				"unbind": target.component.unbind()
				"disable": target.component.enabled=false
				"detach": target.body.remove_child(target.component)
				"rebind": target.component.unbind(); target.component.bind_receiver(target.receiver,target.body)
				"remove": target.component.queue_free()
				"source reset": actor.reset_actor(actor.position,1)
		target.receiver.struck.connect(retire)
		target.component.bind_receiver(target.receiver,target.body)
		await _sync_geometry(); await _start_step(0); await _seconds({},.4)
		_check(fired.size()==1 and target.receiver.hits==(0 if operation=="reset" else 1) and target.receipts.is_empty(),"receiver signal is real, callback retirement prevents subsequent physical effect")
		_check(target.body.position.distance_to(target.start)<.081 and target.body.velocity.length()<.001,"retired delivery cannot leave a pending old impulse")
		if operation=="detach":target.component.free()
		await _knockback_finish()
	for operation in ["reset","unbind rebind","disable enable","replace","diagnostics"]:
		await _knockback_begin("API replay after applied "+operation)
		var target := _knockback_target(actor.position+Vector2(31,0))
		await _sync_geometry(); await _start_step(0); await _await_hit(target)
		if target.delivered.is_empty():_check(false,"setup produced original payload");await _knockback_finish();continue
		var old:Dictionary=target.delivered[0]
		match operation:
			"reset":target.component.reset_history()
			"unbind rebind":target.component.unbind();target.component.bind_receiver(target.receiver,target.body)
			"disable enable":target.component.enabled=false;target.component.enabled=true
			"replace":
				target.component.free();target.component=load(RESPONSE_PATH).instantiate();target.component.receiver_path=NodePath("../Hurtbox");target.body.add_child(target.component)
			"diagnostics":target.component.reset_diagnostics()
		await _step()
		var velocity:Vector2=target.body.velocity;var pause:float=target.body.pause_left
		_check(not target.component.consume_strike(old) and target.body.velocity==velocity and target.body.pause_left==pause,
			"retained receiver identity rejects old source/serial after lifecycle boundary")
		var live_replays:=[]
		actor.strike_sample.connect(func(_source:Node2D,snapshot:Dictionary):
			if snapshot.serial!=old.serial or not live_replays.is_empty():return
			var before:Vector2=target.body.velocity
			var current:bool=actor.is_strike_current(old.serial)
			var accepted:bool=target.component.consume_strike(old)
			live_replays.append({"source_current":current,"accepted":accepted,"unchanged":target.body.velocity==before,"reason":target.component.last_reason}))
		await _until(func():return not live_replays.is_empty(),{},.2)
		_check(live_replays.size()==1 and live_replays[0].source_current and not live_replays[0].accepted and live_replays[0].unchanged and live_replays[0].reason==&"duplicate",
			"old identity stays consumed even when original source becomes eligible again after pause")
		measurements.live_replay=live_replays
		await _seconds({},.35)
		_check(target.body.stun_left==0 and target.body.pause_left==0,"no deferred old effect appears after clocks settle")
		await _knockback_finish()
	await _knockback_begin("real strike confirmation callback resets source")
	var target := _knockback_target(actor.position+Vector2(31,0))
	actor.movement_event.connect(func(event:StringName,_data:Dictionary):
		if event==&"strike_confirmed":actor.reset_actor(actor.position,1))
	await _sync_geometry();await _start_step(0);await _seconds({},.35)
	_check(target.receiver.hits==0 and target.receipts.is_empty() and target.body.position.distance_to(target.start)<.081,
		"source reset during authoritative confirmation cancels before receiver physical effect")
	_check(_count("hitpause_started")==0,"canceled confirmation adds no source pause")
	await _knockback_finish()

func _invalid_packet_cases() -> void:
	await _knockback_begin("API malformed packets during real live delivery")
	var target := _knockback_target(actor.position+Vector2(31,0));target.component.unbind()
	var plain:=Node2D.new();world.add_child(plain)
	var results:=[]
	target.receiver.struck.connect(func(payload:Dictionary):
		var variants := [{"serial":-1},{"serial":1.0},{"serial":"1"},{"serial":true},{"eligible":1},{"eligible":false},{"eligible":"yes"},{"phase":"recovery"},{"phase":0},
			{"impulse":Vector2(NAN,0)},{"impulse":Vector2(INF,0)},{"impulse":"bad"},{"contact_position":Vector2(0,INF)},
			{"source":null},{"source":plain},{"source":target.body},{"source":target.receiver},{"source":7},{"source":Vector2.ONE},{"source":Resource.new()},{"impulse":0},{"contact_position":[]}]
		for changed in variants:
			var before:Vector2=target.body.velocity
			var accepted:bool=target.component.consume_strike(payload.merged(changed,true))
			results.append({"fields":changed.keys(),"accepted":accepted,"unchanged":target.body.velocity==before})
		for missing in ["serial","eligible","phase","impulse","contact_position","source"]:
			var copy:=payload.duplicate(true);copy.erase(missing)
			results.append({"missing":missing,"accepted":target.component.consume_strike(copy),"unchanged":target.body.velocity==Vector2.ZERO}))
	target.component.bind_receiver(target.receiver,target.body)
	await _sync_geometry();await _start_step(0);await _await_hit(target)
	_check(results.size()==28 and results.all(func(row):return not row.accepted and row.unchanged),"twenty-eight malformed or unsupported packets reject before motion inside valid live source scope")
	_check(target.receipts.size()==1 and target.component.applied_count==1,"rejected malformed packets do not consume eventual valid real strike")
	measurements.rejections=results
	await _knockback_finish()

func _distinct_source_case() -> void:
	await _knockback_begin("real distinct sources share serial")
	var target:=_knockback_target(Vector2(132,200))
	secondary=PLAYER.instantiate();secondary.automatic_physics=false;secondary.position=Vector2(164,200)
	secondary.melee_chain=load("res://combat_pc/resources/responsive_chain.tres").duplicate(true)
	world.add_child(secondary);secondary.reset_actor(secondary.position,-1)
	await _sync_geometry();secondary_input={"attack":true};await _step({"attack":true});secondary_input={}
	await _until(func():return target.receipts.size()>=2,{},.5)
	_check(target.receipts.size()==2,"two live actors each affect same physical target")
	if target.receipts.size()==2:
		var a:Dictionary=target.receipts[0].receipt;var b:Dictionary=target.receipts[1].receipt
		_check(a.serial==b.serial and a.source_id!=b.source_id and a.applied_velocity.x*b.applied_velocity.x<0,
			"dedup uses source identity plus serial, with opposite signed effects")
	await _knockback_finish()

func _off_parity_cases() -> void:
	var paths:Dictionary={}
	for mode in ["absent","disabled","unbound"]:
		await _knockback_begin("base motor trajectory "+mode)
		var target:=_knockback_target(actor.position+Vector2(31,0))
		if mode=="absent":target.component.free()
		elif mode=="disabled":target.component.enabled=false
		else:target.component.unbind()
		await _sync_geometry();target.body.apply_impulse(Vector2(80,-150),.18)
		var start_tick:=ticks
		await _start_step(0);await _seconds({},.6)
		var path:=[]
		for row in motor_frames:
			if row.tick>start_tick:path.append(row.bodies[0])
		paths[mode]=path
		_check(target.receipts.is_empty() and target.receiver.hits==1,"optional response off preserves real visual-only contact fixture")
		await _knockback_finish()
	await _knockback_begin("optional component off parity comparison")
	var maximum_position_error:=0.0;var maximum_velocity_error:=0.0;var lengths:=true
	for mode in ["disabled","unbound"]:
		lengths=lengths and paths[mode].size()==paths.absent.size()
		for index in mini(paths[mode].size(),paths.absent.size()):
			maximum_position_error=maxf(maximum_position_error,paths[mode][index].position.distance_to(paths.absent[index].position))
			maximum_velocity_error=maxf(maximum_velocity_error,paths[mode][index].velocity.distance_to(paths.absent[index].velocity))
	_check(lengths and maximum_position_error<.001 and maximum_velocity_error<.001,"absent disabled and unbound component preserve full ordinary motor trajectory")
	measurements.maximum_position_error=maximum_position_error;measurements.maximum_velocity_error=maximum_velocity_error
	await _knockback_finish()

func _profile_cases() -> void:
	await _knockback_begin("shared response resources and defensive tuning")
	var first:=_knockback_target(actor.position+Vector2(31,0),"First")
	var second:=_knockback_target(actor.position+Vector2(39,0),"Second")
	var profile:Resource=first.component.profile
	var before:Dictionary=_resource_values(profile)
	_check(profile==second.component.profile,"default profile is a shared resource")
	await _sync_geometry();await _start_step(0);await _await_hit(first)
	_check(first.receipts.size()==1 and second.receipts.size()==1,"shared profile supports two real receivers in same strike")
	_check(before==_resource_values(profile),"applying and recording response never mutates shared tuning")
	var copy:Dictionary=first.component.last_receipt;copy.applied_velocity=Vector2(-9999,-9999)
	_check(first.component.last_receipt.applied_velocity!=copy.applied_velocity,"diagnostic copies cannot mutate stored response")
	var invalid:=[]
	for field in ["stun_seconds","maximum_speed","maximum_pause_seconds"]:
		for value in [NAN,INF,-1.0]:
			var candidate=profile.duplicate(true);candidate.set(field,value);invalid.append(not candidate.is_valid_profile())
	for value in [Vector2(NAN,1),Vector2(-1,1),Vector2(5,1)]:
		var candidate=profile.duplicate(true);candidate.velocity_scale=value;invalid.append(not candidate.is_valid_profile())
	_check(invalid.size()==12 and invalid.all(func(value):return value),"nonfinite negative and out-of-bound profile values reject")
	await _knockback_finish()
