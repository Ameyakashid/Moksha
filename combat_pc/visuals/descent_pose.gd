@tool
class_name MokshaDescentPose
extends RefCounted
## Pure original drop and dive geometry. No timers, collision queries or effects.
const Keys=preload("res://combat_pc/visuals/descent_keys.gd")

static func sample(mode:String,p:float,t:Dictionary) -> Dictionary:
	var low:bool=float(t.get("body_height",34.0))<=20.1 or bool(t.get("crouched",false))
	var poses:Dictionary=Keys.LOW_POSES if low else Keys.POSES
	var rows:Array=Keys.TIMELINES[mode]
	var key:Dictionary=poses[rows[-1][1]].duplicate(true)
	var label:String=str(rows[-1][1])
	for i in range(rows.size()-1):
		var a:Array=rows[i];var b:Array=rows[i+1]
		if p<=float(b[0]):
			var weight:=clampf((p-float(a[0]))/maxf(float(b[0])-float(a[0]),0.00001),0,1)
			match str(a[2]):
				"hold":weight=0
				"snap":weight=0 if weight<0.45 else 1
				_:weight=weight*weight*(3-2*weight)
			key=_mix(poses[a[1]],poses[b[1]],weight)
			label=str(a[1]) if weight<0.5 else str(b[1]);break
	key["key_name"]=label+("_low" if low else "")
	key["floor_guard"]=true
	# Impact is never synthesized from elapsed descent time or fall velocity.
	# Foot plants require both the motor impact/recovery phase and real grounding.
	if not bool(t.get("grounded",false)):key.feet_on=[false,false]
	return key

static func _mix(a:Dictionary,b:Dictionary,weight:float) -> Dictionary:
	var out:=a.duplicate(true)
	for field in ["pelvis","lean","torso","head_tilt","rib_width"]:
		out[field]=a[field].lerp(b[field],weight) if a[field] is Vector2 else lerpf(float(a[field]),float(b[field]),weight)
	for field in ["hands","feet"]:
		out[field]=[Vector2(a[field][0]).lerp(b[field][0],weight),Vector2(a[field][1]).lerp(b[field][1],weight)]
	out.feet_on=a.feet_on.duplicate() if weight<0.5 else b.feet_on.duplicate()
	return out
