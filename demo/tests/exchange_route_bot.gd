extends "res://demo/tests/expanded_mission_route_bot.gd"
## Explicit sector-start fixture; measured traversal uses real raw PC controls.
var lift_stage:=0
var lift_carry_frames:=0
var lift_first_y:=0.0
var lift_min_y:=INF
var stair_distance:=0.0
var last_observed:=Vector2.ZERO
var observed:=false
var bridge_crossed:=false
var bridge_staged:=false
var recovery:=false
var recovered_floor:=false
var recovery_phase:=0
var activation_order:Array=[]
func _initialize():
 probe_sector=2
 max_sector_seconds=120
 for arg in OS.get_cmdline_user_args():
  if arg=="--recovery":recovery=true
 super._initialize()
func run():
 source_hashes["res://demo/tests/exchange_route_bot.gd"]=FileAccess.get_sha256("res://demo/tests/exchange_route_bot.gd")
 await super.run()
 if approach=="stairs" and activation_order!=[1,0]:failures.append("Stair route did not prove calibration-first order")
 if approach=="lift" and activation_order!=[0,1]:failures.append("Lift route did not prove pressure-first order")
 if not choice_done:failures.append("Actual Exchange sight choice not exercised")
 if sacrifice!=host.blind:failures.append("Requested sight choice not applied")
 if approach=="lift" and (lift_carry_frames<hz/2 or lift_first_y-lift_min_y<100):failures.append("No100px observed real lift carry")
 if approach=="stairs" and stair_distance<300:failures.append("Stair route lacks300px elevated traversal")
 if not bridge_crossed:failures.append("No actual open return bridge crossing")
 if recovery and not recovered_floor:failures.append("No actual floor recovery fall")
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
 report.merge({"exchange_approach":approach,"activation_order":activation_order,"lift_carry_frames":lift_carry_frames,"lift_carry_height":lift_first_y-lift_min_y if lift_carry_frames>0 else 0,"stair_distance":stair_distance,"opened_bridge_crossed":bridge_crossed,"recovery":recovery,"recovered_floor":recovered_floor,"failures":failures,"passed":failures.is_empty()},true)
 var dest="res://demo/evidence/exchange_%s_%s_%dhz%s.json"%[approach,"traded" if sacrifice else "retained",hz,"_recovery" if recovery else ""]
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("EXCHANGE RESULT ",dest," failures=",failures)
 quit(0 if failures.is_empty() else 1)
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if host.sector==2 and approach=="stairs" and choice_done and not host.relay_states.has(1):
  target=host._relay_points()[1]
 if host.sector==2 and host.relay_states.size()==2 and not bridge_crossed:
  if reached_supported_waypoint(Vector2(2150,175),25):bridge_staged=true
  target=Vector2(2310,175) if bridge_staged else Vector2(2150,175)
 if host.sector==2 and host.relay_states.has(0) and not host.relay_states.has(1):
  if approach=="lift" and lift_stage==0:
   target=Vector2(1540,300)
  elif approach=="stairs" and stair_distance<300 and not host.relay_states.has(1):
   target=Vector2(1540,80)
  if recovery and recovery_phase==1:target=Vector2(1620,300)
 return super.navigate(target,d)
func decide()->Dictionary:
 var p=host.player
 var pos:Vector2=p.position
 if host.sector==2:activation_order=host.relay_states.duplicate()
 if observed:
  if pos.y<200 and last_observed.y<200 and pos.x>850 and pos.x<1690:stair_distance+=absf(pos.x-last_observed.x)
  if last_observed.x<2235 and pos.x>=2235 and pos.y>100 and pos.y<190 and host.room.shutters[1].is_open:
   bridge_crossed=true
   events.append({"event":"actual_open_bridge_crossing","position":str(pos),"frame":frame})
 last_observed=pos;observed=true
 if recovery and recovery_phase==0 and pos.y<90 and pos.x>1460 and pos.x<1670:
  recovery_phase=1
  events.append({"event":"recovery_departure","position":str(pos),"frame":frame})
 if recovery_phase==1 and p.grounded and absf(pos.y-300)<4 and pos.x>1490:
  recovered_floor=true;recovery_phase=2;lift_stage=0
  events.append({"event":"actual_recovery_floor","position":str(pos),"frame":frame,"relays":host.relay_states.duplicate()})
 if recovery_phase==1:
  if p.grounded and pos.y<280:return {"down":1.0,"jump":not p._last_jump_held}
  return {"right":1.0} if pos.x<1620 else {}
 if approach=="lift" and host.relay_states.has(0) and not host.relay_states.has(1) and lift_stage<3:
  if lift_stage==0 and absf(pos.x-1540)<18 and pos.y>230:
   lift_stage=1
  if lift_stage==1 or lift_stage==2:
   nav_trace={"explicit_lift_boarding":true}
   if is_instance_valid(p._support) and p._support.get_script()==preload("res://demo/components/mission_lift.gd"):
    if lift_carry_frames==0:lift_first_y=pos.y
    lift_carry_frames+=1;lift_min_y=minf(lift_min_y,pos.y);lift_stage=2
   if lift_stage==2 and pos.y<85:
    lift_stage=3
    events.append({"event":"actual_lift_egress","position":str(pos),"frame":frame,"carry_frames":lift_carry_frames})
    return {"right":1.0}
   var raw:={}
   if absf(pos.x-1540)>5:raw["right" if pos.x<1540 else "left"]=1.0
   if lift_stage==1:raw.jump=(frame%int(hz*1.2))<int(hz*.32)
   return raw
 return super.decide()
