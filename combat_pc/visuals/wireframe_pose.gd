@tool
class_name MokshaWireframePose
extends RefCounted
## Pure original MOKSHA pose evaluation. No scene, collision queries, source-game API,
## animation-driven physics, or recovered proprietary keyframe data.
const Keys = preload("res://combat_pc/visuals/wireframe_keys.gd")
const Combat = preload("res://combat_pc/visuals/combat_pose.gd")
const Descent = preload("res://combat_pc/visuals/descent_pose.gd")
const Climb = preload("res://combat_pc/visuals/climb_pose.gd")
const Wall = preload("res://combat_pc/visuals/wall_pose.gd")
const Landing = preload("res://combat_pc/visuals/landing_pose.gd")
const Slope = preload("res://combat_pc/visuals/slope_pose.gd")
const Charge = preload("res://combat_pc/visuals/charge_pose.gd")
const Combo = preload("res://combat_pc/visuals/combo_pose.gd")
const Shield = preload("res://combat_pc/visuals/shield_pose.gd")
const Defeat = preload("res://combat_pc/visuals/defeat_pose.gd")
const BONE_NAMES := ["pelvis","chest","neck","head","hip_near","hip_far","shoulder_near","shoulder_far","elbow_near","elbow_far","palm_near","palm_far","knee_near","knee_far","ankle_near","ankle_far","sole_near","sole_far","heel_near","heel_far","toe_near","toe_far","rib_near","rib_far","waist_near","waist_far"]

static func facing_of(t: Dictionary) -> float:
	return -1.0 if float(t.get("facing",1))<0.0 else 1.0

static func speed_fraction(t: Dictionary) -> float:
	var v: Vector2=t.get("velocity",Vector2.ZERO)
	return clampf(absf(v.x)/float(t.get("run_reference_speed",Keys.TUNING.run_reference_speed)),0.0,1.0)

static func stride_for(t: Dictionary) -> float:
	return lerpf(Keys.TUNING.slow_stride,Keys.TUNING.fast_stride,speed_fraction(t))

static func evaluate(mode: String, phase: float, t: Dictionary={}) -> Dictionary:
	var p:=clampf(phase,0.0,1.0)
	var key: Dictionary=Keys.POSES.ready.duplicate(true)
	var key_name: String="ready"
	var family:=mode
	var clock: float=t.get("visual_time",0.0)
	match mode:
		"defeated", "defeated_air":
			key=Defeat.sample(mode,p)
			key_name=str(key.key_name)
		"idle":
			key.pelvis.y+=sin(clock*2.6)*0.16
			key.head_tilt=sin(clock*1.3)*0.8
		"run", "run_fast", "run_slow":
			key=_gait(p,t)
			key_name=str(key.get("key_name","run"))
		"start", "jump", "air_jump", "brake", "turn", "land", "land_run":
			var sample:=_timeline(mode,p)
			key=sample.pose
			key_name=sample.key_name
			if mode=="start" and p>0.65:
				key=_mix(key,_gait(float(t.get("gait_phase",0.0)),t),smoothstep(0.65,1.0,p))
			if mode in ["brake","turn"]:
				var v:Vector2=t.get("velocity",Vector2.ZERO)
				var travel:=signf(v.x*facing_of(t))
				if is_zero_approx(travel):travel=-1.0 if mode=="turn" else 1.0
				if mode=="brake" and travel<0.0:key=_mirror_key(key)
			if mode in ["land","land_run"]:
				var strength:=clampf(float(t.get("preimpact_speed",300.0))/520.0,0.3,1.0)
				key.pelvis.y=lerpf(float(Keys.POSES.land_recover.pelvis.y),float(key.pelvis.y),strength)
				key.rib_width=lerpf(5.8,float(key.rib_width),strength)
				if mode=="land_run" and p>0.55:key=_mix(key,_gait(float(t.get("gait_phase",0.0)),t),smoothstep(0.55,1.0,p))
		"jump_rise", "rise":key=Keys.POSES.rise.duplicate(true);key_name="rise"
		"jump_apex", "apex":key=Keys.POSES.apex.duplicate(true);key_name="apex"
		"fall":
			key=Keys.POSES.fall.duplicate(true);key_name="fall"
			var v:Vector2=t.get("velocity",Vector2.ZERO)
			key.lean+=clampf(v.y/520.0,0.0,1.0)*5.0
		"crouch":key=Keys.POSES.crouch.duplicate(true);key_name="crouch"
		"ledge_catch", "ledge_hang", "ledge_pull", "ledge_step", "ledge_settle":
			key=_ledge(mode,p,t)
			key_name=str(key.get("key_name",mode))
		"roll_start", "roll_travel", "roll_recovery", "attack_windup", "attack_active", "attack_recovery", "hurt":
			key=Combat.sample(mode,p,t)
			key_name=str(key.key_name)
		"drop", "dive_startup", "dive_descent", "dive_impact", "dive_recovery":
			key=Descent.sample(mode,p,t)
			key_name=str(key.key_name)
		"climb_align", "climb_idle", "climb_ascend", "climb_descend", "climb_top_exit", "climb_blocked", "climb_release":
			key=Climb.sample(mode,p,t)
			key_name=str(key.key_name)
		"wall_run", "wall_slide", "wall_kick":
			key=Wall.sample(mode,p,t)
			key_name=str(key.key_name)
		"hard_land_impact", "hard_land_recovery":
			key=Landing.sample(mode,p,t)
			key_name=str(key.key_name)
		"shield_raise", "shield_parry", "shield_hold", "shield_miss_recovery", "shield_success_recovery", "shield_release_recovery":
			key=Shield.sample(mode,p,t,_gait(float(t.get("gait_phase",0.0)),t))
			key_name=str(key.key_name)
		_:
			if mode in Combo.MODES:
				key=Combo.sample(mode,p,t);key_name=str(key.key_name)
			elif mode in Charge.MODES:
				var travel_velocity:Vector2=t.get("floor_relative_velocity",t.get("velocity",Vector2.ZERO))
				var gait_direction:float=-1.0 if travel_velocity.x*facing_of(t)<0 else 1.0
				key=Charge.sample(mode,p,t,_gait(float(t.get("gait_phase",0.0))*gait_direction,t));key_name=str(key.key_name)
			else:family="idle"
	var pose:=_solve(key)
	pose["mode"]=family
	pose["key"]=key_name
	pose["phase"]=p
	pose["authorship"]="MOKSHA original pose geometry and timing"
	pose["planted_feet"]=key.get("feet_on",[false,false]).duplicate()
	pose["planted_hands"]=key.get("hands_on",[false,false]).duplicate()
	pose["ground_support"] = family not in ["ledge_catch","ledge_hang","ledge_pull"]
	pose["ledge_support"]=family.begins_with("ledge")
	pose["climb_support"]=bool(key.get("climb_support",false))
	pose["wall_support"]=bool(key.get("wall_support",false))
	pose["landing_support"]=bool(key.get("landing_support",false))
	pose["landing_sliding"]=bool(key.get("landing_sliding",false))
	pose["landing_touch_feet"]=key.get("landing_touch_feet",[false,false]).duplicate()
	pose["floor_normal"]=t.get("floor_normal",Vector2.UP)
	pose["wall_touch_hands"]=key.get("wall_touch_hands",[false,false]).duplicate()
	pose["wall_touch_feet"]=key.get("wall_touch_feet",[false,false]).duplicate()
	pose["wall_normal"]=t.get("wall_normal",Vector2(-float(t.get("wall_side",1)),0))
	pose["floor_guard"]=bool(key.get("floor_guard",false))
	pose["head_tilt"]=float(key.get("head_tilt",0.0))+float(key.lean)*0.2
	pose["head_scale"]=Vector2(lerpf(1.0,1.055,clampf((float(key.rib_width)-5.6)/1.2,0,1)),lerpf(1.0,0.96,clampf((float(key.rib_width)-5.6)/1.2,0,1)))
	pose["weapon"]={"visible":false}
	pose["body_rotation"]=0.0
	if mode in Combat.MODES:Combat.finish(pose,key,mode,t)
	elif mode in Combo.MODES:Combo.finish(pose,key,mode,t)
	elif mode in Charge.MODES:Charge.finish(pose,key,mode,t)
	var facing:=facing_of(t)
	if mode.begins_with("roll_"):facing=-1.0 if float(t.get("roll_direction",facing))<0 else 1.0
	elif mode.begins_with("attack_") and mode not in Combo.MODES and mode not in Charge.MODES:facing=-1.0 if float(t.get("attack_facing",facing))<0 else 1.0
	elif mode.begins_with("dive_"):facing=-1.0 if float(t.get("dive_direction",facing))<0 else 1.0
	elif mode in Shield.MODES:facing=-1.0 if float(t.get("shield_facing",facing))<0 else 1.0
	for bone in BONE_NAMES:
		pose.bones[bone].x*=facing
	for point in pose.weapon:
		if pose.weapon[point] is Vector2:pose.weapon[point].x*=facing
	pose["facing"]=int(facing)
	if mode in Combo.MODES or mode in Charge.MODES:Combo.resolve_weapon_facing(pose,key,t)
	Slope.fit(pose,t)
	if mode in Shield.MODES:Shield.finish(pose,key,t)
	if mode in ["defeated","defeated_air"]:Defeat.finish(pose,t)
	if mode in Combo.MODES or mode in Charge.MODES:Combo.occlude_blade(pose,t)
	if (mode in Combo.MODES or mode in Charge.Keys.STRIKE_MODES) and bool(pose.weapon.get("confirmed",false)) and t.has("combo_contact_world"):
		pose.weapon["contact_point"]=Vector2(t.combo_contact_world)-Vector2(t.get("world_position",t.get("position",Vector2.ZERO)))
		pose.weapon["contact_facing"]=int(t.get("combo_contact_facing",facing))
	return pose

static func _mix(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	var result:=a.duplicate(true)
	for field in ["pelvis","lean","torso","head_tilt","rib_width"]:
		result[field]=a[field].lerp(b[field],t) if a[field] is Vector2 else lerpf(float(a[field]),float(b[field]),t)
	for field in ["feet","hands"]:
		result[field]=[Vector2(a[field][0]).lerp(b[field][0],t),Vector2(a[field][1]).lerp(b[field][1],t)]
	result["feet_on"]=a.get("feet_on",[false,false]).duplicate() if t<0.5 else b.get("feet_on",[false,false]).duplicate()
	if a.has("hands_on") or b.has("hands_on"):
		result["hands_on"]=a.get("hands_on",[false,false]).duplicate() if t<0.5 else b.get("hands_on",[false,false]).duplicate()
	return result

static func _timeline(name: String,p: float) -> Dictionary:
	var rows: Array=Keys.TIMELINES[name]
	for i in range(rows.size()-1):
		var a: Array=rows[i]
		var b: Array=rows[i+1]
		if p<=float(b[0]):
			var u:=clampf((p-float(a[0]))/maxf(float(b[0])-float(a[0]),0.0001),0.0,1.0)
			match str(a[2]):
				"hold":u=0.0
				"snap":u=0.0 if u<0.35 else 1.0
				_:u=u*u*(3.0-2.0*u)
			return {"pose":_mix(Keys.POSES[a[1]],Keys.POSES[b[1]],u),"key_name":str(a[1]) if u<0.5 else str(b[1])}
	return {"pose":Keys.POSES[rows[-1][1]].duplicate(true),"key_name":str(rows[-1][1])}

static func _mirror_key(key: Dictionary) -> Dictionary:
	var out:=key.duplicate(true)
	out.pelvis.x*=-1
	out.lean*=-1
	for field in ["feet","hands"]:
		for i in 2:out[field][i].x*=-1
	return out

static func _gait(phase: float,t: Dictionary) -> Dictionary:
	var p:=fposmod(phase,1.0)
	var n:=speed_fraction(t)
	var stride:=stride_for(t)
	var stance:=lerpf(Keys.TUNING.slow_stance,Keys.TUNING.fast_stance,n)
	var key:Dictionary=Keys.POSES.ready.duplicate(true)
	var bob:=0.0
	var pitch_add:=0.0
	var label:="contact"
	for i in range(Keys.GROUND_CYCLE.size()-1):
		var a: Array=Keys.GROUND_CYCLE[i]
		var b: Array=Keys.GROUND_CYCLE[i+1]
		if p<=float(b[0]):
			var u:=smoothstep(float(a[0]),float(b[0]),p)
			bob=lerpf(float(a[1]),float(b[1]),u)
			pitch_add=lerpf(float(a[2]),float(b[2]),u)
			label=str(a[3]);break
	key.pelvis=Vector2(0,-lerpf(15.5,13.2,n)+0.4*sin(n*PI)+bob*lerpf(0.35,0.8,n))
	key.lean=lerpf(7.0,20.0,n)+pitch_add
	key.torso=8.9
	key.head_tilt=-key.lean*0.3
	key.rib_width=lerpf(5.8,5.4,n)
	key.feet=[];key.hands=[];key.feet_on=[]
	var chest:Vector2=key.pelvis+Vector2(sin(deg_to_rad(key.lean)),-cos(deg_to_rad(key.lean)))*key.torso
	for i in 2:
		var q:=fposmod(p+float(i)*0.5,1.0)
		var front:=stride*stance*0.5
		var foot:Vector2
		if q<stance:
			foot=Vector2(front-q*stride,0)
			key.feet_on.append(true)
		else:
			var u:=(q-stance)/(1.0-stance)
			# Recovery knee lift has a purposeful high passing pose, not a circular pedal.
			var recovery_weight:=u*u*(3-2*u)
			foot=Vector2(lerpf(-front,front,recovery_weight),-lerpf(3.0,8.0,n)*pow(sin(u*PI),1.1))
			key.feet_on.append(false)
		key.feet.append(foot)
		var pump:=-cos(q*TAU)*lerpf(3.7,7.1,n)
		key.hands.append(chest+Vector2(pump,4.6-maxf(pump,0)*0.65))
	key["key_name"]="run_"+label
	return key

static func _ledge(stage: String,p: float,t: Dictionary) -> Dictionary:
	var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO))
	var target:Vector2=t.get("palm_target",t.get("ledge_anchor",root+Vector2(facing_of(t)*9.2,-29.0)))
	var anchor:=Vector2((target.x-root.x)*facing_of(t),target.y-root.y)
	var grip_pose:=_ledge_load(anchor)
	if stage=="ledge_catch":
		grip_pose.pelvis.y+=sin(p*PI)*1.0
		grip_pose.lean+=sin(p*PI)*5.0
		grip_pose["key_name"]="catch_load" if p<0.55 else "catch_hold"
		return grip_pose
	if stage=="ledge_hang":
		grip_pose.pelvis.y+=sin(float(t.get("visual_time",0))*2.7)*0.16
		grip_pose["key_name"]="hang_hold"
		return grip_pose
	if stage=="ledge_settle":
		var settled:Dictionary=_mix(Keys.POSES.ledge_settle,Keys.POSES.ready,p)
		settled["key_name"]="ledge_settle"
		return settled
	if stage=="ledge_pull":
		var hang_target:Vector2=t.get("hang_target",target+Vector2(-facing_of(t)*9.2,29.0))
		var hang_drop:=clampf(hang_target.y-target.y,0.0,29.0)
		var start:Dictionary=_ledge_load(Vector2(anchor.x,-hang_drop))
		var key:=_mix(start,Keys.POSES.ledge_over,smoothstep(0,1,p))
		key.hands[0]=anchor+Vector2(-0.2,0)
		key["hands_on"]=[true,p<0.60 and hang_drop>=18.0]
		if key.hands_on[1]:key.hands[1]=anchor+Vector2(-0.5,0)
		# Tuck the leading sole upward while still outside the wall; only then reach over.
		var original_foot:Vector2=key.feet[0]
		var outside_x:=minf(original_foot.x,anchor.x-4.1)
		key.feet[0].x=lerpf(outside_x,original_foot.x,smoothstep(0.40,0.62,p))
		key.feet[0].y=lerpf(original_foot.y,anchor.y-2.0,smoothstep(0.15,0.45,p))
		key["feet_on"]=[false,false]
		key["leg_bend"]=[1.0,-1.0]
		key["ledge_plane"]=anchor
		key["key_name"]="pull_elbows" if p<0.40 else ("pull_chest_over" if p<0.75 else "pull_body_over")
		return key
	var sample:=_timeline("ledge_step",p)
	var step:Dictionary=sample.pose
	step["ledge_plane"]=anchor
	step["hands_on"]=[p<0.34,false]
	if p<0.34:step.hands[0]=anchor+Vector2(-0.2,0)
	var near_target:=anchor+Vector2(16,0)
	var far_target:=anchor+Vector2(10,0)
	step.feet[0]=Vector2(step.feet[0]).lerp(near_target,smoothstep(0.33,0.48,p))
	step.feet[1]=Vector2(step.feet[1]).lerp(far_target,smoothstep(0.62,0.80,p))
	step["feet_on"]=[p>=0.48,p>=0.80]
	step["key_name"]="body_over" if p<0.33 else ("lead_foot_plant" if p<0.63 else ("rear_foot_recover" if p<0.80 else "ledge_settle"))
	return step

static func _ledge_load(anchor:Vector2) -> Dictionary:
	var depth:=clampf(-anchor.y,0.0,29.0)
	var raw:Dictionary=Keys.POSES.ledge_load.duplicate(true)
	raw.pelvis=Vector2(anchor.x-5.8,anchor.y+17.5)
	raw.feet=[Vector2(raw.pelvis.x+1,minf(-1.0,raw.pelvis.y+11.5)),Vector2(raw.pelvis.x-4,minf(-3.0,raw.pelvis.y+9.0))]
	var key:=_mix(raw,Keys.POSES.ledge_over,1.0-depth/29.0)
	key["leg_bend"]=[-1.0 if depth>18 else 1.0,-1.0]
	key.hands[0]=anchor+Vector2(-0.2,0)
	key["hands_on"]=[true,depth>=18.0]
	if depth>=18.0:key.hands[1]=anchor+Vector2(-0.5,0)
	key["feet_on"]=[false,false]
	for i in 2:
		if key.feet[i].y>anchor.y:key.feet[i].x=minf(float(key.feet[i].x),anchor.x-4.1)
	key["key_name"]="ledge_grip"
	key["ledge_plane"]=anchor
	return key

static func segment_enters_ledge(a:Vector2,b:Vector2,plane:Vector2) -> bool:
	# Tests only the supplied visual edge plane; no world collision query or root movement.
	var low:=0.0
	var high:=1.0
	var start:=a-plane-Vector2(0.05,0.05)
	var delta:=b-a
	for axis in 2:
		var v:float=start[axis]
		var d:float=delta[axis]
		if absf(d)<0.000001:
			if v<=0.0:return false
		elif d>0.0:low=maxf(low,-v/d)
		else:high=minf(high,-v/d)
	return low<high and high>0.0 and low<1.0

static func solve_elbow(root: Vector2,target: Vector2,upper: float,lower: float,bend: float) -> Vector2:
	var delta:=target-root
	var distance:=maxf(delta.length(),0.0001)
	var reach:=clampf(distance,absf(upper-lower)+0.0001,upper+lower-0.0001)
	var axis:=delta/distance
	var along:=(upper*upper-lower*lower+reach*reach)/(2.0*reach)
	var across:=sqrt(maxf(0.0,upper*upper-along*along))
	return root+axis*along+Vector2(-axis.y,axis.x)*across*bend

static func _solve(key: Dictionary) -> Dictionary:
	var j:Dictionary={}
	var angle:=deg_to_rad(float(key.lean))
	var up:=Vector2(sin(angle),-cos(angle))
	var side:=Vector2(cos(angle),sin(angle))
	j.pelvis=key.pelvis
	j.chest=j.pelvis+up*float(key.torso)
	j.neck=j.chest+Vector2(up.x*0.45,-2.1)
	j.head=j.neck+Vector2(up.x*0.35,-3.2)
	j.hip_near=j.pelvis+Vector2(1.5,0.2)
	j.hip_far=j.pelvis+Vector2(-1.5,-0.2)
	j.shoulder_near=j.chest+side*2.3
	j.shoulder_far=j.chest-side*2.3
	j.rib_near=j.chest-up*2.6+side*float(key.rib_width)*0.5
	j.rib_far=j.chest-up*2.6-side*float(key.rib_width)*0.5
	j.waist_near=j.pelvis+up*2.2+side*1.8
	j.waist_far=j.pelvis+up*2.2-side*1.8
	var leg_bend:Array=key.get("leg_bend",[1.0,1.0])
	for i in 2:
		var suffix:="near" if i==0 else "far"
		var foot:Vector2=key.feet[i]
		var foot_normal:Vector2=key.get("foot_normals",[Vector2.UP,Vector2.UP])[i]
		var toe_direction:=Vector2(-foot_normal.y,foot_normal.x)*float(key.get("foot_tangent_sign",1.0))
		j["sole_"+suffix]=foot
		j["ankle_"+suffix]=foot+foot_normal*1.4
		j["heel_"+suffix]=foot-toe_direction*1.8
		j["toe_"+suffix]=foot+toe_direction*3.6
		var knee_bend:float=-float(leg_bend[i])
		j["knee_"+suffix]=solve_elbow(j["hip_"+suffix],j["ankle_"+suffix],Keys.TUNING.upper_leg,Keys.TUNING.lower_leg,knee_bend)
		if bool(key.get("floor_guard",false)) and j["knee_"+suffix].y>0:
			j["knee_"+suffix]=solve_elbow(j["hip_"+suffix],j["ankle_"+suffix],Keys.TUNING.upper_leg,Keys.TUNING.lower_leg,-knee_bend)
		if key.has("floor_plane") and (Vector2(j["knee_"+suffix])-Vector2(key.floor_plane)).dot(Vector2(key.floor_normal))<0.0:
			j["knee_"+suffix]=solve_elbow(j["hip_"+suffix],j["ankle_"+suffix],Keys.TUNING.upper_leg,Keys.TUNING.lower_leg,-knee_bend)
		j["palm_"+suffix]=key.hands[i]
		var arm_bend:float=-1.0 if i==0 else 1.0
		j["elbow_"+suffix]=solve_elbow(j["shoulder_"+suffix],j["palm_"+suffix],Keys.TUNING.upper_arm,Keys.TUNING.lower_arm,arm_bend)
		if key.has("wall_limit_x"):
			var wall_side:float=key.wall_limit_side
			var plane_x:float=key.wall_limit_x
			var skin:float=key.wall_joint_skin
			if (j["knee_"+suffix].x-plane_x)*wall_side > -skin:
				j["knee_"+suffix]=solve_elbow(j["hip_"+suffix],j["ankle_"+suffix],Keys.TUNING.upper_leg,Keys.TUNING.lower_leg,-knee_bend)
			if (j["elbow_"+suffix].x-plane_x)*wall_side > -skin:
				j["elbow_"+suffix]=solve_elbow(j["shoulder_"+suffix],j["palm_"+suffix],Keys.TUNING.upper_arm,Keys.TUNING.lower_arm,-arm_bend)
		if key.has("ledge_plane"):
			var plane:Vector2=key.ledge_plane
			var knee:Vector2=j["knee_"+suffix]
			if segment_enters_ledge(j["hip_"+suffix],knee,plane) or segment_enters_ledge(knee,j["ankle_"+suffix],plane):
				j["knee_"+suffix]=solve_elbow(j["hip_"+suffix],j["ankle_"+suffix],Keys.TUNING.upper_leg,Keys.TUNING.lower_leg,-knee_bend)
			var elbow:Vector2=j["elbow_"+suffix]
			if segment_enters_ledge(j["shoulder_"+suffix],elbow,plane) or segment_enters_ledge(elbow,j["palm_"+suffix],plane):
				j["elbow_"+suffix]=solve_elbow(j["shoulder_"+suffix],j["palm_"+suffix],Keys.TUNING.upper_arm,Keys.TUNING.lower_arm,-arm_bend)
	return {"bones":j,"head_radius":Keys.TUNING.head_radius}
