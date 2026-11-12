extends Node2D
## District-owned recessed waterworks view. No simulation or gameplay authority.
const Plate=preload("res://campaign/assets/cistern/cistern_depth_original.png")
const MAX_DRIPS:=6
var district_id:=""
var camera_center:=Vector2(320,180)
var viewport_size:=Vector2(640,360)
var seed_value:=1
var visual_time:=0.0
var redraw_clock:=0.0
var visible_drips:=0
var residential_profile:=false
var plate_tint:=Color(.46,.57,.59,1)
func configure(profile:Dictionary)->void:
	district_id=str(profile.get("id","l3_cistern"))
	seed_value=1
	for byte in district_id.to_utf8_buffer():seed_value=posmod(seed_value*31+byte,104729)
	residential_profile="homes" in district_id
	plate_tint=Color(.54,.56,.53,1) if residential_profile else Color(.46,.57,.59,1)
	visual_time=0.0;queue_redraw()
func set_view(center:Vector2,size:Vector2)->void:
	if camera_center==center and viewport_size==size:return
	camera_center=center;viewport_size=size;queue_redraw()
func _process(delta:float)->void:
	if not is_visible_in_tree():return
	visual_time=fmod(visual_time+delta,3600.0);redraw_clock+=delta
	if redraw_clock>=.1:redraw_clock=0.0;queue_redraw()
func _draw()->void:
	if district_id.is_empty():return
	var height:=viewport_size.y+100.0
	var tile_width:=Plate.get_width()*height/float(Plate.get_height())
	var left:=camera_center.x-viewport_size.x*.5-40.0
	var top:=camera_center.y-viewport_size.y*.5+(20.0 if residential_profile else -50.0)
	var phase:=fposmod(camera_center.x*(.06 if residential_profile else .14)+float(seed_value%(80 if residential_profile else 400)),tile_width)
	draw_rect(Rect2(camera_center-viewport_size*.5-Vector2(40,50),viewport_size+Vector2(80,100)),Color("081719"))
	var x:=left-phase
	visible_drips=0
	while x<left+viewport_size.x+80:
		draw_texture_rect(Plate,Rect2(x,top,tile_width,height),false,plate_tint)
		if x>left:
			draw_rect(Rect2(x-5,top,10,height),Color("0d1b1d"))
			draw_line(Vector2(x+4,top),Vector2(x+4,top+height),Color("203736"),1)
		for i in 3:
			var dx:=x+tile_width*(.21+i*.25)
			if dx<left or dx>left+viewport_size.x+80 or visible_drips>=MAX_DRIPS:continue
			visible_drips+=1
			var y:=top+height*(.60+fposmod(visual_time*.06+i*.13,.20))
			draw_line(Vector2(dx,y),Vector2(dx,y+3),Color(.18,.30,.29,.30),.6)
		x+=tile_width
