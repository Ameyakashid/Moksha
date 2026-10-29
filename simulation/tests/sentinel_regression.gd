extends SceneTree
## Actual migrated production scene and real mission factory. Setup placements and
## explicitly labelled lifecycle probes are not gameplay outcome simulations.
const SENTINEL = preload("res://demo/components/shared_sentinel.tscn")
const PLAYER = preload("res://combat_pc/player.tscn")
const INCOMING = preload("res://simulation/components/incoming_strike_receiver.tscn")
const HEALTH = preload("res://combat_pc/components/health_component.tscn")
const DEFEAT = preload("res://combat_pc/components/defeat_response.tscn")
class Driver extends Node:
	var actor: Node
	var frame := {}
	func _physics_process(dt: float) -> void:
		if is_instance_valid(actor): actor.physics_tick(dt, frame)
var hz := 120
var world: Node2D
var pc: Node2D
var npc: Node2D
var driver: Driver
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var scenarios: Array[String] = []
var events: Array[Dictionary] = []
var receipts: Array[Dictionary] = []
var defeats := 0
var source_confirmations := 0
var report_prefix := "sentinel"
func new_npc() -> Node2D:
	return SENTINEL.instantiate()
func check_authored_tuning() -> void:
	check(npc.health == 3 and npc._damage == 12 and npc._windup == 0.56 and npc.profile.run_speed == 82 and npc.profile.standing_height == 36, "authored production tuning and mission override")
func additional_scenarios() -> void:
	pass
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"scenario":scenarios.back(),"label":label,"passed":ok})
	if not ok: failures.append(scenarios.back() + ": " + label)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func until(predicate: Callable, seconds := 2.5) -> bool:
	for i in ceili(seconds * hz):
		await frames(1)
		if predicate.call(): return true
	return false
func surface(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return body
func bus_noise(origin: Vector2, kind: StringName, loudness: float, source: Node) -> void:
	events.append({"origin":origin,"kind":kind,"loudness":loudness,"source_id":source.get_instance_id() if is_instance_valid(source) else 0,"source_position":source.global_position if source is Node2D else Vector2.ZERO,"source_facing":source.facing if is_instance_valid(source) and source.has_method("noise_generation") else 0})
func count_noise(kind: StringName, source: Node) -> int:
	return events.filter(func(e): return e.kind == kind and e.source_id == source.get_instance_id()).size()
func begin(label: String, health := 3.0, px := 100.0, nx := 136.0, width := 800.0) -> void:
	scenarios.append(label)
	events.clear(); receipts.clear(); defeats = 0; source_confirmations = 0
	world = Node2D.new(); root.add_child(world)
	surface(Vector2(width / 2, 220), Vector2(width, 40))
	pc = PLAYER.instantiate(); pc.automatic_physics = false; pc.position = Vector2(px, 200)
	var hp = HEALTH.instantiate(); hp.name = "Health"; hp.maximum_health = 60.0; pc.add_child(hp)
	var defeat = DEFEAT.instantiate(); defeat.name = "DefeatResponse"; pc.add_child(defeat)
	var receiver = INCOMING.instantiate(); receiver.counterable = true; pc.get_node("BodyShape").add_child(receiver)
	world.add_child(pc)
	driver = Driver.new(); driver.actor = pc; world.add_child(driver)
	npc = new_npc(); npc.position = Vector2(nx, 200); npc.max_health = health; npc.attack_damage_override = 12.0; npc.ai_enabled = false
	world.add_child(npc); npc.configure(pc, root.get_node("NoiseBus"))
	npc.defeated.connect(func(_who): defeats += 1)
	npc.get_node("ContactAdapter").contact_confirmed.connect(func(_actor, _target, _position, _serial, _kind): source_confirmations += 1)
	receiver.strike_resolved.connect(func(e): receipts.append(e.duplicate(true)))
	await frames(8)
func finish() -> void:
	world.queue_free(); await frames(2)
func attack() -> void:
	npc.ai_enabled = true
func _run() -> void:
	root.get_node("NoiseBus").noise_emitted.connect(bus_noise)
	await begin("production composition and shared physical contact")
	check(npc is MokshaCombatPlayer and npc.get_script().get_base_script().resource_path == "res://combat_pc/player.gd", "facade inherits authoritative combat controller")
	check(not npc.automatic_physics and npc.get_node("IntentDriver").tick_count > 0, "sole intent scheduler ticks")
	check(npc.collision_layer == 32 and npc.collision_mask == 9 and npc.get_node("BodyShape/IncomingStrikeReceiver").collision_layer == 4 and npc.get_node("ContactAdapter").target_mask == 72, "explicit no-friendly-fire contact configuration")
	check(npc.is_in_group("enemies") and npc.is_in_group("actors") and not npc.is_in_group("combat_pc"), "mission groups replace PC role membership")
	check_authored_tuning()
	driver.frame = {"attack":true}
	check(await until(func(): return npc.health < 3), "stock PC actual sweep hits migrated sentinel")
	driver.frame = {}
	check(npc.health == 2 and npc.main_action == &"hurt" and npc.velocity.x > 0, "one physical hit debits Health and controller applies recoil")
	check(count_noise(&"enemy_damage", npc) == 1 and count_noise(&"hurt", npc) == 0, "one Health-confirmed semantic HIT bus event")
	var hit_event: Dictionary = events.filter(func(e): return e.kind == &"enemy_damage" and e.source_id == npc.get_instance_id())[0]
	check(hit_event.origin.is_equal_approx(hit_event.source_position + Vector2(0,-20)) and hit_event.loudness == 0.9, "HIT preserves authored actor-response origin and loudness")
	await finish()
	for mode in ["hurt", "guard", "parry", "lethal_parry"]:
		await begin("sentinel actual incoming " + mode, 3 if mode == "lethal_parry" else 8)
		if mode == "guard": driver.frame = {"shield":true}; await frames(ceili(hz * 0.25))
		attack()
		check(await until(func(): return npc.ai_state == &"windup"), "autonomous observations request genuine controller windup")
		check(count_noise(&"enemy_windup",npc) == 1, "one committed warning with real source")
		var warning: Dictionary = events.filter(func(e): return e.kind == &"enemy_windup" and e.source_id == npc.get_instance_id())[0]
		check(warning.origin.is_equal_approx(warning.source_position + Vector2(0,-26)) and warning.loudness == 0.8, "warning retains committed actor origin and authored loudness")
		if mode in ["parry", "lethal_parry"]:
			await until(func(): return npc._phase_elapsed >= npc._windup - 0.10)
			driver.frame = {"shield":true}
		check(await until(func(): return not receipts.is_empty()), "physical active overlap produces completed defender receipt")
		npc.ai_enabled = false
		var expected: StringName = &"parried" if mode in ["parry", "lethal_parry"] else (&"guarded" if mode == "guard" else &"hurt")
		check(not receipts.is_empty() and receipts[0].outcome == expected, "existing controller adjudicates expected defense")
		check(pc.get_node("Health").current_health == (48.0 if mode == "hurt" else (57.0 if mode == "guard" else 60.0)), "mission damage12 and 75 percent guard retained")
		check(count_noise(&"enemy_attack",npc) == 1 and count_noise(&"strike",npc) == 0, "one semantic active event, no generic duplicate")
		var strike: Dictionary = events.filter(func(e): return e.kind == &"enemy_attack" and e.source_id == npc.get_instance_id())[0]
		check(strike.origin.is_equal_approx(strike.source_position + Vector2(strike.source_facing * 25.5,-22)) and strike.loudness == 1.0, "strike preserves real shared strike-center origin and authored loudness")
		if mode in ["parry", "lethal_parry"]:
			check(pc.get_node("ShieldContactAdapter").confirmed_counters == 1 and npc.get_node("ShieldCounterReceiver").accepted_count == 1, "actual counter ray confirms exactly once")
			check(npc.health == (0 if mode == "lethal_parry" else 5), "counter Health loss bounded by remaining life")
			check(npc.weapon_phase == &"idle" and source_confirmations == 0, "counter recoil cancels source sweep and stale confirmation")
			check(npc.last_attack_result.get("outcome") == &"parried" and npc.last_attack_result.get("counter_confirmed",false), "mission facade retains completed confirmed-counter parry only")
		if mode == "lethal_parry":
			await frames(2)
			check(npc.dead and defeats == 1 and npc.collision_layer == 0 and npc.get_node("BodyShape").disabled and not npc.is_physics_processing(), "terminal cleanup removes collision and scheduling after receipt")
			check(count_noise(&"enemy_damage",npc) == 1 and count_noise(&"enemy_death",npc) == 1, "one genuine HIT and DOWN")
			var serial: int = npc.attack_serial
			npc.reset_at(Vector2(136,200)); await frames(3)
			check(not npc.dead and npc.health == 3 and npc.collision_layer == 32 and not npc.get_node("BodyShape").disabled and npc.is_physics_processing(), "reset restores physical composition and health")
			check(npc.attack_serial == serial and npc.last_attack_result.is_empty(), "reset keeps lifetime attack serial and clears diagnostics")
		await frames(ceili(hz * 0.25))
		check(receipts.size() == 1, "active samples do not double-hit or create ghost strike")
		await finish()
	await begin("solid wall blocks actual AI sight")
	surface(Vector2(118,165),Vector2(8,70)); await frames(3); attack(); await frames(hz)
	check(npc.attack_serial == 0 and receipts.is_empty(), "actual wall blocks AI sight")
	await finish()
	await begin("out-of-detection range cannot invent target contact", 3, 30, 600)
	attack(); await frames(hz * 2)
	check(npc.attack_serial == 0 and receipts.is_empty() and pc.get_node("Health").current_health == 60, "distant player causes neither attack request nor fallback damage")
	await finish()
	await begin("actual rear strike bypasses held front guard", 8, 136, 100)
	driver.frame = {"shield":true}; await frames(ceili(hz * 0.25)); attack()
	check(await until(func(): return not receipts.is_empty()), "rear production strike reaches real PC receiver")
	npc.ai_enabled = false
	check(pc.facing == 1 and not receipts.is_empty() and receipts[0].outcome == &"hurt" and pc.get_node("Health").current_health == 48, "existing directional shield rejects rear block and debits mission12")
	await finish()
	await begin("escaped target and latched facing")
	attack(); await until(func(): return npc.ai_state == &"windup")
	driver.frame = {"right":1.0,"roll":true}
	await frames(ceili(hz * 0.85)); driver.frame = {}; npc.ai_enabled = false
	check(receipts.is_empty() and pc.position.x > npc.position.x, "ordinary roll escapes latched physical strike")
	await finish()
	await begin("missing mission receiver cannot be invented")
	pc.get_node("BodyShape/IncomingStrikeReceiver").queue_free(); await frames(3); attack(); await frames(hz * 2)
	check(pc.get_node("Health").current_health == 60 and npc.attack_serial > 0, "no receiver means no fallback fabricated hit")
	await finish()
	await begin("real raw PC launch then stock-crate contact", 8, 30, 170)
	var crate = preload("res://scenes/props/crate.tscn").instantiate(); crate.position = Vector2(66,183); crate.collision_mask = 33; world.add_child(crate)
	var crate_launches := [0]
	crate.launched.connect(func(_prop): crate_launches[0] += 1)
	await frames(5)
	driver.frame = {"attack":true}; await frames(1); driver.frame = {}
	check(await until(func(): return npc.health < 8, 1.5), "raw sword launch reaches sentinel through real rigid contact")
	check(crate_launches[0] == 1 and npc.health == 5, "stock prop launch dedupes one legacy shim Health debit")
	check(npc.main_action == &"hurt" and count_noise(&"enemy_damage",npc) == 1, "legacy prop response remains controller and Health owned")
	await finish()
	await begin("support removal and edge observation", 3, 30, 140, 200)
	npc.configure(null,root.get_node("NoiseBus")); npc.patrol_radius = 500; attack(); await frames(hz * 2)
	check(npc.position.x < 198 and npc.position.y < 201, "intent patrol brakes before real edge")
	world.get_child(0).queue_free(); await frames(ceili(hz * 0.3))
	check(not npc.grounded and npc.position.y > 210, "shared gravity falls when actual support disappears")
	await finish()
	await begin("committed action survives ai disable; gravity continues")
	attack(); await until(func(): return npc.ai_state == &"windup")
	npc.ai_enabled = false
	check(await until(func(): return not receipts.is_empty()), "decision disable does not secretly cancel committed controller action")
	await finish()
	await begin("hearing peers are explicit configuration")
	npc.configure(null,root.get_node("NoiseBus"))
	var sources: Array[Node] = []
	for path in ["res://demo/components/enemy.tscn","res://demo/components/ranged_enemy.tscn","res://demo/components/warden.tscn"]:
		var actor = load(path).instantiate(); actor.position = Vector2(500,200); actor.ai_enabled = false; world.add_child(actor); sources.append(actor)
	await frames(2)
	for index in sources.size():
		npc.get_node("SentinelPolicy").noise_memory = 0
		npc.hear_noise(npc.global_position+Vector2(-70,0),&"enemy_step",1.0,sources[index])
		check((npc._noise_memory == 0) == (index == 0), "shared sentinel peer filter retains legacy equivalence %d" % index)
		var legacy = sources[index]; legacy._noise_memory = 0; legacy.hear_noise(legacy.global_position,&"enemy_step",1.0,npc)
		check((legacy._noise_memory == 0) == (index == 0), "legacy peer filter hears migrated sentinel as before %d" % index)
		legacy._noise_memory = 0; legacy.hear_noise(legacy.global_position,&"enemy_step",1.0,legacy)
		check(legacy._noise_memory == 0, "legacy own peer source ignored %d" % index)
	npc.get_node("SentinelPolicy").noise_memory = 0; root.get_node("NoiseBus").emit_noise(npc.global_position+Vector2(-70,0),&"weapon_tap",1,pc); attack()
	await frames(ceili(hz * 0.35))
	check(npc.ai_state == &"investigate" and npc.position.x < 130, "shared hearing receipt drives ordinary investigation input")
	await finish()
	await begin("same-stack defeat reset fences deferred cleanup", 3)
	npc.defeated.connect(func(_who): npc.reset_at(Vector2(136,200)), CONNECT_ONE_SHOT)
	npc.take_hit(99,1,true) # Explicit lifecycle API probe, not contact evidence.
	await frames(3)
	check(not npc.dead and npc.health == 3 and npc.collision_layer == 32 and not npc.get_node("BodyShape").disabled and npc.is_physics_processing(), "stale terminal cleanup cannot disable reset life")
	await finish()
	await _hearing_retirement()
	await _no_bus_semantics()
	await _mission_factory()
	await additional_scenarios()
	var report := {"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures,"scope":"Production shared sentinel and mission composition, actual controller contacts/sounds/physics; explicit lifecycle probes labeled."}
	report["archetype"] = report_prefix
	FileAccess.open("res://simulation/evidence/%s_%d.json" % [report_prefix,hz], FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("SHARED %s %d Hz: %d scenarios, %d checks, %d failures" % [report_prefix.to_upper(),hz,scenarios.size(),checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
func _mission_factory() -> void:
	scenarios.append("actual mission factory, shared damage and room-clear lifecycle")
	var host = preload("res://demo/mission.tscn").instantiate(); root.add_child(host); host.save_enabled = false; host.start_new(true); host.input_override = {}
	for actor in host.enemies: actor.ai_enabled = false
	await frames(4)
	var sentinel = host.enemies[0]
	check(sentinel.get_script().resource_path == "res://demo/components/shared_sentinel.gd", "F5 mission factory actually instantiates migrated sentinel")
	check(host.player.get_node_or_null("IntentDriver") == null and host.player.get_node("Health") == host.health and host.player.get_node("BodyShape/IncomingStrikeReceiver").collision_layer == 64, "mission PC adds only incoming bridge to existing scheduler and Health")
	var initial: Vector2 = sentinel.position
	host.player.reset_actor(initial-Vector2(36,0),1); await frames(4)
	host.input_override = {"attack":true}; await frames(1); host.input_override = {}
	check(await until(func(): return sentinel.health < 3), "actual production PC attacks actual production sentinel")
	check(host.sonar.event_history.any(func(e): return e.source_id == sentinel.get_instance_id() and e.kind == &"enemy_damage"), "real sentinel Health debit reaches production sonar")
	var kills: int = host.kills
	sentinel.take_hit(99,1,true) # Labeled host lifecycle boundary, not route gameplay.
	await frames(2)
	check(host.kills == kills + 1 and sentinel.dead, "one genuine depletion updates mission kill count")
	sentinel.take_hit(99,1,true); await frames(1)
	check(host.kills == kills + 1, "dead compatibility call cannot duplicate room clear")
	host.load_sector(1); await frames(3)
	check(host.enemies.any(func(e): return e.kind == "sentinel" and e.get_node_or_null("IntentDriver") != null), "sector transitions retain shared sentinel factory")
	for actor in host.enemies: actor.ai_enabled = false
	check(not host.room.gate_open and host.remaining_enemies() > 0, "locked room begins closed with live actors")
	# Explicit host/depletion boundary to verify room accounting, not a route.
	for actor in host.enemies: actor.take_hit(999,1,true)
	host.relay_on = true
	host._update_gate()
	await frames(2)
	check(host.remaining_enemies() == 0 and host.room.gate_open, "one defeat per actor permits the real room-clear gate")
	host.load_sector(1); await frames(3)
	check(host.remaining_enemies() > 0 and not host.room.gate_open and host.health.current_health == 60, "retry restores encounters, gate and existing player Health")
	host.queue_free(); paused = false; await frames(2)

func _hearing_retirement() -> void:
	for operation in ["reset", "configure", "pause", "pause_resume", "disable_enable", "sensor_unbind", "sensor_rebind", "always_pause_resume", "sensor_disabled"]:
		await begin("earlier real-hearing callback retires " + operation)
		var listener = new_npc()
		listener.ai_enabled = false
		if operation == "always_pause_resume": listener.process_mode = Node.PROCESS_MODE_ALWAYS
		listener.position = Vector2(300,200)
		var changed := [false]
		listener.get_node("HearingSensor").heard.connect(func(_evidence):
			if changed[0]: return
			changed[0] = true
			match operation:
				"reset": listener.reset_at(listener.position)
				"configure": listener.configure(null,root.get_node("NoiseBus"))
				"pause": paused = true
				"pause_resume", "always_pause_resume": paused = true; paused = false
				"sensor_disabled": listener.get_node("HearingSensor").enabled = false
				"disable_enable": listener.enabled = false; listener.enabled = true
				"sensor_unbind": listener.get_node("HearingSensor").unbind()
				"sensor_rebind": listener.get_node("HearingSensor").bind(listener,root.get_node("NoiseBus"))
		)
		world.add_child(listener); listener.configure(pc,root.get_node("NoiseBus"))
		await frames(3)
		root.get_node("NoiseBus").emit_noise(pc.position,&"weapon_tap",1.0,pc)
		check(changed[0] and listener._noise_memory == 0, "old signal cannot install new-life or retired intention")
		paused = false
		if operation == "sensor_unbind": listener.get_node("HearingSensor").bind(listener,root.get_node("NoiseBus"))
		listener.enabled = true
		listener.get_node("HearingSensor").enabled = true
		root.get_node("NoiseBus").emit_noise(pc.position,&"weapon_tap",1.0,pc)
		check(listener._noise_memory > 0, "later genuine evidence remains usable after retirement")
		await finish()
func _no_bus_semantics() -> void:
	await begin("no-bus semantic signal remains single committed event")
	npc.configure(pc,null)
	var requested: Array = []
	var committed: Array = []
	npc.noise_requested.connect(func(_origin, kind, _loudness, _source): requested.append(kind))
	npc.noise_committed.connect(func(event): committed.append(event.kind))
	events.clear()
	driver.frame = {"attack":true}
	check(await until(func(): return npc.health == 2), "actual incoming contact resolves with no configured bus")
	driver.frame = {}
	check(requested.count(&"enemy_damage") == 1 and committed.count(&"enemy_damage") == 1 and not requested.has(&"hurt"), "inherited requested and committed signals expose one semantic HIT")
	check(count_noise(&"enemy_damage",npc) == 0, "unbound relay does not fall back to global bus")
	await finish()
