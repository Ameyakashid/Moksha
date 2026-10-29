extends "res://simulation/tests/campaign_rules_placement.gd"
## Labelled initial placements isolate interfaces, not a full traversal proof.
const District=preload("res://demo/areas/rainline_neighbourhood.gd")
const Room=preload("res://demo/components/mission_room.gd")
func key(code:Key):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
 await frames(1)
 event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event)
 await frames(2)
func run():
 label="Rainline room assembly";world=Node2D.new();world.set_script(Room);root.add_child(world);world.build(District.sector());world.backdrop.hide()
 await frames(3)
 check(world.floor_rects.size()==1 and world.floor_rects[0].size.x==6200,"continuous 6200px ground assembled")
 for role in ["PC","NPC"]:
  for x in [3250,4200]:
   label="Rainline ladder / "+role+" / "+str(x)
   var a=actor(role,Vector2(x,300));await frames(4);move(a,role,Vector2.UP);await frames(int(hz*0.6))
   check(a.main_action==&"climb" and a.position.y<260,"actual deliberate ascent available on this shutter side")
   observations.append({"case":label,"position":str(a.position),"action":str(a.main_action)})
   a.queue_free();await frames(3)
  for side in [-1,1]:
   label="Rainline closed shutter / "+role+" / "+str(side)
   var a=actor(role,Vector2(3680+side*80,300));await frames(4);move(a,role,Vector2(-side,0));await frames(hz)
   check((a.position.x-3680)*side>20 and absf(a.position.x-3680)<45,"actual controller blocked on correct side of closed shutter")
   check(a.grounded,"street support remains available beside closed shutter")
   observations.append({"case":label,"position":str(a.position)})
   a.queue_free();await frames(3)
 await finish()
 label="Rainline production relay/retry input"
 var mission=load("res://demo/tests/rainline_review.tscn").instantiate();root.add_child(mission);await frames(3)
 # Disable opponents only for the short interaction isolation; no traversal claim.
 for enemy in mission.enemies:enemy.process_mode=Node.PROCESS_MODE_DISABLED
 mission.input_override={};mission.player.reset_actor(Vector2(3480,-280),1);await frames(3)
 check(not mission.room.shutters[0].is_open and mission.relay_states.is_empty(),"fresh sector begins physically sealed")
 await key(KEY_E)
 check(mission.relay_on and mission.relay_states==[0],"real E input activates authored relay")
 check(mission.room.shutters[0].is_open and mission.room.shutters[0].collision_shape.disabled,"relay opens actual collision shape")
 await key(KEY_R);await frames(3)
 check(mission.relay_states.is_empty() and not mission.relay_on,"real R retry clears relay state")
 check(not mission.room.shutters[0].is_open and not mission.room.shutters[0].collision_shape.disabled,"retry rebuilds closed physical shutter")
 check(mission.player.position.distance_to(Vector2(75,300))<5,"retry restores supported production spawn")
 mission.queue_free();await frames(3)
 var hashes={}
 for path in ["res://demo/areas/rainline_neighbourhood.gd","res://demo/components/mission_room.gd","res://demo/mission.gd","res://simulation/tests/campaign_rules_rainline_contract.gd"]:hashes[path]=FileAccess.get_sha256(path)
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"observations":observations,"source_hashes":hashes,"scope":"Labelled initial placement, production PC/NPC contact profiles with deliberate raw/intent fixtures; room art hidden, actual ladder climb and closed shutter contacts both sides. Mission E/R is real input; opponents disabled only during isolated interaction. Not full-route or autonomous-enemy proof."}
 FileAccess.open("res://simulation/evidence/campaign_rules_rainline_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RAINLINE CONTRACT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
