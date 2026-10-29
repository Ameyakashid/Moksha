@tool
class_name MokshaLandingPose
extends RefCounted
## Pure authored landing keys and contact-plane projection. Physics is read-only.
const Keys=preload("res://combat_pc/visuals/landing_keys.gd")

static func sample(mode:String,p:float,t:Dictionary) -> Dictionary:
	var kind:String="dive" if str(t.get("hard_land_kind","ordinary"))=="dive" else "ordinary"
	var label:=kind+"_contact"
	var key:Dictionary=Keys.POSES[label].duplicate(true)
	if mode=="hard_land_recovery":
		for i in range(Keys.RECOVERY.size()-1):
			var a:Array=Keys.RECOVERY[i];var b:Array=Keys.RECOVERY[i+1]
			if p<=float(b[0]):
				var first:String=str(a[1]) if a[1]=="compact_ready" else kind+"_"+str(a[1])
				var second:String=str(b[1]) if b[1]=="compact_ready" else kind+"_"+str(b[1])
				var weight:=smoothstep(float(a[0]),float(b[0]),p) if a[2]!="hold" else 0.0
				key=_mix(Keys.POSES[first],Keys.POSES[second],weight)
				label=first if weight<0.5 else second;break
	key["key_name"]="hard_"+label
	key["floor_guard"]=true
	key["landing_support"]=true
	var facing:float=-1 if float(t.get("facing",1))<0 else 1
	var normal:Vector2=t.get("floor_normal",Vector2.UP)
	if not normal.is_finite() or normal.y>=-0.1:normal=Vector2.UP
	normal=normal.normalized();normal.x*=facing
	var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO))
	var plane:Vector2=Vector2(t.get("floor_contact_point",root))-root;plane.x*=facing
	key["floor_plane"]=plane;key["floor_normal"]=normal
	key["foot_normals"]=[normal,normal]
	var contact:bool=bool(t.get("grounded",false))
	var relative:Vector2=t.get("floor_relative_velocity",t.get("velocity",Vector2.ZERO))
	var sliding:bool=bool(t.get("hard_land_skidding",absf(relative.dot(Vector2(-normal.y,normal.x*facing)))>0.1))
	key["landing_sliding"]=contact and sliding
	key["landing_touch_feet"]=[contact,contact]
	key.feet_on=[contact and not sliding,contact and not sliding]
	for i in 2:
		# Preserve authored sole separation, fit only to the supplied physical plane.
		key.feet[i].y=(plane.dot(normal)-float(key.feet[i].x)*normal.x)/normal.y
	return key

static func _mix(a:Dictionary,b:Dictionary,weight:float) -> Dictionary:
	var result:=a.duplicate(true)
	for field in ["pelvis","lean","torso","head_tilt","rib_width"]:
		result[field]=a[field].lerp(b[field],weight) if a[field] is Vector2 else lerpf(float(a[field]),float(b[field]),weight)
	for field in ["feet","hands"]:
		result[field]=[Vector2(a[field][0]).lerp(b[field][0],weight),Vector2(a[field][1]).lerp(b[field][1],weight)]
	return result
