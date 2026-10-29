extends "res://demo/tests/exchange_route_bot.gd"
## Real upper departure -> right floor before calibration -> return; no teleports.
var right_phase:=0
var launch_frame:=0
var launch_position:=Vector2.ZERO
var right_floor:=false
var upper_staged:=false
var return_jump_frame:=-99999
var returned_under_closed:=false
func _initialize():
 approach="lift"
 super._initialize()
func run():
 source_hashes["res://demo/tests/exchange_right_recovery_bot.gd"]=FileAccess.get_sha256("res://demo/tests/exchange_right_recovery_bot.gd")
 await super.run()
 if not right_floor:failures.append("No right-side floor landing with calibration inactive")
 if not returned_under_closed:failures.append("No grounded return beneath closed calibration shutter")
 var original="res://demo/evidence/exchange_lift_%s_%dhz.json"%["traded" if sacrifice else "retained",hz]
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original))
 r.merge({"right_floor_landing":right_floor,"return_beneath_closed_shutter":returned_under_closed,"events":events,"failures":failures,"passed":failures.is_empty()},true)
 var dest="res://demo/evidence/exchange_right_recovery_%dhz.json"%hz
 FileAccess.open(dest,FileAccess.WRITE).store_string(JSON.stringify(r,"  ")+"\n")
 print("EXCHANGE RIGHT RECOVERY ",dest," failures=",failures)
 quit(0 if failures.is_empty() else 1)
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if lift_stage==3 and right_phase==0:
  target=Vector2(1800,20)
  if reached_supported_waypoint(target,25):
   right_phase=1;launch_frame=frame;launch_position=host.player.position
   events.append({"event":"actual_upper_recovery_departure","position":str(launch_position),"frame":frame,"active_relays":host.relay_states.duplicate()})
 return super.navigate(target,d)
func decide()->Dictionary:
 var p=host.player
 var pos:Vector2=p.position
 if right_phase==1:
  if p.grounded and absf(pos.y-300)<4 and pos.x>2260:
   right_phase=2;right_floor=not host.relay_states.has(1)
   events.append({"event":"actual_right_floor_landing_before_calibration","position":str(pos),"frame":frame,"active_relays":host.relay_states.duplicate(),"shutter_open":host.room.shutters[1].is_open})
  else:
   if not upper_staged and p.grounded and pos.x>2035 and pos.y<0:
    upper_staged=true;launch_frame=frame
    events.append({"event":"actual_calibration_shelf_departure_without_activation","position":str(pos),"frame":frame})
   var t:=float(frame-launch_frame)/hz
   var raw:={}
   if pos.x<(2350 if upper_staged else 2070):raw.right=1.0
   if t<.28 or (t>.34 and t<.62):raw.jump=true
   if pos.x>2290 and p.grounded:raw={"down":1.0,"jump":not p._last_jump_held}
   return raw
 if right_phase==2 and pos.x<2200 and pos.y>230 and not host.room.shutters[1].is_open:
  returned_under_closed=true;right_phase=3
  events.append({"event":"actual_return_beneath_closed_bridge","position":str(pos),"frame":frame})
 if right_phase==2:
  if p.grounded and pos.y>280 and pos.x<2255 and not p._last_jump_held:return_jump_frame=frame
  return {"left":1.0,"jump":frame-return_jump_frame<int(hz*.3)}
 return super.decide()
