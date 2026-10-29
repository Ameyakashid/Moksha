extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Combo=preload("res://combat_pc/visuals/combo_pose.gd")
const Keys=preload("res://combat_pc/visuals/combo_keys.gd")
const HEAD=[Vector2(-2.1,-2),Vector2(.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-.25),Vector2(3.2,.55),Vector2(1.6,1.1),Vector2(.7,2.5),Vector2(-1.8,2),Vector2(-2.5,.5)]
var transitions:Array=[]
var checks:=0;var failures:Array[String]=[];var metrics:Dictionary={};var samples:Array=[]
func _init() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func snapshot(step:String,phase:String,p:float,facing:int=1,context:String="ground",slope:float=0.0) -> Dictionary:
 var low:=context in ["low","low_air"]
 var air:=context in ["rise","apex","fall","low_air"]
 var root_position:=Vector2(100,100)
 var n:=Vector2(slope,-1).normalized()
 var t:Dictionary={"position":root_position,"world_position":root_position,"facing":facing,"attack_facing":facing,"velocity":Vector2(70*facing,-140 if context=="rise" else (260 if context=="fall" else 0)),"grounded":not air,"body_height":20.0 if low else 34.0,"crouched":low,"pose":"attack_"+step+"_"+phase,"weapon_phase":phase,"weapon_phase_progress":p,"main_action":"jump" if air else "","attack_pose_id":step,"attack_step_index":Keys.STEP_IDS.find(step),"attack_serial":4,"chain_serial":2,"move_x":0,"support_id":8,"floor_normal":n,"floor_contact_point":root_position+Vector2(-8*signf(slope),0),"support_displacement":Vector2.ZERO}
 if context=="landing":t["landing_visual_progress"]=.1;t["preimpact_speed"]=520
 return t
func _run() -> void:
 _geometry();_timing();_split_facing();_lifecycle();_transition_samples();await _draw()
 var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"scope":"MOKSHA original three-step pose vectors and passive lifecycle; exact motor phase/contact authority, no gameplay capture or reference-track parity"}
 FileAccess.open("res://combat_pc/visuals/tests/combo_visual_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 FileAccess.open("res://combat_pc/visuals/tests/combo_pose_samples.json",FileAccess.WRITE).store_string(JSON.stringify({"description":"MOKSHA original combo offline pose vectors; not native gameplay capture","samples":samples,"transitions":transitions},"\t"))
 print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func _geometry() -> void:
 var arm_error:=0.0;var leg_error:=0.0;var grip_error:=0.0;var low_top:=0.0;var low_blade_top:=0.0;var low_blade_bottom:=-INF;var floor_distance:=INF;var sole_error:=0.0;var tip_floor:=INF;var max_settle:=0.0;var visible_blade_floor:=INF;var occluded_samples:=0
 var band_outside:Dictionary={};var contact_tips:Dictionary={}
 for step in Keys.STEP_IDS:
  for phase in Keys.PHASES:
   var mode:String="attack_"+step+"_"+phase
   for context in ["ground","rise","apex","fall","landing","low","low_air"]:
    for slope in [0.0,-0.5,0.5,-1.0,1.0]:
     if context in ["rise","apex","fall","low_air"] and slope!=0:continue
     for i in range(41):
      var p:=float(i)/40;var t:=snapshot(step,phase,p,1,context,slope);var before:=t.duplicate(true)
      var pose:=Pose.evaluate(mode,p,t)
      check(t==before,"pure combo preserves telemetry")
      check(pose.mode==mode and pose.combo.step==step and pose.facing==1,"authoritative combo identity/facing")
      check(pose.weapon.visible and not pose.has("shield"),"combo owns only its attached blade")
      grip_error=maxf(grip_error,Vector2(pose.weapon.grip).distance_to(pose.bones.palm_near))
      for bone in Pose.BONE_NAMES:check(Vector2(pose.bones[bone]).is_finite(),"finite "+mode+"/"+bone)
      for side in ["near","far"]:
       arm_error=maxf(arm_error,maxf(absf(Vector2(pose.bones["elbow_"+side]).distance_to(pose.bones["palm_"+side])-5.8),absf(Vector2(pose.bones["shoulder_"+side]).distance_to(pose.bones["elbow_"+side])-6)))
       leg_error=maxf(leg_error,maxf(absf(Vector2(pose.bones["knee_"+side]).distance_to(pose.bones["ankle_"+side])-8),absf(Vector2(pose.bones["hip_"+side]).distance_to(pose.bones["knee_"+side])-8)))
      if not t.grounded:check(pose.planted_feet==[false,false],"air combo never invents floor plants")
      if context in ["low","low_air"]:
       for point in ["tip","blade_a","blade_b","pommel","guard_a","guard_b"]:
        low_blade_top=minf(low_blade_top,float(pose.weapon[point].y));low_blade_bottom=maxf(low_blade_bottom,float(pose.weapon[point].y))
       for bone in Pose.BONE_NAMES:low_top=minf(low_top,float(pose.bones[bone].y))
       for offset in HEAD:low_top=minf(low_top,float((Vector2(pose.bones.head)+(offset*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)))).y))
      if t.grounded:
       for side in ["near","far"]:
        for part in ["knee_","heel_","toe_"]:
         floor_distance=minf(floor_distance,(Vector2(pose.bones[part+side])+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
        if pose.planted_feet[0 if side=="near" else 1]:sole_error=maxf(sole_error,absf((Vector2(pose.bones["sole_"+side])+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal))))
       tip_floor=minf(tip_floor,(Vector2(pose.weapon.tip)+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
      if t.grounded:
       for segment in pose.weapon.visible_blade_segments:
        for point in segment:visible_blade_floor=minf(visible_blade_floor,(Vector2(point)+Vector2(t.position)-Vector2(t.floor_contact_point)).dot(Vector2(t.floor_normal)))
       if pose.weapon.occluded_by_floor:occluded_samples+=1
      else:check(not pose.weapon.occluded_by_floor and pose.weapon.visible_blade_segments.size()==3,"air blade ignores stale floor")
      max_settle=maxf(max_settle,float(pose.get("slope_hip_settle",0)))
      if phase=="active" and i==10:
       var dims:Vector2={"slash":Vector2(34,24),"backhand":Vector2(36,26),"finisher":Vector2(42,28)}[step]
       var center:Vector2={"slash":Vector2(25,-20),"backhand":Vector2(26,-21),"finisher":Vector2(29,-20)}[step]
       if context=="low":center.y=maxf(center.y,-20+dims.y*.5)
       var box:=Rect2(center-dims*.5,dims);var tip:Vector2=pose.weapon.tip
       var excess:=maxf(0,maxf(maxf(box.position.x-tip.x,tip.x-box.end.x),maxf(box.position.y-tip.y,tip.y-box.end.y)))
       band_outside[step]=maxf(float(band_outside.get(step,0)),excess)
       if context=="ground" and slope==0:contact_tips[step]=tip
      if i in [0,10,20,30,40] and ((context in ["ground","low","rise","fall"] and slope==0) or (context=="ground" and absf(slope)==1)):
       samples.append({"label":step+"_"+phase+"_"+context+("_slope_up" if slope<0 else ("_slope" if slope>0 else "")),"pose":encode(pose),"telemetry":encode(t)})
      if i in [0,10,40]:
       var mirrored:=snapshot(step,phase,p,-1,context,-slope)
       var left:=Pose.evaluate(mode,p,mirrored)
       for bone in Pose.BONE_NAMES:check(Vector2(-pose.bones[bone].x,pose.bones[bone].y).distance_to(left.bones[bone])<.001,"mirrored combo bone "+bone)
       for point in ["grip","tip","guard_a","guard_b"]:check(Vector2(-pose.weapon[point].x,pose.weapon[point].y).distance_to(left.weapon[point])<.001,"mirrored combo blade "+point)
 metrics={"arm_error_px":arm_error,"leg_error_px":leg_error,"grip_error_px":grip_error,"low_body_top_px":low_top,"low_blade_top_px":low_blade_top,"low_blade_bottom_px":low_blade_bottom,"minimum_ground_body_distance_px":floor_distance,"planted_sole_error_px":sole_error,"minimum_blade_tip_floor_distance_px":tip_floor,"maximum_slope_joint_settle_px":max_settle,"minimum_visible_blade_floor_px":visible_blade_floor,"occluded_ground_samples":occluded_samples,"maximum_active_tip_outside_strike_px":band_outside,"contact_tips":encode(contact_tips)}
 check(arm_error<.001 and leg_error<.001,"combo limb lengths remain anatomical in every context")
 check(grip_error<.0001,"every blade grip is the actual palm")
 check(low_blade_top>=-20 and low_blade_bottom<=.001,"complete ordinary low blade arc fits20px clearance")
 check(low_top>=-19.7,"low body fits20px clearance")
 check(floor_distance>-.001 and sole_error<.001,"ground soles and knees obey the reported floor plane")
 check(visible_blade_floor>-.001,"ground-only visible blade segments stay above floor")
 check(max_settle<=4.0,"slope fitting remains bounded with no root motion")
 for pair in [["slash","backhand"],["backhand","finisher"],["finisher","slash"]]:check(Vector2(contact_tips[pair[0]]).distance_to(contact_tips[pair[1]])>5,"three contact tips create distinct arcs")
func _timing() -> void:
 for step in Keys.STEP_IDS:
  var mode:String="attack_"+step+"_active"
  var a:=Pose.evaluate(mode,.05,snapshot(step,"active",.05));var b:=Pose.evaluate(mode,.55,snapshot(step,"active",.55))
  check(a.bones==b.bones and a.weapon==b.weapon,"each active key is held before follow-through "+step)
  var end:=Pose.evaluate(mode,1,snapshot(step,"active",1));var start:=Pose.evaluate("attack_"+step+"_recovery",0,snapshot(step,"recovery",0))
  check(end.bones==start.bones and end.weapon.tip==start.weapon.tip,"active follow-through flows into recovery "+step)
  var rise:=Pose.evaluate(mode,.1,snapshot(step,"active",.1,1,"rise"));var fall:=Pose.evaluate(mode,.1,snapshot(step,"active",.1,1,"fall"))
  check(rise.bones.sole_near!=fall.bones.sole_near,"air legs retain actual rising/falling context "+step)
 for pair in [["slash","backhand"],["backhand","finisher"]]:
  for reversed in [false,true]:
   var before:=snapshot(pair[0],"recovery",.4)
   var old:=Pose.evaluate(str(before.pose),.4,before)
   var next:=snapshot(pair[1],"windup",0,-1 if reversed else 1)
   next["combo_visual_entry"]={"step":pair[0],"phase":"recovery","progress":.4,"facing":1}
   var initial:=Pose.evaluate(str(next.pose),0,next)
   for bone in ["pelvis","chest","shoulder_near","shoulder_far","palm_near","palm_far","sole_near","sole_far"]:check(Vector2(old.bones[bone]).distance_to(initial.bones[bone])<(4.601 if reversed and str(bone).begins_with("shoulder_") else .001),"early chain entry respects committed turn geometry "+bone)
   check(Vector2(old.weapon.tip).distance_to(initial.weapon.tip)<.001,"early chain blade enters continuously, including reversal")
 for pair in [["slash","backhand"],["backhand","finisher"]]:
  for i in range(31):
   var p:=float(i)/30*.45;var t:=snapshot(pair[1],"windup",p,-1,"low")
   t["combo_visual_entry"]={"step":pair[0],"phase":"recovery","progress":.4,"facing":1}
   var pose:=Pose.evaluate(str(t.pose),p,t)
   if i==0:
    var previous_t:=snapshot(pair[0],"recovery",.4,1,"low")
    var previous_pose:=Pose.evaluate(str(previous_t.pose),.4,previous_t)
    metrics["maximum_low_turn_entry_palm_shift_px"]=maxf(float(metrics.get("maximum_low_turn_entry_palm_shift_px",0)),Vector2(previous_pose.bones.palm_near).distance_to(pose.bones.palm_near))
   for point in ["tip","blade_a","blade_b","pommel","guard_a","guard_b"]:check(pose.weapon[point].y>=-20 and pose.weapon[point].y<=.001,"low reversal projects its blade inside clearance")
   check(Vector2(pose.weapon.grip).distance_to(pose.bones.palm_near)<.001,"low reversal keeps the palm attached")
   if p<.45:check(pose.weapon.turn_projection_fraction<=1.0001,"low reversal is an authored edge-on projection")
func _split_facing() -> void:
 var max_reach_adjust:=0.0
 for step in Keys.STEP_IDS:
  for phase in Keys.PHASES:
   for context in ["ground","rise","fall","low","landing"]:
    for body_facing in [-1,1]:
     for i in range(21):
      var progress:=float(i)/20
      var t:=snapshot(step,phase,progress,body_facing,context)
      t.attack_facing=-body_facing
      var pose:=Pose.evaluate(str(t.pose),progress,t)
      check(pose.facing==body_facing and pose.combo.body_facing==body_facing,"chain body always follows authoritative body facing")
      var expected:int=-body_facing if phase=="active" else body_facing
      check(pose.combo.weapon_facing==expected and pose.combo.strike_facing==-body_facing,"only the live active blade retains committed strike facing")
      if phase=="active":check((Vector2(pose.weapon.tip)-Vector2(pose.weapon.grip)).x*expected>0,"active blade still points along the committed strike")
      else:
       var aligned:=t.duplicate(true);aligned.attack_facing=body_facing
       var expected_pose:=Pose.evaluate(str(t.pose),progress,aligned)
       check(pose.bones==expected_pose.bones and pose.weapon.tip==expected_pose.weapon.tip,"non-active body and blade ignore an old strike direction")
      check(Vector2(pose.weapon.grip).distance_to(pose.bones.palm_near)<.001,"split facing retains the actual hand grip")
      check(absf(Vector2(pose.bones.shoulder_near).distance_to(pose.bones.elbow_near)-6)<.001 and absf(Vector2(pose.bones.elbow_near).distance_to(pose.bones.palm_near)-5.8)<.001,"opposed active strike keeps an anatomical arm")
      max_reach_adjust=maxf(max_reach_adjust,float(pose.combo.arm_reach_adjustment))
 metrics["maximum_split_facing_palm_adjustment_px"]=max_reach_adjust
func _lifecycle() -> void:
 var view=Visual.new();var t:=snapshot("slash","active",.2)
 view.event("attack_started",{"serial":4,"chain_serial":2,"attack_pose_id":"slash"});view.present(0,t)
 view.event("strike_confirmed",{"serial":4,"contact_position":Vector2(132,78)})
 view.present(0,t);var base:=view.get_pose()
 check(base.weapon.confirmed and Vector2(base.weapon.contact_point)+Vector2(t.position)==Vector2(132,78),"real serial mark uses reported world contact")
 t["paused"]=true
 for i in 12:view.present(.016,t)
 check(view.get_pose()==base,"hitpause holds current combo key and mark")
 t.position+=Vector2(3,-2);t.world_position=t.position;t.support_displacement=Vector2(3,-2)
 view.present(0,t)
 check(Vector2(view.get_pose().weapon.contact_point)+Vector2(t.position)==Vector2(132,78),"carrier transport does not move old world contact")
 t.paused=false;t.facing=-1;t.pose="attack_slash_recovery";t.weapon_phase="recovery";t.weapon_phase_progress=.25
 view.present(0,t)
 check(view.get_pose().facing==-1 and view.get_pose().combo.weapon_facing==-1,"recovery body and blade follow a permitted body reversal")
 check(view.get_pose().weapon.contact_facing==1 and Vector2(view.get_pose().weapon.contact_point)+Vector2(t.position)==Vector2(132,78),"recovery turn does not turn or relocate the accepted impact")
 # The next step starts from the displayed recovery direction, not old strike direction.
 t=snapshot("slash","recovery",.4,-1);t.attack_facing=1;view.present(0,t)
 view.event("attack_finished",{"serial":4,"chain_serial":2,"early_chain":true})
 view.event("attack_started",{"serial":5,"chain_serial":2,"attack_pose_id":"backhand"})
 t=snapshot("backhand","windup",0,-1);t.attack_serial=5;view.present(0,t)
 check(view.get_pose().combo.entry_blend and not view.get_pose().weapon.confirmed,"new committed step enters prior recovery and clears contact")
 check(view.get_pose().facing==-1 and view.get_pose().bones.chest.x<view.get_pose().bones.pelvis.x,"early chain captures actual turned recovery facing")
 view.event("strike_confirmed",{"serial":4,"contact_position":Vector2(1000,1000)});view.present(0,t)
 check(not view.get_pose().weapon.confirmed,"late old-step confirmation is rejected")
 t=snapshot("backhand","active",.1,-1);t.attack_serial=5
 view.event("strike_confirmed",{"serial":5,"contact_position":Vector2(70,80)});view.present(0,t)
 check(view.get_pose().weapon.contact_facing==-1,"contact on the first turned active tick uses the current committed facing")
 for replacement in ["roll_start","hurt","shield_raise","fall","dive_startup","climb_idle","wall_run","ledge_hang","hard_land_impact"]:
  view.event("attack_cancelled",{"serial":5})
  check(not view.get_pose().weapon.visible,"cancel retires combo blade synchronously")
  var idle:Dictionary={"pose":replacement,"facing":1,"grounded":false,"weapon_phase":"idle","body_height":34.0,"main_action":""}
  if replacement=="shield_raise":idle["shield_active"]=true
  idle["attack_pose_id"]="backhand";idle["weapon_phase"]="active";idle["attack_serial"]=5
  view.present(0,idle);check(not view.get_pose().weapon.visible,"replacement hides stale blade "+replacement)
  view.event("attack_started",{"serial":5,"chain_serial":3,"attack_pose_id":"backhand"});view.present(0,t)
 view.reset_presentation();check(not view.get_pose().weapon.visible,"reset immediately retires combo geometry")
 view.present(0,{"pose":"idle","grounded":true});check(not view.get_pose().has("combo"),"idle carries no combo metadata")
 check(view.position==Vector2.ZERO and view.rotation==0 and view.scale==Vector2.ONE,"view never moves or scales the physical root")
 view.free()
func _transition_samples() -> void:
 for variant in ["forward","reverse","low","low_reverse"]:
  var view=Visual.new();var time:=0.0
  for index in 3:
   var step:String=Keys.STEP_IDS[index];var serial:=10+index
   var facing:=-1 if variant in ["reverse","low_reverse"] and index==1 else 1
   view.event("attack_started",{"serial":serial,"chain_serial":8,"attack_pose_id":step})
   var times:Array=[[.07,.065,.06],[.065,.07,.065],[.12,.1,.24]][index]
   for phase_index in 3:
    var phase:String=Keys.PHASES[phase_index];var duration:float=times[phase_index]
    var full:float=([.16,.17,.24][index] if phase=="recovery" else duration)
    var count:=maxi(1,int(ceil(duration*60)))
    for i in range(count+1):
     var p:float=minf(1,float(i)/count*duration/full)
     var t:=snapshot(step,phase,p,facing,"low" if variant in ["low","low_reverse"] else "ground")
     t.attack_serial=serial;t.chain_serial=8;t.velocity=Vector2.ZERO
     view.present(1.0/60.0,t)
     transitions.append({"variant":variant,"time":time,"step":step,"phase":phase,"pose":encode(view.get_pose()),"telemetry":encode(t)})
     time+=1.0/60.0
  view.free()
func _draw() -> void:
 var view=Visual.new();root.add_child(view);var draws:Array=[];view.draw.connect(func():draws.append(true))
 for step in Keys.STEP_IDS:
  for phase in Keys.PHASES:
   view.present(.016,snapshot(step,phase,.3));await process_frame;await process_frame
 check(draws.size()==9,"all nine combo modes execute runtime drawing")
 metrics["draw_notifications"]=draws.size();view.queue_free();await process_frame
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
