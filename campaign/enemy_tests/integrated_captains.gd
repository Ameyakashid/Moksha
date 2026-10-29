extends SceneTree
## Real campaign factory, authored placement and production player contact.
## Player setup beside encounter + other guards disabled are focused fixtures,
## not a claim of a traversed route. No damage/health writes resolve engagement.
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var encounters: Array[Dictionary] = []
var host: Node
var context := "factory"
var hz := 120
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"context":context,"label":label,"passed":ok})
	if not ok: failures.append(context + ": " + label)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func run() -> void:
	host = load("res://campaign/campaign.tscn").instantiate()
	root.add_child(host); host.save_enabled = false; host.start_new(true); host.input_override = {}
	await frames(3)
	var expected := {"quarantine_intake":"captain_lancer", "l2_union_dispatch":"captain_keeper", "l3_drainage_commons":"captain_lancer", "works_dispatch_refusal":"captain_keeper"}
	for blind in [false,true]:
		for id in expected:
			context = id + " blind=" + str(blind)
			var index := -1
			for i in host.sectors.size():
				if host.sectors[i].id == id: index = i
			check(index >= 0, "authored captain district exists")
			if index < 0: continue
			host.blind = blind; host.load_sector(index); host.input_override = {}
			for enemy in host.enemies: enemy.ai_enabled = false
			await frames(5)
			check(host.player.get_node("BodyShape/IncomingStrikeReceiver")._health() == host.health, "incoming melee receiver binds current campaign Health")
			check(host.player.get_node("ProjectileReceiver")._health() == host.health, "projectile receiver binds current campaign Health")
			check(host.player.get_node("PhysicalImpactReceiver")._health() == host.health, "cargo impact receiver binds current campaign Health")
			check(host.player.get_node("BoundaryReceiver").get_health() == host.health, "boundary receiver binds current campaign Health")
			var captains: Array = host.enemies.filter(func(e): return str(e.kind).begins_with("captain_"))
			check(captains.size() == 1, "factory registers exactly one authored captain")
			if captains.size() != 1: continue
			var captain: Node2D = captains[0]
			var data: Dictionary = host.sectors[index]
			check(captain.kind == expected[id] and captain.get_node("SentinelPolicy").pattern == str(expected[id]).trim_prefix("captain_"), "scene and policy mapping match authored variant")
			check(captain.scene_file_path == "res://campaign/enemies/" + str(expected[id]).trim_prefix("captain_") + ".tscn", "actual scene is campaign composition, not fallback legacy enemy")
			check(captain._player == host.player and captain._bus == host.bus and captain.is_in_group("enemies") and captain.is_in_group("actors"), "host target, sound bus and sensory groups wired")
			check(captain.grounded and absf(captain.position.y - data.captains[0].at.y) < 2, "authored spawn has actual terrain support")
			check(captain.position.x > captain.room_left and captain.position.x < captain.room_right and captain.room_left >= 40 and captain.room_right <= data.width-50, "local patrol bounds remain within district")
			# Labeled gate-isolation setup, not route completion: satisfy all
			# noncombat requirements before the actual captain fight.
			for goal in host.goals: goal.completed = true
			host.relay_on = true
			host._update_gate()
			check(not data.has("freight") and not data.get("lock",false), "gate fixture has no unfulfilled freight or all-guards condition")
			check(not host.room.gate_open and data.get("captain_required",false), "captain alone keeps seal closed after other objective conditions are fixture-satisfied")
			# Focused encounter placement only. All subsequent approach and hits
			# are ordinary frames through the real mission player scheduler.
			host.player.reset_actor(captain.position - Vector2(32,0),1)
			await frames(5)
			var initial_health: float = captain.health
			var kills: int = host.kills
			var remaining: int = host.remaining_enemies()
			var attacked := false
			for tick in hz * 14:
				if captain.dead: break
				var dx: float = captain.position.x - host.player.position.x
				var frame := {}
				if absf(dx) > 29: frame["right" if dx > 0 else "left"] = 1.0
				if tick % maxi(1,int(hz*0.34)) == 0 and absf(dx) < 45:
					frame["attack"] = true
				host.input_override = frame
				await frames(1)
				if captain.health < initial_health: attacked = true
			host.input_override = {}
			check(attacked, "production player J contact damages actual placed captain")
			check(captain.dead, "ordinary player contact completes captain encounter")
			check(host.kills == kills+1 and host.remaining_enemies() == remaining-1, "one physical defeat increments host kills and decrements remaining once")
			check(host.room.gate_open and host.remaining_enemies() > 0, "actual captain defeat opens isolated seal with ordinary guards alive")
			check(host.sonar.event_history.any(func(e): return e.source_id == captain.get_instance_id() and e.kind == &"enemy_damage"), "actual captain HIT reaches mission sonar in this sight mode")
			await frames(3)
			check(captain.collision_layer == 0 and captain.get_node("BodyShape").disabled, "defeated captain retires physical threat marker")
			encounters.append({"district":id,"blind":blind,"kind":captain.kind,"dead":captain.dead,"initial_health":initial_health,"kills_delta":host.kills-kills,"position":str(captain.position)})
			host.load_sector(index); host.input_override = {}
			for enemy in host.enemies: enemy.ai_enabled = false
			await frames(3)
			var retried: Array = host.enemies.filter(func(e): return str(e.kind).begins_with("captain_"))
			check(retried.size()==1 and not retried[0].dead and retried[0].health==initial_health and not host.room.gate_open, "real district reload restores captain and seal")
			if retried.size() == 1:
				var live: Node2D = retried[0]
				host.player.reset_actor(live.position - Vector2(36,0),1)
				host.input_override = {}
				await frames(3) # Stock reset requires release before fresh held input.
				host.input_override = {"shield":true}
				await frames(ceili(hz*0.25))
				check(host.player.shield_phase == &"hold", "fresh post-reset shield input reaches real held guard")
				live.ai_enabled = true
				for tick in hz*4:
					await frames(1)
					if not live.last_attack_result.is_empty(): break
				live.ai_enabled = false
				check(live.last_attack_result.get("outcome") == &"guarded", "authored terrain permits autonomous captain attack against real player guard")
				check(host.health.current_health == 57.0 and live.last_attack_result.get("amount") == 3.0, "real incoming guarded receipt debits replacement Health by three")
				check(host.sonar.event_history.any(func(e): return e.source_id == live.get_instance_id() and e.kind == &"enemy_windup"), "autonomous warning reaches integrated sonar")
				host.input_override = {}
	for blind in [false,true]:
		context = "integrated sentry projectile blind=" + str(blind)
		var index := 0
		for i in host.sectors.size():
			if host.sectors[i].id == "quarantine_intake": index = i
		host.blind = blind; host.load_sector(index); host.input_override = {}
		for enemy in host.enemies: enemy.ai_enabled = false
		await frames(4)
		var sentries: Array = host.enemies.filter(func(e): return e.kind == "sentry" and absf(e.position.x-870)<5)
		check(sentries.size()==1, "authored ranged sentry exists")
		if sentries.size()==1:
			var sentry: Node2D = sentries[0]
			host.player.reset_actor(sentry.position-Vector2(70,0),1); await frames(4)
			sentry.ai_enabled = true
			for tick in hz*4:
				await frames(1)
				if host.health.current_health < 60: break
			sentry.ai_enabled = false
			var receiver: Node = host.player.get_node("ProjectileReceiver")
			check(receiver.accepted_count > 0 and receiver.last_receipt.get("outcome") == &"hurt", "real authored sentry projectile produces accepted player receipt")
			check(host.health.current_health == 48.0, "real projectile debits replacement campaign Health by twelve")
	var report := {"hz":hz,"checks":checks,"failures":failures,"encounters":encounters,"scope":"Focused real campaign encounter fixtures; actual J contacts, not complete route or visual validation"}
	FileAccess.open("res://campaign/enemy_tests/integrated_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("INTEGRATED CAPTAINS %d Hz: %d encounters, %d checks, %d failures" % [hz,encounters.size(),checks.size(),failures.size()])
	for failure in failures: printerr(failure)
	host.queue_free(); await frames(2)
	quit(0 if failures.is_empty() else 1)
