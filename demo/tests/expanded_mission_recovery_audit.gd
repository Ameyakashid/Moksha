extends "res://demo/tests/expanded_mission_route_bot.gd"
## Separate recovery fixtures. Starting position/sight are placed before measured
## input. Each fixture then uses normal PC movement/combat with every shutter closed.
var fixture_target: Vector2
var fixture_rows: Array=[]

func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
		if arg=="--sacrifice": sacrifice=true
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func run()->void:
	input_dispatch=InputDispatch.new()
	input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS
	root.add_child(input_dispatch)
	var paths: Array[String]=["res://demo/tests/expanded_mission_route_bot.gd","res://demo/tests/expanded_mission_recovery_audit.gd","res://combat_pc/player.gd","res://demo/tests/relay_works_review.gd","res://demo/tests/relay_works_review.tscn"]
	for directory in ["res://demo","res://demo/components","res://demo/areas"]:
		for filename in DirAccess.get_files_at(directory):
			if filename.ends_with(".gd") or filename.ends_with(".tscn"): paths.append(directory+"/"+filename)
	for path in paths: source_hashes[path]=FileAccess.get_sha256(path)
	var cases: Array=[
		{"name":"service_left_floor_to_hub","start":Vector2(650,300),"goal":Vector2(1250,300)},
		{"name":"service_hub_to_left_floor","start":Vector2(1250,300),"goal":Vector2(650,300)},
		{"name":"lift_right_floor_to_upper_relay","start":Vector2(1920,300),"goal":Vector2(1920,-420)},
		{"name":"lift_hub_to_right_floor","start":Vector2(1250,300),"goal":Vector2(1820,300)},
		{"name":"dispatch_right_floor_to_relay","start":Vector2(3650,300),"goal":Vector2(3420,-40)},
		{"name":"dispatch_left_floor_to_relay","start":Vector2(3100,300),"goal":Vector2(3420,-40)}]
	for test in cases:
		host=load("res://demo/tests/relay_works_review.tscn").instantiate()
		root.add_child(host)
		host.save_enabled=false
		# Explicit fixture only: no position, health, AI, relay or collision writes
		# occur after this setup boundary.
		host.player.position=test.start
		host.player.velocity=Vector2.ZERO
		if sacrifice:
			host.blind=true
			host._apply_trade()
			host.sonar.set_blind(true)
		fixture_target=test.goal
		frame=0
		attack_clock=0
		events=[]
		trace=[]
		begin_sector()
		var start_elapsed: float=host.elapsed
		var completed:=false
		var failure:=""
		var starting_bounds=closed_shutters.map(func(rect):return str(rect))
		for tick in hz*40:
			frame=tick
			if host.state=="dead":
				failure="Actual player death during recovery"
				break
			if host.player.grounded and host.player.position.distance_to(fixture_target)<24:
				completed=true
				break
			host.input_override=decide()
			if nav_trace.get("unreachable",false): unreachable_seconds+=1.0/hz
			else: unreachable_seconds=0
			if unreachable_seconds>1:
				failure="No graph path from this closed compartment"
				break
			if tick%(hz/2)==0: trace.append(snapshot())
			await physics_frame
			await process_frame
		if not completed and failure.is_empty(): failure="Recovery exceeded40simulated seconds"
		if host.relay_states.size()!=0 or closed_shutters.size()!=3:
			failure="Fixture opened a relay/shutter"
			completed=false
		var row={"case":test.name,"fixture_start":str(test.start),"target":str(test.goal),"completed":completed,"failure":failure,"simulated_active_seconds":host.elapsed-start_elapsed,"final_position":str(host.player.position),"final_health":host.health.current_health,"blind":host.blind,"all_three_shutters_remained_closed":host.relay_states.is_empty() and closed_shutters.size()==3,"starting_closed_rectangles":starting_bounds,"events":events.duplicate(true),"trace":trace.duplicate(true)}
		fixture_rows.append(row)
		print("RECOVERY AUDIT ",test.name," completed=",completed," seconds=",row.simulated_active_seconds," position=",row.final_position," failure=",failure)
		if not completed: failures.append(test.name+": "+failure)
		host.input_override={}
		host.queue_free()
		await process_frame
		await process_frame
	var changed:=[]
	for path in source_hashes:
		if FileAccess.get_sha256(path)!=source_hashes[path]: changed.append(path)
	if not changed.is_empty(): failures.append("Source files changed during audit")
	var report={"suite":"Relay Works closed compartment recovery audit","hz":hz,"sacrificed_sight":sacrifice,"cases":fixture_rows,"failures":failures,"source_hashes":source_hashes,"sources_changed_during_run":changed,"human_duration_validated":false,"method":"Explicit pre-run position/sight fixtures, then ordinary production PC raw buttons only. No measured position/health/AI/relay/collision writes. All three shutters remain closed throughout. Separate from fresh full-route evidence."}
	var path="res://demo/evidence/expanded_mission_recovery_audit_%dhz_%s.json"%[hz,"sacrificed" if sacrifice else "retained"]
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("RECOVERY AUDIT RESULT ",path," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func decide() -> Dictionary:
	var p = host.player
	var pos: Vector2 = p.position
	var dt := 1.0/hz
	var d: Dictionary = host.sectors[host.sector]
	var raw := {}
	refresh_shutters(d)
	attack_clock += dt
	if absf(pos.x-last_x)<0.3: stagnant += dt
	else: stagnant = 0
	last_x = pos.x
	if frame % maxi(1,hz/3)==0:
		host.tap_weapon()
		inputs_count.tap+=1
	var target: Vector2=fixture_target
	var objective:="closed-compartment recovery"
	var enemy_target: Node2D = null
	var nearest := INF
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var distance: float = pos.distance_to(enemy.position)
		if distance<nearest and (distance<115 or (d.get("lock",false) and objective=="gate")):
			nearest=distance
			enemy_target=enemy
	var in_combat := false
	if enemy_target != null:
		in_combat=absf(pos.x-enemy_target.position.x)<90 and absf(pos.y-enemy_target.position.y)<40 and enemy_target._terrain_visible(pos+Vector2(0,-20))
		if in_combat or (d.get("lock",false) and objective=="gate"):
			target=enemy_target.position
			objective="enemy"
	var nav := navigate(target,d)
	if nav.get("drop",false) and not in_combat and p.grounded:
		return {"down":1.0,"jump":true} if not p._last_jump_held else {}
	var steering: Vector2 = nav.target
	var direction := signf(steering.x-pos.x)
	if absf(steering.x-pos.x)<8: direction=0
	if in_combat:
		direction=signf(enemy_target.position.x-pos.x)
		if absf(enemy_target.position.x-pos.x)<32: direction=0
		if p.facing!=int(signf(enemy_target.position.x-pos.x)): direction=signf(enemy_target.position.x-pos.x)
		var danger: bool=absf(enemy_target.position.x-pos.x)<70 and (enemy_target.ai_state==&"active" or (enemy_target.ai_state==&"windup" and enemy_target._phase_elapsed>enemy_target._windup-0.16))
		if danger: raw.shield=true
		elif absf(enemy_target.position.x-pos.x)<54 and attack_clock>0.15:
			raw.attack=true
			attack_clock=0
	if direction>0: raw.right=1.0
	elif direction<0: raw.left=1.0
	if nav.up and absf(steering.x-pos.x)<12:
		raw.erase("attack")
		raw.erase("shield")
		raw.erase("right")
		raw.erase("left")
		if not p._climb_needs_neutral or p.main_action==&"climb": raw.up=1.0
	var jump_needed: bool=nav.jump and not in_combat
	if not in_combat and direction!=0:
		for rect in d.platforms+freight_solids:
			if rect.size.y<=18: continue
			var edge: float=rect.position.x if direction>0 else rect.end.x
			if (edge-pos.x)*direction>=-8 and (edge-pos.x)*direction<(105 if rect.size.y>60 else 60) and pos.y>rect.position.y+8: jump_needed=true
		for gap in d.get("gaps",[]):
			var edge: float=gap.x if direction>0 else gap.y
			if (edge-pos.x)*direction>=-5 and (edge-pos.x)*direction<45: jump_needed=true
	if p.grounded:
		jump_age=-1
		jump_released=false
		if stagnant>0.45 and direction!=0 and not in_combat and not nav.up: jump_needed=true
		if jump_needed and not p._last_jump_held:
			jump_age=0
			raw.jump=true
	elif jump_age>=0:
		jump_age+=dt
		if jump_age<0.29: raw.jump=true
		elif not jump_released: jump_released=true
		elif jump_age<0.62: raw.jump=true
	elif pos.y>315 and p.air_jumps_left>0:
		raw.jump=true
		jump_age=0.3
		jump_released=true
	nav_trace.merge({"objective":objective,"goal":str(target),"steering":str(steering)},true)
	return raw

