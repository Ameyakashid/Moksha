extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Combat=preload("res://combat_pc/visuals/combat_pose.gd")
const Keys=preload("res://combat_pc/visuals/wireframe_keys.gd")
const HEAD=[Vector2(-2.1,-2.0),Vector2(0.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-0.25),Vector2(3.2,0.55),Vector2(1.6,1.1),Vector2(0.7,2.5),Vector2(-1.8,2.0),Vector2(-2.5,0.5)]
var failures:Array[String]=[]
var metrics:Dictionary={}
var checks:=0
var samples:Array=[]
func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run() -> void:
	_geometry()
	_timing()
	_lifecycle()
	_supported_roll_and_pause()
	await _draw()
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"MOKSHA original combat pose geometry and headless lifecycle; motor hit, cancel and invulnerability rules are not implemented by this visual"}
	FileAccess.open("res://combat_pc/visuals/tests/combat_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/combat_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original MOKSHA combat pose-vector samples; offline inspection, not gameplay capture","samples":samples},"\t"))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func snapshot(mode:String,p:float,facing:int=1,air:bool=false,low:bool=false) -> Dictionary:
	var roll:=mode.trim_prefix("roll_") if mode.begins_with("roll_") else ""
	var weapon:=mode.trim_prefix("attack_") if mode.begins_with("attack_") else "idle"
	return {"position":Vector2.ZERO,"velocity":Vector2(120*facing,-80 if air else 0),"facing":facing,"grounded":not air,"pose":mode,"main_action":"hurt" if mode=="hurt" else ("roll" if not roll.is_empty() else "attack"),"roll_phase":roll,"roll_phase_progress":p,"roll_direction":facing,"weapon_phase":weapon,"weapon_phase_progress":p,"attack_facing":facing,"attack_serial":2,"hurt_progress":p,"hurt_direction":-facing,"body_height":20.0 if not roll.is_empty() or low else 34.0,"crouched":low,"move_x":0,"palm_target":Vector2.ZERO}
func _geometry() -> void:
	var arm_error:=0.0;var leg_error:=0.0
	var roll_top:=0.0;var roll_bottom:=-INF;var worst_top:="";var worst_bottom:=""
	var low_top:=0.0
	for mode in Combat.MODES:
		for variant in ["ground","air","low"]:
			if mode.begins_with("roll_") and variant=="low":continue
			for i in range(101):
				var p:=float(i)/100
				var t:=snapshot(mode,p,1,variant=="air",variant=="low")
				var pose:Dictionary=Pose.evaluate(mode,p,t)
				check(pose.mode==mode,"combat mode selected "+mode)
				for bone in Pose.BONE_NAMES:check(Vector2(pose.bones[bone]).is_finite(),"finite "+mode+"/"+bone)
				for side in ["near","far"]:
					arm_error=maxf(arm_error,absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-Keys.TUNING.lower_arm))
					leg_error=maxf(leg_error,absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-Keys.TUNING.lower_leg))
				var points:Array=[]
				for bone in Pose.BONE_NAMES:points.append(pose.bones[bone])
				for point in HEAD:points.append(Vector2(pose.bones.head)+(point*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt))))
				for point in points:
					if mode.begins_with("roll_"):
						if point.y<roll_top:roll_top=point.y;worst_top="%s %.2f"%[mode,p]
						if point.y>roll_bottom:roll_bottom=point.y;worst_bottom="%s %.2f %s"%[mode,p,str(point)]
					elif variant=="low":low_top=minf(low_top,point.y)
				if variant=="air" and not mode.begins_with("roll_"):check(pose.planted_feet==[false,false],"air attack/hurt has no floor plant")
				if pose.weapon.visible:
					check(Vector2(pose.weapon.grip).distance_to(pose.bones.palm_near)<0.00001,"blade grip follows palm")
					check(Vector2(pose.weapon.tip).distance_to(pose.weapon.blade_a)>18.0,"fixed blade geometry remains full length")
				if i in [0,25,50,75] and variant!="low":samples.append({"label":mode+"_air" if variant=="air" else mode,"pose":_encode(pose),"telemetry":_encode(t)})
		var r:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,1))
		var l:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,-1))
		for bone in Pose.BONE_NAMES:check(Vector2(-r.bones[bone].x,r.bones[bone].y).distance_to(l.bones[bone])<0.001,"combat mirrors "+mode+"/"+bone)
		if r.weapon.visible:
			for point in ["grip","tip","guard_a","blade_a"]:check(Vector2(-r.weapon[point].x,r.weapon[point].y).distance_to(l.weapon[point])<0.001,"weapon mirrors "+point)
	metrics={"arm_reach_error_px":arm_error,"leg_reach_error_px":leg_error,"roll_top_px":roll_top,"roll_bottom_px":roll_bottom,"worst_roll_top":worst_top,"worst_roll_bottom":worst_bottom,"low_body_top_px":low_top}
	check(arm_error<0.35,"all combat palm targets remain reachable")
	check(leg_error<0.35,"all combat sole targets remain reachable")
	check(roll_top>=-19.7 and roll_bottom<=0.05,"entire articulated roll including head outline fits20px clearance")
	check(low_top>=-19.7,"low attack/hurt body stays inside reduced clearance")
func _timing() -> void:
	var a:Dictionary=Pose.evaluate("attack_active",0.02,snapshot("attack_active",0.02))
	var b:Dictionary=Pose.evaluate("attack_active",0.61,snapshot("attack_active",0.61))
	check(a.bones==b.bones and a.weapon==b.weapon,"active contact is a held key rather than an interpolated smear")
	var load:Dictionary=Pose.evaluate("attack_windup",0.80,snapshot("attack_windup",0.80))
	check(Vector2(load.weapon.tip).distance_to(a.weapon.tip)>30,"windup and contact are decisively distinct")
	var spin0:Dictionary=Pose.evaluate("roll_travel",0,snapshot("roll_travel",0))
	var spin1:Dictionary=Pose.evaluate("roll_travel",1,snapshot("roll_travel",1))
	for bone in Pose.BONE_NAMES:check(Vector2(spin0.bones[bone]).distance_to(spin1.bones[bone])<0.001,"full tumble completes to folded exit "+bone)
	var land_t:=snapshot("attack_active",0.3);land_t["landing_visual_progress"]=0.1;land_t["preimpact_speed"]=520
	var land:Dictionary=Pose.evaluate("attack_active",0.3,land_t)
	check(land.bones.pelvis.y>a.bones.pelvis.y+2,"air attack landing compresses hips without discarding the weapon phase")
	check(land.weapon.visible and land.mode=="attack_active","landing retains active weapon pose")
	for low in [false,true]:
		var contact:Dictionary=Pose.evaluate("attack_active",0.3,snapshot("attack_active",0.3,1,false,low))
		var rectangle:=Rect2(Vector2(8,-20 if low else -32),Vector2(32,24))
		check(rectangle.has_point(contact.weapon.tip),"visible contact tip lies within default motor strike area, low="+str(low))
	for transition in [["roll_start", "roll_travel"],["roll_travel", "roll_recovery"],["attack_active", "attack_recovery"]]:
		var end:Dictionary=Pose.evaluate(transition[0],1,snapshot(transition[0],1))
		var start:Dictionary=Pose.evaluate(transition[1],0,snapshot(transition[1],0))
		for bone in Pose.BONE_NAMES:check(Vector2(end.bones[bone]).distance_to(start.bones[bone])<0.001,"continuous authored phase boundary "+str(transition)+"/"+bone)
	check(Pose.evaluate("hurt",0.02,snapshot("hurt",0.02)).bones==Pose.evaluate("hurt",0.28,snapshot("hurt",0.28)).bones,"hurt recoil holds before its guard recovery")
func _lifecycle() -> void:
	var view=Visual.new()
	var t:=snapshot("attack_active",0.3)
	view.event("attack_started",{"serial":2});view.event("strike_confirmed",{"serial":2})
	view.present(0,t)
	var baseline:Dictionary=view.get_pose()
	check(baseline.weapon.confirmed,"confirmed strike marks the held contact")
	t["paused"]=true;t["hitpause_remaining"]=0.07
	for i in range(20):view.present(0.016,t)
	check(view.get_pose()==baseline,"hitpause freezes body, weapon and local impact clock")
	t["paused"]=false;t["weapon_phase_progress"]=0.85
	view.present(0.08,t)
	check(not view.get_pose().weapon.confirmed and view.get_pose().bones!=baseline.bones,"unpause advances impact lifetime and follows authoritative progress")
	view.event("attack_cancelled",{"serial":2});view.event("roll_started")
	view.present(0,snapshot("roll_start",0))
	check(view.pose_name=="roll_start" and not view.get_pose().weapon.visible,"attack cancel yields immediately to roll with no stale weapon")
	view.event("hurt_started");view.present(0,snapshot("hurt",0))
	check(view.pose_name=="hurt","hurt interrupts a roll immediately")
	view.event("hurt_finished");view.event("attack_started",{"serial":3})
	view.present(0,snapshot("attack_windup",0))
	check(view.pose_name=="attack_windup" and not view.get_pose().weapon.confirmed,"repeated attack restarts at fresh windup")
	view.event("attack_cancelled");view.present(0,{"pose":"crouch","crouched":true,"grounded":true,"body_height":20.0,"facing":1})
	check(view.pose_name=="crouch" and not view.get_pose().weapon.visible,"cancel under low clearance obeys motor crouch")
	view.reset_presentation();view.present(0,{"pose":"idle","grounded":true,"position":Vector2(300,100)})
	check(view.pose_name=="idle" and not view.get_pose().weapon.visible,"reset discards combat transients")
	var authority:=snapshot("attack_active",0.3);authority["attack_facing"]=-1;authority["facing"]=1
	var copy:=authority.duplicate(true);view.present(0,authority)
	check(authority==copy and view.get_pose().facing==-1,"visual follows latched attack facing without changing motor facing")
	check(view.position==Vector2.ZERO and view.scale==Vector2.ONE and view.rotation==0,"tumble never rotates or moves physical Node2D")
	view.free()
func _draw() -> void:
	var view=Visual.new();root.add_child(view)
	var draws:Array=[];view.draw.connect(func():draws.append(true))
	for mode in Combat.MODES:
		view.present(0.016,snapshot(mode,0.3))
		await process_frame;await process_frame
	check(draws.size()==Combat.MODES.size(),"headless drawing covers each combat family")
	metrics["draw_notifications"]=draws.size()
	view.queue_free();await process_frame

func _supported_roll_and_pause() -> void:
	var view=Visual.new()
	var lowest:float=-INF;var highest:float=INF
	var root_position:=Vector2.ZERO
	for mode in ["roll_start","roll_travel","roll_recovery"]:
		for i in range(41):
			var t:=snapshot(mode,float(i)/40)
			root_position.x+=2.0
			t.position=root_position
			view.present(1.0/120.0,t)
			var pose:Dictionary=view.get_pose()
			for bone in Pose.BONE_NAMES:
				lowest=maxf(lowest,float(pose.bones[bone].y));highest=minf(highest,float(pose.bones[bone].y))
	check(lowest<0.001 and highest>=-20,"world stance correction preserves the compact rolling body")
	view.reset_presentation()
	var t:=snapshot("attack_active",0.3)
	t.position=Vector2(100,100);t["support_id"]=99
	view.present(0,t)
	var before:Dictionary=view.get_pose()
	t.position+=Vector2(3,-2);t["support_displacement"]=Vector2(3,-2);t["paused"]=true
	view.present(0,t)
	check(view.get_pose().bones==before.bones,"hitpause retains local pose while an authoritative carrier transports the actor")
	metrics["supported_roll_lowest_bone_px"]=lowest
	view.free()
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
