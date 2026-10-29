extends SceneTree
## Labelled direct geometry fixture; not a gameplay route or combat outcome.
var checks:=0
var failures:Array[String]=[]
var receipts:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label)
func run():
 var data=preload("res://demo/areas/warden_loops.gd").sector()
 var room=preload("res://demo/components/mission_room.gd").new();root.add_child(room);room.build(data)
 var probe:=CharacterBody2D.new();probe.collision_layer=0;probe.collision_mask=1
 var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(20,40);shape.shape=rect;shape.position=Vector2(0,-20);probe.add_child(shape);root.add_child(probe)
 await physics_frame;await process_frame
 check(data.enemies==[[770,"sentry",190],[960,"warden",300],[1125,"sentry",245]],"unchanged three authored spawns")
 check(data.width==1700 and data.get("gaps",[]).is_empty(),"unchanged footprint and no floor gaps")
 for spec in [[Vector2(820,299.9),Vector2(85,0)],[Vector2(905,299.9),Vector2(-85,0)],[Vector2(1240,299.9),Vector2(110,0)],[Vector2(1350,299.9),Vector2(-110,0)]]:
  var t:=Transform2D(0,spec[0]);var hit:=probe.test_move(t,spec[1])
  check(not hit,"40px-tall body passes beneath suspended baffle in both directions")
  receipts.append({"from":str(spec[0]),"motion":str(spec[1]),"blocked":hit,"mask":"terrain1 only; excludes optional movable cargo"})
 for spec in [[Vector2(820,190),Vector2(85,0)],[Vector2(1240,220),Vector2(110,0)]]:
  var hit:=KinematicCollision2D.new();var blocked:=probe.test_move(Transform2D(0,spec[0]),spec[1],hit)
  check(blocked,"real high-lane body sweep hits baffle")
  if blocked:
   var body:Node=hit.get_collider();var collider:=body.get_node("CollisionShape2D") as CollisionShape2D
   check(not collider.one_way_collision,"cover baffle is full-solid, not one-way")
   receipts.append({"high_from":str(spec[0]),"hit_position":str(hit.get_position()),"normal":str(hit.get_normal()),"collider":str(body.name)})
 for spec in [[Vector2(770,167),Vector2(940,113)],[Vector2(1125,222),Vector2(1360,168)]]:
  var q:=PhysicsRayQueryParameters2D.create(spec[0],spec[1],9,[probe.get_rid()]);q.hit_from_inside=true
  var hit:=probe.get_world_2d().direct_space_state.intersect_ray(q)
  check(not hit.is_empty(),"real sentry obstruction mask9 ray blocked across upper loop")
 for spec in data.enemies:
  var q:=PhysicsShapeQueryParameters2D.new();q.shape=rect;q.transform=Transform2D(0,Vector2(spec[0],spec[2]-20.1));q.collision_mask=1;q.exclude=[probe.get_rid()]
  check(probe.get_world_2d().direct_space_state.intersect_shape(q).is_empty(),"authored enemy spawn not embedded in new terrain")
 var report={"checks":checks,"failures":failures,"receipts":receipts,"scope":"Direct-state geometry fixture; real physics queries, not gameplay/recovery/projectile-flight proof","module_sha256":FileAccess.get_sha256("res://demo/areas/warden_loops.gd")}
 FileAccess.open("res://demo/evidence/warden_geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("WARDEN GEOMETRY ",JSON.stringify(report))
 room.queue_free();probe.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
