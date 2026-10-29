extends SceneTree
## Rules integration on independently placed physical scenes. No campaign state,
## forced outcome velocities, or rendering-dependent physics admission.
const Actor=preload("res://simulation/actors/shared_actor.tscn")
const NpcSource=preload("res://simulation/components/npc_input_source.gd")
const Floor=preload("res://simulation/world/floor_segment.tscn")
const Platform=preload("res://simulation/world/static_platform.tscn")
const Cargo=preload("res://simulation/world/mission_cargo.tscn")
const Lift=preload("res://simulation/world/moving_lift.tscn")
const Ladder=preload("res://simulation/world/mission_ladder.tscn")
class RawSource extends Node:
 var raw:Dictionary={}
 func sample_raw(_actor:Node,_dt:float)->Dictionary:return raw.duplicate(true)
 func reset_intent():raw.clear()
class Intent extends Node:
 var intent:Dictionary={}
 func sample_intent(_actor:Node,_dt:float)->Dictionary:return intent.duplicate(true)
 func reset_intent():intent.clear()
var hz:=60
var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
var world:Node2D
var label:=""
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
 Engine.physics_ticks_per_second=hz
 run.call_deferred()
func frames(n:int):
 for i in n:await physics_frame;await process_frame
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures.append(label+": "+message)
func begin(offset:Vector2):
 world=Node2D.new();world.position=offset;root.add_child(world)
func finish():world.queue_free();await frames(3)
func actor(role:String,at:Vector2)->Node2D:
 var a=Actor.instantiate();a.position=at
 a.get_node("ContactConfig").profile=load("res://demo/resources/player_contact.tres" if role=="PC" else "res://demo/resources/sentinel_contact.tres")
 var source:Node=RawSource.new() if role=="PC" else NpcSource.new();source.name="InputSource";a.add_child(source)
 if role=="NPC":var policy=Intent.new();policy.name="PatrolPolicy";a.add_child(policy)
 world.add_child(a);return a
func move(a:Node,role:String,axis:Vector2):
 if role=="PC":a.get_node("InputSource").raw={"left":maxf(0,-axis.x),"right":maxf(0,axis.x),"up":maxf(0,-axis.y),"down":maxf(0,axis.y)}
 else:a.get_node("PatrolPolicy").intent={"move":axis}
func floor_loss(role:String,offset:Vector2):
 label="floor art removed / "+role+" / "+str(offset);begin(offset)
 var floor=Floor.instantiate();floor.position=Vector2(250,310);floor.segment_size=Vector2(500,20);world.add_child(floor)
 floor.get_node("View").free();floor.get_node("Support/View").free()
 var a=actor(role,Vector2(120,240))
 var cargo=Cargo.instantiate();cargo.position=Vector2(350,250);world.add_child(cargo);cargo.hide()
 await frames(hz*3)
 check(a.grounded and a._support==floor.get_node("Support"),"real fall lands on independent art-free floor")
 check(absf(a.global_position.y-(offset.y+300))<1,"translated floor world coordinates remain authoritative")
 check(a.collision_layer==(2 if role=="PC" else 32) and a.collision_mask==9,"exact production role contact profile applied")
 check(cargo.sleeping and absf(cargo.global_position.y-(offset.y+286))<1,"hidden production cargo settles on same real support")
 var a_y:float=a.global_position.y;var c_y:float=cargo.global_position.y
 floor.queue_free();await frames(int(hz*0.5))
 check(a.global_position.y>a_y+30 and not a.grounded,"actor falls after actual support removal")
 check(cargo.global_position.y>c_y+30,"sleeping cargo also falls after support removal")
 observations.append({"case":label,"actor_drop":a.global_position.y-a_y,"cargo_drop":cargo.global_position.y-c_y})
 await finish()
func platform_support(role:String,offset:Vector2):
 label="platform View removed / "+role+" / "+str(offset);begin(offset)
 var p=Platform.instantiate();p.position=Vector2(200,300);p.platform_size=Vector2(180,18);p.one_way_collision=true;world.add_child(p);p.get_node("View").free()
 var a=actor(role,Vector2(200,240));await frames(hz)
 check(a.grounded and a._support==p,"real actor supported by independently placed one-way platform without View")
 check(absf(a.global_position.y-(offset.y+291))<1,"platform support uses translated body position")
 await finish()
func lift_support(role:String,offset:Vector2):
 label="hidden translating lift / "+role+" / "+str(offset);begin(offset)
 var lift=Lift.instantiate();lift.position=Vector2(200,300);lift.travel=Vector2(0,-80);lift.period=4.0;lift.platform_size=Vector2(140,14);world.add_child(lift);lift.hide()
 var a=actor(role,Vector2(200,260));var supported:=0;var max_gap:=0.0
 for i in hz*2:
  await frames(1)
  if a.grounded and a._support==lift:
   supported+=1;max_gap=maxf(max_gap,absf(a.global_position.y-(lift.global_position.y-7)))
 check(supported>hz,"real moving support carries actor for more than one second")
 check(a.global_position.y<offset.y+240,"hidden lift actually carries actor upward")
 check(max_gap<3.5,"carried foot follows actual moving surface within solver tolerance")
 observations.append({"case":label,"supported_ticks":supported,"max_surface_gap":max_gap,"actor_local":str(a.position),"lift_local":str(lift.position)})
 await finish()
func ladder_motion(role:String,offset:Vector2):
 label="hidden ladder / "+role+" / "+str(offset);begin(offset)
 var ladder=Ladder.instantiate();ladder.position=Vector2(200,300);ladder.height=200;world.add_child(ladder);ladder.draw_guide=false;ladder.hide()
 var a=actor(role,Vector2(200,250));await frames(3)
 var start:float=a.global_position.y;move(a,role,Vector2.UP);await frames(int(hz*0.6))
 check(a.main_action==&"climb","deliberate raw/intent input attaches real hidden ladder sensor")
 check(a.global_position.y<start-30,"climb controller produces real ascent")
 check(ladder.get_node("SonarRails/Contour").shape.size==Vector2(20,200),"standalone ladder retains independent nonblocking contour")
 move(a,role,Vector2.ZERO);ladder.queue_free();await frames(int(hz*0.5))
 check(a.main_action!=&"climb","removed climbable cannot retain a stale grip")
 await finish()
func transform_refusal():
 label="ladder supported transform contract";begin(Vector2(700,-80))
 var ladder=Ladder.instantiate();ladder.position=Vector2(30,300);ladder.height=160;world.add_child(ladder)
 check(ladder.climb_geometry().axis_x==730 and ladder.climb_geometry().top_y==60,"upright nested translation supported")
 ladder.rotation=0.2;check(ladder.climb_geometry().is_empty(),"rotated ladder explicitly refuses climb geometry")
 ladder.rotation=0;ladder.scale=Vector2(-1,1);check(ladder.climb_geometry().is_empty(),"mirrored ladder explicitly refuses climb geometry")
 ladder.scale=Vector2(1.5,1.2);check(is_equal_approx(ladder.climb_geometry().width,30) and is_equal_approx(ladder.climb_geometry().top_y,28),"positive upright ladder scale explicitly represented")
 await finish()
func run():
 for offset in [Vector2.ZERO,Vector2(3700,-400)]:
  for role in ["PC","NPC"]:
   await floor_loss(role,offset);await platform_support(role,offset);await lift_support(role,offset);await ladder_motion(role,offset)
 await transform_refusal()
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"observations":observations,"scope":"Real production-contact-profile PC/NPC controller composition under upright translated parents, actual floor/platform/lift/ladder contact and cargo gravity. PC raw fixture and NPC intent fixture are deliberate inputs, not autonomous policy or human gameplay. Art removed only where optional View contract allows; hidden root elsewhere. No mutual actor-blocking change."}
 FileAccess.open("res://simulation/evidence/campaign_rules_placement_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("CAMPAIGN RULES ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
