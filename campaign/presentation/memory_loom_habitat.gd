extends Node2D
## Original district-local archive frontage. Decorative residents are not actors.
## No simulation, objective, scent, input or save ownership; no process callback.
const DISTRICT_ID := "works_memory_loom"
const Materials = preload("res://campaign/assets/memory/archive_frontage_original.png")
const FontFace = preload("res://fonts/DejaVuSansMono.ttf")
const CLUSTERS := [Rect2(390,104,880,196), Rect2(1680,138,460,162), Rect2(2510,-90,970,170)]
const MAX_RESIDENTS := 8
const INK := Color("142028")
const CYAN := Color("659b9c")
const AMBER := Color("a58c68")
const MAGENTA := Color("956d86")
var district_id := ""
var camera_center := Vector2(320,180)
var viewport_size := Vector2(640,360)
var visible_clusters := 0
var visible_residents := 0

func configure(profile:Dictionary)->void:
	district_id = str(profile.get("id",""))
	queue_redraw()

func set_view(center:Vector2,size:Vector2)->void:
	if camera_center == center and viewport_size == size:return
	camera_center = center
	viewport_size = size
	queue_redraw()

func cluster_indices_in_view()->Array[int]:
	var output:Array[int]=[]
	if district_id != DISTRICT_ID:return output
	var view := Rect2(camera_center-viewport_size*.5,viewport_size).grow(16)
	for index in CLUSTERS.size():
		if view.intersects(CLUSTERS[index]):output.append(index)
	return output

func _draw()->void:
	visible_clusters = 0
	visible_residents = 0
	for index in cluster_indices_in_view():
		visible_clusters += 1
		match index:
			0:_listening_stacks()
			1:_commons()
			2:_rewriting_gallery()

func _plaque(box:Rect2,label:String,light:Color)->void:
	draw_rect(box,INK)
	# A narrow sign rim, never a walkable bright horizontal shelf.
	draw_line(box.position,box.position+Vector2(0,box.size.y),light,1.5)
	draw_string(FontFace,box.position+Vector2(6,12),label,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-10,9,light)

func material_region(index:int)->Rect2:
	# Dedicated original front-elevation atlas; guarded separate non-tiled strips.
	return [Rect2(36,26,1699,275),Rect2(37,342,966,232),Rect2(34,615,1704,243)][clampi(index,0,2)]

func frontage_rect(index:int)->Rect2:
	var width:float=[880.0,460.0,970.0][clampi(index,0,2)]
	var region:=material_region(index)
	var height:=width*region.size.y/region.size.x
	var left:float=[390.0,1680.0,2510.0][clampi(index,0,2)]
	var bottom:float=[294.0,292.0,74.0][clampi(index,0,2)]
	return Rect2(left,bottom-height,width,height)

func commons_counter_region()->Rect2:
	# Same original pixels replayed over residents, no added opaque glazing.
	return Rect2(37,513,966,61)

func commons_counter_rect()->Rect2:
	var full:=material_region(1)
	var band:=commons_counter_region()
	var box:=frontage_rect(1)
	var pixel_scale:=box.size.x/full.size.x
	return Rect2(box.position+(band.position-full.position)*pixel_scale,band.size*pixel_scale)

func _frontage(index:int)->void:
	draw_texture_rect_region(Materials,frontage_rect(index),material_region(index),Color(.82,.86,.94,1),false,true)

func _listening_stacks()->void:
	_frontage(0)
	_plaque(Rect2(410,113,220,20),"ORIGINALS / STACK A",AMBER)
	_plaque(Rect2(910,114,230,20),"UNALTERED / LOCAL COPIES",AMBER)

func _resident(foot:Vector2,coat:Color,parcel:bool)->void:
	draw_set_transform(foot,0,Vector2(.64,.64))
	draw_line(Vector2(-3,-10),Vector2(-4,0),Color("29353d"),3,true)
	draw_line(Vector2(3,-10),Vector2(4,0),Color("29353d"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-27),Vector2(4,-27),Vector2(6,-9),Vector2(-5,-9)]),coat)
	draw_circle(Vector2(0,-32),3.3,Color("88786e"))
	draw_line(Vector2(-4,-25),Vector2(-7,-14),coat.darkened(.12),3,true)
	draw_line(Vector2(4,-24),Vector2(7,-16),coat.lightened(.1),3,true)
	if parcel:draw_rect(Rect2(3,-21,10,8),Color("87765e"))
	draw_set_transform(Vector2.ZERO)
	visible_residents += 1

func _commons()->void:
	# Rear bay -> eight separate decorative residents -> matching counter pixels.
	_frontage(1)
	var coats := [Color("586272"),Color("6b5369"),Color("667060"),Color("776754")]
	var positions := [1756.0,1780.0,1815.0,1880.0,1906.0,2012.0,2039.0,2070.0]
	for i in MAX_RESIDENTS:
		_resident(Vector2(positions[i],269),coats[i%4],i%3==0)
	draw_texture_rect_region(Materials,commons_counter_rect(),commons_counter_region(),Color(.82,.86,.94,1),false,true)
	_plaque(Rect2(1700,141,300,20),"RECORDS / COMMONS",CYAN)
	_plaque(Rect2(1860,181,136,18),"PUBLIC COPIES",MAGENTA)
	_plaque(Rect2(2010,141,112,20),"NO ERASURE",AMBER)

func _rewriting_gallery()->void:
	_frontage(2)
	_plaque(Rect2(2518,-84,266,22),"REWRITING / STACK B",MAGENTA)
	_plaque(Rect2(3200,-84,260,22),"WITNESS / DO NOT REWRITE",CYAN)
