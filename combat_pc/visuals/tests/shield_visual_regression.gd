extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Keys=preload("res://combat_pc/visuals/shield_keys.gd")
const HEAD=[Vector2(-2.1,-2),Vector2(0.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-0.25),Vector2(3.2,0.55),Vector2(1.6,1.1),Vector2(0.7,2.5),Vector2(-1.8,2),Vector2(-2.5,0.5)]
var checks:=0;var failures:Array[String]=[];var metrics:Dictionary={};var samples:Array=[]
func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func snapshot(mode:String,p:float,low:bool=false,facing:int=1,air_y:float=INF,angle:float=0) -> Dictionary:
	var height:=20.0 if low else 34.0
	return {"position":Vector2.ZERO,"velocity":Vector2(0,0 if is_inf(air_y) else air_y),"facing":facing,"grounded":is_inf(air_y),"body_height":height,"crouched":low,"pose":mode,"main_action":"locomotion","weapon_phase":"idle","shield_active":true,"shield_phase":mode.trim_prefix("shield_"),"shield_phase_progress":p,"shield_serial":3,"shield_facing":facing,"shield_center":Vector2(facing*11,-height*0.55),"shield_size":Vector2(10,height-4),"shield_normal":Vector2(facing,0),"shield_parry_open":mode=="shield_parry","floor_normal":Vector2.UP.rotated(angle),"floor_contact_point":Vector2(-signf(angle)*8,0),"support_id":1,"support_displacement":Vector2.ZERO}
func _run() -> void:
	_geometry();_phase_context();_feedback();_ownership()
	await _drawing()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original shield pose, band, anatomical reach and frozen-event feedback; motor owns timing, geometry and defense/effect outcomes"}
	FileAccess.open("res://combat_pc/visuals/tests/shield_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://combat_pc/visuals/tests/shield_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original shield vectors; offline inspection, not native gameplay capture","samples":samples},"\t"))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func _geometry() -> void:
	var arm_error:=0.0;var leg_error:=0.0;var band_error:=0.0;var low_top:=0.0;var floor_depth:=0.0;var detached:=0;var guard_depth:=0.0;var clipped_depth:=0.0;var clip_count:=0
	for mode in Keys.MODES:
		for low in [false,true]:
			for air_y in [INF,-180.0,0.0,200.0]:
				for angle in [-PI/4,0.0,PI/4]:
					for i in range(41):
						var p:=float(i)/40;var t:=snapshot(mode,p,low,1,air_y,angle);var before:=t.duplicate(true)
						var pose:Dictionary=Pose.evaluate(mode,p,t)
						check(t==before and not pose.weapon.visible and pose.shield.visible,"pure shield pose preserves telemetry and removes sword")
						if not pose.shield.attached:detached+=1
						for bone in Pose.BONE_NAMES:
							check(Vector2(pose.bones[bone]).is_finite(),"finite shield "+bone)
							if low:low_top=minf(low_top,pose.bones[bone].y)
							if is_inf(air_y):floor_depth=minf(floor_depth,(Vector2(pose.bones[bone])-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
						for side in ["near","far"]:
							arm_error=maxf(arm_error,absf(Vector2(pose.bones["shoulder_"+side]).distance_to(pose.bones["elbow_"+side])-6))
							arm_error=maxf(arm_error,absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-5.8))
							leg_error=maxf(leg_error,absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-8))
						check(pose.shield.grip==pose.bones.palm_near,"shield grip stays on the near palm")
						check(pose.shield.raw_outline==pose.shield.outline,"raw defense band remains available independently from clipping")
						if is_inf(air_y):
							if pose.shield.occluded_by_floor:clip_count+=1
							for segment in pose.shield.visible_segments:
								for point in segment:clipped_depth=minf(clipped_depth,(Vector2(point)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
						else:check(not pose.shield.occluded_by_floor and pose.shield.visible_segments.size()==8,"airborne guard ignores stale floor data")
						var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
						for point in pose.shield.outline:
							minimum=minimum.min(point);maximum=maximum.max(point)
							if is_inf(air_y):guard_depth=minf(guard_depth,(Vector2(point)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
							if low:low_top=minf(low_top,point.y)
						band_error=maxf(band_error,minimum.distance_to(t.shield_center-t.shield_size/2));band_error=maxf(band_error,maximum.distance_to(t.shield_center+t.shield_size/2))
						if low:
							for offset in HEAD:
								var point:Vector2=Vector2(pose.bones.head)+(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)))
								low_top=minf(low_top,point.y)
						if not is_inf(air_y):check(pose.planted_feet==[false,false],"air guard never invents floor support")
						if angle==0 and i in [0,10,20,30,40] and air_y in [INF,-180.0]:samples.append({"label":mode+("_low" if low else "")+("_air" if not is_inf(air_y) else ""),"pose":_encode(pose),"telemetry":_encode(t)})
			for p in [0.0,0.4,1.0]:
				var right:Dictionary=Pose.evaluate(mode,p,snapshot(mode,p,low,1,INF,PI/4))
				var left:Dictionary=Pose.evaluate(mode,p,snapshot(mode,p,low,-1,INF,-PI/4))
				for bone in Pose.BONE_NAMES:check(Vector2(-right.bones[bone].x,right.bones[bone].y).distance_to(left.bones[bone])<0.002,"mirror shield joints "+bone)
				for i in right.shield.raw_outline.size():check(Vector2(-right.shield.raw_outline[i].x,right.shield.raw_outline[i].y).distance_to(left.shield.raw_outline[i])<0.002,"mirrored authoritative guard outline")
				check(right.shield.visible_segments.size()==left.shield.visible_segments.size(),"mirrored grounded guard occlusion topology")
	metrics={"arm_length_error_px":arm_error,"leg_length_error_px":leg_error,"band_bounds_error_px":band_error,"low_body_and_guard_top_px":low_top,"minimum_body_floor_distance_px":floor_depth,"unreachable_default_grips":detached,"reported_guard_outline_floor_overlap_px":-guard_depth,"visible_guard_floor_overlap_px":-clipped_depth,"occluded_ground_samples":clip_count}
	check(arm_error<0.01 and leg_error<0.01,"all shield limbs retain authored lengths")
	check(band_error<0.001 and detached==0,"default reported guard band stays attached and exactly bounded")
	check(low_top>=-19.7 and floor_depth>=-0.01,"crouch guard fits20px and supported body stays above floor")
	check(clipped_depth>=-0.001 and clip_count>0,"grounded presentation clipping removes drawn floor crossings without changing raw band")
func _phase_context() -> void:
	for pair in [["shield_raise","shield_parry"],["shield_parry","shield_hold"],["shield_hold","shield_release_recovery"],["shield_hold","shield_miss_recovery"]]:
		var a:=Pose.evaluate(pair[0],1,snapshot(pair[0],1));var b:=Pose.evaluate(pair[1],0,snapshot(pair[1],0))
		for bone in Pose.BONE_NAMES:check(Vector2(a.bones[bone]).distance_to(b.bones[bone])<0.001,"continuous phase boundary "+str(pair)+bone)
	var hold_a:=Pose.evaluate("shield_hold",0,snapshot("shield_hold",0));var hold_b:=Pose.evaluate("shield_hold",1,snapshot("shield_hold",1))
	check(hold_a.bones==hold_b.bones,"indefinite guard has no fake looping or expiry pose")
	var success_a:=Pose.evaluate("shield_success_recovery",0,snapshot("shield_success_recovery",0));var success_b:=Pose.evaluate("shield_success_recovery",0.4,snapshot("shield_success_recovery",0.4))
	check(success_a.bones==success_b.bones,"successful incoming defense starts with a held deflection key")
	var rise:=Pose.evaluate("shield_hold",0,snapshot("shield_hold",0,false,1,-180));var fall:=Pose.evaluate("shield_hold",0,snapshot("shield_hold",0,false,1,180))
	check(rise.bones.sole_near.distance_to(fall.bones.sole_near)>4,"air guard retains rising versus falling legs")
	var moving:=snapshot("shield_hold",0);moving.velocity=Vector2(100,0);moving.gait_phase=0.1
	var first:=Pose.evaluate("shield_hold",0,moving);moving.gait_phase=0.6
	var next:=Pose.evaluate("shield_hold",0,moving)
	check(first.bones.sole_near.distance_to(next.bones.sole_near)>3,"held guard legs follow existing actual-travel gait")
	var distant:=snapshot("shield_hold",0);distant.shield_center=Vector2(120,-18.7)
	var bounded:=Pose.evaluate("shield_hold",0,distant)
	check(not bounded.shield.attached and bounded.shield.center==distant.shield_center,"out-of-reach custom band stays authoritative and reports unattached")
	check(absf(Vector2(bounded.bones.shoulder_near).distance_to(bounded.bones.elbow_near)-6)<0.001 and absf(Vector2(bounded.bones.elbow_near).distance_to(bounded.bones.palm_near)-5.8)<0.001,"custom band cannot stretch the original arm")
	var landing:=snapshot("shield_hold",0);landing.landing_visual_progress=0.0;landing.preimpact_speed=520
	var compressed:=Pose.evaluate("shield_hold",0,landing)
	check(compressed.bones.pelvis.y>hold_a.bones.pelvis.y+1.5 and compressed.shield.center==hold_a.shield.center,"real soft landing compresses behind unchanged guard geometry")
func payload(kind:String="parried") -> Dictionary:
	return {"outcome":kind,"consumed":true,"shield_serial":3,"shield_facing":1,"contact_position":Vector2(7,-20),"normal":Vector2.RIGHT,"attack_key":"fixture/1","counter_confirmed":false,"reflection_confirmed":false}
func _feedback() -> void:
	var view=Visual.new();view.event("shield_started",{"serial":3})
	var t:=snapshot("shield_parry",0.3);view.present(0,t)
	view.event("defense_resolved",payload());t=snapshot("shield_success_recovery",0);view.present(0,t)
	check(view.get_pose().shield.feedback.size()==1 and view.get_pose().shield.feedback[0].kind=="parried","incoming parry produces defense feedback without a counter-hit claim")
	view.event("defense_resolved",payload());view.present(0,t)
	check(view.get_pose().shield.feedback.size()==1,"duplicate defense event cannot repeat visual impact")
	var held:=view.get_bones();t.paused=true;t.position=Vector2(2,-1);t.shield_center+=t.position;t.floor_contact_point+=t.position;t.support_displacement=t.position
	view.present(0.2,t)
	for bone in Pose.BONE_NAMES:check(Vector2(view.get_bones()[bone]).distance_to(held[bone])<0.001,"local hitpause carrier preserves shield body "+bone)
	check(view.get_pose().shield.feedback[0].point+t.position==Vector2(7,-20),"impact mark stays at actual frozen world contact during carrier movement")
	t.facing=-1;t.shield_facing=-1;t.shield_normal=Vector2.LEFT;t.shield_center=t.position+Vector2(-11,-18.7);t.support_displacement=Vector2.ZERO
	view.present(0,t)
	check(view.get_pose().facing==-1 and view.get_pose().shield.normal==Vector2.LEFT,"current host-approved turn updates guard geometry")
	check(view.get_pose().shield.feedback[0].normal==Vector2.RIGHT and view.get_pose().shield.feedback[0].facing==1,"old contact feedback retains its accepted facing and normal")
	view.event("shield_counter_confirmed",payload());view.present(0,t)
	check(view.get_pose().shield.feedback.size()==2 and view.get_pose().shield.feedback[1].kind=="counter","retaliation confirmation is a separate observable feedback kind")
	view.event("shield_reflection_confirmed",payload());view.present(0,t)
	check(view.get_pose().shield.feedback.size()==3 and view.get_pose().shield.feedback[2].kind=="reflect","accepted reflection is independently visible")
	t.paused=false;view.present(0.11,t)
	check(view.get_pose().shield.feedback.is_empty(),"contact marks expire on actor-local time")
	view.event("shield_started",{"serial":4});view.event("defense_resolved",payload());t.shield_serial=4;view.present(0,t)
	check(view.get_pose().shield.feedback.is_empty(),"old serial cannot mark a new shield attempt")
	view.free()
func _ownership() -> void:
	var view=Visual.new();view.present(0,{"pose":"attack_active","weapon_phase":"active","grounded":true})
	check(view.get_pose().weapon.visible,"fixture starts with sword")
	view.event("shield_started",{"serial":3});check(not view.get_pose().weapon.visible,"shield event immediately hides the old sword before the next present")
	var t:=snapshot("shield_raise",0);t.weapon_phase="active";view.present(0,t)
	check(view.pose_name=="shield_raise" and not view.get_pose().weapon.visible,"shield admission removes old sword immediately")
	for mode in ["hurt","roll_start","attack_windup","dive_startup","jump_rise","idle"]:
		view.event("shield_cancelled",{"serial":3})
		check(not view.get_pose().has("shield"),"cancel event hides the guard before the next present")
		var next:Dictionary={"pose":mode,"grounded":mode=="idle","velocity":Vector2(0,-100),"shield_phase":"hold","shield_active":true}
		if mode=="roll_start":next.roll_phase="start"
		if mode=="attack_windup":next.weapon_phase="windup"
		view.present(0,next)
		check(not view.get_pose().has("shield") and view._shield_feedback.is_empty(),"new owner removes stale guard and feedback "+mode)
	view.present(0,snapshot("shield_hold",0));t=snapshot("shield_hold",0);t.shield_active=false;t.pose="idle";t.shield_phase="idle";view.present(0,t)
	check(not view.get_pose().has("shield"),"disabled/idle shield has no overlay")
	view.reset_presentation();view.present(0,{"pose":"idle","grounded":true})
	check(view.position==Vector2.ZERO and view.rotation==0 and view.scale==Vector2.ONE and not view.get_pose().has("shield"),"reset clears presentation without changing physical transform")
	view.free()
func _drawing() -> void:
	var view=Visual.new();root.add_child(view);var draws:Array=[];view.draw.connect(func():draws.append(true))
	for mode in Keys.MODES:
		view.event("shield_started",{"serial":3});view.event("defense_resolved",payload("guarded" if mode=="shield_hold" else "parried"))
		if mode=="shield_success_recovery":view.event("shield_counter_confirmed",payload())
		if mode=="shield_release_recovery":view.event("shield_reflection_confirmed",payload())
		view.present(0,snapshot(mode,0.3))
		await process_frame;await process_frame
	check(draws.size()==6,"headless runtime draw covers six shield phases and contact marks")
	view.queue_free();await process_frame
func _encode(v:Variant) -> Variant:
	if v is Vector2:return [v.x,v.y]
	if v is Dictionary:
		var out:Dictionary={}
		for key in v:out[key]=_encode(v[key])
		return out
	if v is Array:
		var out:Array=[]
		for item in v:out.append(_encode(item))
		return out
	return v
