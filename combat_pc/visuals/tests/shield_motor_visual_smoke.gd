extends SceneTree
## Real actor/fixture events observed by the passive shield view; no synthetic hit.
const PLAYER=preload("res://combat_pc/player.tscn")
const SURFACE=preload("res://combat_pc/fixtures/test_surface.tscn")
const MELEE=preload("res://combat_pc/fixtures/guard_melee_fixture.tscn")
const BULLET=preload("res://combat_pc/fixtures/guard_projectile_fixture.tscn")
class Driver extends Node:
	var actor:Node;var frame:Dictionary={};var ticks:=0
	func _physics_process(dt:float) -> void:actor.physics_tick(dt,frame);ticks+=1
var world:Node2D;var actor:Node;var visual:Node;var driver:Driver
var events:Array=[];var checks:=0;var failures:Array[String]=[];var rows:Array=[]
var band_error:=0.0
func _init() -> void:Engine.physics_ticks_per_second=120;_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run() -> void:
	var paths=["res://combat_pc/player.gd","res://combat_pc/resources/shield_profile.gd","res://combat_pc/components/shield_contact_adapter.gd","res://combat_pc/fixtures/guard_melee_fixture.gd","res://combat_pc/fixtures/guard_projectile.gd","res://combat_pc/fixtures/guard_projectile_fixture.gd","res://combat_pc/resources/shield_profile.tres","res://combat_pc/visuals/wireframe.gd","res://combat_pc/visuals/wireframe_pose.gd","res://combat_pc/visuals/shield_keys.gd","res://combat_pc/visuals/shield_pose.gd","res://combat_pc/visuals/slope_pose.gd"]
	var hashes:Dictionary={}
	for path in paths:hashes[path]=FileAccess.get_sha256(path)
	for facing in [-1,1]:
		await _phases(facing)
		for kind in ["counter","failed_counter","reflect","guard"]:await _contact(kind,facing)
	for path in paths:check(hashes[path]==FileAccess.get_sha256(path),"physical source remained stable during shield view integration "+path)
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"hashes":hashes,"maximum_band_center_error_px":band_error,"scope":"Actual120Hz motor phases and real swept melee/projectile contacts observed by original shield view; no native gameplay capture","scenarios":rows}
	FileAccess.open("res://combat_pc/visuals/tests/shield_motor_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _begin(facing:int) -> void:
	world=Node2D.new();root.add_child(world)
	var floor_body=SURFACE.instantiate();floor_body.position=Vector2(-1000,200);floor_body.size=Vector2(3000,40);world.add_child(floor_body)
	actor=PLAYER.instantiate();actor.position=Vector2(100,200);actor.automatic_physics=false;world.add_child(actor)
	visual=actor.get_node("Visual");events=[]
	actor.movement_event.connect(func(key:StringName,payload:Dictionary):events.append({"event":String(key),"payload":payload.duplicate(true)}))
	driver=Driver.new();driver.actor=actor;driver.process_physics_priority=20;world.add_child(driver)
	await _step({"left":1.0} if facing<0 else {"right":1.0},1);await _step({},20)
func _step(frame:Dictionary,count:int=1) -> void:
	driver.frame=frame
	for i in count:
		var target:=driver.ticks+1
		while driver.ticks<target:await physics_frame;await process_frame
		var t:Dictionary=actor.telemetry();var pose:Dictionary=visual.get_pose()
		if bool(t.shield_active) and pose.has("shield"):
			band_error=maxf(band_error,(Vector2(pose.shield.center)+Vector2(t.position)).distance_to(t.shield_center))
			check(not pose.weapon.visible and pose.facing==t.shield_facing,"live guard replaces sword and follows motor facing")
			check(pose.shield.grip==pose.bones.palm_near and pose.shield.attached,"actual guard stays anatomically attached")
			if not t.grounded:check(pose.planted_feet==[false,false],"real airborne guard has no planted feet")
func _until(test:Callable,frame:Dictionary,limit:int=180) -> bool:
	for i in limit:
		if test.call():return true
		await _step(frame)
	return bool(test.call())
func _finish() -> void:
	world.queue_free();await physics_frame;await process_frame
func _phases(facing:int) -> void:
	await _begin(facing)
	await _step({"shield":true})
	check(await _until(func():return actor.shield_phase==&"hold",{"shield":true}),"fresh held input reaches real indefinite guard")
	await _step({"shield":true,"down":1.0},4)
	check(actor.body_height<=20.1 and visual.get_pose().shield.size==actor.telemetry().shield_size,"held guard follows real crouch clearance and band change")
	await _step({})
	check(actor.shield_phase==&"release_recovery" and visual.pose_name=="shield_release_recovery","release recovery is motor-owned")
	check(await _until(func():return actor.shield_phase==&"idle",{}),"release completes without view completion dependency")
	await _step({},40);await _step({"shield":true});await _step({})
	check(await _until(func():return actor.shield_phase==&"miss_recovery",{}),"short tap reaches original missed-parry recovery")
	check(visual.pose_name=="shield_miss_recovery","real miss has distinct visual owner")
	await _until(func():return actor.shield_phase==&"idle",{});await _step({},40)
	await _step({"jump":true});await _step({},7);await _step({"shield":true},5)
	check(not actor.grounded and visual.pose_name.begins_with("shield_"),"normal airborne shield admission keeps flight")
	await _until(func():return actor.grounded,{"shield":true},180)
	check(actor.grounded and visual.pose_name.begins_with("shield_"),"real landing retains live guard ownership")
	var phases:Array=[]
	for event in events:
		if event.event=="shield_phase_changed" and not phases.has(str(event.payload.phase)):phases.append(str(event.payload.phase))
	rows.append({"kind":"phase_flow","facing":facing,"phases":phases})
	await _finish()
func _contact(kind:String,facing:int) -> void:
	await _begin(facing)
	var fixture=BULLET.instantiate() if kind=="reflect" else MELEE.instantiate()
	fixture.position=actor.position+Vector2(facing*(48 if kind=="reflect" else 40),0);fixture.direction=-facing
	if kind=="failed_counter":fixture.accepts_counter=false
	world.add_child(fixture)
	if kind=="guard":
		await _step({"shield":true});await _until(func():return actor.shield_phase==&"hold",{"shield":true})
		check(fixture.request_attack(),"real guard fixture accepts attack request")
	elif kind=="reflect":
		await _step({"shield":true});check(fixture.fire_projectile()!=null,"real projectile is launched")
	else:
		check(fixture.request_attack(),"real melee fixture accepts attack request")
		await _until(func():return fixture.phase==&"active",{})
		await _step({"shield":true})
	check(await _until(func():return fixture.contacts>0,{"shield":true}),"real swept contact reaches the actor "+kind)
	await _step({"shield":true},2) # Incoming fixtures resolve after the actor's present slot.
	var result:Dictionary=fixture.last_result
	check(str(result.get("outcome",""))==("guarded" if kind=="guard" else "parried"),"physical defense outcome matches fixture "+kind)
	var kinds:Array=[];var world_error:=0.0
	var pose:Dictionary=visual.get_pose()
	if pose.has("shield"):
		for marker in pose.shield.feedback:
			kinds.append(str(marker.kind));world_error=maxf(world_error,(Vector2(marker.point)+actor.global_position).distance_to(Vector2(result.contact_position)))
	check(kinds.has("guarded" if kind=="guard" else "parried"),"incoming contact feedback follows actual result "+kind)
	check(kinds.has("counter")== (kind=="counter"),"counter visual requires separately accepted outgoing counter")
	check(kinds.has("reflect")== (kind=="reflect"),"reflection visual requires actual redirect acceptance")
	check(world_error<0.002,"all actual defense/effect marks use frozen reported world contact")
	if kind!="guard":check(visual.pose_name=="shield_success_recovery","incoming success owns held impact recovery")
	var local:Dictionary=visual.get_bones();var t:Dictionary=actor.telemetry()
	if bool(t.paused):
		await _step({"shield":true})
		if bool(actor.telemetry().paused):check(visual.get_bones()==local,"real local hitpause holds the shield key")
	rows.append({"kind":kind,"facing":facing,"outcome":result.get("outcome",""),"markers":kinds,"world_contact_error_px":world_error})
	await _finish()
