@tool
class_name MokshaShieldPose
extends RefCounted
## Pure original shield art. The band and contact facts come from the motor.
const Keys=preload("res://combat_pc/visuals/shield_keys.gd")
const MODES=Keys.MODES
static func sample(mode:String,p:float,t:Dictionary,ground_gait:Dictionary) -> Dictionary:
	var rows:Array=Keys.TIMELINES[mode]
	var key:Dictionary=Keys.POSES[rows[-1][1]].duplicate(true);var label:String=str(rows[-1][1])
	for i in range(rows.size()-1):
		var a:Array=rows[i];var b:Array=rows[i+1]
		if p<=float(b[0]):
			var weight:=0.0 if a[2]=="hold" else smoothstep(float(a[0]),float(b[0]),p)
			key=_mix(Keys.POSES[a[1]],Keys.POSES[b[1]],weight);label=str(a[1]) if weight<0.5 else str(b[1]);break
	var low:bool=float(t.get("body_height",34))<=20.1 or bool(t.get("crouched",false))
	var grounded:bool=bool(t.get("grounded",false));var v:Vector2=t.get("velocity",Vector2.ZERO)
	if low:
		var original_chest:Vector2=key.pelvis+Vector2(sin(deg_to_rad(key.lean)),-cos(deg_to_rad(key.lean)))*key.torso
		key.pelvis=Vector2(key.pelvis.x,-5.8);key.lean=38+key.lean*0.15;key.torso=6.3;key.head_tilt=-17
		var chest:Vector2=key.pelvis+Vector2(sin(deg_to_rad(key.lean)),-cos(deg_to_rad(key.lean)))*key.torso
		for i in 2:key.hands[i]=chest+(Vector2(key.hands[i])-original_chest)*0.68
		label+="_low"
	elif grounded and absf(v.x)>8:
		key.feet=ground_gait.feet.duplicate(true);key.feet_on=ground_gait.feet_on.duplicate()
		key.pelvis.y+=(float(ground_gait.pelvis.y)+17)*0.6;label+="_moving"
	if not grounded:
		key.feet=[Vector2(4,-1),Vector2(-4,-3)] if low else ([Vector2(6,-7),Vector2(-5,-3)] if v.y< -45 else ([Vector2(4,-5),Vector2(-4,-4)] if absf(v.y)<=45 else [Vector2(3,-1),Vector2(-4,-2)]))
		key.feet_on=[false,false];label+="_air_rise" if v.y< -45 else ("_air_apex" if absf(v.y)<=45 else "_air_fall")
	elif float(t.get("landing_visual_progress",1.0))<1.0:
		# A genuine soft landing compresses behind the still-authoritative guard.
		# Its band remains fixed to motor geometry; this is no new landing owner.
		var load_amount:float=(1-smoothstep(0.18,1,float(t.landing_visual_progress)))*clampf(float(t.get("preimpact_speed",300))/520,0.3,1)
		key.pelvis.y+=(1.0 if low else 2.0)*load_amount;label+="_landing"
	key["key_name"]="shield_"+label;key["floor_guard"]=grounded
	return key
static func _mix(a:Dictionary,b:Dictionary,w:float) -> Dictionary:
	var out:=a.duplicate(true)
	for field in ["pelvis","lean","torso","head_tilt","rib_width","grip_height"]:
		out[field]=a[field].lerp(b[field],w) if a[field] is Vector2 else lerpf(float(a[field]),float(b[field]),w)
	for field in ["hands","feet"]:out[field]=[Vector2(a[field][0]).lerp(b[field][0],w),Vector2(a[field][1]).lerp(b[field][1],w)]
	return out
static func finish(pose:Dictionary,key:Dictionary,t:Dictionary) -> void:
	var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO));var f:float=pose.facing
	var height:float=float(t.get("body_height",20.0 if bool(t.get("crouched",false)) else 34.0))
	var center:Vector2=Vector2(t.get("shield_center",root+Vector2(f*11,-height*0.55)))-root
	var size:Vector2=t.get("shield_size",Vector2(10,maxf(8,height-4)))
	var normal:Vector2=t.get("shield_normal",Vector2(f,0))
	if not normal.is_finite() or normal.length_squared()<0.5:normal=Vector2(f,0)
	normal=normal.normalized()
	var up:=Vector2(normal.y,-normal.x)*f
	var grip:=center-normal*size.x*0.25-up*size.y*float(key.grip_height)
	var attached:=true
	var shoulder:Vector2=pose.bones.shoulder_near
	var reachable:=_reachable_palm(shoulder,grip,f)
	if reachable.distance_to(grip)>0.0001:attached=false
	grip=reachable
	pose.bones.palm_near=grip;pose.bones.elbow_near=_elbow(shoulder,grip,-f)
	var far_shoulder:Vector2=pose.bones.shoulder_far;var far_palm:Vector2=pose.bones.palm_far
	far_palm=_reachable_palm(far_shoulder,far_palm,-f)
	pose.bones.palm_far=far_palm;pose.bones.elbow_far=_elbow(far_shoulder,far_palm,f)
	var outline:Array=[]
	for point in [Vector2(-0.5,-0.32),Vector2(-0.2,-0.5),Vector2(0.25,-0.5),Vector2(0.5,-0.3),Vector2(0.5,0.3),Vector2(0.25,0.5),Vector2(-0.2,0.5),Vector2(-0.5,0.32),Vector2(-0.5,-0.32)]:
		outline.append(center+normal*point.x*size.x-up*point.y*size.y)
	var segments:Array=[];var occluded:=false
	var floor_normal:Vector2=t.get("floor_normal",Vector2.UP)
	var clip_floor:bool=bool(t.get("grounded",false)) and t.has("floor_contact_point") and floor_normal.is_finite() and floor_normal.y< -0.1
	floor_normal=floor_normal.normalized()
	var plane:Vector2=Vector2(t.get("floor_contact_point",root))-root
	for i in range(outline.size()-1):
		var a:Vector2=outline[i];var b:Vector2=outline[i+1]
		if clip_floor:
			var da:float=(a-plane).dot(floor_normal);var db:float=(b-plane).dot(floor_normal)
			if da<0 or db<0:occluded=true
			if da<0 and db<0:continue
			if da<0:a=a.lerp(b,da/(da-db))
			elif db<0:b=a.lerp(b,da/(da-db))
		segments.append([a,b])
	# Rendering occlusion only: retain the complete authoritative band/outline.
	# No closing edge, adjacent terrain, contact rule or collider is invented.
	pose["shield"]={"visible":true,"center":center,"size":size,"normal":normal,"outline":outline,"raw_outline":outline.duplicate(true),"visible_segments":segments,"occluded_by_floor":occluded,"grip":grip,"attached":attached,"parry_open":bool(t.get("shield_parry_open",false)),"phase":str(t.get("shield_phase",str(pose.mode).trim_prefix("shield_"))),"feedback":[]}
	for feedback in t.get("shield_visual_feedback",[]):
		var marker:Dictionary=feedback.duplicate(true);marker["point"]=Vector2(marker.point)-root
		pose.shield.feedback.append(marker)
static func _reachable_palm(shoulder:Vector2,desired:Vector2,facing:float) -> Vector2:
	var delta:=desired-shoulder;var distance:=delta.length()
	var axis:=delta/distance if distance>0.0001 else Vector2(facing,0)
	return shoulder+axis*clampf(distance,0.21,11.6)
static func _elbow(shoulder:Vector2,palm:Vector2,bend:float) -> Vector2:
	var delta:=palm-shoulder;var distance:=clampf(delta.length(),0.2001,11.7999);var axis:=delta.normalized()
	var along:float=(36-33.64+distance*distance)/(2*distance)
	return shoulder+axis*along+Vector2(-axis.y,axis.x)*sqrt(maxf(0,36-along*along))*bend
