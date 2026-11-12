extends SceneTree
## Identical presentation-only camera sweep. NOT gameplay or traversal evidence.
func _initialize()->void:call_deferred("run")
func run()->void:
	var data=preload("res://campaign/logic/campaign_data.gd").sectors()
	var scenery=load("res://campaign/presentation/campaign_scenery.tscn").instantiate()
	root.add_child(scenery)
	for sector in data:
		if sector.id=="l2_freight":scenery.configure(sector)
	var camera=Camera2D.new();root.add_child(camera);camera.enabled=true
	for tick in 600:
		var center:=Vector2(320.0+2200.0*tick/600.0,100.0+sin(tick*.01)*70.0)
		camera.position=center;scenery.update_view(center,Vector2(640,360))
		await process_frame
	scenery.free();camera.free();await process_frame
	print("FOUNDRY_RENDER_SWEEP_COMPLETE 600 identical camera steps; no simulation")
	quit()
