extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Keys=preload("res://combat_pc/visuals/wall_keys.gd")
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
	_geometry();_contacts();_surface_bounds();_ownership()
	await _drawing()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original MOKSHA wall pose/contact geometry and passive ownership; no claim of recovered frame or action timing"}
	FileAccess.open("res://combat_pc/visuals/tests/wall_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/wall_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original MOKSHA wall pose vectors; offline inspection, not gameplay capture","samples":samples},"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func snapshot(mode:String,p:float,wall_side:int=1,low:bool=false,locked:bool=false,gap:float=8.05) -> Dictionary:
	var actor_root:=Vector2(0,200-p*24)
	if mode=="wall_slide":actor_root.y=152+p*18
	elif mode=="wall_kick":actor_root=Vector2(-wall_side*p*32,176-p*25)
	var body_facing:int=wall_side if mode!="wall_kick" or locked else -wall_side
	if locked and mode!="wall_kick":body_facing=-wall_side
	return {"position":actor_root,"world_position":actor_root,"velocity":Vector2(0,-140),"facing":body_facing,"grounded":false,"body_height":20.0 if low else 34.0,"body_width":16.0,"crouched":low,"pose":mode,"main_action":"wall","wall_phase":mode.trim_prefix("wall_"),"wall_active":mode!="wall_kick","wall_phase_progress":p,"wall_side":wall_side,"wall_normal":Vector2(-wall_side,0),"wall_plane_x":wall_side*gap,"wall_top_y":0.0,"wall_bottom_y":300.0,"wall_contact_id":7 if mode!="wall_kick" else 0,"wall_relative_travel":-p*24,"wall_episode_serial":3,"wall_kick_direction":-wall_side,"wall_kick_progress":p,"weapon_phase":"idle"}
func _geometry() -> void:
	var arm_error:=0.0;var leg_error:=0.0;var penetration:=-INF;var low_top:=0.0;var lowest:=-INF
	var worst_wall:="";var worst_low:="";var worst_arm:="";var painted_penetration:=-INF
	for mode in Keys.MODES:
		for low in [false,true]:
			for locked in [false,true]:
				for gap in [8.05,10.0,12.0]:
					for i in range(81):
						var p:=float(i)/80
						var t:=snapshot(mode,p,1,low,locked,gap)
						var before:=t.duplicate(true)
						var pose:Dictionary=Pose.evaluate(mode,p,t)
						check(t==before and pose.facing==t.facing and not pose.weapon.visible,"wall art preserves motor facing and telemetry")
						var points:Array=[]
						for bone in Pose.BONE_NAMES:
							check(Vector2(pose.bones[bone]).is_finite(),"finite wall "+mode+"/"+bone)
							points.append({"label":bone,"point":pose.bones[bone],"radius":0.79 if bone.begins_with("toe_") or bone.begins_with("heel_") or bone.begins_with("sole_") else (0.70 if bone in ["knee_near","elbow_near"] else (0.63 if bone.begins_with("palm_") else 0.53))})
							lowest=maxf(lowest,float(pose.bones[bone].y))
							if low and pose.bones[bone].y<low_top:low_top=pose.bones[bone].y;worst_low=mode+"/"+bone+" "+str(p)
						for offset in HEAD:
							var point:Vector2=(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)));point.x*=pose.facing
							point+=Vector2(pose.bones.head);points.append({"label":"head_outline","point":point,"radius":0.53})
							if low and point.y<low_top:low_top=point.y;worst_low=mode+" head outline "+str(p)
						for index in 2:
							var suffix:String="near" if index==0 else "far"
							var palm:Vector2=pose.bones["palm_"+suffix]
							if not (pose.wall_support and pose.wall_touch_hands[index]):
								var direction:Vector2=(palm-Vector2(pose.bones["elbow_"+suffix])).normalized()
								var across:=Vector2(-direction.y,direction.x)
								for point in [palm-across*0.9,palm+across*0.9]:points.append({"label":"palm_edge_"+suffix,"point":point,"radius":0.63})
								points.append({"label":"fingers_"+suffix,"point":palm+direction*1.7+across*0.65,"radius":0.42})
						for point in points:
							var depth:float=(t.position.x+point.point.x-float(t.wall_plane_x))*float(t.wall_side)
							painted_penetration=maxf(painted_penetration,depth+float(point.radius))
							if depth>penetration:penetration=depth;worst_wall="%s %s low%s locked%s gap%.2f p%.3f"%[mode,point.label,low,locked,gap,p]
						for side in ["near","far"]:
							var ae:=absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-Body.TUNING.lower_arm)
							var le:=absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-Body.TUNING.lower_leg)
							if ae>arm_error:arm_error=ae;worst_arm=mode+"/"+side+" "+str(p)
							leg_error=maxf(leg_error,le)
						if gap==8.05 and i in [0,20,40,60]:
							if not locked:
								samples.append({"label":mode+("_low" if low else ""),"pose":_encode(pose),"telemetry":_encode(t)})
								if not low:
									var mirrored_t:=snapshot(mode,p,-1)
									samples.append({"label":mode+"_left","pose":_encode(Pose.evaluate(mode,p,mirrored_t)),"telemetry":_encode(mirrored_t)})
							elif mode=="wall_kick" and not low:samples.append({"label":"wall_kick_locked_facing","pose":_encode(pose),"telemetry":_encode(t)})
			for locked in [false,true]:
				var right:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,1,low,locked))
				var left:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,0.37,-1,low,locked))
				for bone in Pose.BONE_NAMES:check(Vector2(-right.bones[bone].x,right.bones[bone].y).distance_to(left.bones[bone])<0.001,"mirrored wall geometry "+mode+"/"+bone)
	metrics={"arm_reach_error_px":arm_error,"leg_reach_error_px":leg_error,"maximum_wall_penetration_px":penetration,"worst_wall":worst_wall,"low_body_top_px":low_top,"worst_low":worst_low,"lowest_bone_px":lowest,"worst_arm":worst_arm,"maximum_painted_wall_penetration_px":painted_penetration}
	check(arm_error<0.15 and leg_error<0.15,"wall anatomy remains reachable")
	check(penetration<=-0.3 and painted_penetration<=0.001,"mirrored bones, head outlines and conservative stroke widths stay outside wall plane")
	check(low_top>=-19.7 and lowest<=0.001,"wall low variants fit20px and stay above physical foot plane")
func _contacts() -> void:
	var drift:=0.0;var plane_error:=0.0;var pairs:=0
	for wall_side in [-1,1]:
		var view=Visual.new();var old:Dictionary={};var old_on:Dictionary={}
		for i in range(121):
			var t:=snapshot("wall_run",0,wall_side)
			t.position=Vector2(0,200-float(i)*0.5);t.world_position=t.position;t.wall_relative_travel=-float(i)*0.5
			view.present(1.0/120,t)
			var pose:Dictionary=view.get_pose()
			for index in 2:
				var side:String="near" if index==0 else "far"
				var point:Vector2=t.position+Vector2(pose.bones["sole_"+side])
				if pose.planted_feet[index]:
					plane_error=maxf(plane_error,absf((float(t.wall_plane_x)-point.x)*wall_side-float(Keys.TUNING.foot_skin)))
					check(absf(pose.bones["heel_"+side].x-pose.bones["toe_"+side].x)<0.001,"planted wall sole uses vertical wall-normal geometry")
					if bool(old_on.get(side,false)):drift=maxf(drift,point.distance_to(old[side]));pairs+=1
				old[side]=point;old_on[side]=pose.planted_feet[index]
		var slide:=snapshot("wall_slide",0.3,wall_side)
		var running:=snapshot("wall_run",0.1,wall_side)
		view.present(0,running);var run_hold:Dictionary=view.get_pose()
		running["paused"]=true;running.position+=Vector2(wall_side*2,-3);running.world_position=running.position
		running.wall_plane_x+=wall_side*2;running.wall_top_y-=3;running.wall_bottom_y-=3
		view.present(0.02,running)
		check(view.get_pose()==run_hold,"paused wall-run plants follow validated carrier transport without cycling")
		view.present(0,slide);var before:Dictionary=view.get_pose()
		var old_hand:Vector2=slide.position+Vector2(before.bones.palm_near)
		slide.position.y+=5;slide.world_position=slide.position
		view.present(0.02,slide);var after:Dictionary=view.get_pose()
		check(after.planted_feet==[false,false] and after.planted_hands==[false,false],"slide contacts do not claim planted wall locks")
		check(absf((slide.position+Vector2(after.bones.palm_near)-old_hand).y-5)<0.001,"slide palm moves along wall with authoritative descent")
		var held:Dictionary=view.get_pose();slide["paused"]=true
		slide.position+=Vector2(wall_side*3,-2);slide.world_position=slide.position;slide.wall_plane_x+=wall_side*3;slide.wall_top_y-=2;slide.wall_bottom_y-=2;slide["wall_support_transport"]=Vector2(wall_side*3,-2)
		view.present(0.016,slide)
		check(view.get_pose()==held,"paused swept wall transport preserves local pose")
		view.free()
	metrics["wall_plant_drift_px"]=drift;metrics["wall_sole_plane_error_px"]=plane_error;metrics["wall_planted_frame_pairs"]=pairs
	check(drift<0.003 and plane_error<0.001 and pairs>50,"actual-travel wall foot plants stay fixed and on plane")

func _surface_bounds() -> void:
	for wall_side in [-1,1]:
		for scale_factor in [0.5,1.0,2.0,3.0]:
			for low in [false,true]:
				for mode in ["wall_run","wall_slide"]:
					for i in range(31):
						var p:=float(i)/30
						var t:=snapshot(mode,p,wall_side,low)
						t.wall_top_y=170.0;t.wall_bottom_y=170.0+32.0*scale_factor
						var pose:Dictionary=Pose.evaluate(mode,p,t)
						for index in 2:
							var side:String="near" if index==0 else "far"
							for limb in ["hand","foot"]:
								var touches:bool=pose.wall_touch_hands[index] if limb=="hand" else pose.wall_touch_feet[index]
								if touches:
									var point:Vector2=t.position+Vector2(pose.bones[("palm_" if limb=="hand" else "sole_")+side])
									check(point.y>=float(t.wall_top_y) and point.y<=float(t.wall_bottom_y),"contacts respect finite authoritative scaled wall bounds")
	var first_t:=snapshot("wall_kick",0.02,1,false,true)
	var second_t:=first_t.duplicate(true)
	var first:Dictionary=Pose.evaluate("wall_kick",0.02,first_t)
	var second:Dictionary=Pose.evaluate("wall_kick",0.14,second_t)
	check(first.bones==second.bones,"kick holds its compressed key before the decisive push")
	var seam_view=Visual.new();var seam_t:=snapshot("wall_run",0.1)
	seam_view.present(0,seam_t);var seam_pose:Dictionary=seam_view.get_pose()
	seam_t.wall_contact_id=8
	seam_view.event("wall_support_changed",{"previous_id":7,"contact_id":8,"episode":3})
	seam_view.present(0,seam_t)
	check(seam_view.get_pose()==seam_pose,"coplanar support transfer preserves gait phase and pose")
	seam_view.free()
func _ownership() -> void:
	var view=Visual.new();var markers:Array=[]
	view.phase_event.connect(func(event_name:String,payload:Dictionary):markers.append({"event":event_name,"payload":payload}))
	view.event("wall_attached");view.present(0,snapshot("wall_run",0.1))
	markers.clear();view.event("wall_detached",{"reason":"jump"});view.event("wall_kick",{"direction":-1})
	view.present(0,snapshot("wall_kick",0,1,false,true))
	check(view.pose_name=="wall_kick" and view.get_pose().facing==1,"outward kick honors host-locked body facing")
	check(not view.get_pose().wall_support and view.get_pose().planted_feet==[false,false] and view.get_pose().planted_hands==[false,false],"kick retires all wall support immediately")
	var released:=0
	for marker in markers:
		if marker.event in ["foot_release","hand_release"]:released+=1
	check(released>0,"wall detachment explicitly retires prior contact markers")
	view.event("wall_attached");view.present(0,snapshot("wall_run",0.1))
	view.event("wall_ledge_handoff");view.event("ledge_catch")
	var t:Dictionary={"position":Vector2.ZERO,"main_action":"ledge","pose":"ledge_catch","phase_progress":0.0,"palm_target":Vector2(9.2,-29),"hang_target":Vector2.ZERO,"facing":1,"grounded":false,"wall_phase":"run","wall_active":true}
	view.present(0,t)
	check(view.pose_name=="ledge_catch" and not view.get_pose().wall_support,"valid ledge handoff supersedes old wall fields")
	check(Vector2(view.get_pose().bones.palm_near).distance_to(Vector2(9,-29))<0.001,"ledge handoff uses actual existing palm target")
	for action in ["roll","dive","attack","hurt","climb"]:
		view.event("wall_attached");view.present(0,snapshot("wall_run",0.1));view.event("wall_detached",{"reason":action})
		var next:Dictionary={"position":Vector2.ZERO,"grounded":false,"facing":1,"wall_phase":"run","wall_active":false}
		var expected:String
		match action:
			"roll":next.main_action="roll";next.pose="roll_start";next.roll_phase="start";expected="roll_start"
			"dive":next.main_action="dive";next.pose="dive_startup";next.dive_phase="startup";expected="dive_startup"
			"attack":next.main_action="attack";next.pose="attack_windup";next.weapon_phase="windup";expected="attack_windup"
			"climb":next.main_action="climb";next.pose="climb_idle";next.climb_phase="idle";next.climb_active=true;expected="climb_idle"
			_:next.main_action="hurt";next.pose="hurt";expected="hurt"
		view.present(0,next)
		check(view.pose_name==expected and not view.get_pose().wall_support,"new owner retires wall contacts: "+action)
	view.event("wall_detached",{"reason":"neutral_release"});view.present(0,{"pose":"fall","main_action":"locomotion","grounded":false,"wall_kick_grace":0.06,"wall_active":false,"velocity":Vector2(0,80)})
	check(view.pose_name=="fall" and not view.get_pose().wall_support,"kick grace never retains a wall contact pose")
	view.reset_presentation();view.present(0,{"pose":"idle","grounded":true})
	check(view.pose_name=="idle" and view.position==Vector2.ZERO and view.rotation==0 and view.scale==Vector2.ONE,"reset clears wall art while motor transform stays untouched")
	view.free()
func _drawing() -> void:
	var view=Visual.new();root.add_child(view);var draws:Array=[]
	view.draw.connect(func():draws.append(true))
	for mode in Keys.MODES:
		view.present(0.016,snapshot(mode,0.3));await process_frame;await process_frame
	check(draws.size()==Keys.MODES.size(),"headless wall families draw")
	metrics["draw_notifications"]=draws.size();view.queue_free();await process_frame
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
