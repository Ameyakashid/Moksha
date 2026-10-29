extends SceneTree
func _initialize():
 var out:String=OS.get_cmdline_user_args()[0]
 var data=load('res://demo/mission_data.gd').sectors()
 FileAccess.open(out,FileAccess.WRITE).store_string(var_to_str(data))
 quit()
