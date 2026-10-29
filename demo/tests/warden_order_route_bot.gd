extends "res://demo/tests/expanded_mission_route_bot.gd"
const CampaignIdentity=preload("res://demo/tests/campaign_identity.gd")
## Raw-input target-order experiment. No enemy/health/state outcome writes.
var defeat_order:Array=[]
var health_receipts:Array=[]
var upper_crossed:=false
var right_loop_reached:=false
func _initialize():
 probe_sector=CampaignIdentity.index(preload("res://demo/mission_data.gd").sectors(),"lift_warden")
 scene_path="res://demo/tests/warden_loops_review.tscn"
 max_sector_seconds=150
 super._initialize()
func preferred_enemy():
 if approach=="sentries_first" and host.enemies[0].dead and not right_loop_reached:return null
 var order:Array=[1,0,2] if approach=="warden_first" else [0,2,1]
 for index in order:
  var enemy=host.enemies[index]
  if is_instance_valid(enemy) and not enemy.dead:return enemy
 return null
func begin_sector():
 super.begin_sector()
 for index in host.enemies.size():
  var enemy=host.enemies[index]
  enemy.defeated.connect(func(_enemy):defeat_order.append(index);events.append({"event":"actual_enemy_defeated","roster_index":index,"frame":frame,"position":str(_enemy.position)}))
  enemy.get_node("Health").damage_processed.connect(func(receipt):health_receipts.append(receipt.merged({"roster_index":index,"frame":frame,"player_position":str(host.player.position),"enemy_position":str(enemy.position)})))
func run():
 starting_sight_fixture=sacrifice
 source_hashes["res://demo/tests/warden_order_route_bot.gd"]=FileAccess.get_sha256("res://demo/tests/warden_order_route_bot.gd")
 await super.run()
 var expected:Array=[1,0,2] if approach=="warden_first" else [0,2,1]
 if str(host.sectors[host.sector].id)!="above_the_rain":failures.append("No actual onward transition into ending sector")
 if defeat_order!=expected:failures.append("Actual defeat order mismatch: %s expected%s"%[defeat_order,expected])
 if approach=="sentries_first" and not events.any(func(e):return e.event=="actual_right_loop_flank_with_sentry_alive"):failures.append("Right loop was not used before defeating right sentry")
 if approach=="sentries_first" and not upper_crossed:failures.append("Sentries-first route did not cross western upper loop")
 if not right_loop_reached:failures.append("Did not physically reach far side of right upper loop")
 if health_receipts.is_empty():failures.append("No genuine Health damage receipts")
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
 report.merge({"target_order":approach,"western_upper_loop":upper_crossed,"right_upper_loop":right_loop_reached,"actual_defeat_order":defeat_order,"health_receipts":health_receipts,"failures":failures,"passed":failures.is_empty(),"sight_fixture":"Explicit pre-clock traded-sight configuration; full campaign must exercise real Exchange choice" if sacrifice else "Retained sight; no trade applied", "actual_onward_transition":str(host.sectors[host.sector].id)=="above_the_rain"},true)
 var dest="res://demo/evidence/warden_order_%s_%s_%dhz.json"%[approach,"traded" if sacrifice else "retained",hz]
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("WARDEN ORDER RESULT ",dest," failures=",failures)
 quit(0 if failures.is_empty() else 1)
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if str(host.sectors[host.sector].id)=="lift_warden":
  if approach=="sentries_first" and host.enemies[0].dead and not host.enemies[2].dead and not upper_crossed:
   target=Vector2(970,135)
   if reached_supported_waypoint(target,30):
    upper_crossed=true
    events.append({"event":"actual_western_upper_crossover","position":str(host.player.position),"frame":frame,"warden_alive":not host.enemies[1].dead})
  if approach=="sentries_first" and upper_crossed and not host.enemies[2].dead and not right_loop_reached:
   target=Vector2(1350,190)
   if reached_supported_waypoint(target,25):
    right_loop_reached=true
    events.append({"event":"actual_right_loop_flank_with_sentry_alive","position":str(host.player.position),"frame":frame,"sentry_health":host.enemies[2].health,"warden_alive":not host.enemies[1].dead})
  if host.remaining_enemies()==0 and not right_loop_reached:
   target=Vector2(1350,190)
   if reached_supported_waypoint(target,25):
    right_loop_reached=true
    events.append({"event":"actual_right_upper_loop","position":str(host.player.position),"frame":frame})
 return super.navigate(target,d)
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
   if reached_supported_waypoint(basin_step,16):
    freight_stage=3
    events.append({"event":"freight_basin_egress_staging","frame":frame,"position":str(pos)})
   else:
    target=basin_step
    objective="freight basin staging"
 var enemy_target: Node2D = null
 var nearest := INF
 for enemy in host.enemies:
  if enemy != preferred_enemy(): continue
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
   # Hanging cover above a standing body is not a ground obstacle to jump.
   if pos.y-p.body_height>=rect.end.y:continue
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

