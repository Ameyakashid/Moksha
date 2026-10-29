extends "res://simulation/tests/actor_cargo_regression.gd"
## Independent reviewer experiment only. Geometry/material/lifecycle changes are
## labelled setup/API probes. Observer overrides do not assign motion outcomes.
const FROZEN_PLAYER_SHA := "1468d9d19969ec3848332861a61f374b83d328bcbcfbeb013c228b895168ee92"
class RequestObserver extends "res://simulation/tests/actor_cargo_transport_probe.gd":
	var horizontal_log: Array[Dictionary] = []
	var sweep_log: Array[Dictionary] = []
	var contact_log: Array[Dictionary] = []
	var carry_log: Array[Dictionary] = []
	var pending_log: Array[Dictionary] = []
	func _update_horizontal(dt: float) -> void:
		var cached := _pressure_request_x
		var previous := velocity.x
		super._update_horizontal(dt)
		horizontal_log.append({"frame":Engine.get_physics_frames(),"cached_before":cached,"previous_x":previous,"output_x":velocity.x,"action":main_action,"weapon":weapon_phase,"grounded":grounded})
	func _respond_rigid_contact(hit: KinematicCollision2D, follows: bool) -> void:
		var other := hit.get_collider()
		var before := rigid_contact_impulse_this_tick
		var incoming := velocity
		super._respond_rigid_contact(hit,follows)
		var support_id:=_support.get_instance_id() if is_instance_valid(_support) else 0
		var carried_x:=0.0
		for e in carry_log:
			if e.frame==Engine.get_physics_frames() and e.body_id==support_id: carried_x+=Vector2(e.actual).x
		for e in pending_log:
			if e.frame==Engine.get_physics_frames()-1 and e.body_id==support_id: carried_x+=Vector2(e.actual).x
		contact_log.append({"frame":Engine.get_physics_frames(),"rigid":other is RigidBody2D,"body_id":other.get_instance_id() if is_instance_valid(other) else 0,"normal":hit.get_normal(),"incoming":incoming,"spent":rigid_contact_impulse_this_tick-before,"request":_pressure_request_x,"expected_carrier_x":carried_x/_step_delta,"receipt_carrier_x":Vector2(last_rigid_contact.get("solved_carrier_velocity",Vector2.ZERO)).x})
	func _sweep_segment(motion: Vector2, follows: bool) -> Vector2:
		var before := global_position
		var result := super._sweep_segment(motion,follows)
		sweep_log.append({"frame":Engine.get_physics_frames(),"motion":motion,"actual":global_position-before,"velocity":velocity,"request":_pressure_request_x,"remainder":result})
		return result
	func _transport_with_body(displacement: Vector2, body: Node2D) -> bool:
		var before := global_position
		var clear := super._transport_with_body(displacement,body)
		carry_log.append({"frame":Engine.get_physics_frames(),"body_id":body.get_instance_id() if is_instance_valid(body) else 0,"requested":displacement,"actual":global_position-before,"clear":clear})
		return clear
	func _apply_pending_transport(dt: float) -> void:
		var before:=global_position
		var body:=_support
		super._apply_pending_transport(dt)
		if is_instance_valid(body) and body is AnimatableBody2D:
			pending_log.append({"frame":Engine.get_physics_frames(),"body_id":body.get_instance_id(),"actual":global_position-before})

var pin_wall: StaticBody2D
var gaps: Array[String] = []

func make_actor(role: String, at: Vector2, mask := 9) -> Node2D:
	var result := ACTOR.instantiate()
	result.set_script(RequestObserver)
	result.automatic_physics = false
	result.position = at
	var config: Resource = load("res://demo/resources/player_contact.tres" if role == "PC" else "res://demo/resources/sentinel_contact.tres").duplicate(true)
	config.body_mask=mask; config.terrain_mask=mask
	result.get_node("ContactConfig").profile=config
	var source: Node = RawSource.new() if role=="PC" else NPC.new()
	source.name="InputSource"; result.add_child(source)
	if role=="NPC":
		var policy:=IntentPolicy.new(); policy.name="PatrolPolicy"; result.add_child(policy)
	world.add_child(result)
	check(not result.automatic_physics and result.get_node("IntentDriver")._owns_tick,"single genuine input driver owns observed controller")
	return result

func raw(role: String, x: float, y := 0.0, jump := false, attack := false) -> void:
	if role=="PC": actor.get_node("InputSource").raw={"right":maxf(x,0),"left":maxf(-x,0),"down":maxf(y,0),"up":maxf(-y,0),"jump":jump,"attack":attack}
	else: actor.get_node("PatrolPolicy").intent={"move":Vector2(x,y),"jump":jump,"attack":attack}

func warm_pinned(role: String, ceiling := false) -> bool:
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	pin_wall=surface(Vector2(205,140),Vector2(20,120))
	if ceiling: surface(Vector2(145,159),Vector2(130,10))
	cargo=make_cargo(Vector2(180,186)); cargo.lock_rotation=true
	actor=make_actor(role,Vector2(120,200)); await frames(12); raw(role,1)
	for i in hz*2:
		await frames(1)
		if actor._pressure_request_x>210 and actor._pressure_request_frame==Engine.get_physics_frames() and absf(actor.velocity.x)<0.01:
			check(true,"real repeated side sweeps accumulate request while output velocity is blocked")
			return true
	check(false,"real repeated side sweeps accumulate request while output velocity is blocked")
	records.append({"scenario":label,"warm_position":actor.position,"warm_velocity":actor.velocity,"warm_request":actor._pressure_request_x,"contacts":actor.contact_log.slice(maxi(0,actor.contact_log.size()-8))})
	return false

func pinned(role: String, ceiling: bool) -> void:
	label=role+" independent pinned"+(" corner" if ceiling else " wall")
	if not await warm_pinned(role,ceiling): await finish(); return
	var start:=actor.position; var largest_step:=0.0; var largest_velocity:=0.0; var largest_impulse:=0.0; var budget:=0.0
	var blocked_velocity:=0.0; var blocked_frames:=0; var trace:Array[Dictionary]=[]
	for i in hz:
		var before:=actor.position; await frames(1)
		largest_step=maxf(largest_step,actor.position.distance_to(before)); largest_velocity=maxf(largest_velocity,absf(actor.velocity.x)); largest_impulse=maxf(largest_impulse,actor.rigid_contact_impulse_this_tick); budget+=actor.rigid_contact_impulse_this_tick
		var sides:Array=actor.contact_log.filter(func(e):return e.frame==Engine.get_physics_frames() and absf(Vector2(e.normal).x)>0.65)
		if not sides.is_empty(): blocked_frames+=1; blocked_velocity=maxf(blocked_velocity,absf(actor.velocity.x))
		trace.append({"frame":Engine.get_physics_frames(),"actual":actor.position-before,"velocity":actor.velocity,"side_contacts":sides,"last_sweep":actor.sweep_log.back() if not actor.sweep_log.is_empty() else {},"cargo_velocity":cargo.linear_velocity})
	check(blocked_frames>hz/3 and blocked_velocity<0.01,"actual side-blocked frames expose zero output velocity")
	check(actor.position.x+8<=cargo.position.x-14+0.1 and cargo.position.x+14<=195.1,"actor and unfrozen crate remain on near side of actual constraints")
	check(largest_impulse<=1400.0/hz+0.001 and budget<=1400.001,"all repeated sweeps share one dt-scaled force budget")
	check(cargo.hit_count==0 and cargo.charge==0,"sustained pressure never manufactures weapon launch or charge")
	records.append({"scenario":label,"actual":actor.position-start,"largest_step":largest_step,"largest_output_x":largest_velocity,"largest_blocked_output_x":blocked_velocity,"blocked_frames":blocked_frames,"largest_impulse":largest_impulse,"total_impulse":budget,"request":actor._pressure_request_x,"cargo":cargo.position,"trace":trace})
	await finish()

func mutation(role: String, mode: String) -> void:
	label=role+" independent transition "+mode
	if not await warm_pinned(role): await finish(); return
	var initial_request:float=actor._pressure_request_x
	var initial_frame:=Engine.get_physics_frames(); var initial_position:=actor.position
	var first_accel:float=actor.profile.ground_acceleration/hz
	match mode:
		"neutral": raw(role,0)
		"reverse": raw(role,-1)
		"jump": raw(role,1,0,true)
		"attack": actor.get_node("ContactAdapter").enabled=false; raw(role,1,0,false,true)
		"hurt": actor.receive_attack({"amount":1.0,"stun_seconds":0.12,"hitpause":0.05,"impulse":Vector2.ZERO,"blockable":false,"parryable":false,"rollable":false})
		"hurt_finish":
			actor.receive_attack({"amount":1.0,"stun_seconds":0.12,"hitpause":0.0,"impulse":Vector2.ZERO,"blockable":false,"parryable":false,"rollable":false})
			actor.finish_main_action()
		"reset": actor.reset_actor(actor.position); raw(role,1)
		"crouch": raw(role,1,1)
		"force_config": actor.material_profile.maximum_push_force=1200.0
		"replace_config": actor.material_profile=actor.material_profile.duplicate(true)
		"disable_config": actor.material_profile.push_enabled=false
		"remove": cargo.queue_free()
		"freeze": cargo.freeze=true
		"away": pin_wall.queue_free(); cargo.apply_central_impulse((Vector2(500,0)-cargo.linear_velocity)*cargo.mass)
		"cargo_lifecycle": cargo.invalidate_pending_contacts()
		"cargo_shape": cargo.get_node("CollisionShape2D").shape.size=Vector2(26,28)
		"cargo_mass": cargo.mass=2.0
		"cargo_material": cargo.physics_material_override.friction=0.0
		"static_later": surface(Vector2(actor.position.x+13.005,150),Vector2(10,100))
	await frames(1)
	var samples:Array=actor.horizontal_log.filter(func(e):return e.frame>initial_frame)
	var first:Dictionary=samples[0] if not samples.is_empty() else {}
	var after_request:float=actor._pressure_request_x
	var spent:float=actor.rigid_contact_impulse_this_tick
	if mode in ["remove","freeze","force_config","replace_config","disable_config","reset","cargo_lifecycle","cargo_shape","cargo_mass","cargo_material","hurt_finish"]:
		var no_reuse:bool=not first.is_empty() and absf(first.output_x)<=first_accel+0.05
		check(no_reuse,"retired state cannot reuse previous blocked demand in next acceleration")
		if not no_reuse: gaps.append(label)
	elif mode=="neutral": check(spent==0 and actor._pressure_request_body==null,"neutral input immediately retires request without force")
	elif mode=="reverse": check(not first.is_empty() and first.output_x<=0 and absf(first.output_x)<=first_accel+0.05,"reversal starts normal opposite acceleration without stored demand")
	elif mode=="crouch": check(not first.is_empty() and absf(first.output_x)<=actor.profile.crouch_speed+0.01,"remembered request obeys current crouch limit")
	elif mode in ["jump","attack","hurt"]:
		check(spent==0,"new airborne/weapon/hurt owner cannot spend ground pressure")
		if mode!="hurt": check(actor._pressure_request_body==null,"changed owner retires cached request")
	elif mode=="static_later":
		var sides:Array=actor.contact_log.filter(func(e):return e.frame>initial_frame and not e.rigid and absf(Vector2(e.normal).x)>0.65)
		check(not sides.is_empty() and actor._pressure_request_body==null,"actual later static side collision retires existing rigid request")
		check(absf(actor.velocity.x)<0.01 and actor.position.x<=initial_position.x+0.15,"later static obstacle blocks the released sweep without penetration")
	elif mode=="away":
		await frames(2)
		check(actor.rigid_contact_impulse_this_tick==0 and actor._pressure_request_body==null,"lost side contact expires request and applies no remote force")
		check(absf(actor.velocity.x)<=actor.profile.run_speed+0.05,"contact-loss release stays bounded by ordinary movement target")
	records.append({"scenario":label,"initial_request":initial_request,"first_horizontal":first,"after_request":after_request,"spent":spent,"actual":actor.position-initial_position,"output_velocity":actor.velocity,"action":actor.main_action,"weapon":actor.weapon_phase,"frame":Engine.get_physics_frames()})
	await finish()

func law_control(role: String) -> void:
	label=role+" independent nonrotating law control"
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	cargo=make_cargo(Vector2(180,186),Vector2(28,28),Vector2.ZERO,0,0); cargo.lock_rotation=true
	actor=make_actor(role,Vector2(120,200)); await frames(12); raw(role,1)
	var start:=cargo.position; var maximum:=0.0; var total:=0.0; var start_frame:=Engine.get_physics_frames()
	for i in hz:
		await frames(1); maximum=maxf(maximum,actor.rigid_contact_impulse_this_tick); total+=actor.rigid_contact_impulse_this_tick
	check(Engine.get_physics_frames()-start_frame==hz,"control covers exactly one second of real physics")
	check(maximum<=1400.0/hz+0.001 and total<=1400.001,"shared pressure law preserves per-second budget")
	check(cargo.position.x-start.x>50,"genuine sustained pushing is substantial at this physics rate")
	records.append({"scenario":"independent_law_control","role":role,"dx":cargo.position.x-start.x,"actor":actor.position,"cargo":cargo.position,"max_impulse":maximum,"total_impulse":total})
	await finish()

func carrier_once(role: String) -> void:
	label=role+" independent solved carrier accounting"
	begin(); var carrier:=moving_carrier(Vector2(400,210),Vector2(1400,20)); actor=make_actor(role,Vector2(120,160)); cargo=make_cargo(Vector2(180,186),Vector2(28,28),Vector2.ZERO,0,0)
	await frames(hz); carrier.travel=Vector2(100,0); cargo.linear_velocity=Vector2(220,0); cargo.linear_damp=0; raw(role,1)
	var contacts:Array[Dictionary]=[]; var max_error:=0.0
	for i in hz*2:
		await frames(1)
		if actor.rigid_contact_impulse_this_tick<=0: continue
		var e:Dictionary=actor.last_rigid_contact.duplicate(true)
		# Observer sums actual support sweeps and previous pending displacement,
		# independently of the controller's support-displacement fields.
		for audit in actor.contact_log:
			if audit.frame==Engine.get_physics_frames() and audit.spent>0:
				max_error=maxf(max_error,absf(audit.expected_carrier_x-audit.receipt_carrier_x))
		contacts.append(e)
	check(not contacts.is_empty() and contacts.any(func(e):return Vector2(e.solved_carrier_velocity).x>5),"real side contacts include actual partial carrier transport")
	check(max_error<0.001,"carrier velocity equals independently observed solved transport exactly once")
	check(contacts.all(func(e):return absf(Vector2(e.relative_motor_velocity).x)<=218.01 and absf(Vector2(e.solved_carrier_velocity).x)<=100.1),"stored motor demand does not accumulate carrier speed")
	records.append({"scenario":label,"contacts":contacts,"maximum_accounting_error":max_error})
	await finish()

func uncharged_damage() -> void:
	label="independent uncharged pressure actual impact"
	begin(); surface(Vector2(400,220),Vector2(1200,40)); surface(Vector2(307,150),Vector2(20,100))
	cargo=make_cargo(Vector2(180,186),Vector2(28,28),Vector2.ZERO,0,0); cargo.lock_rotation=true
	actor=make_actor("PC",Vector2(120,200)); var victim:=make_actor("NPC",Vector2(280,200))
	var touched:=[false]; var receipts:Array[Dictionary]=[]
	cargo.body_entered.connect(func(body):
		if body==victim: touched[0]=true)
	victim.get_node("PhysicalImpactReceiver").impact_resolved.connect(func(e):receipts.append(e.duplicate(true)))
	await frames(12); raw("PC",1); await frames(hz*2)
	check(touched[0],"ordinary sustained pressure creates actual cargo-victim body contact")
	check(cargo.charge==0 and cargo.hit_count==0 and victim.get_node("Health").current_health==30 and receipts.is_empty(),"actual uncharged mission cargo contact cannot bypass charge admission")
	records.append({"scenario":label,"contact":touched[0],"receipts":receipts,"health":victim.get_node("Health").current_health,"cargo_velocity":cargo.linear_velocity})
	await finish()

func _run() -> void:
	seed(9017)
	for role in ["PC","NPC"]:
		await pinned(role,false); await pinned(role,true)
		for mode in ["neutral","reverse","jump","attack","hurt","hurt_finish","reset","crouch","force_config","replace_config","disable_config","remove","freeze","away","cargo_lifecycle","cargo_shape","cargo_mass","cargo_material","static_later"]:
			await mutation(role,mode)
		await law_control(role); await carrier_once(role)
	await uncharged_damage()
	await autonomous("sentinel","PC"); await autonomous("warden","NPC")
	var controls:Array=records.filter(func(r):return r.scenario=="independent_law_control")
	label="independent controlled role parity"
	check(controls.size()==2 and absf(controls[0].dx-controls[1].dx)<0.05,"nonrotating equal-config physical law control agrees across role adapters")
	var report:={"hz":hz,"frozen_player_sha256":FROZEN_PLAYER_SHA,"checks":checks,"failures":failures,"expected_followup_gaps":gaps,"records":records,"scope":"Independent frozen request-retention experiment. All motion is solver-driven; explicit geometry/material/lifecycle mutations and inherited API probes labelled. No production core changes."}
	FileAccess.open("res://simulation/evidence/reviewer_request_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("REVIEWER REQUEST %d Hz: %d checks, %d failures"%[hz,checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
