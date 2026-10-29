extends SceneTree
## Optional held modes observed through real motor ticks and swept passive contacts.
const PLAYER=preload("res://combat_pc/player.tscn")
const SURFACE=preload("res://combat_pc/fixtures/test_surface.tscn")
const TARGET=preload("res://combat_pc/fixtures/chain_target.tscn")
const CHAIN=preload("res://combat_pc/resources/light_chain.tres")
const CHARGE=preload("res://combat_pc/resources/held_charge.tres")
const REPEAT=preload("res://combat_pc/resources/held_repeat.tres")
class Driver extends Node:
 var actor:Node;var frame:Dictionary={};var ticks:=0
 func _physics_process(dt:float) -> void:actor.physics_tick(dt,frame);ticks+=1
var world:Node2D;var actor:Node;var view:Node;var driver:Driver;var target:Node
var checks:=0;var failures:Array[String]=[];var rows:Array=[];var samples:Array=[];var events:Array=[]
var contact_error:=0.0;var moving_foot_pairs:Dictionary={};var air_charge_ticks:=0;var air_thrust_ticks:=0;var low_ticks:=0
var last_pose:Dictionary={};var last_t:Dictionary={};var paused_pairs:=0
func _init() -> void:Engine.physics_ticks_per_second=120;_run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _run() -> void:
 var paths=["res://combat_pc/player.gd","res://combat_pc/resources/melee_input_profile.gd","res://combat_pc/resources/held_charge.tres","res://combat_pc/resources/held_repeat.tres","res://combat_pc/resources/melee_chain.gd","res://combat_pc/resources/melee_step.gd","res://combat_pc/components/contact_adapter.gd","res://combat_pc/fixtures/chain_target.gd"]
 for file in DirAccess.get_files_at("res://combat_pc/visuals"):
  if file.ends_with(".gd"):paths.append("res://combat_pc/visuals/"+file)
 var hashes:Dictionary={}
 for path in paths:hashes[path]=FileAccess.get_sha256(path)
 for facing in [-1,1]:
  for context in ["ground","moving","low","moving_low","air","reverse"]:await _full_charge(facing,context)
  await _cancel(facing,"release");await _cancel(facing,"shield")
  await _repeat(facing)
 for path in paths:check(hashes[path]==FileAccess.get_sha256(path),"source stayed stable during held-mode view integration "+path)
 check(moving_foot_pairs.size()>8,"moving charge really changes its foot pose under physical root travel")
 check(air_charge_ticks>0 and air_thrust_ticks>0,"actual fall covers both charging and charged thrust")
 check(low_ticks>0 and paused_pairs>0,"actual roof and contact hitpause exercised")
 var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"hashes":hashes,"scenarios":rows,"maximum_contact_error_px":contact_error,"moving_foot_pairs":moving_foot_pairs.size(),"air_charge_ticks":air_charge_ticks,"air_thrust_ticks":air_thrust_ticks,"low_ticks":low_ticks,"paused_pose_pairs":paused_pairs,"scope":"Actual120Hz optional held-input phases and real swept target contact, observed by original wireframe; no native gameplay capture"}
 FileAccess.open("res://combat_pc/visuals/tests/charge_motor_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 FileAccess.open("res://combat_pc/visuals/tests/charge_motor_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Actual motor/view vectors during optional held modes","samples":samples},"\t"))
 print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func _begin(facing:int,context:String,repeating:bool=false) -> void:
 world=Node2D.new();root.add_child(world);events=[];last_pose={};last_t={}
 var floor_y:=600.0 if context=="air" else 200.0
 var floor_body=SURFACE.instantiate();floor_body.position=Vector2(-1000,floor_y);floor_body.size=Vector2(3000,40);world.add_child(floor_body)
 actor=PLAYER.instantiate();actor.position=Vector2(100,200);actor.automatic_physics=false;actor.initial_facing=facing;actor.melee_chain=CHAIN;actor.melee_input_profile=REPEAT if repeating else CHARGE;world.add_child(actor)
 view=actor.get_node("Visual");actor.movement_event.connect(func(key:StringName,payload:Dictionary):events.append({"event":String(key),"payload":payload.duplicate(true)}))
 driver=Driver.new();driver.actor=actor;driver.process_physics_priority=20;world.add_child(driver)
 await _step({},2 if context=="air" else 20)
 if "low" in context:
  await _step({"down":1.0},2)
  var roof=SURFACE.instantiate();roof.position=Vector2(-500,160);roof.size=Vector2(1400,19);world.add_child(roof)
  await _step({"down":1.0},2)
 target=TARGET.instantiate();target.position=Vector2(actor.position.x+32*facing,floor_y);target.size=Vector2(16,450 if context=="air" else 30);world.add_child(target)
 if "moving" in context:
  var further=TARGET.instantiate();further.position=Vector2(actor.position.x+90*facing,floor_y);world.add_child(further)
 await _step({"down":1.0} if "low" in context else {},1)
func _step(frame:Dictionary,count:int=1) -> void:
 driver.frame=frame
 for i in count:
  var tick:=driver.ticks+1
  while driver.ticks<tick:await physics_frame;await process_frame
  var t:Dictionary=actor.telemetry();var pose:Dictionary=view.get_pose()
  var loading:bool=str(t.weapon_phase)=="charge"
  var thrust:bool=str(t.get("attack_pose_id",""))=="charged_thrust" and str(t.weapon_phase)!="idle"
  if loading or thrust:
   check(pose.mode==str(t.pose) and pose.facing==t.facing,"actual held pose and body facing agree with the motor")
   check(pose.weapon.visible and not pose.has("shield"),"held weapon is exclusive and visible")
   check(Vector2(pose.weapon.grip).distance_to(pose.bones.palm_near)<.001,"actual loading/thrust palm stays attached")
   if loading:
    check(not pose.weapon.contact and not pose.weapon.confirmed,"actual charging emits no invented contact")
    check(absf(float(pose.phase)-float(t.charge_progress))<.0001,"actual charge pose uses motor progress")
    if absf(Vector2(t.velocity).x)>1 and t.grounded:moving_foot_pairs[str(pose.bones.sole_near)+str(pose.bones.sole_far)]=true
    if not t.grounded:air_charge_ticks+=1
   else:
    check(pose.combo.weapon_facing==(t.attack_facing if str(t.weapon_phase)=="active" else t.facing),"charged phase preserves separate body/strike facing")
    if not t.grounded:air_thrust_ticks+=1
   if not t.grounded:check(pose.planted_feet==[false,false],"actual aerial hold/thrust invents no planted support")
   if float(t.body_height)<=20.1:
    low_ticks+=1
    for point in ["tip","blade_a","blade_b","guard_a","guard_b","pommel"]:check(pose.weapon[point].y>=-20 and pose.weapon[point].y<=.001,"actual low blade stays inside clearance")
   if bool(pose.weapon.get("confirmed",false)):
    var found:=false
    for index in range(events.size()-1,-1,-1):
     if events[index].event=="strike_confirmed" and int(events[index].payload.serial)==int(t.attack_serial):
      found=true;contact_error=maxf(contact_error,(Vector2(pose.weapon.contact_point)+Vector2(t.position)).distance_to(Vector2(events[index].payload.contact_position)));break
    check(found,"charged impact mark comes from its actual strike serial")
   if not last_t.is_empty() and bool(t.paused) and bool(last_t.paused) and t.position==last_t.position and str(t.weapon_phase)==str(last_t.weapon_phase) and t.weapon_phase_progress==last_t.weapon_phase_progress and t.charge_progress==last_t.charge_progress:
    check(pose.bones==last_pose.bones and pose.weapon==last_pose.weapon,"actual local pause holds loaded/thrust pose")
    paused_pairs+=1
   if last_t.is_empty() or str(t.weapon_phase)!=str(last_t.weapon_phase):samples.append({"pose":encode(pose),"telemetry":encode(t)})
  last_t=t;last_pose=pose
func _until(test:Callable,frame:Dictionary,limit:int=240) -> bool:
 for i in limit:
  if test.call():return true
  await _step(frame)
 return bool(test.call())
func _full_charge(facing:int,context:String) -> void:
 await _begin(facing,context)
 var frame:Dictionary={"attack":true}
 if "low" in context:frame["down"]=1.0
 if "moving" in context:frame["left" if facing<0 else "right"]=1.0
 await _step(frame)
 check(await _until(func():return actor.weapon_phase==&"charge",frame),"continuous hold reaches real loading "+context)
 check(await _until(func():return str(actor.telemetry().attack_pose_id)=="charged_thrust" and actor.weapon_phase==&"active",frame),"completed charge reaches real swept thrust "+context)
 var contacts:=0
 for e in events:
  if e.event=="strike_confirmed" and int(e.payload.serial)==actor.attack_serial:contacts+=1
 check(contacts>0,"charged thrust reaches a real passive target "+context)
 if context=="reverse":
  check(await _until(func():return actor.weapon_phase==&"recovery",frame),"charged recovery opens")
  frame["left" if facing>0 else "right"]=1.0;await _step(frame,3)
  check(view.get_pose().facing==actor.facing and actor.facing==-facing,"charged recovery visibly follows permitted reversal")
 check(await _until(func():return actor.weapon_phase==&"idle",frame),"charged recovery finishes")
 var serial:int=actor.attack_serial;await _step(frame,36)
 check(actor.attack_serial==serial and not view.get_pose().weapon.visible,"held charged profile cannot silently loop")
 var starts:Array=[]
 for e in events:
  if e.event=="attack_started":starts.append(str(e.payload.attack_pose_id))
 check(starts==["slash","charged_thrust"],"one continuous hold owns exactly starter and thrust")
 rows.append({"context":context,"facing":facing,"started":starts,"charged_contacts_at_active_entry":contacts,"final_body_height":actor.body_height})
 await _finish()
func _cancel(facing:int,kind:String) -> void:
 await _begin(facing,"ground");await _step({"attack":true})
 await _until(func():return actor.weapon_phase==&"charge",{"attack":true})
 await _step({"attack":true},12)
 await _step({} if kind=="release" else {"attack":true,"shield":true},2)
 check(actor.weapon_phase!=&"charge" and not view.get_pose().weapon.visible,"actual loading cancellation hides its blade "+kind)
 if kind=="shield":check(view.pose_name.begins_with("shield_"),"actual shield exclusively replaces loading")
 await _step({},30)
 var charged_started:=false
 for e in events:
  if e.event=="attack_started" and str(e.payload.attack_pose_id)=="charged_thrust":charged_started=true
 check(not charged_started,"cancellation cannot display or start an early-release thrust")
 rows.append({"context":"cancel_"+kind,"facing":facing,"charged_started":charged_started})
 await _finish()
func _repeat(facing:int) -> void:
 await _begin(facing,"ground",true);await _step({"attack":true})
 check(await _until(func():return actor.attack_serial>=5,{"attack":true},300),"held-repeat profile reaches another real chain")
 var ids:Array=[]
 for e in events:
  if e.event=="attack_started":ids.append(str(e.payload.attack_pose_id))
 check(ids.slice(0,5)==["slash","backhand","finisher","slash","backhand"],"held-repeat reuses accepted light poses and fresh strike identities")
 check(not view.get_pose().has("charge"),"optional repeat does not display charging")
 rows.append({"context":"held_repeat","facing":facing,"started":ids});await _finish()
func _finish() -> void:world.queue_free();await physics_frame;await process_frame
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
