extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Keys=preload("res://combat_pc/visuals/landing_keys.gd")
const HEAD=[Vector2(-2.1,-2),Vector2(0.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-0.25),Vector2(3.2,0.55),Vector2(1.6,1.1),Vector2(0.7,2.5),Vector2(-1.8,2),Vector2(-2.5,0.5)]
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var samples:Array=[]
func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run() -> void:
	_geometry();_boundaries();_contacts();_ownership()
	await _drawing()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original hard-contact poses, real floor/skid observation, pause and cancel ownership; no recovered game animation/timing claim"}
	FileAccess.open("res://combat_pc/visuals/tests/landing_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/landing_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original MOKSHA landing vectors, offline inspection rather than gameplay capture","samples":samples},"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func snapshot(mode:String,p:float,kind:String="ordinary",facing:int=1,skid:float=0.0,angle:float=0.0) -> Dictionary:
	var normal:=Vector2.UP.rotated(angle)
	return {"position":Vector2.ZERO,"velocity":Vector2(skid,0),"facing":facing,"grounded":true,"main_action":"hard_land","pose":mode,"hard_land_phase":mode.trim_prefix("hard_land_"),"hard_land_kind":kind,"hard_land_phase_progress":p,"hard_land_skidding":absf(skid)>0.1,"floor_relative_velocity":Vector2(skid,0),"floor_normal":normal,"floor_contact_point":Vector2.ZERO,"support_id":4,"support_displacement":Vector2.ZERO,"body_height":20.0,"crouched":true,"weapon_phase":"idle"}
func _geometry() -> void:
	var arm_error:=0.0;var leg_error:=0.0;var low_top:=0.0;var plane_error:=0.0;var floor_penetration:=0.0
	for kind in ["ordinary","dive"]:
		for mode in Keys.MODES:
			for angle in [-0.2,0.0,0.2]:
				for facing in [-1,1]:
					for i in range(81):
						var p:=float(i)/80
						var t:=snapshot(mode,p,kind,facing,0,angle)
						var original:=t.duplicate(true)
						var pose:Dictionary=Pose.evaluate(mode,p,t)
						check(t==original and pose.facing==facing and not pose.weapon.visible,"pure hard pose preserves telemetry, facing and unarmed silhouette")
						for bone in Pose.BONE_NAMES:
							check(Vector2(pose.bones[bone]).is_finite(),"finite hard-contact "+bone)
							low_top=minf(low_top,float(pose.bones[bone].y))
							floor_penetration=minf(floor_penetration,Vector2(pose.bones[bone]).dot(t.floor_normal))
						for side in ["near","far"]:
							arm_error=maxf(arm_error,absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-5.8))
							leg_error=maxf(leg_error,absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-8))
							for foot in ["sole_","heel_","toe_"]:plane_error=maxf(plane_error,absf(Vector2(pose.bones[foot+side]).dot(t.floor_normal)))
						for offset in HEAD:
							var point:Vector2=(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)));point.x*=facing
							point+=Vector2(pose.bones.head);low_top=minf(low_top,point.y)
						if angle==0 and i in [0,20,40,60,80]:samples.append({"label":kind+"_"+mode+("_left" if facing<0 else ""),"pose":_encode(pose),"telemetry":_encode(t)})
			var right:Dictionary=Pose.evaluate(mode,0.4,snapshot(mode,0.4,kind,1,0,0.2))
			var left:Dictionary=Pose.evaluate(mode,0.4,snapshot(mode,0.4,kind,-1,0,-0.2))
			for bone in Pose.BONE_NAMES:check(Vector2(-right.bones[bone].x,right.bones[bone].y).distance_to(left.bones[bone])<0.001,"mirrored hard keys and floor normal")
	metrics={"arm_error_px":arm_error,"leg_error_px":leg_error,"low_body_top_px":low_top,"floor_plane_error_px":plane_error,"floor_penetration_px":floor_penetration}
	check(arm_error<0.15 and leg_error<0.15,"hard pose limbs remain reachable")
	check(low_top>=-19.7,"hard recovery remains within clearance-safe20px body")
	check(plane_error<0.001 and floor_penetration>-0.001,"feet follow real floor normal and body remains above plane")
func _boundaries() -> void:
	for kind in ["ordinary","dive"]:
		var impact:Dictionary=Pose.evaluate("hard_land_impact",0,snapshot("hard_land_impact",0,kind))
		var end:Dictionary=Pose.evaluate("hard_land_impact",1,snapshot("hard_land_impact",1,kind))
		check(impact.bones==end.bones,"impact key holds across actual motor phase")
		var recovery:Dictionary=Pose.evaluate("hard_land_recovery",0,snapshot("hard_land_recovery",0,kind))
		check(end.bones==recovery.bones,"impact-to-recovery boundary is continuous")
		var held:Dictionary=Pose.evaluate("hard_land_recovery",0.12,snapshot("hard_land_recovery",0.12,kind))
		check(held.bones==recovery.bones,"recovery starts with deliberate held contact")
		var ready:Dictionary=Pose.evaluate("hard_land_recovery",1,snapshot("hard_land_recovery",1,kind))
		var crouch:Dictionary=Pose.evaluate("crouch",0,{})
		check(ready.bones==crouch.bones,"final recovery does not invent standing clearance")
	var soft:Dictionary=Pose.evaluate("land",0,{"grounded":true,"preimpact_speed":300})
	var ordinary:Dictionary=Pose.evaluate("hard_land_impact",0,snapshot("hard_land_impact",0))
	var dive:Dictionary=Pose.evaluate("hard_land_impact",0,snapshot("hard_land_impact",0,"dive"))
	check(soft.bones.head.distance_to(ordinary.bones.head)>5 and ordinary.bones.head.distance_to(dive.bones.head)>3,"soft, ordinary hard and dive hard have visibly distinct34px-scale silhouettes")
	for mode in ["land","dive_impact"]:
		var t:Dictionary={"grounded":true,"facing":1,"body_height":34.0}
		samples.append({"label":mode,"pose":_encode(Pose.evaluate(mode,0,t)),"telemetry":_encode(t)})
func _contacts() -> void:
	var view=Visual.new();var markers:Array=[]
	view.phase_event.connect(func(key:String,payload:Dictionary):markers.append({"event":key,"payload":payload}))
	view.event("hard_land_started")
	var t:=snapshot("hard_land_impact",0,"ordinary",1,100)
	view.present(0,t)
	check(view.get_pose().planted_feet==[false,false],"moving impact soles are sliding, never planted")
	var first:=view.get_bones(true)
	t.position.x=4;t.floor_contact_point.x=4;t.hard_land_phase_progress=0.5
	view.present(0.02,t)
	check(view.get_bones(true).sole_near.x==first.sole_near.x+4,"sliding feet follow actual skid instead of stretching planted legs")
	var plants:=0;var touches:=0
	for marker in markers:
		if marker.event=="foot_plant":plants+=1
		if marker.event=="foot_touch" and marker.payload.contact_type=="sliding":touches+=1
	check(plants==0 and touches==2,"skid markers identify two sliding touches only")
	var paused_skid:=view.get_bones();t.paused=true;t.support_displacement=Vector2(1,-0.5)
	t.position+=t.support_displacement;t.floor_contact_point+=t.support_displacement
	view.present(0.1,t)
	check(view.get_bones()==paused_skid and view.get_pose().planted_feet==[false,false],"paused skid holds contact geometry without relabeling it planted")
	t=snapshot("hard_land_recovery",0.2);t.position=Vector2(4,0);t.floor_contact_point=t.position
	view.present(0.02,t)
	check(view.get_pose().planted_feet==[true,true],"feet plant once actual relative skid stops")
	first=view.get_bones(true)
	var drift:=0.0
	for i in range(1,21):
		t.hard_land_phase_progress=0.2+float(i)/25
		t.position+=Vector2(0.5,-0.2);t.floor_contact_point+=Vector2(0.5,-0.2);t.support_displacement=Vector2(0.5,-0.2)
		view.present(0.006,t)
		var current:=view.get_bones(true)
		for side in ["near","far"]:drift=maxf(drift,Vector2(current["sole_"+side]).distance_to(Vector2(first["sole_"+side])+Vector2(0.5,-0.2)*i))
	metrics["stationary_support_plant_drift_px"]=drift
	check(drift<0.001,"stationary recovery plants move only with real carrier transport")
	first=view.get_bones(true);t.facing=-1;t.support_displacement=Vector2.ZERO
	view.present(0,t)
	check(view.get_pose().facing==-1 and view.get_bones(true).sole_near==first.sole_near and view.get_bones(true).sole_far==first.sole_far,"motor-approved recovery turn preserves supported foot points")
	var held:=view.get_bones();t.paused=true
	t.position+=Vector2(2,-1);t.floor_contact_point+=Vector2(2,-1);t.support_displacement=Vector2(2,-1)
	view.present(0.1,t)
	for bone in Pose.BONE_NAMES:check(Vector2(view.get_bones()[bone]).distance_to(held[bone])<0.001,"hitpause with translated carrier preserves local pose "+bone)
	view.event("hard_land_cancelled",{"reason":"lost_support"})
	check(view._landing_contacts.is_empty() and view._foot_anchors.is_empty(),"cancel immediately retires contact markers and locks")
	view.free()
func _ownership() -> void:
	var view=Visual.new()
	view.event("landed",{"preimpact_speed":600});view.event("dive_impact");view.event("hard_land_started",{"kind":"dive"})
	var t:=snapshot("hard_land_impact",0,"dive")
	t.dive_phase="impact";t.weapon_phase="active";t.roll_phase="travel"
	view.present(0,t)
	check(view.pose_name=="hard_land_impact" and not view.get_pose().weapon.visible,"hard landing owns high dive contact despite obsolete action metadata")
	var held:=view.get_pose();t.paused=true
	for i in 12:view.present(0.1,t)
	check(view.get_pose()==held,"paused hard impact has no view-authored clock")
	view.event("hard_land_finished")
	for next_mode in ["run","jump_rise","roll_start","attack_windup","hurt","fall"]:
		view.reset_presentation()
		view.present(0,snapshot("hard_land_recovery",1))
		view.event("hard_land_cancelled",{"reason":next_mode})
		var next:Dictionary={"pose":next_mode,"main_action":"locomotion","grounded":next_mode in ["run","roll_start","attack_windup"],"crouched":false,"body_height":34.0,"velocity":Vector2(120,-180 if next_mode=="jump_rise" else 100),"move_x":1,"hard_land_phase":"recovery","hard_land_kind":"dive","hard_land_phase_progress":0.7}
		if next_mode=="roll_start":next.main_action="roll";next.roll_phase="start"
		if next_mode=="attack_windup":next.main_action="attack";next.weapon_phase="windup"
		if next_mode=="hurt":next.main_action="hurt"
		view.present(0,next)
		check(not view.pose_name.begins_with("hard_land"),"new owner retires held hard pose: "+next_mode)
		check(view._landing_contacts.is_empty(),"new owner retires floor markers: "+next_mode)
	view.reset_presentation();view.event("hard_land_started");view.present(0,snapshot("hard_land_impact",0))
	view.event("hard_land_finished");view.event("ground_jump")
	view.present(0,{"pose":"jump_rise","main_action":"locomotion","grounded":false,"velocity":Vector2(0,-200),"facing":-1})
	check(view.pose_name=="jump" and view.get_pose().facing==-1,"queued jump release begins mirrored takeoff immediately")
	view.present(0.03,{"pose":"jump_apex","grounded":false,"velocity":Vector2(0,-10),"facing":-1})
	check(view.pose_name=="jump_apex","short variable jump exposes actual early apex")
	view.present(0.01,{"pose":"fall","grounded":false,"velocity":Vector2(0,30),"facing":-1})
	check(view.pose_name=="fall","short jump does not keep held rising art after descent starts")
	view.reset_presentation();view.present(0,{"pose":"idle","grounded":true})
	check(view.pose_name=="idle" and view.position==Vector2.ZERO and view.rotation==0 and view.scale==Vector2.ONE,"reset and pose adapter preserve motor transform")
	view.free()
func _drawing() -> void:
	var view=Visual.new();root.add_child(view)
	var draws:Array=[];view.draw.connect(func():draws.append(true))
	for kind in ["ordinary","dive"]:
		for mode in Keys.MODES:
			view.present(0,snapshot(mode,0.4,kind))
			await process_frame;await process_frame
	check(draws.size()==4,"headless runtime draw covers both hard kinds and phases")
	metrics.draw_notifications=draws.size();view.queue_free();await process_frame
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
