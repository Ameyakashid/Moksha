extends SceneTree
## Black-box-input full route probe. Bot reads layout/AI to plan, but measured
## play sends only PC raw button frames and proximity-limited host interactions.
## It never changes player positions, enemy health, damage, AI, or collision.
var host: Node
var hz := 60
var sacrifice := false
var frame := 0
var sector_seen := -1
var waypoints: Array = []
var waypoint_index := 0
var jump_age := -1.0
var jump_released := false
var attack_clock := 0.0
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []
var failures: Array[String] = []
var retries := 0
var sector_start := 0
var last_x := 0.0
var stagnant := 0.0
var choice_done := false
var pause_done := false
var samples := {}
var report_path := ""
var source_hashes := {}
var inputs_count := {"attack":0,"jump":0,"shield":0,"roll":0,"tap":0}
var roll_exercised := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg == "--sacrifice": sacrifice = true
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	host._unhandled_key_input(event)

func run() -> void:
	for path in ["res://demo/mission.gd","res://demo/mission_data.gd","res://demo/components/enemy.gd","res://combat_pc/player.gd","res://demo/tests/mission_route_bot.gd"]:
		source_hashes[path]=FileAccess.get_sha256(path)
	host = load("res://demo/mission.tscn").instantiate()
	root.add_child(host)
	host.save_enabled = false
	host.start_new(true)
	for tick in range(hz*1500):
		frame = tick
		if host.state == "complete": break
		if host.state == "dead":
			events.append({"event":"death", "sector":host.sector+1, "frame":frame,"position":str(host.player.position)})
			retries += 1
			if retries >= 12:
				failures.append("Twelve input-driven deaths; route aborted")
				break
			key(KEY_R)
			sector_seen = -1
			host.input_override = {}
		elif host.state == "choice":
			host.choose_sight(sacrifice)
			choice_done = true
			events.append({"event":"sight_choice", "sacrificed":sacrifice, "position":str(host.player.position)})
		else:
			if host.sector != sector_seen: begin_sector()
			if tick == hz*2 and not pause_done:
				var before: Vector2 = host.player.position
				var elapsed_before: float = host.elapsed
				key(KEY_ESCAPE)
				for _i in hz/2: await physics_frame
				if host.state != "paused" or host.player.position != before or host.elapsed != elapsed_before:
					failures.append("Pause did not freeze player and active timer")
				key(KEY_ESCAPE)
				pause_done = true
				events.append({"event":"pause_resume", "passed":host.state=="playing"})
			host.input_override = decide()
			for button in ["attack","jump","shield","roll"]:
				if host.input_override.get(button,false): inputs_count[button]+=1
			if frame % (hz/2) == 0:
				trace.append(snapshot())
				if trace.size() > 200: trace.pop_front()
			if frame % (hz*10) == 0: print("ROUTE ", snapshot())
			if frame-sector_start > hz*100:
				failures.append("Sector %d exceeded 100 simulated seconds at %s" % [host.sector+1,host.player.position])
				break
		await physics_frame
		await process_frame
	if host.state != "complete": failures.append("Full route did not reach ending")
	if not choice_done: failures.append("Sight choice interaction not exercised")
	if host.metrics.size()!=12: failures.append("Expected 12 sector completion metrics, got %d" % host.metrics.size())
	var report := {"suite":"input-driven mission route", "hz":hz, "sacrificed_sight":sacrifice, "completed":host.state=="complete", "simulated_active_seconds":host.elapsed, "human_duration_validated":false, "deaths":host.deaths, "retry_count":retries,"kills":host.kills,"caches":host.caches.size(), "sectors":host.metrics, "events":events,"source_hashes":source_hashes,"input_held_frames":inputs_count,"failures":failures,"last_trace":trace,"method":"Actual production physics driven by raw player button dictionaries and proximity interactions; layout/AI-aware deterministic bot; no measured gameplay teleports, health writes, forced kills, gate writes, or AI disabling. Timing is simulated active time, not a human playthrough."}
	report_path = "res://demo/evidence/mission_route_%dhz_%s.json" % [hz,"sacrificed" if sacrifice else "retained"]
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("MISSION ROUTE RESULT ",report_path," complete=",report.completed," active_seconds=",report.simulated_active_seconds," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func begin_sector() -> void:
	sector_seen = host.sector
	sector_start = frame
	waypoint_index = 0
	jump_age = -1
	jump_released = false
	stagnant = 0
	last_x = host.player.position.x
	waypoints = []
	match host.sector:
		1: waypoints = [Vector2(330,247),Vector2(515,192),Vector2(740,142)]
		3: waypoints = [Vector2(430,300)]
		5: waypoints = [Vector2(360,245),Vector2(470,300),Vector2(800,235),Vector2(970,300),Vector2(1270,240),Vector2(1430,185)]
		7: waypoints = [Vector2(360,245),Vector2(555,190),Vector2(820,140)]
		9: waypoints = [Vector2(365,245),Vector2(530,300),Vector2(880,235),Vector2(1100,300),Vector2(1450,240)]
	events.append({"event":"sector_enter", "sector":host.sector+1, "active_seconds":host.elapsed,"health":host.health.current_health,"enemy_tuning":host.enemies.map(func(enemy): return {"kind":enemy.kind,"health":enemy.health,"damage":enemy._damage})})
	print("ENTER SECTOR ",host.sector+1," blind=",host.blind)

func snapshot() -> Dictionary:
	var p = host.player
	var alive := []
	for enemy in host.enemies:
		if is_instance_valid(enemy) and not enemy.dead: alive.append({"position":str(enemy.position),"health":enemy.health,"state":enemy.ai_state})
	return {"frame":frame,"sector":host.sector+1,"position":str(p.position),"velocity":str(p.velocity),"grounded":p.grounded,"action":p.main_action,"weapon":p.weapon_phase,"health":host.health.current_health,"waypoint":waypoint_index,"enemies":alive}

func decide() -> Dictionary:
	var p = host.player
	var pos: Vector2 = p.position
	var dt := 1.0/hz
	var d: Dictionary = host.sectors[host.sector]
	var raw := {}
	attack_clock += dt
	if absf(pos.x-last_x)<0.3: stagnant += dt
	else: stagnant = 0
	last_x = pos.x
	if frame % maxi(1,hz/3)==0:
		host.tap_weapon()
		inputs_count.tap+=1
	if host.sector==0 and frame<hz/2: return {"shield":true}
	if host.sector==11 and not roll_exercised and p.grounded and pos.x>120:
		roll_exercised=true
		return {"right":1.0,"roll":true}
	# Exercise actual host interaction only where its own proximity predicate holds.
	if d.has("station") and not choice_done and host._near(d.station):
		host.interact()
		return {}
	if d.has("relay") and not host.relay_on and host._near(d.relay): host.interact()
	if d.has("cache") and not host.caches.has(host.sector) and host._near(d.cache): host.interact()
	if host._near(Vector2(float(d.width)-45,300),65) and host.room.gate_open:
		host.interact()
		return {}
	while waypoint_index < waypoints.size():
		var wp: Vector2 = waypoints[waypoint_index]
		var landed_waypoint: bool = wp.y < 299 or (p.grounded and pos.y > 295)
		if landed_waypoint and (pos.distance_to(wp)<38 or (pos.x>wp.x+25 and absf(pos.y-wp.y)<40)): waypoint_index+=1
		else: break
	var target := Vector2(float(d.width)-45,300)
	if waypoint_index < waypoints.size(): target = waypoints[waypoint_index]
	elif d.has("relay") and not host.relay_on: target = d.relay
	var enemy_target: Node2D = null
	var nearest := INF
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var distance: float = pos.distance_to(enemy.position)
		if distance<nearest and (distance<140 or (d.get("lock",false) and waypoint_index>=waypoints.size())):
			nearest=distance
			enemy_target=enemy
	var direction := signf(target.x-pos.x)
	var in_combat := false
	if enemy_target != null:
		if absf(pos.y-enemy_target.position.y)<40:
			in_combat = absf(pos.x-enemy_target.position.x)<90 and enemy_target._terrain_visible(pos+Vector2(0,-20))
			target = enemy_target.position
			direction = signf(target.x-pos.x)
			if absf(target.x-pos.x)<32: direction = 0
			# Face opponent using a short directional input, then block telegraphed strike.
			if p.facing != int(signf(target.x-pos.x)): direction = signf(target.x-pos.x)
			var danger: bool = absf(target.x-pos.x)<70 and (enemy_target.ai_state==&"active" or (enemy_target.ai_state==&"windup" and enemy_target._phase_elapsed>enemy_target._windup-0.16))
			if danger: raw.shield = true
			elif absf(target.x-pos.x)<54 and attack_clock>0.15:
				raw.attack = true
				attack_clock = 0
		elif d.get("lock",false):
			target = enemy_target.position
			if target.y>pos.y+35 and absf(target.x-pos.x)<40: target.x+=60
			direction = signf(target.x-pos.x)
	if absf(target.x-pos.x)<10 and not in_combat: direction=0
	if direction>0: raw.right=1.0
	elif direction<0: raw.left=1.0
	var jump_needed := false
	if p.grounded:
		jump_age = -1
		jump_released = false
		# Raise onto solid blocks / selected elevated waypoint.
		for rect in d.platforms:
			if rect.size.y<=18: continue
			var edge: float = rect.position.x if direction>0 else rect.end.x
			if direction!=0 and (edge-pos.x)*direction>=-8 and (edge-pos.x)*direction<54 and pos.y>rect.position.y+8: jump_needed=true
		for gap in d.get("gaps",[]):
			var edge: float = gap.x if direction>0 else gap.y
			if direction!=0 and (edge-pos.x)*direction>=-5 and (edge-pos.x)*direction<50: jump_needed=true
		if target.y < pos.y-32 and absf(target.x-pos.x)<170: jump_needed=true
		if stagnant>0.35 and direction!=0 and not in_combat: jump_needed=true
		if jump_needed and not in_combat:
			jump_age=0
			raw.jump=true
	elif jump_age>=0:
		jump_age+=dt
		# Full jump, one neutral frame, then a fresh air jump at the apex.
		if jump_age<0.29: raw.jump=true
		elif not jump_released: jump_released=true
		elif jump_age<0.62: raw.jump=true
	# Emergency fall recovery uses normal remaining air jump.
	elif pos.y>315 and p.air_jumps_left>0:
		raw.jump=true
		jump_age=0.3
		jump_released=true
	return raw
