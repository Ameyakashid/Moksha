extends "res://demo/tests/expanded_mission_route_bot.gd"
var journey_stage:=0
var cargo_still:=0.0
var last_strike:=-9999
var ordinary_crate:Node2D
var west_listener:Node2D
var decoy_id:=0
var noise_receipts:Array=[]
var listener_min_x:=INF
var listener_start_x:=0.0
var cargo_launches:Array=[]
var cargo_seen:={}
var listener_at_transfer:={}
var decoy_window:=false
var decoy_response_distance:=0.0
var previous_listener_x:=0.0
var full_campaign:=false
var acquisition_trace:Array=[]
func _initialize()->void:
	probe_sector=3
	scene_path="res://demo/tests/freight_journey_review.tscn"
	max_sector_seconds=120
	for arg in OS.get_cmdline_user_args():
		if arg=="--full-campaign":full_campaign=true
	if full_campaign:probe_sector=-1;scene_path="res://demo/mission.tscn"
	super._initialize()
func run()->void:
	source_hashes["res://demo/tests/freight_journey_route.gd"]=FileAccess.get_sha256("res://demo/tests/freight_journey_route.gd")
	await super.run()
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if cargo_launches.size()<3:failures.append("Multi-strike transport not demonstrated")
	if approach=="noise":
		if noise_receipts.is_empty():failures.append("No genuine ordinary-prop listener receipt")
		if decoy_response_distance<10:failures.append("No westward movement during ordinary-prop receipt window")
		if listener_at_transfer.is_empty() or listener_at_transfer.dead:failures.append("Distraction listener not alive during cargo transfer")
	report.merge({"journey_approach":approach,"isolated_sight_fixture":sacrifice and not full_campaign,"acquisition_trace":acquisition_trace,"cargo_launches":cargo_launches,"noise_receipts":noise_receipts,"listener_start_x":listener_start_x,"listener_min_x":listener_min_x,"listener_at_transfer":listener_at_transfer,"decoy_response_distance":decoy_response_distance,"full_campaign":full_campaign,"failures":failures,"passed":failures.is_empty()},true)
	var path="res://demo/evidence/freight_journey_%s_%dhz_%s.json"%[approach,hz,"traded" if sacrifice else "retained"]
	if full_campaign:path=path.trim_suffix(".json")+"_full_campaign.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("FREIGHT JOURNEY ",path," failures=",failures)
	quit(0 if failures.is_empty() else 1)
func begin_sector()->void:
	journey_stage=0
	super.begin_sector()
	if host.sector!=3:return
	west_listener=host.enemies[0]
	listener_start_x=west_listener.position.x
	listener_min_x=listener_start_x
	previous_listener_x=listener_start_x
	for prop in get_nodes_in_group("props"):
		if prop.global_position.distance_to(Vector2(510,285))<30:ordinary_crate=prop;decoy_id=prop.get_instance_id()
	west_listener.get_node("HearingSensor").heard.connect(func(receipt):
		decoy_window=int(receipt.get("source_id",0))==decoy_id
		if decoy_window:noise_receipts.append(receipt.duplicate(true)))
func decide()->Dictionary:
	if is_instance_valid(west_listener):
		listener_min_x=minf(listener_min_x,west_listener.position.x)
		if host.sector==3 and frame%maxi(1,hz/4)==0 and host.player.position.x<1250:
			acquisition_trace.append({"frame":frame,"player_position":str(host.player.position),"listener_position":str(west_listener.position),"listener_state":str(west_listener.ai_state),"listener_alive":not west_listener.dead,"prop_receipt_window":decoy_window,"latest_receipt":west_listener.get_node("HearingSensor").last_receipt.duplicate(true)})
		if decoy_window:decoy_response_distance+=maxf(0,previous_listener_x-west_listener.position.x)
		previous_listener_x=west_listener.position.x
	if host.sector==3 and approach=="noise" and journey_stage<2:return _decide_without_automatic_tap()
	return super.decide()
func freight_plan(data:Dictionary)->Dictionary:
	if host.sector!=3:return super.freight_plan(data)
	var player=host.player
	var cargo=host.room.freight_cradle.cargo
	if journey_stage==0:
		if approach=="noise":
			if is_instance_valid(ordinary_crate) and ordinary_crate.hit_count==0:
				var stance:=Vector2(ordinary_crate.global_position.x+40,300)
				if player.position.distance_to(stance)>9:return {"target":stance,"objective":"ordinary prop decoy stance"}
				if player.facing!=-1:return {"raw":{"left":1.0}}
				if not player.grounded or absf(player.velocity.x)>20 or player.weapon_phase!=&"idle":return {"raw":{}}
				return {"raw":{"attack":true}}
			journey_stage=1
		else:
			if not reached_supported_waypoint(Vector2(750,300),28):return {"target":Vector2(750,300),"objective":"loading lane"}
			journey_stage=2
	if journey_stage==1:
		if not reached_supported_waypoint(Vector2(900,100),28):return {"target":Vector2(900,100),"objective":"maintenance flank after decoy"}
		journey_stage=2
	if journey_stage==2:
		for enemy in host.enemies:
			if not enemy.dead and (approach!="noise" or enemy!=west_listener):return {"target":enemy.position,"objective":"secure transfer lane"}
		journey_stage=3
		if is_instance_valid(west_listener):listener_at_transfer={"position":str(west_listener.position),"dead":west_listener.dead,"frame":frame}
	if journey_stage==3:
		if not reached_supported_waypoint(Vector2(1100,160),25):return {"target":Vector2(1100,160),"objective":"return above cargo to safe loading side"}
		journey_stage=4
	var off_deck:bool=is_instance_valid(cargo) and cargo.global_position.x<2030 and (cargo.global_position.y>260 or cargo.global_position.x<1150)
	if not is_instance_valid(cargo) or not cargo.alive or off_deck:
		if host._near(data.freight.cradle,60):host.interact();return {"raw":{}}
		return {"target":data.freight.cradle-Vector2(40,0),"objective":"return for local replacement"}
	if not cargo_seen.has(cargo.get_instance_id()):
		cargo_seen[cargo.get_instance_id()]=true
		cargo.launched.connect(func(body):cargo_launches.append({"frame":frame,"position":str(body.global_position),"hit_count":body.hit_count,"hard_impacts":body.hard_impacts}))
	if cargo.linear_velocity.length()<25:cargo_still+=1.0/hz
	else:cargo_still=0
	var cargo_position:Vector2=cargo.global_position
	var stance:=Vector2(cargo_position.x-40,240)
	if cargo_position.x>2030:stance.y=270
	if player.position.distance_to(stance)>9:return {"target":stance,"objective":"follow actual freight"}
	if player.facing!=1:return {"raw":{"right":1.0}}
	if not player.grounded or absf(player.velocity.x)>20:return {"raw":{}}
	if cargo_still<0.25 or frame-last_strike<hz or player.weapon_phase!=&"idle":return {"raw":{}}
	last_strike=frame
	return {"raw":{"attack":true}}

# Exact preserved observer decide body, except no automatic Q input during
# the chosen quiet decoy/flank approach. No world/AI/outcome state is changed.
func _decide_without_automatic_tap() -> Dictionary:
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
	if host.sector==0 and frame<hz/2: return {"shield":true}
	if d.get("ending",false) and not roll_exercised and p.grounded and pos.x>120:
		roll_exercised=true
		return {"right":1.0,"roll":true}
	if d.has("station") and not choice_done and host._near(d.station):
		host.interact()
		return {}
	var relay_points: Array = host._relay_points()
	for index in relay_points.size():
		if not host.relay_states.has(index) and host._near(relay_points[index]): host.interact()
	if d.has("cache") and not host.caches.has(host.sector) and host._near(d.cache): host.interact()
	var gate := Vector2(float(d.width)-45,float(d.get("gate_y",300)))
	if host._near(gate,65) and host.room.gate_open:
		events.append({"event":"sector_exit","area_id":str(d.get("id","")),"sector":host.sector+1,"title":str(d.title),"active_seconds":host.elapsed,"remaining_enemies":host.remaining_enemies(),"kills_so_far":host.kills,"caches_so_far":host.caches.size(),"health":host.health.current_health,"activated_relays":host.relay_states.size(),"closed_shutters":closed_shutters.size(),"freight":freight_snapshot()})
		host.interact()
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
	# A horizontal dead zone must not strand an actually hanging actor. This is
	# ordinary navigation input, not a support/completion or actor-state override.
	if not in_combat and not nav.up:
		var recovery := ledge_waypoint_recovery(steering)
		if recovery.is_empty(): recovery = contact_waypoint_recovery(steering)
		if not recovery.is_empty(): raw = recovery
	nav_trace.merge({"objective":objective,"goal":str(target),"steering":str(steering)},true)
	return raw

