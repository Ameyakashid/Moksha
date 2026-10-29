extends "res://simulation/tests/mission_cargo_regression.gd"
## Repeat inherited real-contact admission/defense/lifecycle/chain fixtures with
## the actual production PC material/contact configuration, not stock defaults.
func begin(next_label: String, kind := "PC", x := 240.0) -> void:
	await super.begin(next_label,kind,x)
	if kind == "PC":
		var config := Node.new(); config.set_script(preload("res://simulation/components/actor_contact_config.gd"))
		config.profile = preload("res://demo/resources/player_contact.tres")
		actor.add_child(config)
		check(actor.collision_mask == 9 and actor.terrain_mask == 9 and actor.material_profile != null,"actual production PC material and support masks applied")
func spawn(at: Vector2, velocity := Vector2.ZERO, charged := false, fragile := true, intercept := false) -> RigidBody2D:
	var box = CARGO.instantiate(); box.set_script(preload("res://simulation/tests/mission_cargo_interceptor.gd") if intercept else preload("res://simulation/tests/actor_cargo_rigid_probe.gd")); box.collision_mask = 43
	box.position = at; box.tuning = box.tuning.duplicate(true)
	box.tuning.hard_impacts_to_break = 100
	box.tuning.body_gravity_scale = 0.0 if not velocity.is_zero_approx() else 1.0
	box.linear_velocity = velocity
	world.add_child(box)
	box.impact_profile.break_on_accepted_impact = fragile
	if charged: box.charge = box.tuning.charge_seconds # Labelled initial-state charge setup, not launch evidence.
	return box

var material_observations:Array[Dictionary]=[]
func _run() -> void:
	seed(617)
	root.get_node("NoiseBus").noise_emitted.connect(noise)
	await production_defense()
	await source_lifecycle()
	await production_chain(false)
	await production_chain(true)
	await returning_own_cargo()
	var report := {"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures,"material_observations":material_observations,"scope":"Inherited actual rigid contact/defense fixtures with production PC contact/material configuration; lifecycle/API probes explicitly labelled by inherited fixture."}
	FileAccess.open("res://simulation/evidence/actor_cargo_defense_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PRODUCTION ACTOR CARGO DEFENSE %d Hz: %d checks, %d failures"%[hz,checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func production_defense() -> void:
	for mode in ["guard","parry","rear","roll"]:
		await begin("raw configured PC defense "+mode)
		actor.allow_input = true
		if mode == "rear": actor.facing = 1
		if mode in ["guard","rear"]: key(KEY_K,true); await frames(ceili(hz*.3))
		cargo = spawn(Vector2(120,178),Vector2(260,0),true,false)
		if mode in ["parry","roll"]:
			await until(func():return cargo.position.x >= 195.0)
			key(KEY_K if mode == "parry" else KEY_SHIFT,true)
		check(await until(func():return not receipts.is_empty()),"real approaching crate reaches defense surface")
		if not receipts.is_empty():
			var expected: StringName = {"guard":&"guarded","parry":&"parried","rear":&"hurt","roll":&"evaded"}[mode]
			check(receipts[0].outcome == expected,"existing controller owns configured defense outcome")
			check(health.current_health == {"guard":29.25,"parry":30.0,"rear":27.0,"roll":30.0}[mode],"Health reports actual residual defense damage")
		check(actor.get_node("ShieldContactAdapter").confirmed_reflections == 0 and actor.get_node("ShieldContactAdapter").confirmed_counters == 0,"cargo never advertises rigid reflection or a melee counter")
		await finish()

func production_chain(pinned: bool) -> void:
	await begin("raw sword chain into production PC "+("wall-backed" if pinned else "free"),"PC",260.0)
	if pinned: solid(Vector2(278,160),Vector2(20,80))
	var launcher = PC.instantiate(); launcher.position = Vector2(100,200); world.add_child(launcher)
	var first := spawn(Vector2(136,184),Vector2.ZERO,false,false)
	var second := spawn(Vector2(200,184),Vector2.ZERO,false,false)
	for box in [first,second]: box.tuning.launch_lift = 0; box.tuning.launch_spin_range = Vector2.ZERO
	var transfers: Array[Dictionary] = []; first.physical_charge_resolved.connect(func(e):transfers.append(e.duplicate(true)))
	await frames(6); key(KEY_J,true); await frames(1); key(KEY_J,false)
	check(await until(func():return not transfers.is_empty()),"raw sword launch creates real donor/recipient rigid contact")
	check(second.charge > 0 and second.position.x > 200 and second.hit_count == 0 and second.impact_epoch == 1,"chain transfers charge/momentum without synthetic launch or new epoch")
	var admitted:=await until(func():return health.current_health < 30.0)
	if pinned:
		check(admitted and health.current_health==27.0,"wall-backed actual recipient contact applies exact authored damage")
		check(receipts.any(func(e):return e.source_id == second.get_instance_id() and e.epoch == 1 and e.normal_speed>=80),"recipient owns qualified actual normal-speed contact permit")
	else:
		check(not admitted and not second.material_contacts.is_empty(),"free actor has genuine contact but no unqualified damage")
		check(second.material_contacts.all(func(e):return e.normal_speed<80),"observed normal-relative point speeds explain unbraced rejection")
	material_observations.append({"scenario":"wall-backed chain" if pinned else "free chain","contacts":second.material_contacts.duplicate(true),"receipts":receipts.duplicate(true),"transfers":transfers.duplicate(true)})
	await frames(hz*4)
	check(first.charge <= 0 and second.charge <= 0 and first.charge_transfers == 1,"rest/recontact cannot perpetually renew donor-epoch charge")
	check(transfers.size() == 1 and transfers[0].normal_speed > first.tuning.chain_speed,"one donor-epoch transfer uses relative normal speed")
	await finish()
func returning_own_cargo() -> void:
	await begin("production PC real wall ricochet returns own launch","PC",120.0)
	actor.facing=1; actor.allow_input=true
	solid(Vector2(250,160),Vector2(16,80))
	cargo=spawn(Vector2(155,178),Vector2.ZERO,false,false)
	cargo.tuning.launch_lift=0; cargo.tuning.launch_spin_range=Vector2.ZERO
	cargo.gravity_scale=0; cargo.linear_damp=0; cargo.physics_material_override.bounce=1.0; cargo.physics_material_override.friction=0.0
	await frames(6); key(KEY_J,true); await frames(1); key(KEY_J,false)
	check(await until(func():return not receipts.is_empty()),"raw J launch rebounds through Godot wall solve into original launcher")
	check(cargo.hit_count==1 and health.current_health==27.0,"one real own-cargo recontact applies exact authored damage")
	if not receipts.is_empty(): check(receipts[0].normal_speed>=80 and receipts[0].source_contact_velocity.x<0 and receipts[0].epoch==2,"return receipt preserves actual reversed closing velocity and launch epoch")
	await finish()
