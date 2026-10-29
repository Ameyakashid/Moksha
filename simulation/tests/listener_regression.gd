extends "res://simulation/tests/sentinel_regression.gd"
## The identical real-contact/lifecycle suite runs with listener configuration.
## Extra cases below isolate authored senses, resource isolation and factory use.
const LISTENER_PROFILE = preload("res://demo/resources/listener_archetype.tres")
const HEARING_PROFILE = preload("res://simulation/resources/hearing_profile.gd")
const CONTACT_PROP = preload("res://combat_pc/fixtures/contact_noise_prop.tscn")
func _initialize() -> void:
	report_prefix = "listener"
	super._initialize()
func new_npc() -> Node2D:
	var actor := super.new_npc()
	actor.kind = "listener"
	actor.archetype_profile = LISTENER_PROFILE
	return actor
func check_authored_tuning() -> void:
	check(npc.health == 3 and npc._damage == 12 and npc._windup == 0.46 and npc.melee_chain.steps[0].recovery_seconds == 0.68 and npc.profile.run_speed == 112 and npc.profile.standing_height == 36, "listener tuning with explicit health3 and mission damage12 overrides")
func additional_scenarios() -> void:
	await _configuration()
	await _vision_and_priorities()
	await _hearing_geometry()
	await _physical_noise()
	await _physical_peer_and_fall()
	await _listener_factory()
func _configuration() -> void:
	await begin("listener defaults, private profiles and explicit override precedence", 0)
	check(npc.health == 2 and npc.get_node("Health").capacity == 2, "unoverridden listener capacity is2")
	check(npc.archetype_profile.sight_range_exclusive == 86 and npc.archetype_profile.hearing_memory_seconds == 3.2, "authored listener sight and memory")
	check(npc.archetype_profile.tint.is_equal_approx(Color("c6b5e9")) and npc.archetype_profile.ear_marker, "lavender and ear view configuration")
	check(npc.hearing_range == 340 and npc.hearing_profile.ear_offset == Vector2.ZERO and not npc.hearing_profile.terrain_attenuation_enabled, "production hearing defaults remain legacy foot-origin radius without attenuation")
	var second := new_npc(); second.ai_enabled = false; second.position = Vector2(350,200); world.add_child(second)
	var sentinel = SENTINEL.instantiate(); sentinel.ai_enabled = false; sentinel.position = Vector2(500,200); world.add_child(sentinel)
	var overridden := new_npc(); overridden.ai_enabled = false; overridden.position = Vector2(650,200)
	overridden.max_health = 9; overridden.movement_speed = 123; overridden.windup_override = 0.31; overridden.attack_damage_override = 7
	world.add_child(overridden); await frames(3)
	check(overridden.health == 9 and overridden.profile.run_speed == 123 and overridden._windup == 0.31 and overridden._damage == 7 and overridden.melee_chain.steps[0].recovery_seconds == 0.68, "existing explicit overrides win over archetype defaults")
	check(sentinel.health == 3 and sentinel.profile.run_speed == 82 and sentinel._windup == 0.56 and sentinel.archetype_profile.hearing_memory_seconds == 1.8 and not sentinel.archetype_profile.ear_marker, "same scene retains original sentinel defaults")
	check(npc.archetype_profile != second.archetype_profile and npc.archetype_profile != LISTENER_PROFILE and npc.profile != second.profile and npc.melee_chain != second.melee_chain and npc.hearing_profile != second.hearing_profile, "all mutable actor and authored profiles are private")
	npc.archetype_profile.hearing_memory_seconds = 9; npc.archetype_profile.tint = Color.RED
	npc.profile.run_speed = 1; npc.melee_chain.steps[0].windup_seconds = 2; npc.hearing_profile.range_at_unit_loudness = 1
	check(second.archetype_profile.hearing_memory_seconds == 3.2 and LISTENER_PROFILE.hearing_memory_seconds == 3.2 and second.profile.run_speed == 112 and second._windup == 0.46 and second.hearing_profile.range_at_unit_loudness == 340, "one actor edit cannot change sibling or resource defaults")
	await finish()
func _vision_and_priorities() -> void:
	for distance in [85.9,86.0,86.1]:
		await begin("actual listener sight boundary %.1f" % distance,0,100+distance,100)
		npc.ai_enabled = true
		await frames(1)
		check((npc.ai_state == &"chase") == (distance < 86), "actual target body obeys strict86 cap")
		await finish()
	await begin("listener lower detection range remains additional limit",0,170,100)
	npc.detection_range = 60; attack(); await frames(1)
	check(npc.ai_state == &"patrol", "configured detection60 is not replaced by listener cap86")
	await finish()
	await begin("listener real wall blocks sight then remembered sound chooses direction",0,170,100)
	var wall := surface(Vector2(135,165),Vector2(8,70)); await frames(3)
	# Explicit bus boundary supplies memory. Actual sight remains a terrain ray.
	root.get_node("NoiseBus").emit_noise(Vector2(30,200),&"boundary_fixture",1.0,pc)
	attack(); await frames(1)
	check(not npc._terrain_visible(pc.position+Vector2(0,-20)) and npc.ai_state == &"investigate" and npc.get_node("IntentDriver").last_frame.left > 0, "occluded visible-range target cannot override admitted sound")
	wall.queue_free(); await frames(3)
	check(npc._terrain_visible(pc.position+Vector2(0,-20)) and npc.ai_state == &"chase" and npc.get_node("IntentDriver").last_frame.right > 0, "clear real sight takes priority over opposing remembered sound")
	await finish()
	await begin("listener retained noise lasts3.2 and expires through ordinary clock",0,650,300)
	npc.configure(null,root.get_node("NoiseBus"))
	root.get_node("NoiseBus").emit_noise(npc.position,&"boundary_fixture",1.0,pc)
	check(is_equal_approx(npc._noise_memory,3.2), "accepted event installs authored3.2 seconds")
	attack(); await frames(ceili(hz*2.0))
	check(npc.ai_state == &"investigate" and npc._noise_memory > 1.1 and npc._noise_memory < 1.3, "memory remains beyond sentinel1.8 without new event")
	await frames(ceili(hz*1.3))
	check(npc.ai_state == &"patrol" and npc._noise_memory == 0, "listener memory naturally expires to patrol")
	await finish()
func _hearing_geometry() -> void:
	await begin("listener actual sensor range and configurable real-wall attenuation",0,650,200)
	npc.configure(null,root.get_node("NoiseBus"))
	var sensor := npc.get_node("HearingSensor")
	var policy := npc.get_node("SentinelPolicy")
	var before: int = sensor.heard_count
	root.get_node("NoiseBus").emit_noise(npc.position+Vector2(340,0),&"boundary_fixture",1.0,pc)
	check(sensor.heard_count == before+1 and policy.noise_memory == 3.2 and is_equal_approx(sensor.last_receipt.distance,340), "real sensor admits inclusive actual340 boundary")
	policy.noise_memory = 0
	root.get_node("NoiseBus").emit_noise(npc.position+Vector2(340.1,0),&"boundary_fixture",1.0,pc)
	check(sensor.heard_count == before+1 and policy.noise_memory == 0, "real sensor rejects origin beyond range")
	npc.hearing_profile.ear_offset = Vector2(0,-20)
	npc.hearing_profile.terrain_attenuation_enabled = true
	npc.hearing_profile.blocked_range_multiplier = 0.25
	var wall := surface(Vector2(250,160),Vector2(10,80)); await frames(3)
	root.get_node("NoiseBus").emit_noise(Vector2(300,180),&"boundary_fixture",1.0,pc)
	check(sensor.heard_count == before+1 and policy.noise_memory == 0, "actual wall reduces optional radius to85 and rejects100 distance")
	root.get_node("NoiseBus").emit_noise(Vector2(280,180),&"boundary_fixture",1.0,pc)
	check(sensor.heard_count == before+2 and sensor.last_receipt.terrain_blocked and is_equal_approx(sensor.last_receipt.audible_radius,85), "optional occluded80 event remains audible with real blocked receipt")
	policy.noise_memory = 0; wall.queue_free(); await frames(3)
	root.get_node("NoiseBus").emit_noise(Vector2(300,180),&"boundary_fixture",1.0,pc)
	check(sensor.heard_count == before+3 and not sensor.last_receipt.terrain_blocked and policy.noise_memory == 3.2, "removing physical blocker restores unattenuated hearing")
	await finish()
func _physical_noise() -> void:
	await begin("actual falling crate contact causes listener investigation",0,650,300)
	npc.configure(null,root.get_node("NoiseBus")); npc.hearing_profile.terrain_attenuation_enabled = true; npc.hearing_profile.ear_offset = Vector2(0,-20)
	var prop = CONTACT_PROP.instantiate(); prop.position = Vector2(200,90); world.add_child(prop)
	prop.get_node("ImpactNoise").bind_body(prop,root.get_node("NoiseBus"))
	attack()
	check(await until(func(): return prop.get_node("ImpactNoise").emitted_count > 0), "gravity and real floor collision emit contact sound")
	var heard: Dictionary = npc.get_node("HearingSensor").last_receipt
	check(not heard.is_empty() and heard.source_id == prop.get_instance_id() and heard.origin.is_finite(), "listener receives genuine physical source and unchanged contact origin")
	var at_contact: float = npc.position.x
	await frames(ceili(hz*0.35))
	check(npc.ai_state == &"investigate" and npc._noise_memory > 0 and npc.position.x < at_contact-10, "physical sound observation leads to ordinary leftward motion")
	await finish()
func _physical_peer_and_fall() -> void:
	await begin("listener strike cannot newly damage an overlapping melee peer",8,100,136)
	var peer = SENTINEL.instantiate(); peer.ai_enabled = false; peer.position = Vector2(112,200); world.add_child(peer); await frames(3)
	attack(); check(await until(func(): return not receipts.is_empty()), "ordinary listener attack produces genuine PC contact beside peer")
	npc.ai_enabled = false
	check(peer.health == 3 and peer.get_node("BodyShape/IncomingStrikeReceiver").collision_layer == 4 and npc.get_node("ContactAdapter").target_mask == 72, "actual same-sweep peer receives no friendly-fire damage")
	await finish()
	await begin("real PC contact can knock listener beyond unsupported edge",8,140,176,200)
	npc.configure(null,root.get_node("NoiseBus")); npc.patrol_radius = 500; attack()
	driver.frame = {"attack":true}; await frames(1); driver.frame = {}
	check(await until(func(): return npc.health < 8), "raw PC strike genuinely debits listener before edge")
	check(await until(func(): return npc.position.x > 208 and npc.position.y > 212), "controller recoil carries listener off real support despite AI edge preference")
	check(not npc.grounded and npc.health == 7, "gravity determines fall and single strike retains bounded Health")
	await finish()
func _listener_factory() -> void:
	scenarios.append("actual mission factory composes every listener with private shared profile")
	var host = preload("res://demo/mission.tscn").instantiate(); root.add_child(host); host.save_enabled = false; host.start_new(true); host.input_override = {}
	var count := 0
	for sector in host.sectors.size():
		host.load_sector(sector)
		for actor in host.enemies: actor.ai_enabled = false
		await frames(3)
		for actor in host.enemies:
			if actor.kind != "listener": continue
			count += 1
			check(actor.get_script().resource_path == "res://demo/components/shared_sentinel.gd" and actor.get_node("IntentDriver").tick_count > 0 and actor.get_node_or_null("StrikeHealth") == null, "real factory listener has one shared scheduler and one Health")
			check(actor.health == 2 and actor.profile.run_speed == 112 and actor._windup == 0.46 and actor._damage == 12 and actor.archetype_profile != LISTENER_PROFILE, "real factory listener configuration and mission overrides")
	check(count == 13, "all thirteen authored listener placements use shared production scene")
	host.load_sector(0)
	for actor in host.enemies: actor.ai_enabled = false
	await frames(3)
	var listener: Node2D
	for actor in host.enemies:
		if actor.kind == "listener": listener = actor
	check(is_instance_valid(listener), "initial room exposes real production listener")
	var spawn: Vector2 = listener.position
	host.player.reset_actor(spawn-Vector2(36,0),1); await frames(4)
	host.input_override = {"attack":true}; await frames(1); host.input_override = {}
	check(await until(func(): return listener.health == 1), "real mission PC sword contacts real factory listener")
	check(host.sonar.event_history.any(func(e): return e.source_id == listener.get_instance_id() and e.kind == &"enemy_damage"), "real listener Health receipt reaches mission HIT sonar")
	var kills_before: int = host.kills
	# Labelled lifecycle/accounting boundary after independently proven contact.
	listener.take_hit(99,1,true); await frames(3)
	check(listener.dead and host.kills == kills_before+1 and host.sonar.event_history.any(func(e): return e.source_id == listener.get_instance_id() and e.kind == &"enemy_death"), "one listener defeat reaches actual mission kill and DOWN pipeline")
	host.load_sector(0); await frames(3)
	check(host.enemies.any(func(e): return e.kind == "listener" and not e.dead and e.health == 2), "room reload restores listener configured life")
	host.queue_free(); paused = false; await frames(2)
