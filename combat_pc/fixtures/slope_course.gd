@tool
extends StaticBody2D
## One editor-placeable continuous profile for slope locomotion inspection.
## It is ordinary world collision; the player has no dependency on this fixture.
@export var surface := PackedVector2Array([
	Vector2(0,0),Vector2(80,0),Vector2(240,-80),Vector2(300,-80),
	Vector2(380,0),Vector2(460,0),Vector2(540,-80),Vector2(600,-80),
	Vector2(760,0),Vector2(840,0)
]):
	set(value):
		surface=value
		_sync()
@export var depth := 48.0:
	set(value):
		depth=value
		_sync()
func _ready() -> void:
	_sync()
func _sync() -> void:
	var shape:=get_node_or_null("Shape") as CollisionPolygon2D
	if surface.size()<2:
		if shape:shape.polygon=PackedVector2Array()
		queue_redraw()
		return
	var polygon:=surface.duplicate()
	polygon.append(Vector2(surface[-1].x,depth))
	polygon.append(Vector2(surface[0].x,depth))
	if shape:shape.polygon=polygon
	queue_redraw()
func _draw() -> void:
	if surface.size()<2:return
	draw_polyline(surface,Color("9bddd0"),0.8)
	for point in surface:
		draw_line(point,Vector2(point.x,depth),Color(0.23,0.35,0.40,0.35),0.4)
	draw_line(Vector2(surface[0].x,depth),Vector2(surface[-1].x,depth),Color("6f899b"),0.6)
	draw_string(ThemeDB.fallback_font,Vector2(102,-93),"26.6 UP  /  45 DOWN",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("9bddd0"))
	draw_string(ThemeDB.fallback_font,Vector2(482,-93),"45 UP  /  26.6 DOWN",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("9bddd0"))
	draw_string(ThemeDB.fallback_font,Vector2(12,32),"M  SLOPES / RELEASE, REVERSE, JUMP, ROLL",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("8ea5b5"))
