extends "res://demo/tests/expanded_mission_route_bot.gd"
## Explicit district-start fixture; measured phase uses ordinary production inputs.
var district_id := "l2_capacitor_mill"
var measured_start := 0.0
var goals_seen: Dictionary = {}
var goal_target := Vector2.ZERO
var have_goal := false
var interaction_tick := -999
var checkpoint_hashes: Dictionary = {}
var residential_index := 0
var machine_step := 0
var machine_area := ""
var residential_points: Array[Vector2] = [Vector2(200,245),Vector2(290,190),Vector2(600,135),Vector2(850,80),Vector2(1120,25),Vector2(1850,-30),Vector2(2350,-30),Vector2(2870,25),Vector2(2940,300),Vector2(2730,25),Vector2(3470,-30),Vector2(4000,-85),Vector2(4450,-30),Vector2(4990,-85)]
func _initialize() -> void:
 scene_path="res://campaign/campaign.tscn"
 max_sector_seconds=240
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--district="): district_id=arg.trim_prefix("--district=")
 super._initialize()
func run() -> void:
 input_dispatch=InputDispatch.new()
 input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS
 root.add_child(input_dispatch)
 host=load(scene_path).instantiate()
 root.add_child(host)
 host.save_enabled=false
 host.start_new(true)
 for i in host.sectors.size():
  if str(host.sectors[i].id)==district_id: probe_sector=i
 if probe_sector<0:
  push_error("Unknown district: "+district_id);quit(2);return
 host.load_sector(probe_sector)
 if sacrifice:
  host.state="choice" # Explicit PRE-RUN sight fixture, never measured gameplay.
  host.choose_sight(true)
  starting_sight_fixture=true
  choice_done=true
 assert(host.blind==sacrifice,"Requested isolated sight fixture did not apply")
 measured_start=host.elapsed
 events.append({"event":"isolated_start_fixture","district":district_id,"sight_fixture":sacrifice,"not_full_campaign":true})
 capture_sources("res://")
 for tick in range(hz*max_sector_seconds):
  frame=tick
  if host.sector!=probe_sector or host.state=="upgrade":break
  if host.state=="dead":
   failures.append("Ordinary input route died")
   break
  if host.state=="archive":await key(KEY_E)
  elif host.state=="choice":
   await key(KEY_J if sacrifice else KEY_K)
   choice_done=true
  elif host.state=="playing":
   if sector_seen!=host.sector:begin_sector()
   host.input_override=decide()
   if frame%hz==0:
    trace.append(snapshot())
    if trace.size()>60:trace.pop_front()
   if frame%(hz*15)==0:print("L23 ",district_id," ",snapshot())
  await physics_frame
  await process_frame
 var reached:bool=host.sector!=probe_sector or host.state=="upgrade"
 if not reached and failures.is_empty():failures.append("District timeout")
 var drift:Array[String]=[]
 for path in checkpoint_hashes:
  if FileAccess.get_sha256(path)!=checkpoint_hashes[path]:drift.append(path)
 var report={"district":district_id,"passed":reached and failures.is_empty(),"sight":sacrifice,"explicit_start_and_sight_fixture":true,"full_campaign_evidence":false,"bot_active_seconds":host.elapsed-measured_start,"human_duration_validated":false,"failures":failures,"goals_observed":goals_seen,"events":events,"trace":trace,"source_drift":drift,"source_hashes":checkpoint_hashes,"method":"Measured phase: raw ordinary buttons plus proximity E events. No teleport, damage/health/AI writes, forced goals or gate edits. Initial district and sight are explicit isolated fixtures."}
 var path="res://campaign/route_tests/"+district_id+("_traded" if sacrifice else "_retained")+".json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("L23_RESULT ",path," passed=",report.passed," bot_seconds=",report.bot_active_seconds," failures=",failures)
 quit(0 if report.passed else 1)
func decide() -> Dictionary:
 if district_id=="l3_homes" and residential_index<residential_points.size() and reached_supported_waypoint(residential_points[residential_index],20):
  events.append({"event":"actual_residential_waypoint","index":residential_index,"position":str(host.player.position)})
  residential_index+=1
 have_goal=false
 for goal in host.goals:
  if goal.completed:
   if not goals_seen.has(goal.objective_id):
    goals_seen[goal.objective_id]={"frame":frame,"position":str(host.player.position),"kind":goal.kind,"setting":goal.setting}
   continue
  if goal.optional or not goal.available:continue
  if not have_goal:
   have_goal=true
   goal_target=goal.global_position
  if goal.kind=="breaker" and host._near(goal.global_position,48):
   var facing:float=signf(goal.global_position.x-host.player.position.x)
   if host.player.facing!=int(facing) and facing!=0:
    return {"right":1.0} if facing>0 else {"left":1.0}
   if frame-interaction_tick>=12:
    interaction_tick=frame
    return {"attack":true}
   return {}
  if host._near(goal.global_position,48) and frame-interaction_tick>=12:
   interaction_tick=frame
   queue_key(KEY_E)
   return {}
 return production_decide()
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 var fighting:bool=host.enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and host.player.position.distance_to(enemy.position)<115)
 if have_goal and not fighting:
  var pending_relays:=false
  for index in host._relay_points().size():
   if not host.relay_states.has(index):pending_relays=true
  var hauling:bool=d.has("freight") and not host.room.freight_receiver.is_latched
  if not pending_relays and (not hauling or (str(d.id)=="l2_freight" and not host.goal_done("ticket"))):target=goal_target
 if not have_goal and d.get("captain_required",false) and not fighting:
  for enemy in host.enemies:
   if is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_"):
    target=enemy.position
    break
 if district_id=="l3_homes" and residential_index<residential_points.size() and not fighting:
  target=residential_points[residential_index]
 if machine_area!=str(d.id):
  machine_area=str(d.id)
  machine_step=0
 if str(d.id)=="works_three_crews" and not host.relay_states.has(1) and host.relay_states.has(0) and target.distance_to(Vector2(3440,-430))<1:
  var points:Array[Vector2]=[Vector2(2600,80),Vector2(2700,-140),Vector2(2890,-195),Vector2(2980,-250),Vector2(3150,-155),Vector2(3200,-430),Vector2(3440,-430)]
  if machine_step<points.size() and reached_supported_waypoint(points[machine_step],18):machine_step+=1
  if machine_step<points.size():target=points[machine_step]
 if host.player.main_action==&"climb" and target.y<host.player.position.y-5:
  return {"target":Vector2(host.player.position.x,target.y),"up":true,"jump":false,"drop":false}
 var navigation:Dictionary=super.navigate(target,d)
 if navigation.get("drop",false) and host.player.grounded and host.player._support is RigidBody2D:
  # A crate is not a one-way platform: step/jump off its real support instead.
  navigation["drop"]=false
  navigation["jump"]=true
  navigation["target"]=Vector2(host.player.position.x+90*signf(target.x-host.player.position.x),host.player.position.y)
 return navigation
func refresh_shutters(d:Dictionary,force:=false)->void:
 var bounds:Array[Rect2]=[]
 var signature:=""
 var shutters:Array=host.room.shutters.duplicate()
 if is_instance_valid(host.room.freight_shutter):shutters.append(host.room.freight_shutter)
 for shutter in shutters:
  signature+=str(shutter.is_open)
  if not shutter.is_open and not shutter.collision_shape.disabled:
   var shape=shutter.collision_shape
   bounds.append(Rect2(shape.global_position-shape.shape.size*.5,shape.shape.size))
 for node in host.room.get_children():
  if node.get_script()==preload("res://campaign/logic/objective_door.gd"):
   signature+=str(node.opened)
   if not node.opened:bounds.append(Rect2(node.global_position-node.door_size*.5,node.door_size))
 if signature!=shutter_signature or force:
  shutter_signature=signature
  closed_shutters=bounds
  build_navigation(d)

func queue_key(code:int)->void:
 input_dispatch.pending.append(func():
  var event:=InputEventKey.new()
  event.physical_keycode=code
  event.pressed=true
  host._unhandled_key_input(event))

func production_decide() -> Dictionary:
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
  queue_key(KEY_Q)
  inputs_count.tap+=1
 if host.sector==0 and frame<hz/2: return {"shield":true}
 if d.get("ending",false) and not roll_exercised and p.grounded and pos.x>120:
  roll_exercised=true
  return {"right":1.0,"roll":true}
 if d.has("station") and not choice_done and host._near(d.station):
  queue_key(KEY_E)
  return {}
 var relay_points: Array = host._relay_points()
 for index in relay_points.size():
  if not host.relay_states.has(index) and host._near(relay_points[index]): queue_key(KEY_E)
 if d.has("cache") and not host.caches.has(host.sector) and host._near(d.cache): queue_key(KEY_E)
 var gate := Vector2(float(d.width)-45,float(d.get("gate_y",300)))
 if host._near(gate,65) and host.room.gate_open:
  events.append({"event":"sector_exit","area_id":str(d.get("id","")),"sector":host.sector+1,"title":str(d.title),"active_seconds":host.elapsed,"remaining_enemies":host.remaining_enemies(),"kills_so_far":host.kills,"caches_so_far":host.caches.size(),"health":host.health.current_health,"activated_relays":host.relay_states.size(),"closed_shutters":closed_shutters.size(),"freight":freight_snapshot()})
  queue_key(KEY_E)
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
 if nav.up and absf(steering.x-pos.x)<18 and stagnant>0.3:
  var obstruction:=KinematicCollision2D.new()
  if p.test_move(p.global_transform,Vector2(signf(steering.x-pos.x)*20,0),obstruction,p.profile.collision_margin) and obstruction.get_collider() is RigidBody2D:
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


var cargo_still := 0.0
var last_cargo_strike := -9999
func freight_plan(data:Dictionary)->Dictionary:
 if str(data.id)!="l2_freight":return freight_45_plan(data)
 var player=host.player
 var cargo=host.room.freight_cradle.cargo
 if not host.goal_done("ticket"):
  return {"target":Vector2(790,100),"objective":"recover real shipment docket first"}
 var off_deck:bool=is_instance_valid(cargo) and cargo.global_position.x<2030 and (cargo.global_position.y>260 or cargo.global_position.x<1150)
 if not is_instance_valid(cargo) or not cargo.alive or off_deck:
  if host._near(data.freight.cradle,60):queue_key(KEY_E);return {"raw":{}}
  return {"target":data.freight.cradle-Vector2(40,0),"objective":"return for local replacement"}
 if not freight_seen_cargo.has(cargo.get_instance_id()):
  freight_seen_cargo[cargo.get_instance_id()]=true
  cargo.launched.connect(func(body):events.append({"event":"actual_multi_strike_cargo_launch","frame":frame,"position":str(body.global_position),"hit_count":body.hit_count}))
 if cargo.linear_velocity.length()<25:cargo_still+=1.0/hz
 else:cargo_still=0
 var cargo_position:Vector2=cargo.global_position
 var stance:=Vector2(cargo_position.x-40,240)
 if cargo_position.x>2030:stance.y=270
 if player.position.distance_to(stance)>9:return {"target":stance,"objective":"follow actual freight"}
 if player.facing!=1:return {"raw":{"right":1.0}}
 if not player.grounded or absf(player.velocity.x)>20:return {"raw":{}}
 if cargo_still<.25 or frame-last_cargo_strike<hz or player.weapon_phase!=&"idle":return {"raw":{}}
 last_cargo_strike=frame
 return {"raw":{"attack":true}}

func capture_sources(directory:String)->void:
 for filename in DirAccess.get_files_at(directory):
  if filename.get_extension() in ["gd","tscn","tres","gdshader"]:
   var path=directory.path_join(filename)
   checkpoint_hashes[path]=FileAccess.get_sha256(path)
 for child in DirAccess.get_directories_at(directory):
  if not child.begins_with("."):
   capture_sources(directory.path_join(child))

func freight_45_plan(d:Dictionary)->Dictionary:
 var p=host.player
 var cargo=host.room.freight_cradle.cargo
 if not is_instance_valid(cargo) or not cargo.alive:
  if host._near(d.freight.cradle,58):queue_key(KEY_E);return {"raw":{}}
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
