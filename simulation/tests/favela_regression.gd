extends SceneTree
const Backdrop=preload("res://demo/views/favela_backdrop.tscn")
const Building=preload("res://demo/views/favela_building.tscn")
const Cable=preload("res://demo/views/favela_cable.tscn")
const Rooftop=preload("res://demo/views/favela_rooftop.tscn")
const Profile=preload("res://demo/views/room_backdrop_profile.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);print("FAIL ",label)
func frames(n:=3):
 for i in n:await process_frame
func fingerprint(backdrop)->Array:
 var result:Array=[]
 for p in backdrop.get_node("DecorativePieces").get_children():
  result.append([p.name,p.position,p.kind,p.dimensions,p.variant,p.cable_end,p.cable_sag,p.appearance.wall,p.appearance.outline])
 return result
func safe_tree(node:Node)->bool:
 if node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D:return false
 if node.get_groups().size()>0:return false
 for child in node.get_children():
  if not safe_tree(child):return false
 return true
func run():
 var bus=root.get_node_or_null("NoiseBus")
 if bus!=null:root.remove_child(bus)
 var world:=Node2D.new();root.add_child(world)
 var a=Backdrop.instantiate();var b=Backdrop.instantiate();world.add_child(a);world.add_child(b)
 await frames()
 check(a.profile is Profile,"same RoomBackdropProfile assembly contract")
 check(a.profile!=b.profile and a.style!=b.style and a.style.appearance!=b.style.appearance,"scene profiles and paint are independent resources")
 check(fingerprint(a)==fingerprint(b),"same configuration deterministic without a global random source")
 check(safe_tree(a),"full assembly is decoration only; no collision or groups")
 check(a.get_node("DecorativePieces").get_child_count()>50,"default assembly has composed individual assets")
 var old=fingerprint(b)
 a.style.appearance.wall=Color("332244")
 await frames()
 check(fingerprint(b)==old and fingerprint(a)!=old,"palette editing one instance leaves second untouched")
 a.profile.visual_seed+=3
 await frames()
 check(fingerprint(a)!=fingerprint(b),"seed is independent visual arrangement input")
 var model=fingerprint(a)
 a.position=Vector2(-900,210);a.rotation=.3;a.scale=Vector2(1.7,.6)
 check(fingerprint(a)==model,"transform never changes local asset assembly")
 a.set_animation_time(3.25);a.set_animation_time(NAN)
 check(a.animation_time==3.25,"finite absolute clock forwarding; nonfinite clock rejected")
 a.automatic_animation=true
 await frames()
 check(a.animation_time>3.25,"optional internal clock advances")
 check(fingerprint(a)==model,"external clock and animation flag do not create gameplay state or random drift")
 a.hide();check(safe_tree(a),"hiding leaves decoration-only structure")
 world.remove_child(a);a.profile.visual_seed+=9;world.add_child(a);await frames()
 check(fingerprint(a)!=model and safe_tree(a),"detached configuration reassembles on reentry without ghost physics")
 a.profile.room_bounds=Rect2(0,-520,6200,820);await frames()
 check(a.get_node("DecorativePieces").get_child_count()>200 and a.get_node("DecorativePieces").get_child_count()<500,"large district assembly is bounded and populated")
 a.profile.room_bounds=Rect2(0,0,-3,50);await frames()
 check(a.get_node("DecorativePieces").get_child_count()==0,"invalid bounds safely clear optional artwork")
 a.profile=null;await frames();check(a.get_node("DecorativePieces").get_child_count()==0,"null profile is harmless")
 a.profile=Profile.new();a.profile.room_bounds=Rect2(0,0,700,400);await frames()
 check(a.get_node("DecorativePieces").get_child_count()>0,"restored compatible profile rebuilds")
 var old_style=a.style;a.style=null;await frames()
 check(a.get_node("DecorativePieces").get_child_count()==0,"null style is harmless")
 a.style=old_style;await frames()
 for asset in [Building,Cable,Rooftop]:
  var p=asset.instantiate();var q=asset.instantiate();world.add_child(p);world.add_child(q)
  check(safe_tree(p) and p.appearance!=q.appearance,"individual piece stands alone with local style")
  p.position=Vector2(150,240);p.rotation=.4;p.scale=Vector2(.8,1.2);p.hide()
  check(safe_tree(p),"individual transforms and hide cannot introduce physics")
  p.appearance=null;await frames();p.free();q.free()
 # An unrelated real physical sweep stays identical with artwork present/hidden/removed.
 var floor:=StaticBody2D.new();floor.position=Vector2(100,100);floor.collision_layer=1
 var shape:=CollisionShape2D.new();shape.shape=RectangleShape2D.new();shape.shape.size=Vector2(100,20);floor.add_child(shape);world.add_child(floor)
 var probe:=CharacterBody2D.new();probe.position=Vector2(100,30);probe.collision_layer=0;probe.collision_mask=1
 var ps:=CollisionShape2D.new();ps.shape=RectangleShape2D.new();ps.shape.size=Vector2(10,10);probe.add_child(ps);world.add_child(probe)
 await physics_frame
 var hit=probe.test_move(probe.global_transform,Vector2(0,100));check(hit,"unrelated real sweep establishes physical support")
 a.show();b.hide();await physics_frame;check(probe.test_move(probe.global_transform,Vector2(0,100))==hit,"visibility changes do not affect actual collision query")
 a.free();b.free();await physics_frame;check(probe.test_move(probe.global_transform,Vector2(0,100))==hit,"removing backdrops does not affect actual collision query")
 world.free()
 if bus!=null:root.add_child(bus)
 print("FAVELA RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"No-autoload decorative assembly/lifecycle/resource checks and unchanged real body sweep. Native appearance separate."}))
 quit(0 if failures.is_empty() else 1)
