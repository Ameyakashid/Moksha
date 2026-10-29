extends "res://demo/mission.gd"
var taken:Dictionary={}
func _ready()->void:
	super._ready()
	save_enabled=false
	start_new(false)
func _process(dt:float)->void:
	super._process(dt)
	for item in [[0.30,"cock"],[0.62,"release_pause"],[1.08,"dodge"],[1.20,"catch"],[2.0,"hold"]]:
		if intro_time>=item[0] and not taken.has(item[1]):
			taken[item[1]]=true
			capture.call_deferred(item[1])
	if intro_time>2.5:
		print("OPENING NATIVE REVIEW COMPLETE")
		get_tree().quit()
func capture(label:String)->void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	print("OPENING CAPTURE ",label," ",get_viewport().get_texture().get_image().save_png("res://demo/evidence/native_opening_"+label+".png"))
