extends SceneTree
## Production composition and actual gravity. Initial placement and explicit
## lifecycle API probes are labelled separately from physical crossing evidence.
const PC = preload("res://combat_pc/player.tscn")
const NPC = preload("res://demo/components/shared_sentinel.tscn")
const SENTRY = preload("res://demo/components/shared_sentry.tscn")
const WARDEN = preload("res://demo/components/shared_warden.tscn")
const HEALTH = preload("res://combat_pc/components/health_component.tscn")
const DEFEAT = preload("res://combat_pc/components/defeat_response.tscn")
const RECEIVER = preload("res://simulation/components/boundary_receiver.tscn")
const BOUNDARY = preload("res://simulation/components/boundary_hazard.tscn")
const CRATE = preload("res://scenes/props/crate.tscn")
class Driver extends Node:
	var actor: Node
	var raw := {}
	func _physics_process(dt: float) -> void:
		if is_instance_valid(actor): actor.physics_tick(dt, raw)
var hz := 60
var world: Node2D
var hazard: MokshaBoundaryHazard
var actor: Node2D
var health: MokshaHealthComponent
var driver: Driver
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var scenarios: Array[String] = []
var observed: Array[Dictionary] = []
var processed: Array[Dictionary] = []
var damage: Array[Dictionary] = []
var depleted := 0
var defeated := 0
var traces: Array[Dictionary] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"label": scenarios.back()+" / "+label, "passed": ok})
	if not ok: failures.append(scenarios.back()+" / "+label)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func until(test: Callable, seconds := 2.0) -> bool:
	for i in ceili(hz*seconds):
		if test.call(): return true
		await frames(1)
	return test.call()
func begin(label: String, boundary_y := 100.0) -> void:
	paused = false
	if is_instance_valid(world): world.queue_free(); await frames(3)
	scenarios.append(label)
	observed = []; processed = []; damage = []; depleted = 0; defeated = 0
	world = preload("res://simulation/components/boundary_scope.gd").new(); root.add_child(world)
	hazard = BOUNDARY.instantiate(); hazard.position.y = boundary_y; world.add_child(hazard)
	hazard.boundary_observed.connect(func(receipt): observed.append(receipt.duplicate(true)))
	actor = null; health = null; driver = null
func spawn_actor(kind := "PC", at := Vector2(100, 0), probe := false) -> Node2D:
	actor = (SENTRY if kind == "sentry" else WARDEN if kind == "warden" else NPC if kind != "PC" else PC).instantiate()
	actor.position = at
	if kind == "PC":
		actor.automatic_physics = false
		health = HEALTH.instantiate(); health.maximum_health = 60; actor.add_child(health)
		actor.add_child(DEFEAT.instantiate()); actor.add_child(RECEIVER.instantiate())
	else:
		actor.kind = kind; actor.ai_enabled = false
		if kind == "listener": actor.archetype_profile = preload("res://demo/resources/listener_archetype.tres")
	if probe: actor.get_node("BoundaryReceiver").set_script(preload("res://simulation/tests/boundary_probe_receiver.gd"))
	world.add_child(actor)
	health = actor.get_node("Health")
	actor.damage_resolved.connect(func(receipt): damage.append(receipt.duplicate(true)))
	health.damage_processed.connect(func(receipt): processed.append(receipt.duplicate(true)))
	health.depleted.connect(func(): depleted += 1)
	actor.get_node("DefeatResponse").defeat_started.connect(func(): defeated += 1)
	if kind == "PC":
		driver = Driver.new(); driver.actor = actor; world.add_child(driver)
	return actor
func solid(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at; body.collision_layer = 1
	var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size = size; shape.shape = box; body.add_child(shape); world.add_child(body)
	return body
func spawn_cargo(at := Vector2(200, 0)) -> RigidBody2D:
	var box = CRATE.instantiate(); box.set_script(preload("res://demo/components/mission_prop.gd")); box.position = at
	box.tuning = box.tuning.duplicate(true); box.tuning.hard_impacts_to_break = 100
	world.add_child(box); return box
func _run() -> void:
	for kind in ["PC", "sentinel", "listener", "sentry", "warden"]: await gravity_role(kind)
	await defense_crossings()
	await physical_reentry()
	await fixed_and_reentry()
	await geometric_negatives()
	await initial_policies()
	await eligibility_and_replacement()
	await cargo_retirement()
	await cargo_pending_retirement()
	await designated_cargo()
	await mission_defeat_callbacks()
	await lifecycle_matrix()
	await receipt_forgery()
	await nested_damage()
	await mission_factory()
	paused = false
	if is_instance_valid(world): world.queue_free(); await frames(3)
	var report := {"hz": hz, "checks": checks, "failures": failures, "scenarios": scenarios, "traces": traces,
		"execution": "Real production actors and rigid cargo, actual Godot gravity/physics; initial placement and direct lifecycle probes explicitly labelled. Witness origin, not shape overlap."}
	FileAccess.open("res://simulation/evidence/boundary_%d.json"%hz, FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("SHARED BOUNDARY %d Hz: %d scenarios, %d checks, %d failures"%[hz,scenarios.size(),checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
func gravity_role(kind: String) -> void:
	await begin("actual gravity crossing "+kind)
	spawn_actor(kind)
	var capacity := health.current_health
	check(await until(func(): return defeated == 1), "fall reaches ordinary DefeatResponse")
	check(observed.size()==1 and observed[0].resolved and observed[0].crossed and not observed[0].initial_outside, "one real safe-to-outside observation")
	check(processed.size()==1 and processed[0].applied==capacity and health.current_health==0, "one exact current Health debit")
	check(damage.size()==1 and depleted==1 and defeated==1 and actor.is_defeated(), "one damage/depletion/defeat chain")
	check(observed.size()==1 and observed[0].previous_point.y<=100 and observed[0].point.y>100, "same witness boundary at both samples")
	check(health._guarded_debits.is_empty(), "synchronous guarded reservation released")
	traces.append({"role":kind,"health":processed.duplicate(true),"boundary":observed.duplicate(true)})
	await frames(8); check(observed.size()==1 and depleted==1,"persistent outside does not repeat")
func fixed_and_reentry() -> void:
	await begin("fixed damage, persistent outside, explicit reset lifecycle")
	hazard.profile.damage_mode = MokshaBoundaryProfile.Damage.FIXED; hazard.profile.damage = 7
	spawn_actor(); await until(func():return observed.size()==1)
	check(health.current_health==53 and processed.size()==1,"fixed amount follows ordinary Health")
	await frames(20); check(observed.size()==1 and health.current_health==53,"one attempt for outside episode")
	actor.reset_actor(Vector2(100,0),1) # Explicit new life setup; subsequent fall is actual gravity.
	await until(func():return observed.size()==2)
	check(health.current_health==53 and observed[1].crossed,"reset life has fresh actual crossing")
	await begin("zero fixed damage genuine Health observation")
	hazard.profile.damage_mode=MokshaBoundaryProfile.Damage.FIXED; hazard.profile.damage=0
	spawn_actor(); await until(func():return observed.size()==1)
	check(observed.size()==1 and observed[0].resolved and observed[0].amount==0 and health.current_health==60,"zero damage is a valid resolved fact")
func geometric_negatives() -> void:
	await begin("legitimate landing above boundary")
	solid(Vector2(100,70),Vector2(220,20)); spawn_actor()
	await frames(hz); check(actor.grounded and health.current_health==60 and observed.is_empty(),"solid landing never crosses boundary")
	await begin("edge exactly safe; actual jump and return")
	solid(Vector2(100,110),Vector2(220,20)); spawn_actor("PC",Vector2(100,100))
	await frames(8); check(observed.is_empty(),"exact boundary is safe")
	driver.raw={"jump":true,"jump_pressed":true}; await frames(1); driver.raw={}
	await frames(hz); check(health.current_health==60 and observed.is_empty(),"jump returns to edge without crossing")
	await begin("transformed non-solid world constraint")
	hazard.rotation=.25; spawn_actor("PC",Vector2.ZERO)
	await until(func():return observed.size()==1)
	check(observed.size()==1 and observed[0].crossed and hazard.to_local(observed[0].point).y>0,"actual fall crosses transformed half-plane")
func initial_policies() -> void:
	for policy in [MokshaBoundaryHazard.InitialOutside.OCCUPANCY, MokshaBoundaryHazard.InitialOutside.REQUIRE_INSIDE_FIRST]:
		await begin("labelled initial outside policy "+str(policy)); hazard.initial_outside=policy
		spawn_actor("PC",Vector2(100,120)); await frames(8)
		if policy==MokshaBoundaryHazard.InitialOutside.OCCUPANCY:
			check(observed.size()==1 and observed[0].initial_outside and not observed[0].crossed and health.current_health==0,"occupancy is explicitly not labelled crossing")
		else: check(observed.is_empty() and health.current_health==60,"outside spawn waits for inside observation")
func cargo_retirement() -> void:
	for charged in [false,true]:
		await begin("actual rigid fall "+("charged" if charged else "passive"))
		var box := spawn_cargo(); var facts: Array[Dictionary]=[]
		box.destroyed.connect(func(who):
			facts.append({"alive":who.alive,"enabled":who.simulation_enabled,"charge":who.charge,"pending":who._pending.size(),"pending_charge":who._pending_charge.size(),"epoch":who.impact_epoch})
			who.launch(1); who._break_apart())
		if charged: box.launch(1)
		check(await until(func():return not facts.is_empty()),"actual gravity retires rigid cargo")
		check(facts.size()==1 and not facts[0].alive and not facts[0].enabled and facts[0].charge==0 and facts[0].pending==0 and facts[0].pending_charge==0,"all source/charge authority retired before destroyed callback")
		check(observed.size()==1 and observed[0].resolved and observed[0].effect==&"cargo_retired","one terminal boundary fact")
		await frames(3); check(not is_instance_valid(box),"cleanup frees retired body")
func lifecycle_matrix() -> void:
	for mode in ["reset","health_reset","health_rebind","health_replace","receiver_disable","receiver_rebind","source_disable","source_physics_disable","source_move","source_aba","scope_aba","receiver_path","source_profile","pause","source_queue","target_queue","source_detach","target_detach","target_world"]:
		await begin("callback lifecycle before Health debit / "+mode)
		spawn_actor(); var original_health := health; var receiver: MokshaBoundaryReceiver=actor.get_node("BoundaryReceiver")
		# Put the callback before Health's own signal subscriber, deliberately.
		health.unbind_actor()
		var once := [false]
		actor.damage_resolved.connect(func(receipt):
			if once[0] or not receipt.has("guard_health_id"): return
			once[0]=true
			match mode:
				"reset": actor.reset_actor(Vector2(100,0),1)
				"health_reset": health.reset_to_full()
				"health_rebind": health.bind_actor(actor)
				"health_replace":
					health.unbind_actor(); var replacement=HEALTH.instantiate(); replacement.maximum_health=60; actor.add_child(replacement); receiver.bind(actor,replacement)
				"receiver_disable": receiver.enabled=false
				"receiver_rebind": receiver.bind(actor,health)
				"source_disable": hazard.enabled=false
				"source_physics_disable": hazard.set_physics_process(false)
				"source_move": hazard.position.y-=10
				"source_aba":
					var old=hazard.position;hazard.position.y-=10;hazard.position=old
				"scope_aba":
					var old=world.position;world.position.y-=10;world.position=old
				"receiver_path": receiver.health_path=NodePath("../MissingHealth")
				"source_profile": hazard.profile.damage+=1
				"pause": paused=true
				"source_queue": hazard.queue_free()
				"target_queue": actor.queue_free()
				"source_detach": world.remove_child(hazard)
				"target_detach": world.remove_child(actor)
				"target_world":
					var viewport=SubViewport.new();viewport.world_2d=World2D.new();world.add_child(viewport);actor.reparent(viewport)
		)
		health.bind_actor(actor)
		await until(func():return once[0])
		check(once[0],"genuine crossing reaches earlier signal listener")
		if mode!="target_queue": check(original_health.current_health==60 and depleted==0 and defeated==0,"retired scope cannot debit reset/rebound/retired context")
		if is_instance_valid(original_health): check(original_health._guarded_debits.is_empty(),"retired reservation released")
		paused=false
		if mode=="source_detach": hazard.free()
		if mode=="target_detach": actor.free()
		if mode in ["health_reset","health_rebind","health_replace","receiver_disable","receiver_rebind","source_disable","source_physics_disable","source_move","source_aba","scope_aba","receiver_path","source_profile","pause"]:
			receiver.enabled=true; hazard.enabled=true; hazard.set_physics_process(true); await frames(5)
			check(observed.size()==1,"same outside episode never retries retired/partial attempt")
func receipt_forgery() -> void:
	await begin("exact sealed receipt rejects copied amount and replay")
	hazard.profile.damage_mode=MokshaBoundaryProfile.Damage.FIXED; hazard.profile.damage=5
	spawn_actor(); health.unbind_actor(); var once := [false]; var retained: Array[Dictionary]=[]
	actor.damage_resolved.connect(func(receipt):
		if once[0] or not receipt.has("guard_health_id"): return
		once[0]=true; retained.append(receipt)
		var copy=receipt.duplicate(); copy.amount=999; actor.damage_resolved.emit(copy)
		var equal_copy=receipt.duplicate(); actor.damage_resolved.emit(equal_copy)
		var stripped=receipt.duplicate()
		for field in health.GUARDED_FIELDS: stripped.erase(field)
		stripped.amount=999;actor.damage_resolved.emit(stripped))
	health.bind_actor(actor)
	await until(func():return observed.size()==1)
	check(health.current_health==55 and processed.size()==1,"only exact immutable receipt debits")
	if not retained.is_empty():
		actor.damage_resolved.emit(retained[0])
		var stripped=retained[0].duplicate()
		for field in health.GUARDED_FIELDS: stripped.erase(field)
		actor.damage_resolved.emit(stripped)
		health.reset_to_full();actor.damage_resolved.emit(stripped)
		check(health.current_health==60,"stripped guarded replay rejected after same-life Health reset")
		health.bind_actor(actor);actor.damage_resolved.emit(stripped)
		check(health.current_health==60,"binding serial floor rejects stripped old guard after rebind")
	check(health.current_health==60 and processed.size()==1,"original cannot replay after consumed reservation")
func nested_damage() -> void:
	await begin("nested ordinary accepted damage retires older guarded observation")
	hazard.profile.damage_mode=MokshaBoundaryProfile.Damage.FIXED; hazard.profile.damage=5
	spawn_actor(); health.unbind_actor(); var once := [false]
	actor.damage_resolved.connect(func(receipt):
		if once[0] or not receipt.has("guard_health_id"): return
		once[0]=true
		actor.receive_attack({"amount":3.0,"impulse":actor.velocity,"stun_seconds":0.0,"hitpause":0.0,"rollable":false}))
	health.bind_actor(actor)
	await until(func():return observed.size()==1)
	check(health.current_health==57 and processed.size()==1 and not observed[0].resolved,"later real damage owns changed Health state; old boundary retires")
	await frames(8); check(health.current_health==57 and observed.size()==1,"no repeated partial effect")
	await begin("post-debit nested Health reset suppresses stale resolution")
	spawn_actor(); var once_reset := [false]
	health.health_changed.connect(func(value,_maximum):
		if value==0 and not once_reset[0]: once_reset[0]=true; health.reset_to_full())
	await until(func():return observed.size()==1)
	check(health.current_health==60 and processed.is_empty() and depleted==0 and not observed[0].resolved,"only genuine current processed fact marks resolved")
	await frames(8); check(observed.size()==1,"already attempted episode retained after restored Health")
func mission_factory() -> void:
	await begin("labelled locked-gap fixture / actual mission four factories")
	hazard.enabled=false
	var host=preload("res://demo/mission.tscn").instantiate(); host.save_enabled=false
	var config=preload("res://demo/mission_data.gd").sectors()[0].duplicate(true)
	config.enemies=[[520,"sentinel",220],[560,"listener",220],[600,"sentry",220],[640,"warden",220]]
	config.props=[]; config.platforms=[]; config.gaps=[Vector2(450,750)]; config.lock=true; config.erase("relay");config.erase("cache")
	host.sectors.assign([config]); world.add_child(host); host.start_new(true); host.input_override={}
	for enemy in host.enemies: enemy.ai_enabled=false
	check(host.remaining_enemies()==4 and not host.room.gate_open,"labeled composition starts locked with all four live foes")
	check(await until(func():return host.remaining_enemies()==0),"real gravity + ordinary NPC defeat clears all four")
	check(host.kills==4 and host.room.gate_open and host.state=="playing","gate observer uses actual defeated facts, PC survives")
	host.queue_free(); await frames(3)
	await begin("labelled mission boundary-gap composition / PC actual fall and retry")
	hazard.enabled=false
	host=preload("res://demo/mission.tscn").instantiate(); host.save_enabled=false
	# Test-only room data: actual authored Cistern now has continuous floor.
	# Initial spawn above this explicit gap; gravity/Health/Defeat remain real.
	var gap_config:Dictionary={"id":"boundary_gap_fixture","title":"Boundary gap fixture","subtitle":"Test only","text":"","hint":"","width":900,"theme":"interior","platforms":[],"enemies":[],"props":[],"gaps":[Vector2(450,750)],"spawn":Vector2(560,285)}
	host.sectors.assign([gap_config]); world.add_child(host); host.start_new(true); host.input_override={}
	check(await until(func():return host.state=="dead"),"actual gap fall reaches common mission defeat")
	check(host.health.current_health==0 and host.player.get_node("DefeatResponse").active and host.deaths==1,"mission pauses only after real Health and Defeat")
	var old_id: int=host.player.get_instance_id(); host._pending_retry=true; await frames(1)
	check(host.player.get_instance_id()!=old_id and host.health.current_health==60 and host.state=="playing","ordinary retry constructs fresh life")
	host.queue_free(); paused=false; await frames(3)

func defense_crossings() -> void:
	for mode in ["guard", "parry", "roll", "brace"]:
		await begin("real fall during configured defense / "+mode, 10.0 if mode in ["parry","roll"] else 100.0)
		spawn_actor("warden" if mode=="brace" else "PC", Vector2(100,0), true)
		var receiver = actor.get_node("BoundaryReceiver")
		if mode=="brace":
			actor.get_node("IntentDriver").automatic_driver=false
			driver=Driver.new(); driver.actor=actor; world.add_child(driver)
			driver.raw={"attack":true,"attack_pressed":true}
		elif mode=="roll": driver.raw={"roll":true,"roll_pressed":true}
		else: driver.raw={"shield":true,"shield_pressed":true}
		check(await until(func():return not observed.is_empty()),"gravity crosses during real input action")
		var before: Dictionary=receiver.samples[0] if not receiver.samples.is_empty() else {}
		var held: bool=before.get("protected",false) if mode=="brace" else before.get("roll_invulnerable",false) if mode=="roll" else before.get("shield",&"")==(&"hold" if mode=="guard" else &"parry")
		check(held,"requested actual defense/protection was active at observation")
		check(health.current_health==0 and defeated==1 and processed.size()==1 and processed[0].outcome==&"hurt" and processed[0].braced==0,"boundary cannot be guarded, rolled or braced")
		traces.append({"defense":mode,"before":before,"health":processed.duplicate(true),"observation":observed.duplicate(true)})
func physical_reentry() -> void:
	await begin("actual jump reenters safe side and crosses again")
	hazard.profile.damage_mode=MokshaBoundaryProfile.Damage.FIXED;hazard.profile.damage=7
	solid(Vector2(100,150),Vector2(250,20));spawn_actor()
	check(await until(func():return actor.grounded and actor.main_action==&"locomotion" and observed.size()==1),"first fall lands beyond boundary after one debit")
	await frames(5)
	driver.raw={"jump":true,"jump_pressed":true};await frames(1);driver.raw={"jump":true}
	check(await until(func():return actor.position.y<100),"ordinary jump genuinely returns witness to safe side")
	driver.raw={}
	check(await until(func():return observed.size()==2),"later gravity makes a new real crossing")
	check(health.current_health==46 and processed.size()==2,"exactly one fixed debit per physical outside episode")

func cargo_pending_retirement() -> void:
	for mode in ["impact", "charge"]:
		await begin("genuine pending rigid "+mode+" retired by later gravity boundary",180.0)
		var target: Node2D
		if mode=="impact":
			target=spawn_actor("PC",Vector2(100,80));target.get_node("BoundaryReceiver").enabled=false
			var impact=preload("res://simulation/components/physical_impact_receiver.tscn").instantiate();target.add_child(impact)
		else:
			target=spawn_cargo(Vector2(100,60));target.get_node("BoundaryReceiver").enabled=false
		var box=CRATE.instantiate();box.set_script(preload("res://simulation/tests/boundary_pending_cargo.gd"))
		box.position=Vector2(145,60);box.collision_mask=43;box.tuning=box.tuning.duplicate(true)
		box.tuning.hard_impacts_to_break=100;box.tuning.launch_lift=0;box.tuning.launch_spin_range=Vector2.ZERO
		world.add_child(box);box.launch(-1)
		var facts: Array[Dictionary]=[]
		box.destroyed.connect(func(who):
			var held: int=who.held_impacts.size() if mode=="impact" else who.held_charges.size()
			who.release_held()
			facts.append({"held":held,"pending":who._pending.size(),"pending_charge":who._pending_charge.size(),"charge":who.charge,
				"target_health":health.current_health if mode=="impact" else 0.0,"target_charge":target.charge if mode=="charge" else 0.0}))
		check(await until(func():return not facts.is_empty(),3.0),"donor actually falls across boundary")
		check(not facts.is_empty() and facts[0].held>0,"prior pending packet came from real solver contact")
		check(not facts.is_empty() and facts[0].pending==0 and facts[0].pending_charge==0 and facts[0].charge==0,"pending authority cleared before callback replay")
		check(not facts.is_empty() and (facts[0].target_health==60 if mode=="impact" else facts[0].target_charge==0),"retired donor cannot debit target or transfer charge")
		traces.append({"pending_retirement":mode,"facts":facts})
func mission_defeat_callbacks() -> void:
	for mode in ["reset_during_entry", "replace_before_mission_observer"]:
		await begin("mission current defeat observer lifecycle / "+mode);hazard.enabled=false
		var host=preload("res://demo/mission.tscn").instantiate();host.save_enabled=false
		var config=preload("res://demo/mission_data.gd").sectors()[0].duplicate(true)
		config.spawn=Vector2(560,285);config.gaps=[Vector2(480,640)];config.enemies=[];config.props=[];config.platforms=[]
		host.sectors.assign([config]);world.add_child(host);host.start_new(true);host.input_override={}
		var old=host.player;var response=old.get_node("DefeatResponse");var fired:=[false]
		if mode=="reset_during_entry":
			old.action_changed.connect(func(_before,after):
				if after==&"defeated" and not fired[0]: fired[0]=true;old.reset_actor(Vector2(100,300),1))
		else:
			var callback: Callable
			for connection in response.defeat_started.get_connections():
				if connection.callable.get_object()==host: callback=connection.callable;response.defeat_started.disconnect(callback)
			response.defeat_started.connect(func():
				if fired[0]:return
				fired[0]=true
				var replacement=PC.instantiate();replacement.automatic_physics=false;replacement.position=Vector2(100,300)
				var replacement_health=HEALTH.instantiate();replacement_health.maximum_health=60;replacement.add_child(replacement_health);replacement.add_child(DEFEAT.instantiate())
				host.room.add_child(replacement);host.player=replacement;host.health=replacement_health)
			response.defeat_started.connect(callback)
		check(await until(func():return fired[0]),"actual fall reaches specified real defeat callback")
		check(host.state=="playing" and host.deaths==0 and not paused and host.health.current_health==60,"old defeat cannot pause/debit the fresh current life")
		host.queue_free();await frames(3)

func eligibility_and_replacement() -> void:
	await begin("receiver opt-out and explicit initial outside re-enable")
	spawn_actor();var receiver: MokshaBoundaryReceiver=actor.get_node("BoundaryReceiver");receiver.enabled=false
	await frames(hz/2);check(actor.position.y>100 and health.current_health==60 and observed.is_empty(),"disabled capability receives no fabricated outcome")
	receiver.enabled=true;await frames(2)
	check(observed.size()==1 and observed[0].initial_outside and not observed[0].crossed,"fresh eligible occupancy explicitly labelled")
	await begin("outside episode survives receiver replacement")
	hazard.profile.damage_mode=MokshaBoundaryProfile.Damage.FIXED;hazard.profile.damage=7;spawn_actor()
	await until(func():return observed.size()==1)
	receiver=actor.get_node("BoundaryReceiver");receiver.unbind();actor.remove_child(receiver);receiver.free()
	var replacement=RECEIVER.instantiate();actor.add_child(replacement);await frames(8)
	check(health.current_health==53 and observed.size()==1,"new receiver does not borrow a new outside episode")
	await begin("require-inside-first rearmed by real jump")
	hazard.initial_outside=MokshaBoundaryHazard.InitialOutside.REQUIRE_INSIDE_FIRST
	solid(Vector2(100,150),Vector2(250,20));spawn_actor("PC",Vector2(100,120))
	await until(func():return actor.grounded and actor.main_action==&"locomotion");await frames(5)
	check(observed.is_empty(),"initial outside is harmless under explicit policy")
	driver.raw={"jump":true,"jump_pressed":true};await frames(1);driver.raw={"jump":true}
	check(await until(func():return actor.position.y<100),"ordinary jump enters safe half-plane")
	driver.raw={};await until(func():return observed.size()==1)
	check(observed.size()==1 and observed[0].crossed and not observed[0].initial_outside and defeated==1,"later real crossing uses normal Health/Defeat")
func designated_cargo() -> void:
	await begin("actual freight factory cargo retirement and replacement")
	var cradle=Node2D.new();cradle.set_script(preload("res://demo/components/freight_cradle.gd"))
	cradle.position=Vector2(100,0);cradle.cargo_offset=Vector2(70,-15) # Labelled initial cradle configuration beyond its small support.
	world.add_child(cradle);await frames(2)
	var cargo=cradle.cargo;var old_id:int=cargo.get_instance_id();var terminal:=[0]
	cargo.destroyed.connect(func(_body):terminal[0]+=1)
	check(cargo.is_in_group("freight_cargo") and cargo.get_node("BoundaryReceiver").effect==MokshaBoundaryReceiver.Effect.CARGO_RETIRE,"real designated replacement factory opts into same capability")
	check(await until(func():return terminal[0]==1),"designated rigid body actually falls and retires")
	check(observed.size()==1 and observed[0].resolved,"designated source emits one terminal observation")
	check(cradle.replace_cargo(),"ordinary replacement API remains available after loss")
	await frames(2);check(is_instance_valid(cradle.cargo) and cradle.cargo.get_instance_id()!=old_id and cradle.cargo.alive,"replacement is a fresh live physical source")
