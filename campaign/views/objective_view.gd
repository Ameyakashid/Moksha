extends Node2D
func _process(_dt: float) -> void: queue_redraw()
func _draw() -> void:
	var o = get_parent()
	var c := Color("67e0be") if o.completed else Color("ffc278") if o.available else Color("677985")
	if o.kind == "breaker":
		draw_style_box(_panel(c),Rect2(-18,-42,36,42))
		draw_line(Vector2(-11,-34),Vector2(11,-8),c,3)
		draw_line(Vector2(11,-34),Vector2(-11,-8),c,3)
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
		draw_style_box(_panel(c),Rect2(-18,-42,36,42))
		draw_rect(Rect2(-12,-35,24,19),Color("102b36"))
		if o.kind == "route":
			for i in 3: draw_circle(Vector2(-8+i*8,-25),2,c if o.setting==i else Color("364c59"))
		else: draw_line(Vector2(-9,-26),Vector2(9,-26),c,2)
	var caption: String = o.label + (" ✓" if o.completed else " [PROP]" if o.kind=="plate" else " [J]" if o.kind=="breaker" else " [E]")
	draw_string(ThemeDB.fallback_font,Vector2(-60,-74 if o.kind=="rescue" else -54),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,c)
	if o.kind=="route": draw_string(ThemeDB.fallback_font,Vector2(-50,-66),("UNROUTED / TARGET %d"%o.target) if o.setting<0 else ("CIRCUIT %d / TARGET %d" %[o.setting,o.target]),HORIZONTAL_ALIGNMENT_LEFT,-1,9,c)
func _panel(c:Color)->StyleBoxFlat:
	var p:=StyleBoxFlat.new();p.bg_color=Color("122632");p.border_color=c;p.set_border_width_all(2);p.set_corner_radius_all(3);return p
