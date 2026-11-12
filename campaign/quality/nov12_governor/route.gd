extends "res://campaign/route_tests_45/input_probe.gd"
const Sink=preload("res://campaign/quality/nov12_report_sink.gd")
var destination:=""
var east_first:=false
func _initialize()->void:
 area_id="crown_manual_governor"
 scene_path="res://campaign/campaign.tscn"
 choice_done=false
 hz=60
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):destination=arg.trim_prefix("--report=")
  if arg=="--east-first":east_first=true
  if arg=="--blind":sacrifice=true
 var error=Sink.validate(destination)
 if not error.is_empty():push_error(error);quit(2);return
 Engine.physics_ticks_per_second=hz
 run.call_deferred()
func ordered_goals()->Array:
 var result:Array=host.goals.duplicate()
 if east_first:
  result.sort_custom(func(a,b):return str(a.objective_id)=="supply" and str(b.objective_id)!="supply")
 return result
func run()->void:
 input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
 host=load(scene_path).instantiate();root.add_child(host);host.save_enabled=false
 host.start_new(true)
 for i in host.sectors.size():
  if host.sectors[i].id==area_id:probe_sector=i
 host.load_sector(probe_sector)
 collect_production_sources("res://",run_sources)
 for tick in range(60*240):
  frame=tick
  if host.sector!=probe_sector:break
  if host.state=="dead":failures.append("Actual input death");break
  if host.state=="archive":request_key(KEY_E)
  elif host.state=="choice":
   host.input_override={}
   request_key(KEY_J if sacrifice else KEY_K)
   choice_done=true
  elif host.state=="playing":
   if not choice_done:
    host.input_override={};request_key(KEY_E)
   else:
    if sector_seen!=host.sector:begin_sector()
    host.input_override=decide()
   for goal in host.goals:
    if goal.completed and not completed_ids.has(goal.objective_id):completed_ids.append(goal.objective_id)
  await physics_frame
  await process_frame
 var reached:bool=host.sector!=probe_sector
 if not reached:failures.append("District not exited")
 var expected:Array=["supply","authority","governor"] if east_first else ["authority","supply","governor"]
 if completed_ids!=expected:failures.append("Goal order/optional mismatch: "+str(completed_ids))
 if host.blind!=sacrifice:failures.append("Sight mismatch")
 var drift:Array=[]
 for path in run_sources:
  if FileAccess.get_sha256(path)!=run_sources[path]:drift.append(path)
 var report={"passed":reached and failures.is_empty() and drift.is_empty(),"failures":failures,"source_drift":drift,"source_hashes":run_sources,"completed_ids":completed_ids,"east_first":east_first,"blind":host.blind,"choice_done":choice_done,"seconds":frame/60.0,"method":"Explicit initial Governor district fixture. Actual station E and sight-choice keys, then ordinary movement/combat/interact inputs. No measured position/health/goal/AI writes.","observer_sha256":FileAccess.get_sha256(get_script().resource_path)}
 var error=Sink.write_report(destination,report)
 print("GOVERNOR_RESULT ",report.passed," ",failures," sink=",error)
 var code:=0 if report.passed and error.is_empty() else 1
 host.free();input_dispatch.free();await process_frame;quit(code)
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
 for goal in ordered_goals():
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
  for hazard in d.get("hazards",[]):
   var hazard_rect:Rect2=Rect2(hazard.at-hazard.size/2,hazard.size)
   var hazard_edge:float=hazard_rect.position.x if direction>0 else hazard_rect.end.x
   if pos.y>hazard_rect.position.y-20 and (hazard_edge-pos.x)*direction>=-5 and (hazard_edge-pos.x)*direction<55:
    jump_needed=true
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
