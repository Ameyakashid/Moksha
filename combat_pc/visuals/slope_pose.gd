@tool
class_name MokshaSlopePose
extends RefCounted
## Original passive terrain fit. Joint compression and IK never move the actor root.
const MODES=["idle","run","run_fast","run_slow","start","brake","turn","land","land_run","crouch"]
const PLANTED_SPECIALS=["roll_start","roll_recovery","attack_windup","attack_active","attack_recovery","hurt"]
const REACH=15.8
const MAX_SETTLE=4.0
static func applies(pose:Dictionary,t:Dictionary) -> bool:
	var normal:Vector2=t.get("floor_normal",Vector2.UP)
	var eligible:bool=str(pose.mode)=="attack_charge" or str(pose.mode).begins_with("attack_charged_thrust_") or str(pose.mode) in MODES or ((str(pose.mode) in PLANTED_SPECIALS or str(pose.mode).begins_with("shield_") or str(pose.mode).begins_with("attack_")) and (bool(pose.planted_feet[0]) or bool(pose.planted_feet[1])))
	return eligible and bool(t.get("grounded",false)) and t.has("floor_contact_point") and normal.is_finite() and absf(normal.x)>0.0001 and normal.y < -0.1
static func fit(pose:Dictionary,t:Dictionary) -> void:
	if not applies(pose,t):return
	var n:Vector2=Vector2(t.floor_normal).normalized()
	var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO))
	var plane:=Vector2(t.floor_contact_point)-root
	var bones:Dictionary=pose.bones
	# A rectangular body's uphill corner supports its root above the central
	# floor plane. Compress the authored joints, never scale/extend its legs.
	var settle:=0.0
	for side in ["near","far"]:
		var height:float=(Vector2(bones["hip_"+side])-plane).dot(n)
		settle=maxf(settle,(height-1.4-15.2)/-n.y)
	settle=clampf(settle,0,MAX_SETTLE)
	for bone in bones:
		if not String(bone).begins_with("knee_") and not String(bone).begins_with("ankle_") and not String(bone).begins_with("sole_") and not String(bone).begins_with("heel_") and not String(bone).begins_with("toe_"):
			bones[bone].y+=settle
	pose["slope_support"]=true;pose["slope_hip_settle"]=settle
	pose["slope_weapon_offset"]=Vector2(0,settle) if bool(pose.weapon.get("visible",false)) else Vector2.ZERO
	for point in pose.weapon:
		if pose.weapon[point] is Vector2:pose.weapon[point].y+=settle
	pose["floor_normal"]=n
	for i in 2:
		var side:String="near" if i==0 else "far"
		var desired:Vector2=bones["sole_"+side]
		var hip:Vector2=bones["hip_"+side]
		var on:bool=pose.planted_feet[i]
		var hip_height:float=(hip-plane).dot(n)
		if absf(hip_height-1.4)>REACH:on=false
		var lift:float=0.0 if on else maxf(1.2,-desired.y)
		var ankle_height:=clampf(1.4+lift,maxf(1.4,hip_height-REACH+0.01),hip_height+REACH-0.01)
		var sole:=reachable_sole(hip,desired,plane,n,ankle_height)
		set_leg(pose,side,sole,n)
		pose.planted_feet[i]=on
static func reachable_sole(hip:Vector2,desired:Vector2,plane:Vector2,n:Vector2,ankle_height:float=1.4) -> Vector2:
	var tangent:=Vector2(-n.y,n.x)
	var height:float=(hip-plane).dot(n)
	var depth:=height-ankle_height
	var half_width:=sqrt(maxf(0,REACH*REACH-depth*depth))
	var center:=hip-n*(depth+1.4)
	var along:=clampf((desired-center).dot(tangent),-half_width,half_width)
	return center+tangent*along
static func set_leg(pose:Dictionary,side:String,sole:Vector2,n:Vector2) -> void:
	var j:Dictionary=pose.bones
	var ankle:=sole+n*1.4
	var tangent:=Vector2(-n.y,n.x)*float(pose.facing)
	var hip:Vector2=j["hip_"+side]
	var previous:Vector2=j["knee_"+side]
	var bend:=signf((ankle-hip).cross(previous-hip))
	if is_zero_approx(bend):bend=-float(pose.facing)
	var knee:=_knee(hip,ankle,bend)
	if (knee-sole).dot(n)<0.0:knee=_knee(hip,ankle,-bend)
	j["sole_"+side]=sole;j["ankle_"+side]=ankle;j["knee_"+side]=knee
	j["heel_"+side]=sole-tangent*1.8;j["toe_"+side]=sole+tangent*3.6
static func _knee(hip:Vector2,ankle:Vector2,bend:float) -> Vector2:
	var delta:=ankle-hip
	var distance:=clampf(delta.length(),0.0001,15.9999)
	var axis:=delta.normalized()
	return hip+axis*distance*0.5+Vector2(-axis.y,axis.x)*sqrt(maxf(0,64-distance*distance*0.25))*bend
