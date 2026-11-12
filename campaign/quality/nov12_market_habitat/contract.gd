extends SceneTree
const Habitat=preload("res://campaign/presentation/market_habitat.gd")
const Scenery=preload("res://campaign/presentation/campaign_scenery.gd")
const Data=preload("res://campaign/logic/campaign_data.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var sectors=Data.sectors()
	check(sectors.size()==32,"Catalog remains32 districts")
	var original=sectors.duplicate(true)
	var scenery=Scenery.new()
	scenery.z_index=-5
	root.add_child(scenery)
	var market:Dictionary={}
	for sector in sectors:
		scenery.configure(sector)
		check(scenery.get_child_count()==2,"Stable presentation root shape: "+sector.id)
		check(is_instance_valid(scenery.habitat)==(sector.id==Habitat.DISTRICT_ID),"Exact district selection: "+sector.id)
		if sector.id==Habitat.DISTRICT_ID:
			market=sector
			check(scenery.habitat.get_parent()==scenery.backdrop,"Habitat district owned")
			check(scenery.habitat.z_index+scenery.backdrop.z_index<scenery.terrain_paint.z_index,"Habitat behind exact terrain")
			check(scenery.habitat.get_child_count()==0,"No resident nodes or physics children")
			check(not scenery.habitat.is_processing(),"Static view has no per-frame process")
			scenery.set_sight_enabled(false)
			check(not scenery.habitat.is_visible_in_tree(),"Blind hides habitat subtree")
			scenery.set_sight_enabled(true)
			check(scenery.habitat.is_visible_in_tree(),"Retained sight restores habitat")
		await process_frame
	check(sectors==original,"No authored catalog mutation through32 configurations")
	scenery.configure(market)
	var habitat=scenery.habitat
	check(Habitat.CLUSTERS.size()==3,"Exactly3 authored landmark clusters")
	check(Habitat.MAX_RESIDENTS==6,"Six decorative residents bounded")
	check(market.platforms.has(Rect2(1350,-90,260,18)),"Awning anchored below actual key platform")
	check(market.platforms.has(Rect2(3100,180,480,18)),"Refuge above actual east platform")
	check(market.ladders.has([1460,110,200]),"Key recovery ladder unchanged")
	for index in Habitat.CLUSTERS.size():
		var bounds:Rect2=Habitat.CLUSTERS[index]
		check(bounds.position.x>=0 and bounds.end.x<=market.width,"Cluster within district width")
		scenery.update_view(bounds.get_center(),Vector2(40,40))
		check(habitat.camera_center==bounds.get_center(),"View explicitly forwarded")
		check(habitat.cluster_indices_in_view()==[index],"Only intersecting landmark painted")
	scenery.update_view(Vector2(-10000,-10000),Vector2(640,360))
	check(habitat.cluster_indices_in_view().is_empty(),"Offscreen clusters culled")
	var before=market.duplicate(true)
	seed(874)
	var expected=randi()
	seed(874)
	habitat.configure(market)
	check(randi()==expected,"No global RNG consumption")
	check(market==before,"Habitat does not retain or alter caller data")
	habitat.configure({"id":"l3_water_clinic"})
	habitat.set_view(Vector2(1480,0),Vector2(640,360))
	check(habitat.cluster_indices_in_view().is_empty(),"Unknown profile paints nothing")
	scenery.queue_free()
	await process_frame
	print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Static ownership/culling/sight/data contract; no native visual or gameplay acceptance"}))
	quit(0 if failures.is_empty() else 1)
