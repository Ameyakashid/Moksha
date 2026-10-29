extends SceneTree
## Scene packaging, standalone physics and factory parity; not a full route test.
const Support = preload("res://simulation/tests/field_cache_support.gd")
var checks := 0
var failures: Array[String] = []
var hz := 60
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
 Engine.physics_ticks_per_second=hz
 run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok: failures.append(label);print("FAIL ",label)
func frames(n: int):
 for i in n:
  await physics_frame
  await process_frame
func make(name: String):return load("res://simulation/world/"+name+".tscn").instantiate()
func run():
 var legacy:=GDScript.new()
 legacy.source_code=FileAccess.get_file_as_string("res://simulation/evidence/physical_scene_baseline/mission_room.gd.txt")
 check(legacy.reload()==OK,"archived room compiles")
 for data in preload("res://demo/mission_data.gd").sectors():
  var old=legacy.new();var fresh=preload("res://demo/components/mission_room.gd").new()
  root.add_child(old);root.add_child(fresh);old.build(data);fresh.build(data)
  check(Support.topology(old,[])==Support.topology(fresh,[]),"exact ordered production collision topology")
  check(Support.contours(old)==Support.contours(fresh),"exact ordered production sonar contours")
  for c in fresh.get_children():
   if c.get_script()==preload("res://demo/components/mission_lift.gd"):check(c.scene_file_path.ends_with("moving_lift.tscn"),"production lift uses scene")
   if c.get_script()==preload("res://demo/components/relay_shutter.gd"):check(c.scene_file_path.ends_with("relay_shutter.tscn"),"production shutter uses scene")
  if data.has("freight"):
   check(fresh.freight_cradle.scene_file_path.ends_with("freight_cradle.tscn") and fresh.freight_receiver.scene_file_path.ends_with("freight_receiver.tscn"),"production freight uses scenes")
  old.free();fresh.free()
 await frames(2)
 var bus=root.get_node_or_null("NoiseBus")
 if bus!=null:root.remove_child(bus)
 check(root.get_node_or_null("NoiseBus")==null,"standalone fixtures have no noise service")
 var world:=Node2D.new();root.add_child(world)
 var lift=make("moving_lift");lift.position=Vector2(0,300);lift.travel=Vector2(0,-80);lift.period=4.0;world.add_child(lift)
 var second=make("moving_lift");second.position=Vector2(400,300);second.travel=lift.travel;second.period=lift.period;world.add_child(second)
 lift.hide()
 await frames(hz*2)
 check(lift.position.distance_to(second.position-Vector2(400,0))<0.01,"hidden moving lift retains actual motion without bus")
 check(lift.position.y<250,"standalone lift actually travels")
 lift.set_physics_process(false);second.set_physics_process(false)
 check(Support.topology(lift,[])[1].one_way,"lift retains one-way physical support")
 var shutter=make("relay_shutter");shutter.position=Vector2(1000,200);shutter.shutter_size=Vector2(30,100);world.add_child(shutter);shutter.hide()
 await frames(2)
 var probe:=CharacterBody2D.new();probe.collision_layer=0;probe.collision_mask=1
 var shape:=CollisionShape2D.new();shape.shape=RectangleShape2D.new();shape.shape.size=Vector2(10,10);probe.add_child(shape);world.add_child(probe);probe.position=Vector2(930,200)
 check(probe.test_move(probe.global_transform,Vector2(140,0)),"hidden closed scene shutter blocks real body sweep")
 shutter.set_open(true);await frames(2)
 check(not probe.test_move(probe.global_transform,Vector2(140,0)),"open scene shutter permits real body sweep")
 shutter.set_open(false);await frames(2)
 check(probe.test_move(probe.global_transform,Vector2(140,0)),"scene shutter re-closes without visibility mutation")
 var ladder=make("mission_ladder");ladder.position=Vector2(1400,300);ladder.height=200;world.add_child(ladder)
 check(ladder.climb_geometry().get("top_y")==100.0,"standalone ladder supplies original climb geometry")
 check(ladder.get_node("SonarRails/Contour").shape.size==Vector2(20,200),"standalone ladder owns exact production rails")
 ladder.hide();ladder.draw_guide=false
 check(not ladder.climb_geometry().is_empty() and not Support.contours(ladder).is_empty(),"hidden guide keeps climb and sonar geometry")
 ladder.height=260;ladder.width=30
 check(ladder.get_node("SonarRails/Contour").shape.size==Vector2(30,260) and ladder.climb_geometry().width==30,"configured ladder synchronizes sensor and rails")
 var receiver=make("freight_receiver");receiver.position=Vector2(1900,300);world.add_child(receiver);receiver.hide()
 var cargo=make("mission_cargo");cargo.position=Vector2(1900,240);cargo.set_meta("freight_valid",true);world.add_child(cargo);receiver.bind_cargo(cargo)
 await frames(hz*3)
 check(receiver.is_latched,"hidden standalone receiver latches real falling scene cargo")
 check(cargo.scene_file_path.ends_with("mission_cargo.tscn") and cargo.collision_mask==43,"cargo packages production physical configuration")
 var cradle=make("freight_cradle");cradle.position=Vector2(2300,300);world.add_child(cradle);await frames(3)
 check(is_instance_valid(cradle.cargo) and cradle.cargo.scene_file_path.ends_with("mission_cargo.tscn"),"standalone cradle spawns packaged cargo")
 var old_id=cradle.cargo.get_instance_id();cradle.hide();check(cradle.replace_cargo(),"hidden cradle accepts replacement")
 await frames(3)
 check(is_instance_valid(cradle.cargo) and cradle.cargo.get_instance_id()!=old_id,"hidden cradle replacement commits once")
 var prior=Support.topology(ladder,[]);world.remove_child(ladder);world.add_child(ladder)
 check(Support.topology(ladder,[])==prior,"ladder detach/readd preserves geometry without duplicate rails")
 check(ladder.get_children().filter(func(c):return c is StaticBody2D).size()==1,"one ladder rail body per instance")
 world.free()
 if bus!=null:root.add_child(bus)
 var report={"checks":checks,"failures":failures,"hz":hz,"scope":"Scene factory/topology parity and isolated actual collision/solver checks; no full campaign or native appearance claim."}
 var f=FileAccess.open("res://simulation/evidence/physical_scene_regression_%d.json"%hz,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
 print("PHYSICAL SCENE RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
