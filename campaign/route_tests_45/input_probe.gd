extends "res://demo/tests/expanded_mission_route_bot.gd"
## Isolated district fixture; thereafter actual PC inputs and idle-dispatched keys only.
var area_id := "works_receiving"
var key_pending := false
var last_key_frame := -999
var completed_ids: Array[String] = []
var run_sources: Dictionary = {}
var final_run := false
func _initialize() -> void:
	scene_path="res://campaign/campaign.tscn"
	max_sector_seconds=240
	choice_done=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--area="):area_id=arg.trim_prefix("--area=")
		if arg=="--blind":sacrifice=true
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg=="--final":final_run=true
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func request_key(code:int)->void:
	if key_pending or frame-last_key_frame<12:return
	key_pending=true;last_key_frame=frame
	input_dispatch.pending.append(func():
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
		host._unhandled_key_input(event)
		key_pending=false)
func collect_production_sources(directory:String, result:Dictionary)->void:
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension() in ["gd","tres","tscn","godot","gdshader"]:
			var path:=directory.path_join(filename)
			result[path]=FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory):
		if child.begins_with(".") or "test" in child or "evidence" in child or "qa" in child or child=="docs":continue
		collect_production_sources(directory.path_join(child),result)
func run()->void:
	for source in ["res://campaign/layouts/level_04.gd","res://campaign/layouts/level_05.gd","res://campaign/logic/campaign.gd","res://campaign/logic/objective.gd","res://campaign/logic/objective_door.gd","res://demo/tests/expanded_mission_route_bot.gd","res://campaign/vendor/beehave/blackboard.gd","res://campaign/enemies/captain_policy.gd","res://campaign/enemies/keeper.tscn","res://campaign/enemies/keeper_melee.tres","res://campaign/enemies/keeper_archetype.tres",get_script().resource_path]:run_sources[source]=FileAccess.get_sha256(source)
	collect_production_sources("res://",run_sources)
	input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
	host=load(scene_path).instantiate();root.add_child(host);host.save_enabled=false
	host.start_new(true)
	for index in host.sectors.size():
		if host.sectors[index].id==area_id:probe_sector=index;break
	if probe_sector<0:push_error("Unknown area "+area_id);quit(2);return
	# Explicit initial sector/sight fixture, excluded from navigation evidence.
	host.load_sector(probe_sector)
	if sacrifice:
		host.blind=true;host._apply_build();host.sonar.set_blind(true)
	for tick in range(hz*max_sector_seconds):
		frame=tick
		if host.sector!=probe_sector or host.state in ["upgrade","final_choice","complete"]:break
		if host.state=="dead":failures.append("Actual-input death at "+str(host.player.position));break
		if host.state=="archive":request_key(KEY_E)
		elif host.state=="choice":request_key(KEY_K)
		elif host.state=="playing":
			if sector_seen!=host.sector:begin_sector()
			host.input_override=decide()
			for goal in host.goals:
				if goal.completed and not completed_ids.has(goal.objective_id):
					completed_ids.append(goal.objective_id);events.append({"event":"objective_completed","id":goal.objective_id,"frame":frame,"position":str(host.player.position)})
			if tick%120==0:trace.append(snapshot())
			if tick%600==0:print("PROBE ",area_id," ",snapshot())
		await physics_frame
		await process_frame
	var passed:bool=host.sector!=probe_sector or host.state in ["upgrade","final_choice","complete"]
	if not passed and failures.is_empty():failures.append("Navigation timed out at "+str(host.player.position))
	var end_sources:Dictionary={}
	collect_production_sources("res://",end_sources)
	var changed_sources:Array[String]=[]
	for source in end_sources:
		if not run_sources.has(source):changed_sources.append(source+" (new)")
	for source in run_sources:
		end_sources[source]=FileAccess.get_sha256(source)
		if end_sources[source]!=run_sources[source]:changed_sources.append(source)
	if not changed_sources.is_empty():
		failures.append("Sources changed during run: "+str(changed_sources))
		passed=false
	var result={"hz":hz,"source_hashes_at_end":end_sources,"sources_changed_during_run":changed_sources,"source_hashes_at_start":run_sources,"area":area_id,"passed":passed,"failures":failures,"blind_fixture":sacrifice,"frames":frame,"active_seconds":host.elapsed,"human_duration_validated":false,"completed_objectives":completed_ids,"state":host.state,"method":"Isolated initial district/sight fixture; thereafter raw input_override + idle-dispatched physical keys, autonomous enemies live, no player/enemy/goal/health/collision writes.","events":events,"trace":trace}
	var folder:="res://campaign/route_tests_45/final/" if final_run else "res://campaign/route_tests_45/"
	DirAccess.make_dir_recursive_absolute(folder)
	var output=folder+area_id+("_blind" if sacrifice else "_sighted")+("_%dhz"%hz if final_run else "")+".json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PROBE RESULT ",area_id," ",passed," ",failures)
	quit(0 if passed else 1)

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
		request_key(KEY_Q)
		inputs_count.tap+=1
	if host.sector==0 and frame<hz/2: return {"shield":true}
	if d.get("ending",false) and not roll_exercised and p.grounded and pos.x>120:
		roll_exercised=true
		return {"right":1.0,"roll":true}
	if d.has("station") and not choice_done and host._near(d.station):
		request_key(KEY_E)
		return {}
	var relay_points: Array = host._relay_points()
	for index in relay_points.size():
		if not host.relay_states.has(index) and host._near(relay_points[index]): request_key(KEY_E)
	if d.has("cache") and not host.caches.has(host.sector) and host._near(d.cache): request_key(KEY_E)
	var gate := Vector2(float(d.width)-45,float(d.get("gate_y",300)))
	if host._near(gate,65) and host.room.gate_open:
		events.append({"event":"sector_exit","area_id":str(d.get("id","")),"sector":host.sector+1,"title":str(d.title),"active_seconds":host.elapsed,"remaining_enemies":host.remaining_enemies(),"kills_so_far":host.kills,"caches_so_far":host.caches.size(),"health":host.health.current_health,"activated_relays":host.relay_states.size(),"closed_shutters":closed_shutters.size(),"freight":freight_snapshot()})
		request_key(KEY_E)
		return {}
	var target := gate
	var objective := "gate"
	for index in relay_points.size():
		if not host.relay_states.has(index):
			target=relay_points[index]
			objective="relay %d"%index
			break
	if d.has("station") and not choice_done:
		target=d.station
		objective="station"
	for goal in host.goals:
		if goal.completed or goal.optional or not goal.required_ids.all(func(id): return host.goal_done(id)): continue
		target=goal.global_position
		objective="campaign goal " + goal.objective_id
		if goal.kind=="breaker" and absf(pos.y-target.y)<35 and absf(pos.x-target.x)<48:
			var facing_goal:=signf(target.x-pos.x)
			var strike:Dictionary={"attack":frame%maxi(1,hz/2)==0}
			if p.facing!=int(facing_goal):strike["right" if facing_goal>0 else "left"]=1.0
			return strike
		if host._near(target,48):
			request_key(KEY_E)
			return {}
		break
	if relay_recovery_probe and d.has("relay_labels") and host.relay_states.has(0) and relay_recovery_phase<2:
		if relay_recovery_phase==0:
			if reached_supported_waypoint(Vector2(1740,0),24):
				relay_recovery_phase=1
			else:
				target=Vector2(1740,0)
				objective="diagnostic recovery approach"
		if relay_recovery_phase==1:
			if p.grounded and pos.y>295 and pos.x>1690:
				relay_recovery_phase=2
				if host.relay_states.has(1): failures.append("Recovery fall occurred after Lift shutter already opened")
				events.append({"event":"actual_fall_right_of_closed_lift_shutter","frame":frame,"position":str(pos),"active_relays":host.relay_states.duplicate(),"closed_shutters":closed_shutters.map(func(rect):return str(rect))})
			else:
				target=Vector2(1900,300)
				objective="diagnostic actual fall"
	if d.has("freight") and not host.room.freight_receiver.is_latched:
		var cargo_plan := freight_plan(d)
		if cargo_plan.has("raw"): return cargo_plan.raw
		target=cargo_plan.target
		objective="freight " + str(cargo_plan.objective)
	if d.has("freight") and host.room.freight_receiver.is_latched:
		if p.main_action==&"ledge" and stagnant>0.8 and pos.x>d.freight.receiver.x:
			freight_stage=2
		if freight_stage<3:
			var basin_step: Vector2=d.freight.receiver+Vector2(-30,0)
			if freight_basin_staged(basin_step):
				freight_stage=3
				events.append({"event":"freight_basin_egress_staging","frame":frame,"position":str(pos)})
			else:
				target=basin_step
				objective="freight basin staging"
	var enemy_target: Node2D = null
	var nearest := INF
	for enemy in host.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var distance: float = pos.distance_to(enemy.position)
		var mandatory:bool=d.get("lock",false) or (d.get("captain_required",false) and str(enemy.kind).begins_with("captain_"))
		if distance<nearest and (distance<115 or (mandatory and objective=="gate")):
			nearest=distance
			enemy_target=enemy
	var in_combat := false
	if enemy_target != null:
		in_combat=absf(pos.x-enemy_target.position.x)<90 and absf(pos.y-enemy_target.position.y)<40 and enemy_target._terrain_visible(pos+Vector2(0,-20))
		if in_combat or ((d.get("lock",false) or (d.get("captain_required",false) and str(enemy_target.kind).begins_with("captain_"))) and objective=="gate"):
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
		# Common observed protection is a defensive cue, independent of role.
		# Do not sword-advance through a warning that short recoil cannot stop.
		var protected: bool=enemy_target.has_method("hurt_response_snapshot") and bool(enemy_target.hurt_response_snapshot().protected)
		var warning_remaining: float=enemy_target._windup-enemy_target._phase_elapsed
		if protected and enemy_target.ai_state==&"windup" and warning_remaining>.22 and absf(enemy_target.position.x-pos.x)<28:
			# Ordinary retreat early in the warning creates a real front contact;
			# later ordinary facing input turns back before the shield opening.
			direction=-signf(enemy_target.position.x-pos.x)
		var danger: bool=absf(enemy_target.position.x-pos.x)<70 and (enemy_target.ai_state==&"active" or (enemy_target.ai_state==&"windup" and warning_remaining<(.10 if protected else .16)))
		if danger: raw.shield=true
		elif not protected and absf(enemy_target.position.x-pos.x)<54 and attack_clock>0.15:
			raw.attack=true
			attack_clock=0
	if direction>0: raw.right=1.0
	elif direction<0: raw.left=1.0
	if nav.up and absf(steering.x-pos.x)<18 and stagnant>0.3:
		var obstruction:=KinematicCollision2D.new()
		if p.test_move(p.global_transform,Vector2(signf(steering.x-pos.x)*20,0),obstruction,p.profile.collision_margin) and obstruction.get_collider() is RigidBody2D:
			# A noise prop can move into the ladder approach; strike it aside physically.
			if frame%120==0:print("CLEAR MOVABLE LADDER OBSTRUCTION ",obstruction.get_collider().get_path())
			return {"attack":frame%maxi(1,hz/2)==0,"right":1.0} if steering.x>=pos.x else {"attack":frame%maxi(1,hz/2)==0,"left":1.0}
	if nav.up and absf(steering.x-pos.x)<12:
		raw.erase("attack")
		raw.erase("shield")
		raw.erase("right")
		raw.erase("left")
		if not p._climb_needs_neutral or p.main_action==&"climb": raw.up=1.0
	var jump_needed: bool=nav.jump and not in_combat
	if not in_combat and direction!=0:
		for rect in d.platforms+freight_solids:
			# Observer: a suspended solid above the standing body is not a ground obstacle.
			if pos.y-p.body_height>=rect.end.y: continue
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
	# A horizontal dead zone must not strand an actually hanging actor. This is
	# ordinary navigation input, not a support/completion or actor-state override.
	if not in_combat and not nav.up:
		var recovery := ledge_waypoint_recovery(steering)
		if recovery.is_empty(): recovery = contact_waypoint_recovery(steering)
		if not recovery.is_empty(): raw = recovery
	nav_trace.merge({"objective":objective,"goal":str(target),"steering":str(steering)},true)
	return raw

func freight_plan(d:Dictionary)->Dictionary:
	var p=host.player
	var cargo=host.room.freight_cradle.cargo
	if not is_instance_valid(cargo) or not cargo.alive:
		if host._near(d.freight.cradle,58):request_key(KEY_E);return {"raw":{}}
		return {"target":d.freight.cradle,"objective":"replace destroyed cargo"}
	var stance:Vector2=Vector2(cargo.global_position.x-40,240)
	if cargo.global_position.x>d.freight.receiver.x-80:return {"target":Vector2(d.freight.receiver.x-160,240),"objective":"let delivery settle"}
	if cargo.linear_velocity.length()>45:
		return {"target":Vector2(cargo.global_position.x-90,240),"objective":"escort moving cargo"}
	if p.position.distance_to(stance)>10:return {"target":stance,"objective":"relaunch stance"}
	if p.facing!=1:return {"raw":{"right":1.0}}
	if absf(p.velocity.x)>20 or not p.grounded:return {"raw":{}}
	if p.weapon_phase!=&"idle" or frame-freight_attack_frame<hz/2:return {"raw":{}}
	freight_attack_frame=frame
	events.append({"event":"cargo_relaunch_input","frame":frame,"cargo_position":str(cargo.global_position),"hit_count":cargo.hit_count})
	return {"raw":{"attack":true}}

var machine_step := 0
func navigate(target:Vector2,d:Dictionary)->Dictionary:
	if area_id=="works_three_crews" and not host.relay_states.has(1) and host.relay_states.has(0) and target.distance_to(Vector2(3440,-430))<1:
		var points:Array[Vector2]=[Vector2(2600,80),Vector2(2700,-140),Vector2(2890,-195),Vector2(2980,-250),Vector2(3150,-155),Vector2(3200,-430),Vector2(3440,-430)]
		if machine_step<points.size() and reached_supported_waypoint(points[machine_step],18):machine_step+=1
		if machine_step<points.size():target=points[machine_step]
	if host.player.main_action==&"climb" and target.y<host.player.position.y-5:
		return {"target":Vector2(host.player.position.x,target.y),"up":true,"jump":false,"drop":false}
	return super.navigate(target,d)
