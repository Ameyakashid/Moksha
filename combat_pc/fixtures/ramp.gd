@tool
extends StaticBody2D
@export var rise := 36.0:
	set(value):
		rise=value
		_sync()
@export var width := 96.0:
	set(value):
		width=value
		_sync()
func _ready() -> void: _sync()
func _sync() -> void:
	var shape := get_node_or_null("Shape") as CollisionPolygon2D
	if shape: shape.polygon=PackedVector2Array([Vector2.ZERO,Vector2(width,-rise),Vector2(width,24),Vector2(0,24)])
	queue_redraw()
func _draw() -> void:
	var points := PackedVector2Array([Vector2.ZERO,Vector2(width,-rise),Vector2(width,24),Vector2(0,24),Vector2.ZERO])
	draw_polyline(points,Color("6f899b"),0.7)
	draw_string(ThemeDB.fallback_font,Vector2(12,-42),"SLOPE + LANDING",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("6f899b"))

