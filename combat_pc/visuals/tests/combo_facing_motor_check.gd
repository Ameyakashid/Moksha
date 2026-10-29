extends SceneTree
## Reproduces body-facing versus committed strike-facing with a real motor tick.
const PLAYER=preload("res://combat_pc/player.tscn")
const SURFACE=preload("res://combat_pc/fixtures/test_surface.tscn")
const TARGET=preload("res://combat_pc/fixtures/contact_target.tscn")
const CHAIN=preload("res://combat_pc/resources/light_chain.tres")
class Driver extends Node:
 var actor:Node;var frame:Dictionary={};var ticks:=0
 func _physics_process(dt:float) -> void:actor.physics_tick(dt,frame);ticks+=1
var world:Node2D;var actor:Node;var view:Node;var driver:Driver;var rows:Array=[];var failures:Array=[]
func _init() -> void:Engine.physics_ticks_per_second=120;_run.call_deferred()
func _run() -> void:
 var actor_hash:=FileAccess.get_sha256("res://combat_pc/player.gd")
 var view_hash:=FileAccess.get_sha256("res://combat_pc/visuals/wireframe_pose.gd")
 for active_turn in [false,true]:
  world=Node2D.new();root.add_child(world)
  var floor_body=SURFACE.instantiate();floor_body.position=Vector2(-500,200);floor_body.size=Vector2(1000,40);world.add_child(floor_body)
  actor=PLAYER.instantiate();actor.position=Vector2(0,200);actor.automatic_physics=false;actor.melee_chain=CHAIN.duplicate(true)
  actor.melee_chain.steps[0].allow_turn_active=active_turn;world.add_child(actor);view=actor.get_node("Visual")
  driver=Driver.new();driver.actor=actor;driver.process_physics_priority=20;world.add_child(driver)
  await step({},10);await step({"attack":true});await step({})
  for i in 30:
   if actor.weapon_phase==&"active":break
   await step({})
  if active_turn:
   await step({"left":1.0},2);capture("configured_active_turn")
   var target=TARGET.instantiate();target.position=actor.position+Vector2(32,0);world.add_child(target)
   await step({"left":1.0},2)
   var before_pose:Dictionary=view.get_pose();var mark:Vector2=before_pose.weapon.get("contact_point",Vector2.INF)+actor.position
   if target.hits!=1 or not before_pose.weapon.get("confirmed",false):failures.append("configured active turn must still hit the target on the committed right side")
   if int(before_pose.weapon.get("contact_facing",0))!=1 or mark.distance_to(target.last_contact)>.001:failures.append("configured active turn changed the accepted world contact/facing")
   await step({"left":1.0},2)
   var held:Dictionary=view.get_pose()
   if held.bones!=before_pose.bones or (Vector2(held.weapon.contact_point)+actor.position).distance_to(mark)>.001:failures.append("configured active contact pause failed to hold body and frozen feedback")
   capture("configured_active_contact_pause")
  else:
   await step({"left":1.0},2);capture("default_active_lock")
   for i in 30:
    if actor.weapon_phase==&"recovery":break
    await step({})
   await step({"left":1.0},3);capture("recovery_turn_no_queue")
  world.queue_free();await physics_frame;await process_frame
 var report={"passed":failures.is_empty(),"failures":failures,"motor_sha256":actor_hash,"wireframe_pose_sha256":view_hash,"rows":rows,"scope":"Actual fresh right strike then left input without a queued step; separate custom active-turn resource"}
 FileAccess.open("res://combat_pc/visuals/tests/combo_facing_motor_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func step(frame:Dictionary,count:int=1) -> void:
 driver.frame=frame
 for i in count:
  var tick:=driver.ticks+1
  while driver.ticks<tick:await physics_frame;await process_frame
func capture(label:String) -> void:
 var t:Dictionary=actor.telemetry();var p:Dictionary=view.get_pose();var strike:Dictionary=actor.strike_snapshot()
 rows.append({"case":label,"phase":str(t.weapon_phase),"body_facing":t.facing,"attack_facing":t.attack_facing,"rendered_facing":p.facing,"rendered_key":p.key,"rendered_weapon_facing":p.combo.weapon_facing,"blade_tip":[p.weapon.tip.x,p.weapon.tip.y],"position":[t.position.x,t.position.y],"strike_facing":strike.facing,"pending_step":t.chain_pending_step})
 if p.facing!=t.facing:failures.append(label+": rendered facing contradicts authoritative body facing")
 if int(strike.facing)!=1:failures.append(label+": committed strike rotated")
 if str(t.weapon_phase)=="active" and (Vector2(p.weapon.tip)-Vector2(p.weapon.grip)).x<=0:failures.append(label+": active blade left its committed right direction")
