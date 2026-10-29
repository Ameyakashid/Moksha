extends "res://demo/tests/warden_order_route_bot.gd"
## Real raw-input fall and re-entry checks after the actual three defeats.
var recovery_stage:=0
var recovered:Array=[]
func _initialize():
 super._initialize()
 approach="recovery"
func run():
 source_hashes["res://demo/tests/warden_loop_recovery_bot.gd"]=FileAccess.get_sha256("res://demo/tests/warden_loop_recovery_bot.gd")
 await super.run()
 if recovery_stage<6:failures.append("Both real falls and loop reentries were not completed")
 var original="res://demo/evidence/warden_order_recovery_%s_%dhz.json"%["traded" if sacrifice else "retained",hz]
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original))
 r.merge({"recovery_stage":recovery_stage,"recovery_receipts":recovered,"failures":failures,"passed":failures.is_empty()},true)
 var dest="res://demo/evidence/warden_loop_recovery_%dhz.json"%hz
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(r,"  ")+"\n")
 print("WARDEN LOOP RECOVERY ",dest," failures=",failures)
 quit(0 if failures.is_empty() else 1)
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if host.remaining_enemies()>0 or recovery_stage>=6:return super.navigate(target,d)
 var points:Array=[Vector2(970,135),Vector2(970,300),Vector2(970,135),Vector2(1350,190),Vector2(1350,300),Vector2(1350,190)]
 target=points[recovery_stage]
 if host.player.grounded and host.player.position.distance_to(target)<24:
  recovered.append({"stage":recovery_stage,"position":str(host.player.position),"frame":frame,"grounded":host.player.grounded})
  if recovery_stage==3 or recovery_stage==5:right_loop_reached=true
  recovery_stage+=1
  if recovery_stage>=6:return super.navigate(Vector2(1655,300),d)
  target=points[recovery_stage]
 return physical_navigate(target,d)
func physical_navigate(target: Vector2,d: Dictionary) -> Dictionary:
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
