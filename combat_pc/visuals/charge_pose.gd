@tool
class_name MokshaChargePose
extends RefCounted
## Passive loading and thrust poses. Hold admission, release, charge clock,
## movement and the eventual contact are exclusively owned by the motor.
const Keys=preload("res://combat_pc/visuals/charge_keys.gd")
const Combat=preload("res://combat_pc/visuals/combat_pose.gd")
const Combo=preload("res://combat_pc/visuals/combo_pose.gd")
const MODES=Keys.MODES
static func phase_of(mode:String) -> String:
 return "charge" if mode=="attack_charge" else mode.trim_prefix("attack_charged_thrust_")
static func raw(phase:String,p:float) -> Dictionary:
 var rows:Array=Keys.TIMELINES[phase]
 var key:Dictionary=Keys.POSES[str(rows[-1][1])].duplicate(true);var label:=str(rows[-1][1])
 for i in range(rows.size()-1):
  var a:Array=rows[i];var b:Array=rows[i+1]
  if p<=float(b[0]):
   var u:=clampf((p-float(a[0]))/maxf(float(b[0])-float(a[0]),0.00001),0,1)
   u=0.0 if str(a[2])=="hold" else u*u*(3-2*u)
   key=Combat.mix_keys(Keys.POSES[a[1]],Keys.POSES[b[1]],u)
   label=str(a[1]) if u<.5 else str(b[1]);break
 key["key_name"]="charge/"+label if phase=="charge" else "thrust/"+label
 return key
static func sample(mode:String,p:float,t:Dictionary,gait:Dictionary) -> Dictionary:
 var phase:=phase_of(mode);var key:=raw(phase,p);var label:=str(key.key_name)
 var low:bool=float(t.get("body_height",34.0))<=20.1 or bool(t.get("crouched",false))
 var grounded:=bool(t.get("grounded",true))
 var entry:Dictionary=t.get("charge_visual_entry",{})
 if phase=="charge" and p<Keys.ENTRY_BLEND_END and str(entry.get("step","")) in Combo.Keys.STEP_IDS:
  var previous:=Combo.raw(str(entry.step),str(entry.phase),float(entry.progress),low)
  if int(entry.get("facing",1))!=int(t.get("facing",1)):
   previous.pelvis.x*=-1;previous.lean*=-1;previous.head_tilt*=-1
   for field in ["hands","feet"]:
    for i in 2:previous[field][i].x*=-1
   # A current body turn is authoritative; keep the loading blade in its
   # forward clearance-safe orientation instead of winding around an old side.
   previous.weapon_angle=key.weapon_angle
  key=Combat.mix_keys(previous,key,smoothstep(0,Keys.ENTRY_BLEND_END,p))
  label="charge/entry" if p<Keys.ENTRY_BLEND_END*.5 else label
 key["key_name"]=label;key["weapon_visible"]=true;key["grounded"]=grounded
 key["body_rotation"]=0.0;key["floor_guard"]=grounded
 var velocity:Vector2=t.get("floor_relative_velocity",t.get("velocity",Vector2.ZERO)) if grounded else t.get("velocity",Vector2.ZERO)
 var walking:bool=grounded and absf(velocity.x)>.01 and phase in ["charge","recovery"]
 if walking:
  var weight:=1.0 if phase=="charge" else smoothstep(.10,.50,p)
  for i in 2:
   var foot:Vector2=gait.feet[i]
   foot.x*=.72
   key.feet[i]=Vector2(key.feet[i]).lerp(foot,weight)
   if weight>=.5:key.feet_on[i]=gait.feet_on[i]
  key.pelvis.y+=sin(float(t.get("gait_phase",0))*TAU*2)*.25*weight
  key["key_name"]=label+"_moving"
 if grounded and phase=="active":
  # Rear foot reaches the real plane before the lead foot unloads. Interpolated
  # feet above that plane must never be labeled planted.
  key.feet[0].y=-2.0*smoothstep(.80,1.0,p)
  key.feet[1].y=-2.5*(1.0-smoothstep(.60,.78,p))
  key.feet_on=[p<=.80,p>=.78]
 if grounded:
  for i in 2:
   if absf(float(key.feet[i].y))>.000001:key.feet_on[i]=false
 if low:
  Combat._fit_low_body(key)
  for i in 2:key.hands[i].y=maxf(-17.0,float(key.hands[i].y))
 elif not grounded:
  var air_velocity:Vector2=t.get("velocity",Vector2.ZERO)
  key.feet=[Vector2(6,-5 if air_velocity.y<45 else -2),Vector2(-5,-9 if air_velocity.y<45 else -5)]
  key.pelvis.y-=1;key["key_name"]=label+"_air"
 elif float(t.get("landing_visual_progress",1.0))<1:
  var amount:float=(1-smoothstep(.22,1,float(t.landing_visual_progress)))*clampf(float(t.get("preimpact_speed",300))/520,.3,1)
  key.pelvis.y+=2.4*amount;key.lean+=5*amount
  for i in 2:key.hands[i].y+=1.7*amount
  key["key_name"]=label+"_landing"
 if not grounded:key.feet_on=[false,false]
 var angle:=deg_to_rad(float(key.lean))
 var chest:Vector2=key.pelvis+Vector2(sin(angle),-cos(angle))*float(key.torso)
 for i in 2:
  var shoulder:Vector2=chest+Vector2(cos(angle),sin(angle))*(2.3 if i==0 else -2.3)
  var delta:Vector2=key.hands[i]-shoulder
  key.hands[i]=shoulder+(delta.normalized() if delta.length()>.00001 else Vector2.RIGHT)*clampf(delta.length(),.21,11.6)
 return key
static func finish(pose:Dictionary,key:Dictionary,mode:String,t:Dictionary) -> void:
 var phase:=phase_of(mode)
 Combat.finish(pose,key,"attack_"+("windup" if phase=="charge" else phase),t)
 if phase=="charge":pose.weapon.confirmed=false;pose.weapon.contact=false
 pose["combo"]={"step":"charge" if phase=="charge" else Keys.STEP_ID,"step_index":int(t.get("attack_step_index",-1)),"serial":int(t.get("attack_serial",-1)),"chain_serial":int(t.get("chain_serial",-1)),"phase":phase,"entry_blend":phase=="charge" and t.has("charge_visual_entry") and float(pose.phase)<Keys.ENTRY_BLEND_END}
 pose["charge"]={"loading":phase=="charge","progress":clampf(float(t.get("charge_progress",0)),0,1),"serial":int(t.get("charge_serial",-1)),"role":str(t.get("charge_role","")),"authored":true}
