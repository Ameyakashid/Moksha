@tool
class_name MokshaCombatPose
extends RefCounted
## Pure combat authoring helper. The motor supplies every action/phase/direction.
const Keys=preload("res://combat_pc/visuals/combat_keys.gd")
const MODES=["roll_start","roll_travel","roll_recovery","attack_windup","attack_active","attack_recovery","hurt"]
const ROLL_PIVOT=Vector2(0,-10)
const HEAD_OUTLINE=[Vector2(-2.1,-2.0),Vector2(0.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-0.25),Vector2(3.2,0.55),Vector2(1.6,1.1),Vector2(0.7,2.5),Vector2(-1.8,2.0),Vector2(-2.5,0.5)]

static func sample(mode:String,p:float,t:Dictionary) -> Dictionary:
	var key:Dictionary
	var label:String
	if mode=="roll_travel":
		key=Keys.POSES.roll_tuck.duplicate(true)
		label=["roll_fold","roll_shoulder","roll_inverted","roll_unfold"][mini(int(p*4),3)]
	else:
		var rows:Array=Keys.TIMELINES[mode]
		key=Keys.POSES[rows[-1][1]].duplicate(true);label=str(rows[-1][1])
		for i in range(rows.size()-1):
			var a:Array=rows[i];var b:Array=rows[i+1]
			if p<=float(b[0]):
				var u:=clampf((p-float(a[0]))/maxf(float(b[0])-float(a[0]),0.00001),0,1)
				match str(a[2]):
					"hold":u=0
					"snap":u=0 if u<0.45 else 1
					_:u=u*u*(3-2*u)
				key=mix_keys(Keys.POSES[a[1]],Keys.POSES[b[1]],u)
				label=str(a[1]) if u<0.5 else str(b[1]);break
	key["key_name"]=label
	key["body_rotation"]=TAU*p if mode=="roll_travel" else 0.0
	key["floor_guard"]=mode.begins_with("roll_")
	key["weapon_visible"]=mode.begins_with("attack_")
	key["grounded"]=bool(t.get("grounded",true))
	if mode.begins_with("attack_") or mode=="hurt":
		if float(t.get("body_height",34.0))<=20.1 or bool(t.get("crouched",false)):
			_fit_low_body(key)
		elif not bool(t.get("grounded",true)):
			# The upper-body action stays legible while the legs acknowledge flight.
			var v:Vector2=t.get("velocity",Vector2.ZERO)
			key.feet=[Vector2(6,-5 if v.y<45 else -2),Vector2(-5,-9 if v.y<45 else -5)]
			key.feet_on=[false,false]
			key.pelvis.y-=1.0
			key["key_name"]=label+"_air"
		elif mode.begins_with("attack_"):
			var landing:float=float(t.get("landing_visual_progress",1.0))
			if landing<1.0:
				var amount:float=(1.0-smoothstep(0.22,1.0,landing))*clampf(float(t.get("preimpact_speed",300))/520,0.3,1)
				key.pelvis.y+=2.8*amount
				key.lean+=7.0*amount
				for i in 2:key.hands[i].y+=2.0*amount
				key["key_name"]=label+"_landing"
		if mode=="hurt":
			var away:float=signf(float(t.get("hurt_direction",-float(t.get("facing",1))))*float(t.get("facing",1)))
			if away>0:
				key.pelvis.x*=-1;key.lean*=-1;key.head_tilt*=-1
				for field in ["hands","feet"]:
					for i in 2:key[field][i].x*=-1
	if not bool(t.get("grounded",true)):key.feet_on=[false,false]
	return key

static func mix_keys(a:Dictionary,b:Dictionary,u:float) -> Dictionary:
	var out:=a.duplicate(true)
	for name in ["pelvis","lean","torso","head_tilt","rib_width"]:
		out[name]=a[name].lerp(b[name],u) if a[name] is Vector2 else lerpf(float(a[name]),float(b[name]),u)
	for name in ["hands","feet"]:
		out[name]=[Vector2(a[name][0]).lerp(b[name][0],u),Vector2(a[name][1]).lerp(b[name][1],u)]
	out["feet_on"]=a.feet_on.duplicate() if u<0.5 else b.feet_on.duplicate()
	out["leg_bend"]=a.get("leg_bend",[1.0,1.0]).duplicate() if u<0.5 else b.get("leg_bend",[1.0,1.0]).duplicate()
	if a.has("weapon_angle") or b.has("weapon_angle"):
		out["weapon_angle"]=lerpf(float(a.get("weapon_angle",-40)),float(b.get("weapon_angle",-40)),u)
	return out

static func _fit_low_body(key:Dictionary) -> void:
	var old_angle:=deg_to_rad(float(key.lean))
	var old_chest:Vector2=key.pelvis+Vector2(sin(old_angle),-cos(old_angle))*float(key.torso)
	key.pelvis=Vector2(key.pelvis.x,-6.0)
	key.lean=40.0;key.torso=6.2;key.head_tilt=-17.0
	var new_chest:Vector2=key.pelvis+Vector2(sin(deg_to_rad(40.0)),-cos(deg_to_rad(40.0)))*6.2
	for i in 2:key.hands[i]=new_chest+(Vector2(key.hands[i])-old_chest)*0.8
	key["key_name"]=str(key.key_name)+"_low"

static func finish(pose:Dictionary,key:Dictionary,mode:String,t:Dictionary) -> void:
	var angle:float=float(key.get("body_rotation",0.0))
	if mode=="roll_travel":
		for name in pose.bones:pose.bones[name]=ROLL_PIVOT+(Vector2(pose.bones[name])-ROLL_PIVOT).rotated(angle)
		pose.head_tilt+=rad_to_deg(angle)
	if mode.begins_with("roll_"):
		# Keep the folded silhouette tangent to the motor's foot plane. This is a
		# local bone offset only; the visual never raises or lowers the actor root.
		var bottom:float=-INF
		for name in pose.bones:bottom=maxf(bottom,float(pose.bones[name].y))
		for offset in HEAD_OUTLINE:
			var point:Vector2=Vector2(pose.bones.head)+(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)))
			bottom=maxf(bottom,point.y)
		for name in pose.bones:pose.bones[name].y-=bottom
	pose["body_rotation"]=angle
	pose["weapon"]={"visible":false}
	if bool(key.get("weapon_visible",false)):
		var grip:Vector2=pose.bones.palm_near
		var axis:=Vector2.RIGHT.rotated(deg_to_rad(float(key.get("weapon_angle",-40))))
		var across:=Vector2(-axis.y,axis.x)
		var guard:=grip+axis*1.5
		var tip:=guard+axis*Keys.WEAPON.length
		pose.weapon={"visible":true,"grip":grip,"pommel":grip-axis*Keys.WEAPON.grip,"guard_a":guard-across*Keys.WEAPON.guard,"guard_b":guard+across*Keys.WEAPON.guard,"blade_a":guard+across*Keys.WEAPON.width,"blade_b":guard-across*Keys.WEAPON.width,"tip":tip,"contact":mode=="attack_active","confirmed":bool(t.get("strike_confirmed_visual",false)),"authorship":"MOKSHA original code-native short blade"}
