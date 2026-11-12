extends Node2D
## District-owned optional view. All citizens are background paint, never actors.
## Explicit values only: no input, physics, objectives, saves, or shared RNG.
const Plate=preload("res://campaign/assets/arcology/populous_arcology_original.png")
const FontFace=preload("res://fonts/DejaVuSansMono.ttf")
const MAX_CITIZENS:=144
const COATS=[Color("574455"),Color("3b6265"),Color("75614a"),Color("53614f"),Color("625477"),Color("49546a")]
var district_id:=""
var district_width:=640.0
var camera_center:=Vector2(320,180)
var viewport_size:=Vector2(640,360)
var citizens:Array[Dictionary]=[]
var visual_time:=0.0
var redraw_clock:=0.0
var seed_value:=1
var visible_citizens:=0

func configure(profile:Dictionary)->void:
	district_id=str(profile.get("id","rainline"))
	district_width=maxf(640,float(profile.get("width",640)))
	seed_value=1
	for byte in district_id.to_utf8_buffer():seed_value=posmod(seed_value*31+byte,104729)
	citizens.clear()
	visual_time=0.0
	# Four recessed public galleries. Density is bounded independently of room size.
	for row in 4:
		for i in 36:
			var key:=seed_value+row*997+i*131
			citizens.append({"x":(float(i)+.25+float(posmod(key,61))/100.0)*district_width/36.0,"y":282.0-row*180.0,"phase":float(posmod(key*17,628))/100.0,"coat":posmod(key,COATS.size()),"kind":posmod(key/7,7),"scale":(.57+float(posmod(key/11,17))/100.0)*(1.0 if row==0 else .72),"depth":0.0 if row==0 else .16,"walk":i%3!=0,"span":14.0+float(posmod(key/13,19))})
	queue_redraw()

func set_view(center:Vector2,size:Vector2)->void:
	if camera_center==center and viewport_size==size:return
	camera_center=center
	viewport_size=size
	queue_redraw()

func _process(delta:float)->void:
	if not is_visible_in_tree():return
	visual_time=fmod(visual_time+delta,3600.0)
	redraw_clock+=delta
	if redraw_clock>=1.0/30.0:
		redraw_clock=0.0
		queue_redraw()

func _draw()->void:
	if district_id.is_empty():return
	_draw_depth_plate()
	_draw_public_galleries()
	visible_citizens=0
	var visible_rect:=Rect2(camera_center-viewport_size*.5-Vector2(60,70),viewport_size+Vector2(120,140))
	for person in citizens:
		var phase:float=person.phase+visual_time*.31
		var x:float=person.x+(sin(phase)*float(person.span) if person.walk else 0.0)
		var foot:=Vector2(x,float(person.y))
		if not visible_rect.has_point(foot):continue
		visible_citizens+=1
		_draw_citizen(foot,person,phase)
	# The near-side railing keeps people visibly in a separate recessed lane.
	_draw_gallery_rails()
	draw_set_transform(Vector2.ZERO)

func _draw_depth_plate()->void:
	# Continuous parallax: camera movement scrolls the distant city at 18% speed.
	# The plate is background-only and never supplies a collision silhouette.
	var scale_factor:float=(viewport_size.y+100.0)/float(Plate.get_height())
	var tile_width:float=Plate.get_width()*scale_factor
	var left:float=camera_center.x-viewport_size.x*.5-40.0
	var top:float=camera_center.y-viewport_size.y*.5-50.0
	var phase:float=fposmod(camera_center.x*.18+float(seed_value%400),tile_width)
	var x:float=left-phase
	while x<left+viewport_size.x+80:
		draw_texture_rect(Plate,Rect2(x,top,tile_width,viewport_size.y+100.0),false,Color(.67,.73,.80,1))
		# Recessed structural joint conceals the non-tileable painting's edge.
		if x>left:
			draw_rect(Rect2(x-9,top,18,viewport_size.y+100),Color("101c26"))
			draw_line(Vector2(x+7,top),Vector2(x+7,top+viewport_size.y+100),Color("30535e"),1)
		x+=tile_width
	# A quiet blue veil keeps combat and traversable surfaces in the foreground.
	draw_rect(Rect2(Vector2(left,top),viewport_size+Vector2(80,100)),Color(.018,.035,.065,.12))

func _draw_public_galleries()->void:
	var left:float=maxf(0,camera_center.x-viewport_size.x*.5-60)
	var right:float=minf(district_width,camera_center.x+viewport_size.x*.5+60)
	for row in 4:
		var floor_y:=282.0-row*180.0
		if absf(floor_y-camera_center.y)>viewport_size.y*.5+80:continue
		# Transparent narrow gallery trim, not a bright false gameplay platform.
		draw_rect(Rect2(left,floor_y,right-left,6),Color(.05,.10,.13,.48))
		draw_line(Vector2(left,floor_y+1),Vector2(right,floor_y+1),Color(.20,.31,.34,.5),.7)
		for cell in range(floori(left/340),ceili(right/340)+1):
			var x:=cell*340.0+95.0
			var kind:=posmod(seed_value+cell+row*3,4)
			var light:=Color("7a4266") if kind%2==0 else Color("467378")
			# Sparse illuminated service plaques sit in the painted architecture.
			# The detailed original plate supplies the shops, rather than flat boxes.
			draw_rect(Rect2(x,floor_y-53,60,11),Color(.04,.08,.11,.70))
			draw_line(Vector2(x,floor_y-53),Vector2(x+60,floor_y-53),light,1)
			var word:="NIGHT MARKET" if kind==0 else ("REPAIRS" if kind==1 else ("TRANSIT" if kind==2 else "NIGHT SHIFT"))
			draw_string(FontFace,Vector2(x+4,floor_y-45),word,HORIZONTAL_ALIGNMENT_LEFT,54,6,light.lightened(.12))

func _draw_citizen(foot:Vector2,p:Dictionary,phase:float)->void:
	var s:float=p.scale
	var facing:=1.0 if cos(phase)>0 else -1.0
	var stride:=sin(visual_time*4.1+float(p.phase))*2.3 if p.walk else .0
	var lift:=absf(stride)*.15
	draw_set_transform(foot,0,Vector2(s*facing,s))
	var coat:Color=COATS[int(p.coat)].darkened(.40+float(p.depth))
	var skin:=Color("645b50") if int(p.kind)%2==0 else Color("4b4944")
	var legs:=Color("283740")
	# Separate trouser legs, shoes, coat, neck, face and hair rather than stick figures.
	draw_line(Vector2(-2,-10),Vector2(-3-stride,0),legs,3,true)
	draw_line(Vector2(3,-10),Vector2(4+stride,0),legs,3,true)
	draw_line(Vector2(-4-stride,0),Vector2(-1-stride,0),Color("17252c"),2,true)
	draw_line(Vector2(3+stride,0),Vector2(7+stride,0),Color("17252c"),2,true)
	var hem:= -8.0 if int(p.kind)%3==0 else -12.0
	draw_colored_polygon(PackedVector2Array([Vector2(-4,-26-lift),Vector2(4,-26-lift),Vector2(4.5,hem),Vector2(-4.5,hem)]),coat)
	draw_line(Vector2(1,-25-lift),Vector2(1,hem),coat.lightened(.12),1)
	draw_rect(Rect2(-1,-29-lift,3,4),skin)
	draw_circle(Vector2(0,-32-lift),2.8,skin)
	draw_arc(Vector2(-.5,-33-lift),2.7,PI,TAU,8,Color("28323b"),2,true)
	draw_line(Vector2(-4,-24-lift),Vector2(-6+stride*.5,-14),coat.darkened(.2),3,true)
	draw_line(Vector2(4,-24-lift),Vector2(6-stride*.5,-15),coat.lightened(.08),2.5,true)
	match int(p.kind):
		0: # Cap and shoulder bag.
			draw_rect(Rect2(-3,-35-lift,7,1.5),Color("455b63"))
			draw_rect(Rect2(-8,-18,5,7),Color("6b5a4b"))
		1: # Courier backpack, no weapon silhouette.
			draw_rect(Rect2(-7,-25,4,12),Color("665c4b"))
		2: # Resident holding a parcel.
			draw_rect(Rect2(4,-18,8,7),Color("7b6b57"))
		3: # Long scarf.
			draw_line(Vector2(0,-27),Vector2(-4,-15),Color("8b556b"),2)
		4: # Hooded commuter.
			draw_arc(Vector2(0,-32-lift),3.6,PI*.6,PI*2.4,12,coat.darkened(.1),2,true)
		5: # Grocery tote.
			draw_rect(Rect2(5,-12,5,8),Color("576b60"))
		_: # Worker's reflective shoulder strip, deliberately muted.
			draw_line(Vector2(-3,-24),Vector2(4,-24),Color("988464"),1)
	draw_set_transform(Vector2.ZERO)

func _draw_gallery_rails()->void:
	var left:float=maxf(0,camera_center.x-viewport_size.x*.5-60)
	var right:float=minf(district_width,camera_center.x+viewport_size.x*.5+60)
	for row in 4:
		var y:=282.0-row*180.0
		if absf(y-camera_center.y)>viewport_size.y*.5+80:continue
		draw_line(Vector2(left,y-12),Vector2(right,y-12),Color("28404b"),1)
		for i in range(floori(left/48),ceili(right/48)+1):draw_line(Vector2(i*48,y-12),Vector2(i*48,y+5),Color("253a43"),1)
