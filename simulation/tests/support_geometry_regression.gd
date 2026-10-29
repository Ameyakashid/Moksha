extends SceneTree
const Cargo=preload("res://simulation/components/physical_cargo.tscn")
var hz:=60
var checks:=0
var failures:Array[String]=[]
var world:Node2D
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
 Engine.physics_ticks_per_second=hz;run.call_deferred()
func frames(n:int):
 for i in n: await physics_frame;await process_frame
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func shape(body:StaticBody2D,at:Vector2,size:Vector2):
 var c:=CollisionShape2D.new();c.position=at;c.shape=RectangleShape2D.new();c.shape.size=size;body.add_child(c);return c
func begin(rotation:float,floor_rotation:float,compound:=false):
 world=Node2D.new();root.add_child(world)
 var floor:=StaticBody2D.new();floor.position=Vector2(200,300);floor.rotation=floor_rotation
 floor.physics_material_override=PhysicsMaterial.new();floor.physics_material_override.friction=1.0;floor.physics_material_override.rough=true
 if compound:
  shape(floor,Vector2(-10,0),Vector2(20,20));shape(floor,Vector2(10,0),Vector2(20,20))
 else:shape(floor,Vector2.ZERO,Vector2(300,20))
 world.add_child(floor)
 var cargo:=Cargo.instantiate() as RigidBody2D;cargo.position=Vector2(200,250);cargo.rotation=rotation;cargo.tuning=cargo.tuning.duplicate(true);cargo.tuning.bounce=0;cargo.tuning.friction=1;world.add_child(cargo)
 return [cargo,floor]
func end():world.queue_free();await frames(3)
func run():
 for angles in [Vector2(PI/2,0),Vector2(0.15,0.15)]:
  var pair=begin(angles.x,angles.y);var cargo=pair[0];var floor=pair[1]
  await frames(hz*4)
  check(cargo.sleeping,"rotated/tilted cargo naturally sleeps")
  check(cargo._sleep_support_ids.has(floor.get_instance_id()),"world-normal contact records rotated support")
  var y:float=cargo.position.y;floor.queue_free();await frames(hz)
  check(cargo.position.y>y+100 and not cargo.sleeping,"rotated/tilted support removal resumes real gravity")
  await end()
 var pair=begin(0,0,true);var cargo=pair[0];var floor=pair[1]
 await frames(hz*4)
 check(cargo.sleeping,"compound naturally sleeps")
 var record:Dictionary=cargo._sleep_support_ids.get(floor.get_instance_id(),{})
 check(record.get("owners",{}).size()==2,"both genuine supporting shape owners retained")
 # First changed owner still leaves another real support; a wake may occur,
 # but solver must not force a fall while the remaining piece supports cargo.
 floor.get_child(0).set_deferred("disabled",true);await frames(hz)
 check(cargo.position.y<310,"remaining compound support still physically holds cargo")
 floor.get_child(1).set_deferred("disabled",true);await frames(hz)
 check(cargo.position.y>400,"last compound support loss resumes gravity")
 await end()
 var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Actual 90-degree crate, tilted support and two shape owners on one body; no forced sleeping or outcome velocities."}
 FileAccess.open("res://simulation/evidence/support_geometry_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SUPPORT GEOMETRY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
