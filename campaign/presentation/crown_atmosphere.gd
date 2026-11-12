extends Node2D
## District-owned high-arcology vista, derived presentation only. No simulation authority.
const Plate=preload("res://campaign/assets/crown/crown_vista_original.png")
var district_id:=""
var camera_center:=Vector2(320,180)
var viewport_size:=Vector2(640,360)
var seed_value:=1
var plate_tint:=Color(.48,.48,.55,1)
var warden_profile:=false
func configure(profile:Dictionary)->void:
	district_id=str(profile.get("id","crown_ascent"))
	seed_value=1
	for byte in district_id.to_utf8_buffer():seed_value=posmod(seed_value*31+byte,104729)
	warden_profile="warden" in district_id
	plate_tint=Color(.43,.43,.42,1) if warden_profile else Color(.48,.49,.49,1)
	# Staff are tiny static painted silhouettes, not NPCs. Nothing ticks offscreen.
	set_process(false)
	queue_redraw()
func set_view(center:Vector2,size:Vector2)->void:
	if camera_center==center and viewport_size==size:return
	camera_center=center;viewport_size=size;queue_redraw()
func _draw()->void:
	if district_id.is_empty():return
	var height:=viewport_size.y+100.0
	var tile_width:=Plate.get_width()*height/float(Plate.get_height())
	var left:=camera_center.x-viewport_size.x*.5-40.0
	var top:=camera_center.y-viewport_size.y*.5-45.0
	var phase:=fposmod(camera_center.x*.10+float(seed_value%340),tile_width)
	draw_rect(Rect2(camera_center-viewport_size*.5-Vector2(40,50),viewport_size+Vector2(80,100)),Color("100f10"))
	var x:=left-phase
	while x<left+viewport_size.x+80:
		draw_texture_rect(Plate,Rect2(x,top,tile_width,height),false,plate_tint)
		# Recessed structural ribs conceal repeated painting joints, never gameplay walls.
		if x>left:
			draw_rect(Rect2(x-6,top,12,height),Color("211b18"))
			draw_line(Vector2(x+4,top),Vector2(x+4,top+height),Color("39302a"),1)
		x+=tile_width
