extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
const Climb=preload("res://combat_pc/visuals/climb_pose.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func attached()->Dictionary:
 return {"world_position":Vector2(1260,132),"position":Vector2(1260,132),"climb_axis_x":1260.0,"climb_top_y":130.0,"climb_bottom_y":300.0,"climb_rung_spacing":12.0,"climb_rung_origin_offset":4.0,"body_height":34.0,"grounded":false,"facing":1,"pose":"climb_top_exit","climb_active":true,"climb_phase":"top_exit","climb_phase_progress":1.0-2.0/34.0,"main_action":"climb"}
func _initialize()->void:run.call_deferred()
func run()->void:
 for reason in ["top_exit","horizontal_release","bottom_exit","floor_exit","damage","jump","invalid_target"]:
  for grounded in [false,true]:
   var v=Visual.new();v.present(0,attached())
   var before:Dictionary=v.get_pose().duplicate(true)
   v.event("climb_detached",{"reason":reason})
   var t:Dictionary={"pose":"idle" if grounded else "fall","main_action":"locomotion","grounded":grounded,"position":Vector2(1260,130),"world_position":Vector2(1260,130),"body_height":34.0}
   v.present(0,t)
   var p:Dictionary=v.get_pose()
   if reason=="top_exit" and grounded:
    check(p.mode=="climb_release" and Vector2(p.bones.pelvis).distance_to(before.bones.pelvis)<.01,"supported top exit retains compact torso at release start")
    check(not p.climb_support and p.planted_hands==[false,false],"release claims no climbing grip")
    for bone in ["chest","head","palm_near","palm_far"]:check(Vector2(p.bones[bone]).distance_to(before.bones[bone])<4.0,"bounded body-local detach continuity "+bone)
    v.present(.05,t);check(v.get_pose().bones.pelvis.y < p.bones.pelvis.y,"supported transition rises toward ready")
    v.present(.06,t);check(v.pose_name!="climb_release","release retires at existing duration")
   else:
    check(not (p.mode=="climb_release" and absf(float(p.bones.pelvis.y)+8)<.01),"no compact completion on unsupported/non-top "+reason)
   v.free()
 for action in ["hurt","roll_start","attack_windup","jump_rise"]:
  var v=Visual.new();v.present(0,attached());v.event("climb_detached",{"reason":"top_exit"})
  var t:Dictionary={"pose":action,"main_action":"hurt" if action=="hurt" else "locomotion","grounded":false,"weapon_phase":"windup" if action=="attack_windup" else "idle"}
  if action=="jump_rise":v.event("ground_jump")
  v.present(0,t);check(v.pose_name!="climb_release","real action immediately owns presentation "+action);v.free()
 print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Seeded existing visual events and authoritative-action snapshots; no earned gameplay/native continuity claim"}));quit(0 if failures.is_empty() else 1)
