extends "res://simulation/tests/campaign_rules_rainline_contract.gd"
## Labelled interaction/position fixtures, not route or recovery proof.
func quiet(m):
 for e in m.enemies:e.process_mode=Node.PROCESS_MODE_DISABLED
func place(m,where:Vector2):
 m.player.reset_actor(where,1);await frames(2)
func contour_for(m,body:Node)->bool:
 m.sonar.refresh_geometry()
 for record in m.sonar.geometry:
  var shape=record.anchor.get_ref()
  if is_instance_valid(shape) and (shape==body or body.is_ancestor_of(shape)):return true
 return false
func run():
 label="Exchange isolated lifecycle"
 var m=load("res://demo/mission.tscn").instantiate();root.add_child(m);m.save_enabled=false;m.start_new(true);m.load_sector(2);quiet(m);m.input_override={};await frames(3)
 var d:Dictionary=m.sectors[2]
 check(d.relays.size()==2 and m.room.shutters.size()==2,"two authored relay/shutter pairs")
 for first in [0,1]:
  m.load_sector(2);quiet(m);await frames(3)
  await place(m,Vector2(d.width-45,d.gate_y));await key(KEY_E)
  check(m.sector==2 and not m.room.gate_open,"no-relay exit refused")
  await place(m,d.relays[first]);await key(KEY_E)
  check(m.relay_states==[first],"only selected relay activates")
  check(m.room.shutters[first].is_open and not m.room.shutters[1-first].is_open,"each relay opens only its own physical shutter")
  await place(m,Vector2(d.width-45,d.gate_y));await key(KEY_E)
  check(m.sector==2 and not m.room.gate_open,"either missing relay refuses onward exit")
  await place(m,d.relays[1-first]);await key(KEY_E)
  check(m.relay_on and m.room.gate_open,"both relay orders unlock onward gate")
  await key(KEY_R);await frames(2)
  check(m.relay_states.is_empty() and not m.room.shutters[0].is_open and not m.room.shutters[1].is_open,"retry resets both relay shutters")
  quiet(m)
 for traded in [false,true]:
  m.blind=false;m.load_sector(2);quiet(m);await frames(3)
  await place(m,d.station);await key(KEY_E)
  check(m.state=="choice","actual station E opens choice")
  await key(KEY_J if traded else KEY_K)
  check(m.blind==traded and m.state=="playing","actual choice key applies requested sight mode")
  if not m.caches.has(2):
   await place(m,d.cache);await key(KEY_E);check(m.state=="archive","actual cache E opens archive");await key(KEY_E)
  var speed:float=m.player.profile.run_speed
  var lift:Node
  for child in m.room.get_children():
   if child is AnimatableBody2D:lift=child;break
  m.room.shutters[0].hide();m.room.shutters[1].hide();lift.hide()
  check(contour_for(m,m.room.shutters[0]) and contour_for(m,m.room.shutters[1]),"real closed shutters contribute contours despite hidden drawing")
  check(contour_for(m,lift),"real moving lift contributes collision contour")
  await place(m,d.relays[1]);await key(KEY_E)
  check(not contour_for(m,m.room.shutters[1]),"opened noncolliding shutter no longer yields a sonar contour")
  await key(KEY_R);await frames(3);quiet(m)
  check(m.blind==traded and is_equal_approx(speed,m.player.profile.run_speed),"retry preserves sight choice and associated speed")
  check(m.caches.has(2) and m.room.cache_found,"retry preserves collected cache")
  check(m.relay_states.is_empty() and not m.room.gate_open,"retry does not preserve unlocked gate")
 m.queue_free();await frames(3)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Explicit initial position/state fixture with real E/J/K/R input. Enemies disabled to isolate interfaces. Gate checks cover either missing relay, not route reachability; contours are actual shape provenance, not visual readability. Sight/cache persistence checked. Upper-first traversal and real right-fall return owned by route worker."}
 FileAccess.open("res://simulation/evidence/campaign_rules_exchange_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("EXCHANGE RULES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
