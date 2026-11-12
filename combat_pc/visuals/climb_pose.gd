@tool
class_name MokshaClimbPose
extends RefCounted
## Pure travel-driven rung contacts. No clocks, root movement or collision queries.
const Keys=preload("res://combat_pc/visuals/climb_keys.gd")
const Body=preload("res://combat_pc/visuals/wireframe_keys.gd")

static func sample(mode:String,p:float,t:Dictionary) -> Dictionary:
	var low:bool=float(t.get("body_height",34))<=20.1 or bool(t.get("crouched",false))
	if mode=="climb_release":return _release(p,t,low)
	var key:Dictionary=Keys.BODY[mode].duplicate(true)
	var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO))
	var facing:float=-1 if float(t.get("facing",1))<0 else 1
	var axis:float=(float(t.get("climb_axis_x",root.x))-root.x)*facing
	var top:float=t.get("climb_top_y",root.y-100)
	var bottom:float=t.get("climb_bottom_y",root.y+100)
	var spacing:float=maxf(float(t.get("climb_rung_spacing",12)),0.001)
	var origin:float=bottom-float(t.get("climb_rung_origin_offset",4))
	var highest:float=origin-floorf((origin-top)/spacing)*spacing
	var cycle:float=spacing*2.0
	var relative_height:float=origin-root.y
	var vine:bool=str(t.get("climb_type","ladder"))=="vine"
	if vine:key.pelvis.x-=1.2;key.rib_width-=0.3
	if mode=="climb_top_exit":
		key.pelvis=Vector2(key.pelvis).lerp(Vector2(0,-17),p)
		key.lean=lerpf(float(key.lean),0,p);key.head_tilt=lerpf(float(key.head_tilt),4,p)
	if low:
		key.pelvis=Vector2(key.pelvis.x,-6.0);key.lean=39.0;key.torso=6.2;key.head_tilt=-13.0
	var tilt:=deg_to_rad(float(key.lean))
	var up:=Vector2(sin(tilt),-cos(tilt))
	var across:=Vector2(cos(tilt),sin(tilt))
	var chest:Vector2=key.pelvis+up*float(key.torso)
	key["hands"]=[];key["feet"]=[];key["hands_on"]=[];key["feet_on"]=[]
	var hand_width:float=Keys.TUNING.vine_hand_width if vine else Keys.TUNING.hand_width
	var foot_width:float=Keys.TUNING.vine_foot_width if vine else Keys.TUNING.foot_width
	var interior_width:float=maxf(0.0,float(t.get("climb_width",20.0))*0.3-0.25)
	hand_width=minf(hand_width,interior_width);foot_width=minf(foot_width,interior_width)
	for side_index in 2:
		var lateral:float=1.0 if side_index==0 else -1.0
		# Keep the body-sized reach window while changing the actual world rung
		# pitch. Deriving the phase offset from its base keeps every planted
		# target on a real rung, including positive sensor Y scale.
		var hand_center:float=Keys.TUNING.low_hand_center if low else Keys.TUNING.hand_center
		var hand_base:float=hand_center-spacing*0.5
		var foot_base:float=Keys.TUNING.foot_center-spacing*0.5
		var hand_offset:float=-hand_base+spacing*float(side_index)
		var foot_offset:float=-foot_base+spacing*float(side_index)
		var hand_q:=fposmod((relative_height+hand_offset)/cycle,1.0)
		var foot_q:=fposmod((relative_height+foot_offset)/cycle,1.0)
		var hand_sample:=_limb_cycle(hand_q,hand_base,cycle,Keys.TUNING.hand_swing)
		var foot_sample:=_limb_cycle(foot_q,foot_base,cycle,Keys.TUNING.foot_swing)
		var hand_world_y:float=clampf(root.y+float(hand_sample.y),highest,origin)
		var foot_world_y:float=clampf(root.y+float(foot_sample.y),highest,origin)
		var hand:=Vector2(axis+lateral*(hand_width+float(hand_sample.outward)),hand_world_y-root.y)
		var foot:=Vector2(axis+lateral*(foot_width+float(foot_sample.outward)),foot_world_y-root.y)
		var shoulder:Vector2=chest+across*2.3*lateral
		var hip:Vector2=key.pelvis+Vector2(lateral*1.5,lateral*0.2)
		var hand_on:bool=bool(hand_sample.planted) and shoulder.distance_to(hand)<11.7
		var foot_on:bool=bool(foot_sample.planted) and hip.distance_to(foot+Vector2(0,-1.4))<15.9 and foot.y<=0.01
		if low and hand.y < -19.0:hand.y=-19.0;hand_on=false
		if low and hand.y > -1.0:hand.y=-1.0;hand_on=false
		if low and foot.y < -18.0:foot.y=-18.0;foot_on=false
		if mode=="climb_align" and absf(axis)>6.0:foot_on=false
		if shoulder.distance_to(hand)>11.6:hand=shoulder+(hand-shoulder).normalized()*11.6;hand_on=false
		if foot.y>0.0:
			foot=Vector2(lateral*3.5,-1.0-float(side_index));foot_on=false
		if hip.distance_to(foot+Vector2(0,-1.4))>15.8:
			foot=hip+(foot+Vector2(0,-1.4)-hip).normalized()*15.8+Vector2(0,1.4);foot_on=false
		if mode=="climb_top_exit" and root.y-top<10.0:
			hand=Vector2(5.5,-16) if side_index==0 else Vector2(-4.5,-17)
			if low:hand=Vector2(7,-7) if side_index==0 else Vector2(-2,-10)
			hand_on=false
		key.hands.append(hand);key.feet.append(foot)
		key.hands_on.append(hand_on);key.feet_on.append(foot_on)
	# Original body-local pull-up pilot. Retain baseline feet/root and never
	# claim rail-end reach as a planted rung or platform contact.
	if mode=="climb_top_exit" and not low:
		var compact:float=1.0-smoothstep(4.0,18.0,root.y-top)
		_compact_torso(key,compact)
		var cu:=Vector2(sin(deg_to_rad(float(key.lean))),-cos(deg_to_rad(float(key.lean))))
		var ca:=Vector2(cos(deg_to_rad(float(key.lean))),sin(deg_to_rad(float(key.lean))))
		for i in 2:
			var side:float=1.0 if i==0 else -1.0
			var shoulder:Vector2=key.pelvis+cu*float(key.torso)+ca*2.3*side
			var rail_end:=Vector2(axis+side*hand_width,top-root.y)
			var hand:Vector2=Vector2(key.hands[i]).lerp(rail_end,compact)
			if shoulder.distance_to(hand)>11.6:hand=shoulder+(hand-shoulder).normalized()*11.6
			key.hands[i]=hand
			if compact>0.0:key.hands_on[i]=false
	key["key_name"]=mode.trim_prefix("climb_")+("_vine" if vine else "_ladder")+("_low" if low else "")
	if mode in ["climb_ascend","climb_descend"]:
		key.key_name+="_near_grip" if key.hands_on[0] else "_far_grip"
	key["floor_guard"]=true
	key["climb_support"]=true
	return key

static func _compact_torso(key:Dictionary,weight:float)->void:
	key.pelvis=Vector2(key.pelvis).lerp(Vector2(-1,-8),weight)
	key.lean=lerpf(float(key.lean),39.0,weight)
	key.torso=lerpf(float(key.torso),6.2,weight)
	key.head_tilt=lerpf(float(key.head_tilt),-13.0,weight)

static func _limb_cycle(q:float,base:float,cycle:float,swing:float) -> Dictionary:
	var stance:float=Keys.TUNING.grip_fraction
	if q<stance:return {"y":base+q*cycle,"outward":0.0,"planted":true}
	var u:float=(q-stance)/(1.0-stance)
	var weight:float=u*u*(3-2*u)
	return {"y":lerpf(base+stance*cycle,base,weight),"outward":sin(u*PI)*swing,"planted":false}

static func _release(p:float,t:Dictionary,low:bool) -> Dictionary:
	var key:Dictionary=Body.POSES.crouch.duplicate(true) if low else Body.POSES.ready.duplicate(true)
	var weight:=smoothstep(0,1,p)
	var near_start:=Vector2(7,-12) if low else Vector2(6,-27)
	var far_start:=Vector2(-2,-12) if low else Vector2(-5,-23)
	key.hands=[near_start.lerp(key.hands[0],weight),far_start.lerp(key.hands[1],weight)]
	if not bool(t.get("grounded",false)):
		key.feet=[Vector2(4,-2),Vector2(-4,-4)];key.feet_on=[false,false]
	if bool(t.get("climb_top_release",false)) and bool(t.get("grounded",false)) and not low:
		_compact_torso(key,1.0-weight)
		key.hands=[Vector2(4.2,0).lerp(key.hands[0],weight),Vector2(-4.2,0).lerp(key.hands[1],weight)]
	key["hands_on"]=[false,false];key["climb_support"]=false
	key["key_name"]="climb_release"+("_low" if low else "")
	return key
