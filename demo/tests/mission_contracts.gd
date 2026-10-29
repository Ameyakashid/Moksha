extends SceneTree
const CampaignIdentity=preload("res://demo/tests/campaign_identity.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host = load("res://demo/mission.tscn").instantiate()
	root.add_child(host)
	host.save_enabled = false
	check(host.state=="title" and paused,"begins at a paused title")
	host.start_new(true)
	check(CampaignIdentity.ordered(host.sectors) and host.sector==0,"new mission starts sector zero of exact nine ordered identities")
	check(host.health.current_health==60,"player composed with live health")
	check(host.player.get_node("Visual").get_script().resource_path.ends_with("lithe_wireframe.gd"),"optional lithe view integrated")
	for i in range(host.sectors.size()):
		host.load_sector(i)
		await physics_frame
		await physics_frame
		check(is_instance_valid(host.player) and host.player.position.is_finite(),"sector %d instantiated live actor"%i)
		check(host.enemies.size()==host.sectors[i].enemies.size(),"sector %d enemy composition count"%i)
		check(host.sonar.geometry.size()>0,"sector %d has sound contour geometry"%i)
		for enemy in host.enemies:
			var receiver = enemy.get_node("BodyShape/IncomingStrikeReceiver") if enemy.kind in ["sentinel", "listener", "sentry", "warden"] else enemy.get_node("Hurtbox")
			check(enemy.collision_layer==32 and receiver.collision_layer==4,"distinct body/contact layers")
			if enemy.kind in ["sentinel", "listener", "warden"]: check(enemy.get_node_or_null("IntentDriver") != null and enemy.get_node("ContactAdapter").target_mask == 72,"production melee actor uses shared scheduler and explicit opponent mask")
			if enemy.kind == "sentry": check(enemy.get_node_or_null("IntentDriver") != null and not enemy.get_node("ContactAdapter").enabled and enemy.get_node("ProjectileEmitter").profile.outbound_mask == 43,"production sentry uses shared scheduler, carrier and explicit physical mask")
			check(enemy._player==host.player,"enemy bound to current v26 actor")
		if host.sectors[i].get("lock",false): check(not host.room.gate_open,"combat seal initially closed")
		if host.sectors[i].has("relay"): check(not host.room.gate_open,"relay seal initially closed")
	host.load_sector(2)
	host.player.reset_actor(host.sectors[2].station,1)
	host.interact()
	check(host.state=="choice" and paused,"station opens paused choice")
	host.choose_sight(false)
	check(not host.blind and host.state=="playing" and not paused,"choice refusal resumes sighted route")
	host.interact()
	host.choose_sight(true)
	check(host.blind and host.sonar.blind,"trade activates actual blackout renderer")
	check(is_equal_approx(host.player.profile.run_speed,272.5),"trade +25 percent movement resource copy")
	check(host.sonar.pulses.size()>0,"trade emits real-position tutorial noise after blackout")
	var frozen: Vector2 = host.player.position
	paused = true
	host.state="paused"
	for j in range(10): await physics_frame
	check(host.player.position==frozen,"pause freezes actor")
	host.state="playing"
	paused = false
	host.load_sector(3)
	check(host.blind and is_equal_approx(host.player.profile.run_speed,272.5),"trade persists transition without stacking")
	check(host.sonar.event_history.is_empty(),"transition clears old acoustic history")
	host.tap_weapon()
	check(host.sonar.event_history.size()==1,"one explicit tap yields one event")
	host.tap_weapon()
	check(host.sonar.event_history.size()==1,"tap cooldown prevents repeat spam")
	var origin: Vector2=host.sonar.event_history[0].origin
	check(origin.is_equal_approx(host.player.global_position+Vector2(host.player.facing*12,-17)),"tap origin at actual body hand")
	host._on_defeat()
	check(host.state=="dead" and paused,"defeat enters retry menu")
	host.load_sector(3)
	check(host.state=="playing" and host.health.current_health==60 and not host.player.is_defeated(),"retry releases defeat and heals")
	check(host.blind,"retry preserves sense choice")
	host.load_sector(0)
	host.player.reset_actor(host.sectors[0].relay,1)
	host.interact()
	check(host.relay_on and host.room.gate_open,"relay interaction opens actual objective seal")
	host.player.reset_actor(host.sectors[0].cache,1)
	host.interact()
	check(host.caches.has(0),"nearby cache collected")
	host.interact()
	check(host.caches.count(0)==1,"cache collection idempotent")
	host.load_sector(host.sectors.size()-1)
	host.player.reset_actor(Vector2(655,300),1)
	host.interact()
	check(host.state=="complete" and paused,"final lift produces explicit ending")
	host.show_title()
	check(host.state=="title","ending returns to title")
	host.start_new(true)
	check(not host.blind and host.caches.is_empty() and host.sector==0,"new run resets mission state")
	paused=false
	host.queue_free()
	await process_frame
	var report={"checks":checks,"failures":failures,"scope":"Direct-state integration fixtures, not a timed gameplay playthrough"}
	var f=FileAccess.open("res://demo/evidence/mission_contracts.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	print("MISSION CONTRACTS ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
