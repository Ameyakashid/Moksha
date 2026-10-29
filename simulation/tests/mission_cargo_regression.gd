extends SceneTree
## Actual production sources/hosts and raw InputMap events. Scene placement,
## controlled initial velocity, and labelled lifecycle probes are test setup.
const CARGO = preload("res://scenes/props/crate.tscn")
const MISSION_PROP = preload("res://demo/components/mission_prop.gd")
const PC = preload("res://simulation/actors/impact_player.tscn")
const SHARED = preload("res://demo/components/shared_sentinel.tscn")
const LEGACY = preload("res://demo/components/enemy.tscn")
const SENTRY = preload("res://demo/components/ranged_enemy.tscn")
const WARDEN = preload("res://demo/components/shared_warden.tscn")
const LEGACY_WARDEN = preload("res://demo/components/warden.tscn")
var hz := 120
var only := ""
var world: Node2D
var actor: Node2D
var health: Node
var cargo: RigidBody2D
var receipts: Array[Dictionary] = []
var noises: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var scenarios: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func until(test: Callable, seconds := 2.0) -> bool:
	for i in ceili(seconds * hz):
		await frames(1)
		if test.call(): return true
	return false
func check(ok: bool, label: String) -> void:
	checks.append({"scenario":scenarios.back(),"label":label,"passed":ok})
	if not ok: failures.append(scenarios.back()+": "+label)
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)
func solid(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at
	var shape := CollisionShape2D.new(); var rectangle := RectangleShape2D.new(); rectangle.size = size
	shape.shape = rectangle; body.add_child(shape); world.add_child(body); return body
func begin(label: String, kind := "PC", x := 240.0) -> void:
	scenarios.append(label); receipts.clear(); noises.clear()
	world = Node2D.new(); root.add_child(world); solid(Vector2(400,220),Vector2(1400,40))
	actor = {"PC":PC,"sentinel":SHARED,"listener":SHARED,"legacy":LEGACY,"legacy_sentry":SENTRY,"warden":WARDEN,"legacy_warden":LEGACY_WARDEN}[kind].instantiate()
	actor.position = Vector2(x,200)
	if kind == "PC": actor.initial_facing = -1; actor.allow_input = false
	else:
		actor.ai_enabled = false; actor.max_health = 30.0
		if kind == "listener": actor.archetype_profile = preload("res://demo/resources/listener_archetype.tres")
	world.add_child(actor)
	health = actor.get_node("Health" if kind in ["PC","sentinel","listener","warden"] else "StrikeHealth/Health")
	actor.get_node("PhysicalImpactReceiver").impact_resolved.connect(func(e): receipts.append(e.duplicate(true)))
	await frames(8)
	check(actor.get_node("PhysicalImpactReceiver").capture_generation() >= 0,"existing host Health/receiver bound")
func finish() -> void:
	for code in [KEY_J,KEY_K,KEY_A,KEY_D,KEY_SHIFT,KEY_SPACE]: key(code,false)
	world.queue_free(); paused = false; await frames(3)
func spawn(at: Vector2, velocity := Vector2.ZERO, charged := false, fragile := true, intercept := false) -> RigidBody2D:
	var box = CARGO.instantiate(); box.set_script(preload("res://simulation/tests/mission_cargo_interceptor.gd") if intercept else MISSION_PROP); box.collision_mask = 43
	box.position = at; box.tuning = box.tuning.duplicate(true)
	box.tuning.hard_impacts_to_break = 100
	box.tuning.body_gravity_scale = 0.0 if not velocity.is_zero_approx() else 1.0
	box.linear_velocity = velocity
	world.add_child(box)
	box.impact_profile.break_on_accepted_impact = fragile
	if charged: box.charge = box.tuning.charge_seconds # Labelled initial-state charge setup, not launch evidence.
	return box
func noise(at: Vector2, kind: StringName, loudness: float, source: Node) -> void:
	noises.append({"at":at,"kind":kind,"loudness":loudness,"source_id":source.get_instance_id() if is_instance_valid(source) else 0})
func _run() -> void:
	seed(617)
	root.get_node("NoiseBus").noise_emitted.connect(noise)
	if only in ["","raw"]: await raw_launch_hosts()
	if only in ["","eligibility"]: await eligibility_and_defense()
	if only in ["","lifecycle"]: await source_lifecycle()
	if only in ["","chain"]: await real_chains()
	if only in ["","warden"]: await warden_brace()
	if only in ["","mission"]: await mission_factory()
	var report := {"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures,
		"scope":"Real rigid-body contacts and raw InputMap launches/defense; explicit initial-state/API lifecycle probes labelled; four full mission routes are separate."}
	FileAccess.open("res://simulation/evidence/cargo_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("MISSION CARGO %d Hz: %d scenarios, %d checks, %d failures"%[hz,scenarios.size(),checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
func raw_launch_hosts() -> void:
	for kind in ["PC","sentinel","listener","legacy","legacy_sentry","legacy_warden","warden"]:
		await begin("raw sword launches production cargo into "+kind,kind,230.0)
		var launcher = PC.instantiate(); launcher.position = Vector2(100,200); world.add_child(launcher)
		cargo = spawn(Vector2(136,183))
		cargo.tuning.launch_lift = 0; cargo.tuning.launch_spin_range = Vector2.ZERO
		var cargo_id := cargo.get_instance_id(); var launches := [0]; var impacts := [0]; var destroys := [0]
		cargo.launched.connect(func(_box): launches[0] += 1)
		cargo.impacted.connect(func(_box,_target,_amount,_direction): impacts[0] += 1)
		cargo.destroyed.connect(func(_box): destroys[0] += 1)
		await frames(5); key(KEY_J,true); await frames(1); key(KEY_J,false)
		check(await until(func(): return not receipts.is_empty()),"raw J -> actual sword contact -> rigid target contact")
		check(launches[0] == 1 and health.current_health == 27.0,"same authored three damage from one genuine launch")
		if not receipts.is_empty():
			check(receipts[0].accepted and receipts[0].normal_speed >= 80.0 and receipts[0].epoch == 2,"source-owned epoch and contact-point closing evidence")
			check(Vector2(receipts[0].impulse).is_equal_approx(Vector2(180,-80)) and actor.velocity.x > 0.0,"same exact requested impulse through existing host motion owner")
		check(impacts[0] == 1 and destroys[0] == 1 and not is_instance_valid(cargo),"one accepted fragile impact and destruction")
		check(noises.filter(func(e): return e.source_id == cargo_id and e.kind == &"prop_launch").size() == 1 and noises.filter(func(e): return e.source_id == cargo_id and e.kind == &"prop_break").size() == 1,"one launch and one break sound retain actual cargo source")
		check(launcher.get_node("Health").current_health == 30.0,"launch does not fabricate a self-hit before real recontact")
		await finish()
func eligibility_and_defense() -> void:
	for kind in ["PC","sentinel","legacy_sentry","warden"]:
		await begin("uncharged falling mission cargo stays harmless "+kind,kind)
		cargo = spawn(Vector2(240,70)); await frames(hz)
		check(health.current_health == 30.0 and receipts.is_empty() and cargo.captured_contacts == 0,"real passive contact has no mission damage permit")
		check(cargo._contact_speed >= 0 and noises.any(func(e):return e.kind == &"prop_impact"),"material collision still emits physical noise")
		await finish()
	for mode in ["disabled","wall","slow","expiry","tangent","rotation"]:
		await begin("charged admission "+mode)
		if mode == "disabled": actor.get_node("PhysicalImpactReceiver").enabled = false
		if mode == "wall": solid(Vector2(175,165),Vector2(12,70))
		cargo = spawn(Vector2(120,180),Vector2(280,0),true,false)
		if mode == "slow": cargo.linear_velocity = Vector2(20,0); cargo.position.x = 210
		if mode == "expiry": cargo.charge = 0.06
		if mode == "tangent": cargo.position = Vector2(211,180); cargo.linear_velocity = Vector2(0,-300)
		if mode == "rotation": cargo.position = Vector2(214,180); cargo.linear_velocity = Vector2.ZERO; cargo.angular_velocity = 25.0
		await frames(hz)
		if mode == "rotation": check(health.current_health == 27.0 and not receipts.is_empty() and receipts[0].source_contact_velocity.length() >= 80.0,"rotating corner's real point speed admits without COM motion")
		else: check(health.current_health == 30.0 and receipts.is_empty(),"no damage without eligible real normal-closing charged contact")
		check(cargo.alive,"rejection cannot invoke legacy break or damage")
		cargo.impact_enemy(actor)
		check(health.current_health == (27.0 if mode == "rotation" else 30.0),"public legacy cargo entry is retired")
		await finish()
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
func source_lifecycle() -> void:
	for mode in ["expiry","relaunch","disable","replacement","host_reset","receipt_reset"]:
		await begin("captured genuine contact retirement "+mode,"sentinel")
		cargo = spawn(Vector2(120,180),Vector2(280,0),true,true,true)
		var interrupted := [false]
		if mode == "receipt_reset": actor.get_node("PhysicalImpactReceiver").impact_resolved.connect(func(_e):actor.reset_at(actor.position))
		else:
			cargo.before_delivery = func(_target,_receiver,_packet):
				if interrupted[0]: return
				interrupted[0] = true
				match mode:
					"expiry": cargo.charge = 0.0; cargo.invalidate_pending_contacts()
					"relaunch": cargo.launch(-1)
					"disable": cargo.set_impact_simulation_enabled(false)
					"replacement": cargo.alive = false; cargo.invalidate_pending_contacts()
					"host_reset": actor.reset_at(actor.position)
		check(await until(func():return cargo.captured_contacts > 0),"interceptor sees only actual source-captured contact")
		await frames(5)
		check(health.current_health == 30.0,"stale contact cannot debit current host life")
		check(cargo.alive or mode == "replacement","stale response cannot authorize impact break")
		if mode != "receipt_reset": check(receipts.is_empty(),"retired response has no completed receiver receipt")
		await finish()
	await begin("real recontact needs a new launch epoch","sentinel")
	cargo = spawn(Vector2(120,178),Vector2(260,0),true,false)
	cargo.tuning.launch_lift = 0; cargo.tuning.launch_spin_range = Vector2.ZERO
	check(await until(func():return health.current_health == 27.0),"first charged real contact damages once")
	await frames(ceili(hz*.55)); var epoch: int = cargo.impact_epoch
	cargo.launch(1,NAN); check(cargo.impact_epoch == epoch,"invalid launch cannot rearm")
	cargo.launch(1)
	check(await until(func():return health.current_health == 24.0),"new valid launch has actual second contact and new debit")
	check(receipts.size() == 2 and cargo.impact_epoch == epoch+1,"relaunch alone advances epoch and clears visited actors")
	await finish()
func real_chains() -> void:
	await begin("raw sword chain transfers real momentum and bounded charge","PC",260.0)
	var launcher = PC.instantiate(); launcher.position = Vector2(100,200); world.add_child(launcher)
	var first := spawn(Vector2(136,184),Vector2.ZERO,false,false)
	var second := spawn(Vector2(200,184),Vector2.ZERO,false,false)
	for box in [first,second]: box.tuning.launch_lift = 0; box.tuning.launch_spin_range = Vector2.ZERO
	var transfers: Array[Dictionary] = []; first.physical_charge_resolved.connect(func(e):transfers.append(e.duplicate(true)))
	await frames(6); key(KEY_J,true); await frames(1); key(KEY_J,false)
	check(await until(func():return not transfers.is_empty()),"raw sword launch creates real donor/recipient rigid contact")
	check(second.charge > 0 and second.position.x > 200 and second.hit_count == 0 and second.impact_epoch == 1,"chain transfers charge/momentum without synthetic launch or new epoch")
	check(await until(func():return health.current_health < 30.0),"chain-recipient cargo physically reaches registered actor")
	check(receipts.any(func(e):return e.source_id == second.get_instance_id() and e.epoch == 1),"recipient owns its actual contact permit")
	await frames(hz*4)
	check(first.charge <= 0 and second.charge <= 0 and first.charge_transfers == 1,"rest/recontact cannot perpetually renew donor-epoch charge")
	check(transfers.size() == 1 and transfers[0].normal_speed > first.tuning.chain_speed,"one donor-epoch transfer uses relative normal speed")
	await finish()
func warden_brace() -> void:
	await begin("actual cargo preserves Warden brace capability","warden",240.0)
	var target = PC.instantiate(); target.position = Vector2(275,200); target.allow_input = false; world.add_child(target)
	actor.configure(target,root.get_node("NoiseBus")); actor.ai_enabled = true
	check(await until(func():return actor.ai_state == &"windup"),"autonomous real target observation commits Warden warning")
	cargo = spawn(Vector2(195,174),Vector2(360,0),true,false)
	check(await until(func():return not receipts.is_empty()),"charged cargo reaches Warden during genuine windup")
	check(health.current_health == 27.0 and actor.braced_contacts == 1 and actor.main_action != &"hurt","same damage3; authored bracing suppresses short cargo impulse/stun")
	check(actor.ai_state in [&"windup",&"active"],"brace preserves committed action rather than forcing a fake stagger")
	await finish()
func mission_factory() -> void:
	scenarios.append("production mission factories, cargo hazard and retry")
	var host = preload("res://demo/mission.tscn").instantiate(); root.add_child(host); host.save_enabled = false; host.start_new(true); host.input_override = {}
	for enemy in host.enemies: enemy.ai_enabled = false
	await frames(8)
	check(host.player.get_node_or_null("PhysicalImpactReceiver") != null and host.player.get_node("PhysicalImpactReceiver").capture_generation() >= 0,"production PC now composes genuine impact receiver")
	var props := get_nodes_in_group("props").filter(func(p):return host.room.is_ancestor_of(p))
	check(not props.is_empty() and props.all(func(p):return p.get_script() == MISSION_PROP and p.collision_mask == 43 and p.impact_profile.requires_charge),"all ordinary mission props use common charged source and shared physical mask")
	check(host.enemies.all(func(e):return e.get_node_or_null("PhysicalImpactReceiver") != null),"all present mission actors expose configured receiver")
	var pc_ref = host.player; var hp: float = host.health.current_health
	var hazard = CARGO.instantiate(); hazard.set_script(MISSION_PROP); hazard.collision_mask = 43; hazard.position = host.player.position+Vector2(0,-100)
	hazard.tuning = hazard.tuning.duplicate(true); hazard.tuning.hard_impacts_to_break = 100; host.room.add_child(hazard); hazard.charge = 2.5
	check(await until(func():return host.health.current_health < hp),"real falling charged hazard can injure ordinary production PC")
	check(host.health.current_health == hp-3.0,"production PC has no silent cargo immunity")
	host.load_sector(host.sector); await frames(8)
	check(host.player != pc_ref and host.health.current_health == 60.0 and host.player.get_node("PhysicalImpactReceiver").capture_generation() >= 0,"real room retry replaces source/actor lifetimes and restores receiver")
	host.load_sector(3); await frames(8)
	if host.room.freight_cradle != null:
		var freight = host.room.freight_cradle.cargo
		check(freight.get_script() == MISSION_PROP and freight.collision_mask == 43,"freight cradle uses exact same mission source/mask")
	else: check(false,"expected freight room fixture index")
	host.queue_free(); paused = false; await frames(3)
