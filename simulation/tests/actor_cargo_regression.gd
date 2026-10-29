extends "res://simulation/tests/actor_cargo_baseline.gd"
## Final assertions are separate from immutable prechange observations.
const SENTINEL = preload("res://demo/components/shared_sentinel.tscn")
const WARDEN = preload("res://demo/components/shared_warden.tscn")
const SENTRY = preload("res://demo/components/shared_sentry.tscn")
var checks: Array[Dictionary] = []
var label := ""
func check(ok: bool, detail: String) -> void:
	checks.append({"scenario":label,"label":detail,"passed":ok})
	if not ok: failures.append(label+": "+detail)
func make_actor(role: String, at: Vector2, mask := 9) -> Node2D:
	var result := super.make_actor(role,at,mask)
	var config: Resource = load("res://demo/resources/player_contact.tres" if role == "PC" else "res://demo/resources/sentinel_contact.tres").duplicate(true)
	config.body_mask = mask; config.terrain_mask = mask
	result.get_node("ContactConfig").configure(config)
	check(not result.automatic_physics and result.get_node("IntentDriver")._owns_tick,"exactly one intended driver owns actor scheduling")
	return result
func support(role: String, mask: int) -> void:
	label = "land and stand "+role
	await super.support(role,mask)
	var observed: Dictionary = records.back().observed
	check(observed.grounded and observed.support_is_cargo and not observed.cargo_frozen,"real unfrozen cargo supports the actor after gravity landing")
	check(absf(Vector2(observed.actor_position).y-172) < 1,"feet remain at actual crate top")
func push(role: String) -> void:
	label = "sidewalk pushes "+role
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	cargo=make_cargo(Vector2(180,186)); actor=make_actor(role,Vector2(120,200)); await frames(12)
	var initial:=snapshot(); var start:=cargo.position; var first_frame:=Engine.get_physics_frames(); var max_speed:=0.0; var minimum_gap:=INF
	var contacts:Array[Dictionary]=[]
	intent(role,Vector2.RIGHT)
	for i in hz:
		await frames(1); max_speed=maxf(max_speed,cargo.linear_velocity.length()); minimum_gap=minf(minimum_gap,cargo.position.x-actor.position.x)
		if actor.rigid_contact_impulse_this_tick>0 and contacts.size()<12:
			var observation:Dictionary=actor.last_rigid_contact.duplicate(true); observation.relative_frame=Engine.get_physics_frames()-first_frame; contacts.append(observation)
	var result:Dictionary={"scenario":"sidewalk","role":role,"cargo_displacement":cargo.position-start,"maximum_cargo_speed":max_speed,"minimum_center_gap":minimum_gap,"initial":initial,"observed":snapshot(),"first_contacts":contacts,"delivered_input":actor.get_node("IntentDriver").last_frame,"configuration":{"run_speed":actor.profile.run_speed,"acceleration":actor.profile.ground_acceleration,"body_width":actor.profile.body_width,"mass":cargo.mass,"friction":cargo.physics_material_override.friction}}
	records.append(result)
	check(Vector2(result.cargo_displacement).x > 5,"ordinary intent imparts actual rigid displacement")
	check(result.maximum_cargo_speed > 5 and result.maximum_cargo_speed < 400,"bounded actual cargo speed")
	check(result.observed.charge == 0 and result.observed.launches == 0,"ordinary motor pressure neither charges nor invokes a weapon launch")
	await finish()
func moving_support(role: String, rotation := false) -> void:
	label = ("rotating support " if rotation else "blocked support ")+role
	await super.moving_support(role,rotation)
	var result: Dictionary = records.back()
	check(result.supported_ticks > hz/5,"genuine floor support is observed")
	check(result.isolated_transport.maximum_reported_x_error < 0.0001,"reported transport equals actual swept movement")
	if rotation:
		check(result.isolated_transport.rotating_samples > 5,"continuous support includes actual rigid rotation")
		check(result.isolated_transport.maximum_lost_anchor_x < 0.001,"clear transport follows the captured committed contact anchor")
	else:
		check(Vector2(result.observed.actor_position).x <= 267.1,"ceiling-height side wall physically blocks actor carry")
func stale_launch(operation: String) -> void:
	label = "confirmation retirement "+operation
	await super.stale_launch(operation)
	var result: Dictionary = records.back()
	check(result.callback_count == 1,"mutation occurs inside genuine canonical contact confirmation")
	check(result.observed.launches == 0 and result.observed.charge == 0,"retired captured geometry cannot launch or charge")
func launch_feedback() -> void:
	label = "post-commit presentation retirement"
	await super.launch_feedback()
	var result: Dictionary = records.back()
	check(result.observed.launches == 1,"already committed launch remains one physical fact")
	var first_frame: int = result.events[0].frame if not result.events.is_empty() else -1
	check(first_frame >= 0 and result.events.filter(func(e): return e.frame == first_frame and e.kind in ["sound","text","launched"]).is_empty(),"retired synchronous launch does not continue old feedback")
func support_removal(role: String, broken := false) -> void:
	label = ("broken support falls " if broken else "removed support falls ")+role
	begin(); surface(Vector2(300,220),Vector2(800,40))
	cargo = make_cargo(Vector2(200,186)); actor = make_actor(role,Vector2(200,105)); await frames(hz)
	check(actor.grounded and actor._support == cargo,"actual landing precedes support removal")
	var before := actor.position.y
	if broken: cargo._break_apart() # Labelled physical-source break lifecycle API.
	else: cargo.queue_free()
	await frames(hz/2)
	check(actor.position.y > before+20 and actor.grounded and actor._support != cargo,"gravity reaches lower floor after actual support deletion")
	await finish()
func push_mass(role: String, mass_value: float, friction := 0.7) -> Dictionary:
	label = "bounded push mass "+str(mass_value)+" "+role
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	cargo = make_cargo(Vector2(180,186)); cargo.mass = mass_value; cargo.physics_material_override.friction=friction
	actor = make_actor(role,Vector2(120,200)); await frames(12)
	var start := cargo.position; var start_frame := Engine.get_physics_frames(); var start_ticks: int = actor.get_node("IntentDriver").tick_count; var largest := 0.0; var total := 0.0
	intent(role,Vector2.RIGHT)
	for i in hz:
		await frames(1); largest = maxf(largest,actor.rigid_contact_impulse_this_tick); total += actor.rigid_contact_impulse_this_tick
	var result := {"role":role,"mass":mass_value,"friction":friction,"frames":Engine.get_physics_frames()-start_frame,"dx":cargo.position.x-start.x,"largest_impulse":largest,"total_impulse":total}
	check(result.frames == hz,"measured engine physics interval is one second")
	check(actor.get_node("IntentDriver").tick_count-start_ticks == hz and actor.get_node("IntentDriver").last_frame.right == 1.0,"one driver tick per physics frame delivers requested raw or NPC input")
	check(largest <= 1400.0/hz+0.001 and total <= 1400.001,"one dt-scaled actor budget covers all sub-sweeps")
	records.append({"scenario":"mass_response","result":result})
	await finish()
	return result
func autonomous(kind: String, victim_role: String) -> void:
	label = "autonomous "+kind+" cargo hits "+victim_role
	begin(); surface(Vector2(400,220),Vector2(1200,40)); surface(Vector2(120,206),Vector2(96,20))
	var launcher: Node2D = (WARDEN if kind == "warden" else SENTINEL).instantiate()
	launcher.position = Vector2(150,196)
	if kind == "listener": launcher.archetype_profile = preload("res://demo/resources/listener_archetype.tres")
	world.add_child(launcher)
	cargo = make_cargo(Vector2(184,186)); cargo.tuning.launch_lift = 0; cargo.tuning.launch_spin_range = Vector2.ZERO
	var observer := make_actor("PC",Vector2(184,105))
	var victim: Node2D
	if victim_role == "PC": victim = make_actor("PC",Vector2(280,200))
	else:
		victim = SENTINEL.instantiate(); victim.position = Vector2(280,200); victim.ai_enabled = false; victim.max_health = 30.0; world.add_child(victim)
	launcher.configure(observer,root.get_node("NoiseBus"))
	var facts: Array[Dictionary] = []; var launches := [0]; var phases: Array[StringName] = []
	cargo.launched.connect(func(_p): launches[0] += 1)
	launcher.movement_event.connect(func(k: StringName,_p: Dictionary): phases.append(k))
	victim.get_node("PhysicalImpactReceiver").impact_resolved.connect(func(receipt): facts.append(receipt.duplicate(true)))
	for i in hz*4:
		await frames(1)
		if not facts.is_empty(): break
	check(launcher.attack_serial > 0 and phases.has(&"attack_started"),"production policy observes a real target and requests canonical attack")
	check(launches[0] == 1,"genuine autonomous sword sweep launches the unfrozen mission crate once")
	check(not facts.is_empty() and facts[0].accepted and facts[0].normal_speed >= 80,"real resulting rigid contact reaches registered victim")
	check(victim.get_node("Health").current_health == 27,"downstream charged cargo applies authored damage through Health")
	records.append({"scenario":label,"launches":launches[0],"phases":phases,"facts":facts,"victim_health":victim.get_node("Health").current_health})
	await finish()
func factory() -> void:
	label = "actual production factory configuration"
	var host := preload("res://demo/mission.tscn").instantiate(); host.save_enabled = false; root.add_child(host); host.start_new(true); host.input_override = {}
	for index in host.sectors.size():
		host.load_sector(index); await frames(2)
		check(host.player.terrain_mask == 9 and host.player.collision_mask == 9 and host.player.material_profile != null,"factory PC composes material contacts")
		check(host.player.get_node("ContactAdapter").target_mask == 12 and host.player.get_node("ContactAdapter").obstruction_mask == 9,"PC physical melee obstruction includes cargo")
		for npc in host.enemies:
			check(npc.terrain_mask == 9 and npc.collision_mask == 9 and npc.material_profile != null,"factory NPC uses same physical material")
			check(npc.get_node("ContactAdapter").target_mask == 72 and npc.get_node("ContactAdapter").obstruction_mask == 9,"NPC cargo target capability preserves hostile-only actor mask")
			if npc.kind == "sentry": check(not npc.get_node("ContactAdapter").enabled,"ranged-only sentry has no implicit melee weapon")
	host.queue_free(); paused = false; await frames(3)
func source_scope(mode: String) -> void:
	label = "canonical cargo scope "+mode
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	actor = make_actor("NPC",Vector2(120,200))
	cargo = CARGO.instantiate(); cargo.set_script(preload("res://simulation/tests/actor_cargo_strike_probe.gd")); cargo.position = Vector2(155,186); cargo.collision_mask = 43
	cargo.tuning = cargo.tuning.duplicate(true); cargo.tuning.hard_impacts_to_break = 1000
	world.add_child(cargo); await frames(8)
	var calls := [0]; var launches := [0]; var receipts := [0]
	cargo.launched.connect(func(_p): launches[0]+=1)
	cargo.strike_launch_resolved.connect(func(_p): receipts[0]+=1)
	cargo.before_receive = func(packet):
		calls[0]+=1
		match mode:
			"direction": packet.facing = -int(packet.facing)
			"strength": packet.prop_launch_scale = float(packet.prop_launch_scale)*2.0
			"shape_disabled": cargo.get_node("CollisionShape2D").disabled = true
			"source_reset": actor.reset_actor(actor.position)
			"source_removed": world.remove_child(actor)
			"cargo_removed": world.remove_child(cargo)
			"simulation_disabled": cargo.set_impact_simulation_enabled(false)
			"pause": paused = true
	intent("NPC",Vector2.ZERO,true); await frames(1); intent("NPC")
	await frames(hz)
	check(calls[0] == 1,"actual source sweep reaches scoped receiver once")
	check(cargo.hit_count == 0 and cargo.charge == 0 and launches[0] == 0 and receipts[0] == 0,"mutated or retired canonical cargo permit has no launch or successful receipt")
	if mode == "source_removed": actor.queue_free()
	if mode == "cargo_removed": cargo.queue_free()
	await finish()
func nested_launch() -> void:
	label = "nested physical launch presentation"
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor = make_actor("PC",Vector2(120,200)); cargo = make_cargo(Vector2(155,186)); await frames(8)
	var events: Array[Dictionary] = []; var nested := [false]
	cargo.burst_requested.connect(func(_a,_b,_c,_d):
		events.append({"kind":"burst","epoch":cargo.impact_epoch,"frame":Engine.get_physics_frames()})
		if not nested[0]: nested[0]=true; cargo.launch(-1))
	cargo.launched.connect(func(_p): events.append({"kind":"launch","epoch":cargo.impact_epoch,"frame":Engine.get_physics_frames()}))
	intent("PC",Vector2.ZERO,true); await frames(1); intent("PC"); await frames(ceili(hz*.4))
	check(cargo.hit_count == 2 and cargo.impact_epoch == 3,"explicit callback relaunch commits exactly its independent physical epoch")
	check(events.filter(func(e):return e.kind == "launch").size() == 1 and events.any(func(e):return e.kind == "launch" and e.epoch == 3),"outer retired launch cannot resume after nested launch overwrites state")
	records.append({"scenario":label,"events":events}); await finish()
func melee_negative(role: String, mode: String) -> void:
	label = role+" real sword negative "+mode
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor(role,Vector2(120,200))
	cargo=make_cargo(Vector2(240 if mode == "range" else 165,186))
	if mode == "wall": surface(Vector2(143,150),Vector2(6,100))
	if mode == "behind_cargo":
		var blocker := make_cargo(Vector2(144,186)); blocker.freeze=true
	await frames(8); intent(role,Vector2.ZERO,true); await frames(1); intent(role); await frames(hz)
	check(actor.attack_serial > 0,"ordinary role input commits genuine attack")
	check(cargo.hit_count == 0 and cargo.charge == 0,"range or actual material obstruction prevents launch")
	if mode != "range": check(actor.get_node("ContactAdapter").occluded_contacts > 0,"physical swing ray records obstruction")
	await finish()
func repeated_swing(role: String) -> void:
	label = role+" once per swing and new swing"
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor(role,Vector2(120,200)); cargo=make_cargo(Vector2(155,186))
	cargo.tuning.launch_speed=20; cargo.tuning.launch_lift=0; cargo.tuning.launch_spin_range=Vector2.ZERO
	await frames(8); intent(role,Vector2.ZERO,true); await frames(1); intent(role); await frames(hz)
	check(cargo.hit_count == 1,"multi-frame actual sword confirms cargo once in first swing")
	var serial: int=actor.attack_serial
	intent(role,Vector2.ZERO,true); await frames(1); intent(role); await frames(hz)
	check(actor.attack_serial > serial and cargo.hit_count == 2,"fresh released input and new canonical swing can relaunch still-reachable cargo")
	await finish()
func pressure_negative(role: String, mode: String) -> void:
	label = role+" bounded motor pressure "+mode
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor(role,Vector2(120,200)); cargo=make_cargo(Vector2(155,186))
	if mode == "frozen": cargo.freeze=true
	if mode == "disabled": cargo.set_impact_simulation_enabled(false)
	if mode == "moving_away": cargo.linear_velocity=Vector2(500,0); cargo.physics_material_override.friction=0
	await frames(8); intent(role,Vector2.RIGHT)
	var total:=0.0; var maximum:=0.0
	for i in hz:
		await frames(1); total+=actor.rigid_contact_impulse_this_tick; maximum=maxf(maximum,cargo.linear_velocity.length())
	check(total == 0,"frozen/disabled/separating material receives no motor impulse")
	check(cargo.hit_count == 0 and cargo.charge == 0,"ordinary contact never invents attack charge")
	records.append({"scenario":label,"total_impulse":total,"maximum_cargo_speed":maximum}); await finish()
func launch_underfoot(role: String, ceiling := false) -> void:
	label = role+" launch real occupied cargo"+(" under ceiling" if ceiling else "")
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	cargo=make_cargo(Vector2(200,186),Vector2(100,28)); actor=make_actor(role,Vector2(200,105)); await frames(hz)
	check(actor.grounded and actor._support==cargo,"actual gravity landing establishes occupied cargo")
	if ceiling: surface(Vector2(220,125),Vector2(160,8)); await frames(2)
	var before:=actor.position; cargo.tuning.launch_spin_range=Vector2.ZERO
	# Explicit launch API tests transport under an independently committed physical impulse.
	cargo.launch(1)
	var maximum:=0.0; var top:=actor.position.y; var transported:=0.0
	for i in hz:
		var prior:=actor.position; await frames(1); maximum=maxf(maximum,actor.position.distance_to(prior)); top=minf(top,actor.position.y); transported+=actor._support_displacement.length()
	check(cargo.hit_count==1 and cargo.position.x>200,"real launch moves the occupied unfrozen rigid body")
	check(maximum < 40 and actor.position.is_finite() and cargo.linear_velocity.length()<1000,"swept actor and Godot rigid response remain bounded")
	if ceiling: check(top >= 162.0,"ceiling physically stops the standing actor head")
	else: check(transported>5 and actor.position.distance_to(before)>5,"real support motion transports the supported actor")
	records.append({"scenario":label,"maximum_actor_step":maximum,"minimum_feet_y":top,"actual_transport":transported,"observed":snapshot()}); await finish()

func moving_carrier(at: Vector2, size: Vector2) -> AnimatableBody2D:
	var body := AnimatableBody2D.new(); body.set_script(preload("res://simulation/tests/actor_cargo_carrier.gd")); body.position=at
	var shape:=CollisionShape2D.new(); var box:=RectangleShape2D.new(); box.size=size; shape.shape=box; body.add_child(shape); world.add_child(body)
	return body
func carrier_pressure(role: String) -> void:
	label=role+" real Animatable carrier pressure"
	begin(); var carrier:=moving_carrier(Vector2(400,210),Vector2(1400,20)); actor=make_actor(role,Vector2(120,160)); cargo=make_cargo(Vector2(180,186),Vector2(28,28),Vector2.ZERO,0,0)
	await frames(hz); check(actor.grounded and actor._support==carrier,"actual landing binds moving support")
	carrier.travel=Vector2(100,0); cargo.linear_velocity=Vector2(220,0); cargo.linear_damp=0; intent(role,Vector2.RIGHT)
	var observations:Array[Dictionary]=[]
	for i in hz*2:
		await frames(1)
		if actor.rigid_contact_impulse_this_tick>0: observations.append(actor.last_rigid_contact.duplicate(true))
	check(not observations.is_empty(),"ground walking closes actual moving-carrier side contact")
	check(observations.any(func(e):return e.solved_carrier_velocity.x>5),"pressure includes prior already-solved Animatable carry, not an unsolved target")
	for e in observations:
		check(absf(e.actual_closing_speed-(Vector2(e.actor_world_velocity)-Vector2(e.body_contact_velocity)).dot(-Vector2(e.normal))) < 0.001,"actual approach diagnostic retains measured relative point velocity")
	records.append({"scenario":label,"contacts":observations,"observed":snapshot(),"carrier_position":carrier.position,"prior_carry":actor._last_pending_transport_velocity,"driver":actor.get_node("IntentDriver").last_frame}); await finish()
func support_orientation(role: String, hurt_pause: bool) -> void:
	label=role+" Animatable orientation loss"+(" during hurt pause" if hurt_pause else "")
	begin(); var carrier:=moving_carrier(Vector2(200,210),Vector2(180,20)); actor=make_actor(role,Vector2(200,150)); await frames(hz)
	check(actor.grounded and actor._support==carrier,"real landing establishes the captured support normal")
	if hurt_pause:
		# Labelled lifecycle/API probe; genuine incoming-contact hurt is covered separately.
		actor.receive_attack({"amount":1.0,"stun_seconds":0.3,"hitpause":0.3,"impulse":Vector2.ZERO,"source_position":Vector2(100,200),"blockable":false,"parryable":false,"rollable":false})
		check(actor.hitpause_remaining>0 and actor._pause_support==carrier,"hurt pause retains only its observed support")
	carrier.spin=deg_to_rad(60)*hz
	await frames(1); carrier.spin=0
	records.append({"scenario":label,"actor":actor.position,"grounded":actor.grounded,"retained":actor._pause_support!=null,"carrier_rotation":carrier.rotation,"committed_rotation":actor._physics_transform(carrier).get_rotation(),"captured_normal":actor._support_local_normal,"world_normal":carrier.global_transform.basis_xform(actor._support_local_normal),"action":actor.main_action,"pause":actor.hitpause_remaining})
	check(not actor.grounded and (actor._pause_support==null if hurt_pause else actor._support==null),"unwalkable planned orientation retires support before pending carry")
	await frames(hz/2); check(actor.position.y>210,"ordinary gravity follows rotated-away support")
	await finish()
func landing_removal(role: String) -> void:
	label=role+" landing callback removes pending carrier"
	begin(); var carrier:=moving_carrier(Vector2(200,210),Vector2(180,20)); carrier.travel=Vector2(80,0); actor=make_actor(role,Vector2(200,130))
	var removed:=[false]; var at_removal:=[Vector2.ZERO]; var after_tick:=[Vector2.ZERO]
	actor.movement_event.connect(func(kind,_payload):
		if kind==&"landed" and not removed[0]: removed[0]=true; at_removal[0]=actor.position; carrier.queue_free())
	for i in hz:
		await frames(1)
		if removed[0]: after_tick[0]=actor.position; break
	check(removed[0],"genuine landed event executes synchronous lifecycle mutation")
	check(actor._support==null and not actor.grounded,"retired carrier is rejected before pending transport")
	check(absf(after_tick[0].x-at_removal[0].x)<0.001,"detached support cannot carry actor after callback")
	await finish()
func post_launch_geometry(mode: String) -> void:
	label="post-commit launch geometry "+mode
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor("PC",Vector2(120,200)); cargo=make_cargo(Vector2(155,186)); await frames(8)
	var changed:=[false]; var events:Array[String]=[]
	cargo.burst_requested.connect(func(_a,_b,_c,_d):
		if changed[0]: return
		changed[0]=true
		if mode=="move": cargo.position.x+=100
		else: cargo.get_node("CollisionShape2D").shape.size=Vector2(8,8))
	cargo.launched.connect(func(_p):events.append("launch"))
	cargo.strike_launch_resolved.connect(func(_p):events.append("receipt"))
	intent("PC",Vector2.ZERO,true); await frames(1); intent("PC"); await frames(hz/2)
	check(changed[0] and cargo.hit_count==1,"one physical launch commits before callback changes geometry")
	check(events.is_empty(),"captured post-commit geometry fences both launched and receiver presentation callbacks")
	await finish()

func separating_contact_api(role: String) -> void:
	label=role+" separating real-query material API probe"
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor(role,Vector2(120,200)); cargo=make_cargo(Vector2(155,186)); await frames(8)
	intent(role,Vector2.RIGHT); await frames(1)
	# A genuine Godot sweep query captures actual geometry. This explicitly
	# labelled API negative does not claim an autonomous moving-away collision.
	var contact:=KinematicCollision2D.new()
	var touched:bool=actor.test_move(actor.global_transform,Vector2(40,0),contact,actor.profile.collision_margin)
	check(touched and contact.get_collider()==cargo,"actual shape sweep observes cargo contact geometry")
	cargo.linear_velocity=Vector2(500,0)
	var direct:=PhysicsServer2D.body_get_direct_state(cargo.get_rid())
	var before:=direct.linear_velocity
	var result:Dictionary=actor.material_profile.respond(actor,contact,Vector2(50,0),Vector2(218,0),1400.0/hz,true)
	check(direct.linear_velocity.x>400 and result.is_empty() and direct.linear_velocity==before,"body separating faster than commanded motor receives no attractive impulse")
	cargo.linear_velocity=Vector2(100,0)
	result=actor.material_profile.respond(actor,contact,Vector2(50,0),Vector2(218,0),1400.0/hz,true)
	check(not result.is_empty() and result.actual_closing_speed<0 and result.target_closing_speed>0 and result.magnitude<=1400.0/hz,"real contact sustains bounded commanded pressure despite clipped instantaneous motor speed")
	await finish()
func off_center_pressure(role: String) -> void:
	label=role+" off-centre real rigid pressure"
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor(role,Vector2(120,200)); cargo=make_cargo(Vector2(180,160),Vector2(28,80)); await frames(12)
	intent(role,Vector2.RIGHT); var maximum_spin:=0.0; var maximum_speed:=0.0; var impulses:=0.0
	for i in hz*2:
		await frames(1); maximum_spin=maxf(maximum_spin,absf(cargo.angular_velocity)); maximum_speed=maxf(maximum_speed,cargo.linear_velocity.length()); impulses+=actor.rigid_contact_impulse_this_tick
	check(impulses>0 and maximum_spin>0.01,"actual off-centre motor impulse produces Godot angular response")
	check(maximum_speed<500 and maximum_spin<20 and cargo.hit_count==0,"bounded pressure does not manufacture launch charge or runaway energy")
	records.append({"scenario":label,"maximum_spin":maximum_spin,"maximum_speed":maximum_speed,"total_impulse":impulses}); await finish()
func controlled_push(role: String) -> Dictionary:
	label=role+" matched nonrotating pressure control"
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor(role,Vector2(120,200)); cargo=make_cargo(Vector2(180,186)); cargo.lock_rotation=true; await frames(12)
	var start:=cargo.position; intent(role,Vector2.RIGHT); await frames(hz)
	var result:Dictionary={"actor":actor.position,"cargo":cargo.position,"dx":cargo.position.x-start.x,"charge":cargo.charge,"ticks":actor.get_node("IntentDriver").tick_count}
	check(result.dx>5 and cargo.charge==0,"unfrozen constrained material moves through the same ordinary force path")
	records.append({"scenario":label,"result":result}); await finish(); return result
func role_parity() -> void:
	label="matched ordinary input role parity"
	var pc:Dictionary=records.filter(func(r):return r.scenario=="sidewalk" and r.get("role")=="PC")[0]
	var npc:Dictionary=records.filter(func(r):return r.scenario=="sidewalk" and r.get("role")=="NPC")[0]
	check(pc.configuration==npc.configuration and pc.delivered_input==npc.delivered_input,"unlocked production-material role fixtures use identical motor/material configuration and delivered command")
	check(Vector2(pc.initial.actor_position).distance_to(Vector2(npc.initial.actor_position))<0.001 and Vector2(pc.initial.cargo_position).distance_to(Vector2(npc.initial.cargo_position))<0.001,"role fixtures begin from equivalent observed geometry")
	# Free rotation/contact ordering can amplify tiny solver differences. Keep
	# those ordinary outcomes above, and compare a separately labelled controlled
	# angular material to test role law without claiming identical chaotic paths.
	var controlled_pc:=await controlled_push("PC"); var controlled_npc:=await controlled_push("NPC")
	label="matched ordinary input role parity"
	check(Vector2(controlled_pc.actor).distance_to(Vector2(controlled_npc.actor))<0.1 and Vector2(controlled_pc.cargo).distance_to(Vector2(controlled_npc.cargo))<0.1,"identical nonrotating control produces equal actual PC/NPC displacement")

func small_paused_rotation(role: String) -> void:
	label=role+" allowed rotation during hurt pause"
	begin(); var carrier:=moving_carrier(Vector2(200,210),Vector2(180,20)); actor=make_actor(role,Vector2(230,150)); await frames(hz)
	check(actor.grounded and actor._support==carrier,"genuine landing precedes labelled local-pause API probe")
	actor.receive_attack({"amount":1.0,"stun_seconds":0.5,"hitpause":0.4,"impulse":Vector2.ZERO,"source_position":Vector2(100,200),"blockable":false,"parryable":false,"rollable":false})
	var local_anchor:Vector2=actor._pause_support_local_anchor
	var start_anchor:Vector2=actor._pause_support_anchor_position
	var start:=actor.position; var maximum_error:=0.0; var retained:=0
	carrier.spin=0.25
	for i in ceili(hz*.2):
		var before:=actor.position; await frames(1)
		maximum_error=maxf(maximum_error,(actor.position-before-actor._support_displacement).length())
		if actor._pause_support==carrier: retained+=1
	var expected:Vector2=carrier.global_transform*local_anchor-start_anchor
	check(retained>=hz*.18 and actor.hitpause_remaining>0,"small walkable rotation retains actual support throughout local freeze")
	check(expected.length()>0.5 and (actor.position-start-expected).length()<0.05,"paused actor follows true local contact anchor including rotation")
	check(maximum_error<0.001,"paused transport diagnostics report actual solved displacement")
	records.append({"scenario":label,"actual":actor.position-start,"expected":expected,"maximum_error":maximum_error,"retained_ticks":retained}); await finish()

func pressure_owner_negative(role: String, mode: String) -> void:
	label=role+" no motor pressure during "+mode
	begin(); surface(Vector2(400,220),Vector2(1200,40)); actor=make_actor(role,Vector2(120,200))
	cargo=make_cargo(Vector2(180,100) if mode=="air" else Vector2(150,186),Vector2(28,200) if mode=="air" else Vector2(28,28)); await frames(8)
	actor.get_node("ContactAdapter").enabled=false # Isolate locomotor force, not weapon launch.
	if mode=="attack": intent(role,Vector2.RIGHT,true)
	elif mode=="air":
		if role=="PC": actor.get_node("InputSource").raw={"right":1.0,"jump":true}
		else: actor.get_node("PatrolPolicy").intent={"move":Vector2.RIGHT,"jump":true}
	var total:=0.0; var contacts:=0; var owned:=0
	for i in ceili(hz*.35):
		await frames(1)
		total+=actor.rigid_contact_impulse_this_tick
		if mode=="air" and not actor.grounded: owned+=1
		if mode=="attack" and actor.weapon_phase!=&"idle": owned+=1
		if actor._wall_normal.x<-.5: contacts+=1
	check(total==0,"neutral/weapon/air owner cannot spend ordinary grounded force budget")
	if mode!="neutral": check(owned>5 and contacts>0,"genuine owner phase and real side obstruction are observed")
	records.append({"scenario":label,"impulse":total,"contacts":contacts,"owned_ticks":owned}); await finish()
func transport_bound_api() -> void:
	label="opposing support stages bound API"
	begin(); actor=make_actor("PC",Vector2.ZERO)
	check(not actor._support_transport_pair_bounded(Vector2(100,0),Vector2(-100,0),1.0/hz),"opposing large committed/planned stages cannot cancel the safety limit")
	check(actor._support_transport_pair_bounded(Vector2(0.1,0),Vector2(-0.1,0),1.0/hz),"individually bounded opposing stages remain eligible")
	await finish()

func _run() -> void:
	seed(3271)
	for role in ["PC","NPC"]:
		await support(role,9); await push(role); await moving_support(role); await moving_support(role,true); await support_removal(role); await support_removal(role,true)
		for mode in ["range","wall","behind_cargo"]: await melee_negative(role,mode)
		await repeated_swing(role)
		for mode in ["frozen","disabled","moving_away"]: await pressure_negative(role,mode)
		await launch_underfoot(role); await launch_underfoot(role,true)
		for mode in ["neutral","attack","air"]: await pressure_owner_negative(role,mode)
		await separating_contact_api(role); await off_center_pressure(role)
		await carrier_pressure(role); await support_orientation(role,false); await support_orientation(role,true); await small_paused_rotation(role); await landing_removal(role)
		var light := await push_mass(role,0.7); var heavy := await push_mass(role,3.0)
		check(light.dx > heavy.dx+5,"ordinary push preserves meaningful material mass difference")
		await push_mass(role,1.1,0.0)
	for operation in ["retire","move","shape","freeze"]: await stale_launch(operation)
	await launch_feedback()
	await nested_launch()
	for mode in ["move","shape"]: await post_launch_geometry(mode)
	for mode in ["direction","strength","shape_disabled","source_reset","source_removed","cargo_removed","simulation_disabled","pause"]: await source_scope(mode)
	for kind in ["sentinel","listener","warden"]:
		for victim_role in ["PC","NPC"]: await autonomous(kind,victim_role)
	await transport_bound_api()
	await role_parity()
	await factory()
	var report := {"hz":hz,"checks":checks,"failures":failures,"records":records,"scope":"Actual shared motion and canonical cargo contacts, matched input roles, production autonomous policy launch and actual factory configurations. Initial geometry/material state and lifecycle mutations are labelled."}
	FileAccess.open("res://simulation/evidence/actor_cargo_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("ACTOR CARGO %d Hz: %d checks, %d failures"%[hz,checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
