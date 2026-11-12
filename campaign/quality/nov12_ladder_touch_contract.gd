extends SceneTree
class Host extends Node2D:
	var state:="playing"
	var _loading_campaign:=false
	var session_generation:=0
	var blind:=true
	var player:Node2D
	var room:=Node2D.new()
	var camera:=Node2D.new()
class Driver extends Node:
	var player:Node
	var frame:Dictionary={}
	var ticks:=0
	func _physics_process(dt:float)->void:
		player.physics_tick(dt,frame);ticks+=1
var host:Host
var driver:Driver
var observer:Node
var ladder:Area2D
var failures:Array[String]=[]
var checks:=0
var hz:=60
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func body(rect:Rect2)->StaticBody2D:
	var node:=StaticBody2D.new();node.position=rect.get_center()
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collider.shape=shape
	node.add_child(collider);host.room.add_child(node);return node
func setup(on:=true)->void:
	host=Host.new();root.add_child(host);host.add_child(host.room);host.add_child(host.camera)
	body(Rect2(-200,300,800,40))
	ladder=load("res://simulation/world/mission_ladder.tscn").instantiate();ladder.position=Vector2(100,300);ladder.height=160;host.room.add_child(ladder)
	host.player=load("res://combat_pc/player.tscn").instantiate();host.player.automatic_physics=false;host.player.position=Vector2(75,300);host.room.add_child(host.player)
	driver=Driver.new();driver.player=host.player;host.add_child(driver)
	observer=load("res://campaign/perception/ladder_touch_observer.gd").new();host.add_child(observer);observer.bind(host);observer.enabled=on
func step(frame:Dictionary={},count:=1)->void:
	driver.frame=frame
	for i in count:
		var until:=driver.ticks+1
		while driver.ticks<until:await physics_frame;await process_frame
func finish()->void:
	host.free();host=null;driver=null;observer=null;ladder=null;await process_frame
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	if hz not in [60,120]:quit(2);return
	Engine.physics_ticks_per_second=hz
	call_deferred("run")
func run()->void:
	setup();await step({},3)
	check(observer.read_snapshot().is_empty(),"outside actual reach does not reveal ladder")
	await step({"right":1.0},ceili(hz/12.0))
	check(not observer.read_snapshot().is_empty(),"ordinary movement enters actual body overlap")
	var contact:Dictionary=observer.read_snapshot()
	if contact.is_empty():await finish();quit(1);return
	check(contact.keys().size()==2 and contact.has("segments") and contact.has("held"),"only clipped fragment and held flag cross boundary")
	check(contact.segments.size()<=10 and not contact.held,"at most two rails three rungs, touch not automatic grab")
	for point in contact.segments:
		check(absf(point.x)<=30 and point.y>=-host.player.body_height*.5-18.01 and point.y<=-host.player.body_height*.5+18.01,"body-local clipped fragment")
	host.blind=false;check(observer.read_visible_snapshot().is_empty(),"retained sight draws no additional ladder art");host.blind=true
	await step({"up":1.0},ceili(hz*.2))
	check(host.player.main_action==&"climb","normal input commits real climb")
	check(observer.read_snapshot().get("held",false),"held flag comes from actual controller")
	await step({"right":1.0,"jump":true},ceili(hz/30.0))
	await step({"right":1.0},ceili(hz*.25))
	check(observer.read_snapshot().is_empty(),"ordinary jump-away loses contact, no trail")
	# Explicit seeded negative configurations below; not a natural traversal claim.
	host.player.reset_actor(Vector2(84,300),1);await step({},2)
	check(not observer.read_snapshot().is_empty(),"reachable ladder fixture")
	var wall:=body(Rect2(94,250,4,50));await step({},2)
	check(observer.read_snapshot().is_empty(),"short obstruction rejects touch through thin wall")
	wall.free();await step({},2)
	check(not observer.read_snapshot().is_empty(),"removing obstruction restores local touch")
	ladder.enabled=false;check(observer.read_snapshot().is_empty(),"same-frame disabled geometry fenced");await step()
	check(observer.snapshot.is_empty(),"disabled ladder retires on physics sample");ladder.enabled=true
	await step({},2)
	ladder.position.x+=100;check(observer.read_snapshot().is_empty(),"moved target invalidates old fragment immediately");await step()
	check(observer.snapshot.is_empty(),"moved-away ladder not retained")
	ladder.width=128;host.player.reset_actor(Vector2(145,300),1);await step({},2)
	check(observer.read_snapshot().is_empty(),"oversized sensor cannot enlarge actual reach")
	ladder.width=20;ladder.position.x=100;host.player.reset_actor(Vector2(100,100),1);await step({},2)
	check(observer.read_snapshot().is_empty(),"above actual ladder span")
	host.player.reset_actor(Vector2(84,300),1);await step({},2)
	host.session_generation+=1;check(observer.read_snapshot().is_empty(),"same-frame session fence");await step()
	host.state="dead";check(observer.read_snapshot().is_empty(),"death fence");await step()
	check(observer.snapshot.is_empty(),"death retires contact");host.state="playing";await step({},2)
	host.state="journal";check(observer.read_snapshot().is_empty(),"modal fence");host.state="playing"
	await step({},2)
	paused=true;check(observer.read_snapshot().is_empty(),"paused tree hides contact before callback")
	await process_frame;check(observer.snapshot.is_empty(),"pause retires contact");paused=false
	await step({},2)
	ladder.collision_layer=0;check(observer.read_snapshot().is_empty(),"collision mask retirement immediate")
	await step();check(observer.snapshot.is_empty(),"layer zero not sampled");ladder.collision_layer=16
	await step({},2)
	ladder.get_node("SensorShape").set_deferred("disabled",true);await step({},2)
	check(observer.read_snapshot().is_empty(),"disabled sensor excluded")
	ladder.get_node("SensorShape").set_deferred("disabled",false);await step({},2)
	ladder.reparent(root,true);check(observer.read_snapshot().is_empty(),"foreign-room contact cannot persist")
	await step();check(observer.snapshot.is_empty(),"foreign-room collider excluded by provenance")
	ladder.reparent(host.room,true);await step({},2)

	ladder.queue_free();check(observer.read_snapshot().is_empty(),"queued deletion cannot draw stale fragment");await step()
	check(observer.snapshot.is_empty(),"freed contact excluded")
	await finish()
	var traces:Array=[]
	for on in [false,true]:
		setup(on);var trace:Array=[]
		await step({},3)
		for i in ceili(hz*1.5):
			var frame:Dictionary={"right":1.0} if i<ceili(hz/12.0) else ({"up":1.0} if i<ceili(hz*35/60.0) else ({"right":1.0,"jump":true} if i<ceili(hz*37/60.0) else {"right":1.0}))
			await step(frame)
			trace.append([host.player.position,host.player.velocity,host.player.main_action,host.player.grounded])
		traces.append(trace);await finish()
	check(traces[0]==traces[1],"contact presentation on/off preserves1.5s real-physics movement/action frames")
	print("LADDER_TOUCH_RESULT ",JSON.stringify({"passed":failures.is_empty(),"physics_hz":Engine.physics_ticks_per_second,"checks":checks,"failures":failures,"scope":"Real actor/ladder physics with input-frame driver and explicitly seeded negatives; not screen-only play acceptance"}))
	quit(0 if failures.is_empty() else 1)
