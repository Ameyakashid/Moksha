extends SceneTree
## Integration observation only: real motor snapshots drive the unchanged passive rig.
const PLAYER=preload("res://combat_pc/player.tscn")
const SURFACE=preload("res://combat_pc/fixtures/test_surface.tscn")
class Driver extends Node:
	var actor:Node
	var input_frame:Dictionary={}
	var ticks:=0
	func _physics_process(dt:float) -> void:
		actor.physics_tick(dt,input_frame);ticks+=1
var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
func _init() -> void:
	Engine.physics_ticks_per_second=120
	_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run() -> void:
	var initial_hash:=FileAccess.get_sha256("res://combat_pc/player.gd")
	for kind in ["ordinary","dive"]:
		for facing in [-1,1]:await _scenario(kind,facing)
	check(initial_hash==FileAccess.get_sha256("res://combat_pc/player.gd"),"motor stayed stable while snapshot integration ran")
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"motor_sha256":initial_hash,"scope":"Actual120Hz physics snapshots observed by original landing rig; no native gameplay capture","observations":observations}
	FileAccess.open("res://combat_pc/visuals/tests/landing_motor_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _scenario(kind:String,facing:int) -> void:
	var world:=Node2D.new();root.add_child(world)
	var floor_body=SURFACE.instantiate();floor_body.position=Vector2(-1000,400);floor_body.size=Vector2(3000,40)
	floor_body.moving=true;floor_body.travel=Vector2(80,0);floor_body.travel_speed=30.0;world.add_child(floor_body)
	var actor=PLAYER.instantiate();actor.position=Vector2(100,0);actor.facing=facing;actor.automatic_physics=false;actor.enable_hard_landing=true;world.add_child(actor)
	var visual=actor.get_node("Visual")
	var driver:=Driver.new();driver.actor=actor;driver.process_physics_priority=20;world.add_child(driver)
	var impact_seen:=false;var recovery_seen:=false;var released:=false;var skid_seen:=false;var plant_seen:=false
	var max_plane_error:=0.0;var max_arm_error:=0.0;var last_phase:="";var trace:Array=[]
	for i in range(230):
		driver.input_frame={"right":1.0} if facing>0 else {"left":1.0}
		if kind=="dive" and i==2:driver.input_frame=driver.input_frame.merged({"down":1.0,"jump":true})
		var target:=driver.ticks+1
		while driver.ticks<target:await physics_frame;await process_frame
		var t:Dictionary=actor.telemetry();var pose:Dictionary=visual.get_pose()
		if t.main_action=="hard_land":
			check(pose.mode=="hard_land_"+String(t.hard_land_phase),"real owner and visual phase match")
			check(String(t.hard_land_kind)==kind,"real contact retains ordinary/dive kind")
			check(pose.facing==t.facing and not pose.weapon.visible,"real hard pose respects facing and removes weapon")
			check(int(t.facing)==facing,"physical fixture reaches requested mirrored facing")
			impact_seen=impact_seen or t.hard_land_phase=="impact";recovery_seen=recovery_seen or t.hard_land_phase=="recovery"
			if t.hard_land_skidding:skid_seen=true;check(pose.planted_feet==[false,false],"real skid never claims planted feet")
			else:plant_seen=true;check(pose.planted_feet==[true,true],"real stopped recovery plants feet")
			for side in ["near","far"]:
				max_arm_error=maxf(max_arm_error,absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-5.8))
				for label in ["sole_","heel_","toe_"]:
					var point:Vector2=Vector2(pose.bones[label+side])+Vector2(t.position)
					max_plane_error=maxf(max_plane_error,absf((point-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal))))
			if String(t.hard_land_phase)!=last_phase:
				last_phase=String(t.hard_land_phase);trace.append({"phase":last_phase,"body_height":t.body_height,"pose_key":pose.key,"skidding":t.hard_land_skidding,"facing":t.facing})
		elif recovery_seen:released=true;check(not String(pose.mode).begins_with("hard_land"),"real release immediately changes visual owner");break
	check(impact_seen and recovery_seen and released,"real fall traverses impact/recovery/release")
	check(plant_seen,"real carrier-supported recovery reaches a stationary plant")
	if kind=="ordinary":check(skid_seen,"ordinary approach produces observed physical skid before stop")
	check(max_plane_error<0.002 and max_arm_error<0.15,"real contact telemetry fits soles and anatomy")
	observations.append({"kind":kind,"facing":facing,"impact":impact_seen,"recovery":recovery_seen,"released":released,"skid":skid_seen,"planted":plant_seen,"floor_plane_error_px":max_plane_error,"trace":trace})
	world.queue_free();await physics_frame;await process_frame
