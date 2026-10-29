extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Keys=preload("res://combat_pc/visuals/climb_keys.gd")
const Body=preload("res://combat_pc/visuals/wireframe_keys.gd")
const HEAD=[Vector2(-2.1,-2.0),Vector2(0.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-0.25),Vector2(3.2,0.55),Vector2(1.6,1.1),Vector2(0.7,2.5),Vector2(-1.8,2.0),Vector2(-2.5,0.5)]
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var samples:Array=[]
func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run() -> void:
	_geometry();_contacts();_scaled_contacts();_geometry_edits();_pause_and_exit();_interruptions()
	await _drawing()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original MOKSHA ladder/vine pose geometry and travel-driven presentation contacts; no root or collision authority"}
	FileAccess.open("res://combat_pc/visuals/tests/climb_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/climb_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original MOKSHA climb vectors; offline inspection, not gameplay capture","samples":samples},"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func snapshot(mode:String,p:float,low:bool=false,kind:String="ladder",facing:int=1) -> Dictionary:
	var actor_root:=Vector2(0,200-p*24)
	if mode=="climb_top_exit":actor_root.y=20+(1-p)*34
	if mode=="climb_align":actor_root.x=-10*(1-p)*facing
	return {"position":actor_root,"world_position":actor_root,"velocity":Vector2(0,-100),"facing":facing,"grounded":mode=="climb_release","body_height":20.0 if low else 34.0,"crouched":low,"pose":mode,"main_action":"locomotion" if mode=="climb_release" else "climb","climb_active":mode!="climb_release","climb_phase":mode.trim_prefix("climb_"),"climb_phase_progress":p,"climb_axis_x":0.0,"climb_top_y":20.0,"climb_bottom_y":320.0,"climb_distance":-p*24,"climb_rung_spacing":12.0,"climb_rung_origin_offset":8.0 if kind=="vine" else 4.0,"climb_target_id":8,"climb_type":kind,"weapon_phase":"idle","move_x":0.0}
func _geometry() -> void:
	var arm_error:=0.0;var leg_error:=0.0;var low_top:=0.0;var bottom:=-INF
	var worst_arm:="";var worst_leg:="";var worst_low:=""
	for mode in Keys.MODES:
		for low in [false,true]:
			for kind in ["ladder","vine"]:
				for i in range(41):
					var p:=float(i)/40
					var t:=snapshot(mode,p,low,kind)
					var before:=t.duplicate(true)
					var pose:Dictionary=Pose.evaluate(mode,p,t)
					check(t==before and pose.mode==mode and not pose.weapon.visible,"pure unarmed climb mode "+mode)
					for bone in Pose.BONE_NAMES:
						check(Vector2(pose.bones[bone]).is_finite(),"finite "+mode+"/"+bone)
						bottom=maxf(bottom,float(pose.bones[bone].y))
						if low and pose.bones[bone].y<low_top:low_top=pose.bones[bone].y;worst_low=mode+" "+kind+" "+str(p)+" "+bone
					for side in ["near","far"]:
						var ae:=absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-Body.TUNING.lower_arm)
						var le:=absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-Body.TUNING.lower_leg)
						if ae>arm_error:arm_error=ae;worst_arm=mode+" "+kind+" "+str(p)+" "+side
						if le>leg_error:leg_error=le;worst_leg=mode+" "+kind+" "+str(p)+" "+side
					if low:
						for offset in HEAD:
							var point:Vector2=Vector2(pose.bones.head)+(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)))
							if point.y<low_top:low_top=point.y;worst_low=mode+" "+kind+" "+str(p)+" head outline"
					if i in [0,10,20,30] and (kind=="ladder" or mode in ["climb_idle","climb_ascend"]):
						samples.append({"label":mode+("_low" if low else "")+("_vine" if kind=="vine" else ""),"pose":_encode(pose),"telemetry":_encode(t)})
				var a:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,low,kind,1))
				var b:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,low,kind,-1))
				for bone in Pose.BONE_NAMES:check(Vector2(-a.bones[bone].x,a.bones[bone].y).distance_to(b.bones[bone])<0.001,"mirror "+mode+"/"+bone)
	metrics={"arm_reach_error_px":arm_error,"leg_reach_error_px":leg_error,"low_body_top_px":low_top,"lowest_bone_px":bottom,"worst_arm":worst_arm,"worst_leg":worst_leg,"worst_low":worst_low}
	check(arm_error<0.15 and leg_error<0.15,"climb limbs stay anatomically reachable")
	check(low_top>=-19.7 and bottom<=0.001,"climb low variant fits20px and stays above the foot plane")
func _contacts() -> void:
	var drift:=0.0;var pairs:=0;var rung_error:=0.0
	for low in [false,true]:
		for kind in ["ladder","vine"]:
			var view=Visual.new()
			var previous:Dictionary={};var previous_on:Dictionary={}
			for i in range(301):
				var travel:float=float(i)*0.4 if i<180 else 72.0-float(i-180)*0.4
				var mode:String="climb_ascend" if i<180 else "climb_descend"
				var t:=snapshot(mode,0,low,kind)
				t.position=Vector2(0,200-travel);t.world_position=t.position;t.climb_distance=-travel
				view.present(1.0/120,t)
				var pose:Dictionary=view.get_pose()
				for index in 2:
					var side:String="near" if index==0 else "far"
					for limb in ["palm","sole"]:
						var key:String=limb+"_"+side
						var on:bool=pose.planted_hands[index] if limb=="palm" else pose.planted_feet[index]
						var world:Vector2=t.position+Vector2(pose.bones[key])
						if on:
							var unit:float=(float(t.climb_bottom_y)-float(t.climb_rung_origin_offset)-world.y)/float(t.climb_rung_spacing)
							rung_error=maxf(rung_error,absf(unit-roundf(unit))*12)
							if bool(previous_on.get(key,false)):drift=maxf(drift,world.distance_to(previous[key]));pairs+=1
						previous_on[key]=on;previous[key]=world
			view.free()
	metrics["rung_contact_drift_px"]=drift;metrics["rung_grid_error_px"]=rung_error;metrics["planted_frame_pairs"]=pairs
	check(drift<0.003 and pairs>500,"hands and feet remain world-planted through upward travel and reversal")
	check(rung_error<0.001,"planted contacts coincide with authoritative guide rungs")
func _pause_and_exit() -> void:
	var view=Visual.new();var t:=snapshot("climb_idle",0.35)
	view.event("climb_attached");view.present(0,t)
	var original:Dictionary=view.get_pose()
	for i in range(50):view.present(0.02,t)
	check(view.get_pose()==original,"holding still never cycles with elapsed time")
	t["paused"]=true;t.position+=Vector2(7,-5);t.world_position=t.position;t.climb_axis_x+=7;t.climb_top_y-=5;t.climb_bottom_y-=5;t["climb_transport"]=Vector2(7,-5)
	view.present(0.016,t)
	check(view.get_pose()==original,"hitpause and coherent sensor transport keep the exact local pose")
	view.present(0,snapshot("climb_top_exit",1))
	check(view.get_pose().planted_hands==[false,false],"top exit releases grips after the sensor leaves arm reach")
	view.event("climb_detached",{"reason":"bottom_exit"})
	view.present(0,{"pose":"idle","main_action":"locomotion","grounded":true,"weapon_phase":"idle"})
	check(view.pose_name=="climb_release" and view.get_pose().planted_feet==[true,true],"ordinary grounded bottom exit settles on real support")
	view.present(0.2,{"pose":"idle","main_action":"locomotion","grounded":true})
	check(view.pose_name=="idle","release pose completes without holding motor ownership")
	view.free()

func _scaled_contacts() -> void:
	var drift:=0.0;var grid_error:=0.0;var lateral_error:=0.0;var low_top:=0.0;var bottom:=-INF;var pairs:=0
	for sensor_scale in [0.1,0.5,1.0,1.5,2.0,3.0]:
		for width in [0.8,8.0,20.0,64.0]:
			for low in [false,true]:
				for kind in ["ladder","vine"]:
					var previous:Dictionary={};var previous_on:Dictionary={}
					for i in range(101):
						var t:=snapshot("climb_ascend",0,low,kind)
						t.position=Vector2(0,260-float(i)*0.3*sensor_scale);t.world_position=t.position
						t.climb_top_y=0.0;t.climb_bottom_y=600.0;t["climb_width"]=width
						t.climb_rung_spacing=12.0*sensor_scale;t.climb_rung_origin_offset=(8.0 if kind=="vine" else 4.0)*sensor_scale
						var pose:Dictionary=Pose.evaluate("climb_ascend",0,t)
						for bone in Pose.BONE_NAMES:
							bottom=maxf(bottom,float(pose.bones[bone].y))
							if low:low_top=minf(low_top,float(pose.bones[bone].y))
						for index in 2:
							var side:String="near" if index==0 else "far"
							for limb in ["palm","sole"]:
								var key:String=limb+"_"+side
								var on:bool=pose.planted_hands[index] if limb=="palm" else pose.planted_feet[index]
								var world:Vector2=t.position+Vector2(pose.bones[key])
								if on:
									var unit:float=(float(t.climb_bottom_y)-float(t.climb_rung_origin_offset)-world.y)/float(t.climb_rung_spacing)
									grid_error=maxf(grid_error,absf(unit-roundf(unit))*float(t.climb_rung_spacing))
									lateral_error=maxf(lateral_error,absf(world.x)-width*0.3)
									if bool(previous_on.get(key,false)):drift=maxf(drift,world.distance_to(previous[key]));pairs+=1
								previous_on[key]=on;previous[key]=world
	metrics["scaled_rung_drift_px"]=drift;metrics["scaled_grid_error_px"]=grid_error;metrics["scaled_rung_lateral_error_px"]=lateral_error;metrics["scaled_low_body_top_px"]=low_top;metrics["scaled_lowest_bone_px"]=bottom;metrics["scaled_contact_frame_pairs"]=pairs
	check(drift<0.003 and grid_error<0.003 and pairs>1000,"positive sensor scale preserves exact world-rung contact anchors")
	check(lateral_error<0.001,"narrow and wide sensors keep contact centers inside rung width")
	check(low_top>=-19.7 and bottom<0.001,"unreachable scaled rungs release contacts without exceeding low-body clearance")
func _interruptions() -> void:
	for action in ["jump","roll","dive","attack","hurt"]:
		var view=Visual.new();view.event("climb_attached");view.present(0,snapshot("climb_idle",0.4))
		view.event("climb_detached",{"reason":action})
		var t:Dictionary={"position":Vector2.ZERO,"grounded":false,"climb_active":false,"climb_phase":"idle","facing":1,"velocity":Vector2(0,-150)}
		var expected:String
		match action:
			"jump":view.event("ground_jump");t.pose="jump_rise";t.main_action="locomotion";expected="jump"
			"roll":view.event("roll_started");t.pose="roll_start";t.main_action="roll";t.roll_phase="start";expected="roll_start"
			"dive":view.event("dive_started");t.pose="dive_startup";t.main_action="dive";t.dive_phase="startup";expected="dive_startup"
			"attack":view.event("attack_started");t.pose="attack_windup";t.main_action="attack";t.weapon_phase="windup";expected="attack_windup"
			_:view.event("hurt_started");t.pose="hurt";t.main_action="hurt";expected="hurt"
		view.present(0,t)
		check(view.pose_name==expected and not view.get_pose().climb_support,"new action immediately releases ladder owner: "+action)
		check(view.get_pose().planted_hands==[false,false],"no retained ladder grips after "+action)
		check(view.position==Vector2.ZERO and view.rotation==0 and view.scale==Vector2.ONE,"presentation never changes root transform")
		view.reset_presentation();view.present(0,{"pose":"idle","grounded":true})
		check(view.pose_name=="idle","reset clears climb release state")
		view.free()

func _geometry_edits() -> void:
	var view=Visual.new();var markers:Array=[]
	view.phase_event.connect(func(event_name:String,payload:Dictionary):markers.append({"event":event_name,"payload":payload}))
	var t:=snapshot("climb_idle",0.35);t["climb_width"]=20.0
	view.present(0,t)
	markers.clear();t.climb_width=8.0
	view.present(0,t)
	var released:=0
	for marker in markers:
		if marker.event in ["hand_release","foot_release"] and marker.payload.reason=="geometry_changed":released+=1
	check(released>0,"editing rung width explicitly releases old contacts before resampling")
	var pose:Dictionary=view.get_pose()
	for i in 2:
		var side:String="near" if i==0 else "far"
		if pose.planted_hands[i]:check(absf(float(pose.bones["palm_"+side].x))<=2.4,"edited narrow rung contains palm contact")
		if pose.planted_feet[i]:check(absf(float(pose.bones["sole_"+side].x))<=2.4,"edited narrow rung contains sole contact")
	markers.clear();t.climb_rung_spacing=18.0;t.climb_rung_origin_offset=6.0
	view.present(0,t)
	check(not markers.is_empty(),"scale edit resamples contact geometry instead of keeping stale anchors")
	view.free()
func _drawing() -> void:
	var view=Visual.new();root.add_child(view)
	var draws:Array=[];view.draw.connect(func():draws.append(true))
	for mode in Keys.MODES:
		view.present(0.016,snapshot(mode,0.3))
		await process_frame;await process_frame
	check(draws.size()==Keys.MODES.size(),"headless drawing covers climb families")
	metrics["draw_notifications"]=draws.size()
	view.queue_free();await process_frame
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
