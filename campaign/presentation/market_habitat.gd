extends Node2D
## Original, optional district paint. Never an actor, collider or objective source.
const DISTRICT_ID := "l3_inundated_market"
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

func _shutter(box:Rect2)->void:
	draw_rect(box,Color("253a3d"))
	for y in range(int(box.position.y)+4,int(box.end.y),6):
		draw_line(Vector2(box.position.x+2,y),Vector2(box.end.x-2,y),Color("34494a"),.7)
	# Flood staining is within the frontage, never an apparent platform edge.
	draw_rect(Rect2(box.position.x,box.end.y-25,box.size.x,25),Color(.06,.13,.13,.47))
	for x in range(int(box.position.x)+8,int(box.end.x),23):
		draw_line(Vector2(x,box.end.y-26),Vector2(x+2,box.end.y-12),Color("3c514b"),1)
	draw_line(Vector2(box.get_center().x,box.end.y-13),Vector2(box.get_center().x+7,box.end.y-13),Color("596160"),1)

func _bundle(at:Vector2,tint:Color)->void:
	draw_colored_polygon(PackedVector2Array([at+Vector2(-9,0),at+Vector2(-10,-9),at+Vector2(-6,-13),at+Vector2(7,-12),at+Vector2(10,-7),at+Vector2(9,0)]),tint)
	draw_line(at+Vector2(-7,-10),at+Vector2(8,-8),tint.lightened(.12),.7)
	draw_line(at+Vector2(1,-12),at+Vector2(1,0),Color("384243"),1)

func _entrance_stalls()->void:
	# Full-height closed shutters distinguish the market from portable cargo.
	for i in 3:
		var x := 120.0+i*150.0
		draw_rect(Rect2(x-8,194,132,106),INK)
		_shutter(Rect2(x,215,116,85))
		_plaque(Rect2(x,195,116,16),["REPAIRS / 04","NIGHT PRODUCE","TEXTILE REUSE"][i],CYAN if i%2==0 else MAGENTA)
		# Rolled fabric is narrow and ragged, not a walkable roof silhouette.
		draw_line(Vector2(x-4,212),Vector2(x+120,212),Color("435151"),4)
		for j in 8:draw_line(Vector2(x+j*16,211),Vector2(x+j*16+2,216),Color("635767"),2)
		_bundle(Vector2(x+98,299),Color("475249"))
	# Recessed entry mast; no direction arrow or interactable-looking icon.
	draw_rect(Rect2(105,174,8,126),Color("1c3439"))
	_plaque(Rect2(116,177,170,14),"MARKET / LOW WATER",CYAN)

func _key_awning()->void:
	# Cloth hangs UNDER the existing platform at (1350,-90,260,18).
	# The collision skin at y=-90 remains the only bright traversable lip.
	draw_rect(Rect2(1352,-72,256,176),Color(.05,.10,.12,.70))
	_shutter(Rect2(1375,-28,105,132))
	_shutter(Rect2(1492,-28,92,132))
	_plaque(Rect2(1380,-51,188,16),"MENDED SAILS / 04",MAGENTA)
	for i in 13:
		var x := 1350.0+i*20.0
		var hem := -54.0+float(i%3)*2.0
		draw_colored_polygon(PackedVector2Array([Vector2(x,-72),Vector2(x+20,-72),Vector2(x+18,hem),Vector2(x+2,hem-1)]),Color("675267") if i%2==0 else Color("36565b"))
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
	draw_rect(Rect2(3170,66,370,108),Color(.035,.08,.095,.92))
	for x in [3180.0,3300.0,3420.0]:
		draw_rect(Rect2(x,88,104,80),Color("233b3f"))
		draw_rect(Rect2(x+8,95,86,35),Color("35474a"))
		draw_line(Vector2(x+8,130),Vector2(x+94,130),Color("455c5b"),1)
	_plaque(Rect2(3190,70,200,15),"ROOF REFUGE / RESIDENTS",CYAN)
	# Narrow laundry rope and irregular hanging fabric, deliberately not a ledge.
	draw_polyline(PackedVector2Array([Vector2(3170,58),Vector2(3350,64),Vector2(3540,57)]),Color("415153"),.7)
	for i in 5:
		var x := 3235.0+i*48
		draw_colored_polygon(PackedVector2Array([Vector2(x,62),Vector2(x+15,62),Vector2(x+14,78+i%3),Vector2(x+2,76)]),Color("4f4b57") if i%2 else Color("455b58"))
	var coats := [Color("4b5661"),Color("64505f"),Color("586252")]
	for i in MAX_RESIDENTS:
		_resident(Vector2(3202+i*53,163),coats[i%3],i==2 or i==4,i%2==0)
	_bundle(Vector2(3218,167),Color("565342"))
	_bundle(Vector2(3485,167),Color("5d4b57"))
	for x in range(3170,3541,24):draw_line(Vector2(x,150),Vector2(x,174),Color("2b454b"),1)
	draw_line(Vector2(3170,150),Vector2(3540,150),Color("39565a"),1.4)
