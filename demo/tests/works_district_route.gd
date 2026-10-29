extends "res://demo/tests/expanded_mission_route_bot.gd"
## Actual raw inputs and real station/relay interactions; layout-aware, not human QA.
var order_code:="012"
var route_points:Array[Vector2]=[]
var route_step:=0
var boarding_waypoint:=-1
var lift_mode:=0
var carry_frames:=0
var carry_origin:=Vector2.ZERO
var carry_dy:=0.0
var docked:=false
var intervening_support:=false
var egress_frame:=0
var actual_order:Array=[]
var previous_position:=Vector2.ZERO
var bridge_crossed:=false
var recoveries:=false
var recovery_receipts:Array=[]
var recovery_points:Dictionary={}
var cargo_obstruction_jump_receipts:Array=[]
func _initialize()->void:
 DirAccess.make_dir_recursive_absolute("res://demo/evidence")
 probe_sector=6
 max_sector_seconds=240
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--order="):order_code=arg.trim_prefix("--order=")
  if arg=="--recoveries":recoveries=true
 super._initialize()
func begin_sector()->void:
 super.begin_sector()
 route_step=0
 if recoveries:
  for point in [Vector2(5630,80),Vector2(6000,80),Vector2(6000,300),Vector2(6000,80),Vector2(5630,80),Vector2(5630,300)]:
   recovery_points[route_points.size()]="closed_dispatch_right_floor_return"
   route_points.append(point)
  for point in [Vector2(4220,-240),Vector2(3920,-240),Vector2(3920,300),Vector2(4220,-240),Vector2(3520,300),Vector2(3520,-240),Vector2(3620,300),Vector2(3520,-240),Vector2(2200,300)]:
   recovery_points[route_points.size()]="closed_connector"
   route_points.append(point)
 for n in order_code.length():
  var branch:=int(order_code.substr(n,1))
  if branch==0:
   route_points.append_array([Vector2(1900,245),Vector2(1780,190),Vector2(1660,135),Vector2(1500,80)])
   if recoveries:
    for point in [Vector2(1600,300),Vector2(1900,245),Vector2(1780,190),Vector2(1660,135),Vector2(1500,80)]:
     recovery_points[route_points.size()]="closed_service_right_fall_return"
     route_points.append(point)
   route_points.append_array([Vector2(1200,80),Vector2(950,80),Vector2(650,80),Vector2(450,300),Vector2(980,190),Vector2(1250,300),Vector2(1700,300),Vector2(2200,300)])
  elif branch==1:
   if approach=="lift":
    boarding_waypoint=route_points.size()
    route_points.append(Vector2(2900,240))
   else:route_points.append_array([Vector2(2600,80),Vector2(2700,-140),Vector2(2890,-195),Vector2(2980,-250)])
   route_points.append_array([Vector2(3150,-155),Vector2(3200,-430),Vector2(3440,-430)])
   if n==order_code.length()-1 or order_code.substr(n+1,1)=="2":route_points.append_array([Vector2(3550,-240),Vector2(3920,-240),Vector2(4220,-240)])
   else:route_points.append_array([Vector2(3520,300),Vector2(2200,300)])
  else:
   if n>0 and order_code.substr(n-1,1)=="1":route_points.append_array([Vector2(4520,-295),Vector2(4890,-240),Vector2(5250,-240),Vector2(5520,-240)])
   else:route_points.append_array([Vector2(4320,135),Vector2(4700,135),Vector2(5050,80),Vector2(5220,80),Vector2(5520,300),Vector2(5520,-240)])
   if n<order_code.length()-1:route_points.append_array([Vector2(5630,300),Vector2(2200,300)])
 route_points.append(Vector2(6200,300))
 previous_position=host.player.position
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if route_step<route_points.size():target=route_points[route_step]
 if host.player.main_action==&"climb" and target.y<host.player.position.y-5:
  return {"target":Vector2(host.player.position.x,target.y),"up":true,"jump":false,"drop":false}
 return super.navigate(target,d)
func decide()->Dictionary:
 var p=host.player
 var pos:Vector2=p.position
 if host.relay_states.size()>actual_order.size():
  actual_order=host.relay_states.duplicate()
  events.append({"event":"actual_circuit_activation_order","order":actual_order.duplicate(),"frame":frame,"position":str(pos)})
 if previous_position.x<3800 and pos.x>=3800 and p.grounded and absf(pos.y+240)<3 and host.room.shutters[1].is_open:
  bridge_crossed=true
  events.append({"event":"actual_open_lift_dispatch_connection","frame":frame,"position":str(pos),"support":str(p._support.get_path())})
 previous_position=pos
 if route_step<route_points.size() and reached_supported_waypoint(route_points[route_step],18):
  var receipt:={"event":"works_supported_waypoint","index":route_step,"target":str(route_points[route_step]),"position":str(pos),"frame":frame,"support":str(p._support.get_path()) if is_instance_valid(p._support) else "none"}
  events.append(receipt)
  if recovery_points.has(route_step):
   receipt=receipt.duplicate();receipt.recovery=recovery_points[route_step];receipt.active_relays=host.relay_states.duplicate()
   receipt.shutters_physically_closed=host.room.shutters.map(func(shutter):return not shutter.is_open and not shutter.collision_shape.disabled and (shutter.collision_layer&1)!=0)
   if receipt.shutters_physically_closed.has(false):failures.append("Recovery shutter not physically closed")
   if route_points[route_step].y==300:
    receipt.exact_floor_support=p.grounded and p._support is StaticBody2D and str(p._support.get_path()).ends_with("/FloorSegment/Support") and absf(pos.y-300)<1
    if not receipt.exact_floor_support:failures.append("Recovery floor target did not land on actual FloorSegment support")
   recovery_receipts.append(receipt)
   if not host.relay_states.is_empty():failures.append("Recovery occurred after a circuit opened")
  if route_step==boarding_waypoint:lift_mode=1
  route_step+=1
 if lift_mode>0:return lift_inputs()
 return final_egress_obstruction_input(super.decide())
func final_egress_obstruction_input(raw:Dictionary)->Dictionary:
 # Test navigation only, after every branch: select a normal jump on actual cargo contact.
 var p=host.player
 if route_step!=route_points.size()-1 or host.relay_states.size()!=3 or lift_mode>0 or not p.grounded or raw.has("attack") or raw.has("shield"):return raw
 var direction:=float(raw.get("right",0))-float(raw.get("left",0))
 if direction==0:return raw
 var hit:=KinematicCollision2D.new()
 if p.test_move(p.global_transform,Vector2(direction*12,0),hit,p.profile.collision_margin) and hit.get_collider() is RigidBody2D and absf(hit.get_normal().x)>.5:
  raw.jump=not p._last_jump_held
  if raw.jump:
   var receipt:={"event":"actual_movable_obstruction_jump_input","frame":frame,"position":str(p.position),"collider":str(hit.get_collider().get_path()),"collider_script":str(hit.get_collider().get_script().resource_path),"normal":str(hit.get_normal()),"direction":direction}
   cargo_obstruction_jump_receipts.append(receipt);events.append(receipt)
 return raw
func lift_inputs()->Dictionary:
 var p=host.player
 var pos:Vector2=p.position
 var lift:Node2D=null
 for child in host.room.get_children():
  if child.get_script()==preload("res://demo/components/mission_lift.gd"):lift=child
 if lift==null:failures.append("Missing optional lift");return {}
 if lift_mode==3:
  var exact_dock:bool=p._support is StaticBody2D and p._support.get_script()==preload("res://simulation/world/static_platform.gd") and p._support.global_position.is_equal_approx(Vector2(3170,-146)) and p._support.platform_size==Vector2(200,18)
  if p.grounded and exact_dock and absf(pos.y+155)<3:
   docked=true;lift_mode=0
   events.append({"event":"actual_direct_stationary_dock","frame":frame,"position":str(pos),"support":str(p._support.get_path())})
   return {}
  if p.grounded and is_instance_valid(p._support) and p._support!=lift and not exact_dock:
   events.append({"event":"intervening_lift_egress_support","frame":frame,"position":str(pos),"support":str(p._support.get_path()),"support_script":str(p._support.get_script().resource_path),"support_position":str(p._support.global_position)})
   intervening_support=true;failures.append("Intervening non-dock support during lift egress");lift_mode=0;return {}
  if frame-egress_frame>hz*3:failures.append("Lift egress missed side dock");lift_mode=0;return {}
  return {"right":1.0} if pos.x<3150 else {"left":1.0}
 if p._support==lift:
  if carry_frames==0:carry_origin=pos
  carry_frames+=1
  carry_dy=maxf(carry_dy,carry_origin.y-pos.y)
  lift_mode=2
 if lift_mode==2 and pos.y< -162 and carry_dy>300:
  lift_mode=3;egress_frame=frame
  events.append({"event":"actual_lift_egress_input","position":str(pos),"carry_frames":carry_frames,"carry_dy":carry_dy,"frame":frame})
  return {"right":1.0}
 if lift_mode==2:
  if p._support==lift:return {}
  return {"right":1.0} if pos.x<lift.position.x else {"left":1.0}
 var raw:={}
 if absf(pos.x-lift.position.x)>7:raw["right" if pos.x<lift.position.x else "left"]=1.0
 raw.jump=(frame%int(hz*1.2))<int(hz*.32)
 return raw
func run()->void:
 source_hashes["res://demo/tests/works_district_route.gd"]=FileAccess.get_sha256("res://demo/tests/works_district_route.gd")
 await super.run()
 var expected:Array=[]
 for c in order_code:expected.append(int(c))
 if actual_order!=expected:failures.append("Actual circuit activation order differs from requested")
 if str(host.sectors[host.sector].id)!="lift_warden":failures.append("No actual onward Warden transition")
 if route_step<route_points.size()-1:failures.append("Required branch waypoints not traversed")
 if approach=="lift" and (not docked or intervening_support or carry_frames<hz/2 or carry_dy<300):failures.append("Optional lift lacks actual carry/direct stationary docking proof")
 if order_code.contains("12") and not bridge_crossed:failures.append("Lift-to-Dispatch connection not physically traversed")
 if recoveries and recovery_receipts.size()!=20:failures.append("Closed-shutter fall-return receipts incomplete")
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
 report.merge({"requested_order":order_code,"actual_order":actual_order,"approach":approach,"route_waypoints_reached":route_step,"route_waypoints_total":route_points.size(),"carry_frames":carry_frames,"carry_dy":carry_dy,"direct_stationary_dock":docked,"intervening_non_dock_support":intervening_support,"lift_dispatch_connection":bridge_crossed,"recovery_receipts":recovery_receipts,"cargo_obstruction_jump_receipts":cargo_obstruction_jump_receipts,"sight_method":"Actual choice at existing hub station after sector-start fixture","passed":failures.is_empty(),"failures":failures},true)
 var path="res://demo/evidence/works_%s_%s_%s_%dhz%s.json"%[order_code,approach,"traded" if sacrifice else "retained",hz,"_recovery" if recoveries else ""]
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("WORKS DISTRICTS ",path," failures=",failures)
 quit(0 if failures.is_empty() else 1)
