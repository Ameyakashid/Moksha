@tool
class_name MokshaComboPose
extends RefCounted
## Pure original chain poses. Physics phase, identity, body and facing are inputs.
const Keys=preload("res://combat_pc/visuals/combo_keys.gd")
const Combat=preload("res://combat_pc/visuals/combat_pose.gd")
const CombatKeys=preload("res://combat_pc/visuals/combat_keys.gd")
const MODES=Keys.MODES
static func _key(key_name:String,low:bool) -> Dictionary:
 var result:Dictionary=(Keys.POSES[key_name] if Keys.POSES.has(key_name) else CombatKeys.POSES[key_name]).duplicate(true)
 if low:result.weapon_angle=Keys.LOW_ANGLES[key_name]
 return result
static func raw(step:String,phase:String,p:float,low:bool=false) -> Dictionary:
 var rows:Array=CombatKeys.TIMELINES["attack_"+phase] if step=="slash" else Keys.TIMELINES[step+"_"+phase]
 var result:Dictionary=_key(str(rows[-1][1]),low);var label:=str(rows[-1][1])
 for i in range(rows.size()-1):
  var a:Array=rows[i];var b:Array=rows[i+1]
  if p<=float(b[0]):
   var u:=clampf((p-float(a[0]))/maxf(float(b[0])-float(a[0]),0.00001),0,1)
   u=0.0 if str(a[2])=="hold" else u*u*(3-2*u)
   result=Combat.mix_keys(_key(str(a[1]),low),_key(str(b[1]),low),u)
   label=str(a[1]) if u<0.5 else str(b[1]);break
 result["key_name"]=step+"/"+label
 return result
static func sample(mode:String,p:float,t:Dictionary) -> Dictionary:
 var step:=str(t.get("attack_pose_id",mode.split("_")[1]))
 if step not in Keys.STEP_IDS:step=mode.split("_")[1]
 var phase:=str(mode.get_slice("_",2))
 var low:=float(t.get("body_height",34.0))<=20.1 or bool(t.get("crouched",false))
 var key:=raw(step,phase,p,low)
 var label:=str(key.key_name)
 var entry:Dictionary=t.get("combo_visual_entry",{})
 var low_turn_projection:=Vector2.ZERO
 var has_low_turn_projection:=false
 if phase=="windup" and p<Keys.ENTRY_BLEND_END and str(entry.get("step","")) in Keys.STEP_IDS:
  var previous:=raw(str(entry.step),str(entry.phase),float(entry.progress),low)
  var reversed_facing:bool=int(entry.get("facing",1))!=int(t.get("facing",t.get("attack_facing",1)))
  if reversed_facing:
   previous.pelvis.x*=-1;previous.lean*=-1;previous.head_tilt*=-1
   for field in ["hands","feet"]:
    for i in 2:previous[field][i].x*=-1
   previous.weapon_angle=180.0-float(previous.weapon_angle)
  # Use the shorter blade rotation while keeping the body key anatomically solved.
  previous.weapon_angle=float(key.weapon_angle)+wrapf(float(previous.weapon_angle)-float(key.weapon_angle),-180,180)
  var blend:=smoothstep(0,Keys.ENTRY_BLEND_END,p)
  if low and reversed_facing:
   # Original out-of-plane turn projection. A full planar sword rotation
   # cannot turn in20px clearance; both endpoint blades remain full length.
   low_turn_projection=Vector2.RIGHT.rotated(deg_to_rad(float(previous.weapon_angle))).lerp(Vector2.RIGHT.rotated(deg_to_rad(float(key.weapon_angle))),blend)
   has_low_turn_projection=true
  key=Combat.mix_keys(previous,key,blend)
  label=step+"/chain_entry" if p<Keys.ENTRY_BLEND_END*0.5 else label
 key["key_name"]=label;key["weapon_visible"]=true;key["grounded"]=bool(t.get("grounded",true))
 key["body_rotation"]=0.0;key["floor_guard"]=bool(t.get("grounded",true))
 if low:
  Combat._fit_low_body(key)
  for i in 2:key.hands[i].y=maxf(-17.0,float(key.hands[i].y))
 elif not bool(t.get("grounded",true)):
  var velocity:Vector2=t.get("velocity",Vector2.ZERO)
  key.feet=[Vector2(6,-5 if velocity.y<45 else -2),Vector2(-5,-9 if velocity.y<45 else -5)]
  key.feet_on=[false,false];key.pelvis.y-=1.0;key["key_name"]=label+"_air"
 elif float(t.get("landing_visual_progress",1.0))<1.0:
  var landing:=float(t.landing_visual_progress)
  var amount:float=(1.0-smoothstep(0.22,1.0,landing))*clampf(float(t.get("preimpact_speed",300))/520,0.3,1)
  key.pelvis.y+=2.8*amount;key.lean+=7.0*amount
  for i in 2:key.hands[i].y+=2.0*amount
  key["key_name"]=label+"_landing"
 if not bool(t.get("grounded",true)):key.feet_on=[false,false]
 # Bounded anatomical palm fit; the blade stays attached to this actual palm.
 var radians:=deg_to_rad(float(key.lean))
 var chest:Vector2=key.pelvis+Vector2(sin(radians),-cos(radians))*float(key.torso)
 for i in 2:
  var shoulder:Vector2=chest+Vector2(cos(radians),sin(radians))*(2.3 if i==0 else -2.3)
  var offset:Vector2=key.hands[i]-shoulder
  if offset.length()>11.6:key.hands[i]=shoulder+offset.normalized()*11.6
  elif offset.length()<0.21:key.hands[i]=shoulder+(offset.normalized() if offset.length()>0.00001 else Vector2.RIGHT)*0.21
 if has_low_turn_projection:key["low_turn_projection"]=low_turn_projection
 return key
static func finish(pose:Dictionary,key:Dictionary,mode:String,t:Dictionary) -> void:
 var phase:=str(mode.get_slice("_",2))
 Combat.finish(pose,key,"attack_"+phase,t)
 if key.has("low_turn_projection"):
  var projected:Vector2=key.low_turn_projection
  var axis:=projected.normalized() if projected.length()>0.00001 else Vector2.UP
  var across:=Vector2(-axis.y,axis.x)
  var grip:Vector2=pose.weapon.grip;var guard:=grip+projected*1.5
  pose.weapon.pommel=grip-projected*CombatKeys.WEAPON.grip
  pose.weapon.guard_a=guard-across*CombatKeys.WEAPON.guard;pose.weapon.guard_b=guard+across*CombatKeys.WEAPON.guard
  pose.weapon.blade_a=guard+across*CombatKeys.WEAPON.width;pose.weapon.blade_b=guard-across*CombatKeys.WEAPON.width
  pose.weapon.tip=guard+projected*CombatKeys.WEAPON.length
  pose.weapon["turn_projection_fraction"]=projected.length()
  pose.weapon["unprojected_blade_length"]=CombatKeys.WEAPON.length
 pose["combo"]={"step":mode.get_slice("_",1),"step_index":int(t.get("attack_step_index",Keys.STEP_IDS.find(mode.get_slice("_",1)))),"serial":int(t.get("attack_serial",-1)),"chain_serial":int(t.get("chain_serial",-1)),"phase":phase,"entry_blend":phase=="windup" and t.has("combo_visual_entry") and float(pose.phase)<Keys.ENTRY_BLEND_END}
static func resolve_weapon_facing(pose:Dictionary,key:Dictionary,t:Dictionary) -> void:
 # Body-facing and the live strike's committed direction are separate facts.
 # Recovery has no live strike; its blade follows the permitted body turn.
 var body_facing:=float(pose.facing)
 var strike_facing:float=-1.0 if float(t.get("attack_facing",body_facing))<0 else 1.0
 var active:bool=str(pose.combo.phase)=="active"
 var weapon_facing:float=strike_facing if active else body_facing
 pose.combo["body_facing"]=int(body_facing);pose.combo["strike_facing"]=int(strike_facing)
 pose.combo["weapon_facing"]=int(weapon_facing);pose.combo["arm_reach_adjustment"]=0.0
 if not active or weapon_facing==body_facing:return
 var desired:=Vector2(Vector2(key.hands[0]).x*weapon_facing,Vector2(key.hands[0]).y)
 var shoulder:Vector2=pose.bones.shoulder_near
 var delta:=desired-shoulder
 var palm:Vector2=shoulder+delta.normalized()*clampf(delta.length(),0.21,11.6)
 pose.bones.palm_near=palm
 var reach:=clampf(shoulder.distance_to(palm),0.2001,11.7999)
 var arm_axis:Vector2=(palm-shoulder).normalized()
 var along:float=(36-33.64+reach*reach)/(2*reach)
 pose.bones.elbow_near=shoulder+arm_axis*along+Vector2(-arm_axis.y,arm_axis.x)*sqrt(maxf(0,36-along*along))*(-body_facing)
 var radians:=deg_to_rad(float(key.weapon_angle))
 var axis:=Vector2(cos(radians)*weapon_facing,sin(radians))
 var across:=Vector2(-sin(radians)*weapon_facing,cos(radians))
 var guard:=palm+axis*1.5
 pose.weapon.grip=palm;pose.weapon.pommel=palm-axis*CombatKeys.WEAPON.grip
 pose.weapon.guard_a=guard-across*CombatKeys.WEAPON.guard;pose.weapon.guard_b=guard+across*CombatKeys.WEAPON.guard
 pose.weapon.blade_a=guard+across*CombatKeys.WEAPON.width;pose.weapon.blade_b=guard-across*CombatKeys.WEAPON.width
 pose.weapon.tip=guard+axis*CombatKeys.WEAPON.length
 pose.combo.arm_reach_adjustment=palm.distance_to(desired)
static func occlude_blade(pose:Dictionary,t:Dictionary) -> void:
 # Drawing-only floor occlusion. Every raw weapon point and strike stays intact.
 var n:Vector2=t.get("floor_normal",Vector2.UP)
 var clip_floor:bool=bool(t.get("grounded",false)) and t.has("floor_contact_point") and n.is_finite() and n.y< -0.1
 n=n.normalized()
 var root:Vector2=t.get("world_position",t.get("position",Vector2.ZERO))
 var plane:Vector2=Vector2(t.get("floor_contact_point",root))-root
 var outline:Array=[pose.weapon.blade_a,pose.weapon.tip,pose.weapon.blade_b,pose.weapon.blade_a]
 var segments:Array=[];var occluded:=false
 for i in range(outline.size()-1):
  var a:Vector2=outline[i];var b:Vector2=outline[i+1]
  if clip_floor:
   var da:float=(a-plane).dot(n);var db:float=(b-plane).dot(n)
   if da<0 or db<0:occluded=true
   if da<0 and db<0:continue
   if da<0:a=a.lerp(b,da/(da-db))
   elif db<0:b=a.lerp(b,da/(da-db))
  segments.append([a,b])
 pose.weapon["visible_blade_segments"]=segments
 pose.weapon["occluded_by_floor"]=occluded
