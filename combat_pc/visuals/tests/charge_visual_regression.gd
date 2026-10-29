extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Charge=preload("res://combat_pc/visuals/charge_pose.gd")
const HEAD=[Vector2(-2.1,-2),Vector2(.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-.25),Vector2(3.2,.55),Vector2(1.6,1.1),Vector2(.7,2.5),Vector2(-1.8,2),Vector2(-2.5,.5)]
var checks:=0;var failures:Array[String]=[];var metrics:Dictionary={};var samples:Array=[]
func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func snapshot(mode:String,p:float,facing:int=1,context:String="ground",slope:float=0) -> Dictionary:
 var loading:=mode=="attack_charge";var low:bool="low" in context;var moving:bool="moving" in context
 var air:=context in ["rise","fall","low_air"]
 var root_position:=Vector2(100,100);var normal:=Vector2(slope,-1).normalized()
 var t:Dictionary={"pose":mode,"position":root_position,"world_position":root_position,"grounded":not air,"facing":facing,"attack_facing":facing,"body_height":20.0 if low else 34.0,"crouched":low,"velocity":Vector2((75 if moving else 0)*facing,-140 if context=="rise" else (220 if context=="fall" else 0)),"weapon_phase":"charge" if loading else mode.trim_prefix("attack_charged_thrust_"),"weapon_phase_progress":p,"attack_pose_id":"slash" if loading else "charged_thrust","attack_serial":3,"charge_serial":2,"charge_role":"starter" if loading else "charged","charge_progress":p if loading else 1.0,"charge_phase":"loading","input_mode":"held_charge","move_x":facing if moving else 0,"gait_phase":fposmod(p*.57+.14,1.0),"support_id":7,"floor_normal":normal,"floor_contact_point":root_position+Vector2(-8*signf(slope),0),"support_displacement":Vector2.ZERO,"main_action":"jump" if air else "locomotion"}
 if context=="landing":t["landing_visual_progress"]=.1;t["preimpact_speed"]=520
 return t
func _run() -> void:
 _geometry();_timing();_moving();_lifecycle();await _draw()
 var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"Original optional MOKSHA loading/thrust vectors, travel-driven feet and passive lifecycle. No reference frame or gameplay-capture claim."}
 FileAccess.open("res://combat_pc/visuals/tests/charge_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 FileAccess.open("res://combat_pc/visuals/tests/charge_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"Original MOKSHA charge/thrust offline vectors","samples":samples},"\t"))
 print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func _geometry() -> void:
 var arm_error:=0.0;var leg_error:=0.0;var low_top:=0.0;var low_blade_top:=0.0;var low_blade_bottom:=-INF;var sole_error:=0.0;var min_floor:=INF;var blade_floor:=INF
 for mode in Charge.MODES:
  for context in ["ground","moving","low","moving_low","rise","fall","low_air","landing"]:
   for slope in [0.0,-1.0,1.0]:
    if context in ["rise","fall","low_air"] and slope!=0:continue
    for i in range(41):
     var p:=float(i)/40;var t:=snapshot(mode,p,1,context,slope);var original:=t.duplicate(true);var pose:=Pose.evaluate(mode,p,t)
     check(t==original and pose.mode==mode,"charge/thrust evaluation preserves authoritative state")
     check(pose.weapon.visible and not pose.has("shield"),"charge/thrust has one attached blade")
     check(Vector2(pose.weapon.grip).distance_to(pose.bones.palm_near)<.001,"charge/thrust grip is attached")
     if mode=="attack_charge":check(not pose.weapon.contact and not pose.weapon.confirmed,"charge alone cannot display a strike")
     for bone in Pose.BONE_NAMES:check(Vector2(pose.bones[bone]).is_finite(),"finite charge joint")
     for side in ["near","far"]:
      arm_error=maxf(arm_error,maxf(absf(Vector2(pose.bones["shoulder_"+side]).distance_to(pose.bones["elbow_"+side])-6),absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-5.8)))
      leg_error=maxf(leg_error,maxf(absf(Vector2(pose.bones["hip_"+side]).distance_to(pose.bones["knee_"+side])-8),absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-8)))
     if not t.grounded:check(pose.planted_feet==[false,false] and not pose.weapon.occluded_by_floor,"air pose has no stale ground contact/occlusion")
     if "low" in context:
      for bone in Pose.BONE_NAMES:low_top=minf(low_top,float(pose.bones[bone].y))
      for offset in HEAD:low_top=minf(low_top,float((Vector2(pose.bones.head)+(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)))).y))
      for point in ["tip","blade_a","blade_b","guard_a","guard_b","pommel"]:
       low_blade_top=minf(low_blade_top,float(pose.weapon[point].y));low_blade_bottom=maxf(low_blade_bottom,float(pose.weapon[point].y))
     if t.grounded:
      for side in ["near","far"]:
       for part in ["knee_","heel_","toe_"]:min_floor=minf(min_floor,(Vector2(pose.bones[part+side])+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
       if pose.planted_feet[0 if side=="near" else 1]:sole_error=maxf(sole_error,absf((Vector2(pose.bones["sole_"+side])+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal))))
      for line in pose.weapon.visible_blade_segments:
       for point in line:blade_floor=minf(blade_floor,(Vector2(point)+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
     if i in [0,10,20,30,40]:
      var left:=Pose.evaluate(mode,p,snapshot(mode,p,-1,context,-slope))
      for bone in Pose.BONE_NAMES:check(Vector2(-pose.bones[bone].x,pose.bones[bone].y).distance_to(left.bones[bone])<.001,"charge/thrust mirrors body")
      check(Vector2(-pose.weapon.tip.x,pose.weapon.tip.y).distance_to(left.weapon.tip)<.001,"charge/thrust mirrors full blade")
      if slope==0:samples.append({"label":mode+"_"+context,"pose":encode(pose),"telemetry":encode(t)})
 metrics={"arm_error_px":arm_error,"leg_error_px":leg_error,"low_body_top_px":low_top,"low_blade_top_px":low_blade_top,"low_blade_bottom_px":low_blade_bottom,"sole_plane_error_px":sole_error,"minimum_body_floor_distance_px":min_floor,"minimum_visible_blade_floor_distance_px":blade_floor}
 check(arm_error<.001 and leg_error<.001,"all charge/thrust limbs retain anatomical length")
 check(low_top>=-19.7 and low_blade_top>=-20 and low_blade_bottom<=.001,"entire low body and blade arc respect20px clearance")
 check(sole_error<.001 and min_floor>-.001 and blade_floor>-.001,"actual floor plane constrains soles/knees and visible blade")
func _timing() -> void:
 var loaded:=Pose.evaluate("attack_charge",1,snapshot("attack_charge",1))
 var windup:=Pose.evaluate("attack_charged_thrust_windup",0,snapshot("attack_charged_thrust_windup",0))
 check(loaded.bones==windup.bones and loaded.weapon.tip==windup.weapon.tip,"full loading flows into committed thrust windup")
 var contact:=Pose.evaluate("attack_charged_thrust_active",.05,snapshot("attack_charged_thrust_active",.05))
 var held:=Pose.evaluate("attack_charged_thrust_active",.5,snapshot("attack_charged_thrust_active",.5))
 check(contact.bones==held.bones and contact.weapon.tip==held.weapon.tip,"thrust has a held straight contact key")
 check(contact.weapon.tip.x-loaded.weapon.tip.x>15,"charged thrust has visible forward extension")
 var end:=Pose.evaluate("attack_charged_thrust_active",1,snapshot("attack_charged_thrust_active",1))
 var recovery:=Pose.evaluate("attack_charged_thrust_recovery",0,snapshot("attack_charged_thrust_recovery",0))
 check(end.bones==recovery.bones and end.weapon.tip==recovery.weapon.tip,"thrust follow-through enters recovery continuously")
 for mode in Charge.MODES:
  var t:=snapshot(mode,.3);t.facing=-1;t.attack_facing=1
  var pose:=Pose.evaluate(mode,.3,t)
  check(pose.facing==-1 and pose.combo.weapon_facing==(1 if mode=="attack_charged_thrust_active" else -1),"charge/thrust preserves body versus committed active facing")
func _moving() -> void:
 var distinct:Dictionary={};var low_distinct:Dictionary={}
 for i in range(21):
  for low in [false,true]:
   var t:=snapshot("attack_charge",.6,1,"moving_low" if low else "moving");t.gait_phase=float(i)/20
   var pose:=Pose.evaluate("attack_charge",.6,t)
   samples.append({"label":"attack_charge_low_gait" if low else "attack_charge_gait","pose":encode(pose),"telemetry":encode(t)})
   var key:=str(pose.bones.sole_near)+str(pose.bones.sole_far)
   if low:low_distinct[key]=true
   else:distinct[key]=true
 check(distinct.size()>12 and low_distinct.size()>12,"actual-travel loading has a visible ordinary gait and low shuffle")
 var still:=snapshot("attack_charge",.9);var a:=Pose.evaluate("attack_charge",.9,still);still.gait_phase=.8;var b:=Pose.evaluate("attack_charge",.9,still)
 check(a.bones==b.bones,"stationary charge does not cycle from time or held input")
 metrics["distinct_moving_foot_pairs"]=distinct.size();metrics["distinct_low_moving_foot_pairs"]=low_distinct.size()
func _lifecycle() -> void:
 var view=Visual.new();var t:=snapshot("attack_charge",.5)
 view.event("charge_started",{"charge_serial":2});view.event("strike_confirmed",{"serial":1,"contact_position":Vector2(120,80)})
 view.present(0,t);var before:=view.get_pose()
 check(not before.weapon.confirmed,"old starter hit cannot light the charging blade")
 t["paused"]=true
 for i in 10:view.present(.016,t)
 check(view.get_pose()==before,"local pause holds charging key and gait")
 t.position+=Vector2(3,-2);t.world_position=t.position;t.support_displacement=Vector2(3,-2);t.floor_contact_point+=Vector2(3,-2)
 view.present(0,t);check(view.get_pose().bones==before.bones,"paused carrier transport preserves the local charging pose")
 view.event("charge_cancelled",{"charge_serial":2,"reason":"released"});check(not view.get_pose().weapon.visible,"release retires loading weapon synchronously")
 view.present(0,{"pose":"idle","grounded":true,"weapon_phase":"idle","charge_progress":1,"charge_phase":"ready"});check(not view.get_pose().weapon.visible,"stale charge readiness cannot auto-create a thrust")
 view.event("charge_started",{"charge_serial":3});view.present(0,snapshot("attack_charge",1))
 view.event("charge_committed",{"charge_serial":3});view.event("attack_started",{"serial":4,"attack_pose_id":"charged_thrust"})
 t=snapshot("attack_charged_thrust_active",.2);t.attack_serial=4;view.present(0,t)
 view.event("strike_confirmed",{"serial":3,"contact_position":Vector2(900,900)});view.present(0,t);check(not view.get_pose().weapon.confirmed,"old real-strike serial cannot confirm the charged thrust")
 view.event("strike_confirmed",{"serial":4,"contact_position":Vector2(128,80)});view.present(0,t)
 check(view.get_pose().weapon.confirmed and Vector2(view.get_pose().weapon.contact_point)+Vector2(t.position)==Vector2(128,80),"only confirmed charged contact receives a world mark")
 for replacement in ["hurt","roll_start","shield_raise","fall","climb_idle","dive_startup"]:
  view.event("charge_cancelled",{});view.event("attack_cancelled",{})
  var other:Dictionary={"pose":replacement,"facing":1,"grounded":false,"weapon_phase":"idle","charge_phase":"ready","charge_progress":1,"attack_pose_id":"charged_thrust"}
  if replacement=="shield_raise":other["shield_active"]=true
  view.present(0,other);check(not view.get_pose().weapon.visible,"replacement retires loading/thrust "+replacement)
 view.reset_presentation();check(view.position==Vector2.ZERO and view.scale==Vector2.ONE and view.rotation==0,"view never moves physical actor")
 view.free()
func _draw() -> void:
 var view=Visual.new();root.add_child(view);var draws:Array=[];view.draw.connect(func():draws.append(true))
 for mode in Charge.MODES:
  view.present(.016,snapshot(mode,.3));await process_frame;await process_frame
 check(draws.size()==4,"all loading/thrust families execute native drawing API")
 view.queue_free();await process_frame
func encode(value:Variant) -> Variant:
 if value is Vector2:return [value.x,value.y]
 if value is Dictionary:
  var out:Dictionary={}
  for key in value:out[key]=encode(value[key])
  return out
 if value is Array:
  var out:Array=[]
  for item in value:out.append(encode(item))
  return out
 return value
