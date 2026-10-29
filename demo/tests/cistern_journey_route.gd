extends "res://demo/tests/expanded_mission_route_bot.gd"
## Layout-aware raw-input diagnostic. Sight is configured before sector clock.
var route_points:Array[Vector2]=[]
var route_step:=0
var lift_index:=0
var lift_mode:=0
var carries:=[{"frames":0,"dx":0.0,"dy":0.0},{"frames":0,"dx":0.0,"dy":0.0}]
var carry_origin:=Vector2.ZERO
var egress_frame:=0
var docked:=[false,false]
var last_egress_support:=""
var intervening_support:=[false,false]
var bridge_crossed:=false
var previous_position:=Vector2.ZERO
func _initialize()->void:
 probe_sector=4
 max_sector_seconds=150
 super._initialize()
func begin_sector()->void:
 super.begin_sector()
 route_step=0;lift_index=0;lift_mode=0
 if approach.begins_with("fixed"):
  route_points=[Vector2(620,190),Vector2(1100,80),Vector2(1850,0),Vector2(2270,-120),Vector2(1870,-240),Vector2(1880,-320)]
 else:
  route_points=[Vector2(920,280),Vector2(1300,145),Vector2(1450,30),Vector2(1680,-245),Vector2(1880,-320)]
 route_points.append(Vector2(2280,-320))
 if approach.ends_with("channel"):
  route_points.append_array([Vector2(2510,-200),Vector2(3000,-320),Vector2(3280,-610)])
 else:
  route_points.append_array([Vector2(2500,-430),Vector2(2780,-490),Vector2(3270,-610)])
 route_points.append(Vector2(3520,-760))
 previous_position=host.player.position
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if route_step<route_points.size():target=route_points[route_step]
 return super.navigate(target,d)
func decide()->Dictionary:
 var p=host.player
 var pos:Vector2=p.position
 if previous_position.x<2140 and pos.x>=2140 and absf(pos.y+320)<45 and host.room.shutters[0].is_open:
  bridge_crossed=true
  events.append({"event":"actual_open_flood_bridge_crossing","position":str(pos),"frame":frame})
 previous_position=pos
 if route_step<route_points.size() and reached_supported_waypoint(route_points[route_step],24):
  events.append({"event":"cistern_route_waypoint","index":route_step,"position":str(pos),"frame":frame,"support":str(p._support.get_path()) if is_instance_valid(p._support) else "none"})
  if approach.begins_with("lift") and route_step in [0,2]:lift_mode=1;lift_index=0 if route_step==0 else 1
  route_step+=1
 if lift_mode>0:
  var origin:=Vector2(1000,300) if lift_index==0 else Vector2(1570,50)
  var live_lift:Node2D=null
  for child in host.room.get_children():
   if child.get_script()==preload("res://demo/components/mission_lift.gd") and child.origin==origin:live_lift=child
  if live_lift==null:
   failures.append("Missing authored lift")
   return {}
  if lift_mode==3:
   var dock:=Vector2(1300,145) if lift_index==0 else Vector2(1680,-245)
   var support_path:=str(p._support.get_path()) if is_instance_valid(p._support) else "air"
   if support_path!=last_egress_support:
    events.append({"event":"lift_egress_support_transition","lift":lift_index,"support":support_path,"position":str(pos),"grounded":p.grounded,"frame":frame})
    last_egress_support=support_path
   var expected_center:=Vector2(1340,154) if lift_index==0 else Vector2(1720,-236)
   var exact_dock:bool=p._support is StaticBody2D and p._support.get_script()==preload("res://simulation/world/static_platform.gd") and p._support.global_position.is_equal_approx(expected_center) and p._support.platform_size==Vector2(160,18)
   if p.grounded and exact_dock and absf(pos.y-dock.y)<3:
    docked[lift_index]=true;lift_mode=0
    events.append({"event":"actual_stationary_dock_after_lift","lift":lift_index,"position":str(pos),"support":str(p._support.get_path()),"frame":frame})
    return {}
   if p.grounded and is_instance_valid(p._support) and p._support!=live_lift and not exact_dock:
    intervening_support[lift_index]=true
    failures.append("Lift%d intervening non-dock support during egress"%lift_index)
    lift_mode=0
    return {}
   if frame-egress_frame>hz*3:
    failures.append("Lift%d departure missed stationary dock"%lift_index);lift_mode=0
    return {}
   var out:={}
   if absf(pos.x-dock.x)>8:out["right" if pos.x<dock.x else "left"]=1.0
   if not p.grounded and p.velocity.y>0 and pos.y>dock.y+25 and p.air_jumps_left>0:out.jump=not p._last_jump_held
   return out
  if p._support==live_lift:
   if carries[lift_index].frames==0:carry_origin=pos
   carries[lift_index].frames+=1
   carries[lift_index].dx=maxf(carries[lift_index].dx,absf(pos.x-carry_origin.x))
   carries[lift_index].dy=maxf(carries[lift_index].dy,carry_origin.y-pos.y)
   lift_mode=2
  var threshold:=140.0 if lift_index==0 else -250.0
  if lift_mode==2 and pos.y<threshold and carries[lift_index].dy>(70 if lift_index==0 else 150):
   events.append({"event":"actual_lift_departure_input","lift":lift_index,"position":str(pos),"carry":carries[lift_index].duplicate(),"frame":frame})
   lift_mode=3;egress_frame=frame;last_egress_support=""
   return {"right":1.0}
  if lift_mode==2:
   if p._support==live_lift:return {}
   return {"right":1.0} if pos.x<live_lift.position.x else {"left":1.0}
  var raw:={}
  if absf(pos.x-live_lift.position.x)>7:raw["right" if pos.x<live_lift.position.x else "left"]=1.0
  raw.jump=(frame%int(hz*1.2))<int(hz*.32)
  return raw
 return super.decide()
func run()->void:
 source_hashes["res://demo/tests/cistern_journey_route.gd"]=FileAccess.get_sha256("res://demo/tests/cistern_journey_route.gd")
 await super.run()
 if str(host.sectors[host.sector].id)!="upper_residential_crossing":failures.append("No actual onward transition to Upper Residential Crossing")
 if route_step<route_points.size()-1:failures.append("Required route not traversed")
 if not bridge_crossed:failures.append("Open flood bridge not crossed")
 if approach.begins_with("lift"):
  for i in 2:
   if not docked[i]:failures.append("Lift%d no direct stationary docking receipt"%i)
   if carries[i].frames<hz/2 or carries[i].dy<(70 if i==0 else 150):failures.append("Lift%d lacks actual support/carry proof"%i)
  if carries[0].dx<70:failures.append("Diagonal lift lacks actual horizontal carriage")
 if host.blind!=sacrifice:failures.append("Sight fixture mismatch")
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
 report.merge({"approach":approach,"route_waypoints_reached":route_step,"route_waypoints_total":route_points.size(),"actual_lift_carries":carries,"direct_stationary_docks":docked,"intervening_non_dock_support":intervening_support,"open_bridge_crossed":bridge_crossed,"onward_transition":str(host.sectors[host.sector].id)=="upper_residential_crossing","sight_fixture":"Pre-clock traded sight; no station interaction" if sacrifice else "Retained sight; no trade","passed":failures.is_empty(),"failures":failures},true)
 var dest="res://demo/evidence/cistern_%s_%s_%dhz.json"%[approach,"traded" if sacrifice else "retained",hz]
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("CISTERN RESULT ",dest," failures=",failures)
 quit(0 if failures.is_empty() else 1)
