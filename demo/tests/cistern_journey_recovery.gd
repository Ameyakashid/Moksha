extends "res://demo/tests/cistern_journey_route.gd"
## Real post-dock/channel falls and fixed-route recovery; no pose setup during play.
var recovery_case:="lower_dock"
var fall_started:=false
var floor_seen:=false
var return_seen:=false
var return_point:=Vector2.ZERO
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--recovery="):recovery_case=arg.trim_prefix("--recovery=")
 super._initialize()
func decide()->Dictionary:
 var p=host.player
 var pos:Vector2=p.position
 if floor_seen and return_seen and lift_mode==2 and lift_index==1 and is_instance_valid(p._support) and p._support.get_script()==preload("res://demo/components/mission_lift.gd") and absf(pos.x-p._support.position.x)>6:
  return {"right":1.0} if pos.x<p._support.position.x else {"left":1.0}
 if floor_seen and return_seen and lift_mode==1:
  var low_y:=300.0 if lift_index==0 else 50.0
  if pos.y>low_y+75:
   events.append({"event":"missed_reboarding_return_to_fixed_departure","lift":lift_index,"position":str(pos),"frame":frame,"test_navigation_only":true})
   lift_mode=0;route_step=0 if lift_index==0 else 2
 if not fall_started:
  if recovery_case=="missed_boarding" and reached_supported_waypoint(Vector2(920,280),24):
   var lift:Node2D=null
   for child in host.room.get_children():
    if child.get_script()==preload("res://demo/components/mission_lift.gd") and child.origin==Vector2(1000,300):lift=child
   if lift!=null and lift.position.y<170:
    fall_started=true;return_point=Vector2(900,135)
    events.append({"event":"explicit_late_phase_missed_boarding_fixture","position":str(pos),"lift_position":str(lift.position),"frame":frame,"note":"Test holds at real dock until lift is absent; not a game waiting gate"})
   return {"right":1.0} if fall_started else {}
  var trigger:bool=(docked[0] and lift_mode==0) if recovery_case=="lower_dock" else ((docked[1] and lift_mode==0) if recovery_case=="upper_dock" else (host.caches.has(4) if recovery_case=="channel" else false))
  if trigger:
   fall_started=true
   return_point=Vector2(900,135) if recovery_case=="lower_dock" else (Vector2(1800,0) if recovery_case=="upper_dock" else Vector2(2800,-260))
   events.append({"event":"recovery_real_fall_departure","case":recovery_case,"position":str(pos),"frame":frame})
 if fall_started and not floor_seen:
  if p.grounded and absf(pos.y-300)<3:
   floor_seen=true
   events.append({"event":"recovery_actual_floor_contact","case":recovery_case,"position":str(pos),"frame":frame})
   return {}
  if recovery_case=="missed_boarding":return {"right":1.0}
  if p.grounded and p._support is RigidBody2D:return {"left":1.0}
  var raw:={"down":1.0}
  if recovery_case=="upper_dock" and absf(pos.x-1600)>8:raw["left" if pos.x>1600 else "right"]=1.0
  if p.grounded:raw.jump=not p._last_jump_held
  elif pos.y>190 and p.velocity.y>300:raw.roll=true
  return raw
 if floor_seen and not return_seen and reached_supported_waypoint(return_point,24):
  return_seen=true
  events.append({"event":"recovery_actual_fixed_reentry","case":recovery_case,"position":str(pos),"frame":frame})
 return super.decide()
func run()->void:
 source_hashes["res://demo/tests/cistern_journey_recovery.gd"]=FileAccess.get_sha256("res://demo/tests/cistern_journey_recovery.gd")
 await super.run()
 if not fall_started or not floor_seen or not return_seen:failures.append("Missing actual departure/floor/fixed reentry")
 var base="res://demo/evidence/cistern_%s_%s_%dhz.json"%[approach,"traded" if sacrifice else "retained",hz]
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base))
 report.merge({"recovery_case":recovery_case,"actual_fall_departure":fall_started,"actual_floor_contact":floor_seen,"actual_fixed_reentry":return_seen,"passed":failures.is_empty(),"failures":failures},true)
 var dest="res://demo/evidence/cistern_recovery_%s_%s_%dhz.json"%[recovery_case,"traded" if sacrifice else "retained",hz]
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("CISTERN RECOVERY ",dest," failures=",failures)
 quit(0 if failures.is_empty() else 1)

func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if floor_seen and not return_seen:return fixed_recovery_navigation(return_point,d)
 return super.navigate(target,d)

func fixed_recovery_navigation(target:Vector2,d:Dictionary)->Dictionary:
 target=project_supported_waypoint(target)
 var p=host.player
 var pos: Vector2=p.position
 if p.grounded: support=closest_surface(pos)
 var goal:=closest_surface(target)
 var result:={"target":target,"jump":false,"up":false,"drop":false}
 if support==goal:
  if target.y>pos.y+35 and absf(target.x-pos.x)<40: result.target.x+=60
  nav_trace={"support":support,"goal_surface":goal,"next":goal}
  return result
 var queue: Array[int]=[support]
 var previous:={support:-1}
 var used:={}
 while not queue.is_empty():
  var here: int=queue.pop_front()
  if here==goal: break
  for edge in links[here]:
   var next: int=edge.to
   if previous.has(next): continue
   previous[next]=here
   used[next]=edge
   queue.append(next)
 if not previous.has(goal):
  nav_trace={"support":support,"goal_surface":goal,"unreachable":true}
  result.jump=target.y<pos.y-30 and absf(target.x-pos.x)<170
  return result
 var next:=goal
 while previous[next]!=support and previous[next]!=-1: next=previous[next]
 var edge: Dictionary=used[next]
 var destination: Rect2=platforms[next]
 var from: Rect2=platforms[support]
 var direction:=1.0 if (target.x if next==goal else destination.get_center().x)>pos.x else -1.0
 if destination.position.y>from.position.y+5 and destination.position.x<=from.end.x and destination.end.x>=from.position.x:
  direction=1.0 if target.x>pos.x else -1.0
 var inset:=minf(28,destination.size.x*0.35)
 var landing:=clampf(pos.x,destination.position.x+inset,destination.end.x-inset)
 if edge.ladder:
  result.target=Vector2(edge.x,destination.position.y)
  result.up=true
 else:
  result.target=Vector2(landing,destination.position.y)
  var rise:=from.position.y-destination.position.y
  if rise < -35 and from.size.y<=18 and not freight_solids.has(from) and pos.x>destination.position.x+12 and pos.x<destination.end.x-12:
   result.drop=true
  var boundary:=from.end.x if direction>0 else from.position.x
  var start_distance:=40.0 if rise<=0 else 60.0
  var horizontal_gap:=maxf(0,maxf(destination.position.x-from.end.x,from.position.x-destination.end.x))
  # For an overlapping target jump below its edge; for a separated landing,
  # walk to the departure lip before consuming the first jump.
  if horizontal_gap<1:
   result.jump=rise>10 and absf(landing-pos.x)<90
  else:
   result.jump=(boundary-pos.x)*direction<start_distance
   if not result.jump: result.target.x=boundary-direction*15
  if rise< -5 and absf(result.target.x-pos.x)<12:
   result.target.x=(from.end.x+25) if direction>0 else (from.position.x-25)
 nav_trace={"support":support,"goal_surface":goal,"next":next,"ladder":bool(edge.ladder)}
 return result
