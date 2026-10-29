extends SceneTree
## Real continuous-course telemetry comparison; visual files only.
const PLAYER=preload("res://combat_pc/player.tscn")
const COURSE=preload("res://combat_pc/fixtures/slope_course.tscn")
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
class Driver extends Node:
	var actor:Node
	var input_frame:Dictionary={}
	var ticks:=0
	func _physics_process(dt:float) -> void:actor.physics_tick(dt,input_frame);ticks+=1
var checks:=0
var failures:Array[String]=[]
var rows:Array=[]
var samples:Array=[]
func _init() -> void:Engine.physics_ticks_per_second=120;_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run() -> void:
	var initial_hash:=FileAccess.get_sha256("res://combat_pc/player.gd")
	for direction in [-1,1]:await _course(direction)
	check(initial_hash==FileAccess.get_sha256("res://combat_pc/player.gd"),"motor hash stayed stable during visual integration")
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"motor_sha256":initial_hash,"scope":"Actual120Hz slope-course snapshots, real grounded ordinary pose fit and a shadow view with original flat support; special actions excluded","rows":rows}
	FileAccess.open("res://combat_pc/visuals/tests/slope_motor_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/slope_motor_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original vectors sampled from real engine snapshots; still not a native capture","samples":samples},"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _course(direction:int) -> void:
	var world:=Node2D.new();root.add_child(world)
	var floor_body=COURSE.instantiate();floor_body.position=Vector2(0,300);world.add_child(floor_body)
	var actor=PLAYER.instantiate();actor.position=Vector2(20 if direction>0 else 820,300);actor.automatic_physics=false;world.add_child(actor)
	var visual=actor.get_node("Visual");var former=Visual.new();actor.movement_event.connect(former.event)
	var driver:=Driver.new();driver.actor=actor;driver.process_physics_priority=20;world.add_child(driver)
	var plane_error:=0.0;var old_gap:=0.0;var reach_error:=0.0;var compression:=0.0;var grounded_samples:=0;var plants:=0
	var normals:Dictionary={};var last_normal:=Vector2.UP;var changes:=0;var sampled:Dictionary={}
	var held_locations:Dictionary={};var hold_remaining:=0;var idle_samples:=0
	for i in range(680):
		driver.input_frame={"right":1.0} if direction>0 else {"left":1.0}
		for location in [150,335,495,675]:
			if absf(actor.position.x-location)<4 and not held_locations.has(location):held_locations[location]=true;hold_remaining=32
		if hold_remaining>0:driver.input_frame={};hold_remaining-=1
		if i<4:driver.input_frame={}
		var target:=driver.ticks+1
		while driver.ticks<target:await physics_frame;await process_frame
		var t:Dictionary=actor.telemetry();var pose:Dictionary=visual.get_pose()
		var former_t:=t.duplicate(true);former_t.erase("floor_contact_point");former.present(1.0/120,former_t)
		if t.grounded and bool(pose.get("slope_support",false)):
			grounded_samples+=1
			if pose.mode=="idle":idle_samples+=1
			var n:Vector2=t.floor_normal
			var label:String="%+.1f"%rad_to_deg(Vector2.UP.angle_to(n));normals[label]=true
			if last_normal.distance_to(n)>0.01:changes+=1
			last_normal=n
			compression=maxf(compression,float(pose.slope_hip_settle))
			check(pose.facing==t.facing,"actual slope fit keeps physical facing")
			for index in 2:
				var side:String="near" if index==0 else "far"
				if pose.planted_feet[index]:
					plants+=1
					for foot in ["sole_","toe_","heel_"]:
						var point:Vector2=Vector2(t.position)+Vector2(pose.bones[foot+side])
						plane_error=maxf(plane_error,absf((point-Vector2(t.floor_contact_point)).dot(n)))
				var old:Dictionary=former.get_pose()
				if old.planted_feet[index]:old_gap=maxf(old_gap,absf((Vector2(t.position)+Vector2(old.bones["sole_"+side])-Vector2(t.floor_contact_point)).dot(n)))
				reach_error=maxf(reach_error,absf(Vector2(pose.bones["hip_"+side]).distance_to(pose.bones["knee_"+side])-8))
				reach_error=maxf(reach_error,absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-8))
			if not sampled.has(label) and plants>0:
				sampled[label]=true;samples.append({"label":"direction%d normal%s"%[direction,label],"pose":_encode(pose),"telemetry":_encode(t)})
		elif t.grounded:last_normal=Vector2.UP
		if (direction>0 and actor.position.x>805) or (direction<0 and actor.position.x<35):break
	check(grounded_samples>80 and plants>40,"actual course exercises supported slope pose samples")
	check(idle_samples>20,"actual course exercises stationary idle on inclined support")
	check(normals.size()>=4 and changes>=4,"continuous collider exercises mirrored26.6/45degree normal transitions")
	check(plane_error<0.002 and reach_error<0.002,"actual supported soles fit the confirmed plane without leg stretch")
	check(old_gap>2.0,"real telemetry reproduces the previous flat-foot plane error")
	check(compression<=4,"actual slope joint compression remains bounded")
	rows.append({"direction":direction,"normal_degrees":normals.keys(),"normal_changes":changes,"grounded_slope_samples":grounded_samples,"idle_slope_samples":idle_samples,"planted_samples":plants,"old_flat_foot_gap_px":old_gap,"corrected_sole_plane_error_px":plane_error,"leg_length_error_px":reach_error,"maximum_joint_compression_px":compression})
	former.free();world.queue_free();await physics_frame;await process_frame
func _encode(value:Variant) -> Variant:
	if value is Vector2:return [value.x,value.y]
	if value is Dictionary:
		var out:Dictionary={}
		for key in value:out[key]=_encode(value[key])
		return out
	if value is Array:
		var out:Array=[]
		for item in value:out.append(_encode(item))
		return out
	return value
