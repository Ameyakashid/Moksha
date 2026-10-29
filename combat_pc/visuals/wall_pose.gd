@tool
class_name MokshaWallPose
extends RefCounted
## Pure, passive wall-contact art. Every plane and phase comes from the motor.
const Keys=preload("res://combat_pc/visuals/wall_keys.gd")

static func sample(mode:String,p:float,t:Dictionary) -> Dictionary:
	var low:bool=float(t.get("body_height",34))<=20.1 or bool(t.get("crouched",false))
	if mode=="wall_kick":return _kick(p,low,t)
	var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO))
	var facing:float=-1.0 if float(t.get("facing",1))<0 else 1.0
	var wall_side:float=-1.0 if float(t.get("wall_side",1))<0 else 1.0
	var local_side:float=wall_side*facing
	var plane:float=(float(t.get("wall_plane_x",root.x+wall_side*8.05))-root.x)*wall_side
	var top:float=float(t.get("wall_top_y",root.y-1000))-root.y
	var bottom:float=float(t.get("wall_bottom_y",root.y+1000))-root.y
	var key:Dictionary=Keys.RUN.duplicate(true) if mode=="wall_run" else Keys.SLIDE.duplicate(true)
	var travel:float=float(t.get("wall_relative_travel",0.0))
	var cycle:float=fposmod(-travel/float(Keys.TUNING.stride),1.0)
	if mode=="wall_run":
		key.pelvis.y+=sin(cycle*TAU*2)*0.35
	else:
		key.pelvis.y+=p*1.4;key.lean-=p*5;key.head_tilt+=p*4
	if low:
		key.pelvis=Vector2(-1.2,-6.0);key.lean=35.0;key.torso=6.2;key.head_tilt=-14.0
	key["hands"]=[];key["feet"]=[];key["feet_on"]=[];key["hands_on"]=[false,false]
	key["foot_normals"]=[];key["wall_touch_hands"]=[];key["wall_touch_feet"]=[]
	var active:bool=bool(t.get("wall_active",true))
	var guide_index:int=0 if cycle<0.5 else 1
	for i in 2:
		var q:=fposmod(cycle+float(i)*0.5,1.0)
		var foot:Vector2
		var normal:=Vector2.LEFT
		var foot_on:=false
		var foot_touch:=false
		if mode=="wall_run":
			if q<float(Keys.TUNING.stance):
				foot=Vector2(plane-Keys.TUNING.foot_skin,Keys.TUNING.foot_base+q*Keys.TUNING.stride)
				foot_on=true;foot_touch=true
			else:
				var u:float=(q-float(Keys.TUNING.stance))/(1-float(Keys.TUNING.stance))
				var weight:=u*u*(3-2*u)
				var lift:=sin(u*PI)
				foot=Vector2(plane-Keys.TUNING.foot_skin-float(Keys.TUNING.foot_recovery)*lift,lerpf(float(Keys.TUNING.foot_base)+float(Keys.TUNING.stance)*float(Keys.TUNING.stride),float(Keys.TUNING.foot_base),weight)-float(Keys.TUNING.knee_lift)*lift)
				normal=Vector2.LEFT.rotated(lift*0.45)
		else:
			foot=Vector2(plane-Keys.TUNING.foot_skin,-8.0 if not low else -5.0) if i==0 else Vector2(-3.5,-2.0)
			foot_touch=i==0 and p<0.8
			if i==0 and p>0.65:
				foot.x-=smoothstep(0.65,1,p)*3.5
				foot_touch=false
			if i==1:normal=Vector2.UP
		if low:foot.y=maxf(foot.y,-15.3)
		if foot.y<top+4.0 or foot.y>bottom-2.0:foot_touch=false;foot_on=false;foot.x=minf(foot.x,plane-4.0)
		var hand:Vector2
		var hand_touch:bool
		if mode=="wall_run":
			hand_touch=i==guide_index
			hand=Vector2(plane-Keys.TUNING.palm_skin,-25.0 if not low else -13.0) if hand_touch else Vector2(-3.5,-18.0 if not low else -8.0)
		else:
			hand_touch=i==0 or p<0.7
			hand=Vector2(plane-Keys.TUNING.palm_skin,(-25.0 if i==0 else -18.0)+p*1.0) if not low else Vector2(plane-Keys.TUNING.palm_skin,-13.0 if i==0 else -7.0)
			if not hand_touch:hand=Vector2(-3.5,-18.0 if not low else -8.0)
		if hand.y<top or hand.y>bottom:hand_touch=false;hand.x=minf(hand.x,plane-4.0)
		key.hands.append(hand);key.feet.append(foot);key.foot_normals.append(normal)
		key.feet_on.append(foot_on and active);key.wall_touch_feet.append(foot_touch and active);key.wall_touch_hands.append(hand_touch and active)
	key["wall_limit_x"]=plane
	key["wall_limit_side"]=1.0
	key["wall_joint_skin"]=Keys.TUNING.joint_skin
	key["wall_support"]=active
	key["floor_guard"]=true
	key["key_name"]=("wall_drive_near" if cycle<0.5 else "wall_drive_far") if mode=="wall_run" else ("wall_slide_brace" if p<0.65 else "wall_slide_release")
	if low:key.key_name+="_low"
	if local_side<0:
		key.pelvis.x*=-1;key.lean*=-1;key.head_tilt*=-1
		for field in ["hands","feet","foot_normals"]:
			for i in 2:key[field][i].x*=-1
		key.wall_limit_x*=-1;key.wall_limit_side=-1.0
	key["foot_tangent_sign"]=local_side
	_fit_reach(key)
	return key

static func _fit_reach(key:Dictionary) -> void:
	var angle:=deg_to_rad(float(key.lean))
	var up:=Vector2(sin(angle),-cos(angle))
	var lateral:=Vector2(cos(angle),sin(angle))
	var chest:Vector2=key.pelvis+up*float(key.torso)
	for i in 2:
		var sign_side:float=1.0 if i==0 else -1.0
		var shoulder:Vector2=chest+lateral*2.3*sign_side
		var hip:Vector2=key.pelvis+Vector2(1.5*sign_side,0.2*sign_side)
		var hand:Vector2=key.hands[i]
		if shoulder.distance_to(hand)>11.6:
			key.hands[i]=shoulder+(hand-shoulder).normalized()*11.6
			key.wall_touch_hands[i]=false
		if not bool(key.wall_touch_hands[i]) and key.has("wall_limit_x"):
			# Free fingers point beyond the palm. Keep that original hand outline
			# clear too when an intended wall touch becomes unreachable.
			var wall_side:float=key.wall_limit_side
			var finger_excess:float=(key.hands[i].x-float(key.wall_limit_x))*wall_side+2.6
			if finger_excess>0:key.hands[i].x-=finger_excess*wall_side
		var ankle:Vector2=key.feet[i]+Vector2(key.foot_normals[i])*1.4
		if hip.distance_to(ankle)>15.8:
			key.feet[i]=hip+(ankle-hip).normalized()*15.8-Vector2(key.foot_normals[i])*1.4
			key.feet_on[i]=false;key.wall_touch_feet[i]=false

static func _kick(p:float,low:bool,t:Dictionary) -> Dictionary:
	var key:Dictionary=Keys.KICK.open.duplicate(true)
	var label:="wall_kick_open"
	for i in range(Keys.KICK_KEYS.size()-1):
		var a:Array=Keys.KICK_KEYS[i];var b:Array=Keys.KICK_KEYS[i+1]
		if p<=float(b[0]):
			var weight:=clampf((p-float(a[0]))/maxf(float(b[0])-float(a[0]),0.0001),0,1)
			match str(a[2]):
				"hold":weight=0
				"snap":weight=0 if weight<0.4 else 1
				_:weight=weight*weight*(3-2*weight)
			var first:Dictionary=Keys.KICK[a[1]];var second:Dictionary=Keys.KICK[b[1]]
			key=first.duplicate(true)
			for field in ["pelvis","lean","torso","head_tilt","rib_width"]:
				key[field]=first[field].lerp(second[field],weight) if first[field] is Vector2 else lerpf(float(first[field]),float(second[field]),weight)
			for field in ["feet","hands"]:key[field]=[Vector2(first[field][0]).lerp(second[field][0],weight),Vector2(first[field][1]).lerp(second[field][1],weight)]
			label="wall_kick_"+str(a[1] if weight<0.5 else b[1]);break
	if low:
		key.pelvis=Vector2(0,-6);key.lean=36.0;key.torso=6.2;key.head_tilt=-15.0
		key.feet=[Vector2(4,-3),Vector2(-4,-4)]
		key.hands=[Vector2(7,-8),Vector2(-3,-11)]
		label+="_low"
	key["key_name"]=label;key["hands_on"]=[false,false]
	key["wall_support"]=false;key["wall_touch_hands"]=[false,false];key["wall_touch_feet"]=[false,false]
	key["floor_guard"]=true
	key["foot_normals"]=[Vector2.UP,Vector2.RIGHT.slerp(Vector2.UP,smoothstep(0.52,1.0,p))]
	var facing:float=-1.0 if float(t.get("facing",1))<0 else 1.0
	var outward:float=-1.0 if float(t.get("wall_kick_direction",facing))<0 else 1.0
	key["foot_tangent_sign"]=outward*facing
	if outward*facing<0:
		key.pelvis.x*=-1;key.lean*=-1;key.head_tilt*=-1
		for field in ["hands","feet","foot_normals"]:
			for i in 2:key[field][i].x*=-1
	if t.has("wall_plane_x"):
		var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO))
		var plane:float=(float(t.wall_plane_x)-root.x)*facing
		var side:float=float(t.get("wall_side",-outward))*facing
		key["wall_limit_x"]=plane;key["wall_limit_side"]=side;key["wall_joint_skin"]=Keys.TUNING.joint_skin
		for i in 2:
			var normal:Vector2=key.foot_normals[i]
			var tangent:=Vector2(-normal.y,normal.x)*float(key.foot_tangent_sign)
			var excess:=0.0
			for offset in [normal*1.4,-tangent*1.8,tangent*3.6]:
				excess=maxf(excess,(Vector2(key.feet[i])+offset-Vector2(plane,0)).x*side+float(Keys.TUNING.foot_skin))
			key.feet[i].x-=excess*side
			var hand_excess:float=(key.hands[i].x-plane)*side+2.6
			if hand_excess>0:key.hands[i].x-=hand_excess*side
	_fit_reach(key)
	return key
