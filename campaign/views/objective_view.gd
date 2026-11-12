extends Node2D
const Caption=preload("res://campaign/views/objective_caption.gd")
const Cabinet=preload("res://assets/props/utility_cabinet.tres")
func _ready() -> void:
	# Machine paint stays behind actors. Caption paint must clear foreground props.
	# Keep the caption parented here so blind-mode hiding remains authoritative.
	z_index=-1
	var caption:=Node2D.new();caption.name="Caption";caption.set_script(Caption);caption.z_index=7;add_child(caption)
func _process(_dt: float) -> void: queue_redraw()
func _draw() -> void:
	var o = get_parent()
	var c := Color("67e0be") if o.completed else Color("ffc278") if o.available else Color("bac7cd")
	if o.kind == "breaker":
		draw_texture_rect(Cabinet,Rect2(-18,-42,36,42),false,Color(.7,.78,.8,1))
		if not o.completed:
			var cover:=PackedVector2Array([Vector2(-12,-34),Vector2(9,-34),Vector2(13,-30),Vector2(13,-11),Vector2(9,-7),Vector2(-9,-7),Vector2(-13,-11),Vector2(-13,-30)])
			draw_colored_polygon(cover,Color("3a4850"))
			cover.append(cover[0]);draw_polyline(cover,Color("9a7b58"),1,true)
			for bolt in [Vector2(-9,-30),Vector2(9,-30),Vector2(-9,-11),Vector2(9,-11)]:draw_circle(bolt,1.2,Color("b28a5d"),true,-1,true)
			for y in [-25,-21,-17]:draw_line(Vector2(-7,y),Vector2(7,y),Color("586975"),1.4,true)
		else:draw_rect(Rect2(-10,-31,20,19),Color("101e25"))
		draw_rect(Rect2(-10,-4,20,2),c)
	elif o.kind == "plate":
		draw_rect(Rect2(-38,-5,76,5),c)
		draw_line(Vector2(-32,-8),Vector2(32,-8),c,2)
	elif o.kind == "rescue":
		draw_style_box(_panel(c),Rect2(-19,-62,38,62))
		if not o.completed:
			draw_circle(Vector2(0,-44),6,Color("c7d4df"))
			draw_line(Vector2(0,-36),Vector2(0,-16),Color("c7d4df"),5)
	elif o.kind == "recover":
		draw_circle(Vector2(0,-20),13,c,false,2)
		draw_rect(Rect2(-5,-29,10,18),c)
	else:
		draw_texture_rect(Cabinet,Rect2(-18,-42,36,42),false,Color(.8,.86,.9,1))
		draw_rect(Rect2(-12,-35,24,19),Color("102b36"))
		if o.kind == "route":
			for i in 3: draw_circle(Vector2(-8+i*8,-25),2,c if o.setting==i else Color("364c59"))
		else: draw_line(Vector2(-9,-26),Vector2(9,-26),c,2)
func _panel(c:Color)->StyleBoxFlat:
	var p:=StyleBoxFlat.new();p.bg_color=Color("122632");p.border_color=c;p.set_border_width_all(2);p.set_corner_radius_all(3);return p


static func painted_bounds(kind:String)->Rect2:
	# Conservative local bounds of this view's machine paint, including strokes.
	# Caption avoidance consumes these; gameplay collision/radii do not.
	match kind:
		"recover":return Rect2(-14,-34,28,28)
		"rescue":return Rect2(-19,-62,38,62)
		"plate":return Rect2(-38,-9,76,9)
		_:return Rect2(-18,-42,36,42)

func caption_exclusion_rect()->Rect2:
	return get_global_transform_with_canvas()*painted_bounds(str(get_parent().kind))
