extends Node2D
## Original district-local archive frontage. Decorative residents are not actors.
## No simulation, objective, scent, input or save ownership; no process callback.
const DISTRICT_ID := "works_memory_loom"
const Materials = preload("res://campaign/assets/memory/memory_works_original.png")
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
	# Existing original archive painting, inspected at native resolution.
	# Storage ceramic, inhabited glazing, dark machinery; no new asset bytes.
	return [Rect2(802,152,126,170),Rect2(1880,205,270,105),Rect2(1518,240,156,225)][clampi(index,0,2)]

func _material(box:Rect2,index:int,tint:Color)->void:
	draw_texture_rect_region(Materials,box,material_region(index),tint)

func _listening_stacks()->void:
	# Rear-wall storage begins BELOW the optional platform's true y=80 lip.
	_plaque(Rect2(410,113,220,20),"ORIGINALS / STACK A",AMBER)
	for i in 6:
		var x := 405.0+i*143.0
		_material(Rect2(x,147,116,147),0,Color(.48,.50,.58,1))
		for row in 5:
			var y := 159.0+row*25.0
			for column in 5:
				var spine := Color(.23,.25,.28,.32) if (row+column+i)%3 else Color(.33,.29,.28,.32)
				draw_rect(Rect2(x+12+column*18,y,12,18),spine)
				draw_line(Vector2(x+14+column*18,y+4),Vector2(x+21+column*18,y+4),AMBER.darkened(.48),.7)
		# Inset cabinet seams stay subdued behind physical props and actors.
		draw_line(Vector2(x+4,150),Vector2(x+4,291),Color("35434a"),1)
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
	# Recessed public counter: people are behind glazing and a rear balustrade.
	# None suggests another rescue target, interact prompt or collidable NPC.
	_material(Rect2(1686,161,448,132),1,Color(.48,.53,.59,1))
	_plaque(Rect2(1700,141,300,20),"RECORDS / COMMONS",CYAN)
	for i in 4:
		var x := 1700.0+i*105.0
		draw_rect(Rect2(x,174,95,106),Color(.06,.12,.16,.28))
		draw_line(Vector2(x,174),Vector2(x,280),Color("3e5360"),2)
		draw_line(Vector2(x+5,177),Vector2(x+28,177),CYAN.darkened(.18),1)
	var coats := [Color("586272"),Color("6b5369"),Color("667060"),Color("776754")]
	for i in MAX_RESIDENTS:
		_resident(Vector2(1717+i*53,269),coats[i%4],i%3==0)
	# Transparent-looking rear counter separates scenery from the real walkway.
	draw_rect(Rect2(1698,251,422,35),Color(.09,.16,.20,.55))
	for x in range(1700,2121,28):draw_line(Vector2(x,251),Vector2(x,286),Color("31434d"),1)
	draw_line(Vector2(1698,251),Vector2(2120,251),Color("536672"),1)
	_plaque(Rect2(1860,181,136,18),"PUBLIC COPIES",MAGENTA)
	_plaque(Rect2(2010,141,112,20),"NO ERASURE",AMBER)

func _rewriting_gallery()->void:
	# Reels occupy the BACK wall. No false platform extends through real cover.
	_plaque(Rect2(2518,-84,266,22),"REWRITING / STACK B",MAGENTA)
	for i in 7:
		var x := 2530.0+i*133.0
		_material(Rect2(x,-49,108,123),2,Color(.44,.43,.55,1))
		draw_circle(Vector2(x+52,-15),20,Color("353448"))
		draw_arc(Vector2(x+52,-15),17,.2,TAU-.3,24,MAGENTA.darkened(.35),1)
		draw_circle(Vector2(x+52,-15),5,Color("61546a"))
		# Uneven narrow receipt ribbons, not a repeated navigable catwalk.
		draw_rect(Rect2(x+45,6,12,54-(i%3)*9),Color("655f68"))
		for line_index in 5:
			draw_line(Vector2(x+47,10+line_index*7),Vector2(x+54,10+line_index*7),Color("373a44"),.7)
		draw_line(Vector2(x+4,-43),Vector2(x+4,69),Color("37434f"),1)
	_plaque(Rect2(3200,-84,260,22),"WITNESS / DO NOT REWRITE",CYAN)
