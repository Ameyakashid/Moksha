extends SceneTree
## Explicit state fixtures. These are not measured gameplay or completion routes.
var host: Node
var failures: Array[String] = []
var checks := 0
var hz := 60
var scenarios: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition: failures.append(label)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	host._unhandled_key_input(event)
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func run() -> void:
	host=load("res://demo/mission.tscn").instantiate()
	root.add_child(host)
	host.save_enabled=false
	check(host.state=="title" and paused,"title starts paused")
	host.start_new()
	check(host.state=="intro" and paused,"new mission enters skippable intro")
	key(KEY_SPACE)
	check(host.state=="playing" and not paused,"intro skip resumes physics")
	host.input_override={"right":1.0}
	await frames(20)
	check(host.player.position.x>75,"normal input moves the player")
	scenarios.append("title/new mission/intro skip")
	key(KEY_ESCAPE)
	var at: Vector2=host.player.position
	var elapsed: float=host.elapsed
	await frames(30)
	check(host.player.position==at and host.elapsed==elapsed,"pause freezes player and active timer")
	key(KEY_ESCAPE)
	await frames(10)
	check(host.player.position.x>at.x and host.elapsed>elapsed,"resume restores movement and timer")
	scenarios.append("pause and resume")
	# Direct fixture placement is isolated from the route bot and its time totals.
	host.load_sector(2)
	host.player.position=Vector2(430,300)
	host.input_override={}
	host.interact()
	check(host.state=="choice" and paused,"station opens explicit choice")
	key(KEY_K)
	check(host.state=="playing" and not host.blind,"refusing preserves sight")
	host.interact()
	key(KEY_J)
	check(host.blind and host.state=="playing" and not paused,"accepting resumes blind route")
	check(is_equal_approx(host.player.profile.run_speed,host._base_speed*1.25),"blind route has promised 25 percent run speed")
	check(is_equal_approx(host.player.combat_profile.roll_start_speed,host._base_roll[0]*1.25),"blind route has promised 25 percent roll speed")
	scenarios.append("explicit fixture: retain then sacrifice sight")
	host.player.position=host.sectors[2].cache
	host.interact()
	check(host.state=="archive" and paused and host.caches.has(2),"cache opens paused archive and marks collection")
	var archive_elapsed: float=host.elapsed
	await frames(15)
	check(host.elapsed==archive_elapsed,"archive reading is excluded from active time")
	key(KEY_E)
	check(host.state=="playing" and not paused,"E closes archive and resumes")
	scenarios.append("explicit fixture: optional archive reading")
	host.player.receive_attack({"amount":60.0,"rollable":false,"impulse":Vector2.ZERO})
	check(host.health.current_health==0,"fixture damage reaches attached health component")
	check(host.player.is_defeated(),"health depletion reaches attached defeat response")
	check(host.state=="dead" and paused and host.deaths==1,"defeat pauses and counts once")
	host._on_defeat()
	check(host.deaths==1,"repeated defeat callback is idempotent")
	key(KEY_R)
	await frames(3)
	check(host.state=="playing" and not paused and host.sector==2,"death retry reloads same sector and resumes")
	check(host.health.current_health==host.health.capacity,"retry restores full health")
	check(host.blind and host.caches.has(2),"retry preserves sight trade and collected caches")
	check(host.player.position.distance_to(Vector2(75,300))<5,"retry resets player to checkpoint spawn")
	scenarios.append("explicit fixture: defeat and checkpoint retry")
	key(KEY_ESCAPE)
	key(KEY_R)
	await frames(3)
	check(host.state=="playing" and not paused,"retry from pause resumes the room")
	scenarios.append("pause menu retry")
	host.load_sector(host.sectors.size()-1)
	host.player.position=Vector2(655,300)
	host.interact()
	check(host.state=="complete" and paused,"ending interaction shows completion and pauses")
	key(KEY_ENTER)
	check(host.state=="title" and paused,"completion returns to title")
	host.start_new(true)
	check(host.state=="playing" and not paused and not host.blind and host.sector==0,"fresh replay resets sight and sector")
	check(host.deaths==0 and host.kills==0 and host.metrics.is_empty() and host.caches.is_empty(),"fresh replay resets run counters")
	scenarios.append("explicit fixture: ending, title, fresh replay")
	# Save fixtures use only the test process's isolated temporary user directory.
	check(OS.get_user_data_dir().begins_with("/tmp/"),"save fixture uses temporary user directory")
	if OS.get_user_data_dir().begins_with("/tmp/"):
		host.load_sector(2)
		host.blind=true
		host._apply_trade()
		host.caches.append(1)
		host.kills=9
		host.deaths=2
		host.elapsed=42.5
		host.metrics.append({"sector":0,"seconds":20.0,"blind":false,"health":48.0})
		host.metrics.append({"sector":1,"seconds":22.5,"blind":false,"health":36.0})
		host.save_enabled=true
		host._save_checkpoint()
		check(host._valid_save(),"stable-ID schema-4 checkpoint validates")
		host.show_title()
		check(host.continue_available,"title exposes saved checkpoint")
		host.blind=false
		host.caches.clear()
		host.kills=0
		host.deaths=0
		host.elapsed=0
		host.metrics.clear()
		host.continue_run()
		check(host.sector==2 and host.blind and host.state=="playing", "continue restores sector and sight")
		check(host.kills==9 and host.deaths==2 and is_equal_approx(host.elapsed,42.5), "continue restores run statistics")
		check(host.caches.has(1) and host.metrics.size()==2 and host.metrics[0].seconds==20.0,"continue restores cache and prior sector metrics")
		check(host.health.current_health==host.health.capacity,"continue starts checkpoint at full health")
		host.save_enabled=false
		scenarios.append("explicit temporary-save fixture: stable-ID schema-4 persistence and continue")

	var report={"suite":"mission lifecycle fixtures","hz":hz,"checks":checks,"failures":failures,"scenarios":scenarios,"method":"Separate direct state/position fixtures for lifecycle wiring. Not claimed as input-driven route completion or included in playtime evidence."}
	FileAccess.open("res://demo/evidence/mission_route_lifecycle_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("MISSION LIFECYCLE ",hz," Hz: ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
