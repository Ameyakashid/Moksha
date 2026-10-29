extends SceneTree
const Scenery = preload("res://campaign/presentation/campaign_scenery.tscn")
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for level in range(1,6):
		var node = Scenery.instantiate()
		root.add_child(node)
		var platforms: Array[Rect2] = [Rect2(80,210,141,16),Rect2(400,170,127,80)]
		var data := {"id":"visual_test", "level":level,"width":1000,"top":-100,"gaps":[Vector2(600,700)],"platforms":platforms}
		node.configure(data)
		check(node.get_child_count()==2,"two isolated paint components")
		check(node.terrain_paint.surfaces.size()==4,"floor gap and two precise platforms")
		check(node.terrain_paint.surfaces[0]==Rect2(0,300,600,80),"floor starts correctly")
		check(node.terrain_paint.surfaces[1]==Rect2(700,300,300,80),"gap remains empty")
		check(node.terrain_paint.surfaces[2]==platforms[0],"one-way bounds unchanged")
		check(node.backdrop.theme.motif==["city","foundry","water","memory","crown"][level-1],"five distinct visual themes")
		node.set_sight_enabled(false)
		check(not node.visible and not node.backdrop.is_visible_in_tree() and not node.terrain_paint.is_visible_in_tree(),"sight sacrifice hides complete art tree")
		node.configure(data)
		check(not node.visible and node.get_child_count()==2,"reconfiguration preserves blindness and no duplicate nodes")
		node.set_sight_enabled(true)
		check(node.visible,"sight restoration")
		for child in node.get_children():check(not child is CollisionObject2D,"paint never adds physics")
		node.queue_free()
	await process_frame
	if failures.is_empty():print("PRESENTATION_CONTRACT_PASS: 5 themes, gaps, exact surfaces, blind/reconfigure, no physics")
	else:for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
