extends SceneTree
## Catalog and presentation composition only. This is not an input-route fixture.
## Source and packed executions are distinct receipts; neither proves native pixels.
const Data = preload("res://campaign/logic/campaign_data.gd")
const Scenery = preload("res://campaign/presentation/campaign_scenery.gd")
const Habitat = preload("res://campaign/presentation/memory_loom_habitat.gd")
var checks := 0
var failures:Array[String] = []
func check(ok:bool,label:String)->void:
	checks += 1
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var catalog:Dictionary = Data.load_catalog()
	check(catalog.ok,"complete catalog validates")
	if not catalog.ok:
		print(JSON.stringify({"passed":false,"failures":failures}))
		quit(1)
		return
	var sectors:Array = catalog.sectors
	check(sectors.size()==32,"32 stable districts")
	var original := sectors.duplicate(true)
	var loom:Dictionary = {}
	var scenery = Scenery.new()
	scenery.z_index = -5
	root.add_child(scenery)
	for district in sectors:
		scenery.configure(district)
		check(scenery.get_child_count()==2,"stable scenery root shape: "+district.id)
		check(is_instance_valid(scenery.memory_loom_habitat)==(district.id==Habitat.DISTRICT_ID),"exact Loom-only child: "+district.id)
		if district.id==Habitat.DISTRICT_ID:
			loom = district
			check(scenery.memory_loom_habitat.get_parent()==scenery.backdrop,"district-owned presentation lifetime")
			check(scenery.memory_loom_habitat.z_index+scenery.backdrop.z_index<scenery.terrain_paint.z_index,"residents below terrain and gameplay")
			check(scenery.memory_loom_habitat.get_child_count()==0,"no resident actors/collision children")
			check(not scenery.memory_loom_habitat.is_processing() and not scenery.memory_loom_habitat.is_physics_processing(),"no scenery tick")
			scenery.set_sight_enabled(false)
			check(not scenery.memory_loom_habitat.is_visible_in_tree(),"sight sacrifice hides entire local frontage")
			scenery.set_sight_enabled(true)
			check(scenery.memory_loom_habitat.is_visible_in_tree(),"retained sight restores local frontage")
		await process_frame
	check(sectors==original,"32 configurations never mutate authored input")
	check(not loom.is_empty(),"stable district found")
	if loom.is_empty():
		scenery.queue_free()
		await process_frame
		quit(1)
		return
	check(loom.objectives.map(func(g):return str(g.id))==["first_account","other_account","preserve","index"],"stable objective and receipt IDs")
	check(loom.objectives[2].requires==["first_account","other_account"],"preservation still requires both originals")
	check(loom.objectives[2].at==Vector2(3550,300),"isolation desk belongs to east dispatch")
	check(loom.spawn==Vector2(1900,300) and loom.station==Vector2(1800,300),"commons keeps entry and public-copy station")
	check(loom.objective_doors.map(func(d):return d.at)==[Vector2(1440,205),Vector2(2360,205),Vector2(3690,160)],"both returns and final seal keep their positions")
	check(loom.objectives[3].optional and loom.objectives[3].reward=="vitality","optional index keeps same reward")
	check(loom.enemies.size()==7,"seven ordinary enemies, no added waves")
	check(loom.irritants==[{"at":Vector2(2880,268)}],"existing default disperser only")
	check(loom.objective_doors[0].requires==["first_account"] and loom.objective_doors[1].requires==["other_account"] and loom.objective_doors[2].requires==["preserve"],"separate return requirements and final seal")
	scenery.configure(loom)
	var habitat = scenery.memory_loom_habitat
	check(Habitat.CLUSTERS.size()==3 and Habitat.MAX_RESIDENTS==8,"bounded original frontage/commons/gallery")
	var texture_bounds := Rect2(Vector2.ZERO,Vector2(Habitat.Materials.get_size()))
	for index in 3:check(texture_bounds.encloses(habitat.material_region(index)),"material crop within existing original texture")
	check(Habitat.Materials.get_size()==Vector2(1774,887),"original atlas dimensions")
	for index in 3:
		var source:Rect2=habitat.material_region(index)
		var destination:Rect2=habitat.frontage_rect(index)
		check(is_equal_approx(source.size.x/source.size.y,destination.size.x/destination.size.y),"no atlas aspect distortion")
		check(Habitat.CLUSTERS[index].encloses(destination),"frontage stays inside reserved cluster")
		for other in range(index+1,3):check(not source.intersects(habitat.material_region(other)),"separate guarded atlas strips")
	check(habitat.material_region(1).encloses(habitat.commons_counter_region()),"counter samples only commons pixels")
	check(habitat.frontage_rect(1).encloses(habitat.commons_counter_rect()),"counter maps inside bay")
	check(habitat.commons_counter_rect().position.y>248 and habitat.commons_counter_rect().position.y<269,"counter leaves resident heads/torso visible and covers feet")
	for index in Habitat.CLUSTERS.size():
		var bounds:Rect2 = Habitat.CLUSTERS[index]
		check(bounds.position.x>=0 and bounds.end.x<=loom.width,"cluster inside district")
		scenery.update_view(bounds.get_center(),Vector2(40,40))
		check(habitat.camera_center==bounds.get_center(),"explicit view forwarding")
		check(habitat.cluster_indices_in_view()==[index],"bounded view culling")
	scenery.update_view(Vector2(-10000,-10000),Vector2(640,360))
	check(habitat.cluster_indices_in_view().is_empty(),"no offscreen drawing clusters")
	seed(4917)
	var expected := randi()
	seed(4917)
	habitat.configure(loom)
	check(randi()==expected,"no scenery RNG side effect")
	habitat.configure({"id":"works_receiving"})
	habitat.set_view(Vector2(1900,220),Vector2(640,360))
	check(habitat.cluster_indices_in_view().is_empty(),"non-Loom profile paints nothing")
	scenery.configure(loom)
	var old_child:WeakRef = weakref(scenery.memory_loom_habitat)
	scenery.configure(sectors[0])
	await process_frame
	check(not is_instance_valid(old_child.get_ref()),"room reconfiguration retires local habitat")
	scenery.queue_free()
	await process_frame
	print("MEMORY_LOOM_CONTRACT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Catalog/presentation composition only, not actor traversal or native appearance"}))
	quit(0 if failures.is_empty() else 1)
