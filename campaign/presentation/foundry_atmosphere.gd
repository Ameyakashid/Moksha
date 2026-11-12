extends Node2D
## Optional district-owned view: recessed foundry paint, never collision or actors.
const Plate=preload("res://campaign/assets/foundry/foundry_depth_original.png")
const MAX_VISIBLE_WORKERS:=9
var district_id:=""
var camera_center:=Vector2(320,180)
var viewport_size:=Vector2(640,360)
var seed_value:=1
var visual_time:=0.0
var redraw_clock:=0.0
var visible_workers:=0
var plate_tint:=Color(.60,.64,.66,1)
func configure(profile:Dictionary)->void:
	district_id=str(profile.get("id","foundry"))
	seed_value=1
	for byte in district_id.to_utf8_buffer():seed_value=posmod(seed_value*31+byte,104729)
	plate_tint=Color(.54,.56,.55,1) if "thermal" in district_id else Color(.51,.60,.64,1)
	visual_time=0.0
	queue_redraw()
func set_view(center:Vector2,size:Vector2)->void:
	if camera_center==center and viewport_size==size:return
	camera_center=center;viewport_size=size
	queue_redraw()
func _process(delta:float)->void:
	if not is_visible_in_tree():return
	visual_time=fmod(visual_time+delta,3600.0)
	redraw_clock+=delta
	if redraw_clock>=1.0/15.0:
		redraw_clock=0.0;queue_redraw()
func _draw()->void:
	if district_id.is_empty():return
	var height:=viewport_size.y+100.0
	var scale_factor:=height/float(Plate.get_height())
	var tile_width:=Plate.get_width()*scale_factor
	var left:=camera_center.x-viewport_size.x*.5-40.0
	var top:=camera_center.y-viewport_size.y*.5-50.0
	var phase:=fposmod(camera_center.x*.16+float(seed_value%320),tile_width)
	var x:=left-phase
	visible_workers=0
	# Bounded viewport tiles, not room-width geometry. Opaque plate owns this view.
	while x<left+viewport_size.x+80:
		draw_texture_rect(Plate,Rect2(x,top,tile_width,height),false,plate_tint)
		if x>left:
			draw_rect(Rect2(x-6,top,12,height),Color("101b20"))
			draw_line(Vector2(x+4,top),Vector2(x+4,top+height),Color("263f46"),1)
		for i in 3:
			var p:=float(seed_value%61)*.1+i*2.1
			var foot:=Vector2(x+tile_width*(.27+i*.24)+sin(visual_time*.21+p)*7,top+height*.389)
			if foot.x<left or foot.x>left+viewport_size.x+80:continue
			if visible_workers>=MAX_VISIBLE_WORKERS:break
			visible_workers+=1
			_draw_worker(foot,scale_factor*.92,p,i)
		x+=tile_width
	_draw_lower_recess(left,top,viewport_size.x+80,height,phase)
	draw_set_transform(Vector2.ZERO)
func _draw_worker(foot:Vector2,s:float,phase:float,kind:int)->void:
	var stride:=sin(visual_time*2.8+phase)*1.6 if kind!=1 else 0.0
	draw_set_transform(foot,0,Vector2(s,s))
	var coat:=Color("4a4936") if kind%2==0 else Color("30464a")
	draw_line(Vector2(-2,-13),Vector2(-3-stride,0),Color("202d30"),3,true)
	draw_line(Vector2(3,-13),Vector2(4+stride,0),Color("202d30"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-4,-29),Vector2(4,-29),Vector2(5,-12),Vector2(-4,-12)]),coat)
	draw_line(Vector2(-4,-27),Vector2(-6+stride,-16),coat.darkened(.1),3,true)
	draw_line(Vector2(4,-27),Vector2(6-stride,-16),coat.darkened(.1),3,true)
	draw_circle(Vector2(0,-33),3,Color("615b49"))
	draw_arc(Vector2(0,-34),3.5,PI,TAU,8,Color("625e42"),2,true)
	draw_line(Vector2(-4,-34),Vector2(4,-34),Color("615f48"),1,true)
	if kind==1:draw_rect(Rect2(4,-20,5,7),Color("354c51"))
	draw_set_transform(Vector2.ZERO)

func _draw_lower_recess(left:float,top:float,width:float,height:float,phase:float)->void:
	# Fade the painted furnace wall into a quiet recessed service basement.
	# These dim vertical supports never imply a traversable horizontal surface.
	var y0:=top+height*.60
	var y1:=top+height*.76
	var bottom:=top+height
	var clear:=Color(.012,.022,.027,0)
	var dark:=Color(.012,.022,.027,.88)
	draw_polygon(PackedVector2Array([Vector2(left,y0),Vector2(left+width,y0),Vector2(left+width,y1),Vector2(left,y1)]),PackedColorArray([clear,clear,dark,dark]))
	draw_rect(Rect2(left,y1,width,bottom-y1),dark)
	var x:=left-fposmod(phase,180.0)
	while x<left+width:
		draw_rect(Rect2(x,y1-18,4,bottom-y1+18),Color("081014"))
		draw_line(Vector2(x+4,y1-18),Vector2(x+4,bottom),Color("0d171c"),1)
		draw_rect(Rect2(x+28,y1+19,34,24),Color("070e11"))
		draw_line(Vector2(x+31,y1+23),Vector2(x+31,y1+39),Color("0c1519"),1)
		x+=180
