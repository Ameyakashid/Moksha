extends "res://simulation/tests/projectile_regression.gd"
var retirements:Array=[]
func setup(at:float,foot:float):
 shots=[];contacts=[];carriers=[];retirements=[]
 world=preload("res://demo/components/mission_room.gd").new();root.add_child(world);world.build(preload("res://demo/areas/warden_loops.gd").sector())
 # Labelled support fixture holds test shooters at baffle height; not a route.
 _surface(Vector2(at-70,foot+9),Vector2(90,18));_surface(Vector2(at+100,foot+9),Vector2(90,18))
 left=_actor(Vector2(at-70,foot),"RAW");right=_actor(Vector2(at+100,foot),"RAW",-1)
 left.get_node("ProjectileAim").target_path=right.get_path();right.get_node("ProjectileAim").target_path=left.get_path()
 left.get_node("ProjectileEmitter").projectile_emitted.connect(func(receipt):
  var c=instance_from_id(receipt.carrier_id)
  c.retired.connect(func(body,reason):retirements.append({"reason":str(reason),"position":str(body.global_position),"reflected":body.reflected})))
 await _frames(5)
func baffle(at:float)->Node:
 for child in world.get_children():
  if child is StaticBody2D and absf(child.position.x-at)<1:return child
 return null
func _run():
 var rows:Array=[]
 for at in [864.0,1294.0]:
  for mode in ["closed outbound","open control","closed reflected"]:
   label=str(at)+" / "+mode;await setup(at,190 if at<1000 else 220)
   var cover=baffle(at);_check(is_instance_valid(cover),"authored actual baffle body found")
   var shape=cover.get_node("CollisionShape2D")
   if mode!="closed outbound":shape.disabled=true
   await _frames(2);await _attack(left)
   var emitted=await _until(func():return not shots.is_empty())
   _check(emitted,"raw attack emits real authorized carrier")
   if not emitted:
    print("NO EMISSION ",label," left=",left.position," grounded=",left.grounded," action=",left.main_action," weapon=",left.weapon_phase)
    await _end();continue
   if mode=="closed reflected":
    await _until(func():return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38)
    _request(right,{"shield":true});await _until(func():return not contacts.is_empty())
    _check(not contacts.is_empty() and contacts[0].outcome==&"parried" and contacts[0].reflection_confirmed,"actual timed shield reflects incoming carrier")
    shape.disabled=false # Explicit dynamic-cover isolation, never claimed as static encounter sequence.
   await _frames(hz)
   if mode=="open control":_check(_health(right)<30,"same lane without baffle permits actual hit")
   else:
    _check(_health(left)==30 and _health(right)==30,"real cover prevents outbound/return damage")
    _check(not retirements.is_empty() and retirements[0].reason=="obstruction_or_unregistered","carrier retired on physical obstruction, not aim gate or timeout")
    if mode=="closed reflected":_check(not retirements.is_empty() and retirements[0].reflected,"intercepted carrier was genuinely reflected")
   rows.append({"case":label,"shots":shots.size(),"contacts":contacts.duplicate(true),"retirements":retirements.duplicate(true)})
   await _end()
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"rows":rows,"module_sha256":FileAccess.get_sha256("res://demo/areas/warden_loops.gd"),"scope":"Actual authored baffle bodies and shared emitter-authorized projectile flight from raw attack, with labelled extra support platforms/actor placements. Outbound closed/open paired control. Reflection uses actual timed parry then restores temporarily disabled baffle for return-flight isolation; not claimed a naturally occurring static encounter sequence. No AI tactic or full route proof."}
 FileAccess.open("res://simulation/evidence/campaign_rules_warden_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("WARDEN FLIGHT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
