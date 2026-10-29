extends SceneTree
const Platform = preload("res://simulation/world/static_platform.tscn")
const View = preload("res://demo/views/platform_view.tscn")
const Appearance = preload("res://demo/views/platform_appearance.gd")
const Support = preload("res://simulation/tests/static_platform_support.gd")
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
func surface(at: Vector2, size: Vector2, one_way := false):
	var p=Platform.instantiate();p.position=at;p.platform_size=size;p.one_way_collision=one_way;world.add_child(p);return p
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
		check(Support.topology(old,[])==Support.topology(fresh,[]),str(data.get("name","room"))+" exact ordered physical topology")
		check(Support.contours(old)==Support.contours(fresh),"exact ordered collision-derived sonar contours")
		await end()
	begin()
	var first=surface(Vector2(100,200),Vector2(200,18),true)
	var second=surface(Vector2(500,200),Vector2(160,60))
	check(first.get_node("CollisionShape2D").shape.size==Vector2(200,18),"configured shape ready")
	check(first.get_node("CollisionShape2D").one_way_collision and first.get_node("CollisionShape2D").one_way_collision_margin==1.0,"configured one-way default margin")
	check(first.get_node("View").platform_size==Vector2(200,18),"view size matches physical size")
	check(first.appearance!=second.appearance and first.get_node("CollisionShape2D").shape!=second.get_node("CollisionShape2D").shape,"instance resources independent")
	var sonar:=Sonar.new();world.add_child(sonar);sonar.tuning=preload("res://resources/sensory/sonar_default.tres").duplicate(true);sonar.tuning.sample_spacing=12;sonar.tuning.max_geometry_segments=12000;sonar.bind_level(world,null)
	var old_contours:=Support.contours(first)
	first.platform_size=Vector2(240,55);first.one_way_collision=false;first.one_way_collision_margin=3.0
	sonar.refresh_geometry()
	check(first.get_node("CollisionShape2D").shape.size==Vector2(240,55) and second.get_node("CollisionShape2D").shape.size==Vector2(160,60),"live size edit changes only owned shape")
	check(cached_contours(sonar)==Support.contours(world),"cached production sonar refresh uses updated real shape")
	check(Support.contours(first)!=old_contours,"actual contour changes with geometry")
	check(not first.get_node("CollisionShape2D").one_way_collision and first.get_node("CollisionShape2D").one_way_collision_margin==3.0,"live one-way and margin configuration")
	var retired_appearance=first.appearance
	first.appearance=Appearance.new()
	check(not retired_appearance.changed.is_connected(first.get_node("View").queue_redraw),"replaced appearance disconnects old redraw subscription")
	var geometry:=Support.contours(first);first.appearance.fill=Color.RED;first.get_node("View").hide()
	check(Support.contours(first)==geometry and first.collision_layer==1 and first.collision_mask==0,"appearance and visibility cannot change collision or sonar")
	first.platform_size=Vector2(NAN,3);first.platform_size=Vector2.ZERO;first.one_way_collision_margin=-1
	check(first.platform_size==Vector2(240,55) and first.one_way_collision_margin==3.0,"invalid geometry rejected without corrupting valid state")
	var pack:=PackedScene.new();check(pack.pack(first)==OK,"edited platform packs")
	check(ResourceSaver.save(pack,"user://static_platform_roundtrip.tscn")==OK,"edited platform saves")
	var restored=load("user://static_platform_roundtrip.tscn").instantiate();world.add_child(restored)
	check(restored.platform_size==first.platform_size and restored.appearance.fill==Color.RED and restored.get_node("CollisionShape2D").shape.size==first.platform_size,"configuration survives save/reload")
	var detached=View.instantiate();detached.platform_size=Vector2(123,33);world.add_child(detached)
	check(detached.get_child_count()==0,"appearance view runs without physical or mission host")
	var shape=first.get_node("CollisionShape2D");first.get_node("View").free();first.appearance=Appearance.new();first.platform_size=Vector2(260,60)
	check(shape.shape.size==Vector2(260,60),"physics remains configurable without optional view")

	var nested:=Node2D.new();nested.position=Vector2(35,21);nested.rotation=0.2;world.add_child(nested)
	var transformed=Platform.instantiate();transformed.position=Vector2(100,60);transformed.platform_size=Vector2(180,30);nested.add_child(transformed)
	check(transformed.get_node("View").global_transform==transformed.get_node("CollisionShape2D").global_transform,"nested translated/rotated view and physical shape share transform")
	sonar.refresh_geometry();check(cached_contours(sonar)==Support.contours(world),"cached sonar honors nested live transforms")
	transformed.queue_free();await frames(2);sonar.refresh_geometry()
	check(cached_contours(sonar)==Support.contours(world),"removed platform leaves no cached sonar ghost")
	var replacement=Platform.instantiate();nested.add_child(replacement);sonar.refresh_geometry()
	check(cached_contours(sonar)==Support.contours(world),"new standalone platform enters live sonar geometry")
	await end()
	# Actual common actor, driven by raw PC inputs versus NPC intent. Initial placement only.
	for one_way in [false,true]:
		begin()
		for offset in [Vector2.ZERO,OFFSET]: surface(Vector2(200,209)+offset,Vector2(300,18),one_way)
		pair(Vector2(180,100));await frames(hz)
		check(pc.grounded and npc.grounded and absf(pc.position.y-200)<1,"both actors fall and settle on "+str(one_way))
		equal("matching actual support trajectories")
		input(Vector2.RIGHT);await frames(hz)
		check(not pc.grounded and not npc.grounded and pc.position.y>210,"both actors walk off real support and fall")
		equal("matching actual support loss")
		await end()
	# Upward passage is a physics result, not a forced launch/teleport.
	for one_way in [false,true]:
		begin()
		for offset in [Vector2.ZERO,OFFSET]:
			surface(Vector2(200,320)+offset,Vector2(500,40))
			surface(Vector2(200,254)+offset,Vector2(300,18),one_way)
		pair(Vector2(180,300));await frames(8);input(Vector2.ZERO,true)
		var highest:=300.0
		for i in range(hz):
			await frames(1);highest=minf(highest,pc.position.y)
			if i==ceili(hz*0.4): input()
			equal("jump PC/NPC parity "+str(one_way)+" tick "+str(i))
		print("JUMP ",one_way," highest=",highest," final=",pc.position," grounded=",pc.grounded)
		check(highest<245 if one_way else highest>290,"upward passage only through one-way platform")
		check(pc.grounded and absf(pc.position.y-(245.0 if one_way else 300.0))<1,"downward catch versus solid underside")
		if one_way:
			input(Vector2.DOWN,true);await frames(3);input();await frames(hz)
			check(pc.grounded and npc.grounded and absf(pc.position.y-300)<1,"ordinary down+jump drops both through actual support")
			equal("targeted drop cleanup parity")
		await end()
	begin()
	var supports: Array=[]
	for offset in [Vector2.ZERO,OFFSET]: supports.append(surface(Vector2(200,220)+offset,Vector2(400,40)))
	pair(Vector2(180,200));await frames(8)
	check(pc.grounded and npc.grounded,"actors supported before removal")
	for p in supports: p.queue_free()
	await frames(ceili(hz*0.3))
	check(not pc.grounded and not npc.grounded and pc.position.y>210,"removing actual asset removes both supports")
	await end()
	var report={"hz":hz,"checks":checks,"failures":failures,"scope":"Actual physics frames at requested tick rate; raw/intent fixture inputs and initial placement; no assigned motion outcome. Rendering is separate."}
	FileAccess.open("res://simulation/evidence/static_platform_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STATIC PLATFORM ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
