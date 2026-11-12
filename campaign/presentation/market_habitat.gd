extends Node2D
## Original, optional district paint. Never an actor, collider or objective source.
const DISTRICT_ID := "l3_inundated_market"
const Materials = preload("res://campaign/assets/market/market_materials_original.png")
const FontFace = preload("res://fonts/DejaVuSansMono.ttf")
const CLUSTERS := [Rect2(105,174,470,126), Rect2(1325,-73,310,186), Rect2(3160,56,400,124)]
const MAX_RESIDENTS := 6
const CYAN := Color("547d80")
const MAGENTA := Color("81566d")
const INK := Color("13282c")
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
	# Authored local wayfinding; this scenery parent is hidden after sight trade.
	var foot_sign:=Rect2(1300,251,142,30)
	if district_id==DISTRICT_ID and Rect2(camera_center-viewport_size*.5,viewport_size).grow(16).intersects(foot_sign):
		_plaque(foot_sign,"FLOOD KEY  ↑",Color("e0b975"))
		draw_string(FontFace,foot_sign.position+Vector2(5,23),"MENDED SAILS",HORIZONTAL_ALIGNMENT_LEFT,134,8,CYAN)
	for index in cluster_indices_in_view():
		visible_clusters += 1
		match index:
			0:_entrance_stalls()
			1:_key_awning()
			2:_refuge()

func _plaque(box:Rect2,label:String,light:Color)->void:
	draw_rect(box,INK)
	draw_line(box.position,Vector2(box.end.x,box.position.y),light,.8)
	draw_string(FontFace,box.position+Vector2(5,10),label,HORIZONTAL_ALIGNMENT_LEFT,box.size.x-8,8,light)

func material_region(quadrant:int)->Rect2:
	# Inset avoids sampling the neighboring atlas panel at scaled boundaries.
	var half := Vector2(Materials.get_size())*.5
	return Rect2(Vector2(quadrant%2,quadrant/2)*half+Vector2(2,2),half-Vector2(4,4))

func _material(box:Rect2,quadrant:int,tint:Color)->void:
	draw_texture_rect_region(Materials,box,material_region(quadrant),tint)

func _cloth(points:PackedVector2Array,box:Rect2,tint:Color)->void:
	var region := material_region(2)
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((region.position+(point-box.position)/box.size*region.size)/Vector2(Materials.get_size()))
	draw_polygon(points,PackedColorArray([tint]),uvs,Materials)

func _shutter(box:Rect2)->void:
	_material(box,0,Color(.63,.72,.72,1))
	# Wet lower staining and shadow in the reveal, not a new collision lip.
	draw_colored_polygon(PackedVector2Array([box.position+Vector2(0,box.size.y*.70),box.position+Vector2(box.size.x,box.size.y*.77),box.end,Vector2(box.position.x,box.end.y)]),Color(.025,.07,.07,.30))
	draw_rect(Rect2(box.position.x,box.position.y,box.size.x,3),Color(0,.025,.03,.42))

func _bundle(at:Vector2,tint:Color)->void:
	draw_colored_polygon(PackedVector2Array([at+Vector2(-9,0),at+Vector2(-10,-9),at+Vector2(-6,-13),at+Vector2(7,-12),at+Vector2(10,-7),at+Vector2(9,0)]),tint)
	draw_line(at+Vector2(-7,-10),at+Vector2(8,-8),tint.lightened(.12),.7)
	draw_line(at+Vector2(1,-12),at+Vector2(1,0),Color("384243"),1)

func _entrance_stalls()->void:
	# Full-height closed shutters distinguish the market from portable cargo.
	for i in 3:
		var x := 120.0+i*150.0
		_material(Rect2(x-8,194,132,106),3,Color(.55,.66,.67,1))
		_shutter(Rect2(x,215,116,85))
		_plaque(Rect2(x,195,116,16),["REPAIRS / 04","NIGHT PRODUCE","TEXTILE REUSE"][i],CYAN if i%2==0 else MAGENTA)
		# Rolled fabric is narrow and ragged, not a walkable roof silhouette.
		_cloth(PackedVector2Array([Vector2(x-4,211),Vector2(x+120,211),Vector2(x+119,217),Vector2(x+44,219),Vector2(x-3,216)]),Rect2(x-4,211,124,8),Color(.60,.68,.70,1))
		_bundle(Vector2(x+98,299),Color("475249"))
	# Recessed entry mast; no direction arrow or interactable-looking icon.
	draw_rect(Rect2(105,174,8,126),Color("1c3439"))
	_plaque(Rect2(116,177,170,14),"MARKET / LOW WATER",CYAN)

func _key_awning()->void:
	# Cloth hangs UNDER the existing platform at (1350,-90,260,18).
	# The collision skin at y=-90 remains the only bright traversable lip.
	_material(Rect2(1352,-72,256,176),3,Color(.53,.65,.66,1))
	_shutter(Rect2(1375,-28,105,132))
	_shutter(Rect2(1492,-28,92,132))
	_plaque(Rect2(1380,-51,188,16),"MENDED SAILS / 04",MAGENTA)
	_cloth(PackedVector2Array([Vector2(1350,-72),Vector2(1610,-72),Vector2(1607,-56),Vector2(1530,-52),Vector2(1450,-55),Vector2(1352,-59)]),Rect2(1350,-72,260,20),Color(.69,.72,.76,1))
	for x in [1358.0,1602.0]:
		draw_line(Vector2(x,-70),Vector2(x,108),Color("344c50"),3)
		draw_line(Vector2(x,-70),Vector2(x+(-22 if x>1500 else 22),-32),Color("405456"),2)
	_bundle(Vector2(1540,104),Color("4d5850"))
	_bundle(Vector2(1570,104),Color("5c4e55"))

func _resident(foot:Vector2,coat:Color,small:bool,parcel:bool)->void:
	var s := .50 if small else .68
	draw_set_transform(foot,0,Vector2(s,s))
	draw_line(Vector2(-2,-10),Vector2(-3,0),Color("293b42"),3,true)
	draw_line(Vector2(3,-10),Vector2(4,0),Color("293b42"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-27),Vector2(4,-27),Vector2(5,-8),Vector2(-5,-8)]),coat)
	draw_line(Vector2(-4,-24),Vector2(-6,-13),coat.darkened(.15),3,true)
	draw_line(Vector2(4,-24),Vector2(7,-16),coat.lightened(.08),3,true)
	draw_circle(Vector2(0,-32),3,Color("756b61"))
	draw_arc(Vector2(-.5,-33),3,PI,TAU,8,Color("344047"),2,true)
	draw_line(Vector2(-3,-27),Vector2(4,-27),Color("846276"),2)
	if parcel:draw_rect(Rect2(4,-19,9,8),Color("706351"))
	draw_set_transform(Vector2.ZERO)
	visible_residents += 1

func _refuge()->void:
	# Occupants are behind the rear railing; their lane is not traversable.
	_material(Rect2(3170,66,370,108),3,Color(.53,.64,.65,1))
	draw_rect(Rect2(3170,66,370,5),Color(0,.02,.03,.48))
	for x in [3180.0,3300.0,3420.0]:
		_material(Rect2(x,88,104,80),1,Color(.66,.73,.72,1))
	_plaque(Rect2(3190,70,200,15),"ROOF REFUGE / RESIDENTS",CYAN)
	# Narrow laundry rope and irregular hanging fabric, deliberately not a ledge.
	draw_polyline(PackedVector2Array([Vector2(3170,58),Vector2(3350,64),Vector2(3540,57)]),Color("415153"),.7)
	for i in 5:
		var x := 3235.0+i*48
		_cloth(PackedVector2Array([Vector2(x,62),Vector2(x+15,62),Vector2(x+14,78+i%3),Vector2(x+2,76)]),Rect2(x,62,15,18),Color(.65,.72,.74,1) if i%2 else Color(.48,.64,.65,1))
	var coats := [Color("4b5661"),Color("64505f"),Color("586252")]
	for i in MAX_RESIDENTS:
		_resident(Vector2(3202+i*53,163),coats[i%3],i==2 or i==4,i%2==0)
	_bundle(Vector2(3218,167),Color("565342"))
	_bundle(Vector2(3485,167),Color("5d4b57"))
	for x in range(3170,3541,24):draw_line(Vector2(x,150),Vector2(x,174),Color("2b454b"),1)
	draw_line(Vector2(3170,150),Vector2(3540,150),Color("39565a"),1.4)
