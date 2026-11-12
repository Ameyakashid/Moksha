extends "res://campaign/quality/nov12_ladder_teaching/owner_contract.gd"
## Reuses real host -> owner -> painter delivery, with exact staged-input trace.
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const Climb=preload("res://combat_pc/visuals/climb_pose.gd")
var trace:Array=[]
var below_seen:=false
var near_seen:=false
var exit_seen:=false
var reference:=false
var output:="user://completion-trace.json"
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg=="--reference":reference=true
  if arg.begins_with("--trace="):output=arg.trim_prefix("--trace=")
 super._initialize()
func step(frame:Dictionary,count:=1)->void:
 # Budget one tick at a time: baseline and pilot receive identical inputs.
 for i in count:
  await super.step(frame,1)
  var p=host.player
  trace.append([label,driver.ticks,p.position.x,p.position.y,p.velocity.x,p.velocity.y,str(p.main_action),p.grounded,str(p._climb_phase),p.phase_progress,host.health.current_health])
  if not reference and p.main_action==&"climb" and p._climb_phase==&"top_exit":
   var t:Dictionary=p.telemetry();var original:Dictionary=t.duplicate(true)
   var key:Dictionary=Climb.sample("climb_top_exit",p.phase_progress,t)
   if float(t.world_position.y)-float(t.climb_top_y)<4.0:check(key.pelvis==Vector2(-1,-8) and key.lean==39.0,"near-top approach is compact, not standing")
   var pose:Dictionary=Pose.evaluate("climb_top_exit",p.phase_progress,t)
   check(pose.climb_support and t==original,"pose is pure body-local climbing presentation")
   for bone in Pose.BONE_NAMES:check(Vector2(pose.bones[bone]).is_finite(),"finite top-approach bone")
   var gap:float=p.position.y-float(t.climb_top_y)
   if gap>10:below_seen=true
   if gap>0 and gap<10:near_seen=true
  if p.main_action!=&"climb" and p.grounded and absf(p.position.y-130)<.2:exit_seen=true
func run()->void:
 await super.run()
 if not reference:
  check(below_seen and near_seen and exit_seen,"real input crossed below-top, near-top and supported exit")
  # Supported release remains unchanged and no longer claims climbing support.
  var released:Dictionary=Climb.sample("climb_release",1,{"grounded":true})
  check(not released.climb_support and released.feet_on==[true,true],"standing only after supported release")
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(trace))
 print(JSON.stringify({"completion_checks":checks,"passed":failures.is_empty(),"trace_samples":trace.size(),"below_top":below_seen,"near_top":near_seen,"supported_exit":exit_seen,"reference":reference}))
 quit(0 if failures.is_empty() else 1)
