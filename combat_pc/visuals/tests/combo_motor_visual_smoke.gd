extends SceneTree
## Real three-step PC flow and passive target contacts observed by the view.
const PLAYER=preload("res://combat_pc/player.tscn")
const SURFACE=preload("res://combat_pc/fixtures/test_surface.tscn")
const TARGET=preload("res://combat_pc/fixtures/chain_target.tscn")
const CHAIN=preload("res://combat_pc/resources/light_chain.tres")
class Driver extends Node:
 var actor:Node;var frame:Dictionary={};var ticks:=0
 func _physics_process(dt:float) -> void:actor.physics_tick(dt,frame);ticks+=1
var world:Node2D;var actor:Node;var visual:Node;var driver:Driver;var target:Node
var checks:=0;var failures:Array[String]=[];var events:Array=[];var rows:Array=[];var samples:Array=[]
var contact_error:=0.0;var sole_error:=0.0;var last_pose:Dictionary={};var last_telemetry:Dictionary={};var pause_pairs:=0;var low_turn_samples:=0;var low_recovery_turn_samples:=0
func _init() -> void:Engine.physics_ticks_per_second=120;_run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _run() -> void:
 var paths=["res://combat_pc/player.gd","res://combat_pc/resources/melee_chain.gd","res://combat_pc/resources/melee_step.gd","res://combat_pc/resources/light_chain.tres","res://combat_pc/components/contact_adapter.gd","res://combat_pc/fixtures/chain_target.gd","res://combat_pc/fixtures/contact_target.gd"]
 for file in DirAccess.get_files_at("res://combat_pc/visuals"):
  if file.ends_with(".gd"):paths.append("res://combat_pc/visuals/"+file)
 var hashes:Dictionary={}
 for path in paths:hashes[path]=FileAccess.get_sha256(path)
 for facing in [-1,1]:
  for context in ["ground","air","low","slope","reverse","low_reverse"]:await _chain_flow(facing,context)
 for path in paths:check(hashes[path]==FileAccess.get_sha256(path),"source remained stable "+path)
 check(low_recovery_turn_samples>0,"actual low-roof recovery follows a permitted body reversal")
 check(pause_pairs>0,"actual contact hitpause produced held pose pairs")
 var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"hashes":hashes,"maximum_confirmed_contact_error_px":contact_error,"maximum_slope_sole_error_px":sole_error,"held_actual_pause_pairs":pause_pairs,"low_turn_projection_samples":low_turn_samples,"low_recovery_turn_samples":low_recovery_turn_samples,"scenarios":rows,"scope":"Actual120Hz motor input, step commitments and real swept passive-target contacts; no native gameplay capture"}
 FileAccess.open("res://combat_pc/visuals/tests/combo_motor_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 FileAccess.open("res://combat_pc/visuals/tests/combo_motor_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Actual motor/view vector observations from the120Hz headless physics harness","samples":samples},"\t"))
 print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func _begin(facing:int,context:String) -> void:
 world=Node2D.new();root.add_child(world)
 if context=="slope":
  var body:=StaticBody2D.new();body.collision_layer=1;var poly:=CollisionPolygon2D.new()
  poly.polygon=PackedVector2Array([Vector2(-300,600),Vector2(600,-300),Vector2(600,700),Vector2(-300,700)])
  body.add_child(poly);world.add_child(body)
 else:
  var floor_body=SURFACE.instantiate();floor_body.position=Vector2(-1000,200);floor_body.size=Vector2(3000,40);world.add_child(floor_body)
 actor=PLAYER.instantiate();actor.position=Vector2(100,150 if context=="slope" else 200);actor.automatic_physics=false;actor.melee_chain=CHAIN;actor.initial_facing=facing;world.add_child(actor)
 visual=actor.get_node("Visual");events=[];last_pose={};last_telemetry={}
 actor.movement_event.connect(func(key:StringName,payload:Dictionary):events.append({"event":String(key),"payload":payload.duplicate(true)}))
 driver=Driver.new();driver.actor=actor;driver.process_physics_priority=20;world.add_child(driver)
 await _step({},45)
 if context in ["low","low_reverse"]:
  await _step({"down":1.0},2)
  var roof=SURFACE.instantiate();roof.position=Vector2(-100,160);roof.size=Vector2(600,19);world.add_child(roof);await _step({"down":1.0},2)
 target=TARGET.instantiate();target.position=actor.position+Vector2(32*facing,0);target.size=Vector2(16,130 if context=="air" else 30);world.add_child(target)
 await _step({"down":1.0} if context in ["low","low_reverse"] else {},2)
func _step(frame:Dictionary,count:int=1) -> void:
 driver.frame=frame
 for i in count:
  var tick:=driver.ticks+1
  while driver.ticks<tick:await physics_frame;await process_frame
  var t:Dictionary=actor.telemetry();var pose:Dictionary=visual.get_pose()
  if str(t.get("attack_pose_id",""))!="" and str(t.weapon_phase)!="idle":
   check(pose.mode==str(t.pose) and pose.has("combo") and str(pose.combo.step)==str(t.attack_pose_id),"real committed step selects its exact visual family")
   check(pose.facing==t.facing and not pose.has("shield"),"real body facing and weapon ownership stay authoritative")
   check(pose.combo.weapon_facing==(t.attack_facing if str(t.weapon_phase)=="active" else t.facing),"real phase separates committed active strike from body-facing recovery")
   check(Vector2(pose.weapon.grip).distance_to(pose.bones.palm_near)<.001,"actual combo grip stays attached")
   if not t.grounded:check(pose.planted_feet==[false,false],"actual aerial combo retains unplanted legs")
   if pose.weapon.has("turn_projection_fraction"):low_turn_samples+=1
   if float(t.body_height)<=20.1:
    if str(t.weapon_phase)=="recovery" and t.facing!=t.attack_facing:low_recovery_turn_samples+=1
    for point in ["tip","blade_a","blade_b","pommel","guard_a","guard_b"]:check(pose.weapon[point].y>=-20 and pose.weapon[point].y<=.001,"actual low blade remains inside body clearance")
   if bool(pose.get("slope_support",false)):
    for side in ["near","far"]:
     if pose.planted_feet[0 if side=="near" else 1]:sole_error=maxf(sole_error,absf((Vector2(pose.bones["sole_"+side])+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal))))
   if bool(pose.weapon.get("confirmed",false)):
    var found:=false
    for j in range(events.size()-1,-1,-1):
     if events[j].event=="strike_confirmed" and int(events[j].payload.serial)==int(t.attack_serial):
      found=true;contact_error=maxf(contact_error,(Vector2(pose.weapon.contact_point)+Vector2(t.position)).distance_to(Vector2(events[j].payload.contact_position)));break
    check(found,"visible impact belongs to this real step serial")
   if not last_telemetry.is_empty() and bool(t.paused) and bool(last_telemetry.paused) and t.attack_serial==last_telemetry.attack_serial and t.position==last_telemetry.position and t.weapon_phase_progress==last_telemetry.weapon_phase_progress:
    check(pose.bones==last_pose.bones and pose.weapon==last_pose.weapon,"actual local hitpause holds the body and weapon key")
    pause_pairs+=1
   if str(t.weapon_phase)=="active" and (last_telemetry.is_empty() or t.attack_serial!=last_telemetry.attack_serial or str(last_telemetry.weapon_phase)!="active"):
    samples.append({"pose":encode(pose),"telemetry":encode(t)})
  last_pose=pose;last_telemetry=t
func _until(test:Callable,frame:Dictionary,limit:int=200) -> bool:
 for i in limit:
  if test.call():return true
  await _step(frame)
 return bool(test.call())
func _chain_flow(facing:int,context:String) -> void:
 await _begin(facing,context)
 var base:Dictionary={"down":1.0} if context in ["low","low_reverse"] else {}
 if context=="air":await _step({"jump":true});await _step({},2)
 var press:=base.duplicate();press["attack"]=true
 await _step(press);await _step(base)
 var seen:Array=[];var airborne_steps:Array=[];var actual_facings:Array=[]
 for index in 3:
  check(await _until(func():return int(actor.telemetry().attack_step_index)==index and actor.weapon_phase==&"active",base),"real chain reaches active step "+str(index)+"/"+context)
  var t:Dictionary=actor.telemetry();seen.append(str(t.attack_pose_id));actual_facings.append(int(t.attack_facing))
  if not t.grounded:airborne_steps.append(index)
  if context not in ["reverse","low_reverse"]:check(target.hits>=index+1,"physical target receives this live step "+str(index)+"/"+context)
  if index<2:
   var next_frame:=base.duplicate();next_frame["attack"]=true
   await _step(next_frame)
   if context in ["reverse","low_reverse"]:
    base={"left":1.0} if facing>0 and index==0 or facing<0 and index==1 else {"right":1.0}
    if context=="low_reverse":base["down"]=1.0
   await _step(base)
 check(await _until(func():return actor.weapon_phase==&"idle",base),"finisher recovery retires without visual completion authority")
 check(not visual.get_pose().weapon.visible,"completed chain removes sword")
 check(seen==["slash","backhand","finisher"],"real committed order is visually distinct")
 if context not in ["reverse","low_reverse"]:check(target.hits==3,"passive target receives exactly one confirmed hit per step")
 if context=="air":check(not airborne_steps.is_empty(),"real jump overlaps chain without fabricated floor plants")
 if context in ["low","low_reverse"]:check(actor.body_height<=20.1,"actual roof keeps low body through combo")
 rows.append({"context":context,"initial_facing":facing,"steps":seen,"committed_facings":actual_facings,"airborne_steps":airborne_steps,"hits":target.hits,"final_body_height":actor.body_height})
 world.queue_free();await physics_frame;await process_frame
func encode(value:Variant) -> Variant:
 if value is Vector2:return [value.x,value.y]
 if value is Dictionary:
  var out:Dictionary={}
  for key in value:out[key]=encode(value[key])
  return out
 if value is Array:
  var out:Array=[]
  for item in value:out.append(encode(item))
  return out
 return value
