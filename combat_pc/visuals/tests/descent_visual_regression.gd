extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Keys=preload("res://combat_pc/visuals/descent_keys.gd")
const BodyKeys=preload("res://combat_pc/visuals/wireframe_keys.gd")
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
	_geometry();_phase_keys();_ownership()
	await _drawing()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original MOKSHA drop/dive presentation, contact/phase ownership and headless drawing; no physics rules or recovered animation data"}
	FileAccess.open("res://combat_pc/visuals/tests/descent_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/descent_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original MOKSHA drop and dive vectors; offline pose inspection, not gameplay capture","samples":samples},"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func snapshot(mode:String,p:float,low:bool=false,facing:int=1) -> Dictionary:
	var contact:bool=mode in ["dive_impact","dive_recovery"]
	return {"position":Vector2.ZERO,"velocity":Vector2(0,0 if contact else 600),"facing":facing,"grounded":contact,"pose":mode,"main_action":"drop" if mode=="drop" else "dive","dive_phase":mode.trim_prefix("dive_") if mode!="drop" else "","dive_phase_progress":p,"dive_direction":facing,"dive_serial":3,"dive_fall_distance":120.0,"dive_impact_speed":600.0,"drop_phase":"release" if p<0.75 else "clear","drop_progress":p,"drop_active":mode=="drop","body_height":20.0 if low else 34.0,"crouched":low,"weapon_phase":"idle","move_x":0.0}
func _geometry() -> void:
	var arm_error:=0.0;var leg_error:=0.0;var low_top:=0.0;var lowest:=-INF
	var distinct:Dictionary={}
	for mode in Keys.MODES:
		var signature:=""
		for low in [false,true]:
			for i in range(61):
				var progress:=float(i)/60
				var t:=snapshot(mode,progress,low)
				var before:=t.duplicate(true)
				var pose:Dictionary=Pose.evaluate(mode,progress,t)
				check(t==before,"pure drop/dive evaluation preserves telemetry")
				check(pose.mode==mode and not pose.weapon.visible,"correct unarmed descent pose "+mode)
				for bone in Pose.BONE_NAMES:
					check(Vector2(pose.bones[bone]).is_finite(),"finite "+mode+"/"+bone)
					lowest=maxf(lowest,float(pose.bones[bone].y))
					if low:low_top=minf(low_top,float(pose.bones[bone].y))
				for side in ["near","far"]:
					arm_error=maxf(arm_error,absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-BodyKeys.TUNING.lower_arm))
					leg_error=maxf(leg_error,absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-BodyKeys.TUNING.lower_leg))
				if low:
					for offset in HEAD:
						var point:Vector2=Vector2(pose.bones.head)+(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)))
						low_top=minf(low_top,point.y)
				check(pose.planted_feet==[true,true] if t.grounded else pose.planted_feet==[false,false],"foot support belongs to physical impact/recovery only")
				if i in [0,15,30,45]:
					samples.append({"label":mode+("_low" if low else ""),"pose":_encode(pose),"telemetry":_encode(t)})
					signature+=str(pose.bones.head)+str(pose.bones.palm_near)+str(pose.bones.knee_near)
			var right:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,low,1))
			var left:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,low,-1))
			for bone in Pose.BONE_NAMES:check(Vector2(-right.bones[bone].x,right.bones[bone].y).distance_to(left.bones[bone])<0.001,"mirrored descent "+mode+"/"+bone)
		distinct[signature]=mode
	metrics={"arm_reach_error_px":arm_error,"leg_reach_error_px":leg_error,"low_body_top_px":low_top,"lowest_body_bone_px":lowest,"distinct_families":distinct.size()}
	check(arm_error<0.15 and leg_error<0.15,"descent palms and soles remain anatomically reachable")
	check(low_top>=-19.7 and lowest<=0.001,"low silhouettes fit20px and body stays above the foot plane")
	check(distinct.size()==Keys.MODES.size(),"every drop/dive family has distinct authored keys")
func _phase_keys() -> void:
	for low in [false,true]:
		var impact_a:Dictionary=Pose.evaluate("dive_impact",0,snapshot("dive_impact",0,low))
		var impact_b:Dictionary=Pose.evaluate("dive_impact",1,snapshot("dive_impact",1,low))
		check(impact_a.bones==impact_b.bones,"impact holds through the entire actual contact phase")
		for pair in [["dive_startup","dive_descent"],["dive_impact","dive_recovery"]]:
			var a:Dictionary=Pose.evaluate(pair[0],1,snapshot(pair[0],1,low))
			var b:Dictionary=Pose.evaluate(pair[1],0,snapshot(pair[1],0,low))
			for bone in Pose.BONE_NAMES:check(Vector2(a.bones[bone]).distance_to(b.bones[bone])<0.001,"descent phase boundary "+str(pair)+"/"+bone)
		var recovered:Dictionary=Pose.evaluate("dive_recovery",1,snapshot("dive_recovery",1,low))
		var neutral:Dictionary=Pose.evaluate("crouch" if low else "idle",0,{})
		for bone in ["head","pelvis","palm_near","sole_near"]:check(Vector2(recovered.bones[bone]).distance_to(neutral.bones[bone])<0.001,"recovery restores clearance-appropriate neutral key")
		var released:Dictionary=Pose.evaluate("drop",0,snapshot("drop",0,low))
		check(released.bones.pelvis.y>=neutral.bones.pelvis.y and released.bones.sole_near.y==0,"drop releases downward without a jump or upward foot stroke")
		check(recovered.bones.pelvis.y<impact_a.bones.pelvis.y-1,"recovery unfolds from planted impact compression")
func _ownership() -> void:
	var view=Visual.new()
	view.event("ground_jump");view.event("strike_confirmed")
	view.present(0,{"pose":"attack_active","main_action":"attack","weapon_phase":"active","weapon_phase_progress":0.3,"grounded":true})
	check(view.get_pose().weapon.visible,"fixture begins with drawn active weapon")
	view.event("dive_started",{"serial":3})
	var t:=snapshot("dive_startup",0)
	t.weapon_phase="active" # An interrupted action's stale field cannot override the new owner.
	view.present(0,t)
	check(view.pose_name=="dive_startup" and not view.get_pose().weapon.visible,"dive immediately removes interrupted weapon and old jump transients")
	t=snapshot("dive_descent",1)
	for i in range(30):view.present(0.1,t)
	check(view.pose_name=="dive_descent" and view.get_pose().planted_feet==[false,false],"time and speed never synthesize floor impact")
	view.event("dive_impact",{"speed":600});t=snapshot("dive_impact",0)
	view.present(0,t)
	check(view.pose_name=="dive_impact" and view.get_pose().planted_feet==[true,true],"authoritative real contact starts planted impact")
	var held:Dictionary=view.get_pose()
	t["paused"]=true
	for i in range(10):view.present(0.016,t)
	check(view.get_pose()==held,"hitpause holds descent impact and support pose")
	view.event("dive_cancelled");view.event("roll_started")
	view.present(0,{"pose":"roll_start","main_action":"roll","roll_phase":"start","roll_phase_progress":0.0,"roll_direction":-1,"dive_phase":"impact","grounded":true,"crouched":true})
	check(view.pose_name=="roll_start" and view.get_pose().facing==-1,"roll replaces dive owner immediately")
	view.event("hurt_started");view.present(0,{"pose":"hurt","main_action":"hurt","hurt_progress":0.0,"dive_phase":"impact","grounded":false})
	check(view.pose_name=="hurt","damage replaces dive owner immediately")
	view.event("drop_started")
	view.present(0,snapshot("drop",0,true))
	check(view.pose_name=="drop" and not view.get_pose().weapon.visible,"fresh drop clears old attack and jump visuals")
	view.present(0,{"pose":"fall","main_action":"locomotion","drop_active":true,"drop_phase":"release","drop_progress":1.0,"grounded":false,"velocity":Vector2(0,80)})
	check(view.pose_name=="fall","collision cleanup after drop expiry cannot retain visual ownership")
	view.present(0,{"pose":"fall","main_action":"locomotion","dive_phase":"recovery","grounded":false,"velocity":Vector2(0,100)})
	check(view.pose_name=="fall","lost support and cancelled dive return immediately to falling")
	view.present(0,{"pose":"drop_blocked","main_action":"locomotion","drop_geometry_blocked":true,"drop_active":true,"grounded":false,"body_height":20.0})
	check(view.pose_name=="crouch" and not view.get_pose().weapon.visible,"explicit blocked geometry pose holds a quiet compact body")
	view.present(0,{"pose":"roll_travel","main_action":"roll","roll_phase":"travel","roll_phase_progress":0.5,"drop_active":true,"drop_cleanup_blocked":true,"grounded":true})
	check(view.pose_name=="roll_travel","pending exception cleanup alone cannot override a roll")
	view.reset_presentation();view.present(0,{"pose":"idle","grounded":true})
	check(view.pose_name=="idle" and view.position==Vector2.ZERO and view.scale==Vector2.ONE and view.rotation==0,"reset clears action while physical transform stays motor-owned")
	view.free()
func _drawing() -> void:
	var view=Visual.new();root.add_child(view)
	var draws:Array=[];view.draw.connect(func():draws.append(true))
	for mode in Keys.MODES:
		view.present(0.016,snapshot(mode,0.3))
		await process_frame;await process_frame
	check(draws.size()==Keys.MODES.size(),"headless draw covers all descent families")
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
