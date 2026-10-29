extends "res://demo/tests/expanded_mission_route_bot.gd"
## Layout-aware raw-input traversal, not human usability or campaign timing proof.
var route_points:Array[Vector2]=[]
var route_step:=0
var thresholds:Array[Rect2]=[Rect2(1100,190,160,110),Rect2(2280,135,170,165),Rect2(3640,120,150,180)]
var threshold_receipts:=[{"frames":0,"min_x":INF,"max_x":-INF},{"frames":0,"min_x":INF,"max_x":-INF},{"frames":0,"min_x":INF,"max_x":-INF}]
var elevated_distance:=0.0
var last_position:=Vector2.ZERO
var fall_return:=false
var actual_fall_floor:=false
var actual_ladder_return:=false
func _initialize()->void:
 probe_sector=5
 max_sector_seconds=150
 for arg in OS.get_cmdline_user_args():
  if arg=="--fall-return":fall_return=true
 super._initialize()
func begin_sector()->void:
 super.begin_sector()
 route_step=0
 if approach=="street":
  route_points=[Vector2(840,300),Vector2(1130,190),Vector2(1230,190),Vector2(1480,300),Vector2(2040,300),Vector2(2310,135),Vector2(2420,135),Vector2(2940,300),Vector2(3290,300),Vector2(3670,120),Vector2(3760,120),Vector2(4140,300),Vector2(5050,-85)]
 elif approach=="mixed":
  route_points=[Vector2(840,300),Vector2(1130,190),Vector2(1230,190),Vector2(1480,300),Vector2(2040,300),Vector2(2310,135),Vector2(2420,135),Vector2(2940,300),Vector2(2730,25),Vector2(3470,-30),Vector2(4000,-85),Vector2(4500,-30),Vector2(4990,-85)]
 else:
  route_points=[Vector2(200,245),Vector2(290,190),Vector2(600,135),Vector2(850,80),Vector2(1120,25),Vector2(1700,-30)]
  if fall_return:route_points.append_array([Vector2(1700,300),Vector2(1300,25),Vector2(1700,-30)])
  route_points.append_array([Vector2(2350,-30),Vector2(2870,25),Vector2(3470,-30),Vector2(4000,-85),Vector2(4500,-30),Vector2(4990,-85)])
 last_position=host.player.position
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if route_step<route_points.size():target=route_points[route_step]
 return super.navigate(target,d)
func decide()->Dictionary:
 var p=host.player
 var pos:Vector2=p.position
 if pos.y<120 and last_position.y<120 and pos.x<4800:elevated_distance+=absf(pos.x-last_position.x)
 last_position=pos
 if p.grounded and p._support is StaticBody2D and p._support.get_script()==preload("res://simulation/world/static_platform.gd"):
  for i in thresholds.size():
   if p._support.global_position.is_equal_approx(thresholds[i].get_center()) and p._support.platform_size==thresholds[i].size:
    threshold_receipts[i].frames+=1
    threshold_receipts[i].min_x=minf(threshold_receipts[i].min_x,pos.x)
    threshold_receipts[i].max_x=maxf(threshold_receipts[i].max_x,pos.x)
 if route_step<route_points.size() and reached_supported_waypoint(route_points[route_step],18):
  events.append({"event":"residential_supported_waypoint","index":route_step,"target":str(route_points[route_step]),"position":str(pos),"support":str(p._support.get_path()) if is_instance_valid(p._support) else "none","frame":frame})
  if fall_return and route_step==6:actual_fall_floor=true
  if fall_return and route_step==7:actual_ladder_return=true
  route_step+=1
 return super.decide()
func run()->void:
 source_hashes["res://demo/tests/residential_crossing_route.gd"]=FileAccess.get_sha256("res://demo/tests/residential_crossing_route.gd")
 await super.run()
 if host.sector!=6:failures.append("No actual onward transition into Relay Works")
 if route_step<route_points.size()-1:failures.append("Required route not traversed")
 var required:=3 if approach=="street" else (2 if approach=="mixed" else 0)
 for i in required:
  if threshold_receipts[i].frames<hz/10 or threshold_receipts[i].max_x-threshold_receipts[i].min_x<60:failures.append("Threshold%d lacks sustained actual support crossing"%i)
 if approach=="roof" and elevated_distance<2500:failures.append("Roof route lacks sustained elevated traversal")
 if approach=="street" and elevated_distance>1000:failures.append("Street observer substituted roof route")
 if approach=="mixed" and elevated_distance<1200:failures.append("Mixed route lacks upper continuation")
 if fall_return and (not actual_fall_floor or not actual_ladder_return):failures.append("No actual fall and fixed crosslink return")
 if host.blind!=sacrifice:failures.append("Sight fixture mismatch")
 for receipt in threshold_receipts:
  if receipt.frames==0:
   receipt.min_x=null
   receipt.max_x=null
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
 report.merge({"approach":approach,"supported_thresholds":threshold_receipts,"elevated_distance":elevated_distance,"route_waypoints_reached":route_step,"route_waypoints_total":route_points.size(),"fall_return":fall_return,"actual_fall_floor":actual_fall_floor,"actual_fixed_crosslink_return":actual_ladder_return,"onward_transition":host.sector==6,"sight_fixture":"Pre-clock traded sight; not actual Exchange interaction" if sacrifice else "Retained sight","passed":failures.is_empty(),"failures":failures},true)
 var dest="res://demo/evidence/residential_%s_%s_%dhz%s.json"%[approach,"traded" if sacrifice else "retained",hz,"_fall_return" if fall_return else ""]
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("RESIDENTIAL RESULT ",dest," failures=",failures)
 quit(0 if failures.is_empty() else 1)
