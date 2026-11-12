extends SceneTree
## Staged original pose samples, not gameplay evidence. Run on each revision.
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
func _initialize()->void:
 var destination:="user://completion-poses.txt"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):destination=arg.trim_prefix("--output=")
 var samples:Array=[]
 for gap in [24.0,9.0,2.0,0.0]:
  var supported:bool=gap==0
  var mode:String="climb_release" if supported else "climb_top_exit"
  var phase:float=1.0 if supported else 1.0-gap/34.0
  var t:Dictionary={"world_position":Vector2(1260,130+gap),"position":Vector2(1260,130+gap),"climb_axis_x":1260.0,"climb_top_y":130.0,"climb_bottom_y":300.0,"climb_rung_spacing":12.0,"climb_rung_origin_offset":4.0,"body_height":34.0,"grounded":supported,"facing":1,"climb_top_release":supported}
  samples.append({"gap":gap,"pose":Pose.evaluate(mode,phase,t)})
 FileAccess.open(destination,FileAccess.WRITE).store_string(var_to_str(samples))
 var transitions:Array=[]
 var visual=load("res://combat_pc/visuals/wireframe.gd").new()
 var near:Dictionary={"world_position":Vector2(1260,132),"position":Vector2(1260,132),"climb_axis_x":1260.0,"climb_top_y":130.0,"climb_bottom_y":300.0,"climb_rung_spacing":12.0,"climb_rung_origin_offset":4.0,"body_height":34.0,"grounded":false,"facing":1,"pose":"climb_top_exit","climb_active":true,"climb_phase":"top_exit","climb_phase_progress":1.0-2.0/34.0,"main_action":"climb"}
 visual.present(0,near);visual.event("climb_detached",{"reason":"top_exit"})
 var t:Dictionary={"pose":"idle","main_action":"locomotion","grounded":true,"position":Vector2(1260,130),"world_position":Vector2(1260,130),"body_height":34.0}
 var elapsed:=0.0
 for dt in [0.0,.025,.025,.05]:
  elapsed+=dt;visual.present(dt,t);transitions.append({"gap":0.0,"seconds":elapsed,"pose":visual.get_pose().duplicate(true)})
 FileAccess.open(destination+".transition",FileAccess.WRITE).store_string(var_to_str(transitions));visual.free();quit()
