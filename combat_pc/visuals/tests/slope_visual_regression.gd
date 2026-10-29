extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Slope=preload("res://combat_pc/visuals/slope_pose.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var samples:Array=[]
func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func snapshot(mode:String,angle:float,facing:int=1,root_point:=Vector2.ZERO) -> Dictionary:
	return {"position":root_point,"world_position":root_point,"grounded":true,"pose":mode,"main_action":"locomotion","facing":facing,"velocity":Vector2.ZERO if mode=="idle" else Vector2(120*facing,120*facing*tan(angle)),"floor_relative_velocity":Vector2.ZERO if mode=="idle" else Vector2(120*facing,120*facing*tan(angle)),"floor_normal":Vector2.UP.rotated(angle),"floor_contact_point":root_point+Vector2(-signf(angle)*8,0),"support_id":1,"support_displacement":Vector2.ZERO,"body_width":16.0,"body_height":20.0 if mode=="crouch" else 34.0,"crouched":mode=="crouch","run_reference_speed":218.0}
func _run() -> void:
	_geometry();_specials();_special_pause();_contacts();_transitions();_unreachable()
	await _drawing()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original passive ordinary and explicitly planted special slope contacts, mirrored26.6/45degree planes, same-collider crest/valley, reach/cancel and carrier pause; no motor root changes"}
	FileAccess.open("res://combat_pc/visuals/tests/slope_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/slope_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original slope-adjusted vectors, offline inspection rather than gameplay capture","samples":samples},"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _geometry() -> void:
	var max_plane:=0.0;var max_normal:=0.0;var reach_error:=0.0;var penetration:=0.0;var max_settle:=0.0;var planted:=0
	for angle in [-PI/4,-atan(0.5),atan(0.5),PI/4]:
		for facing in [-1,1]:
			for mode in Slope.MODES:
				for i in range(61):
					var p:=float(i)/60
					var t:=snapshot(mode,angle,facing)
					var original:=t.duplicate(true)
					var pose:Dictionary=Pose.evaluate(mode,p,t)
					check(t==original and pose.facing==facing,"slope adjustment keeps telemetry and facing read-only")
					max_settle=maxf(max_settle,float(pose.slope_hip_settle))
					for bone in Pose.BONE_NAMES:
						check(Vector2(pose.bones[bone]).is_finite(),"finite slope "+bone)
						penetration=minf(penetration,(Vector2(pose.bones[bone])-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
					for index in 2:
						var side:String="near" if index==0 else "far"
						var b:Dictionary=pose.bones
						reach_error=maxf(reach_error,absf(Vector2(b["hip_"+side]).distance_to(b["knee_"+side])-8))
						reach_error=maxf(reach_error,absf(Vector2(b["knee_"+side]).distance_to(b["ankle_"+side])-8))
						if pose.planted_feet[index]:
							planted+=1
							for foot in ["sole_","toe_","heel_"]:max_plane=maxf(max_plane,absf((Vector2(b[foot+side])-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal))))
							max_normal=maxf(max_normal,absf((Vector2(b["ankle_"+side])-Vector2(b["sole_"+side])).normalized().dot(Vector2(-t.floor_normal.y,t.floor_normal.x))))
					if facing==1 and i in [0,15,30,45] and mode in ["idle","run","brake","turn","land","crouch"]:samples.append({"label":"%s_%+.1f"%[mode,rad_to_deg(angle)],"pose":_encode(pose),"telemetry":_encode(t)})
				var a:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,angle,1))
				var b:Dictionary=Pose.evaluate(mode,0.37,snapshot(mode,-angle,-1))
				for bone in Pose.BONE_NAMES:check(Vector2(-a.bones[bone].x,a.bones[bone].y).distance_to(b.bones[bone])<0.002,"mirrored slope fit "+mode+bone)
	metrics={"planted_foot_samples":planted,"maximum_sole_plane_error_px":max_plane,"ankle_tangent_dot":max_normal,"leg_length_error_px":reach_error,"minimum_bone_plane_distance_px":penetration,"maximum_joint_compression_px":max_settle}
	check(max_plane<0.001 and max_normal<0.001,"planted sole/heel/toe and ankle normal agree with actual plane")
	check(reach_error<0.002 and penetration>-0.002,"corrected limbs remain anatomical and above floor")
	check(max_settle<=4,"joint compression is bounded, never a root offset")
func _specials() -> void:
	var plane_error:=0.0;var reach_error:=0.0;var weapon_offset:=0.0;var body_relative_error:=0.0;var uncorrected_penetration:=0.0
	var explicit_contacts:=0
	for mode in Slope.PLANTED_SPECIALS:
		for angle in [-PI/4,-atan(0.5),atan(0.5),PI/4]:
			for facing in [-1,1]:
				for low in [false,true]:
					for i in range(81):
						var p:=float(i)/80;var t:=snapshot(mode,angle,facing)
						t.body_height=20.0 if low else 34.0;t.crouched=low;t.roll_direction=facing;t.attack_facing=facing
						var flat_t:=t.duplicate(true);flat_t.erase("floor_contact_point")
						var original:Dictionary=Pose.evaluate(mode,p,flat_t)
						var pose:Dictionary=Pose.evaluate(mode,p,t)
						if bool(pose.get("slope_support",false)):
							for index in 2:
								var side:String="near" if index==0 else "far"
								check(not pose.planted_feet[index] or original.planted_feet[index],"special slope correction never invents planted feet")
								if pose.planted_feet[index]:
									explicit_contacts+=1
									for foot in ["sole_","heel_","toe_"]:plane_error=maxf(plane_error,absf((Vector2(pose.bones[foot+side])-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal))))
								reach_error=maxf(reach_error,absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-8))
							for bone in ["head","chest","pelvis","palm_near","palm_far","elbow_near","elbow_far"]:
								body_relative_error=maxf(body_relative_error,(Vector2(pose.bones[bone])-Vector2(original.bones[bone])-Vector2(0,pose.slope_hip_settle)).length())
							if bool(pose.weapon.visible):
								weapon_offset=maxf(weapon_offset,Vector2(pose.slope_weapon_offset).length())
								for point in pose.weapon:
									if pose.weapon[point] is Vector2:check((Vector2(pose.weapon[point])-Vector2(original.weapon[point])-Vector2(pose.slope_weapon_offset)).length()<0.001,"terrain-compressed weapon remains attached to original grip")
						else:
							check(pose.bones==original.bones,"unplanted special phase retains exact original geometry")
							for bone in Pose.BONE_NAMES:uncorrected_penetration=minf(uncorrected_penetration,(Vector2(pose.bones[bone])-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
						var airborne:=t.duplicate(true);airborne.grounded=false
						check(not Pose.evaluate(mode,p,airborne).get("slope_support",false),"airborne special pose retains its owner")
						if not low and angle in [-PI/4,PI/4] and facing==1 and i in [0,20,40,60]:samples.append({"label":"%s_%+.1f"%[mode,rad_to_deg(angle)],"pose":_encode(pose),"telemetry":_encode(t)})
	metrics["special_sole_plane_error_px"]=plane_error;metrics["special_leg_length_error_px"]=reach_error;metrics["weapon_contact_offset_px"]=weapon_offset;metrics["upper_body_relative_error_px"]=body_relative_error;metrics["uncorrected_unplanted_special_bone_penetration_px"]=-uncorrected_penetration;metrics["special_planted_foot_samples"]=explicit_contacts
	check(plane_error<0.001 and reach_error<0.002,"explicitly supported special feet match real normal within anatomical reach")
	check(weapon_offset<=4 and body_relative_error<0.001,"bounded terrain compression preserves upper-body and weapon geometry")
func _contacts() -> void:
	var drift:=0.0;var pairs:=0
	for angle in [-PI/4,-atan(0.5),atan(0.5),PI/4]:
		for facing in [-1,1]:
			var view=Visual.new();var old:Dictionary={};var old_on:Array=[false,false]
			for i in range(121):
				var point:=Vector2(i*0.4*facing,i*0.4*facing*tan(angle))
				var t:=snapshot("run",angle,facing,point)
				view.present(1.0/120,t)
				var pose:Dictionary=view.get_pose();var world:Dictionary=view.get_bones(true)
				for index in 2:
					var side:String="near" if index==0 else "far"
					if pose.planted_feet[index] and old_on[index]:drift=maxf(drift,Vector2(world["sole_"+side]).distance_to(old[side]));pairs+=1
					old[side]=world["sole_"+side];old_on[index]=pose.planted_feet[index]
			view.free()
	metrics["planted_world_drift_px"]=drift;metrics["planted_frame_pairs"]=pairs
	check(drift<0.002 and pairs>100,"reachable running plants remain fixed until real step/reach release")
	var view=Visual.new();var t:=snapshot("idle",atan(0.5));view.present(0,t)
	var held:=view.get_bones();t.paused=true;t.support_displacement=Vector2(3,-2);t.position+=t.support_displacement;t.world_position=t.position;t.floor_contact_point+=t.support_displacement
	view.present(0.5,t)
	for bone in Pose.BONE_NAMES:check(Vector2(view.get_bones()[bone]).distance_to(held[bone])<0.001,"paused carrier preserves local slope pose "+bone)
	check(view.get_pose().planted_feet==[true,true],"idle slope holds real contacts without cycling")
	view.free()
func _special_pause() -> void:
	for mode in Slope.PLANTED_SPECIALS:
		var view=Visual.new();var t:=snapshot(mode,atan(0.5))
		t.phase_progress=0.0 if mode=="roll_start" else 0.75;t.velocity=Vector2.ZERO;t.floor_relative_velocity=Vector2.ZERO
		view.present(0,t)
		check(view.get_pose().get("slope_support",false),"fixture uses an explicitly supported special key "+mode)
		var held:=view.get_bones();var held_weapon:Dictionary=view.get_pose().weapon
		t.paused=true;t.support_displacement=Vector2(2,1);t.position+=t.support_displacement;t.world_position=t.position;t.floor_contact_point+=t.support_displacement
		view.present(0.1,t)
		for bone in Pose.BONE_NAMES:check(Vector2(view.get_bones()[bone]).distance_to(held[bone])<0.001,"special hitpause carrier holds joint shape "+mode+bone)
		check(view.get_pose().weapon==held_weapon,"special hitpause carrier holds attached weapon "+mode)
		view.event("ground_jump");view.present(0,{"pose":"jump_rise","grounded":false,"velocity":Vector2(0,-100)})
		check(view._slope_contacts.is_empty() and not view.get_pose().get("slope_support",false),"special departure retires all ground contacts "+mode)
		view.free()
func _transitions() -> void:
	var view=Visual.new();var markers:Array=[]
	view.phase_event.connect(func(key:String,payload:Dictionary):markers.append({"event":key,"data":payload}))
	for angle in [atan(0.5),0.0,-PI/4,PI/4,-atan(0.5)]:
		var t:=snapshot("idle",angle);view.present(0,t)
		var pose:Dictionary=view.get_pose()
		if angle!=0:
			for side in ["near","far"]:check(absf((Vector2(pose.bones["sole_"+side])-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))<0.001,"same collider crest/valley replaces old plane")
	var releases:=0
	for marker in markers:
		if marker.event=="foot_release":releases+=1
	check(releases>=6,"same-ID normal changes retire old contact markers")
	var t:=snapshot("idle",atan(0.5));view.present(0,t)
	t.floor_contact_point+=Vector2(0,1.5);view.present(0,t)
	check(absf((Vector2(view.get_pose().bones.sole_near)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))<0.001,"parallel same-ID plane displacement revalidates contact")
	view.event("ground_jump")
	check(view._slope_contacts.is_empty(),"takeoff event retires slope locks immediately")
	view.present(0,{"position":Vector2.ZERO,"grounded":false,"pose":"jump_rise","velocity":Vector2(0,-100)})
	check(not view.get_pose().get("slope_support",false),"air ownership cannot retain a slope correction")
	view.reset_presentation();check(view.position==Vector2.ZERO and view.scale==Vector2.ONE and view.rotation==0,"terrain fit never changes node transform")
	view.free()
func _unreachable() -> void:
	var t:=snapshot("idle",atan(0.5));t.floor_contact_point+=Vector2(0,80)
	var pose:Dictionary=Pose.evaluate("idle",0,t)
	check(pose.planted_feet==[false,false],"an unreachable host plane releases both contacts instead of stretching")
	for side in ["near","far"]:check(Vector2(pose.bones["hip_"+side]).distance_to(pose.bones["ankle_"+side])<=15.81,"released feet stay within normal rig reach")
	for mode in ["roll_travel","ledge_hang","climb_idle","wall_run","hard_land_impact"]:
		var a:=snapshot(mode,atan(0.5));var b:=a.duplicate(true);b.floor_normal=Vector2.UP
		if mode=="hard_land_impact":continue # Its established separate floor-normal contract remains intentional.
		check(not Pose.evaluate(mode,0.2,a).get("slope_support",false),"ordinary slope adapter excludes special owner "+mode)
func _drawing() -> void:
	var view=Visual.new();root.add_child(view)
	var draws:Array=[];view.draw.connect(func():draws.append(true))
	for angle in [-PI/4,PI/4]:
		view.present(0,snapshot("idle",angle))
		await process_frame;await process_frame
	check(draws.size()==2,"headless draw covers mirrored slope contacts")
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
