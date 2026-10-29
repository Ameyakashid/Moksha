extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Keys=preload("res://combat_pc/visuals/wireframe_keys.gd")
const MODES=["idle","start","run","brake","turn","jump","air_jump","jump_rise","jump_apex","fall","land","land_run","crouch","ledge_catch","ledge_hang","ledge_pull","ledge_step"]
var failures:Array[String]=[]
var checks:=0
var metrics:Dictionary={}
var samples:Array=[]

func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func _run() -> void:
	_geometry()
	_mirrors()
	_key_timing()
	_foot_plants()
	_ledge_grips()
	_motion_readability()
	_support_motion()
	_observer_contract()
	await _draw_lifecycle()
	_export()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original MOKSHA presentation geometry and headless lifecycle; vector previews are not gameplay screenshots","source_boundary":"No original Dead Cells sprite poses/timing or source-game selector transplanted"}
	var file:=FileAccess.open("res://combat_pc/visuals/tests/visual_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _snapshot(mode:String,p:float,facing:int=1,drop:float=29.0) -> Dictionary:
	var root:=Vector2.ZERO
	var anchor:=Vector2(facing*9.2,-drop)
	if mode=="ledge_pull":
		anchor.y=lerpf(-drop,1.0,smoothstep(0,1,p))
	elif mode=="ledge_step":
		anchor=Vector2(lerpf(9.2,-12.0,smoothstep(0,1,p))*facing,1.0)
	return {"position":root,"world_position":root,"velocity":Vector2(218*facing,0),"facing":facing,"move_x":facing,"grounded":not mode.begins_with("ledge") and mode not in ["jump","air_jump","jump_rise","jump_apex","fall"],"pose":mode,"phase_progress":p,"palm_target":anchor,"ledge_anchor":anchor,"hang_target":anchor+Vector2(-facing*9.2,drop),"gait_phase":p,"preimpact_speed":520.0,"run_reference_speed":218.0}

func _geometry() -> void:
	var max_arm:=0.0;var max_leg:=0.0;var worst_arm:="";var worst_leg:=""
	var signatures:Dictionary={}
	for mode in MODES:
		var fingerprint:=""
		for n in range(21):
			var p:=float(n)/20.0
			var pose:Dictionary=Pose.evaluate(mode,p,_snapshot(mode,p))
			var b:Dictionary=pose.bones
			check(b.size()==Pose.BONE_NAMES.size(),"complete body geometry "+mode)
			for key in Pose.BONE_NAMES:check(Vector2(b[key]).is_finite(),"finite "+mode+"/"+key)
			for side in ["near","far"]:
				var ae:=absf(Vector2(b["elbow_"+side]).distance_to(b["palm_"+side])-Keys.TUNING.lower_arm)
				var le:=absf(Vector2(b["knee_"+side]).distance_to(b["ankle_"+side])-Keys.TUNING.lower_leg)
				if ae>max_arm:max_arm=ae;worst_arm="%s/%s@%.2f"%[mode,side,p]
				if le>max_leg:max_leg=le;worst_leg="%s/%s@%.2f"%[mode,side,p]
			if n in [0,5,10,15,20]:fingerprint+=str(b.head)+str(b.palm_near)+str(b.knee_near)
			if n in [0,5,10,15]:samples.append({"label":mode,"pose":_encode(pose),"telemetry":_encode(_snapshot(mode,p))})
		signatures[fingerprint]=mode
	metrics["unique_mode_silhouettes"]=signatures.size()
	metrics["maximum_arm_reach_error_px"]=max_arm;metrics["worst_arm"]=worst_arm
	metrics["maximum_leg_reach_error_px"]=max_leg;metrics["worst_leg"]=worst_leg
	check(signatures.size()==MODES.size(),"every milestone pose family has a distinct signature")
	check(max_arm<0.35,"authored hand targets fit arm reach")
	check(max_leg<0.35,"authored foot targets fit leg reach")
	var ready:Dictionary=Pose.evaluate("idle",0,{})
	var crouch:Dictionary=Pose.evaluate("crouch",0,{})
	metrics["standing_head_top_px"]=ready.bones.head.y-2.7
	metrics["crouch_head_top_px"]=crouch.bones.head.y-2.7
	check(absf(float(metrics.standing_head_top_px)+34.0)<0.1,"standing rig is34px with feet at0")
	check(float(metrics.crouch_head_top_px)>=-20.0,"crouch silhouette fits20px clearance authoring target")

func _mirrors() -> void:
	for mode in MODES:
		var r:Dictionary=Pose.evaluate(mode,0.37,_snapshot(mode,0.37,1))
		var l:Dictionary=Pose.evaluate(mode,0.37,_snapshot(mode,0.37,-1))
		for bone in Pose.BONE_NAMES:
			var point:Vector2=r.bones[bone]
			check(Vector2(-point.x,point.y).distance_to(l.bones[bone])<0.001,"facing mirror "+mode+"/"+bone)

func _key_timing() -> void:
	var a:Dictionary=Pose.evaluate("land",0.02,{"preimpact_speed":520})
	var b:Dictionary=Pose.evaluate("land",0.20,{"preimpact_speed":520})
	var recover:Dictionary=Pose.evaluate("land",0.80,{"preimpact_speed":520})
	check(a.bones.pelvis==b.bones.pelvis,"impact key is deliberately held instead of interpolated away")
	check(recover.bones.pelvis.y<a.bones.pelvis.y-3.0,"landing recovers from compressed hips")
	var ground:Dictionary=Pose.evaluate("jump",0.3,{})
	var air:Dictionary=Pose.evaluate("air_jump",0.3,{})
	check(Vector2(ground.bones.palm_near).distance_to(air.bones.palm_near)>5.0,"air jump has a distinct recoil/drive silhouette")
	check(Pose.evaluate("ledge_hang",0,_snapshot("ledge_hang",0)).planted_hands==[true,true],"hang supports both palms")
	check(Pose.evaluate("ledge_pull",0.8,_snapshot("ledge_pull",0.8)).planted_hands==[true,false],"late pull releases far hand while body passes ledge")
	check(Pose.evaluate("ledge_step",0.9,_snapshot("ledge_step",0.9)).planted_feet==[true,true],"late step has both planted feet")

func _foot_plants() -> void:
	var drift:=0.0;var plant_frames:=0;var contacts:=0
	for speed in [60.0,140.0,218.0]:
		var view=Visual.new()
		var previous:Dictionary={};var previous_on:Dictionary={"near":false,"far":false}
		for i in range(360):
			var root:=Vector2(i*speed/120.0,0)
			view.present(1.0/120.0,{"position":root,"velocity":Vector2(speed,0),"facing":1,"grounded":true,"move_x":1,"pose":"run","run_reference_speed":218.0,"tick_id":i})
			var pose:Dictionary=view.get_pose()
			for side_index in 2:
				var side:="near" if side_index==0 else "far"
				var planted:bool=pose.planted_feet[side_index]
				var world:Vector2=root+Vector2(pose.bones["sole_"+side])
				if planted and previous_on[side]:drift=maxf(drift,world.distance_to(previous[side]));plant_frames+=1
				if planted and not previous_on[side]:contacts+=1
				previous[side]=world;previous_on[side]=planted
		view.free()
	metrics["maximum_foot_plant_drift_px"]=drift;metrics["planted_foot_frame_pairs"]=plant_frames;metrics["foot_contacts"]=contacts
	check(drift<0.002 and plant_frames>100,"world-planted soles remain stable across slow and fast running")

func _ledge_grips() -> void:
	var max_grip_error:=0.0
	var below_plane_crossings:Array=[]
	var max_shallow_reach:=0.0
	for drop in [0.0,8.0,18.0,29.0]:
		for mode in ["ledge_catch","ledge_hang","ledge_pull","ledge_step"]:
			for i in range(21):
				var p:=float(i)/20.0
				var t:=_snapshot(mode,p,1,drop)
				var pose:Dictionary=Pose.evaluate(mode,p,t)
				for bone in ["knee_near","knee_far","heel_near","heel_far","toe_near","toe_far","elbow_near","elbow_far"]:
					var point:Vector2=pose.bones[bone]
					if point.x>t.palm_target.x+0.1 and point.y>t.palm_target.y+0.1:
						below_plane_crossings.append("%s/%s@%.2f drop%.0f"%[mode,bone,p,drop])
				for side in 2:
					var suffix:="near" if side==0 else "far"
					for pair in [["hip_","knee_"],["knee_","ankle_"],["shoulder_","elbow_"],["elbow_","palm_"]]:
						if Pose.segment_enters_ledge(pose.bones[pair[0]+suffix],pose.bones[pair[1]+suffix],t.palm_target):
							below_plane_crossings.append("segment %s/%s%s@%.2f drop%.0f"%[mode,pair[0],suffix,p,drop])
					max_shallow_reach=maxf(max_shallow_reach,absf(Vector2(pose.bones["elbow_"+suffix]).distance_to(pose.bones["palm_"+suffix])-Keys.TUNING.lower_arm))
					max_shallow_reach=maxf(max_shallow_reach,absf(Vector2(pose.bones["knee_"+suffix]).distance_to(pose.bones["ankle_"+suffix])-Keys.TUNING.lower_leg))
					if pose.planted_hands[side]:
						var target:Vector2=t.palm_target+Vector2(-0.2 if side==0 else -0.5,0)
						var actual:Vector2=pose.bones["palm_near" if side==0 else "palm_far"]
						max_grip_error=maxf(max_grip_error,actual.distance_to(target))
	metrics["maximum_palm_anchor_error_px"]=max_grip_error
	metrics["ledge_plane_crossings"]=below_plane_crossings
	metrics["maximum_shallow_ledge_reach_error_px"]=max_shallow_reach
	check(below_plane_crossings.is_empty(),"ledge limbs stay outside the wall until above its top")
	check(max_shallow_reach<0.35,"shallow and full ledge poses remain anatomically reachable")
	check(max_grip_error<0.001,"catch/hang/pull palms follow authoritative world ledge including shallow arrival")

func _motion_readability() -> void:
	var lowest:=INF;var highest:=-INF
	var knee_forward:=0.0
	for i in range(60):
		var pose:Dictionary=Pose.evaluate("run",float(i)/60.0,{"velocity":Vector2(218,0),"run_reference_speed":218.0})
		lowest=minf(lowest,float(pose.bones.head.y));highest=maxf(highest,float(pose.bones.head.y))
		knee_forward=maxf(knee_forward,float(pose.bones.knee_near.x)-float(pose.bones.hip_near.x))
	check(highest-lowest<3.0,"run head is steady while limbs articulate")
	check(knee_forward>6.0,"run recovery includes a pronounced forward knee key")
	for p in [0.0,0.5]:
		var pose:Dictionary=Pose.evaluate("run",p,{"velocity":Vector2(218,0),"run_reference_speed":218.0})
		var leg:float=pose.bones.sole_near.x-pose.bones.pelvis.x
		var arm:float=pose.bones.palm_near.x-pose.bones.chest.x
		check(leg*arm<0.0,"run contact keys use opposing arm and leg reach")
	metrics["run_head_vertical_range_px"]=highest-lowest
	metrics["run_knee_forward_reach_px"]=knee_forward

func _support_motion() -> void:
	var view=Visual.new()
	var baseline:Vector2
	var support_error:=0.0
	for i in range(60):
		var root_position:=Vector2(200+float(i),300)
		view.present(1.0/60.0,{"position":root_position,"velocity":Vector2.ZERO,"grounded":true,"pose":"idle","facing":1,"support_id":7,"support_displacement":Vector2(1,0) if i>0 else Vector2.ZERO})
		var world:Vector2=root_position+Vector2(view.get_pose().bones.sole_near)
		if i==0:baseline=world
		else:support_error=maxf(support_error,(world-baseline-Vector2(i,0)).length())
	check(support_error<0.001,"planted foot travels exactly with authoritative moving support")
	metrics["moving_support_foot_error_px"]=support_error
	view.reset_presentation()
	view.present(0.0,{"position":Vector2(500,100),"velocity":Vector2.ZERO,"grounded":true,"pose":"idle","facing":1})
	check(view.get_pose().planted_feet==[true,true],"reset starts fresh foot anchors after teleport")
	view.free()

func _observer_contract() -> void:
	var view=Visual.new()
	var snapshot:=_snapshot("run",0.5)
	snapshot["collider"]={"size":Vector2(16,34)}
	var before:=snapshot.duplicate(true)
	view.event("ground_jump",{"speed":365})
	view.present(1.0/60.0,snapshot)
	var copy:Dictionary=view.bone_positions
	copy["head"]=Vector2(999,999)
	check(snapshot==before,"presentation does not mutate motor telemetry or collision data")
	check(view.position==Vector2.ZERO and view.scale==Vector2.ONE and view.rotation==0,"visual never changes its physical parent transform or facing")
	check(view.bone_positions.head!=Vector2(999,999),"bone positions are returned as independent copies")
	view.present(0.01,{"pose":"crouch","crouched":true,"grounded":true,"facing":-1,"velocity":Vector2.ZERO})
	check(view.pose_name=="crouch","motor crouch decision takes precedence over other visual transients")
	view.free()

func _draw_lifecycle() -> void:
	var view=Visual.new();root.add_child(view)
	var draws:Array=[];view.draw.connect(func():draws.append(1))
	for mode in ["idle","run","land","ledge_pull"]:
		view.present(0.016,_snapshot(mode,0.5))
		await process_frame
		await process_frame
	check(draws.size()>0,"headless scene executes authored draw geometry")
	metrics["headless_draw_notifications"]=draws.size()
	view.queue_free();await process_frame

func _export() -> void:
	var output:Dictionary={"description":"MOKSHA original pose-vector samples; offline preview, not a gameplay capture","metadata":Keys.METADATA,"tuning":_encode(Keys.TUNING),"samples":samples}
	var file:=FileAccess.open("res://combat_pc/visuals/tests/pose_samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))

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
