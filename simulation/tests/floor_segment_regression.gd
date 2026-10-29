extends SceneTree
const Floor = preload("res://simulation/world/floor_segment.tscn")
const View = preload("res://demo/views/floor_view.tscn")
const Appearance = preload("res://demo/views/floor_appearance.gd")
const Support = preload("res://simulation/tests/floor_segment_support.gd")
const Actor = preload("res://simulation/actors/shared_actor.tscn")
const NPCSource = preload("res://simulation/components/npc_input_source.gd")
const Sonar = preload("res://demo/components/mission_sonar.gd")
class RawSource extends Node:
	var raw := {}
	func sample_raw(_actor: Node, _dt: float) -> Dictionary: return raw.duplicate(true)
	func reset_intent() -> void: raw.clear()
class Policy extends Node:
	var intent := {}
	func sample_intent(_actor: Node, _dt: float) -> Dictionary: return intent.duplicate(true)
	func reset_intent() -> void: intent.clear()
var hz := 60
var checks := 0
var failures: Array[String] = []
var world: Node2D
var pc: Node2D
var npc: Node2D
const OFFSET := Vector2(1000,0)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func begin() -> void:
	world=Node2D.new();root.add_child(world)
func end() -> void:
	world.queue_free(); await frames(3)
func surface(at: Vector2, size: Vector2):
	var p=Floor.instantiate();p.position=at;p.segment_size=size;world.add_child(p);return p
func pair(at: Vector2) -> void:
	pc=Actor.instantiate();pc.position=at
	var raw:=RawSource.new();raw.name="InputSource";pc.add_child(raw);world.add_child(pc)
	npc=Actor.instantiate();npc.position=at+OFFSET
	var source:=NPCSource.new();source.name="InputSource";npc.add_child(source)
	var policy:=Policy.new();policy.name="PatrolPolicy";npc.add_child(policy);world.add_child(npc)
func input(move:=Vector2.ZERO, jump:=false) -> void:
	pc.get_node("InputSource").raw={"left":maxf(0,-move.x),"right":maxf(0,move.x),"down":maxf(0,move.y),"up":maxf(0,-move.y),"jump":jump}
	npc.get_node("PatrolPolicy").intent={"move":move,"jump":jump}
func equal(label: String) -> void:
	check(pc.position.distance_to(npc.position-OFFSET)<0.05 and pc.velocity.distance_to(npc.velocity)<0.05 and pc.grounded==npc.grounded,label)
func cached_contours(sonar: Node) -> Array:
	var result: Array=[]
	for record in sonar.geometry:
		result.append({"a":record.a,"b":record.b,"transform":record.anchor.get_ref().global_transform})
	return result
func _run() -> void:
	var legacy:=Support.legacy_room_script()
	for data in preload("res://demo/mission_data.gd").sectors():
		begin()
		var old=legacy.new();var fresh=preload("res://demo/components/mission_room.gd").new()
		world.add_child(old);world.add_child(fresh);old.build(data);fresh.build(data)
		check(Support.topology(old,[])==Support.topology(fresh,[]),str(data.get("title","room"))+" exact ordered physical topology")
		check(Support.contours(old)==Support.contours(fresh),"exact ordered collision-derived sonar contours")
		check(old.floor_rects==fresh.floor_rects,"authored floor rectangles unchanged")
		await end()
	begin()
	var first=surface(Vector2(100,200),Vector2(200,80));var second=surface(Vector2(500,200),Vector2(160,60))
	var shape=first.get_node("Support/CollisionShape2D");var body=first.get_node("Support")
	check(not first is PhysicsBody2D and body is StaticBody2D and shape.get_parent()==body,"root places/configures; composed existing static support owns physics")
	check(shape.shape.size==Vector2(200,80) and first.get_node("View").segment_size==shape.shape.size,"physical and visual dimensions synchronized")
	check(not shape.one_way_collision and shape.one_way_collision_margin==1.0 and body.collision_layer==1 and body.collision_mask==0 and body.physics_material_override==null,"original solid support defaults")
	check(body.appearance==null and body.get_node("View").appearance==null,"composed platform paint is disabled")
	check(first.appearance!=second.appearance and shape.shape!=second.get_node("Support/CollisionShape2D").shape,"independent default appearance and collider")
	var sonar:=Sonar.new();world.add_child(sonar);sonar.tuning=preload("res://resources/sensory/sonar_default.tres").duplicate(true);sonar.tuning.sample_spacing=12;sonar.tuning.max_geometry_segments=12000;sonar.bind_level(world,null)
	var original:=Support.contours(first)
	first.segment_size=Vector2(240,55);first.hatch_reference_x=-40.75
	var material:=PhysicsMaterial.new();material.friction=0.6;material.bounce=0.1;first.physics_material=material
	sonar.refresh_geometry()
	check(shape.shape.size==Vector2(240,55) and second.get_node("Support/CollisionShape2D").shape.size==Vector2(160,60),"resize changes only owned shape")
	check(body.physics_material_override==material and second.get_node("Support").physics_material_override==null,"material forwarded to actual body without leaking to peer")
	check(first.get_node("View").hatch_reference_x==-40.75,"authored hatch reference forwarded")
	check(cached_contours(sonar)==Support.contours(world) and Support.contours(first)!=original,"cached sonar refresh uses edited physical rectangle")
	var retired=first.appearance;first.appearance=Appearance.new()
	check(not retired.changed.is_connected(first.get_node("View").queue_redraw),"old appearance redraw subscription disconnected")
	var geometry:=Support.contours(first);first.appearance.fill=Color.RED;first.get_node("View").hide()
	check(Support.contours(first)==geometry,"paint and visibility cannot change physical sonar")
	first.segment_size=Vector2(NAN,3);first.segment_size=Vector2.ZERO;first.segment_size=Vector2(-1,80);first.hatch_reference_x=INF
	check(first.segment_size==Vector2(240,55) and first.hatch_reference_x==-40.75,"invalid configuration rejected retaining valid values")
	var pack:=PackedScene.new();check(pack.pack(first)==OK,"configured floor packs")
	check(ResourceSaver.save(pack,"user://floor_segment_roundtrip.tscn")==OK,"configured floor saves")
	var restored=load("user://floor_segment_roundtrip.tscn").instantiate();world.add_child(restored)
	check(restored.segment_size==first.segment_size and restored.hatch_reference_x==-40.75 and restored.appearance.fill==Color.RED and restored.physics_material.friction==material.friction and restored.get_node("Support/CollisionShape2D").shape.size==first.segment_size,"dimensions appearance phase material survive reload")
	var detached=View.instantiate();world.add_child(detached);check(detached.get_child_count()==0,"detached view has no physics or mission dependency")
	first.get_node("View").free();first.appearance=null;first.segment_size=Vector2(260,60)
	check(shape.shape.size==Vector2(260,60),"physics remains configurable without optional view")
	var nested:=Node2D.new();nested.position=Vector2(35,21);nested.rotation=0.2;world.add_child(nested)
	var inner:=Node2D.new();inner.position=Vector2(-12,35);inner.rotation=-0.1;nested.add_child(inner)
	var transformed=Floor.instantiate();transformed.position=Vector2(100,60);transformed.segment_size=Vector2(180,30);transformed.hatch_reference_x=19.5;inner.add_child(transformed)
	check(transformed.get_node("View").global_transform==transformed.get_node("Support/CollisionShape2D").global_transform,"nested translated rotated view and collider coincide")
	nested.position+=Vector2(11.25,16);nested.rotation+=0.1
	check(transformed.hatch_reference_x==19.5,"placement transforms do not rewrite authored hatch phase")
	sonar.refresh_geometry();check(cached_contours(sonar)==Support.contours(world),"cached sonar honors nested live transforms")
	transformed.queue_free();await frames(2);sonar.refresh_geometry();check(cached_contours(sonar)==Support.contours(world),"removal clears cached sonar ghost")
	var replacement=Floor.instantiate();inner.add_child(replacement);sonar.refresh_geometry();check(cached_contours(sonar)==Support.contours(world),"replacement registers actual collider in sonar")
	await end()
	# Same actual shared actor; only fixture placement and raw/intent input are assigned.
	begin()
	for offset in [Vector2.ZERO,OFFSET]: surface(Vector2(200,240)+offset,Vector2(300,80))
	pair(Vector2(180,100));await frames(hz)
	check(pc.grounded and npc.grounded and absf(pc.position.y-200)<1,"both actors fall onto real floor");equal("landing parity")
	input(Vector2.DOWN,true);await frames(3);input();await frames(hz)
	check(pc.grounded and npc.grounded and absf(pc.position.y-200)<1,"down jump cannot drop through solid floor");equal("solid down jump parity")
	input(Vector2.RIGHT);await frames(hz)
	check(not pc.grounded and not npc.grounded and pc.position.y>210,"both walk off real segment into open gap");equal("gap fall parity")
	await end()
	begin()
	for offset in [Vector2.ZERO,OFFSET]:
		surface(Vector2(200,340)+offset,Vector2(500,80))
		surface(Vector2(200,254)+offset,Vector2(300,18))
	pair(Vector2(180,300));await frames(8);input(Vector2.ZERO,true)
	var highest:=300.0
	for i in range(hz):
		await frames(1);highest=minf(highest,pc.position.y)
		if i==ceili(hz*0.4): input()
		equal("solid underside PC/NPC parity tick "+str(i))
	check(highest>290 and pc.grounded and absf(pc.position.y-300)<1,"thin configured floor still blocks upward passage")
	await end()
	begin()
	var supports: Array=[]
	for offset in [Vector2.ZERO,OFFSET]: supports.append(surface(Vector2(200,240)+offset,Vector2(400,80)))
	pair(Vector2(180,200));await frames(8);check(pc.grounded and npc.grounded,"both supported before removal")
	for p in supports: p.get_node("View").hide()
	await frames(8);check(pc.grounded and npc.grounded,"view hiding preserves real support")
	for p in supports: p.queue_free()
	await frames(ceili(hz*0.3));check(not pc.grounded and not npc.grounded and pc.position.y>210,"asset removal causes actual support loss");equal("support deletion parity")
	await end()
	var report={"hz":hz,"checks":checks,"failures":failures,"scope":"Actual physics frames at requested tick rate; raw/intent fixture inputs and initial placement; no assigned motion outcome. Rendering separate."}
	FileAccess.open("res://simulation/evidence/floor_segment_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FLOOR SEGMENT ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
