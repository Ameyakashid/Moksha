extends SceneTree
func _initialize()->void:
	print("PACK_PATH_PROBE ",JSON.stringify({"res":ProjectSettings.globalize_path("res://"),"user":ProjectSettings.globalize_path("user://nov6_audio/result.json")}))
	quit()
