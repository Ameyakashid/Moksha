extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var host=load("res://campaign/campaign.tscn").instantiate();root.add_child(host);host.save_enabled=false
	host.start_new(true)
	await physics_frame
	for i in host.sectors.size():
		host.load_sector(i)
		await physics_frame
		await process_frame
		print("DISTRICT ",i," ",host.sectors[i].id," goals=",host.goals.size())
	print("SMOKE_DISTRICTS=",host.sectors.size())
	quit()
